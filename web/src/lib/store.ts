import { useSyncExternalStore } from 'react';
import { grams, levelByGramsOnly, levelCap, levelFor, places, km as distKm, type LatLng, type Level, type Mode, type Place } from './data';
import { L, subscribeLang, lang } from './i18n';

/** Lille butik med localStorage, så web-udgaven husker dagen og profilen som appen. */
function persisted<T>(key: string, initial: T) {
  let value: T = initial;
  try { const raw = localStorage.getItem(key); if (raw) value = JSON.parse(raw); } catch { /* privat tilstand */ }
  const ls = new Set<() => void>();
  return {
    get: () => value,
    set: (v: T) => { value = v; try { localStorage.setItem(key, JSON.stringify(v)); } catch { /* ignoreres */ } ls.forEach((f) => f()); },
    subscribe: (f: () => void) => { ls.add(f); return () => { ls.delete(f); }; },
  };
}

// MARK: Dagens ture
export interface Trip { id: string; date: string; title: string; mode: Mode; km: number; grams: number }
const tripsStore = persisted<Trip[]>('hyggevert.trips.v1', []);
const isToday = (iso: string) => new Date(iso).toDateString() === new Date().toDateString();

export interface Celebration { id: string; before: Level | null; after: Level }
const celebrationStore = persisted<Celebration | null>('hyggevert.celebration', null);

export const day = {
  trips: () => tripsStore.get().filter((t) => isToday(t.date)),
  total: () => day.trips().reduce((s, t) => s + t.grams, 0),
  level: (): Level | null => (day.trips().length ? levelFor(day.total(), day.trips().map((t) => t.mode)) : null),
  levelAdding: (g: number, m: Mode) => levelFor(day.total() + g, [...day.trips().map((t) => t.mode), m]),
  saved: () => day.trips().reduce((s, t) => s + grams('car', t.km) - t.grams, 0),
  /** Rejseformen, der holder rabatten nede, hvis det ikke er CO₂-grænsen. */
  cappingMode: (): Mode | null => {
    const lv = day.level();
    if (!lv || levelByGramsOnly(day.total()) === lv) return null;
    return day.trips().map((t) => t.mode).find((m) => levelCap(m) === lv) ?? null;
  },
  add(t: Omit<Trip, 'id' | 'date'>) {
    const before = day.level();
    tripsStore.set([{ ...t, id: crypto.randomUUID(), date: new Date().toISOString() }, ...day.trips()]);
    celebrationStore.set({ id: crypto.randomUUID(), before, after: day.level() ?? 'none' });
  },
  reset: () => tripsStore.set([]),
  example() {
    const at = (h: number, m: number) => { const d = new Date(); d.setHours(h, m, 0, 0); return d.toISOString(); };
    tripsStore.set([
      { id: 'ex2', date: at(11, 40), title: L('example.trip2'), mode: 'tram', km: 4.2, grams: grams('tram', 4.2) },
      { id: 'ex1', date: at(9, 15), title: L('example.trip1'), mode: 'bus', km: 44, grams: grams('bus', 44) },
    ]);
  },
  dismissCelebration: () => celebrationStore.set(null),
};
export const useDay = () => { useSyncExternalStore(tripsStore.subscribe, tripsStore.get); return day; };
export const useCelebration = () => useSyncExternalStore(celebrationStore.subscribe, celebrationStore.get);

// MARK: Profil fra spørgeskemaet
export type Interest = 'cuisine' | 'shopping' | 'musee' | 'nature' | 'activite';
export type Company = 'family' | 'friends' | 'familyKids' | 'solo' | 'agency';
export interface Profile { name: string; interests: Interest[]; budgetEuro: number; age: number; company: Company | null }
export const emptyProfile: Profile = { name: '', interests: [], budgetEuro: 800, age: 30, company: null };
const profileStore = persisted<Profile | null>('hyggevert.profile.v1', null);
export const useProfile = () => useSyncExternalStore(profileStore.subscribe, profileStore.get);
export const saveProfile = (p: Profile | null) => profileStore.set(p);

const shoppingIDs = new Set(['latinerkvarteret', 'salling-rooftop', 'street-food', 'godsbanen', 'aarhus-o']);
const kidIDs = new Set(['tivoli-friheden', 'den-gamle-by', 'moesgaard', 'naturhistorisk', 'marselisborg', 'dokk1', 'botanisk-have', 'aarhus-oje', 'steno', 'ballehage']);

export function matches(i: Interest, p: Place) {
  switch (i) {
    case 'cuisine': return p.category === 'restaurant' || p.category === 'cafe';
    case 'shopping': return shoppingIDs.has(p.id);
    case 'musee': return p.category === 'musee';
    case 'nature': return p.category === 'nature' || (p.category === 'secret' && p.id !== 'godsbanen');
    case 'activite': return p.category === 'activite' || p.category === 'excursion';
  }
}
export function score(pr: Profile, p: Place) {
  if (p.category === 'partenaire') return 0;
  let s = pr.interests.some((i) => matches(i, p)) ? 3 : 0;
  const c = p.category;
  if (pr.company === 'familyKids' && kidIDs.has(p.id)) s += 2;
  if (pr.company === 'family' && (c === 'musee' || c === 'nature')) s += 1;
  if (pr.company === 'friends' && (c === 'activite' || c === 'restaurant' || c === 'cafe')) s += 1;
  if (pr.company === 'solo' && p.isHiddenGem) s += 1;
  if (pr.company === 'agency' && c === 'excursion') s += 1;
  if (pr.budgetEuro < 300 && (c === 'nature' || c === 'secret')) s += 1;
  if (pr.budgetEuro > 2000 && (c === 'excursion' || p.organic)) s += 1;
  return s;
}
export const displayName = (p: Profile | null) => p?.name.trim() || 'Camille';
export const walkLimit = (p: Profile | null) => ((p?.age ?? 30) >= 65 ? 1.6 : 3.2);
export function recommendations(p: Profile | null, origin: LatLng, limit = 8) {
  if (!p) return [];
  return places.map((x) => [x, score(p, x)] as const).filter(([, s]) => s > 0)
    .sort((a, b) => b[1] - a[1] || distKm(origin, a[0]) - distKm(origin, b[0])).slice(0, limit).map(([x]) => x);
}

// MARK: Sprog som hook
export const useLang = () => useSyncExternalStore(subscribeLang, lang);
