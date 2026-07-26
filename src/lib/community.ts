import { auth, db, isFirebaseConfigured } from "@/../firebase.config";
import {
  collection,
  doc,
  getDoc,
  onSnapshot,
  query,
  runTransaction,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  type DocumentData,
  type Unsubscribe
} from "@react-native-firebase/firestore";
import type {
  CoachAd,
  CoachAdPlan,
  CoachContact,
  CoachInterest,
  Player,
  PrivateLeague,
  PrivateLeagueInput
} from "@/types";

export const COACH_PRODUCTS: Record<CoachAdPlan, { id: string; days: number; fallbackPrice: string }> = {
  week: { id: "coach_ad_7_days", days: 7, fallbackPrice: "4,99 €" },
  month: { id: "coach_ad_30_days", days: 30, fallbackPrice: "12,99 €" }
};
export const PRIVATE_LEAGUE_PRODUCT = { id: "private_league_create", fallbackPrice: "6,99 €" } as const;

const nowIso = () => new Date().toISOString();

function dateValue(value: unknown, fallback = nowIso()): string {
  if (typeof value === "string") return value;
  if (value && typeof value === "object" && "toDate" in value && typeof value.toDate === "function") {
    return value.toDate().toISOString();
  }
  return fallback;
}

function normalizeCoachAd(id: string, raw: DocumentData): CoachAd {
  return {
    id,
    ownerId: String(raw.ownerId ?? ""),
    coachName: String(raw.coachName ?? "Entrenador"),
    photoURL: typeof raw.photoURL === "string" ? raw.photoURL : null,
    headline: String(raw.headline ?? "Entrenamientos de tenis"),
    bio: String(raw.bio ?? ""),
    city: String(raw.city ?? ""),
    clubIds: Array.isArray(raw.clubIds) ? raw.clubIds.filter((item): item is string => typeof item === "string") : [],
    specialties: Array.isArray(raw.specialties) ? raw.specialties.filter((item): item is string => typeof item === "string") : [],
    priceNote: typeof raw.priceNote === "string" ? raw.priceNote : undefined,
    plan: raw.plan === "month" ? "month" : "week",
    status: ["draft", "pending_payment", "active", "expired"].includes(raw.status) ? raw.status : "draft",
    createdAt: dateValue(raw.createdAt),
    activeFrom: raw.activeFrom ? dateValue(raw.activeFrom) : undefined,
    expiresAt: raw.expiresAt ? dateValue(raw.expiresAt) : undefined
  };
}

function normalizeLeague(id: string, raw: DocumentData): PrivateLeague {
  return {
    id,
    ownerId: String(raw.ownerId ?? ""),
    name: String(raw.name ?? "Liga privada"),
    description: String(raw.description ?? ""),
    division: ["novato", "d", "c", "b", "a"].includes(raw.division) ? raw.division : "novato",
    format: raw.format === "doubles" ? "doubles" : "singles",
    maxMembers: Number.isInteger(raw.maxMembers) ? raw.maxMembers : 8,
    memberIds: Array.isArray(raw.memberIds) ? raw.memberIds.filter((item): item is string => typeof item === "string") : [],
    inviteCode: String(raw.inviteCode ?? ""),
    createdAt: dateValue(raw.createdAt)
  };
}

export function subscribeToActiveCoachAds(
  onNext: (ads: CoachAd[]) => void,
  onError?: (error: Error) => void
): Unsubscribe {
  if (!isFirebaseConfigured) {
    onNext([]);
    return () => {};
  }
  return onSnapshot(
    query(collection(db, "coachAds"), where("status", "==", "active")),
    (snapshot) => {
      const now = Date.now();
      const ads = snapshot.docs
        .map((item) => normalizeCoachAd(item.id, item.data()))
        .filter((item) => !item.expiresAt || new Date(item.expiresAt).getTime() > now)
        .sort((a, b) => b.createdAt.localeCompare(a.createdAt));
      onNext(ads);
    },
    (error) => onError?.(error)
  );
}

