import { useState } from 'react';
import { CheckCircle2, ChevronLeft, ChevronRight, Clock, Info, Leaf, Map as MapIcon, Navigation, Sparkles, Route as RouteIcon, Bike, Zap, Bus, TramFront } from 'lucide-react';
import type { ReactNode } from 'react';
import { C, area, catColor, catIconColor, colocated, credits, grams, isBike, isTransit, levelPercent, levelTitle, modeColor, roadKm, summary, type Hub, type LimeZone, type Place, type Stop, type Level } from '../lib/data';
import { fmt, L } from '../lib/i18n';
import { links, open } from '../lib/links';
import { currentOrigin, requestLocation, useLocation } from '../lib/location';
import { optGrams, optMainKm, optMinutes, planOptions, route as fetchRoute, type TripOption } from '../lib/planner';
import { day, useDay, useProfile, walkLimit } from '../lib/store';
import { CatBadge, Credit, ExampleTag, LeafBadge, modeIcon, OrganicTag, Photo, Tag, catIcon } from '../ui/common';

type Step = 'info' | 'locating' | 'options' | 'chosen';

export default function PlaceSheet({ place, onRoute, onDone }: { place: Place; onRoute: (o: TripOption | null) => void; onDone: () => void }) {
  const loc = useLocation();
  const profile = useProfile();
  const d = useDay();
  const [step, setStep] = useState<Step>('info');
  const [options, setOptions] = useState<TripOption[]>([]);
  const [chosen, setChosen] = useState<TripOption | null>(null);
  const [loading, setLoading] = useState(false);
  const [askMaps, setAskMaps] = useState(false);

  async function go() {
    setStep('locating');
    await requestLocation();
    // Regn fra den nyeste placering (hook-værdien er fra før tilladelsen).
    setOptions(planOptions(currentOrigin(), place, walkLimit(profile)));
    setStep('options');
  }

  async function choose(o: TripOption) {
    setChosen(o); setStep('chosen'); setLoading(true); onRoute(o);
    const r = await fetchRoute(o);
    setChosen((c) => (c?.id === o.id ? r : c));
    onRoute(r);
    setLoading(false);
  }

  function finish(o: TripOption) {
    day.add({ title: L('trip.to', place.name), mode: o.mode, km: optMainKm(o), grams: optGrams(o) });
    onDone();
  }

  const mapsMode = chosen?.mode ?? place.greenTransport;
  const mapsChooser = askMaps && (
    <div className="card" style={{ display: 'flex', flexDirection: 'column', gap: 8, boxShadow: 'inset 0 0 0 1px var(--hair)' }}>
      <strong>{L('go.maps.title')}</strong>
      <a className="pill quiet" href={links.google(place, mapsMode)} target="_blank" rel="noopener">Google Maps</a>
      <a className="pill quiet" href={links.apple(place, mapsMode)} target="_blank" rel="noopener">{L('go.maps.plans')}</a>
    </div>
  );

  if (step === 'locating') return <p className="muted" style={{ textAlign: 'center', padding: 40 }}>{L('go.locating')}</p>;

  if (step === 'options') {
    return (
      <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
        <Back onClick={() => setStep('info')}>{L('go.back.info')}</Back>
        <h2 style={{ font: '800 24px/1.15 var(--display)' }}>{L('go.options.title', place.name)}</h2>
        <span className="row muted small"><Navigation size={14} />{loc.fallback ? L('go.origin.demo') : L('go.origin.you')}</span>
        {options.map((o, i) => <OptionCard key={o.id} o={o} best={i === 0 && o.mode !== 'car'} after={d.levelAdding(optGrams(o), o.mode)} onClick={() => choose(o)} />)}
      </div>
    );
  }

  if (step === 'chosen' && chosen) {
    const o = chosen;
    const note = o.mode === 'donkey' ? L('go.note.donkey') : o.mode === 'lime' ? L('go.note.lime') : isTransit(o.mode) ? L('go.note.ticket') : null;
    return (
      <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
        <Back onClick={() => { setStep('options'); onRoute(null); }}>{L('go.back.options')}</Back>
        <div className="row" style={{ gap: 14 }}>
          {isBike(o.mode) ? <LeafBadge size={52} /> : <ModeDot o={o} />}
          <div>
            <h2 style={{ font: '800 22px var(--display)' }}>{L(`mode.${o.mode}`)}</h2>
            <span className="row muted" style={{ gap: 14, fontWeight: 600, fontSize: 15 }}>
              <span className="row" style={{ gap: 4 }}><Clock size={15} />{fmt.minutes(optMinutes(o))}</span>
              <span className="row" style={{ gap: 4 }}><Leaf size={15} />{fmt.co2(optGrams(o))}</span>
              {loading && <span className="tiny">…</span>}
            </span>
          </div>
        </div>
        <div className="card">
          {o.legs.map((l, i) => {
            const Icon = modeIcon[l.mode];
            return (
              <div key={i} className="row" style={{ alignItems: 'flex-start', gap: 12, paddingBottom: i < o.legs.length - 1 ? 12 : 0 }}>
                <span style={{ width: 30, height: 30, borderRadius: '50%', background: modeColor(l.mode), color: '#fff', display: 'grid', placeItems: 'center', flex: 'none' }}><Icon size={14} /></span>
                <div>
                  <div style={{ fontWeight: 600, fontSize: 15 }}>{l.title}</div>
                  <div className="muted" style={{ fontSize: 13 }}>{L('leg.meta', fmt.minutes(l.minutes), fmt.km(l.km))}</div>
                  {l.indicative && isTransit(l.mode) && <div className="muted tiny">{L('leg.indicative')}</div>}
                </div>
              </div>
            );
          })}
        </div>
        {note && <div className="card row" style={{ background: C.fjordLight, borderRadius: 18, alignItems: 'flex-start' }}><Info size={18} color={C.fjord} style={{ flex: 'none' }} /><span className="small">{note}</span></div>}
        {o.legs.some((l) => l.indicative && !isTransit(l.mode)) && <p className="muted tiny" style={{ margin: 0 }}>{L('go.note.offline')}</p>}
        {o.mode === 'donkey' && <a className="pill secondary" href={links.donkey(o.hub)} target="_blank" rel="noopener"><Bike size={18} />{L('go.open.donkey')}</a>}
        {o.mode === 'lime' && <a className="pill secondary" href={links.limeStore} target="_blank" rel="noopener"><Zap size={18} />{L('go.open.lime')}</a>}
        {isTransit(o.mode) && <>
          <a className="pill secondary" href={links.google(place, 'bus')} target="_blank" rel="noopener"><RouteIcon size={18} />{L('go.transit.route')}</a>
          <div className="row"><a className="pill quiet" href={links.midttrafik} target="_blank" rel="noopener">{L('go.open.midttrafik')}</a><a className="pill quiet" href={links.rejsebillet} target="_blank" rel="noopener">{L('go.open.ticket')}</a></div>
        </>}
        <button className="pill quiet" onClick={() => setAskMaps(!askMaps)}><MapIcon size={18} />{L('go.maps')}</button>
        {mapsChooser}
        <button className="pill dark" onClick={() => finish(o)}><CheckCircle2 size={18} />{L('go.arrived')}</button>
      </div>
    );
  }

  // 1. Info
  const dist = roadKm(loc.origin, place);
  const M = modeIcon[place.greenTransport];
  const here = colocated(place);
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
      {credits[place.id] && <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
        <div style={{ borderRadius: 20, overflow: 'hidden' }}><Photo place={place} height={180} /></div>
        <Credit place={place} />
      </div>}
      <div className="row" style={{ gap: 6, flexWrap: 'wrap' }}>
        <Tag fg={catIconColor(place.category)} bg={catColor[place.category]} icon={catIcon[place.category]}>{L(`category.${place.category}`)}</Tag>
        {place.isHiddenGem && place.category !== 'secret' && <Tag fg={C.highlight} bg={C.night} icon={Sparkles}>{L('category.secret')}</Tag>}
        {place.organic && <OrganicTag />}
        {place.demo && <ExampleTag />}
      </div>
      <div>
        <h2 style={{ font: '800 26px/1.1 var(--display)' }}>{place.name}</h2>
        <div className="muted small" style={{ fontWeight: 500, marginTop: 4 }}>{area(place)}</div>
      </div>
      <p style={{ margin: 0 }}>{summary(place)}</p>
      {here.length > 0 && (
        <div className="card" style={{ padding: 14, borderRadius: 14 }}>
          <div className="muted small" style={{ fontWeight: 600, marginBottom: 8 }}>{L('go.alsohere')}</div>
          {here.map((p) => <div key={p.id} className="row" style={{ gap: 10 }}><CatBadge c={p.category} size={30} radius={9} /><strong style={{ fontSize: 15 }}>{p.name}</strong>{p.organic && <OrganicTag />}</div>)}
        </div>
      )}
      <div className="row" style={{ gap: 10, alignItems: 'stretch' }}>
        <Stat icon={<Navigation size={15} />} value={fmt.km(dist)} label={loc.fallback ? L('go.from.demo') : L('go.from.you')} />
        <Stat icon={<M size={15} />} value={L(`mode.short.${place.greenTransport}`)} label={L('go.suggested')} />
        <Stat icon={<Leaf size={15} />} value={fmt.co2(grams(place.greenTransport, dist))} label={L('go.co2')} />
      </div>
      <button className="pill primary" onClick={go}><Navigation size={18} />{L('go.cta')}</button>
      <button className="pill quiet" onClick={() => setAskMaps(!askMaps)}><MapIcon size={18} />{L('go.maps')}</button>
      {mapsChooser}
    </div>
  );
}

