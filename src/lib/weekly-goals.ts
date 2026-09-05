/**
 * Objetivos semanales de los anillos, elegidos por cada persona.
 *
 * Se guardan en el dispositivo (AsyncStorage) igual que las preferencias de
 * notificación: son una preferencia personal, no un dato competitivo, y
 * llevarlos a Firestore costaría una lectura por arranque sin aportar nada.
 */
import { useEffect, useState } from "react";
import AsyncStorage from "@react-native-async-storage/async-storage";
import { createWeeklyGoalsStore } from "./weekly-goals-store";
import {
  DEFAULT_WEEKLY_GOALS,
  normalizeWeeklyGoals,
  type RingKey,
  type WeeklyGoals
} from "@/lib/gamification";

const store = createWeeklyGoalsStore(AsyncStorage);

export async function loadWeeklyGoals(): Promise<WeeklyGoals> {
  return store.load();
}

export async function saveWeeklyGoals(next: WeeklyGoals): Promise<void> {
  return store.save(next);
}

/** Hook reactivo: todas las pantallas con anillos comparten los mismos objetivos. */
export function useWeeklyGoals() {
  const [goals, setGoals] = useState<WeeklyGoals>(store.get);

  useEffect(() => {
    const unsubscribe = store.subscribe(setGoals);
    setGoals(store.get());
    void loadWeeklyGoals();
    return unsubscribe;
  }, []);

  const setGoal = (key: RingKey, value: number) => {
    const next = normalizeWeeklyGoals({ ...store.get(), [key]: value });
    void saveWeeklyGoals(next);
  };

  const reset = () => {
    void saveWeeklyGoals(DEFAULT_WEEKLY_GOALS);
  };

  return { goals, setGoal, reset };
}
