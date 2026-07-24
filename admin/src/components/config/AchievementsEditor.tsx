import { useRef, useState } from 'react';
import { Button, Input, InputNumber, Popconfirm, Table, Tooltip } from 'antd';
import { DeleteOutlined, PlusOutlined, QuestionCircleOutlined } from '@ant-design/icons';
import type { ColumnsType } from 'antd/es/table';

interface AchievementRow {
  uid: number;
  id: string;
  title: string;
  description: string;
  icon: string;
  diamondReward?: number;
  /** Неизвестные (passthrough) поля исходной записи */
  extras: Record<string, unknown>;
}

interface Props {
  value: unknown[];
  onChange: (next: unknown[]) => void;
}

const KNOWN = new Set(['id', 'title', 'description', 'icon', 'diamondReward']);

const initRows = (value: unknown[]): AchievementRow[] =>
  (Array.isArray(value) ? value : []).map((entry, i) => {
    const e = (entry && typeof entry === 'object' ? entry : {}) as Record<string, unknown>;
    const extras: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(e)) if (!KNOWN.has(k)) extras[k] = v;
    return {
      uid: i + 1,
      id: typeof e.id === 'string' ? e.id : '',
      title: typeof e.title === 'string' ? e.title : '',
      description: typeof e.description === 'string' ? e.description : '',
      icon: typeof e.icon === 'string' ? e.icon : '',
      diamondReward: typeof e.diamondReward === 'number' ? e.diamondReward : undefined,
      extras,
    };
  });

/**
 * Таблица ачивок. Отдельного поля «триггер» в схеме нет: триггером служит id
 * (клиент отслеживает события по фиксированному словарю id-ачивок).
 */
export default function AchievementsEditor({ value, onChange }: Props) {
  const [rows, setRows] = useState<AchievementRow[]>(() => initRows(value));
  const nextUid = useRef(rows.length + 1);

  const build = (list: AchievementRow[]): unknown[] =>
    list
      .filter((r) => r.id.trim())
      .map((r) => {
        const entry: Record<string, unknown> = { ...r.extras, id: r.id.trim() };
        if (r.title.trim()) entry.title = r.title;
        if (r.icon.trim()) entry.icon = r.icon;
        if (typeof r.diamondReward === 'number') entry.diamondReward = r.diamondReward;
        if (r.description.trim()) entry.description = r.description;
        return entry;
      });

  const update = (list: AchievementRow[]) => {
    setRows(list);
    onChange(build(list));
  };

  const patchRow = (uid: number, patch: Partial<AchievementRow>) =>
    update(rows.map((r) => (r.uid === uid ? { ...r, ...patch } : r)));

  const textCell = (field: 'id' | 'title' | 'description' | 'icon', placeholder: string) =>
    function TextCell(_: unknown, r: AchievementRow) {
      return (
        <Input
          value={r[field]}
          size="small"
          placeholder={placeholder}
          status={field === 'id' && !r.id.trim() ? 'error' : undefined}
          onChange={(e) => patchRow(r.uid, { [field]: e.target.value })}
        />
      );
    };

  const columns: ColumnsType<AchievementRow> = [
    {
      title: (
        <span>
          ID (триггер){' '}
          <Tooltip title="ID — ключ триггера: клиент начисляет ачивку по своему словарю событий, а награда берётся из этой таблицы по id.">
            <QuestionCircleOutlined />
          </Tooltip>
        </span>
      ),
      key: 'id',
      width: 170,
      render: textCell('id', 'first_story'),
    },
    { title: 'Название', key: 'title', width: 170, render: textCell('title', 'Первая история') },
    { title: 'Описание', key: 'description', render: textCell('description', 'Начни первую новеллу') },
    {
      title: (
        <span>
          Иконка{' '}
          <Tooltip title="Имя Material-иконки (auto_stories, favorite, …)">
            <QuestionCircleOutlined />
          </Tooltip>
        </span>
      ),
      key: 'icon',
      width: 140,
      render: textCell('icon', 'auto_stories'),
    },
    {
      title: '💎 Награда',
      key: 'diamondReward',
      width: 110,
      render: (_: unknown, r: AchievementRow) => (
        <InputNumber
          value={r.diamondReward}
          min={0}
          precision={0}
          size="small"
          style={{ width: '100%' }}
          onChange={(v) => patchRow(r.uid, { diamondReward: typeof v === 'number' ? v : undefined })}
        />
      ),
    },
    {
      title: '',
      key: 'del',
      width: 44,
      render: (_: unknown, r: AchievementRow) => (
        <Popconfirm title={`Удалить ачивку "${r.id || '(без id)'}"?`} onConfirm={() => update(rows.filter((x) => x.uid !== r.uid))}>
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
        locale={{ emptyText: 'Нет ачивок' }}
      />
      <Button
        icon={<PlusOutlined />}
        onClick={() => update([...rows, { uid: nextUid.current++, id: '', title: '', description: '', icon: '', extras: {} }])}
        style={{ marginTop: 8 }}
      >
        Добавить ачивку
      </Button>
    </div>
  );
}