function Back({ children, onClick }: { children: ReactNode; onClick: () => void }) {
  return <button className="row" onClick={onClick} style={{ color: C.moss, fontWeight: 600, minHeight: 44, gap: 4, alignSelf: 'flex-start' }}><ChevronLeft size={18} />{children}</button>;
}

function Stat({ icon, value, label }: { icon: ReactNode; value: string; label: string }) {
  return <div style={{ flex: 1, background: '#fff', borderRadius: 14, padding: 12, display: 'flex', flexDirection: 'column', gap: 6, color: C.moss, minWidth: 0 }}>
    {icon}<strong style={{ color: C.ink, fontSize: 15, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{value}</strong><span className="muted tiny">{label}</span>
  </div>;
}

function ModeDot({ o }: { o: TripOption }) {
  const Icon = modeIcon[o.mode];
  return <span style={{ width: 52, height: 52, borderRadius: '50%', background: modeColor(o.mode), color: '#fff', display: 'grid', placeItems: 'center' }}><Icon size={22} /></span>;
}

function OptionCard({ o, best, after, onClick }: { o: TripOption; best: boolean; after: Level; onClick: () => void }) {
  const car = o.mode === 'car';
  const Icon = modeIcon[o.mode];
  const summaryText = o.legs.map((l) => `${fmt.minutes(l.minutes)} ${L(`mode.phrase.${l.mode}`)}`).join(' + ');
  return (
    <button className="card" onClick={onClick} disabled={car} style={{ textAlign: 'left', display: 'flex', flexDirection: 'column', gap: 12, opacity: car ? 0.72 : 1, boxShadow: best ? `inset 0 0 0 2px ${C.moss}` : undefined, cursor: car ? 'default' : 'pointer' }}>
      <div className="row" style={{ gap: 12 }}>
        <span style={{ width: 46, height: 46, borderRadius: '50%', display: 'grid', placeItems: 'center', background: car ? 'rgba(181,80,46,.1)' : modeColor(o.mode), color: car ? C.car : '#fff', flex: 'none' }}><Icon size={19} /></span>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div className="row" style={{ gap: 6, flexWrap: 'wrap' }}>
            <h3>{L(`mode.${o.mode}`)}</h3>
            {best && <Tag fg="#fff" bg={C.moss}>{L('go.best')}</Tag>}
            {o.zone?.demo && <ExampleTag />}
          </div>
          <div className="muted" style={{ fontSize: 13 }}>{summaryText}</div>
        </div>
        {!car && <ChevronRight color={C.ink2} />}
      </div>
      <div className="row" style={{ gap: 8 }}>
        <Tag fg={C.ink} bg={C.bg} icon={Clock}>{fmt.minutes(optMinutes(o))}</Tag>
        <Tag fg={car ? C.car : C.moss} bg={car ? 'rgba(181,80,46,.1)' : C.mossLight} icon={Leaf}>{fmt.co2(optGrams(o))}</Tag>
        <span className="spacer" />
        <span style={{ fontSize: 12, fontWeight: 600, color: car ? C.car : C.fjord }}>
          {car ? L('go.compare') : levelPercent[after] > 0 ? `${levelTitle(after)} −${levelPercent[after]} %` : levelTitle(after)}
        </span>
      </div>
    </button>
  );
}

// MARK: Transportpunkt
type TSel = { kind: 'stop'; stop: Stop } | { kind: 'hub'; hub: Hub } | { kind: 'lime'; zone: LimeZone };
export function TransportSheet({ sel }: { sel: TSel }) {
  const head = (Icon: typeof Bus, color: string, kind: string, name: string, tag: string, example = false) => (
    <div className="row" style={{ gap: 14 }}>
      <span style={{ width: 50, height: 50, borderRadius: 14, background: color, color: '#fff', display: 'grid', placeItems: 'center' }}><Icon size={22} /></span>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 4, alignItems: 'flex-start' }}>
        <span className="muted small" style={{ fontWeight: 600 }}>{kind}</span>
        <h2 style={{ font: '800 22px var(--display)' }}>{name}</h2>
        {example ? <ExampleTag /> : <Tag fg={C.fjord} bg={C.fjordLight}>{tag}</Tag>}
      </div>
    </div>
  );
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
      {sel.kind === 'stop' && <>
        {head(sel.stop.type === 'tram' ? TramFront : Bus, sel.stop.type === 'tram' ? C.night : C.fjord, L(sel.stop.type === 'tram' ? 'transport.tram' : 'transport.bus'), sel.stop.name, L('transport.source.osm'))}
        <p style={{ margin: 0 }}>{L('go.note.ticket')}</p>
        <button className="pill secondary" onClick={() => open(links.google(sel.stop, 'walk'))}><RouteIcon size={18} />{L('go.transit.route')}</button>
        <div className="row"><a className="pill quiet" href={links.midttrafik} target="_blank" rel="noopener">{L('go.open.midttrafik')}</a><a className="pill quiet" href={links.rejsebillet} target="_blank" rel="noopener">{L('go.open.ticket')}</a></div>
      </>}
      {sel.kind === 'hub' && <>
        {head(Bike, C.moss, L('transport.donkey'), sel.hub.name, L('transport.source.gbfs'), sel.hub.demo)}
        <p style={{ margin: 0 }}>{L('transport.donkey.body')}</p>
        <a className="pill primary" href={links.donkey(sel.hub)} target="_blank" rel="noopener"><Bike size={18} />{L('go.open.donkey')}</a>
      </>}
      {sel.kind === 'lime' && <>
        {head(Zap, C.moss, L('transport.lime'), sel.zone.name, '', true)}
        <p style={{ margin: 0 }}>{L('transport.lime.body')}</p>
        <a className="pill primary" href={links.limeStore} target="_blank" rel="noopener"><Zap size={18} />{L('go.open.lime')}</a>
      </>}
    </div>
  );
}
