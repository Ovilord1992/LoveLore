import { useState } from 'react';
import { Button, Card, Input, InputNumber, Popconfirm, Space, Switch, Table, Tooltip, Typography } from 'antd';
import { DeleteOutlined, PlusOutlined, QuestionCircleOutlined } from '@ant-design/icons';
import type { ColumnsType } from 'antd/es/table';
import OverridesEditor from './OverridesEditor';
import { type OverrideRow, overridesToRows, rowsToOverrides, takeOverrideUid } from './overrides';

const { Text } = Typography;

interface VariantRow {
  uid: number;
  key: string;
  weight?: number;
  overrides: OverrideRow[];
  /** Неизвестные (passthrough) поля исходного варианта */
  extras: Record<string, unknown>;
}

interface ExperimentRow {
  uid: number;
  id: string;
  enabled: boolean;
  variants: VariantRow[];
  /** Неизвестные (passthrough) поля исходного эксперимента */
  extras: Record<string, unknown>;
}

interface Props {
  value: unknown[];
  onChange: (next: unknown[]) => void;
}

const asRecord = (v: unknown): Record<string, unknown> =>
  v && typeof v === 'object' && !Array.isArray(v) ? (v as Record<string, unknown>) : {};

const KNOWN_EXP = new Set(['id', 'enabled', 'variants']);
const KNOWN_VARIANT = new Set(['key', 'weight', 'overrides']);

const pickExtras = (e: Record<string, unknown>, known: Set<string>): Record<string, unknown> => {
  const extras: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(e)) if (!known.has(k)) extras[k] = v;
  return extras;
};

const initRows = (value: unknown[]): ExperimentRow[] =>
  (Array.isArray(value) ? value : []).map((entry) => {
    const e = asRecord(entry);
    const variants = (Array.isArray(e.variants) ? e.variants : []).map((raw): VariantRow => {
      const v = asRecord(raw);
      return {
        uid: takeOverrideUid(),
        key: typeof v.key === 'string' ? v.key : '',
        weight: typeof v.weight === 'number' ? v.weight : undefined,
        overrides: overridesToRows(v.overrides),
        extras: pickExtras(v, KNOWN_VARIANT),
      };
    });
    return {
      uid: takeOverrideUid(),
      id: typeof e.id === 'string' ? e.id : '',
      enabled: e.enabled !== false,
      variants,
      extras: pickExtras(e, KNOWN_EXP),
    };
  });

const totalWeight = (exp: ExperimentRow): number =>
  exp.variants.reduce((sum, v) => sum + (typeof v.weight === 'number' ? v.weight : 0), 0);

/**
 * Редактор секции experiments (A/B, спека 4.6): таблица экспериментов,
 * в развёрнутой строке — варианты (key/weight/overrides).
 */
