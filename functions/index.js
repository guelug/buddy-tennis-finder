// Verificación server-side de compras (Google Play). Requiere el plan Blaze
// para desplegarse (Cloud Functions), por eso `PURCHASES_ENABLED`
// (src/lib/features.ts) está desactivado por defecto en ambas plataformas:
// la app no depende de que estas funciones estén desplegadas para arrancar.
//
// TODO(android-purchases): esta función solo sabe hablar con la API de
// Google Play. Antes de reactivarla en producción, sustituir/complementar
// con Stripe u otra pasarela si Blaze no es viable.
// TODO(ios-purchases): no existe todavía verificación de recibos de Apple
// aquí (App Store Server API o JWS de StoreKit 2). No activar
// `EXPO_PUBLIC_IOS_PURCHASES_ENABLED` hasta añadirla.
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");
const { google } = require("googleapis");
const crypto = require("node:crypto");

initializeApp();

const db = getFirestore();
const PACKAGE_NAME = "com.matchpoint.clubs";
const COACH_PRODUCTS = {
  coach_ad_7_days: { plan: "week", days: 7 },
  coach_ad_30_days: { plan: "month", days: 30 }
};
const LEAGUE_PRODUCT = "private_league_create";

class PermanentPurchaseError extends Error {}

function accountHash(ownerId) {
  return crypto.createHash("sha256").update(ownerId).digest("hex");
}

async function publisherClient() {
  const auth = new google.auth.GoogleAuth({ scopes: ["https://www.googleapis.com/auth/androidpublisher"] });
  return google.androidpublisher({ version: "v3", auth });
}

async function verifyProduct(productId, purchaseToken, ownerId) {
  const publisher = await publisherClient();
  const response = await publisher.purchases.products.get({
    packageName: PACKAGE_NAME,
    productId,
    token: purchaseToken
  });
  if (response.data.purchaseState === 1) throw new PermanentPurchaseError("Google Play indica que la compra fue cancelada.");
  if (response.data.purchaseState !== 0) throw new Error("La compra todavía no figura como completada en Google Play.");
  if (response.data.obfuscatedExternalAccountId !== accountHash(ownerId)) {
    throw new PermanentPurchaseError("La compra no pertenece a este usuario.");
  }
  return {
    publisher,
    orderId: response.data.orderId || "",
    alreadyConsumed: response.data.consumptionState === 1
  };
}

async function consumeProduct(publisher, productId, purchaseToken) {
  await publisher.purchases.products.consume({ packageName: PACKAGE_NAME, productId, token: purchaseToken });
}

exports.verifyCoachPurchase = onDocumentCreated({
  document: "coachPurchases/{purchaseToken}",
  region: "europe-west1",
  retry: true
}, async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;
  const purchase = snapshot.data();
  const product = COACH_PRODUCTS[purchase.productId];
  if (!product || purchase.purchaseToken !== event.params.purchaseToken) {
    await snapshot.ref.update({ status: "rejected", reason: "Producto no válido." });
    return;
  }
  if (purchase.platform && purchase.platform !== "android") {
    // Ver TODO(ios-purchases) al principio del archivo: todavía no hay
    // verificación de recibos de Apple, así que no intentamos validar contra
    // la API de Google Play con un token que no es suyo.
    await snapshot.ref.update({ status: "rejected", reason: "Verificación de iOS aún no implementada." });
    return;
  }

  try {
    const { publisher, orderId, alreadyConsumed } = await verifyProduct(purchase.productId, purchase.purchaseToken, purchase.ownerId);
    const adRef = db.doc(`coachAds/${purchase.adId}`);
    await db.runTransaction(async (transaction) => {
      const [freshPurchase, adSnapshot] = await Promise.all([transaction.get(snapshot.ref), transaction.get(adRef)]);
      if (freshPurchase.data().status === "verified") return;
      if (!adSnapshot.exists || adSnapshot.data().ownerId !== purchase.ownerId || adSnapshot.data().plan !== product.plan) {
        throw new PermanentPurchaseError("El anuncio no coincide con la compra.");
      }
      const activeFrom = Date.now();
      const expiresAt = activeFrom + product.days * 24 * 60 * 60 * 1000;
      transaction.update(adRef, {
        status: "active",
        activeFrom: Timestamp.fromMillis(activeFrom),
        expiresAt: Timestamp.fromMillis(expiresAt),
        updatedAt: FieldValue.serverTimestamp()
      });
      transaction.update(snapshot.ref, {
        status: "verified",
        orderId,
        verifiedAt: FieldValue.serverTimestamp()
      });
    });
    if (!alreadyConsumed) await consumeProduct(publisher, purchase.productId, purchase.purchaseToken);
    await snapshot.ref.update({ consumedAt: FieldValue.serverTimestamp() });
  } catch (error) {
    console.error("verifyCoachPurchase", error);
    if (error instanceof PermanentPurchaseError) {
      await snapshot.ref.update({ status: "rejected", reason: error.message, rejectedAt: FieldValue.serverTimestamp() });
      return;
    }
    await snapshot.ref.update({ lastError: String(error.message || error), retryAt: FieldValue.serverTimestamp() });
    throw error;
  }
});

