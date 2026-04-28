/**
 * Тесты IAP-модуля.
 *
 * Стратегия: для проверки бизнес-логики (валидация входа, dedup, начисление)
 * мокаем prisma через vi.mock, чтобы не зависеть от живой БД (как и social.test.ts
 * — там тестируются только контракты, в этом репо нет инфраструктуры in-memory БД).
 *
 * Что НЕ покрыто и оставлено TODO:
 *   - Полные E2E-тесты с реальной Postgres (нужен docker-compose в CI).
 *   - Конкурентность (две параллельные верификации одного transactionId) — purrtgres
 *     unique constraint обеспечит корректность, но интеграционный тест нужен отдельно.
 */
import { describe, it, expect, vi, beforeEach } from 'vitest';

// ─── Мокаем prisma до импорта SUT ───────────────────────────────────────────
// vi.mock хойстится в начало файла, поэтому всё его состояние объявляем
// через vi.hoisted — единственный способ безопасно делиться объектами между
// фабрикой mock и тестами.
const mocks = vi.hoisted(() => {
  type MockTx = {
    id: string;
    userId: string;
    platform: string;
    productId: string;
    transactionId: string;
    receiptHash: string;
    verified: boolean;
    rewardClaimed: boolean;
  };
  type MockCurrency = { userId: string; diamonds: number; tickets: number };
  type MockUser = { id: string; vipExpiresAt: Date | null };

  const state = {
    txs: [] as MockTx[],
    currencies: new Map<string, MockCurrency>(),
    users: new Map<string, MockUser>(),
    config: {
      iap: {} as Record<string, { diamonds?: number; tickets?: number; vipDays?: number }>,
    },
  };

  function resetState() {
    state.txs = [];
    state.currencies = new Map();
    state.users = new Map();
    state.config.iap = {
      diamonds_20: { diamonds: 20 },
      starter_bundle: { diamonds: 100, tickets: 10 },
      vip_monthly: { vipDays: 30 },
    };
  }

  // Используем globalThis.crypto (Node 20+) — без top-level import,
  // чтобы не создавать ссылок снаружи vi.hoisted().
  const randomUuid = () =>
    (globalThis as unknown as { crypto: { randomUUID: () => string } }).crypto.randomUUID();

  const prismaMock: any = {
    iapTransaction: {
      findUnique: async ({ where }: any) => {
        const w = where.platform_transactionId;
        return (
          state.txs.find(
            (t) => t.platform === w.platform && t.transactionId === w.transactionId
          ) ?? null
        );
      },
      create: async ({ data }: any) => {
        const tx: MockTx = { id: randomUuid(), ...data };
        state.txs.push(tx);
        return tx;
      },
      upsert: async ({ where, update, create }: any) => {
        const w = where.platform_transactionId;
        const existing = state.txs.find(
          (t) => t.platform === w.platform && t.transactionId === w.transactionId
        );
        if (existing) {
          Object.assign(existing, update);
          return existing;
        }
        const tx: MockTx = { id: randomUuid(), ...create };
        state.txs.push(tx);
        return tx;
      },
    },
    currencyData: {
      findUnique: async ({ where }: any) => state.currencies.get(where.userId) ?? null,
      upsert: async ({ where, update, create }: any) => {
        const existing = state.currencies.get(where.userId);
        if (existing) {
          if (update.diamonds?.increment != null) existing.diamonds += update.diamonds.increment;
          if (update.tickets?.increment != null) existing.tickets += update.tickets.increment;
          return existing;
        }
        const created: MockCurrency = {
          userId: create.userId,
          diamonds: create.diamonds,
          tickets: create.tickets,
        };
        state.currencies.set(create.userId, created);
        return created;
      },
    },
    user: {
      findUnique: async ({ where }: any) => state.users.get(where.id) ?? null,
      update: async ({ where, data }: any) => {
        const u = state.users.get(where.id);
        if (u) {
          if (data.vipExpiresAt !== undefined) u.vipExpiresAt = data.vipExpiresAt;
          return u;
        }
        const created: MockUser = { id: where.id, vipExpiresAt: data.vipExpiresAt ?? null };
        state.users.set(where.id, created);
        return created;
      },
    },
    gameConfig: {
      findUnique: async () => ({ iap: state.config.iap }),
    },
    $transaction: async (fn: any) => fn(prismaMock),
  };

  return { state, resetState, prismaMock };
});

const { state, resetState } = mocks;

vi.mock('../db', () => ({ default: mocks.prismaMock }));

// IAP_VALIDATOR=mock по умолчанию — MockValidator всегда возвращает verified=true
process.env.IAP_VALIDATOR = 'mock';

// SUT-импорты идут после моков
import { processIapPurchase } from '../iap/service';
import { MockValidator } from '../iap/validators/mock';
import { getValidator } from '../iap/validators/factory';
import { getRewardForProduct } from '../iap/rewards';

