import { useState } from 'react';
import { Button, DatePicker, Input, Popconfirm, Select, Table, Tooltip, Typography } from 'antd';
import { DeleteOutlined, PlusOutlined, QuestionCircleOutlined } from '@ant-design/icons';
import type { ColumnsType } from 'antd/es/table';
import dayjs, { type Dayjs } from 'dayjs';
import OverridesEditor from './OverridesEditor';
import { type OverrideRow, overridesToRows, rowsToOverrides, takeOverrideUid } from './overrides';

const { Text } = Typography;

type Platform = 'android' | 'ios';

interface SegmentRow {
  uid: number;
  id: string;
  platform?: Platform;
  vip?: boolean;
  installedAfter?: string;
  installedBefore?: string;
  overrides: OverrideRow[];
  /** Неизвестные (passthrough) поля исходного сегмента */
  extras: Record<string, unknown>;
  /** Неизвестные (passthrough) поля conditions */
  extrasConditions: Record<string, unknown>;
}

interface Props {
  value: unknown[];
  onChange: (next: unknown[]) => void;
}

const asRecord = (v: unknown): Record<string, unknown> =>
  v && typeof v === 'object' && !Array.isArray(v) ? (v as Record<string, unknown>) : {};

const KNOWN_SEG = new Set(['id', 'conditions', 'overrides']);
const KNOWN_COND = new Set(['platform', 'vip', 'installedAfter', 'installedBefore']);

const pickExtras = (e: Record<string, unknown>, known: Set<string>): Record<string, unknown> => {
  const extras: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(e)) if (!known.has(k)) extras[k] = v;
  return extras;
};

const initRows = (value: unknown[]): SegmentRow[] =>
  (Array.isArray(value) ? value : []).map((entry) => {
    const e = asRecord(entry);
    const cond = asRecord(e.conditions);
    return {
      uid: takeOverrideUid(),
      id: typeof e.id === 'string' ? e.id : '',
      platform: cond.platform === 'android' || cond.platform === 'ios' ? cond.platform : undefined,
      vip: typeof cond.vip === 'boolean' ? cond.vip : undefined,
      installedAfter: typeof cond.installedAfter === 'string' ? cond.installedAfter : undefined,
      installedBefore: typeof cond.installedBefore === 'string' ? cond.installedBefore : undefined,
      overrides: overridesToRows(e.overrides),
      extras: pickExtras(e, KNOWN_SEG),
      extrasConditions: pickExtras(cond, KNOWN_COND),
    };
  });

/**
 * Редактор секции segments (спека 4.6): таблица сегментов с условиями
 * (платформа/VIP/дата установки), overrides — в развёрнутой строке.
 */
