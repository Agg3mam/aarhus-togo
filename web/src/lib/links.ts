import type { Hub, LatLng, Mode, Place } from './data';

// App Store-id'er slået op i iTunes Search API (country=dk). Universelle links åbner appen, hvis den findes.
export const links = {
  donkeyStore: 'https://apps.apple.com/dk/app/id933526449',
  limeStore: 'https://apps.apple.com/dk/app/id1199780189',
  midttrafik: 'https://apps.apple.com/dk/app/id1290197423',
  rejsebillet: 'https://apps.apple.com/dk/app/id1664432486',
  donkey: (h?: Hub) => h?.deeplink ?? 'https://apps.apple.com/dk/app/id933526449',
  google(to: LatLng, m: Mode) {
    const travel = m === 'walk' ? 'walking' : ['bike', 'donkey', 'lime'].includes(m) ? 'bicycling' : m === 'car' ? 'driving' : 'transit';
    return `https://www.google.com/maps/dir/?api=1&destination=${to.lat},${to.lng}&travelmode=${travel}`;
  },
  apple(p: Place, m: Mode) {
    const flag = m === 'walk' ? 'w' : m === 'car' ? 'd' : ['bike', 'donkey', 'lime'].includes(m) ? 'c' : 'r';
    return `https://maps.apple.com/?daddr=${p.lat},${p.lng}&dirflg=${flag}&q=${encodeURIComponent(p.name)}`;
  },
};
export const open = (url: string) => window.open(url, '_blank', 'noopener');
