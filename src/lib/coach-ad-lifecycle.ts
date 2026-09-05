import type { CoachAd } from "@/types";

export type CoachAdLifecycle = "pending" | "active" | "expiring" | "expired";

const DAY_MS = 24 * 60 * 60 * 1000;

export function coachAdLifecycle(ad: CoachAd, now = new Date()): CoachAdLifecycle {
  if (ad.status === "pending_payment" || ad.status === "draft") return "pending";
  if (ad.status === "expired") return "expired";

  const expiresAt = ad.expiresAt ? new Date(ad.expiresAt).getTime() : Number.POSITIVE_INFINITY;
  if (!Number.isFinite(expiresAt) || expiresAt <= now.getTime()) return "expired";
  return expiresAt - now.getTime() <= 3 * DAY_MS ? "expiring" : "active";
}

export function coachAdDaysRemaining(ad: CoachAd, now = new Date()): number | null {
  if (!ad.expiresAt) return null;
  const remaining = new Date(ad.expiresAt).getTime() - now.getTime();
  if (!Number.isFinite(remaining)) return null;
  return Math.max(0, Math.ceil(remaining / DAY_MS));
}

export function effectiveCoachAd(ad: CoachAd, now = new Date()): CoachAd {
  return coachAdLifecycle(ad, now) === "expired" && ad.status === "active"
    ? { ...ad, status: "expired" }
    : ad;
}
