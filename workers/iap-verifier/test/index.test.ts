import { describe, expect, it } from "vitest";
import {
  accountTokenForUid,
  hasRecentAuthentication,
  validateAccountDeletionBody,
  validateAndroidPurchaseBody,
  validatePurchaseBody
} from "../src/index";

describe("accountTokenForUid", () => {
  it("is stable and creates an RFC 4122 UUID", async () => {
    const first = await accountTokenForUid("user-123");
    const second = await accountTokenForUid("user-123");
    expect(first).toBe(second);
    expect(first).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
  });

  it("does not collide for different sample users", async () => {
    await expect(accountTokenForUid("user-123")).resolves.not.toBe(await accountTokenForUid("user-456"));
  });
});

describe("validatePurchaseBody", () => {
  const token = "36e9b45d-5c9d-55a4-8f5c-94838c70f697";

  it("accepts a bounded coach purchase", () => {
    expect(validatePurchaseBody({
      kind: "coach",
      productId: "coach_ad_7_days",
      transactionId: "2000001234567890",
      appAccountToken: token,
      adId: "coach-ad"
    })).toMatchObject({ kind: "coach", productId: "coach_ad_7_days" });
  });

  it("accepts and normalizes a league purchase", () => {
    expect(validatePurchaseBody({
      kind: "league",
      productId: "private_league_create",
      transactionId: "2000001234567891",
      appAccountToken: token,
      league: {
        name: "  Liga Barcelona  ",
        description: " Amistosa ",
        division: "c",
        format: "singles",
        maxMembers: 12
      }
    })).toMatchObject({ kind: "league", league: { name: "Liga Barcelona", maxMembers: 12 } });
  });

  it("rejects arbitrary product ids and transaction paths", () => {
    expect(() => validatePurchaseBody({
      kind: "coach",
      productId: "free_money",
      transactionId: "../victim",
      appAccountToken: token,
      adId: "ad"
    })).toThrow();
  });
});

describe("validateAndroidPurchaseBody", () => {
  const token = "36e9b45d-5c9d-55a4-8f5c-94838c70f697";

  it("accepts a bounded coach purchase with purchaseToken", () => {
    expect(validateAndroidPurchaseBody({
      kind: "coach",
      productId: "coach_ad_7_days",
      purchaseToken: "purchasedtoken-abc123-def456-ghi789-jkl012",
      appAccountToken: token,
      adId: "coach-ad"
    })).toMatchObject({ kind: "coach", productId: "coach_ad_7_days" });
  });

  it("accepts and normalizes a league purchase with purchaseToken", () => {
    expect(validateAndroidPurchaseBody({
      kind: "league",
      productId: "private_league_create",
      purchaseToken: "purchasedtoken-abc123-def456-ghi789-jkl012",
      appAccountToken: token,
      league: {
        name: "  Liga Barcelona  ",
        description: " Amistosa ",
        division: "c",
        format: "singles",
        maxMembers: 12
      }
    })).toMatchObject({ kind: "league", league: { name: "Liga Barcelona", maxMembers: 12 } });
  });

  it("rejects arbitrary product ids", () => {
    expect(() => validateAndroidPurchaseBody({
      kind: "coach",
      productId: "free_money",
      purchaseToken: "purchasedtoken-abc123",
      appAccountToken: token,
      adId: "ad"
    })).toThrow();
  });

  it("rejects short purchase tokens", () => {
    expect(() => validateAndroidPurchaseBody({
      kind: "coach",
      productId: "coach_ad_7_days",
      purchaseToken: "short",
      appAccountToken: token,
      adId: "ad"
    })).toThrow();
  });
});

describe("account deletion validation", () => {
  it("requires the exact destructive-action confirmation", () => {
    expect(() => validateAccountDeletionBody({ confirmation: "DELETE_ACCOUNT" })).not.toThrow();
    expect(() => validateAccountDeletionBody({ confirmation: "delete_account" })).toThrow();
    expect(() => validateAccountDeletionBody(null)).toThrow();
  });

  it("requires a recent sign-in and rejects implausible future tokens", () => {
    const now = Date.parse("2026-08-12T12:00:00Z");
    expect(hasRecentAuthentication(now / 1000 - 599, now)).toBe(true);
    expect(hasRecentAuthentication(now / 1000 - 601, now)).toBe(false);
    expect(hasRecentAuthentication(now / 1000 + 299, now)).toBe(true);
    expect(hasRecentAuthentication(now / 1000 + 301, now)).toBe(false);
    expect(hasRecentAuthentication(0, now)).toBe(false);
  });
});
