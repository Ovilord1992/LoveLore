import { useEffect, useState, useCallback } from 'react';
import { Table, Tag, Space, Button, Select, Typography, Popconfirm, App as AntApp } from 'antd';
import { CheckOutlined, CloseOutlined, DeleteOutlined } from '@ant-design/icons';
import type { ColumnsType, TablePaginationConfig } from 'antd/es/table';
import { getReviews, approveReview, rejectReview, deleteReview } from '../services/api';

const { Title } = Typography;

interface ReviewRow {
  id: string;
  text: string;
  status: string;
  createdAt: string;
  user: { email: string };
  novel: { title: string };
}

const statusColors: Record<string, string> = {
  pending: 'gold',
  approved: 'green',
  rejected: 'red',
};

export default function ReviewsPage() {
  const [reviews, setReviews] = useState<ReviewRow[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [statusFilter, setStatusFilter] = useState<string>('all');
  const [loading, setLoading] = useState(false);
  const { message } = AntApp.useApp();

  const fetchReviews = useCallback(async () => {
    setLoading(true);
    try {
      const params: { page: number; limit: number; status?: string } = { page, limit: 10 };
      if (statusFilter !== 'all') params.status = statusFilter;
      const { data } = await getReviews(params);
      setReviews(data.items);
      setTotal(data.total);
    } finally {
      setLoading(false);
    }
  }, [page, statusFilter]);

  useEffect(() => { fetchReviews(); }, [fetchReviews]);

  const handleApprove = async (id: string) => {
    try {
      await approveReview(id);
      message.success('Отзыв одобрен');
      fetchReviews();
    } catch {
      message.error('Ошибка одобрения');
    }
  };

  const handleReject = async (id: string) => {
    try {
      await rejectReview(id);
      message.success('Отзыв отклонён');
      fetchReviews();
    } catch {
      message.error('Ошибка отклонения');
    }
  };

  const handleDelete = async (id: string) => {
    try {
      await deleteReview(id);
      message.success('Отзыв удалён');
      fetchReviews();
    } catch {
      message.error('Ошибка удаления');
    }
  };

  const columns: ColumnsType<ReviewRow> = [
    {
      title: 'Новелла', key: 'novel',
      render: (_: unknown, r: ReviewRow) => r.novel?.title,
    },
    {
      title: 'Email', key: 'user',
      render: (_: unknown, r: ReviewRow) => r.user?.email,
    },
    {
      title: 'Отзыв', dataIndex: 'text', key: 'text',
      ellipsis: true,
    },
    {
      title: 'Статус', dataIndex: 'status', key: 'status',
      render: (status: string) => <Tag color={statusColors[status] || 'default'}>{status}</Tag>,
    },
    {
      title: 'Дата', dataIndex: 'createdAt', key: 'createdAt',
      render: (d: string) => new Date(d).toLocaleDateString('ru'),
    },
    {
      title: 'Действия', key: 'actions',
      render: (_: unknown, r: ReviewRow) => (
        <Space>
          <Button icon={<CheckOutlined />} size="small" onClick={() => handleApprove(r.id)} title="Одобрить" />
          <Button icon={<CloseOutlined />} size="small" onClick={() => handleReject(r.id)} title="Отклонить" />
          <Popconfirm title="Удалить отзыв?" onConfirm={() => handleDelete(r.id)}>
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
      <Title level={3}>Отзывы</Title>
      <Select
        value={statusFilter}
        onChange={(v) => { setStatusFilter(v); setPage(1); }}
        style={{ marginBottom: 16, width: 200 }}
      >
        <Select.Option value="all">Все</Select.Option>
        <Select.Option value="pending">Ожидающие</Select.Option>
        <Select.Option value="approved">Одобренные</Select.Option>
        <Select.Option value="rejected">Отклонённые</Select.Option>
      </Select>
      <Table
        columns={columns}
        dataSource={reviews}
        rowKey="id"
        loading={loading}
        pagination={{ current: page, total, pageSize: 10 }}
        onChange={handleTableChange}
      />
    </div>
  );
}
