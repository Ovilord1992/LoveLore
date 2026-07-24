import { useState } from 'react';
import { Button, Input, Popconfirm, Select, Space, Table, Typography, App as AntApp } from 'antd';
import { DeleteOutlined, PlusOutlined } from '@ant-design/icons';
import type { ColumnsType } from 'antd/es/table';

const { Text } = Typography;

export type LocalizationSection = Record<string, Record<string, string>>;

interface KvRow {
  uid: number;
  k: string;
  v: string;
}

interface Props {
  value: LocalizationSection;
  onChange: (next: LocalizationSection) => void;
}

const toRows = (dict: Record<string, string> | undefined, startUid: number): KvRow[] =>
  Object.entries(dict ?? {}).map(([k, v], i) => ({ uid: startUid + i, k, v: String(v) }));

const rowsToDict = (rows: KvRow[]): Record<string, string> => {
  const dict: Record<string, string> = {};
  for (const r of rows) {
    const key = r.k.trim();
    if (key) dict[key] = r.v;
  }
  return dict;
};

// Сквозной счётчик uid строк (модульный — чтобы не читать ref во время рендера)
let uidSeq = 1;
const takeUids = (n: number) => {
  const start = uidSeq;
  uidSeq += n;
  return start;
};

/** Редактор локализации: выбор языка → таблица ключ/значение, добавление/удаление языков и строк. */
export default function LocalizationEditor({ value, onChange }: Props) {
  const { message } = AntApp.useApp();

  const [data, setData] = useState<LocalizationSection>(() => ({ ...value }));
  const [lang, setLang] = useState<string>(() => Object.keys(value)[0] ?? '');
  const [rows, setRows] = useState<KvRow[]>(() => {
    const dict = value[Object.keys(value)[0] ?? ''] ?? {};
    return toRows(dict, takeUids(Object.keys(dict).length));
  });
  const [newLang, setNewLang] = useState('');

  const commit = (nextRows: KvRow[], targetLang = lang) => {
    const nextData = { ...data, [targetLang]: rowsToDict(nextRows) };
    setRows(nextRows);
    setData(nextData);
    onChange(nextData);
  };

  const switchLang = (next: string) => {
    setLang(next);
    const dict = data[next] ?? {};
    setRows(toRows(dict, takeUids(Object.keys(dict).length)));
  };

  const addLanguage = () => {
    const code = newLang.trim().toLowerCase();
    if (!code) return;
    if (data[code]) {
      message.warning(`Язык "${code}" уже есть`);
      switchLang(code);
      setNewLang('');
      return;
    }
    // Новый язык наследует ключи текущего — переводчику остаётся заменить значения
    const template = lang ? { ...(data[lang] ?? {}) } : {};
    const nextData = { ...data, [code]: template };
    setData(nextData);
    onChange(nextData);
    setLang(code);
    setRows(toRows(template, takeUids(Object.keys(template).length)));
    setNewLang('');
  };

  const removeLanguage = () => {
    if (!lang) return;
    const nextData = { ...data };
    delete nextData[lang];
    setData(nextData);
    onChange(nextData);
    const next = Object.keys(nextData)[0] ?? '';
    setLang(next);
    const dict = nextData[next] ?? {};
    setRows(toRows(dict, takeUids(Object.keys(dict).length)));
  };

  const patchRow = (uid: number, patch: Partial<KvRow>) =>
    commit(rows.map((r) => (r.uid === uid ? { ...r, ...patch } : r)));

  const columns: ColumnsType<KvRow> = [
    {
      title: 'Ключ',
      key: 'k',
      width: 240,
      render: (_: unknown, r: KvRow) => (
        <Input
          value={r.k}
          size="small"
          placeholder="btn_play"
          status={r.k.trim() ? undefined : 'error'}
          onChange={(e) => patchRow(r.uid, { k: e.target.value })}
        />
      ),
    },
    {
      title: 'Значение',
      key: 'v',
      render: (_: unknown, r: KvRow) => (
        <Input
          value={r.v}
          size="small"
          placeholder="Начать историю"
          onChange={(e) => patchRow(r.uid, { v: e.target.value })}
        />
      ),
    },
    {
      title: '',
      key: 'del',
      width: 44,
      render: (_: unknown, r: KvRow) => (
        <Button icon={<DeleteOutlined />} size="small" danger onClick={() => commit(rows.filter((x) => x.uid !== r.uid))} />
      ),
    },
  ];

  return (
    <Space direction="vertical" style={{ width: '100%' }}>
      <Space wrap>
        <Text>Язык:</Text>
        <Select
          value={lang || undefined}
          onChange={switchLang}
          style={{ width: 110 }}
          placeholder="—"
          options={Object.keys(data).map((l) => ({ value: l, label: l }))}
        />
        {lang && (
          <Popconfirm title={`Удалить язык "${lang}" со всеми строками?`} onConfirm={removeLanguage}>
            <Button icon={<DeleteOutlined />} danger size="small">Удалить язык</Button>
          </Popconfirm>
        )}
        <Input
          value={newLang}
          onChange={(e) => setNewLang(e.target.value)}
          placeholder="код: en, es…"
          size="small"
          style={{ width: 110 }}
          maxLength={8}
          onPressEnter={addLanguage}
        />
        <Button icon={<PlusOutlined />} size="small" onClick={addLanguage} disabled={!newLang.trim()}>
          Добавить язык
        </Button>
      </Space>
      {lang ? (
        <>
          <Table
            columns={columns}
            dataSource={rows}
            rowKey="uid"
            size="small"
            pagination={false}
            locale={{ emptyText: 'Нет строк' }}
          />
          <Button icon={<PlusOutlined />} onClick={() => commit([...rows, { uid: takeUids(1), k: '', v: '' }])}>
            Добавить строку
          </Button>
        </>
      ) : (
        <Text type="secondary">Нет языков — добавьте первый.</Text>
      )}
    </Space>
  );
}