function inviteCode() {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let result = "";
  for (let index = 0; index < 8; index += 1) result += chars[Math.floor(Math.random() * chars.length)];
  return result;
}

exports.verifyLeaguePurchase = onDocumentCreated({
  document: "leaguePurchases/{purchaseToken}",
  region: "europe-west1",
  retry: true
}, async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;
  const purchase = snapshot.data();
  if (purchase.productId !== LEAGUE_PRODUCT || purchase.purchaseToken !== event.params.purchaseToken) {
    await snapshot.ref.update({ status: "rejected", reason: "Producto no válido." });
    return;
  }
  if (purchase.platform && purchase.platform !== "android") {
    // Ver TODO(ios-purchases) al principio del archivo.
    await snapshot.ref.update({ status: "rejected", reason: "Verificación de iOS aún no implementada." });
    return;
  }
  try {
    const { publisher, orderId, alreadyConsumed } = await verifyProduct(purchase.productId, purchase.purchaseToken, purchase.ownerId);
    const leagueRef = db.collection("privateLeagues").doc();
    const inviteRef = leagueRef.collection("private").doc("invite");
    await db.runTransaction(async (transaction) => {
      const freshPurchase = await transaction.get(snapshot.ref);
      if (freshPurchase.data().status === "verified") return;
      const input = purchase.league || {};
      if (typeof input.name !== "string" || input.name.trim().length < 3) throw new PermanentPurchaseError("Datos de liga no válidos.");
      const code = inviteCode();
      transaction.create(leagueRef, {
        id: leagueRef.id,
        ownerId: purchase.ownerId,
        name: input.name.trim().slice(0, 80),
        description: String(input.description || "").trim().slice(0, 400),
        division: input.division,
        format: input.format,
        maxMembers: Math.min(32, Math.max(2, Number(input.maxMembers) || 12)),
        memberIds: [purchase.ownerId],
        createdAt: FieldValue.serverTimestamp()
      });
      transaction.create(inviteRef, { code, createdAt: FieldValue.serverTimestamp() });
      transaction.update(snapshot.ref, {
        status: "verified",
        leagueId: leagueRef.id,
        orderId,
        verifiedAt: FieldValue.serverTimestamp()
      });
    });
    if (!alreadyConsumed) await consumeProduct(publisher, purchase.productId, purchase.purchaseToken);
    await snapshot.ref.update({ consumedAt: FieldValue.serverTimestamp() });
  } catch (error) {
    console.error("verifyLeaguePurchase", error);
    if (error instanceof PermanentPurchaseError) {
      await snapshot.ref.update({ status: "rejected", reason: error.message, rejectedAt: FieldValue.serverTimestamp() });
      return;
    }
    await snapshot.ref.update({ lastError: String(error.message || error), retryAt: FieldValue.serverTimestamp() });
    throw error;
  }
});

exports.acceptLeagueInvite = onDocumentCreated({
  document: "leagueJoinRequests/{requestId}",
  region: "europe-west1"
}, async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;
  const request = snapshot.data();
  const leagueRef = db.doc(`privateLeagues/${request.leagueId}`);
  const inviteRef = leagueRef.collection("private").doc("invite");
  await db.runTransaction(async (transaction) => {
    const [leagueSnapshot, inviteSnapshot] = await Promise.all([
      transaction.get(leagueRef),
      transaction.get(inviteRef)
    ]);
    if (!leagueSnapshot.exists) {
      transaction.update(snapshot.ref, { status: "rejected", reason: "La liga ya no existe." });
      return;
    }
    const league = leagueSnapshot.data();
    if (!inviteSnapshot.exists || inviteSnapshot.data().code !== request.inviteCode) {
      transaction.update(snapshot.ref, { status: "rejected", reason: "El código de invitación no es válido." });
      return;
    }
    if (league.memberIds.includes(request.userId)) {
      transaction.update(snapshot.ref, { status: "accepted", processedAt: FieldValue.serverTimestamp() });
      return;
    }
    if (league.memberIds.length >= league.maxMembers) {
      transaction.update(snapshot.ref, { status: "rejected", reason: "La liga ya está completa." });
      return;
    }
    transaction.update(leagueRef, { memberIds: FieldValue.arrayUnion(request.userId), updatedAt: FieldValue.serverTimestamp() });
    transaction.update(snapshot.ref, { status: "accepted", processedAt: FieldValue.serverTimestamp() });
  });
});
