import fr from '../generated/strings-fr.json';
import da from '../generated/strings-da.json';

export type Lang = 'fr' | 'da';
const tables: Record<Lang, Record<string, string>> = { fr, da };
const KEY = 'hyggevert.lang';

function read(): Lang {
  try { return localStorage.getItem(KEY) === 'da' ? 'da' : 'fr'; } catch { return 'fr'; }
}
let current: Lang = read();
const listeners = new Set<() => void>();

export const lang = () => current;
export function setLang(l: Lang) {
  current = l;
  try { localStorage.setItem(KEY, l); } catch { /* privat tilstand */ }
  document.documentElement.lang = l;
  listeners.forEach((f) => f());
}
export function subscribeLang(f: () => void) { listeners.add(f); return () => { listeners.delete(f); }; }
export const langNames: Record<Lang, string> = { fr: 'Français', da: 'Dansk' };
export const locale = () => (current === 'fr' ? 'fr-FR' : 'da-DK');

/** Slår en tekst op og udfylder %@, %ld, %1$@ og %% som i iPhone-appen. */
export function L(key: string, ...args: (string | number)[]): string {
  const fmt = tables[current][key] ?? tables.fr[key] ?? key;
  let i = 0;
  return fmt.replace(/%(?:(\d+)\$)?(@|ld|d)|%%/g, (m, pos) => {
    if (m === '%%') return '%';
    const v = args[pos ? Number(pos) - 1 : i++];
    return v === undefined ? '' : String(v);
  });
}

const num = (v: number, digits: number) =>
  v.toLocaleString(locale(), { minimumFractionDigits: digits, maximumFractionDigits: digits });

export const fmt = {
  km: (km: number) => (km < 1 ? `${Math.round((km * 1000) / 10) * 10} m` : `${num(km, km < 10 ? 1 : 0)} km`),
  co2: (g: number) => (g < 1000 ? `${Math.round(g)} g` : `${num(g / 1000, 1)} kg`),
  minutes: (min: number) => {
    const m = Math.max(1, Math.round(min));
    return m < 60 ? `${m} min` : `${Math.floor(m / 60)} h ${String(m % 60).padStart(2, '0')}`;
  },
  time: (d: Date) => d.toLocaleTimeString(locale(), { hour: '2-digit', minute: '2-digit' }),
  today: () => {
    const s = new Date().toLocaleDateString(locale(), { weekday: 'long', day: 'numeric', month: 'long' });
    return s.charAt(0).toUpperCase() + s.slice(1);
  },
};