export function subscribeToMyCoachAds(uid: string, onNext: (ads: CoachAd[]) => void): Unsubscribe {
  if (!isFirebaseConfigured) {
    onNext([]);
    return () => {};
  }
  return onSnapshot(query(collection(db, "coachAds"), where("ownerId", "==", uid)), (snapshot) => {
    onNext(snapshot.docs
      .map((item) => normalizeCoachAd(item.id, item.data()))
      .sort((a, b) => b.createdAt.localeCompare(a.createdAt)));
  });
}

export async function getCoachAd(adId: string): Promise<CoachAd | null> {
  if (!isFirebaseConfigured) return null;
  const snapshot = await getDoc(doc(db, "coachAds", adId));
  return snapshot.exists() ? normalizeCoachAd(snapshot.id, snapshot.data()) : null;
}

export async function createCoachAdDraft(
  owner: Player,
  input: Pick<CoachAd, "headline" | "bio" | "city" | "clubIds" | "specialties" | "priceNote" | "plan">,
  contact: CoachContact
): Promise<CoachAd> {
  const uid = auth.currentUser?.uid;
  if (!isFirebaseConfigured || !uid) throw new Error("Inicia sesión para publicar tu anuncio.");
  if (owner.id !== uid) throw new Error("El perfil no coincide con la sesión activa.");
  if (!input.headline.trim() || !input.bio.trim()) throw new Error("Añade un titular y una presentación.");
  if (!contact.phone && !contact.whatsapp && !contact.email && !contact.website) {
    throw new Error("Añade al menos una forma de contacto.");
  }

  const adRef = doc(collection(db, "coachAds"));
  const createdAt = nowIso();
  const ad: CoachAd = {
    id: adRef.id,
    ownerId: uid,
    coachName: owner.name,
    photoURL: owner.photoURL ?? null,
    headline: input.headline.trim().slice(0, 90),
    bio: input.bio.trim().slice(0, 700),
    city: input.city.trim().slice(0, 80),
    clubIds: input.clubIds.slice(0, 8),
    specialties: input.specialties.map((item) => item.trim()).filter(Boolean).slice(0, 8),
    priceNote: input.priceNote?.trim().slice(0, 80),
    plan: input.plan,
    status: "pending_payment",
    createdAt
  };

  await runTransaction(db, async (transaction) => {
    transaction.set(adRef, { ...ad, createdAt: serverTimestamp() });
    transaction.set(doc(db, "coachAds", adRef.id, "private", "contact"), {
      ownerId: uid,
      phone: contact.phone?.trim().slice(0, 40) ?? "",
      whatsapp: contact.whatsapp?.trim().slice(0, 40) ?? "",
      email: contact.email?.trim().slice(0, 120) ?? "",
      website: contact.website?.trim().slice(0, 200) ?? "",
      updatedAt: serverTimestamp()
    });
  });
  return ad;
}

export async function registerCoachPurchase(adId: string, productId: string, purchaseToken: string, transactionId?: string | null) {
  const uid = auth.currentUser?.uid;
  if (!uid) throw new Error("La sesión ha caducado.");
  const purchaseRef = doc(db, "coachPurchases", purchaseToken);
  await setDoc(purchaseRef, {
    ownerId: uid,
    adId,
    productId,
    purchaseToken,
    transactionId: transactionId ?? "",
    platform: "android",
    status: "pending_verification",
    createdAt: serverTimestamp()
  });
}

export function waitForCoachPurchaseVerification(purchaseToken: string, timeoutMs = 45_000): Promise<void> {
  return new Promise((resolve, reject) => {
    let settled = false;
    const timeout = setTimeout(() => {
      if (settled) return;
      settled = true;
      unsubscribe();
      reject(new Error("Google Play está verificando el pago. Tu anuncio se activará automáticamente en unos minutos."));
    }, timeoutMs);
    const unsubscribe = onSnapshot(doc(db, "coachPurchases", purchaseToken), (snapshot) => {
      if (!snapshot.exists() || settled) return;
      const status = snapshot.data().status;
      if (status === "verified") {
        settled = true;
        clearTimeout(timeout);
        unsubscribe();
        resolve();
      } else if (status === "rejected") {
        settled = true;
        clearTimeout(timeout);
        unsubscribe();
        reject(new Error("Google Play no pudo validar esta compra."));
      }
    }, (error) => {
      if (settled) return;
      settled = true;
      clearTimeout(timeout);
      reject(error);
    });
  });
}

