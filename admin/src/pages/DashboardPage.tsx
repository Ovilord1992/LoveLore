import { useEffect, useState } from 'react';
import { Card, Col, Row, Statistic, Typography, message, Spin, Empty } from 'antd';
import { UserOutlined, BookOutlined, DownloadOutlined } from '@ant-design/icons';
import api from '../services/api';

const { Title } = Typography;

interface Stats {
  totalUsers: number;
  totalNovels: number;
  totalDownloads: number;
  active: { day: number; week: number; month: number };
}

export default function DashboardPage() {
  const [stats, setStats] = useState<Stats | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    setLoading(true);
    api
      .get('/admin/stats')
      .then((r) => setStats(r.data))
      .catch((err) => {
        message.error('Не удалось загрузить статистику');
        console.error(err);
      })
      .finally(() => setLoading(false));
  }, []);

  if (loading) {
    return <Spin size="large" style={{ display: 'block', margin: '100px auto' }} />;
  }

  if (!stats) {
    return (
      <div>
        <Title level={3}>Дашборд</Title>
        <Empty description="Нет данных" />
      </div>
    );
  }

  return (
    <div>
      <Title level={3}>Дашборд</Title>
      <Row gutter={[16, 16]}>
        <Col xs={24} sm={8}>
          <Card><Statistic title="Пользователей" value={stats.totalUsers} prefix={<UserOutlined />} /></Card>
        </Col>
        <Col xs={24} sm={8}>
          <Card><Statistic title="Новелл" value={stats.totalNovels} prefix={<BookOutlined />} /></Card>
        </Col>
        <Col xs={24} sm={8}>
          <Card><Statistic title="Загрузок" value={stats.totalDownloads} prefix={<DownloadOutlined />} /></Card>
        </Col>
      </Row>
      <Row gutter={[16, 16]} style={{ marginTop: 16 }}>
        <Col xs={24} sm={8}>
          <Card><Statistic title="Активных за 24ч" value={stats.active.day} /></Card>
        </Col>
        <Col xs={24} sm={8}>
          <Card><Statistic title="Активных за 7д" value={stats.active.week} /></Card>
        </Col>
        <Col xs={24} sm={8}>
          <Card><Statistic title="Активных за 30д" value={stats.active.month} /></Card>
        </Col>
      </Row>
    </div>
  );
}
