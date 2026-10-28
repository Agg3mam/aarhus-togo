import type { ReactNode } from 'react';
import {
  Bike, Building2, Bus, Car, CloudOff, Coffee, Drama, Footprints, Landmark, Leaf, Lock, Map, Sparkles, Store,
  TrainFront, TramFront, TreePine, UtensilsCrossed, Zap, type LucideIcon,
} from 'lucide-react';
import { C, catColor, catIconColor, credits, photo, type Category, type Level, type Mode, type Place } from '../lib/data';
import { L } from '../lib/i18n';

export const modeIcon: Record<Mode, LucideIcon> = {
  walk: Footprints, bike: Bike, donkey: Bike, lime: Zap, tram: TramFront, bus: Bus, train: TrainFront, car: Car,
};
export const catIcon: Record<Category, LucideIcon> = {
  nature: Leaf, musee: Landmark, secret: Sparkles, partenaire: Store, excursion: Map,
  restaurant: UtensilsCrossed, cafe: Coffee, activite: Drama,
};
export const levelIcon: Record<Level, LucideIcon> = { foret: TreePine, prairie: Leaf, ville: Building2, none: CloudOff };
export const LockIcon = Lock;

export function Tag({ children, fg = C.moss, bg = C.mossLight, icon: Icon }: { children: ReactNode; fg?: string; bg?: string; icon?: LucideIcon }) {
  return <span className="tag" style={{ color: fg, background: bg }}>{Icon && <Icon size={12} strokeWidth={2.4} />}{children}</span>;
}
export const OrganicTag = ({ dark = false }) => (
  <Tag fg={dark ? C.night : C.moss} bg={dark ? C.highlight : C.mossLight} icon={Leaf}>{L('tag.organic')}</Tag>
);
export const ExampleTag = () => <Tag fg={C.ochre} bg="rgba(135,99,26,.12)">{L('common.example')}</Tag>;

export function CatBadge({ c, size = 48, radius = 14 }: { c: Category; size?: number; radius?: number }) {
  const Icon = catIcon[c];
  return <span style={{ width: size, height: size, borderRadius: radius, background: catColor[c], color: catIconColor(c), display: 'grid', placeItems: 'center', flex: 'none' }}>
    <Icon size={size * 0.42} strokeWidth={2} /></span>;
}

/** Stedets foto, eller kategoriens farve og ikon. */
export function Photo({ place, height }: { place: Place; height: number }) {
  const src = photo(place);
  if (src) return <img className="photo" src={src} alt="" style={{ height }} loading="lazy" />;
  const Icon = catIcon[place.category];
  return <div style={{ height, background: catColor[place.category], color: catIconColor(place.category), display: 'grid', placeItems: 'center', opacity: 1 }}>
    <Icon size={height * 0.3} strokeWidth={1.4} style={{ opacity: .85 }} /></div>;
}

/** Fotograf og licens med link til Commons, som licenserne kræver. */
export function Credit({ place, dark = false }: { place: Place; dark?: boolean }) {
  const c = credits[place.id];
  if (!c) return null;
  return <a className="credit" href={c.url} target="_blank" rel="noopener" style={dark ? { color: 'rgba(255,255,255,.8)' } : undefined}>
    {c.author ? L('photo.credit', c.author, c.license) : L('photo.credit.noauthor', c.license)}</a>;
}

export function LeafBadge({ size = 44 }: { size?: number }) {
  return <span className="leaf" style={{ width: size, height: size }} aria-hidden><Leaf size={size * 0.48} fill={C.highlight} strokeWidth={1.5} /></span>;
}

export function ModeCircle({ m, size = 44, color }: { m: Mode; size?: number; color?: string }) {
  const Icon = modeIcon[m];
  return <span style={{ width: size, height: size, borderRadius: '50%', background: color ?? C.moss, color: '#fff', display: 'grid', placeItems: 'center', flex: 'none' }}>
    <Icon size={size * 0.42} /></span>;
}
