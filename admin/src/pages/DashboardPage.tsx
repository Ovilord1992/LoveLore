import { lazy, Suspense, useEffect, useState } from 'react';
import { Card, Col, Row, Segmented, Statistic, Table, Typography, App as AntApp, Spin, Empty } from 'antd';
import { UserOutlined, BookOutlined, DownloadOutlined, DollarOutlined, TeamOutlined } from '@ant-design/icons';
import type { ColumnsType } from 'antd/es/table';
import api from '../services/api';

// Библиотека графиков тяжёлая — грузим отдельным чанком только на дашборде
const Line = lazy(() => import('@ant-design/plots').then((m) => ({ default: m.Line })));
const Column = lazy(() => import('@ant-design/plots').then((m) => ({ default: m.Column })));

const { Title } = Typography;

interface Stats {
  totalUsers: number;
  totalNovels: number;
  totalDownloads: number;
  active: { day: number; week: number; month: number };
}

interface DatedCount { date: string; count: number }
interface DatedRevenue { date: string; usdCents: number }
interface TopNovel { id: string; title: string; chapterCompletes: number }

interface Summary {
  dau: DatedCount[];
  wau: number;
  mau: number;
  newUsers: DatedCount[];
  revenueEstimateUsdCents: number;
  revenueByDay: DatedRevenue[];
  topNovels: TopNovel[];
}

// Палитра (валидирована на белой поверхности): одна серия — один цвет
const COLOR_DAU = '#2a78d6';
const COLOR_NEW_USERS = '#4a3aa7';
const COLOR_REVENUE = '#008300';
const INK_MUTED = '#898781';

/** Дни без событий в ответе отсутствуют — дополняем нулями весь период */
const fillDays = <T,>(rows: { date: string }[], days: number, pick: (r?: { date: string }) => T): (T & { date: string })[] => {
  const byDate = new Map(rows.map((r) => [r.date, r]));
  const out: (T & { date: string })[] = [];
  const now = new Date();
  for (let i = days - 1; i >= 0; i--) {
    const d = new Date(now.getTime() - i * 24 * 60 * 60 * 1000);
    const key = d.toISOString().slice(0, 10);
    out.push({ ...pick(byDate.get(key)), date: key });
  }
  return out;
};

const shortDate = (iso: string) => `${iso.slice(8, 10)}.${iso.slice(5, 7)}`;

const usd = (cents: number) => `$${(cents / 100).toFixed(2)}`;

