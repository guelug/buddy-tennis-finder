import { DEFAULT_WEEKLY_GOALS, normalizeWeeklyGoals, type WeeklyGoals } from "./gamification";

type Storage = { getItem(key: string): Promise<string | null>; setItem(key: string, value: string): Promise<void> };
const STORAGE_KEY = "matchpoint-weekly-goals";

/** A single shared snapshot; late disk reads never replace a newer user choice. */
export function createWeeklyGoalsStore(storage: Storage) {
  let cache: WeeklyGoals | null = null;
  let loading: Promise<WeeklyGoals> | null = null;
  let writing = Promise.resolve();
  const listeners = new Set<(value: WeeklyGoals) => void>();
  const get = () => cache ?? DEFAULT_WEEKLY_GOALS;
  const notify = () => listeners.forEach((listener) => listener(get()));

  function load(): Promise<WeeklyGoals> {
    if (cache) return Promise.resolve(cache);
    if (!loading) {
      loading = storage.getItem(STORAGE_KEY).then((stored) => {
        if (cache === null) {
          cache = stored ? normalizeWeeklyGoals(JSON.parse(stored)) : DEFAULT_WEEKLY_GOALS;
          notify();
        }
        return get();
      }).catch(() => {
        // Also preserve a user choice if the older read failed.
        if (cache === null) cache = DEFAULT_WEEKLY_GOALS;
        notify();
        return get();
      });
    }
    return loading;
  }

  function save(next: WeeklyGoals): Promise<void> {
    cache = normalizeWeeklyGoals(next);
    const serialized = JSON.stringify(cache);
    notify();
    // A failed write must not block subsequent preferences from being saved.
    writing = writing.then(() => storage.setItem(STORAGE_KEY, serialized)).catch(() => {});
    return writing;
  }

  return { get, load, save, subscribe(listener: (value: WeeklyGoals) => void) {
    listeners.add(listener);
    return () => { listeners.delete(listener); };
  } };
}
