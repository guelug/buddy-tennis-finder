import { Redis } from '@upstash/redis';

export type UsageFeature = 'chat' | 'try_on' | 'optimize';
export type UsageTier = 'free' | 'testflight';

type WindowName = 'five_hour' | 'daily' | 'weekly' | 'monthly';
type QuotaRule = { limit: number; windowSeconds: number };
type FeatureQuota = Partial<Record<WindowName, QuotaRule>>;
type MemoryEntry = { used: number; expiresAt: number };

const memoryQuota = new Map<string, MemoryEntry>();
let redisClient: Redis | null | undefined;
let warnedAboutMemoryFallback = false;

const ATOMIC_CONSUME_SCRIPT = `
for index, key in ipairs(KEYS) do
  local used = tonumber(redis.call('GET', key) or '0')
  local limit = tonumber(ARGV[((index - 1) * 2) + 1])
  if used >= limit then
    return { 0, index, used, redis.call('TTL', key) }
  end
end

local result = { 1 }
for index, key in ipairs(KEYS) do
  local nextValue = redis.call('INCR', key)
  if nextValue == 1 then
    redis.call('EXPIRE', key, tonumber(ARGV[((index - 1) * 2) + 2]))
  end
  table.insert(result, nextValue)
end
return result
`;

const ATOMIC_REFUND_SCRIPT = `
for _, key in ipairs(KEYS) do
  local used = tonumber(redis.call('GET', key) or '0')
  if used > 0 then
    redis.call('DECR', key)
  end
end
return 1
`;

const QUOTAS: Record<UsageTier, Record<UsageFeature, FeatureQuota>> = {
  free: {
    chat: {
      daily: { limit: 20, windowSeconds: 24 * 60 * 60 },
      weekly: { limit: 80, windowSeconds: 7 * 24 * 60 * 60 },
    },
    try_on: {
      weekly: { limit: 2, windowSeconds: 7 * 24 * 60 * 60 },
      monthly: { limit: 6, windowSeconds: 30 * 24 * 60 * 60 },
    },
    optimize: {
      daily: { limit: 10, windowSeconds: 24 * 60 * 60 },
      monthly: { limit: 60, windowSeconds: 30 * 24 * 60 * 60 },
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
  | { allowed: true; tier: UsageTier; remaining: Record<string, number> }
  | { allowed: false; tier: UsageTier; limit: number; used: number; resetAt: string; window: string };

export function normalizeTier(input: string | null | undefined): UsageTier {
  return input === 'testflight' ? 'testflight' : 'free';
}

export async function checkAndConsumeQuota(
  userId: string,
  tier: UsageTier,
  feature: UsageFeature
): Promise<QuotaDecision> {
  const redis = getRedis();
  if (!redis) {
    warnAboutMemoryFallback();
    return checkAndConsumeMemoryQuota(userId, tier, feature);
  }

  const featureQuota = QUOTAS[tier][feature];
  const windows = Object.entries(featureQuota).flatMap(([name, rule]) =>
    rule ? [{ name, rule, key: quotaKey(userId, feature, name) }] : []
  );
  const result = await redis.eval(
    ATOMIC_CONSUME_SCRIPT,
    windows.map(window => window.key),
    windows.flatMap(window => [String(window.rule.limit), String(window.rule.windowSeconds)])
  ) as Array<number | string>;

  if (Number(result[0]) === 0) {
    const rejectedIndex = Number(result[1]) - 1;
    const rejected = windows[rejectedIndex];
    const used = Number(result[2]);
    const ttl = Number(result[3]);
    const resetSeconds = ttl > 0 ? ttl : rejected.rule.windowSeconds;
    return {
      allowed: false,
      tier,
      limit: rejected.rule.limit,
      used,
      resetAt: new Date(Date.now() + resetSeconds * 1000).toISOString(),
      window: rejected.name,
    };
  }

  const remaining: Record<string, number> = {};
  for (const [index, window] of windows.entries()) {
    remaining[window.name] = Math.max(0, window.rule.limit - Number(result[index + 1]));
  }

  return { allowed: true, tier, remaining };
}

export async function deleteUserQuota(userId: string): Promise<void> {
  const prefix = `usage:${userId}:`;
  const redis = getRedis();
  if (!redis) {
    for (const key of memoryQuota.keys()) if (key.startsWith(prefix)) memoryQuota.delete(key);
    return;
  }

  const keys = await redis.keys(`${prefix}*`);
  await Promise.all(keys.map(key => redis.del(key)));
}

export async function refundQuota(userId: string, feature: UsageFeature): Promise<void> {
  const prefix = `usage:${userId}:${feature}:`;
  const redis = getRedis();
  if (!redis) {
    refundMemoryQuota(prefix);
    return;
  }

  const keys = await redis.keys(`${prefix}*`);
  if (keys.length > 0) await redis.eval(ATOMIC_REFUND_SCRIPT, keys, []);
}

function getRedis(): Redis | null {
  if (redisClient !== undefined) return redisClient;
  const url = process.env.UPSTASH_REDIS_REST_URL || process.env.KV_REST_API_URL;
  const token = process.env.UPSTASH_REDIS_REST_TOKEN || process.env.KV_REST_API_TOKEN;
  redisClient = url && token ? new Redis({ url, token }) : null;
  return redisClient;
}

function warnAboutMemoryFallback(): void {
  if (warnedAboutMemoryFallback) return;
  warnedAboutMemoryFallback = true;
  console.warn('Persistent quota store is not configured; using per-instance memory limits.');
}

function quotaKey(userId: string, feature: UsageFeature, window: string): string {
  return `usage:${userId}:${feature}:${window}`;
}

function checkAndConsumeMemoryQuota(userId: string, tier: UsageTier, feature: UsageFeature): QuotaDecision {
  const featureQuota = QUOTAS[tier][feature];
  const remaining: Record<string, number> = {};
  const now = Date.now();

  for (const [window, rule] of Object.entries(featureQuota)) {
    if (!rule) continue;
    const entry = normalizedMemoryEntry(quotaKey(userId, feature, window), rule.windowSeconds, now);
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
    if (!rule) continue;
    const key = quotaKey(userId, feature, window);
    const entry = normalizedMemoryEntry(key, rule.windowSeconds, now);
    entry.used += 1;
    memoryQuota.set(key, entry);
    remaining[window] = Math.max(0, rule.limit - entry.used);
  }
  return { allowed: true, tier, remaining };
}

function refundMemoryQuota(prefix: string): void {
  for (const [key, entry] of memoryQuota.entries()) {
    if (key.startsWith(prefix) && entry.used > 0) {
      memoryQuota.set(key, { ...entry, used: entry.used - 1 });
    }
  }
}

function normalizedMemoryEntry(key: string, windowSeconds: number, now: number): MemoryEntry {
  const existing = memoryQuota.get(key);
  if (existing && existing.expiresAt > now) return existing;
  return { used: 0, expiresAt: now + windowSeconds * 1000 };
}
