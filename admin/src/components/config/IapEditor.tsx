import { useRef, useState } from 'react';
import { Button, Input, InputNumber, Popconfirm, Table, Typography } from 'antd';
import { DeleteOutlined, PlusOutlined } from '@ant-design/icons';
import type { ColumnsType } from 'antd/es/table';

const { Text } = Typography;

/** Секция iap: map productId → награда + спец-ключ products[] с ценами usdCents */
export type IapSection = Record<string, unknown>;

interface IapRow {
  uid: number;
  productId: string;
  diamonds?: number;
  tickets?: number;
  vipDays?: number;
  usdCents?: number;
}

interface Props {
  value: IapSection;
  onChange: (next: IapSection) => void;
}

const asRecord = (v: unknown): Record<string, unknown> =>
  v && typeof v === 'object' && !Array.isArray(v) ? (v as Record<string, unknown>) : {};

const numOrUndef = (v: unknown): number | undefined => (typeof v === 'number' ? v : undefined);

const initRows = (value: IapSection): IapRow[] => {
  const products = Array.isArray(value.products) ? (value.products as unknown[]).map(asRecord) : [];
  const priceById = new Map(products.map((p) => [String(p.id ?? ''), numOrUndef(p.usdCents)]));

  const ids = Object.keys(value).filter((k) => k !== 'products');
  for (const p of products) {
    const id = String(p.id ?? '');
    if (id && !ids.includes(id)) ids.push(id);
  }

  return ids.map((id, i) => {
    const reward = asRecord(value[id]);
    return {
      uid: i + 1,
      productId: id,
      diamonds: numOrUndef(reward.diamonds),
      tickets: numOrUndef(reward.tickets),
      vipDays: numOrUndef(reward.vipDays),
      usdCents: priceById.get(id),
    };
  });
};

/** Таблица IAP-продуктов: productId, награды (diamonds/tickets/vipDays) и цена usdCents (→ products[]). */
export default function IapEditor({ value, onChange }: Props) {
  // Исходное значение — для сохранения неизвестных (passthrough) полей продуктов
  const [original] = useState(value);
  const [rows, setRows] = useState<IapRow[]>(() => initRows(value));
  const nextUid = useRef(rows.length + 1);

  const build = (list: IapRow[]): IapSection => {
    const origProducts = Array.isArray(original.products)
      ? (original.products as unknown[]).map(asRecord)
      : [];
    const next: IapSection = {};
    const products: Record<string, unknown>[] = [];
    for (const r of list) {
      const id = r.productId.trim();
      if (!id) continue;
      const reward: Record<string, unknown> = { ...asRecord(original[id]) };
      for (const field of ['diamonds', 'tickets', 'vipDays'] as const) {
        if (typeof r[field] === 'number') reward[field] = r[field];
        else delete reward[field];
      }
      next[id] = reward;

      const origProd = origProducts.find((p) => String(p.id ?? '') === id) ?? {};
      const prod: Record<string, unknown> = { ...origProd, id };
      if (typeof r.usdCents === 'number') prod.usdCents = r.usdCents;
      else delete prod.usdCents;
      products.push(prod);
    }
    next.products = products;
    return next;
  };

  const update = (list: IapRow[]) => {
    setRows(list);
    onChange(build(list));
  };

  const patchRow = (uid: number, patch: Partial<IapRow>) =>
    update(rows.map((r) => (r.uid === uid ? { ...r, ...patch } : r)));

  const addRow = () => {
    update([...rows, { uid: nextUid.current++, productId: '' }]);
  };

  const numberCell = (field: 'diamonds' | 'tickets' | 'vipDays' | 'usdCents') =>
    function NumberCell(_: unknown, r: IapRow) {
      return (
        <InputNumber
          value={r[field]}
          min={0}
          precision={0}
          size="small"
          style={{ width: '100%' }}
          onChange={(v) => patchRow(r.uid, { [field]: typeof v === 'number' ? v : undefined })}
        />
      );
    };

  const columns: ColumnsType<IapRow> = [
    {
      title: 'productId',
      key: 'productId',
      render: (_: unknown, r: IapRow) => (
        <Input
          value={r.productId}
          size="small"
          placeholder="diamonds_20"
          status={r.productId.trim() ? undefined : 'error'}
          onChange={(e) => patchRow(r.uid, { productId: e.target.value })}
        />
      ),
    },
    { title: '💎 Алмазы', key: 'diamonds', width: 110, render: numberCell('diamonds') },
    { title: '🎟 Билеты', key: 'tickets', width: 100, render: numberCell('tickets') },
    { title: 'VIP, дней', key: 'vipDays', width: 100, render: numberCell('vipDays') },
    {
      title: 'Цена, ¢ USD',
      key: 'usdCents',
      width: 150,
      render: (_: unknown, r: IapRow) => (
        <div>
          {numberCell('usdCents')(_, r)}
          {typeof r.usdCents === 'number' && (
            <Text type="secondary" style={{ fontSize: 11 }}>= ${(r.usdCents / 100).toFixed(2)}</Text>
          )}
        </div>
      ),
    },
    {
      title: '',
      key: 'del',
      width: 44,
      render: (_: unknown, r: IapRow) => (
        <Popconfirm title={`Удалить продукт "${r.productId || '(без id)'}"?`} onConfirm={() => update(rows.filter((x) => x.uid !== r.uid))}>
          <Button icon={<DeleteOutlined />} size="small" danger />
        </Popconfirm>
      ),
    },
  ];

  return (
    <div>
      <Table
        columns={columns}
        dataSource={rows}
        rowKey="uid"
        size="small"
        pagination={false}
        locale={{ emptyText: 'Нет продуктов' }}
      />
      <Button icon={<PlusOutlined />} onClick={addRow} style={{ marginTop: 8 }}>
        Добавить продукт
      </Button>
    </div>
  );
}
