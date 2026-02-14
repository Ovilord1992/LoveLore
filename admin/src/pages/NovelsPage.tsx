import { useEffect, useState, useCallback } from 'react';
import { Table, Input, Button, Space, Switch, Typography, App as AntApp, Popconfirm, Upload } from 'antd';
import { SearchOutlined, UploadOutlined, DeleteOutlined } from '@ant-design/icons';
import type { ColumnsType, TablePaginationConfig } from 'antd/es/table';
import type { UploadProps } from 'antd';
import api from '../services/api';

const { Title } = Typography;

interface NovelRow {
  id: string;
  title: string;
  author: string;
  version: number;
  chaptersCount: number;
  downloads: number;
  isPublished: boolean;
  fileSize: number;
  updatedAt: string;
}

export default function NovelsPage() {
  const [novels, setNovels] = useState<NovelRow[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(false);
  const { message } = AntApp.useApp();

  const fetchNovels = useCallback(async () => {
    setLoading(true);
    try {
      const { data } = await api.get('/admin/novels', { params: { page, limit: 20, search } });
      setNovels(data.novels);
      setTotal(data.total);
    } finally {
      setLoading(false);
    }
  }, [page, search]);

  useEffect(() => { fetchNovels(); }, [fetchNovels]);

  const togglePublish = async (id: string, current: boolean) => {
    try {
      await api.patch(`/admin/novels/${id}`, { isPublished: !current });
      message.success(!current ? 'Новелла опубликована' : 'Новелла скрыта');
      fetchNovels();
    } catch {
      message.error('Ошибка обновления');
    }
  };

  const deleteNovel = async (id: string) => {
    try {
      await api.delete(`/novels/${id}`);
      message.success('Новелла удалена');
      fetchNovels();
    } catch {
      message.error('Ошибка удаления');
    }
  };

  const uploadProps: UploadProps = {
    name: 'file',
    action: `${api.defaults.baseURL}/novels/upload`,
    headers: { Authorization: `Bearer ${localStorage.getItem('admin_token') || ''}` },
    accept: '.zip',
    showUploadList: false,
    onChange(info) {
      if (info.file.status === 'done') {
        message.success(`${info.file.response?.novel?.title || 'Новелла'} загружена`);
        fetchNovels();
      } else if (info.file.status === 'error') {
        message.error('Ошибка загрузки');
      }
    },
  };

  const formatSize = (bytes: number) => {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  };

  const columns: ColumnsType<NovelRow> = [
    { title: 'Название', dataIndex: 'title', key: 'title' },
    { title: 'Автор', dataIndex: 'author', key: 'author' },
    { title: 'v', dataIndex: 'version', key: 'version', width: 50 },
    { title: 'Глав', dataIndex: 'chaptersCount', key: 'chapters', width: 60 },
    { title: 'Загрузок', dataIndex: 'downloads', key: 'downloads', width: 90 },
    {
      title: 'Размер', dataIndex: 'fileSize', key: 'fileSize', width: 90,
      render: (s: number) => formatSize(s),
    },
    {
      title: 'Статус', key: 'published', width: 100,
      render: (_: unknown, r: NovelRow) => (
        <Switch
          checked={r.isPublished}
          checkedChildren="Pub"
          unCheckedChildren="Off"
          onChange={() => togglePublish(r.id, r.isPublished)}
        />
      ),
    },
    {
      title: 'Обновлена', dataIndex: 'updatedAt', key: 'updatedAt',
      render: (d: string) => new Date(d).toLocaleDateString('ru'),
    },
    {
      title: '', key: 'actions', width: 50,
      render: (_: unknown, r: NovelRow) => (
        <Popconfirm title="Удалить новеллу?" onConfirm={() => deleteNovel(r.id)}>
          <Button icon={<DeleteOutlined />} size="small" danger />
        </Popconfirm>
      ),
    },
  ];

  const handleTableChange = (pagination: TablePaginationConfig) => {
    setPage(pagination.current || 1);
  };

  return (
    <div>
      <Space style={{ marginBottom: 16, width: '100%', justifyContent: 'space-between' }}>
        <Title level={3} style={{ margin: 0 }}>Новеллы</Title>
        <Upload {...uploadProps}>
          <Button icon={<UploadOutlined />} type="primary">Загрузить ZIP</Button>
        </Upload>
      </Space>
      <Input
        prefix={<SearchOutlined />}
        placeholder="Поиск по названию или автору..."
        value={search}
        onChange={(e) => { setSearch(e.target.value); setPage(1); }}
        style={{ marginBottom: 16, maxWidth: 400 }}
        allowClear
      />
      <Table
        columns={columns}
        dataSource={novels}
        rowKey="id"
        loading={loading}
        pagination={{ current: page, total, pageSize: 20 }}
        onChange={handleTableChange}
      />
    </div>
  );
}
