import { useEffect, useState } from 'react';
import { Card, Col, Row, Statistic, Typography } from 'antd';
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

  useEffect(() => {
    api.get('/admin/stats').then((r) => setStats(r.data));
  }, []);

  if (!stats) return null;

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
