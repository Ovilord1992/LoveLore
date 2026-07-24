import { Button, Input, Table, Tooltip, Typography } from 'antd';
import { DeleteOutlined, PlusOutlined, QuestionCircleOutlined } from '@ant-design/icons';
import type { ColumnsType } from 'antd/es/table';
import { type OverrideRow, takeOverrideUid } from './overrides';

const { Text } = Typography;

interface Props {
  rows: OverrideRow[];
  onChange: (next: OverrideRow[]) => void;
}

/**
 * Контролируемый список overrides «dot-путь → значение».
 * Состояние держит родительский редактор (Experiments/Segments) — здесь только UI.
 */
export default function OverridesEditor({ rows, onChange }: Props) {
  const patchRow = (uid: number, patch: Partial<OverrideRow>) =>
    onChange(rows.map((r) => (r.uid === uid ? { ...r, ...patch } : r)));

  const columns: ColumnsType<OverrideRow> = [
    {
      title: (
        <span>
          Путь (dot){' '}
          <Tooltip title="Плоский dot-путь внутри секций конфига, например economy.premiumChoiceBaseCost или ads.maxAdsPerDay. Значение заменяется целиком.">
            <QuestionCircleOutlined />
          </Tooltip>
        </span>
      ),
      key: 'k',
      width: '45%',
      render: (_: unknown, r: OverrideRow) => (
        <Input
          value={r.k}
          size="small"
          placeholder="economy.premiumChoiceBaseCost"
          status={r.k.trim() ? undefined : 'error'}
          onChange={(e) => patchRow(r.uid, { k: e.target.value })}
        />
      ),
    },
    {
      title: (
        <span>
          Значение{' '}
          <Tooltip title={'Числа и true/false распознаются автоматически. Чтобы задать строку «true» или «42» — возьмите её в кавычки: "true". Допустим и JSON (объект/массив).'}>
            <QuestionCircleOutlined />
          </Tooltip>
        </span>
      ),
      key: 'v',
      render: (_: unknown, r: OverrideRow) => (
        <Input
          value={r.v}
          size="small"
          placeholder="10"
          onChange={(e) => patchRow(r.uid, { v: e.target.value })}
        />
      ),
    },
    {
      title: '',
      key: 'del',
      width: 44,
      render: (_: unknown, r: OverrideRow) => (
        <Button icon={<DeleteOutlined />} size="small" danger onClick={() => onChange(rows.filter((x) => x.uid !== r.uid))} />
      ),
    },
  ];

  return (
    <div>
      {rows.length > 0 ? (
        <Table columns={columns} dataSource={rows} rowKey="uid" size="small" pagination={false} />
      ) : (
        <Text type="secondary" style={{ display: 'block', marginBottom: 4 }}>Нет overrides — значения берутся из базового конфига.</Text>
      )}
      <Button
        icon={<PlusOutlined />}
        size="small"
        style={{ marginTop: rows.length > 0 ? 8 : 0 }}
        onClick={() => onChange([...rows, { uid: takeOverrideUid(), k: '', v: '' }])}
      >
        Добавить override
      </Button>
    </div>
  );
}
