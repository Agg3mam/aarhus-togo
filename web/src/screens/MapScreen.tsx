import { useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { MapContainer, TileLayer, Marker, Polyline, Circle, useMap, useMapEvents } from 'react-leaflet';
import L_ from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { Bike, Bus, MapPin, TramFront, X, Zap } from 'lucide-react';
import { C, catColor, catIconColor, hubs, limeZones, mapPlaces, modeColor, stops, type Hub, type LatLng, type LimeZone, type Place, type Stop } from '../lib/data';
import { L } from '../lib/i18n';
import { requestLocation, useLocation } from '../lib/location';
import type { TripOption } from '../lib/planner';
import { useNav } from '../App';
import { catIcon } from '../ui/common';
import PlaceSheet, { TransportSheet } from './PlaceSheet';

type Sel = { kind: 'place'; place: Place } | { kind: 'stop'; stop: Stop } | { kind: 'hub'; hub: Hub } | { kind: 'lime'; zone: LimeZone };

const iconCache = new Map<string, L_.DivIcon>();
function divIcon(key: string, html: () => ReactNode, size: number, anchorBottom = false) {
  if (!iconCache.has(key)) {
    iconCache.set(key, L_.divIcon({ html: renderToStaticMarkup(<>{html()}</>), className: '', iconSize: [size, size], iconAnchor: [size / 2, anchorBottom ? size : size / 2] }));
  }
  return iconCache.get(key)!;
}
const placeIcon = (p: Place, selected: boolean) => {
  const s = selected ? 44 : 34;
  return divIcon(`p-${p.category}-${selected}`, () => {
    const I = catIcon[p.category];
    return <div className="marker" style={{ width: s, height: s, background: catColor[p.category], color: catIconColor(p.category) }}><I size={s * 0.45} strokeWidth={2.2} /></div>;
  }, s, true);
};
const stopIcon = (t: 'bus' | 'tram') => t === 'tram'
  ? divIcon('tram', () => <div className="marker" style={{ width: 24, height: 24, borderRadius: 7, borderWidth: 1.5, background: C.night, color: C.highlight }}><TramFront size={13} /></div>, 24)
  : divIcon('bus', () => <div className="marker" style={{ width: 17, height: 17, borderWidth: 1.5, background: C.fjord, color: '#fff' }}><Bus size={9} /></div>, 17);
const hubIcon = divIcon('hub', () => <div className="marker" style={{ width: 19, height: 19, borderRadius: 5, borderWidth: 1.5, background: C.moss, color: '#fff' }}><Bike size={10} /></div>, 19);
const limeIcon = divIcon('lime', () => <div className="marker" style={{ width: 19, height: 19, borderWidth: 1.5, background: '#fff', color: C.moss, borderColor: C.moss }}><Zap size={10} /></div>, 19);
const youIcon = divIcon('you', () => <div style={{ width: 16, height: 16, borderRadius: '50%', background: C.fjord, border: '3px solid #fff', boxShadow: `0 0 8px ${C.fjord}` }} />, 16);

const AARHUS: [number, number] = [56.146, 10.2];
const selKey = (s: Sel) => (s.kind === 'place' ? s.place.id : s.kind === 'stop' ? s.stop.id : s.kind === 'hub' ? 'h' + s.hub.id : s.zone.id);

export default function MapScreen() {
  const nav = useNav();
  const { origin } = useLocation();
  const [showPlaces, setShowPlaces] = useState(true);
  const [showTransport, setShowTransport] = useState(true);
  const [sel, setSel] = useState<Sel | null>(null);
  const [route, setRoute] = useState<TripOption | null>(null);
  const [view, setView] = useState<{ zoom: number; bounds: L_.LatLngBounds | null }>({ zoom: 13, bounds: null });
  const mapRef = useRef<L_.Map | null>(null);

  useEffect(() => { requestLocation(); }, []);

  const open = (s: Sel) => {
    setRoute(null);
    setSel(s);
    if (s.kind === 'place') reveal(s.place);
  };
  const reveal = (p: LatLng) => {
    const m = mapRef.current; if (!m) return;
    const z = Math.max(m.getZoom(), 14);
    const pt = m.project([p.lat, p.lng], z).add([0, window.innerHeight * 0.22]);
    m.flyTo(m.unproject(pt, z), z, { duration: 0.7 });
  };

  // "Voir sur la carte" fra Explorer eller forsiden.
  useEffect(() => {
    if (!nav.focus) return;
    const p = nav.focus; nav.clearFocus();
    const t = setTimeout(() => open({ kind: 'place', place: p }), 150);
    return () => clearTimeout(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [nav.focus]);

  // Vis hele ruten over bundarket.
  useEffect(() => {
    const m = mapRef.current; if (!m || !route) return;
    const pts = route.legs.flatMap((l) => (l.path.length ? l.path : [l.from, l.to]));
    m.flyToBounds(L_.latLngBounds(pts.map((p) => [p.lat, p.lng])), { paddingTopLeft: [30, 90], paddingBottomRight: [30, window.innerHeight * 0.5], duration: 0.8 });
  }, [route]);

  const visibleTransport = useMemo(() => {
    const trams = stops.filter((s) => s.type === 'tram');
    if (view.zoom < 15 || !view.bounds) return { trams, buses: [] as Stop[], hubs: [] as Hub[], limes: [] as LimeZone[] };
    const inB = (p: LatLng) => view.bounds!.contains([p.lat, p.lng]);
    return { trams, buses: stops.filter((s) => s.type === 'bus' && inB(s)).slice(0, 150), hubs: hubs.filter(inB).slice(0, 150), limes: limeZones.filter(inB) };
  }, [view]);

  const selectedPlace = sel?.kind === 'place' ? sel.place : null;

  return (
    <div style={{ position: 'fixed', inset: 0 }}>
      <MapContainer center={AARHUS} zoom={13} zoomControl={false} style={{ height: '100%' }} ref={mapRef}>
        {/* OpenStreetMaps egne fliser: gratis og uden nøgle (følg tile.openstreetmap.org's brugsregler). */}
        <TileLayer url="https://tile.openstreetmap.org/{z}/{x}/{y}.png" maxZoom={19}
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>' />
        <ViewWatcher onChange={setView} />

        {route && route.legs.map((l, i) => (
          <Polyline key={i} positions={(l.path.length ? l.path : [l.from, l.to]).map((p): [number, number] => [p.lat, p.lng])}
            pathOptions={{ color: modeColor(l.mode), weight: l.mode === 'walk' ? 5 : 6, dashArray: l.mode === 'walk' ? '1 9' : l.indicative ? '12 8' : undefined, lineCap: 'round' }} />
        ))}

        {showTransport && !route && <>
          {limeZones.map((z) => <Circle key={z.id} center={[z.lat, z.lng]} radius={z.radius_m} pathOptions={{ color: C.moss, weight: 1.5, dashArray: '4 4', fillOpacity: 0.12, opacity: 0.6 }} />)}
          {visibleTransport.trams.concat(visibleTransport.buses).map((s) => <Marker key={s.id} position={[s.lat, s.lng]} icon={stopIcon(s.type)} eventHandlers={{ click: () => open({ kind: 'stop', stop: s }) }} title={s.name} />)}
          {visibleTransport.hubs.map((h) => <Marker key={h.id} position={[h.lat, h.lng]} icon={hubIcon} eventHandlers={{ click: () => open({ kind: 'hub', hub: h }) }} title={h.name} />)}
          {visibleTransport.limes.map((z) => <Marker key={z.id} position={[z.lat, z.lng]} icon={limeIcon} eventHandlers={{ click: () => open({ kind: 'lime', zone: z }) }} title={z.name} />)}
        </>}

        {route ? (
          <Marker position={[route.destination.lat, route.destination.lng]} icon={placeIcon(route.destination, true)} />
        ) : showPlaces && mapPlaces.filter((p) => view.zoom >= 15 || (p.category !== 'restaurant' && p.category !== 'cafe') || selectedPlace?.id === p.id).map((p) => (
          <Marker key={p.id} position={[p.lat, p.lng]} icon={placeIcon(p, selectedPlace?.id === p.id)} title={p.name}
            zIndexOffset={selectedPlace?.id === p.id ? 1000 : 0} eventHandlers={{ click: () => open({ kind: 'place', place: p }) }} />
        ))}

        <Marker position={[origin.lat, origin.lng]} icon={youIcon} interactive={false} />
      </MapContainer>

      <div className="row" style={{ position: 'absolute', top: 'calc(env(safe-area-inset-top) + 10px)', left: 16, right: 16, zIndex: 700 }}>
        <span className="icon-btn" style={{ width: 'auto', borderRadius: 99, padding: '0 16px', font: '800 22px var(--display)' }}>{L('map.title')}</span>
        <span className="spacer" />
        <button className={`icon-btn ${showPlaces ? 'on' : ''}`} aria-pressed={showPlaces} aria-label={L('map.layer.places')} onClick={() => setShowPlaces(!showPlaces)}><MapPin size={19} /></button>
        <button className={`icon-btn ${showTransport ? 'on' : ''}`} aria-pressed={showTransport} aria-label={L('map.layer.transport')} onClick={() => setShowTransport(!showTransport)}><TramFront size={19} /></button>
      </div>

      {sel && (
        <Sheet key={selKey(sel)} expanded={!!route} onClose={() => { setSel(null); setRoute(null); }}>
          {sel.kind === 'place'
            ? <PlaceSheet place={sel.place} onRoute={setRoute} onDone={() => { setSel(null); setRoute(null); }} />
            : <TransportSheet sel={sel} />}
        </Sheet>
      )}
    </div>
  );
}

function ViewWatcher({ onChange }: { onChange: (v: { zoom: number; bounds: L_.LatLngBounds }) => void }) {
  const map = useMap();
  const emit = () => onChange({ zoom: map.getZoom(), bounds: map.getBounds() });
  useMapEvents({ moveend: emit, zoomend: emit });
  useEffect(emit, []); // eslint-disable-line react-hooks/exhaustive-deps
  return null;
}

/** Bundark med to højder; håndtaget skifter mellem dem, og man kan trække det ned for at lukke. */
function Sheet({ children, onClose, expanded }: { children: ReactNode; onClose: () => void; expanded: boolean }) {
  const [full, setFull] = useState(false);
  const start = useRef<number | null>(null);
  useEffect(() => { if (expanded) setFull(false); }, [expanded]);
  const h = full ? '92vh' : expanded ? '46vh' : '58vh';
  return (
    <section className="sheet" style={{ height: `calc(${h} + var(--tabbar))` }} aria-modal="false" role="dialog">
      <div className="grab" onClick={() => setFull(!full)}
        onPointerDown={(e) => { start.current = e.clientY; }}
        onPointerUp={(e) => { if (start.current === null) return; const dy = e.clientY - start.current; start.current = null;
          if (dy > 60) { if (full) setFull(false); else onClose(); } else if (dy < -40) setFull(true); }}>
        <span />
      </div>
      <button className="icon-btn close" onClick={onClose} aria-label={L('go.back.info')} style={{ width: 36, height: 36 }}><X size={18} /></button>
      <div className="body" onScroll={(e) => { if ((e.target as HTMLElement).scrollTop > 40 && !full) setFull(true); }}>{children}</div>
    </section>
  );
}