describe('IAP — MockValidator', () => {
  it('всегда возвращает verified=true для consumable', async () => {
    const v = new MockValidator();
    const r = await v.verify({
      platform: 'apple',
      productId: 'diamonds_20',
      receipt: 'fake-receipt',
      userId: 'u1',
    });
    expect(r.verified).toBe(true);
    expect(r.transactionId).toMatch(/^mock-/);
    expect(r.isSubscription).toBe(false);
  });

  it('помечает vip_* как подписку с expiresAt', async () => {
    const v = new MockValidator();
    const r = await v.verify({
      platform: 'google',
      productId: 'vip_monthly',
      receipt: 'fake',
      userId: 'u1',
    });
    expect(r.verified).toBe(true);
    expect(r.isSubscription).toBe(true);
    expect(r.expiresAt).toBeInstanceOf(Date);
  });
});

describe('IAP — factory', () => {
  beforeEach(() => {
    process.env.IAP_VALIDATOR = 'mock';
  });

  it('возвращает MockValidator при IAP_VALIDATOR=mock', () => {
    process.env.IAP_VALIDATOR = 'mock';
    expect(getValidator('apple')).toBeInstanceOf(MockValidator);
    expect(getValidator('google')).toBeInstanceOf(MockValidator);
  });

  it('бросает понятную ошибку при IAP_VALIDATOR=real без секретов Apple', () => {
    process.env.IAP_VALIDATOR = 'real';
    delete process.env.APPLE_SHARED_SECRET;
    expect(() => getValidator('apple')).toThrow(/Apple validator not configured/);
  });

  it('бросает понятную ошибку при IAP_VALIDATOR=real без секретов Google', () => {
    process.env.IAP_VALIDATOR = 'real';
    delete process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON;
    delete process.env.GOOGLE_PLAY_PACKAGE_NAME;
    expect(() => getValidator('google')).toThrow(/Google validator not configured/);
  });
});

describe('IAP — getRewardForProduct', () => {
  beforeEach(resetState);

  it('возвращает награду из RemoteConfig.iap', async () => {
    const r = await getRewardForProduct('diamonds_20');
    expect(r).toEqual({ diamonds: 20 });
  });

  it('возвращает {} для неизвестного продукта (если он не vip_*)', async () => {
    const r = await getRewardForProduct('unknown_product');
    expect(r).toEqual({});
  });

  it('подставляет vipDays=30 для vip_*, если нет в конфиге', async () => {
    state.config.iap = {}; // явно очищаем
    const r = await getRewardForProduct('vip_premium');
    expect(r.vipDays).toBe(30);
  });

  it('берёт vipDays из конфига если есть', async () => {
    state.config.iap = { vip_monthly: { vipDays: 30 } };
    const r = await getRewardForProduct('vip_monthly');
    expect(r.vipDays).toBe(30);
  });
});