export default function DashboardPage() {
  const [stats, setStats] = useState<Stats | null>(null);
  const [summary, setSummary] = useState<Summary | null>(null);
  const [loading, setLoading] = useState(true);
  const [summaryLoading, setSummaryLoading] = useState(true);
  const [days, setDays] = useState(30);
  const { message } = AntApp.useApp();

  useEffect(() => {
    let active = true;
    const load = async () => {
      try {
        const { data } = await api.get('/admin/stats');
        if (active) setStats(data);
      } catch (err: unknown) {
        if (!active) return;
        const e = err as { response?: { data?: { error?: string } } };
        message.error(e.response?.data?.error || 'Не удалось загрузить статистику');
      } finally {
        if (active) setLoading(false);
      }
    };
    load();
    return () => { active = false; };
  }, [message]);

  useEffect(() => {
    let active = true;
    const load = async () => {
      setSummaryLoading(true);
      try {
        const { data } = await api.get('/admin/analytics/summary', { params: { days } });
        if (active) setSummary(data);
      } catch (err: unknown) {
        if (!active) return;
        const e = err as { response?: { data?: { error?: string } } };
        message.error(e.response?.data?.error || 'Не удалось загрузить аналитику');
      } finally {
        if (active) setSummaryLoading(false);
      }
    };
    load();
    return () => { active = false; };
  }, [days, message]);

  if (loading) {
    return <Spin size="large" style={{ display: 'block', margin: '100px auto' }} />;
  }

  const dauData = summary ? fillDays(summary.dau, days, (r) => ({ count: (r as DatedCount | undefined)?.count ?? 0 })) : [];
  const newUsersData = summary ? fillDays(summary.newUsers, days, (r) => ({ count: (r as DatedCount | undefined)?.count ?? 0 })) : [];
  const revenueData = summary
    ? fillDays(summary.revenueByDay, days, (r) => ({ usd: ((r as DatedRevenue | undefined)?.usdCents ?? 0) / 100 }))
    : [];

  const axisX = {
    labelFormatter: shortDate,
    labelFill: INK_MUTED,
    line: false,
    tickLength: 0,
  };
  const axisY = { labelFill: INK_MUTED, tickLength: 0 };

  const topColumns: ColumnsType<TopNovel> = [
    { title: 'Новелла', dataIndex: 'title', key: 'title' },
    { title: 'ID', dataIndex: 'id', key: 'id', width: 180, ellipsis: true },
    {
      title: 'Завершений глав',
      dataIndex: 'chapterCompletes',
      key: 'chapterCompletes',
      width: 160,
      align: 'right' as const,
      sorter: (a, b) => a.chapterCompletes - b.chapterCompletes,
      defaultSortOrder: 'descend' as const,
    },
  ];

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
        <Title level={3} style={{ margin: 0 }}>Дашборд</Title>
        <Segmented
          value={days}
          onChange={(v) => setDays(v as number)}
          options={[
            { label: '7 дней', value: 7 },
            { label: '30 дней', value: 30 },
            { label: '90 дней', value: 90 },
          ]}
        />
      </div>

      {stats ? (
        <>
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
        </>
      ) : (
        <Empty description="Нет данных статистики" />
      )}

      <Spin spinning={summaryLoading}>
        <Row gutter={[16, 16]} style={{ marginTop: 16 }}>
          <Col xs={24} sm={8}>
            <Card>
              <Statistic title="WAU (по событиям)" value={summary?.wau ?? 0} prefix={<TeamOutlined />} />
            </Card>
          </Col>
          <Col xs={24} sm={8}>
            <Card>
              <Statistic title="MAU (по событиям)" value={summary?.mau ?? 0} prefix={<TeamOutlined />} />
            </Card>
          </Col>
          <Col xs={24} sm={8}>
            <Card>
              <Statistic
                title={`Выручка за ${days} дн. (оценка)`}
                value={(summary?.revenueEstimateUsdCents ?? 0) / 100}
                precision={2}
                prefix={<DollarOutlined />}
              />
            </Card>
          </Col>
        </Row>

        <Suspense fallback={<Spin style={{ display: 'block', margin: '48px auto' }} />}>
        <Row gutter={[16, 16]} style={{ marginTop: 16 }}>
          <Col xs={24}>
            <Card title="DAU — уникальные пользователи по дням">
              <Line
                data={dauData}
                xField="date"
                yField="count"
                height={260}
                style={{ stroke: COLOR_DAU, lineWidth: 2 }}
                axis={{ x: axisX, y: axisY }}
                tooltip={{ title: (d: { date: string }) => shortDate(d.date), items: [{ field: 'count', name: 'DAU' }] }}
              />
            </Card>
          </Col>
        </Row>

        <Row gutter={[16, 16]} style={{ marginTop: 16 }}>
          <Col xs={24} lg={12}>
            <Card title="Новые пользователи по дням">
              <Column
                data={newUsersData}
                xField="date"
                yField="count"
                height={240}
                style={{ fill: COLOR_NEW_USERS, radiusTopLeft: 4, radiusTopRight: 4 }}
                axis={{ x: axisX, y: axisY }}
                tooltip={{ title: (d: { date: string }) => shortDate(d.date), items: [{ field: 'count', name: 'Регистрации' }] }}
              />
            </Card>
          </Col>
          <Col xs={24} lg={12}>
            <Card title="Выручка по дням (оценка, $)">
              <Column
                data={revenueData}
                xField="date"
                yField="usd"
                height={240}
                style={{ fill: COLOR_REVENUE, radiusTopLeft: 4, radiusTopRight: 4 }}
                axis={{ x: axisX, y: { ...axisY, labelFormatter: (v: number) => `$${v}` } }}
                tooltip={{
                  title: (d: { date: string }) => shortDate(d.date),
                  items: [{ field: 'usd', name: 'Выручка', valueFormatter: (v: number) => usd(Math.round(v * 100)) }],
                }}
              />
            </Card>
          </Col>
        </Row>
        </Suspense>

        <Row gutter={[16, 16]} style={{ marginTop: 16 }}>
          <Col xs={24}>
            <Card title={`Топ новелл по завершениям глав (${days} дн.)`}>
              <Table
                columns={topColumns}
                dataSource={summary?.topNovels ?? []}
                rowKey="id"
                size="small"
                pagination={false}
                locale={{ emptyText: 'Нет данных за период' }}
              />
            </Card>
          </Col>
        </Row>
      </Spin>
    </div>
  );
}
