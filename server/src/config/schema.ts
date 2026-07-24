import { z } from 'zod';

/**
 * Zod-валидация секций GameConfig (спека 2.4/2.7).
 * Неизвестные ключи НЕ отклоняются — сохраняются с console.warn (passthrough).
 */

const intNonNeg = z.number().int().min(0);

const economySchema = z
  .object({
    maxTickets: z.number().int().min(1).optional(),
    ticketRefillMinutes: z.number().int().min(1).optional(),
    startDiamonds: intNonNeg.optional(),
    startTickets: intNonNeg.optional(),
    diamondCostPerTicket: intNonNeg.optional(),
    legacySyncCap: intNonNeg.optional(),
  })
  .passthrough();

const adsSchema = z
  .object({
    maxAdsPerDay: intNonNeg.optional(),
    diamondReward: intNonNeg.optional(),
    ticketReward: intNonNeg.optional(),
    rewardAmount: intNonNeg.optional(),
    rewardedAdUnitIdAndroid: z.string().optional(),
    rewardedAdUnitIdIos: z.string().optional(),
  })
  .passthrough();

const iapProductRewardSchema = z
  .object({
    diamonds: intNonNeg.optional(),
    tickets: intNonNeg.optional(),
    vipDays: intNonNeg.optional(),
    usdCents: intNonNeg.optional(),
  })
  .passthrough();

const iapProductsEntrySchema = z
  .object({
    id: z.string().min(1),
    usdCents: intNonNeg.optional(),
  })
  .passthrough();

// iap: map productId → награда, плюс специальный ключ products[] (цены в usdCents).
const iapSchema = z.record(z.unknown()).superRefine((val, ctx) => {
  for (const [key, v] of Object.entries(val)) {
    if (key === 'products') {
      const r = z.array(iapProductsEntrySchema).safeParse(v);
      if (!r.success) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['products'],
          message: 'products must be an array of { id, usdCents? }',
        });
      }
    } else {
      const r = iapProductRewardSchema.safeParse(v);
      if (!r.success) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: [key],
          message: 'product reward must be { diamonds?, tickets?, vipDays?, usdCents? } (non-negative ints)',
        });
      }
    }
  }
});

const vipSchema = z
  .object({
    dailyDiamonds: intNonNeg.optional(),
    unlimitedTickets: z.boolean().optional(),
    earlyAccess: z.boolean().optional(),
    noAds: z.boolean().optional(),
    exclusiveFrame: z.boolean().optional(),
  })
  .passthrough();

const dailySchema = z.array(
  z
    .object({
      day: z.number().int().min(1),
      diamonds: intNonNeg.optional(),
      tickets: intNonNeg.optional(),
      label: z.string().optional(),
    })
    .passthrough()
);

const achievementsSchema = z.array(
  z
    .object({
      id: z.string().min(1),
      title: z.string().optional(),
      icon: z.string().optional(),
      diamondReward: intNonNeg.optional(),
      description: z.string().optional(),
    })
    .passthrough()
);

const localizationSchema = z.record(z.record(z.string()));

export const CONFIG_SECTIONS = ['economy', 'ads', 'iap', 'vip', 'daily', 'achievements', 'localization'] as const;
export type ConfigSection = (typeof CONFIG_SECTIONS)[number];

const sectionSchemas: Record<ConfigSection, z.ZodTypeAny> = {
  economy: economySchema,
  ads: adsSchema,
  iap: iapSchema,
  vip: vipSchema,
  daily: dailySchema,
  achievements: achievementsSchema,
  localization: localizationSchema,
};

/** Известные ключи объектных секций — для warning о неизвестных (не отклоняем). */
const knownKeys: Partial<Record<ConfigSection, ReadonlySet<string>>> = {
  economy: new Set(Object.keys(economySchema.shape)),
  ads: new Set(Object.keys(adsSchema.shape)),
  vip: new Set(Object.keys(vipSchema.shape)),
};

export interface ConfigValidationError {
  section: string;
  message: string;
}

export type ConfigValidationResult =
  | { ok: true; warnings: string[] }
  | { ok: false; errors: ConfigValidationError[] };

/**
 * Валидирует присутствующие в body секции конфига.
 * Возвращает ошибки по секциям; неизвестные ключи внутри секций — только warning.
 */
export function validateGameConfigInput(body: Record<string, unknown>): ConfigValidationResult {
  const errors: ConfigValidationError[] = [];
  const warnings: string[] = [];

  if (!body || typeof body !== 'object') {
    return { ok: false, errors: [{ section: 'body', message: 'config body must be an object' }] };
  }

  for (const key of Object.keys(body)) {
    if (!CONFIG_SECTIONS.includes(key as ConfigSection)) {
      warnings.push(`unknown top-level key '${key}' — ignored`);
    }
  }

  for (const section of CONFIG_SECTIONS) {
    const value = body[section];
    if (value === undefined) continue;

    const parsed = sectionSchemas[section].safeParse(value);
    if (!parsed.success) {
      for (const issue of parsed.error.issues) {
        const path = issue.path.length > 0 ? `.${issue.path.join('.')}` : '';
        errors.push({ section, message: `${section}${path}: ${issue.message}` });
      }
      continue;
    }

    const known = knownKeys[section];
    if (known && value && typeof value === 'object' && !Array.isArray(value)) {
      for (const k of Object.keys(value)) {
        if (!known.has(k)) warnings.push(`unknown key ${section}.${k} — preserved as-is`);
      }
    }
  }

  if (errors.length > 0) return { ok: false, errors };

  for (const w of warnings) {
    console.warn(`[config] ${w}`);
  }
  return { ok: true, warnings };
}
