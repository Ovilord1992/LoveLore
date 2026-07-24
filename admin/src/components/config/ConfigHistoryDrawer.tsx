import { useCallback, useEffect, useState } from 'react';
import { Button, Drawer, Modal, Popconfirm, Space, Spin, Table, Typography, App as AntApp } from 'antd';
import { EyeOutlined, RollbackOutlined } from '@ant-design/icons';
import type { ColumnsType } from 'antd/es/table';
import api from '../../services/api';

const { Text } = Typography;

interface HistoryEntry {
  version: number;
  changedBy: string;
  createdAt: string;
}

interface Snapshot extends HistoryEntry {
  data: Record<string, unknown>;
}

interface Props {
  open: boolean;
  onClose: () => void;
  /** Вызывается после успешного отката — родитель перезагружает форму конфига */
  onRolledBack: () => void;
}

/** История версий конфига: список, просмотр снапшота, откат. */
export default function ConfigHistoryDrawer({ open, onClose, onRolledBack }: Props) {
  const [history, setHistory] = useState<HistoryEntry[]>([]);
  const [loading, setLoading] = useState(false);
  const [snapshot, setSnapshot] = useState<Snapshot | null>(null);
  const [snapshotLoading, setSnapshotLoading] = useState(false);
  const [rollingBack, setRollingBack] = useState<number | null>(null);
  const { message } = AntApp.useApp();

  const fetchHistory = useCallback(async () => {
    setLoading(true);
    try {
      const { data } = await api.get('/admin/config/history');
      setHistory(data.history);
    } catch (err: unknown) {
      const e = err as { response?: { data?: { error?: string } } };
      message.error(e.response?.data?.error || 'Ошибка загрузки истории конфига');
    } finally {
      setLoading(false);
    }
  }, [message]);

  useEffect(() => {
    if (open) fetchHistory();
  }, [open, fetchHistory]);

  const viewSnapshot = async (version: number) => {
    setSnapshotLoading(true);
    try {
      const { data } = await api.get(`/admin/config/history/${version}`);
      setSnapshot(data);
    } catch (err: unknown) {
      const e = err as { response?: { data?: { error?: string } } };
      message.error(e.response?.data?.error || 'Ошибка загрузки снапшота');
    } finally {
      setSnapshotLoading(false);
    }
  };

  const rollback = async (version: number) => {
    setRollingBack(version);
    try {
      const { data } = await api.post('/admin/config/rollback', { version });
      message.success(`Откат к v${data.rolledBackTo}: текущая версия теперь v${data.version}`);
      onRolledBack();
      fetchHistory();
    } catch (err: unknown) {
      const e = err as { response?: { data?: { error?: string } } };
      message.error(e.response?.data?.error || 'Ошибка отката');
    } finally {
      setRollingBack(null);
    }
  };

  const columns: ColumnsType<HistoryEntry> = [
    { title: 'Версия', dataIndex: 'version', key: 'version', width: 80, render: (v: number) => <Text strong>v{v}</Text> },
    {
      title: 'Кто',
      dataIndex: 'changedBy',
      key: 'changedBy',
      ellipsis: true,
      render: (v: string) => <Text style={{ fontSize: 12 }} title={v}>{v}</Text>,
    },
    {
      title: 'Когда',
      dataIndex: 'createdAt',
      key: 'createdAt',
      width: 150,
      render: (d: string) => new Date(d).toLocaleString('ru'),
    },
    {
      title: '',
      key: 'actions',
      width: 90,
      render: (_: unknown, r: HistoryEntry) => (
        <Space>
          <Button
            icon={<EyeOutlined />}
            size="small"
            title="Просмотр снапшота"
            loading={snapshotLoading && snapshot?.version !== r.version}
            onClick={() => viewSnapshot(r.version)}
          />
          <Popconfirm
            title={`Откатиться к v${r.version}?`}
            description="Текущий конфиг будет заменён этим снапшотом (с новой версией)."
            okText="Откатиться"
            cancelText="Отмена"
            onConfirm={() => rollback(r.version)}
          >
            <Button icon={<RollbackOutlined />} size="small" danger title="Откатиться" loading={rollingBack === r.version} />
          </Popconfirm>
        </Space>
      ),
    },
  ];

  return (
    <Drawer title="🕘 История конфига" open={open} onClose={onClose} width={640}>
      {loading ? (
        <Spin style={{ display: 'block', margin: '40px auto' }} />
      ) : (
        <Table
          columns={columns}
          dataSource={history}
          rowKey="version"
          size="small"
          pagination={{ pageSize: 15 }}
          locale={{ emptyText: 'История пуста' }}
        />
      )}

      <Modal
        title={snapshot ? `Снапшот v${snapshot.version} — ${new Date(snapshot.createdAt).toLocaleString('ru')}` : ''}
        open={!!snapshot}
        onCancel={() => setSnapshot(null)}
        footer={[
          <Popconfirm
            key="rollback"
            title={`Откатиться к v${snapshot?.version}?`}
            description="Текущий конфиг будет заменён этим снапшотом (с новой версией)."
            okText="Откатиться"
            cancelText="Отмена"
            onConfirm={() => {
              if (snapshot) {
                rollback(snapshot.version);
                setSnapshot(null);
              }
            }}
          >
            <Button danger icon={<RollbackOutlined />}>Откатиться к этой версии</Button>
          </Popconfirm>,
          <Button key="close" onClick={() => setSnapshot(null)}>Закрыть</Button>,
        ]}
        width={760}
      >
        <pre
          style={{
            maxHeight: '60vh',
            overflow: 'auto',
            background: '#f6f6f6',
            padding: 12,
            borderRadius: 6,
            fontSize: 12,
            margin: 0,
          }}
        >
          {snapshot ? JSON.stringify(snapshot.data, null, 2) : ''}
        </pre>
      </Modal>
    </Drawer>
  );
}