export default function ExperimentsEditor({ value, onChange }: Props) {
  const [rows, setRows] = useState<ExperimentRow[]>(() => initRows(value));
  const [expandedKeys, setExpandedKeys] = useState<readonly React.Key[]>(() => rows.map((r) => r.uid));

  const build = (list: ExperimentRow[]): unknown[] =>
    list
      .filter((r) => r.id.trim())
      .map((r) => ({
        ...r.extras,
        id: r.id.trim(),
        enabled: r.enabled,
        variants: r.variants
          .filter((v) => v.key.trim())
          .map((v) => ({
            ...v.extras,
            key: v.key.trim(),
            weight: typeof v.weight === 'number' ? v.weight : 1,
            overrides: rowsToOverrides(v.overrides),
          })),
      }));

  const update = (list: ExperimentRow[]) => {
    setRows(list);
    onChange(build(list));
  };

  const patchExp = (uid: number, patch: Partial<ExperimentRow>) =>
    update(rows.map((r) => (r.uid === uid ? { ...r, ...patch } : r)));

  const patchVariant = (exp: ExperimentRow, vuid: number, patch: Partial<VariantRow>) =>
    patchExp(exp.uid, { variants: exp.variants.map((v) => (v.uid === vuid ? { ...v, ...patch } : v)) });

  const addExperiment = () => {
    const uid = takeOverrideUid();
    const control: VariantRow = { uid: takeOverrideUid(), key: 'control', weight: 50, overrides: [], extras: {} };
    update([...rows, { uid, id: '', enabled: false, variants: [control], extras: {} }]);
    setExpandedKeys((prev) => [...prev, uid]);
  };

  const columns: ColumnsType<ExperimentRow> = [
    {
      title: (
        <span>
          ID эксперимента{' '}
          <Tooltip title="Стабильный идентификатор: бакетирование клиента детерминировано по deviceId + id. Смена id перераспределит пользователей по вариантам.">
            <QuestionCircleOutlined />
          </Tooltip>
        </span>
      ),
      key: 'id',
      width: 240,
      render: (_: unknown, r: ExperimentRow) => (
        <Input
          value={r.id}
          size="small"
          placeholder="price_test_1"
          status={r.id.trim() ? undefined : 'error'}
          onChange={(e) => patchExp(r.uid, { id: e.target.value })}
        />
      ),
    },
    {
      title: 'Включён',
      key: 'enabled',
      width: 100,
      render: (_: unknown, r: ExperimentRow) => (
        <Switch
          checked={r.enabled}
          checkedChildren="Да"
          unCheckedChildren="Нет"
          onChange={(checked) => patchExp(r.uid, { enabled: checked })}
        />
      ),
    },
    {
      title: 'Варианты',
      key: 'variants',
      render: (_: unknown, r: ExperimentRow) => {
        const sum = totalWeight(r);
        return (
          <Text type={sum > 0 ? 'secondary' : 'danger'}>
            {r.variants.length} шт · суммарный вес {sum}
          </Text>
        );
      },
    },
    {
      title: '',
      key: 'del',
      width: 44,
      render: (_: unknown, r: ExperimentRow) => (
        <Popconfirm title={`Удалить эксперимент "${r.id || '(без id)'}"?`} onConfirm={() => update(rows.filter((x) => x.uid !== r.uid))}>
          <Button icon={<DeleteOutlined />} size="small" danger />
        </Popconfirm>
      ),
    },
  ];

  const renderVariants = (exp: ExperimentRow) => {
    const sum = totalWeight(exp);
    return (
      <Space direction="vertical" style={{ width: '100%' }} size="small">
        {exp.variants.map((v) => (
          <Card
            key={v.uid}
            size="small"
            title={
              <Space wrap>
                <Input
                  value={v.key}
                  size="small"
                  placeholder="control"
                  style={{ width: 160 }}
                  status={v.key.trim() ? undefined : 'error'}
                  onChange={(e) => patchVariant(exp, v.uid, { key: e.target.value })}
                />
                <Text type="secondary">вес:</Text>
                <InputNumber
                  value={v.weight}
                  size="small"
                  min={1}
                  precision={0}
                  style={{ width: 80 }}
                  status={typeof v.weight === 'number' && v.weight > 0 ? undefined : 'error'}
                  onChange={(n) => patchVariant(exp, v.uid, { weight: typeof n === 'number' ? n : undefined })}
                />
                {sum > 0 && typeof v.weight === 'number' && (
                  <Text type="secondary">≈ {((v.weight / sum) * 100).toFixed(1)}%</Text>
                )}
              </Space>
            }
            extra={
              <Popconfirm
                title={`Удалить вариант "${v.key || '(без key)'}"?`}
                onConfirm={() => patchExp(exp.uid, { variants: exp.variants.filter((x) => x.uid !== v.uid) })}
              >
                <Button icon={<DeleteOutlined />} size="small" danger disabled={exp.variants.length <= 1} />
              </Popconfirm>
            }
          >
            <OverridesEditor rows={v.overrides} onChange={(next) => patchVariant(exp, v.uid, { overrides: next })} />
          </Card>
        ))}
        <Space wrap>
          <Button
            icon={<PlusOutlined />}
            size="small"
            onClick={() =>
              patchExp(exp.uid, {
                variants: [...exp.variants, { uid: takeOverrideUid(), key: '', weight: 50, overrides: [], extras: {} }],
              })
            }
          >
            Добавить вариант
          </Button>
          <Text type={sum > 0 ? 'secondary' : 'danger'}>
            Суммарный вес: {sum}
            {sum > 0
              ? ` — доли: ${exp.variants
                  .filter((v) => typeof v.weight === 'number')
                  .map((v) => `${v.key || '?'} ${(((v.weight as number) / sum) * 100).toFixed(1)}%`)
                  .join(', ')}`
              : ' — задайте положительные веса'}
          </Text>
        </Space>
      </Space>
    );
  };

  return (
    <div>
      <Text type="secondary" style={{ display: 'block', marginBottom: 8 }}>
        Порядок применения на клиенте: базовый конфиг → overrides сегментов → overrides варианта каждого включённого эксперимента.
      </Text>
      <Table
        columns={columns}
        dataSource={rows}
        rowKey="uid"
        size="small"
        pagination={false}
        locale={{ emptyText: 'Нет экспериментов' }}
        expandable={{
          expandedRowRender: renderVariants,
          expandedRowKeys: expandedKeys,
          onExpandedRowsChange: setExpandedKeys,
        }}
      />
      <Button icon={<PlusOutlined />} onClick={addExperiment} style={{ marginTop: 8 }}>
        Добавить эксперимент
      </Button>
    </div>
  );
}
