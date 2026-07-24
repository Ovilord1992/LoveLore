import { useRef, useState } from 'react';
import { Button, Input, InputNumber, Popconfirm, Table, Typography } from 'antd';
import { DeleteOutlined, PlusOutlined } from '@ant-design/icons';
import type { ColumnsType } from 'antd/es/table';

const { Text } = Typography;

interface DailyRow {
  uid: number;
  diamonds: number;
  tickets: number;
  label: string;
  /** Неизвестные (passthrough) поля исходной записи */
  extras: Record<string, unknown>;
}

interface Props {
  value: unknown[];
  onChange: (next: unknown[]) => void;
}

const KNOWN = new Set(['day', 'diamonds', 'tickets', 'label']);

const initRows = (value: unknown[]): DailyRow[] =>
  (Array.isArray(value) ? value : []).map((entry, i) => {
    const e = (entry && typeof entry === 'object' ? entry : {}) as Record<string, unknown>;
    const extras: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(e)) if (!KNOWN.has(k)) extras[k] = v;
    return {
      uid: i + 1,
      diamonds: typeof e.diamonds === 'number' ? e.diamonds : 0,
      tickets: typeof e.tickets === 'number' ? e.tickets : 0,
      label: typeof e.label === 'string' ? e.label : '',
      extras,
    };
  });

/** Редактор ежедневных наград: день = позиция строки, валюта + сумма + подпись. */
export default function DailyEditor({ value, onChange }: Props) {
  const [rows, setRows] = useState<DailyRow[]>(() => initRows(value));
  const nextUid = useRef(rows.length + 1);

  const build = (list: DailyRow[]): unknown[] =>
    list.map((r, i) => {
      const entry: Record<string, unknown> = { ...r.extras, day: i + 1, diamonds: r.diamonds, tickets: r.tickets };
      if (r.label.trim()) entry.label = r.label;
      return entry;
    });

  const update = (list: DailyRow[]) => {
    setRows(list);
    onChange(build(list));
  };

  const patchRow = (uid: number, patch: Partial<DailyRow>) =>
    update(rows.map((r) => (r.uid === uid ? { ...r, ...patch } : r)));

  const columns: ColumnsType<DailyRow> = [
    {
      title: 'День',
      key: 'day',
      width: 70,
      render: (_: unknown, __: DailyRow, index: number) => <Text strong>{index + 1}</Text>,
    },
    {
      title: '💎 Алмазы',
      key: 'diamonds',
      width: 120,
      render: (_: unknown, r: DailyRow) => (
        <InputNumber
          value={r.diamonds}
          min={0}
          precision={0}
          size="small"
          style={{ width: '100%' }}
          onChange={(v) => patchRow(r.uid, { diamonds: typeof v === 'number' ? v : 0 })}
        />
      ),
    },
    {
      title: '🎟 Билеты',
      key: 'tickets',
      width: 120,
      render: (_: unknown, r: DailyRow) => (
        <InputNumber
          value={r.tickets}
          min={0}
          precision={0}
          size="small"
          style={{ width: '100%' }}
          onChange={(v) => patchRow(r.uid, { tickets: typeof v === 'number' ? v : 0 })}
        />
      ),
    },
    {
      title: 'Подпись',
      key: 'label',
      render: (_: unknown, r: DailyRow) => (
        <Input
          value={r.label}
          size="small"
          placeholder="5 💎"
          onChange={(e) => patchRow(r.uid, { label: e.target.value })}
        />
      ),
    },
    {
      title: '',
      key: 'del',
      width: 44,
      render: (_: unknown, r: DailyRow) => (
        <Popconfirm title="Удалить день? Нумерация сдвинется." onConfirm={() => update(rows.filter((x) => x.uid !== r.uid))}>
          <Button icon={<DeleteOutlined />} size="small" danger />
        </Popconfirm>
      ),
    },
  ];

  return (
    <div>
      {rows.length !== 7 && (
        <Text type="warning" style={{ display: 'block', marginBottom: 8 }}>
          Внимание: дней сейчас {rows.length}, клиент рассчитан на цикл из 7 дней.
        </Text>
      )}
      <Table
        columns={columns}
        dataSource={rows}
        rowKey="uid"
        size="small"
        pagination={false}
        locale={{ emptyText: 'Нет наград' }}
      />
      <Button icon={<PlusOutlined />} onClick={() => update([...rows, { uid: nextUid.current++, diamonds: 0, tickets: 0, label: '', extras: {} }])} style={{ marginTop: 8 }}>
        Добавить день
      </Button>
    </div>
  );
}
