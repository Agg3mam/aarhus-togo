import { useSyncExternalStore } from 'react';
import { AARHUS_H, km, type LatLng } from './data';

/** Brugerens placering. Mangler den, eller er den langt fra Aarhus, bruges Aarhus H, så demoen altid virker. */
let real: LatLng | null = null;
let asked = false;
const ls = new Set<() => void>();
let snapshot = { origin: AARHUS_H, fallback: true };

function update() {
  const fallback = !real || km(real, AARHUS_H) > 40;
  snapshot = { origin: fallback ? AARHUS_H : real!, fallback };
  ls.forEach((f) => f());
}

export function requestLocation(): Promise<void> {
  if (!('geolocation' in navigator)) return Promise.resolve();
  asked = true;
  return new Promise((resolve) => {
    navigator.geolocation.getCurrentPosition(
      (p) => { real = { lat: p.coords.latitude, lng: p.coords.longitude }; update(); resolve(); },
      () => resolve(),
      { enableHighAccuracy: false, timeout: 6000, maximumAge: 60000 },
    );
  });
}
export const locationAsked = () => asked;
export const currentOrigin = () => snapshot.origin;
export const useLocation = () => useSyncExternalStore((f) => { ls.add(f); return () => { ls.delete(f); }; }, () => snapshot);
