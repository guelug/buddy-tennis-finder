/**
 * Lista de jugadores "buscando partido casual".
 *
 * Colección `teamSeekers/{uid}` — un documento por jugador que activa el
 * toggle. Ambos lados permanecen en la lista aunque se emparejen (para poder
 * ojearse), pero el auto-match avisa al que estaba primero.
 */
import {
  collection,
  deleteDoc,
  doc,
  getDocs,
  onSnapshot,
  query,
  serverTimestamp,
  setDoc,
  where,
  type Unsubscribe
} from "@react-native-firebase/firestore";
import { db, isFirebaseConfigured } from "@/../firebase.config";
import { findAutoMatch, type TeamSeeker } from "@/lib/auto-match";
import { loadNotificationPrefs } from "@/lib/notification-settings";
import { notifySound } from "@/lib/feedback";
import { notifyTeamSeeking, sendNotification } from "@/lib/notifications";
import type { Player } from "@/types";

const COLLECTION_NAME = "teamSeekers";

function readSeeker(id: string, data: unknown): TeamSeeker {
  const raw = (data ?? {}) as Partial<TeamSeeker>;
  return {
    id,
    name: String(raw.name ?? ""),
    level: (raw.level as TeamSeeker["level"]) ?? "c",
    city: String(raw.city ?? ""),
    clubIds: Array.isArray(raw.clubIds) ? raw.clubIds : [],
    seekingSince: typeof raw.seekingSince === "string" ? raw.seekingSince : new Date().toISOString()
  };
}

/** Activa "buscando rival". Devuelve el jugador emparejado automáticamente (o null). */
export async function startSeekingTeam(
  player: Player,
  messages: { autoMatch: (name: string) => string; teamSeeking: (name: string) => string }
): Promise<TeamSeeker | null> {
  if (!isFirebaseConfigured || player.isDemo) return null;
  const seeker: TeamSeeker = {
    id: player.id,
    name: player.name,
    level: player.level,
    city: player.city,
    clubIds: player.clubIds,
    seekingSince: new Date().toISOString()
  };
  try {
    await setDoc(doc(db, COLLECTION_NAME, player.id), {
      ...seeker,
      createdAt: serverTimestamp()
    });
  } catch (error) {
    console.warn("[matchpoint] No se pudo marcar como buscando equipo", error);
    return null;
  }

  // ¿Ya había alguien compatible buscando? El aviso va para el más antiguo.
  const existing = await listTeamSeekers(player.city).catch(() => [] as TeamSeeker[]);
  const match = findAutoMatch(seeker, existing);
  if (match) {
    const prefs = await loadNotificationPrefs();
    if (prefs.autoMatch) {
      void sendNotification({
        recipientId: match.id,
        type: "auto_match",
        actorId: player.id,
        actorName: player.name,
        message: messages.autoMatch(player.name),
        route: "/matches"
      });
    }
  }
  // El resto de compatibles de la ciudad recibe el aviso de búsqueda (tope 20
  // dentro de notifyTeamSeeking). Quien tiene teamSeeking apagado lo descarta
  // al leer su bandeja.
  void notifyTeamSeeking(player, [player.level], messages.teamSeeking(player.name));
  return match;
}

export async function stopSeekingTeam(uid: string): Promise<void> {
  if (!isFirebaseConfigured) return;
  try {
    await deleteDoc(doc(db, COLLECTION_NAME, uid));
  } catch (error) {
    console.warn("[matchpoint] No se pudo salir de la lista de búsqueda", error);
  }
}

export async function listTeamSeekers(city: string): Promise<TeamSeeker[]> {
  if (!isFirebaseConfigured || !city) return [];
  const snapshot = await getDocs(query(collection(db, COLLECTION_NAME), where("city", "==", city)));
  return snapshot.docs.map((item) => readSeeker(item.id, item.data()));
}

/** Suscripción en vivo a la lista de buscadores de la ciudad del jugador. */
export function subscribeToTeamSeekers(
  city: string | undefined,
  uid: string | undefined,
  onNext: (seekers: TeamSeeker[], iAmSeeking: boolean) => void
): Unsubscribe {
  if (!isFirebaseConfigured || !city || !uid) {
    onNext([], false);
    return () => {};
  }
  return onSnapshot(
    query(collection(db, COLLECTION_NAME), where("city", "==", city)),
    (snapshot) => {
      const seekers = snapshot.docs.map((item) => readSeeker(item.id, item.data()));
      const iAmSeeking = seekers.some((seeker) => seeker.id === uid);
      onNext(seekers, iAmSeeking);
    },
    () => onNext([], false)
  );
}

/** Aviso sonoro para nuevas entradas en la lista (lo llama la UI si procede). */
export function notifyNewSeeker() {
  void notifySound();
}
