import { useEffect, useState, useCallback, useRef } from 'react';
import { Table, Input, Button, Tag, Space, Modal, Descriptions, Typography, InputNumber, Select, App as AntApp, Popconfirm } from 'antd';
import { SearchOutlined, EyeOutlined, DeleteOutlined, EditOutlined } from '@ant-design/icons';
import type { ColumnsType, TablePaginationConfig } from 'antd/es/table';
import api from '../services/api';

const { Title } = Typography;

interface UserRow {
  id: string;
  email: string;
  displayName: string;
  role: string;
  createdAt: string;
  _count: { saves: number };
}

interface UserDetail {
  id: string;
  email: string;
  displayName: string;
  role: string;
  createdAt: string;
  profile: { diamonds?: number; tickets?: number; totalNovelsStarted?: number; totalChaptersRead?: number } | null;
  currency: { diamonds: number; tickets: number } | null;
  saves: { id: string; novelId: string; updatedAt: string }[];
}

export default function UsersPage() {
  const [users, setUsers] = useState<UserRow[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  const [debouncedSearch, setDebouncedSearch] = useState('');
  const [loading, setLoading] = useState(false);
  const [detail, setDetail] = useState<UserDetail | null>(null);
  const [detailOpen, setDetailOpen] = useState(false);
  const [editOpen, setEditOpen] = useState(false);
  const [editForm, setEditForm] = useState({ role: '', diamonds: 0, tickets: 0 });
  const reqId = useRef(0);
  const { message } = AntApp.useApp();

  // Debounce поля поиска
  useEffect(() => {
    const t = setTimeout(() => { setDebouncedSearch(search); setPage(1); }, 350);
    return () => clearTimeout(t);
  }, [search]);

  const fetchUsers = useCallback(async () => {
    const myId = ++reqId.current; // защита от гонок
    setLoading(true);
    try {
      const { data } = await api.get('/admin/users', { params: { page, limit: 20, search: debouncedSearch } });
      if (myId !== reqId.current) return;
      setUsers(data.users);
      setTotal(data.total);
    } catch (err: unknown) {
      if (myId !== reqId.current) return;
      const e = err as { response?: { data?: { error?: string } } };
      message.error(e.response?.data?.error || 'Ошибка загрузки пользователей');
    } finally {
      if (myId === reqId.current) setLoading(false);
    }
  }, [page, debouncedSearch, message]);

  useEffect(() => { fetchUsers(); }, [fetchUsers]);

  const showDetail = async (id: string) => {
    try {
      const { data } = await api.get(`/admin/users/${id}`);
      setDetail(data.user);
      setDetailOpen(true);
    } catch (err: unknown) {
      const e = err as { response?: { data?: { error?: string } } };
      message.error(e.response?.data?.error || 'Ошибка загрузки пользователя');
    }
  };

  const openEdit = async (id: string) => {
    try {
      const { data } = await api.get(`/admin/users/${id}`);
      const u = data.user as UserDetail;
      setDetail(u);
      setEditForm({
        role: u.role,
        diamonds: u.currency?.diamonds || 0,
        tickets: u.currency?.tickets || 0,
      });
      setEditOpen(true);
    } catch (err: unknown) {
      const e = err as { response?: { data?: { error?: string } } };
      message.error(e.response?.data?.error || 'Ошибка загрузки пользователя');
    }
  };

  const saveEdit = async () => {
    if (!detail) return;
    try {
      await api.patch(`/admin/users/${detail.id}`, editForm);
      message.success('Пользователь обновлён');
      setEditOpen(false);
      fetchUsers();
    } catch {
      message.error('Ошибка обновления');
    }
  };

  const deleteUser = async (id: string) => {
    try {
      await api.delete(`/admin/users/${id}`);
      message.success('Пользователь удалён');
      fetchUsers();
    } catch (err: unknown) {
      const error = err as { response?: { data?: { error?: string } } };
      message.error(error.response?.data?.error || 'Ошибка удаления');
    }
  };

  const columns: ColumnsType<UserRow> = [
    { title: 'Email', dataIndex: 'email', key: 'email' },
    { title: 'Имя', dataIndex: 'displayName', key: 'displayName' },
    {
      title: 'Роль', dataIndex: 'role', key: 'role',
      render: (role: string) => <Tag color={role === 'admin' ? 'red' : 'blue'}>{role}</Tag>,
    },
    {
      title: 'Сохранений', key: 'saves',
      render: (_: unknown, r: UserRow) => r._count.saves,
    },
    {
      title: 'Регистрация', dataIndex: 'createdAt', key: 'createdAt',
      render: (d: string) => new Date(d).toLocaleDateString('ru'),
    },
    {
      title: 'Действия', key: 'actions',
      render: (_: unknown, r: UserRow) => (
        <Space>
          <Button icon={<EyeOutlined />} size="small" onClick={() => showDetail(r.id)} />
          <Button icon={<EditOutlined />} size="small" onClick={() => openEdit(r.id)} />
          <Popconfirm title="Удалить пользователя?" onConfirm={() => deleteUser(r.id)}>
            <Button icon={<DeleteOutlined />} size="small" danger />
          </Popconfirm>
        </Space>
      ),
    },
  ];

  const handleTableChange = (pagination: TablePaginationConfig) => {
    setPage(pagination.current || 1);
  };

  return (
    <div>
      <Title level={3}>Пользователи</Title>
      <Input
        prefix={<SearchOutlined />}
        placeholder="Поиск по email или имени..."
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        style={{ marginBottom: 16, maxWidth: 400 }}
        allowClear
      />
      <Table
        columns={columns}
        dataSource={users}
        rowKey="id"
        loading={loading}
        pagination={{ current: page, total, pageSize: 20 }}
        onChange={handleTableChange}
      />

      {/* Детали */}
      <Modal title="Детали пользователя" open={detailOpen} onCancel={() => setDetailOpen(false)} footer={null} width={600}>
        {detail && (
          <Descriptions column={1} bordered size="small">
            <Descriptions.Item label="ID">{detail.id}</Descriptions.Item>
            <Descriptions.Item label="Email">{detail.email}</Descriptions.Item>
            <Descriptions.Item label="Имя">{detail.displayName}</Descriptions.Item>
            <Descriptions.Item label="Роль"><Tag color={detail.role === 'admin' ? 'red' : 'blue'}>{detail.role}</Tag></Descriptions.Item>
            <Descriptions.Item label="💎 Алмазы">{detail.currency?.diamonds ?? 0}</Descriptions.Item>
            <Descriptions.Item label="🎟 Билеты">{detail.currency?.tickets ?? 0}</Descriptions.Item>
            <Descriptions.Item label="Сохранений">{detail.saves.length}</Descriptions.Item>
            <Descriptions.Item label="Регистрация">{new Date(detail.createdAt).toLocaleString('ru')}</Descriptions.Item>
          </Descriptions>
        )}
      </Modal>

      {/* Редактирование */}
      <Modal title="Редактировать пользователя" open={editOpen} onCancel={() => setEditOpen(false)} onOk={saveEdit}>
        {detail && (
          <Space direction="vertical" style={{ width: '100%' }}>
            <div>Email: <strong>{detail.email}</strong></div>
            <div>
              Роль:
              <Select value={editForm.role} onChange={(v) => setEditForm({ ...editForm, role: v })} style={{ width: 120, marginLeft: 8 }}>
                <Select.Option value="user">user</Select.Option>
                <Select.Option value="admin">admin</Select.Option>
              </Select>
            </div>
            <div>
              💎 Алмазы:
              <InputNumber value={editForm.diamonds} onChange={(v) => setEditForm({ ...editForm, diamonds: v || 0 })} min={0} style={{ marginLeft: 8 }} />
            </div>
            <div>
              🎟 Билеты:
              <InputNumber value={editForm.tickets} onChange={(v) => setEditForm({ ...editForm, tickets: v || 0 })} min={0} style={{ marginLeft: 8 }} />
            </div>
          </Space>
        )}
      </Modal>
    </div>
  );
}
