import prisma from '../db';

/**
 * Ретеншн и воронка по AnalyticsEvent (спека 4.4) — raw SQL в стиле
 * admin analytics/summary.
 */

const DAY_MS = 24 * 60 * 60 * 1000;

export interface RetentionCohort {
  date: string;
  installs: number;
  d1: number | null;
  d7: number | null;
  d30: number | null;
}

/**
 * Когорта = deviceId с первым session_start в дату date; dN = число устройств
 * когорты с любым событием в date+N. Для неполных когорт (день date+N ещё
 * не завершился) dN = null.
 */
export async function getRetentionCohorts(days: number, now: Date = new Date()): Promise<RetentionCohort[]> {
  const since = new Date(now.getTime() - days * DAY_MS);

  const rows = await prisma.$queryRaw<
    { date: string; installs: number; d1: number; d7: number; d30: number }[]
  >`
    WITH firsts AS (
      SELECT device_id, MIN(date_trunc('day', ts)) AS cohort_date
      FROM analytics_events
      WHERE name = 'session_start'
      GROUP BY device_id
    ),
    activity AS (
      SELECT DISTINCT device_id, date_trunc('day', ts) AS day
      FROM analytics_events
    )
    SELECT to_char(f.cohort_date, 'YYYY-MM-DD') AS date,
           COUNT(DISTINCT f.device_id)::int AS installs,
           COUNT(DISTINCT CASE WHEN a.day = f.cohort_date + INTERVAL '1 day'   THEN a.device_id END)::int AS d1,
           COUNT(DISTINCT CASE WHEN a.day = f.cohort_date + INTERVAL '7 days'  THEN a.device_id END)::int AS d7,
           COUNT(DISTINCT CASE WHEN a.day = f.cohort_date + INTERVAL '30 days' THEN a.device_id END)::int AS d30
    FROM firsts f
    LEFT JOIN activity a ON a.device_id = f.device_id
    WHERE f.cohort_date >= ${since}
    GROUP BY f.cohort_date
    ORDER BY f.cohort_date`;

  const todayUtcMs = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate());

  return rows.map((r) => {
    const cohortMs = Date.parse(`${r.date}T00:00:00Z`);
    // dN валиден, только если день date+N полностью прошёл (строго раньше сегодня).
    const complete = (n: number) => cohortMs + n * DAY_MS < todayUtcMs;
    return {
      date: r.date,
      installs: r.installs,
      d1: complete(1) ? r.d1 : null,
      d7: complete(7) ? r.d7 : null,
      d30: complete(30) ? r.d30 : null,
    };
  });
}

export interface FunnelChapter {
  chapter: number;
  starts: number;
  completes: number;
}

export interface NovelFunnel {
  novelId: string;
  novelStarts: number;
  chapters: FunnelChapter[];
}

/**
 * Воронка новеллы: distinct deviceId по novel_start / chapter_start /
 * chapter_complete (params.novelId / params.chapter).
 */
export async function getNovelFunnel(novelId: string): Promise<NovelFunnel> {
  const [startRows, chapterRows] = await Promise.all([
    prisma.$queryRaw<{ count: number }[]>`
      SELECT COUNT(DISTINCT device_id)::int AS count
      FROM analytics_events
      WHERE name = 'novel_start' AND params->>'novelId' = ${novelId}`,
    prisma.$queryRaw<FunnelChapter[]>`
      SELECT (params->>'chapter')::int AS chapter,
             COUNT(DISTINCT CASE WHEN name = 'chapter_start'    THEN device_id END)::int AS starts,
             COUNT(DISTINCT CASE WHEN name = 'chapter_complete' THEN device_id END)::int AS completes
      FROM analytics_events
      WHERE name IN ('chapter_start', 'chapter_complete')
        AND params->>'novelId' = ${novelId}
        AND params->>'chapter' ~ '^[0-9]+$'
      GROUP BY 1
      ORDER BY 1`,
  ]);

  return {
    novelId,
    novelStarts: startRows[0]?.count ?? 0,
    chapters: chapterRows,
  };
}
