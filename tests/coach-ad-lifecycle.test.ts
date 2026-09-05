import assert from "node:assert/strict";
import test from "node:test";
import { coachAdDaysRemaining, coachAdLifecycle, effectiveCoachAd } from "../src/lib/coach-ad-lifecycle";
import type { CoachAd } from "../src/types";

const NOW = new Date("2026-08-28T12:00:00.000Z");

function ad(overrides: Partial<CoachAd> = {}): CoachAd {
  return {
    id: "ad-1",
    ownerId: "coach-1",
    coachName: "Coach",
    headline: "Clases",
    bio: "Entrenamientos personalizados",
    city: "Madrid",
    clubIds: [],
    specialties: ["Técnica"],
    plan: "week",
    status: "active",
    createdAt: "2026-08-20T12:00:00.000Z",
    expiresAt: "2026-09-04T12:00:00.000Z",
    ...overrides
  };
}

test("clasifica anuncios pendientes, activos, próximos a vencer y caducados", () => {
  assert.equal(coachAdLifecycle(ad({ status: "pending_payment", expiresAt: undefined }), NOW), "pending");
  assert.equal(coachAdLifecycle(ad(), NOW), "active");
  assert.equal(coachAdLifecycle(ad({ expiresAt: "2026-08-30T12:00:00.000Z" }), NOW), "expiring");
  assert.equal(coachAdLifecycle(ad({ expiresAt: "2026-08-28T11:59:59.000Z" }), NOW), "expired");
});

test("redondea los días restantes hacia arriba y nunca devuelve negativos", () => {
  assert.equal(coachAdDaysRemaining(ad({ expiresAt: "2026-08-29T00:00:00.000Z" }), NOW), 1);
  assert.equal(coachAdDaysRemaining(ad({ expiresAt: "2026-08-27T00:00:00.000Z" }), NOW), 0);
});

test("normaliza como caducado un anuncio que el servidor aún marca activo", () => {
  const current = ad({ expiresAt: "2026-08-27T12:00:00.000Z" });
  assert.equal(effectiveCoachAd(current, NOW).status, "expired");
  assert.equal(effectiveCoachAd(ad(), NOW).status, "active");
});

test("un anuncio sin vencimiento válido no se muestra como publicidad vigente", () => {
  for (const expiresAt of [undefined, "invalid", NOW.toISOString()]) {
    assert.equal(coachAdLifecycle(ad({ expiresAt }), NOW), "expired");
  }
  assert.equal(coachAdDaysRemaining(ad({ expiresAt: "invalid" }), NOW), null);
  assert.equal(coachAdLifecycle(ad({ expiresAt: "2026-08-31T12:00:00.000Z" }), NOW), "expiring");
  assert.equal(coachAdLifecycle(ad({ expiresAt: "2026-08-31T12:00:00.001Z" }), NOW), "active");
});