export async function expressCoachInterest(adId: string, interested: Player): Promise<CoachContact> {
  const uid = auth.currentUser?.uid;
  if (!uid || interested.id !== uid) throw new Error("Inicia sesión para contactar.");
  const adRef = doc(db, "coachAds", adId);
  const interestRef = doc(db, "coachInterests", `${adId}_${uid}`);
  await runTransaction(db, async (transaction) => {
    const [adSnapshot, interestSnapshot] = await Promise.all([
      transaction.get(adRef),
      transaction.get(interestRef)
    ]);
    if (!adSnapshot.exists()) throw new Error("Este anuncio ya no está disponible.");
    const ad = normalizeCoachAd(adSnapshot.id, adSnapshot.data());
    if (ad.status !== "active" || (ad.expiresAt && new Date(ad.expiresAt).getTime() <= Date.now())) {
      throw new Error("Este anuncio ha caducado.");
    }
    if (ad.ownerId === uid) throw new Error("Este es tu propio anuncio.");
    if (!interestSnapshot.exists()) {
      transaction.set(interestRef, {
        coachAdId: adId,
        coachOwnerId: ad.ownerId,
        interestedUserId: uid,
        interestedName: interested.name,
        interestedPhotoURL: interested.photoURL ?? null,
        createdAt: serverTimestamp()
      });
    }
  });
  const contactSnapshot = await getDoc(doc(db, "coachAds", adId, "private", "contact"));
  if (!contactSnapshot.exists()) throw new Error("El entrenador todavía no ha añadido sus datos de contacto.");
  const raw = contactSnapshot.data();
  return {
    phone: raw.phone || undefined,
    whatsapp: raw.whatsapp || undefined,
    email: raw.email || undefined,
    website: raw.website || undefined
  };
}

export function subscribeToCoachInterests(uid: string, onNext: (items: CoachInterest[]) => void): Unsubscribe {
  if (!isFirebaseConfigured) {
    onNext([]);
    return () => {};
  }
  return onSnapshot(query(collection(db, "coachInterests"), where("coachOwnerId", "==", uid)), (snapshot) => {
    const items = snapshot.docs.map((item) => {
      const raw = item.data();
      return {
        id: item.id,
        coachAdId: String(raw.coachAdId),
        coachOwnerId: String(raw.coachOwnerId),
        interestedUserId: String(raw.interestedUserId),
        interestedName: String(raw.interestedName ?? "Jugador"),
        interestedPhotoURL: typeof raw.interestedPhotoURL === "string" ? raw.interestedPhotoURL : null,
        createdAt: dateValue(raw.createdAt),
        readAt: raw.readAt ? dateValue(raw.readAt) : undefined
      } satisfies CoachInterest;
    }).sort((a, b) => b.createdAt.localeCompare(a.createdAt));
    onNext(items);
  });
}

export async function markCoachInterestRead(id: string) {
  await updateDoc(doc(db, "coachInterests", id), { readAt: serverTimestamp() });
}

export async function registerLeaguePurchase(input: PrivateLeagueInput, purchaseToken: string, transactionId?: string | null) {
  const uid = auth.currentUser?.uid;
  if (!uid) throw new Error("La sesión ha caducado.");
  await setDoc(doc(db, "leaguePurchases", purchaseToken), {
    ownerId: uid,
    productId: PRIVATE_LEAGUE_PRODUCT.id,
    purchaseToken,
    transactionId: transactionId ?? "",
    platform: "android",
    status: "pending_verification",
    league: {
      name: input.name.trim().slice(0, 80),
      description: input.description.trim().slice(0, 400),
      division: input.division,
      format: input.format,
      maxMembers: Math.min(32, Math.max(2, input.maxMembers))
    },
    createdAt: serverTimestamp()
  });
}

