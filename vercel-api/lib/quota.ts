import { kv } from '@vercel/kv';

export type UsageFeature = 'chat' | 'try_on' | 'optimize';
export type UsageTier = 'free' | 'premium' | 'pro' | 'testflight';

type WindowName = 'five_hour' | 'daily' | 'weekly' | 'monthly';

type QuotaRule = {
  limit: number;
  windowSeconds: number;
};

type FeatureQuota = Partial<Record<WindowName, QuotaRule>>;

type MemoryEntry = {
  used: number;
  expiresAt: number;
};

const memoryQuota = new Map<string, MemoryEntry>();

const QUOTAS: Record<UsageTier, Record<UsageFeature, FeatureQuota>> = {
  free: {
    chat: {
      daily: { limit: 10, windowSeconds: 24 * 60 * 60 },
      weekly: { limit: 40, windowSeconds: 7 * 24 * 60 * 60 },
    },
    try_on: {
      weekly: { limit: 1, windowSeconds: 7 * 24 * 60 * 60 },
      monthly: { limit: 3, windowSeconds: 30 * 24 * 60 * 60 },
    },
    optimize: {
      daily: { limit: 10, windowSeconds: 24 * 60 * 60 },
      monthly: { limit: 60, windowSeconds: 30 * 24 * 60 * 60 },
    },
  },
  premium: {
    chat: {
      five_hour: { limit: 40, windowSeconds: 5 * 60 * 60 },
      weekly: { limit: 350, windowSeconds: 7 * 24 * 60 * 60 },
    },
    try_on: {
      daily: { limit: 8, windowSeconds: 24 * 60 * 60 },
      monthly: { limit: 60, windowSeconds: 30 * 24 * 60 * 60 },
    },
    optimize: {
      daily: { limit: 60, windowSeconds: 24 * 60 * 60 },
      monthly: { limit: 600, windowSeconds: 30 * 24 * 60 * 60 },
    },
  },
  pro: {
    chat: {
      five_hour: { limit: 80, windowSeconds: 5 * 60 * 60 },
      weekly: { limit: 900, windowSeconds: 7 * 24 * 60 * 60 },
    },
    try_on: {
      daily: { limit: 20, windowSeconds: 24 * 60 * 60 },
      monthly: { limit: 200, windowSeconds: 30 * 24 * 60 * 60 },
    },
    optimize: {
      daily: { limit: 120, windowSeconds: 24 * 60 * 60 },
      monthly: { limit: 1200, windowSeconds: 30 * 24 * 60 * 60 },
    },
  },
  testflight: {
    chat: {
      five_hour: { limit: 80, windowSeconds: 5 * 60 * 60 },
      weekly: { limit: 500, windowSeconds: 7 * 24 * 60 * 60 },
    },
    try_on: {
      daily: { limit: 20, windowSeconds: 24 * 60 * 60 },
      monthly: { limit: 120, windowSeconds: 30 * 24 * 60 * 60 },
    },
    optimize: {
      daily: { limit: 120, windowSeconds: 24 * 60 * 60 },
      monthly: { limit: 1200, windowSeconds: 30 * 24 * 60 * 60 },
    },
  },
};

export type QuotaDecision =
  | {
      allowed: true;
      tier: UsageTier;
      remaining: Record<string, number>;
    }
  | {
      allowed: false;
      tier: UsageTier;
      limit: number;
      used: number;
      resetAt: string;
      window: string;
    };

export function normalizeTier(input: string | null | undefined): UsageTier {
  if (input === 'premium' || input === 'pro' || input === 'testflight') {
    return input;
  }
  return 'free';
}

