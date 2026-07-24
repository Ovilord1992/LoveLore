import prisma from '../db';

/**
 * Сохранение GameConfig + снапшот в ConfigHistory (для истории и отката).
 * Вызывается из PUT /v1/admin/config и POST /v1/admin/config/rollback.
 */

export interface ConfigSections {
  economy?: unknown;
  ads?: unknown;
  iap?: unknown;
  vip?: unknown;
  daily?: unknown;
  achievements?: unknown;
  localization?: unknown;
  experiments?: unknown;
  segments?: unknown;
  links?: unknown;
}

type ConfigRow = {
  version: number;
  economy: unknown;
  ads: unknown;
  iap: unknown;
  vip: unknown;
  daily: unknown;
  achievements: unknown;
  localization: unknown;
  experiments: unknown;
  segments: unknown;
  links: unknown;
};

function snapshotOf(config: ConfigRow): Record<string, unknown> {
  return {
    economy: config.economy,
    ads: config.ads,
    iap: config.iap,
    vip: config.vip,
    daily: config.daily,
    achievements: config.achievements,
    localization: config.localization,
    experiments: config.experiments,
    segments: config.segments,
    links: config.links,
  };
}

/** Частичное обновление секций + инкремент версии + запись истории. */
export async function saveConfigWithHistory(
  sections: ConfigSections,
  changedBy: string
): Promise<{ version: number }> {
  const { economy, ads, iap, vip, daily, achievements, localization, experiments, segments, links } = sections;

  return prisma.$transaction(async (db) => {
    const current = await db.gameConfig.findUnique({ where: { id: 'singleton' } });
    const newVersion = (current?.version ?? 0) + 1;

    const config = await db.gameConfig.upsert({
      where: { id: 'singleton' },
      update: {
        version: newVersion,
        ...(economy !== undefined && { economy: economy as object }),
        ...(ads !== undefined && { ads: ads as object }),
        ...(iap !== undefined && { iap: iap as object }),
        ...(vip !== undefined && { vip: vip as object }),
        ...(daily !== undefined && { daily: daily as object }),
        ...(achievements !== undefined && { achievements: achievements as object }),
        ...(localization !== undefined && { localization: localization as object }),
        ...(experiments !== undefined && { experiments: experiments as object }),
        ...(segments !== undefined && { segments: segments as object }),
        ...(links !== undefined && { links: links as object }),
      },
      create: {
        id: 'singleton',
        version: newVersion,
        economy: (economy ?? {}) as object,
        ads: (ads ?? {}) as object,
        iap: (iap ?? {}) as object,
        vip: (vip ?? {}) as object,
        daily: (daily ?? []) as object,
        achievements: (achievements ?? []) as object,
        localization: (localization ?? {}) as object,
        experiments: (experiments ?? []) as object,
        segments: (segments ?? []) as object,
        links: (links ?? {}) as object,
      },
    });

    await db.configHistory.create({
      data: {
        version: newVersion,
        changedBy,
        data: snapshotOf(config as unknown as ConfigRow) as object,
      },
    });

    return { version: config.version };
  });
}

export type RollbackResult =
  | { ok: true; version: number; rolledBackTo: number }
  | { ok: false; error: 'version_not_found' };

/** Откат: копирует снапшот указанной версии в GameConfig с инкрементом версии. */
export async function rollbackConfig(version: number, changedBy: string): Promise<RollbackResult> {
  const snapshot = await prisma.configHistory.findUnique({ where: { version } });
  if (!snapshot) return { ok: false, error: 'version_not_found' };

  const data = snapshot.data as ConfigSections;
  const { version: newVersion } = await saveConfigWithHistory(
    {
      economy: data.economy ?? {},
      ads: data.ads ?? {},
      iap: data.iap ?? {},
      vip: data.vip ?? {},
      daily: data.daily ?? [],
      achievements: data.achievements ?? [],
      localization: data.localization ?? {},
      experiments: data.experiments ?? [],
      segments: data.segments ?? [],
      links: data.links ?? {},
    },
    changedBy
  );

  return { ok: true, version: newVersion, rolledBackTo: version };
}
