/**
 * Objetivos semanales de los anillos, elegidos por cada persona.
 *
 * Se guardan en el dispositivo (AsyncStorage) igual que las preferencias de
 * notificación: son una preferencia personal, no un dato competitivo, y
 * llevarlos a Firestore costaría una lectura por arranque sin aportar nada.
 */
import { useEffect, useState } from "react";
import AsyncStorage from "@react-native-async-storage/async-storage";
import {
  DEFAULT_WEEKLY_GOALS,
  normalizeWeeklyGoals,
  type RingKey,
  type WeeklyGoals
} from "@/lib/gamification";

const STORAGE_KEY = "matchpoint-weekly-goals";
const listeners = new Set<(goals: WeeklyGoals) => void>();
let cache: WeeklyGoals | null = null;

export async function loadWeeklyGoals(): Promise<WeeklyGoals> {
  if (cache) return cache;
  try {
    const stored = await AsyncStorage.getItem(STORAGE_KEY);
    cache = stored ? normalizeWeeklyGoals(JSON.parse(stored) as Partial<WeeklyGoals>) : DEFAULT_WEEKLY_GOALS;
  } catch {
    // Un valor corrupto o sin permiso de lectura no debe dejar la pantalla en blanco.
    cache = DEFAULT_WEEKLY_GOALS;
  }
  return cache;
}

export async function saveWeeklyGoals(next: WeeklyGoals): Promise<void> {
  const normalized = normalizeWeeklyGoals(next);
  cache = normalized;
  listeners.forEach((listener) => listener(normalized));
  try {
    await AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(normalized));
  } catch {
    // El valor en memoria sigue sirviendo para esta sesión.
  }
}

/** Hook reactivo: todas las pantallas con anillos comparten los mismos objetivos. */
export function useWeeklyGoals() {
  const [goals, setGoals] = useState<WeeklyGoals>(cache ?? DEFAULT_WEEKLY_GOALS);

  useEffect(() => {
    let active = true;
    void loadWeeklyGoals().then((value) => {
      if (active) setGoals(value);
    });
    const listener = (next: WeeklyGoals) => setGoals(next);
    listeners.add(listener);
    return () => {
      active = false;
      listeners.delete(listener);
    };
  }, []);

  const setGoal = (key: RingKey, value: number) => {
    const next = normalizeWeeklyGoals({ ...goals, [key]: value });
    setGoals(next);
    void saveWeeklyGoals(next);
  };

  const reset = () => {
    setGoals(DEFAULT_WEEKLY_GOALS);
    void saveWeeklyGoals(DEFAULT_WEEKLY_GOALS);
  };

  return { goals, setGoal, reset };
}