export async function checkAndConsumeQuota(
  userId: string,
  tier: UsageTier,
  feature: UsageFeature
): Promise<QuotaDecision> {
  if (!isKVConfigured()) {
    if (process.env.NODE_ENV === 'production') {
      throw new Error('QUOTA_STORE_NOT_CONFIGURED');
    }
    return checkAndConsumeMemoryQuota(userId, tier, feature);
  }

  const featureQuota = QUOTAS[tier][feature];
  const remaining: Record<string, number> = {};

  for (const [window, rule] of Object.entries(featureQuota)) {
    if (!rule) { continue; }

    const key = quotaKey(userId, feature, window);
    const used = (await kv.get<number>(key)) ?? 0;

    if (used >= rule.limit) {
      const ttl = await kv.ttl(key);
      const resetSeconds = ttl > 0 ? ttl : rule.windowSeconds;
      return {
        allowed: false,
        tier,
        limit: rule.limit,
        used,
        resetAt: new Date(Date.now() + resetSeconds * 1000).toISOString(),
        window,
      };
    }
  }

  for (const [window, rule] of Object.entries(featureQuota)) {
    if (!rule) { continue; }

    const key = quotaKey(userId, feature, window);
    const used = (await kv.get<number>(key)) ?? 0;

    if (used === 0) {
      await kv.set(key, 1, { ex: rule.windowSeconds });
      remaining[window] = rule.limit - 1;
    } else {
      const next = await kv.incr(key);
      remaining[window] = Math.max(0, rule.limit - next);
    }
  }

  return { allowed: true, tier, remaining };
}

export async function deleteUserQuota(userId: string): Promise<void> {
  const prefix = `usage:${userId}:`;

  if (!isKVConfigured()) {
    if (process.env.NODE_ENV === 'production') {
      throw new Error('QUOTA_STORE_NOT_CONFIGURED');
    }
    for (const key of memoryQuota.keys()) {
      if (key.startsWith(prefix)) {
        memoryQuota.delete(key);
      }
    }
    return;
  }

  const keys = await kv.keys(`${prefix}*`);
  if (keys.length > 0) {
    await kv.del(...keys);
  }
}

export async function refundQuota(userId: string, feature: UsageFeature): Promise<void> {
  if (!isKVConfigured()) {
    if (process.env.NODE_ENV === 'production') {
      return;
    }
    refundMemoryQuota(userId, feature);
    return;
  }

  const pattern = `usage:${userId}:${feature}:*`;
  const keys = await kv.keys(pattern);
  await Promise.all(keys.map(async key => {
    const current = (await kv.get<number>(key)) ?? 0;
    if (current > 0) {
      await kv.decr(key);
    }
  }));
}

function quotaKey(userId: string, feature: UsageFeature, window: string): string {
  return `usage:${userId}:${feature}:${window}`;
}

function isKVConfigured(): boolean {
  return Boolean(
    process.env.KV_REST_API_URL ||
    process.env.KV_URL ||
    process.env.UPSTASH_REDIS_REST_URL
  );
}

function checkAndConsumeMemoryQuota(
  userId: string,
  tier: UsageTier,
  feature: UsageFeature
): QuotaDecision {
  const featureQuota = QUOTAS[tier][feature];
  const remaining: Record<string, number> = {};
  const now = Date.now();

  for (const [window, rule] of Object.entries(featureQuota)) {
    if (!rule) { continue; }

    const key = quotaKey(userId, feature, window);
    const entry = normalizedMemoryEntry(key, rule.windowSeconds, now);

    if (entry.used >= rule.limit) {
      return {
        allowed: false,
        tier,
        limit: rule.limit,
        used: entry.used,
        resetAt: new Date(entry.expiresAt).toISOString(),
        window,
      };
    }
  }

  for (const [window, rule] of Object.entries(featureQuota)) {
    if (!rule) { continue; }

    const key = quotaKey(userId, feature, window);
    const entry = normalizedMemoryEntry(key, rule.windowSeconds, now);
    entry.used += 1;
    memoryQuota.set(key, entry);
    remaining[window] = Math.max(0, rule.limit - entry.used);
  }

  return { allowed: true, tier, remaining };
}

function refundMemoryQuota(userId: string, feature: UsageFeature): void {
  const prefix = `usage:${userId}:${feature}:`;
  for (const [key, entry] of memoryQuota.entries()) {
    if (key.startsWith(prefix) && entry.used > 0) {
      memoryQuota.set(key, { ...entry, used: entry.used - 1 });
    }
  }
}

function normalizedMemoryEntry(key: string, windowSeconds: number, now: number): MemoryEntry {
  const existing = memoryQuota.get(key);
  if (existing && existing.expiresAt > now) {
    return existing;
  }

  return {
    used: 0,
    expiresAt: now + windowSeconds * 1000,
  };
}