export function waitForLeaguePurchaseVerification(purchaseToken: string, timeoutMs = 45_000): Promise<string> {
  return new Promise((resolve, reject) => {
    let settled = false;
    const purchaseRef = doc(db, "leaguePurchases", purchaseToken);
    const timeout = setTimeout(() => {
      if (settled) return;
      settled = true;
      unsubscribe();
      reject(new Error("Google Play está verificando el pago. La liga aparecerá automáticamente en unos minutos."));
    }, timeoutMs);
    const unsubscribe = onSnapshot(purchaseRef, (snapshot) => {
      if (!snapshot.exists() || settled) return;
      const data = snapshot.data();
      if (data.status === "verified" && typeof data.leagueId === "string") {
        settled = true;
        clearTimeout(timeout);
        unsubscribe();
        resolve(data.leagueId);
      } else if (data.status === "rejected") {
        settled = true;
        clearTimeout(timeout);
        unsubscribe();
        reject(new Error("Google Play no pudo validar esta compra."));
      }
    }, (error) => {
      if (settled) return;
      settled = true;
      clearTimeout(timeout);
      reject(error);
    });
  });
}

export function subscribeToMyPrivateLeagues(uid: string, onNext: (items: PrivateLeague[]) => void): Unsubscribe {
  if (!isFirebaseConfigured) {
    onNext([]);
    return () => {};
  }
  return onSnapshot(query(collection(db, "privateLeagues"), where("memberIds", "array-contains", uid)), (snapshot) => {
    onNext(snapshot.docs.map((item) => normalizeLeague(item.id, item.data())).sort((a, b) => b.createdAt.localeCompare(a.createdAt)));
  });
}

export async function getPrivateLeague(id: string): Promise<PrivateLeague | null> {
  if (!isFirebaseConfigured) return null;
  const snapshot = await getDoc(doc(db, "privateLeagues", id));
  if (!snapshot.exists()) return null;
  const league = normalizeLeague(snapshot.id, snapshot.data());
  const uid = auth.currentUser?.uid;
  if (uid && league.memberIds.includes(uid)) {
    const inviteSnapshot = await getDoc(doc(db, "privateLeagues", id, "private", "invite"));
    if (inviteSnapshot.exists()) league.inviteCode = String(inviteSnapshot.data().code ?? "");
  }
  return league;
}

export async function joinPrivateLeague(id: string, inviteCode: string): Promise<PrivateLeague> {
  const uid = isFirebaseConfigured ? auth.currentUser?.uid : null;
  if (!uid) throw new Error("Inicia sesión para unirte.");
  // Limpiamos espacios accidentales (teclado móvil, copiar/pegar): sin este
  // trim las reglas rechazaban la solicitud con un críptico "permission denied".
  const code = inviteCode.trim().toUpperCase();
  if (code.length !== 8) throw new Error("El código de invitación debe tener 8 caracteres.");
  // Cada intento usa un documento nuevo: si el usuario se equivoca de código
  // puede volver a intentarlo sin reabrir ni mutar una solicitud ya procesada.
  const requestRef = doc(collection(db, "leagueJoinRequests"));
  await setDoc(requestRef, {
    leagueId: id,
    userId: uid,
    inviteCode: code,
    status: "pending",
    createdAt: serverTimestamp()
  });
  return new Promise((resolve, reject) => {
    let settled = false;
    const timeout = setTimeout(() => {
      if (settled) return;
      settled = true;
      unsubscribe();
      reject(new Error("La invitación se está procesando. Vuelve a abrirla en unos segundos."));
    }, 30_000);
    const unsubscribe = onSnapshot(requestRef, async (snapshot) => {
      if (!snapshot.exists() || settled) return;
      const status = snapshot.data().status;
      if (status === "accepted") {
        settled = true;
        clearTimeout(timeout);
        unsubscribe();
        const league = await getPrivateLeague(id);
        if (league) resolve(league); else reject(new Error("No pudimos cargar la liga."));
      } else if (status === "rejected") {
        settled = true;
        clearTimeout(timeout);
        unsubscribe();
        reject(new Error(String(snapshot.data().reason || "La invitación no es válida.")));
      }
    }, (error) => {
      if (settled) return;
      settled = true;
      clearTimeout(timeout);
      reject(error);
    });
  });
}