export default function SegmentsEditor({ value, onChange }: Props) {
  const [rows, setRows] = useState<SegmentRow[]>(() => initRows(value));
  const [expandedKeys, setExpandedKeys] = useState<readonly React.Key[]>(() => rows.map((r) => r.uid));

  const build = (list: SegmentRow[]): unknown[] =>
    list
      .filter((r) => r.id.trim())
      .map((r) => {
        const conditions: Record<string, unknown> = { ...r.extrasConditions };
        if (r.platform) conditions.platform = r.platform;
        if (typeof r.vip === 'boolean') conditions.vip = r.vip;
        if (r.installedAfter) conditions.installedAfter = r.installedAfter;
        if (r.installedBefore) conditions.installedBefore = r.installedBefore;
        const seg: Record<string, unknown> = {
          ...r.extras,
          id: r.id.trim(),
          overrides: rowsToOverrides(r.overrides),
        };
        if (Object.keys(conditions).length > 0) seg.conditions = conditions;
        return seg;
      });

  const update = (list: SegmentRow[]) => {
    setRows(list);
    onChange(build(list));
  };

  const patchRow = (uid: number, patch: Partial<SegmentRow>) =>
    update(rows.map((r) => (r.uid === uid ? { ...r, ...patch } : r)));

  const addSegment = () => {
    const uid = takeOverrideUid();
    update([...rows, { uid, id: '', overrides: [], extras: {}, extrasConditions: {} }]);
    setExpandedKeys((prev) => [...prev, uid]);
  };

  const dateCell = (field: 'installedAfter' | 'installedBefore') =>
    function DateCell(_: unknown, r: SegmentRow) {
      return (
        <DatePicker
          value={r[field] ? dayjs(r[field]) : null}
          size="small"
          showTime
          format="DD.MM.YYYY HH:mm"
          placeholder="—"
          style={{ width: '100%' }}
          onChange={(d: Dayjs | null) => patchRow(r.uid, { [field]: d ? d.toISOString() : undefined })}
        />
      );
    };

  const columns: ColumnsType<SegmentRow> = [
    {
      title: 'ID сегмента',
      key: 'id',
      width: 170,
      render: (_: unknown, r: SegmentRow) => (
        <Input
          value={r.id}
          size="small"
          placeholder="ios_vip"
          status={r.id.trim() ? undefined : 'error'}
          onChange={(e) => patchRow(r.uid, { id: e.target.value })}
        />
      ),
    },
    {
      title: 'Платформа',
      key: 'platform',
      width: 120,
      render: (_: unknown, r: SegmentRow) => (
        <Select
          value={r.platform ?? 'any'}
          size="small"
          style={{ width: '100%' }}
          options={[
            { value: 'any', label: 'Любая' },
            { value: 'android', label: 'Android' },
            { value: 'ios', label: 'iOS' },
          ]}
          onChange={(v: 'any' | Platform) => patchRow(r.uid, { platform: v === 'any' ? undefined : v })}
        />
      ),
    },
    {
      title: 'VIP',
      key: 'vip',
      width: 110,
      render: (_: unknown, r: SegmentRow) => (
        <Select
          value={r.vip === undefined ? 'any' : r.vip ? 'yes' : 'no'}
          size="small"
          style={{ width: '100%' }}
          options={[
            { value: 'any', label: 'Любой' },
            { value: 'yes', label: 'Да' },
            { value: 'no', label: 'Нет' },
          ]}
          onChange={(v: 'any' | 'yes' | 'no') => patchRow(r.uid, { vip: v === 'any' ? undefined : v === 'yes' })}
        />
      ),
    },
    {
      title: (
        <span>
          Установлено после{' '}
          <Tooltip title="Условие по дате первого запуска приложения (first_launch_ts). Пусто — без ограничения.">
            <QuestionCircleOutlined />
          </Tooltip>
        </span>
      ),
      key: 'installedAfter',
      width: 190,
      render: dateCell('installedAfter'),
    },
    {
      title: 'Установлено до',
      key: 'installedBefore',
      width: 190,
      render: dateCell('installedBefore'),
    },
    {
      title: 'Overrides',
      key: 'overrides',
      render: (_: unknown, r: SegmentRow) => {
        const count = r.overrides.filter((o) => o.k.trim()).length;
        return <Text type="secondary">{count > 0 ? `${count} шт` : 'нет'}</Text>;
      },
    },
    {
      title: '',
      key: 'del',
      width: 44,
      render: (_: unknown, r: SegmentRow) => (
        <Popconfirm title={`Удалить сегмент "${r.id || '(без id)'}"?`} onConfirm={() => update(rows.filter((x) => x.uid !== r.uid))}>
          <Button icon={<DeleteOutlined />} size="small" danger />
        </Popconfirm>
      ),
    },
  ];

  return (
    <div>
      <Text type="secondary" style={{ display: 'block', marginBottom: 8 }}>
        Пользователь попадает в сегмент, если выполнены все заданные условия. Overrides подошедших сегментов применяются по порядку массива, поверх базового конфига.
      </Text>
      <Table
        columns={columns}
        dataSource={rows}
        rowKey="uid"
        size="small"
        pagination={false}
        locale={{ emptyText: 'Нет сегментов' }}
        expandable={{
          expandedRowRender: (r) => (
            <OverridesEditor rows={r.overrides} onChange={(next) => patchRow(r.uid, { overrides: next })} />
          ),
          expandedRowKeys: expandedKeys,
          onExpandedRowsChange: setExpandedKeys,
        }}
      />
      <Button icon={<PlusOutlined />} onClick={addSegment} style={{ marginTop: 8 }}>
        Добавить сегмент
      </Button>
    </div>
  );
}
