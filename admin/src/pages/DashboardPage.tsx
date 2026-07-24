import { lazy, Suspense, useEffect, useState } from 'react';
import { Card, Col, Row, Segmented, Select, Statistic, Table, Tooltip, Typography, App as AntApp, Spin, Empty } from 'antd';
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

interface RetentionCohort {
  date: string;
  installs: number;
  d1: number | null;
  d7: number | null;
  d30: number | null;
}

interface FunnelChapter { chapter: number; starts: number; completes: number }

interface FunnelData {
  novelId: string;
  novelStarts: number;
  chapters: FunnelChapter[];
}

interface NovelOption { id: string; title: string }

// Палитра (валидирована на белой поверхности): одна серия — один цвет
const COLOR_DAU = '#2a78d6';
const COLOR_NEW_USERS = '#4a3aa7';
const COLOR_REVENUE = '#008300';
const INK_MUTED = '#898781';
// Пара для воронки (starts vs completes) — проверена валидатором: CVD ΔE 104, контраст ≥ 3:1
const COLOR_FUNNEL_STARTS = '#2a78d6';
const COLOR_FUNNEL_COMPLETES = '#008300';

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
  const [retentionDays, setRetentionDays] = useState(30);
  const [retention, setRetention] = useState<RetentionCohort[]>([]);
  const [retentionLoading, setRetentionLoading] = useState(true);
  const [novelOptions, setNovelOptions] = useState<NovelOption[]>([]);
  const [funnelNovelId, setFunnelNovelId] = useState<string | null>(null);
  const [funnel, setFunnel] = useState<FunnelData | null>(null);
  const [funnelLoading, setFunnelLoading] = useState(false);
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

  // Ретеншн — свой период, независимый от периода сводки
  useEffect(() => {
    let active = true;
    const load = async () => {
      setRetentionLoading(true);
      try {
        const { data } = await api.get('/admin/analytics/retention', { params: { days: retentionDays } });
        if (active) setRetention(data.cohorts);
      } catch (err: unknown) {
        if (!active) return;
        const e = err as { response?: { data?: { error?: string } } };
        message.error(e.response?.data?.error || 'Не удалось загрузить ретеншн');
      } finally {
        if (active) setRetentionLoading(false);
      }
    };
    load();
    return () => { active = false; };
  }, [retentionDays, message]);

  // Список новелл для селектора воронки (однократно)
  useEffect(() => {
    let active = true;
    const load = async () => {
      try {
        const { data } = await api.get('/admin/novels', { params: { page: 1, limit: 100 } });
        if (active) setNovelOptions((data.novels as NovelOption[]).map(({ id, title }) => ({ id, title })));
      } catch {
        // Селектор останется пустым — воронка недоступна, остальной дашборд работает
      }
    };
    load();
    return () => { active = false; };
  }, []);

  // Воронка выбранной новеллы
  useEffect(() => {
    if (!funnelNovelId) {
      setFunnel(null);
      return;
    }
    let active = true;
    const load = async () => {
      setFunnelLoading(true);
      try {
        const { data } = await api.get('/admin/analytics/funnel', { params: { novelId: funnelNovelId } });
        if (active) setFunnel(data);
      } catch (err: unknown) {
        if (!active) return;
        const e = err as { response?: { data?: { error?: string } } };
        message.error(e.response?.data?.error || 'Не удалось загрузить воронку');
        setFunnel(null);
      } finally {
        if (active) setFunnelLoading(false);
      }
    };
    load();
    return () => { active = false; };
  }, [funnelNovelId, message]);

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

  // ─── Ретеншн: таблица когорт (свежие сверху), % с абсолютом в тултипе ──────
  const retentionRows = [...retention].reverse();

  const pctCell = (field: 'd1' | 'd7' | 'd30') =>
    function PctCell(_: unknown, r: RetentionCohort) {
      const v = r[field];
      if (v === null || v === undefined) {
        return (
          <Tooltip title="Окно ещё не завершилось — значение появится, когда пройдёт соответствующий день">
            <span style={{ color: INK_MUTED }}>—</span>
          </Tooltip>
        );
      }
      const pct = r.installs > 0 ? (v / r.installs) * 100 : 0;
      return (
        <Tooltip title={`${v} из ${r.installs} устройств вернулись`}>
          <span>{pct.toFixed(1)}%</span>
        </Tooltip>
      );
    };

  const retentionColumns: ColumnsType<RetentionCohort> = [
    {
      title: 'Дата когорты', dataIndex: 'date', key: 'date', width: 130,
      render: (d: string) => shortDate(d),
      sorter: (a, b) => a.date.localeCompare(b.date),
    },
    { title: 'Установок', dataIndex: 'installs', key: 'installs', width: 110, align: 'right' as const },
    { title: 'D1', key: 'd1', width: 90, align: 'right' as const, render: pctCell('d1') },
    { title: 'D7', key: 'd7', width: 90, align: 'right' as const, render: pctCell('d7') },
    { title: 'D30', key: 'd30', width: 90, align: 'right' as const, render: pctCell('d30') },
  ];

  // ─── Воронка: две серии (начали/завершили) по главам ──────────────────────
  const funnelChartData = funnel
    ? [...funnel.chapters]
        .sort((a, b) => a.chapter - b.chapter)
        .flatMap((c) => [
          { chapter: `Гл. ${c.chapter}`, type: 'Начали', value: c.starts },
          { chapter: `Гл. ${c.chapter}`, type: 'Завершили', value: c.completes },
        ])
    : [];

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

      {/* ─── Ретеншн (спека 4.4) ─────────────────────────────────────────── */}
      <Row gutter={[16, 16]} style={{ marginTop: 16 }}>
        <Col xs={24}>
          <Card
            title="Ретеншн — когорты по дате первого запуска"
            extra={
              <Segmented
                value={retentionDays}
                onChange={(v) => setRetentionDays(v as number)}
                options={[
                  { label: '7 дней', value: 7 },
                  { label: '30 дней', value: 30 },
                  { label: '90 дней', value: 90 },
                ]}
              />
            }
          >
            <Table
              columns={retentionColumns}
              dataSource={retentionRows}
              rowKey="date"
              size="small"
              loading={retentionLoading}
              pagination={{ pageSize: 15, hideOnSinglePage: true, size: 'small' }}
              locale={{ emptyText: 'Нет когорт за период — события session_start ещё не поступали' }}
            />
          </Card>
        </Col>
      </Row>

      {/* ─── Воронка по главам (спека 4.4) ───────────────────────────────── */}
      <Row gutter={[16, 16]} style={{ marginTop: 16 }}>
        <Col xs={24}>
          <Card
            title="Воронка новеллы — начали и завершили главу"
            extra={
              <Select
                showSearch
                allowClear
                placeholder="Выберите новеллу"
                style={{ width: 300 }}
                value={funnelNovelId}
                onChange={(v) => setFunnelNovelId(v ?? null)}
                optionFilterProp="label"
                options={novelOptions.map((n) => ({ value: n.id, label: n.title }))}
              />
            }
          >
            {!funnelNovelId ? (
              <Empty description="Выберите новеллу, чтобы построить воронку по главам" />
            ) : funnelLoading ? (
              <Spin style={{ display: 'block', margin: '48px auto' }} />
            ) : funnel ? (
              <>
                <Statistic
                  title="Начали новеллу (уникальных устройств, novel_start)"
                  value={funnel.novelStarts}
                  style={{ marginBottom: 16 }}
                />
                {funnel.chapters.length > 0 ? (
                  <Suspense fallback={<Spin style={{ display: 'block', margin: '48px auto' }} />}>
                    <Column
                      data={funnelChartData}
                      xField="chapter"
                      yField="value"
                      colorField="type"
                      group
                      height={280}
                      style={{ radiusTopLeft: 4, radiusTopRight: 4 }}
                      scale={{ color: { range: [COLOR_FUNNEL_STARTS, COLOR_FUNNEL_COMPLETES] } }}
                      axis={{ x: { labelFill: INK_MUTED, line: false, tickLength: 0 }, y: axisY }}
                      tooltip={{ title: (d: { chapter: string }) => d.chapter }}
                    />
                  </Suspense>
                ) : (
                  <Empty description="По главам этой новеллы пока нет событий chapter_start / chapter_complete" />
                )}
              </>
            ) : (
              <Empty description="Нет данных" />
            )}
          </Card>
        </Col>
      </Row>
    </div>
  );
}
