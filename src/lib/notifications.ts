/**
 * Motor de notificaciones in-app sobre Firestore.
 *
 * Sin Cloud Functions todavía: el fan-out lo hace el cliente que dispara el
 * evento (publicar partido casual, pedir unirse, auto-match). A escala de club
 * es correcto y barato; cuando llegue el backend de push, los mismos puntos de
 * disparo llaman a la función y este módulo queda como bandeja + badge.
 *
 * Colección `notifications`: un documento por aviso, siempre dirigido a UN
 * jugador (`recipientId`). Las reglas dejan leer solo al destinatario.
 */
import {
  addDoc,
  collection,
  doc,
  getDocs,
  limit,
  onSnapshot,
  query,
  serverTimestamp,
  updateDoc,
  where,
  type Unsubscribe
} from "@react-native-firebase/firestore";
import { db, isFirebaseConfigured } from "@/../firebase.config";
import { isLevelCompatible } from "@/lib/matching";
import type { Player, SkillLevel } from "@/types";

export type NotificationType =
  /** Alguien busca rival para partido casual en tu ciudad y nivel. */
  | "team_seeking"
  /** Alguien ha pedido unirse a un partido que tú publicas. */
  | "match_interest"
  /** Auto-match: publicaste y ya había alguien compatible buscando. */
  | "auto_match"
  /** Tu solicitud para unirte fue aceptada. */
  | "join_accepted";

export type AppNotification = {
  id: string;
  recipientId: string;
  type: NotificationType;
  /** Quién disparó el aviso (para mostrar nombre/nivel y abrir su perfil). */
  actorId: string;
  actorName: string;
  /** Texto corto y concreto, en el idioma del disparador. */
  message: string;
  /** Ruta interna opcional para abrir al tocar el aviso. */
  route?: string;
  read: boolean;
  createdAt: string;
};

const COLLECTION_NAME = "notifications";

function normalizeNotification(id: string, data: unknown): AppNotification | null {
  if (!data || typeof data !== "object") return null;
  const raw = data as Partial<AppNotification>;
  if (!raw.recipientId || !raw.type || !raw.actorId || !raw.actorName || !raw.message) return null;
  return {
    id,
    recipientId: raw.recipientId,
    type: raw.type,
    actorId: raw.actorId,
    actorName: raw.actorName,
    message: raw.message,
    route: raw.route,
    read: raw.read === true,
    createdAt: typeof raw.createdAt === "string" ? raw.createdAt : new Date().toISOString()
  };
}

/** Escribe un aviso dirigido. Nunca lanza: fallar una notificación no puede romper la acción que la origina. */
export async function sendNotification(input: Omit<AppNotification, "id" | "read" | "createdAt">): Promise<void> {
  if (!isFirebaseConfigured || input.recipientId === input.actorId) return;
  try {
    await addDoc(collection(db, COLLECTION_NAME), {
      ...input,
      route: input.route ?? null,
      read: false,
      createdAt: new Date().toISOString(),
      createdAtServer: serverTimestamp()
    });
  } catch (error) {
    console.warn("[matchpoint] No se pudo enviar la notificación", error);
  }
}

/**
 * Fan-out para partido casual: avisa a todos los jugadores reales de la misma
 * ciudad cuyo nivel encaje con los niveles aceptados por el organizador.
 * Tope sanitario: 20 destinatarios por evento.
 */
export async function notifyTeamSeeking(
  actor: Player,
  acceptedLevels: SkillLevel[],
  message: string
): Promise<number> {
  if (!isFirebaseConfigured || actor.isDemo) return 0;
  try {
    const snapshot = await getDocs(
      query(
        collection(db, "players"),
        where("profileComplete", "==", true),
        where("city", "==", actor.city),
        limit(60)
      )
    );
    const targets = snapshot.docs
      .map((item) => normalizeNotificationTarget(item.id, item.data()))
      .filter((player): player is Player => Boolean(player))
      .filter((player) => player.id !== actor.id && player.isDemo !== true)
      .filter((player) =>
        acceptedLevels.length > 0
          ? acceptedLevels.includes(player.level)
          : isLevelCompatible(player.level, actor.level)
      )
      .slice(0, 20);

    await Promise.all(
      targets.map((player) =>
        sendNotification({
          recipientId: player.id,
          type: "team_seeking",
          actorId: actor.id,
          actorName: actor.name,
          message,
          route: "/"
        })
      )
    );
    return targets.length;
  } catch (error) {
    console.warn("[matchpoint] Fan-out de team_seeking falló", error);
    return 0;
  }
}

function normalizeNotificationTarget(id: string, data: unknown): Player | null {
  if (!data || typeof data !== "object") return null;
  const raw = data as Partial<Player>;
  if (!raw.name || !raw.level || !raw.city) return null;
  return { ...raw, id } as Player;
}

/** Suscripción en vivo a la bandeja del jugador (badge, toasts, lista). */
export function subscribeToMyNotifications(
  uid: string,
  onNext: (items: AppNotification[]) => void,
  onError?: (error: Error) => void
): Unsubscribe {
  if (!isFirebaseConfigured || !uid) return () => {};
  return onSnapshot(
    query(collection(db, COLLECTION_NAME), where("recipientId", "==", uid), limit(40)),
    (snapshot) => {
      const items = snapshot.docs
        .map((item) => normalizeNotification(item.id, item.data()))
        .filter((item): item is AppNotification => Boolean(item))
        .sort((a, b) => b.createdAt.localeCompare(a.createdAt));
      onNext(items);
    },
    (reason) => onError?.(reason instanceof Error ? reason : new Error(String(reason)))
  );
}

export async function markNotificationRead(id: string): Promise<void> {
  if (!isFirebaseConfigured) return;
  try {
    await updateDoc(doc(db, COLLECTION_NAME, id), { read: true, updatedAt: serverTimestamp() });
  } catch {
    // No crítico: el aviso simplemente seguirá marcado como no leído.
  }
}

export async function markAllNotificationsRead(items: AppNotification[]): Promise<void> {
  await Promise.all(items.filter((item) => !item.read).map((item) => markNotificationRead(item.id)));
}
