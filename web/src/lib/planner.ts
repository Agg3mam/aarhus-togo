import { AARHUS_H, grams, hubs, isTransit, km, limeZones, nearest, roadKm, speed, stops, type Hub, type LatLng, type LimeZone, type Mode, type Place, type Stop } from './data';
import { L } from './i18n';

export interface Leg {
  mode: Mode; from: LatLng; to: LatLng; km: number; minutes: number; title: string;
  path: LatLng[]; indicative: boolean;
}
export interface TripOption {
  id: string; mode: Mode; legs: Leg[]; destination: Place; overhead: number;
  hub?: Hub; zone?: LimeZone; stop?: Stop;
}

export const optMinutes = (o: TripOption) => o.legs.reduce((s, l) => s + l.minutes, o.overhead);
export const optTotalKm = (o: TripOption) => o.legs.reduce((s, l) => s + l.km, 0);
export const optGrams = (o: TripOption) => (o.mode === 'walk' ? 0 : grams(o.mode, o.legs.filter((l) => l.mode === o.mode).reduce((s, l) => s + l.km, 0)));
export const optMainKm = (o: TripOption) => (o.mode === 'walk' ? optTotalKm(o) : o.legs.filter((l) => l.mode !== 'walk').reduce((s, l) => s + l.km, 0));

function leg(m: Mode, a: LatLng, b: LatLng, title: string, indicative = false): Leg {
  const d = roadKm(a, b);
  return { mode: m, from: a, to: b, km: d, minutes: (d / speed[m]) * 60, title, path: [], indicative };
}

/** 2–4 grønne forslag efter laveste CO₂ og bilen til sidst – som Planner.swift. */
export function planOptions(origin: LatLng, place: Place, walkLimitKm = 3.2): TripOption[] {
  const crow = km(origin, place);
  const green: TripOption[] = [];
  let n = 0;
  const id = () => `${place.id}-${n++}`;

  if (crow * 1.3 <= walkLimitKm) green.push({ id: id(), mode: 'walk', destination: place, overhead: 0, legs: [leg('walk', origin, place, L('leg.walk.to', place.name))] });

  const hub = nearest(hubs, origin);
  if (crow <= 12 && hub && hub[1] <= 1.5) green.push({ id: id(), mode: 'donkey', destination: place, overhead: 2, hub: hub[0], legs: [
    leg('walk', origin, hub[0], L('leg.walk.donkey', hub[0].name)), leg('donkey', hub[0], place, L('leg.ride.to', place.name))] });

  const zone = nearest(limeZones, origin);
  if (crow <= 12 && zone && zone[1] <= 1.5) green.push({ id: id(), mode: 'lime', destination: place, overhead: 2, zone: zone[0], legs: [
    leg('walk', origin, zone[0], L('leg.walk.lime', zone[0].name)), leg('lime', zone[0], place, L('leg.ride.to', place.name))] });

  if (crow > 1.2) { const t = transit(origin, place, id()); if (t) green.push(t); }

  green.sort((a, b) => optGrams(a) - optGrams(b) || optMinutes(a) - optMinutes(b));
  const car = leg('car', origin, place, L('leg.car'));
  if (crow > 15) car.minutes = (car.km / 70) * 60;
  return [...green.slice(0, 4), { id: id(), mode: 'car', destination: place, overhead: 5, legs: [car] }];
}

function transit(origin: LatLng, place: Place, id: string): TripOption | null {
  if (km(origin, place) > 15 && place.greenTransport === 'train') {
    const station: Stop = { id: 'aarhus-h', name: 'Aarhus H', type: 'bus', ...AARHUS_H };
    return { id, mode: 'train', destination: place, overhead: 10, stop: station, legs: [
      leg('walk', origin, station, L('leg.walk.station')), leg('train', station, place, L('leg.train', place.area), true)] };
  }
  const trams = stops.filter((s) => s.type === 'tram');
  const nt = nearest(trams, origin), dt = nearest(trams, place);
  const useTram = (nt?.[1] ?? 9) <= 0.9 && ((dt?.[1] ?? 9) <= 1 || place.greenTransport === 'tram');
  const mode: Mode = useTram ? 'tram' : 'bus';
  const pool = useTram ? trams : stops;
  const start = nearest(pool, origin);
  if (!start || start[1] > 1.5) return null;
  const legs = [leg('walk', origin, start[0], L('leg.walk.stop', start[0].name))];
  const end = nearest(pool, place);
  if (end && end[1] <= 1.2 && end[0].id !== start[0].id) {
    legs.push(leg(mode, start[0], end[0], L('leg.transit', L(`mode.${mode}`), end[0].name), true));
    legs.push(leg('walk', end[0], place, L('leg.walk.to', place.name)));
  } else {
    legs.push(leg(mode, start[0], place, L('leg.transit.direct', L(`mode.${mode}`), place.area), true));
  }
  return { id, mode, destination: place, overhead: 6, stop: start[0], legs };
}

/** Rigtige gå- og cykelruter fra OSRM (routing.openstreetmap.de). Svarer den ikke på 8 s, bruges en lige linje. */
export async function route(o: TripOption): Promise<TripOption> {
  const legs = await Promise.all(o.legs.map(async (l): Promise<Leg> => {
    const profile = l.mode === 'walk' ? 'routed-foot' : ['bike', 'donkey', 'lime'].includes(l.mode) ? 'routed-bike' : null;
    if (!profile || l.indicative || isTransit(l.mode)) return { ...l, path: [l.from, l.to] };
    try {
      const ctl = new AbortController();
      const t = setTimeout(() => ctl.abort(), 8000);
      const res = await fetch(`https://routing.openstreetmap.de/${profile}/route/v1/driving/${l.from.lng},${l.from.lat};${l.to.lng},${l.to.lat}?overview=full&geometries=geojson`, { signal: ctl.signal });
      clearTimeout(t);
      const r = (await res.json()).routes?.[0];
      if (!r) throw new Error('ingen rute');
      const kmReal = r.distance / 1000;
      return { ...l, km: kmReal, minutes: l.mode === 'walk' ? r.duration / 60 : (kmReal / speed[l.mode]) * 60,
        path: r.geometry.coordinates.map(([lng, lat]: number[]) => ({ lat, lng })) };
    } catch {
      return { ...l, path: [l.from, l.to], indicative: true };
    }
  }));
  return { ...o, legs };
}
