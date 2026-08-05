/**
 * Preferencias de notificación del jugador. Se guardan en el dispositivo
 * (AsyncStorage) y se aplican en el momento de recibir/disparar avisos.
 *
 * Todo arranca ACTIVADO por defecto, tal como pide el producto: las
 * notificaciones son el motor del matchmaking y solo se apagan a propósito.
 */
import { useEffect, useState } from "react";
import AsyncStorage from "@react-native-async-storage/async-storage";

export type NotificationPrefs = {
  /** Alguien publica que busca equipo/partido casual en mi ciudad y división. */
  teamSeeking: boolean;
  /** Alguien pide unirse a un partido que yo he publicado (interés recibido). */
  matchInterest: boolean;
  /** Se ha emparejado automáticamente a alguien conmigo (auto-match). */
  autoMatch: boolean;
  /** Sonido de pelota al recibir un aviso (además de la vibración). */
  sound: boolean;
};

export const DEFAULT_NOTIFICATION_PREFS: NotificationPrefs = {
  teamSeeking: true,
  matchInterest: true,
  autoMatch: true,
  sound: true
};

const STORAGE_KEY = "matchpoint-notification-prefs";
const listeners = new Set<(prefs: NotificationPrefs) => void>();
let cache: NotificationPrefs | null = null;

export async function loadNotificationPrefs(): Promise<NotificationPrefs> {
  try {
    const stored = await AsyncStorage.getItem(STORAGE_KEY);
    if (!stored) return DEFAULT_NOTIFICATION_PREFS;
    const parsed = JSON.parse(stored) as Partial<NotificationPrefs>;
    // Claves nuevas que el usuario aún no tiene → siempre activadas.
    return { ...DEFAULT_NOTIFICATION_PREFS, ...parsed };
  } catch {
    return DEFAULT_NOTIFICATION_PREFS;
  }
}

export async function saveNotificationPrefs(next: NotificationPrefs): Promise<void> {
  cache = next;
  listeners.forEach((listener) => listener(next));
  // El motor de sonido/vibración necesita el valor sin pasar por AsyncStorage.
  try {
    const { refreshFeedbackPrefs } = await import("@/lib/feedback");
    refreshFeedbackPrefs(next);
  } catch {
    // El módulo puede no estar cargado todavía en arranque muy temprano.
  }
  try {
    await AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(next));
  } catch {
    // El estado en memoria sigue valiendo para esta sesión.
  }
}

/**
 * Hook reactivo: devuelve las preferencias actuales y un setter parcial.
 * Mantiene todas las pantallas (settings, badge, motor de avisos) sincronizadas.
 */
export function useNotificationPrefs() {
  const [prefs, setPrefs] = useState<NotificationPrefs>(cache ?? DEFAULT_NOTIFICATION_PREFS);

  useEffect(() => {
    let active = true;
    void loadNotificationPrefs().then((value) => {
      if (active) setPrefs(value);
    });
    const listener = (next: NotificationPrefs) => setPrefs(next);
    listeners.add(listener);
    return () => {
      active = false;
      listeners.delete(listener);
    };
  }, []);

  const update = (patch: Partial<NotificationPrefs>) => {
    const next = { ...prefs, ...patch };
    setPrefs(next);
    void saveNotificationPrefs(next);
  };

  return { prefs, update };
}