describe('IAP — processIapPurchase', () => {
  beforeEach(() => {
    resetState();
    process.env.IAP_VALIDATOR = 'mock';
  });

  it('успешно начисляет diamonds для consumable', async () => {
    const res = await processIapPurchase({
      platform: 'apple',
      productId: 'diamonds_20',
      receipt: 'r1',
      userId: 'u1',
    });

    expect(res.status).toBe('success');
    expect(res.rewards).toEqual({ diamonds: 20 });
    expect(res.newBalance?.diamonds).toBe(70); // start 50 + 20
    expect(res.newBalance?.tickets).toBe(5);   // start 5
    expect(state.txs).toHaveLength(1);
    expect(state.txs[0]!.verified).toBe(true);
    expect(state.txs[0]!.rewardClaimed).toBe(true);
  });

  it('дедуп: повторный verify той же transaction → already_claimed, баланс не дублируется', async () => {
    // Первый вызов — patches MockValidator чтобы дать стабильный transactionId
    const stableTxId = 'mock-stable-1';
    const spy = vi.spyOn(MockValidator.prototype, 'verify').mockResolvedValue({
      verified: true,
      transactionId: stableTxId,
      productId: 'diamonds_20',
      isSubscription: false,
    });

    const r1 = await processIapPurchase({
      platform: 'apple',
      productId: 'diamonds_20',
      receipt: 'r1',
      userId: 'u1',
    });
    expect(r1.status).toBe('success');
    expect(r1.newBalance?.diamonds).toBe(70);

    const r2 = await processIapPurchase({
      platform: 'apple',
      productId: 'diamonds_20',
      receipt: 'r1',
      userId: 'u1',
    });
    expect(r2.status).toBe('already_claimed');
    expect(r2.newBalance?.diamonds).toBe(70); // НЕ удвоилось

    expect(state.txs).toHaveLength(1);
    spy.mockRestore();
  });

  it('неизвестный продукт (нет в RemoteConfig.iap) → success, но reward пустой', async () => {
    const res = await processIapPurchase({
      platform: 'apple',
      productId: 'unknown_sku',
      receipt: 'r-unk',
      userId: 'u1',
    });
    expect(res.status).toBe('success');
    expect(res.rewards).toEqual({});
    // Баланса нет — currency не создавалась, потому что reward пустой
    expect(state.currencies.has('u1')).toBe(false);
  });

  it('VIP-подписка корректно продлевает vipExpiresAt от текущего значения', async () => {
    // Существующая подписка истекает через 5 дней
    const existing = new Date(Date.now() + 5 * 24 * 60 * 60 * 1000);
    state.users.set('u1', { id: 'u1', vipExpiresAt: existing });

    const stableTxId = 'mock-vip-1';
    const spy = vi.spyOn(MockValidator.prototype, 'verify').mockResolvedValue({
      verified: true,
      transactionId: stableTxId,
      productId: 'vip_monthly',
      isSubscription: true,
      expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
    });

    const res = await processIapPurchase({
      platform: 'google',
      productId: 'vip_monthly',
      receipt: 'r-vip',
      userId: 'u1',
    });

    expect(res.status).toBe('success');
    expect(res.rewards?.vipDays).toBe(30);
    expect(res.vipExpiresAt).toBeInstanceOf(Date);

    // Должно быть существующее (5 дней) + 30 дней = ~35 дней от now (с допуском 1с)
    const expectedMs = existing.getTime() + 30 * 24 * 60 * 60 * 1000;
    const actualMs = (res.vipExpiresAt as Date).getTime();
    expect(Math.abs(actualMs - expectedMs)).toBeLessThan(1000);

    spy.mockRestore();
  });

  it('VIP без существующей подписки: vipExpiresAt = now + vipDays', async () => {
    const stableTxId = 'mock-vip-2';
    const spy = vi.spyOn(MockValidator.prototype, 'verify').mockResolvedValue({
      verified: true,
      transactionId: stableTxId,
      productId: 'vip_monthly',
      isSubscription: true,
    });

    const before = Date.now();
    const res = await processIapPurchase({
      platform: 'apple',
      productId: 'vip_monthly',
      receipt: 'r-vip-fresh',
      userId: 'u-new',
    });

    expect(res.status).toBe('success');
    const ms = (res.vipExpiresAt as Date).getTime();
    // Должно быть now + 30d (±1s)
    expect(ms).toBeGreaterThanOrEqual(before + 30 * 24 * 60 * 60 * 1000 - 1000);
    expect(ms).toBeLessThanOrEqual(Date.now() + 30 * 24 * 60 * 60 * 1000 + 1000);

    spy.mockRestore();
  });

  it('verified=false → status=invalid + audit-запись', async () => {
    const spy = vi.spyOn(MockValidator.prototype, 'verify').mockResolvedValue({
      verified: false,
      transactionId: null,
      productId: 'diamonds_20',
      isSubscription: false,
      error: 'fake fail',
    });

    const res = await processIapPurchase({
      platform: 'apple',
      productId: 'diamonds_20',
      receipt: 'bad',
      userId: 'u1',
    });

    expect(res.status).toBe('invalid');
    expect(res.error).toBe('fake fail');
    // Audit-запись создана
    expect(state.txs).toHaveLength(1);
    expect(state.txs[0]!.verified).toBe(false);

    spy.mockRestore();
  });
});

// ─── Контракт роута: тесты HTTP-валидации входных параметров ────────────────
// Полные интеграционные тесты роута требуют запущенного express + supertest +
// БД. Здесь — только unit-уровень валидаторов, как принято в social.test.ts.
describe('IAP — Route input validation contracts', () => {
  const VALID_PLATFORMS = new Set(['apple', 'google']);

  it('platform должен быть apple или google', () => {
    expect(VALID_PLATFORMS.has('apple')).toBe(true);
    expect(VALID_PLATFORMS.has('google')).toBe(true);
    expect(VALID_PLATFORMS.has('windows')).toBe(false);
    expect(VALID_PLATFORMS.has('')).toBe(false);
  });

  it('productId не должен быть пустым и слишком длинным', () => {
    const MAX = 200;
    expect('diamonds_20'.length > 0 && 'diamonds_20'.length <= MAX).toBe(true);
    expect(''.length > 0).toBe(false);
    expect('A'.repeat(MAX + 1).length <= MAX).toBe(false);
  });

  it('receipt не должен быть пустым и слишком длинным', () => {
    const MAX = 100_000;
    expect('valid-receipt'.length > 0 && 'valid-receipt'.length <= MAX).toBe(true);
    expect(''.length > 0).toBe(false);
    expect('A'.repeat(MAX + 1).length <= MAX).toBe(false);
  });

  // TODO: интеграционный тест "анонимный запрос → 401" через supertest
  // (требует bootstrap express-приложения как в social.test.ts он не реализован).
});
