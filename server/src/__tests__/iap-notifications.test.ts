/**
 * Тесты обработчика Google RTDN и логики отзыва покупок (спека 2.6).
 * Верификация OIDC замокана флагом verified; mock-prisma по паттерну iap.test.ts.
 */
import { describe, it, expect, vi, beforeEach } from 'vitest';
import crypto from 'crypto';

const mocks = vi.hoisted(() => {
  type TxRow = {
    id: string;
    userId: string;
    platform: string;
    productId: string;
    transactionId: string;
    receiptHash: string;
    verified: boolean;
    rewardClaimed: boolean;
    revokedAt: Date | null;
    createdAt: Date;
  };
  type NotifRow = {
    id: string;
    platform: string;
    messageId: string | null;
    type: string | null;
    transactionId: string | null;
    payload: unknown;
    processed: boolean;
    error: string | null;
  };
  type LedgerRow = { userId: string; currency: string; delta: number; reason: string; refId: string | null; idempotencyKey: string };

  const state = {
    txs: [] as TxRow[],
    notifications: [] as NotifRow[],
    ledger: [] as LedgerRow[],
    currencies: new Map<string, { userId: string; diamonds: number; tickets: number }>(),
    users: new Map<string, { id: string; vipExpiresAt: Date | null }>(),
    config: { iap: {} as Record<string, unknown> },
  };

  function resetState() {
    state.txs = [];
    state.notifications = [];
    state.ledger = [];
    state.currencies = new Map();
    state.users = new Map();
    state.config.iap = {
      diamonds_20: { diamonds: 20 },
      vip_monthly: { vipDays: 30 },
    };
  }

  const randomUuid = () =>
    (globalThis as unknown as { crypto: { randomUUID: () => string } }).crypto.randomUUID();

  const prismaMock: any = {
    storeNotification: {
      create: async ({ data }: any) => {
        if (
          data.messageId != null &&
          state.notifications.some((n) => n.platform === data.platform && n.messageId === data.messageId)
        ) {
          const err = new Error('Unique constraint failed') as Error & { code: string };
          err.code = 'P2002';
          throw err;
        }
        const row: NotifRow = {
          id: randomUuid(),
          platform: data.platform,
          messageId: data.messageId ?? null,
          type: data.type ?? null,
          transactionId: data.transactionId ?? null,
          payload: data.payload,
          processed: data.processed ?? false,
          error: data.error ?? null,
        };
        state.notifications.push(row);
        return { id: row.id };
      },
      update: async ({ where, data }: any) => {
        const row = state.notifications.find((n) => n.id === where.id);
        if (!row) throw new Error('not found');
        if (data.processed !== undefined) row.processed = data.processed;
        if (data.error !== undefined) row.error = data.error;
        return row;
      },
    },
    iapTransaction: {
      findUnique: async ({ where }: any) => {
        const w = where.platform_transactionId;
        return (
          state.txs.find((t) => t.platform === w.platform && t.transactionId === w.transactionId) ??
          null
        );
      },
      findFirst: async ({ where }: any) => {
        const rows = state.txs
          .filter(
            (t) =>
              (where.platform === undefined || t.platform === where.platform) &&
              (where.receiptHash === undefined || t.receiptHash === where.receiptHash) &&
              (where.verified === undefined || t.verified === where.verified)
          )
          .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
        return rows[0] ?? null;
      },
      update: async ({ where, data }: any) => {
        const row = state.txs.find((t) => t.id === where.id);
        if (!row) throw new Error('not found');
        if (data.revokedAt !== undefined) row.revokedAt = data.revokedAt;
        return row;
      },
    },
    currencyData: {
      findUnique: async ({ where }: any) => state.currencies.get(where.userId) ?? null,
      update: async ({ where, data }: any) => {
        const row = state.currencies.get(where.userId);
        if (!row) throw new Error('not found');
        if (typeof data.diamonds === 'number') row.diamonds = data.diamonds;
        if (typeof data.tickets === 'number') row.tickets = data.tickets;
        return row;
      },
    },
    currencyLedger: {
      create: async ({ data }: any) => {
        if (state.ledger.some((r) => r.userId === data.userId && r.idempotencyKey === data.idempotencyKey)) {
          const err = new Error('Unique constraint failed') as Error & { code: string };
          err.code = 'P2002';
          throw err;
        }
        state.ledger.push({ ...data, refId: data.refId ?? null });
        return data;
      },
    },
    user: {
      findUnique: async ({ where }: any) => state.users.get(where.id) ?? null,
      update: async ({ where, data }: any) => {
        const u = state.users.get(where.id);
        if (!u) throw new Error('not found');
        if (data.vipExpiresAt !== undefined) u.vipExpiresAt = data.vipExpiresAt;
        return u;
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

import { processGoogleNotification } from '../iap/notifications';
import { revokeIapTransaction } from '../iap/revocation';

const sha256 = (s: string) => crypto.createHash('sha256').update(s).digest('hex');

function envelope(data: object, messageId = 'msg-1') {
  return {
    message: {
      data: Buffer.from(JSON.stringify(data), 'utf-8').toString('base64'),
      messageId,
    },
    subscription: 'projects/p/subscriptions/s',
  };
}

function seedTx(partial: Partial<(typeof state.txs)[number]> = {}) {
  const tx = {
    id: 'tx-1',
    userId: 'u1',
    platform: 'google',
    productId: 'diamonds_20',
    transactionId: 'GPA.123',
    receiptHash: sha256('purchase-token-1'),
    verified: true,
    rewardClaimed: true,
    revokedAt: null as Date | null,
    createdAt: new Date(),
    ...partial,
  };
  state.txs.push(tx);
  return tx;
}

beforeEach(resetState);

describe('IAP — Google RTDN handler', () => {
  it('без верификации: сохраняет payload, НИКАКИХ действий', async () => {
    seedTx();
    state.currencies.set('u1', { userId: 'u1', diamonds: 70, tickets: 5 });

    const result = await processGoogleNotification(
      envelope({ voidedPurchaseNotification: { orderId: 'GPA.123', purchaseToken: 'purchase-token-1' } }),
      false
    );

    expect(result.action).toBe('stored_unverified');
    expect(state.notifications).toHaveLength(1);
    expect(state.notifications[0]!.error).toMatch(/verification/);
    // Транзакция НЕ отозвана, баланс не тронут.
    expect(state.txs[0]!.revokedAt).toBeNull();
    expect(state.currencies.get('u1')!.diamonds).toBe(70);
  });

  it('voided purchase (verified): revokedAt + компенсация в леджер', async () => {
    seedTx();
    state.currencies.set('u1', { userId: 'u1', diamonds: 70, tickets: 5 });

    const result = await processGoogleNotification(
      envelope({ voidedPurchaseNotification: { orderId: 'GPA.123', purchaseToken: 'purchase-token-1' } }),
      true
    );

    expect(result.action).toBe('revoke:revoked');
    expect(state.txs[0]!.revokedAt).not.toBeNull();
    expect(state.currencies.get('u1')!.diamonds).toBe(50); // 70 - 20
    expect(state.ledger).toHaveLength(1);
    expect(state.ledger[0]!.reason).toBe('iap_refund');
    expect(state.ledger[0]!.delta).toBe(-20);
    expect(state.notifications[0]!.processed).toBe(true);
  });

  it('компенсация клампится: баланс не уходит ниже 0', async () => {
    seedTx();
    state.currencies.set('u1', { userId: 'u1', diamonds: 7, tickets: 5 }); // потратил почти всё

    const result = await processGoogleNotification(
      envelope({ voidedPurchaseNotification: { orderId: 'GPA.123' } }),
      true
    );

    expect(result.action).toBe('revoke:revoked');
    expect(state.currencies.get('u1')!.diamonds).toBe(0);
    expect(state.ledger[0]!.delta).toBe(-7);
  });

  it('идемпотентность по messageId: повторная доставка → duplicate, без двойного отзыва', async () => {
    seedTx();
    state.currencies.set('u1', { userId: 'u1', diamonds: 70, tickets: 5 });
    const env = envelope({ voidedPurchaseNotification: { orderId: 'GPA.123' } }, 'msg-42');

    const first = await processGoogleNotification(env, true);
    expect(first.action).toBe('revoke:revoked');

    const second = await processGoogleNotification(env, true);
    expect(second.action).toBe('duplicate');
    expect(state.currencies.get('u1')!.diamonds).toBe(50); // не удвоилось
    expect(state.notifications).toHaveLength(1);
  });

  it('SUBSCRIPTION_REVOKED (type 12): находит транзакцию по хэшу purchaseToken и отзывает VIP', async () => {
    seedTx({
      id: 'tx-vip',
      productId: 'vip_monthly',
      transactionId: 'GPA.VIP',
      receiptHash: sha256('vip-token'),
    });
    const future = new Date(Date.now() + 20 * 86400_000);
    state.users.set('u1', { id: 'u1', vipExpiresAt: future });

    const result = await processGoogleNotification(
      envelope({ subscriptionNotification: { notificationType: 12, purchaseToken: 'vip-token' } }),
      true
    );

    expect(result.action).toBe('revoke:revoked');
    expect(state.txs[0]!.revokedAt).not.toBeNull();
    // VIP срезан до "сейчас".
    expect(state.users.get('u1')!.vipExpiresAt!.getTime()).toBeLessThanOrEqual(Date.now() + 1000);
  });

  it('прочие subscription-нотификации (например RENEWED=2) игнорируются', async () => {
    seedTx();
    const result = await processGoogleNotification(
      envelope({ subscriptionNotification: { notificationType: 2, purchaseToken: 'purchase-token-1' } }),
      true
    );
    expect(result.action).toBe('ignored');
    expect(state.txs[0]!.revokedAt).toBeNull();
  });

  it('неизвестный orderId → revoke:not_found', async () => {
    const result = await processGoogleNotification(
      envelope({ voidedPurchaseNotification: { orderId: 'GPA.UNKNOWN' } }),
      true
    );
    expect(result.action).toBe('revoke:not_found');
  });

  it('битый base64 в message.data (verified) → stored_undecodable', async () => {
    const result = await processGoogleNotification(
      { message: { data: '!!!not-base64-json!!!', messageId: 'msg-x' } },
      true
    );
    expect(result.action).toBe('stored_undecodable');
  });
});

describe('IAP — revokeIapTransaction (идемпотентность)', () => {
  it('повторный отзыв → already_revoked', async () => {
    seedTx();
    state.currencies.set('u1', { userId: 'u1', diamonds: 70, tickets: 5 });

    expect(await revokeIapTransaction('google', 'GPA.123')).toBe('revoked');
    expect(await revokeIapTransaction('google', 'GPA.123')).toBe('already_revoked');
    expect(state.currencies.get('u1')!.diamonds).toBe(50); // компенсация один раз
  });

  it('неверифицированная транзакция не отзывается', async () => {
    seedTx({ verified: false });
    expect(await revokeIapTransaction('google', 'GPA.123')).toBe('not_found');
  });
});
