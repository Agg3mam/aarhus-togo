import placesFile from '../generated/places.json';
import partnersFile from '../generated/partners.json';
import stopsFile from '../generated/stops.json';
import hubsFile from '../generated/donkey-hubs.json';
import limeFile from '../generated/lime-zones.json';
import factorsFile from '../generated/co2-factors.json';
import creditsFile from '../generated/photo-credits.json';
import { L, lang } from './i18n';

export type Mode = 'walk' | 'bike' | 'donkey' | 'lime' | 'tram' | 'bus' | 'train' | 'car';
export type Category = 'nature' | 'musee' | 'secret' | 'partenaire' | 'excursion' | 'restaurant' | 'cafe' | 'activite';
export interface LatLng { lat: number; lng: number }

export interface Place extends LatLng {
  id: string; name: string; category: Category; area: string; greenTransport: Mode;
  isHiddenGem: boolean; description_fr: string; description_da?: string; demo?: boolean; organic?: boolean;
}
export interface Stop extends LatLng { id: string; name: string; type: 'bus' | 'tram' }
export interface Hub extends LatLng { id: string; name: string; deeplink: string | null; demo: boolean }
export interface LimeZone extends LatLng { id: string; name: string; radius_m: number; demo: boolean }
interface Partner extends LatLng { id: string; name: string; kind: string; offer_fr: string; offer_da?: string; demo: boolean }
export interface Credit { file: string; author: string; license: string; url: string }

export const AARHUS_H: LatLng = { lat: 56.150001, lng: 10.203561 };

const partners = (partnersFile.partners as Partner[]).map<Place>((p) => ({
  id: p.id, name: p.name, category: 'partenaire', area: '', greenTransport: 'walk', isHiddenGem: false,
  description_fr: p.offer_fr, description_da: p.offer_da, demo: true, lat: p.lat, lng: p.lng,
}));
export const partnerList = partners;
export const places = [...(placesFile.places as Place[]), ...partners];
export const stops = stopsFile.stops as Stop[];
export const hubs = hubsFile.hubs as Hub[];
export const limeZones = limeFile.zones as LimeZone[];
export const credits = creditsFile as Record<string, Credit>;
const factors = Object.fromEntries(Object.entries(factorsFile.factors).map(([k, v]) => [k, (v as { g_per_km: number }).g_per_km]));

export const grams = (m: Mode, km: number) => (factors[m] ?? 0) * km;
export const summary = (p: Place) => (lang() === 'da' ? p.description_da ?? p.description_fr : p.description_fr);
export const area = (p: Place) => (p.category === 'partenaire' ? L('common.example') : p.area);
export const photo = (p: Place) => (credits[p.id] ? `${import.meta.env.BASE_URL}img/${p.id}.jpg` : null);

/** Andre steder på præcis samme punkt (fx caféen i et museum). */
export const colocated = (p: Place) => places.filter((x) => x.id !== p.id && x.lat === p.lat && x.lng === p.lng);
/** Ét punkt pr. position til kortet. */
export const mapPlaces = (() => {
  const seen = new Set<string>();
  return places.filter((p) => { const k = `${p.lat},${p.lng}`; if (seen.has(k)) return false; seen.add(k); return true; });
})();

// MARK: Afstand
export function km(a: LatLng, b: LatLng) {
  const r = Math.PI / 180;
  const dLat = (b.lat - a.lat) * r, dLng = (b.lng - a.lng) * r;
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(a.lat * r) * Math.cos(b.lat * r) * Math.sin(dLng / 2) ** 2;
  return 2 * 6371 * Math.asin(Math.min(1, Math.sqrt(h)));
}
export const roadKm = (a: LatLng, b: LatLng) => km(a, b) * 1.3;
export function nearest<T extends LatLng>(items: T[], p: LatLng): [T, number] | null {
  let best: [T, number] | null = null;
  for (const it of items) { const d = km(p, it); if (!best || d < best[1]) best = [it, d]; }
  return best;
}

// MARK: Rejseformer og kategorier
export const modes: Mode[] = ['walk', 'bike', 'donkey', 'lime', 'tram', 'bus', 'train', 'car'];
export const speed: Record<Mode, number> = { walk: 4.8, bike: 15, donkey: 15, lime: 18, tram: 22, bus: 20, train: 65, car: 32 };
export const isBike = (m: Mode) => m === 'bike' || m === 'donkey' || m === 'lime';
export const isTransit = (m: Mode) => m === 'tram' || m === 'bus' || m === 'train';

export const C = {
  bg: '#F3F5F0', surface: '#FFFFFF', ink: '#15241B', ink2: '#4F5E55', moss: '#2E6B45', fjord: '#1D5675',
  mossLight: '#E3EEE5', fjordLight: '#E0ECF2', night: '#15241B', highlight: '#9BD3AE', car: '#B5502E',
  ochre: '#87631A', plum: '#7A3E6E', teal: '#2B6B70',
};
export const modeColor = (m: Mode) => (m === 'walk' ? C.fjord : isBike(m) ? C.moss : m === 'car' ? C.car : C.night);
export const catColor: Record<Category, string> = {
  nature: C.moss, musee: C.fjord, secret: C.night, partenaire: C.ochre, excursion: C.ink2,
  restaurant: C.plum, cafe: C.plum, activite: C.teal,
};
export const catIconColor = (c: Category) => (c === 'secret' ? C.highlight : '#fff');

// MARK: Rabatniveauer
export type Level = 'foret' | 'prairie' | 'ville' | 'none';
export const levelOrder: Level[] = ['foret', 'prairie', 'ville', 'none'];
export const levelPercent: Record<Level, number> = { foret: 20, prairie: 10, ville: 5, none: 0 };
export const levelLimitKg: Record<Level, number> = { foret: 2, prairie: 5, ville: 8, none: 0 };
export const levelTitle = (l: Level) => L(`level.${l}`);
export const BUDGET = 8000;

function byGrams(g: number): Level { return g <= 2000 ? 'foret' : g <= 5000 ? 'prairie' : g <= 8000 ? 'ville' : 'none'; }
/** Gang/cykel −20 %, Lime og offentlig transport højst −10 %, bil ingen rabat. */
export const levelCap = (m: Mode): Level => (m === 'walk' || m === 'bike' || m === 'donkey' ? 'foret' : m === 'car' ? 'none' : 'prairie');
export function levelFor(g: number, ms: Mode[]): Level {
  const worst = Math.max(levelOrder.indexOf(byGrams(g)), ...ms.map((m) => levelOrder.indexOf(levelCap(m))));
  return levelOrder[worst];
}
export const levelByGramsOnly = byGrams;
