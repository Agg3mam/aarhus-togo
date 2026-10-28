import { useEffect, useRef, useState } from 'react';
import { ArrowDown, BadgeCheck, Bike, CalendarPlus, Droplet, Globe, Lock, MoreHorizontal, Recycle, RotateCcw, UserRoundPen, Map as MapIcon } from 'lucide-react';
import { BUDGET, C, levelLimitKg, levelPercent, levelTitle, type Level } from '../lib/data';
import { fmt, L, langNames, setLang, type Lang } from '../lib/i18n';
import { useLocation } from '../lib/location';
import { displayName, recommendations, saveProfile, useDay, useProfile, type Trip } from '../lib/store';
import { useNav } from '../App';
import { levelIcon, modeIcon, Photo } from '../ui/common';

const tips = [['water', Droplet], ['pant', Recycle], ['bike', Bike], ['organic', BadgeCheck]] as const;

export default function Home() {
  const d = useDay();
  const profile = useProfile();
  const nav = useNav();
  const { origin } = useLocation();
  const level = d.level();
  const total = d.total();
  const recs = recommendations(profile, origin);

  return (
    <main className="screen">
      <div className="stack">
        <Header />
        <button className="card dark" onClick={() => nav.setTab('discounts')} style={{ display: 'flex', gap: 18, alignItems: 'center', textAlign: 'left', padding: '20px 18px' }}>
          <ZoneRing grams={total} />
          <div style={{ display: 'flex', flexDirection: 'column', gap: 6, minWidth: 0 }}>
            <span className="row" style={{ gap: 6, color: C.highlight, fontWeight: 600, fontSize: 14 }}>
              {level ? <LevelIcon l={level} /> : <Lock size={16} />}{level ? levelTitle(level) : L('home.level.locked')}
            </span>
            <span style={{ font: '800 38px/1 var(--display)', color: '#fff' }}>{level ? (levelPercent[level] ? `−${levelPercent[level]} %` : '0 %') : '−20 %'}</span>
            <span style={{ fontSize: 14, color: 'rgba(255,255,255,.85)' }}>{level ? nextStep(level, total, d.cappingMode()) : L('home.level.locked.sub')}</span>
            {d.saved() > 0 && <span className="tag" style={{ background: C.highlight, color: C.night, alignSelf: 'flex-start' }}><ArrowDown size={12} />{L('home.saved', fmt.co2(d.saved()))}</span>}
          </div>
        </button>

        {recs.length > 0 && (
          <section style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            <div><h2>{L('home.foryou')}</h2><p className="muted small" style={{ margin: '2px 0 0' }}>{L('home.foryou.sub')}</p></div>
            <div style={{ display: 'flex', gap: 12, overflowX: 'auto', margin: '0 -16px', padding: '0 16px', scrollPaddingInline: 16, scrollSnapType: 'x mandatory', scrollbarWidth: 'none' }}>
              <span style={{ flex: 'none', width: 0, marginRight: -12 }} aria-hidden />
              {recs.map((p) => (
                <button key={p.id} onClick={() => nav.show(p)} style={{ flex: 'none', width: 176, background: '#fff', borderRadius: 20, overflow: 'hidden', textAlign: 'left', scrollSnapAlign: 'start' }}>
                  <Photo place={p} height={104} />
                  <div style={{ padding: 12 }}>
                    <div style={{ font: '700 16px/1.2 var(--display)', minHeight: 38 }}>{p.name}</div>
                    <div className="muted small" style={{ marginTop: 6 }}>{L(`category.${p.category}`)}</div>
                  </div>
                </button>
              ))}
            </div>
          </section>
        )}

        <section style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          <h2>{L('home.trips')}</h2>
          {d.trips().length === 0 ? (
            <div className="card" style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
              <p className="muted" style={{ margin: 0 }}>{L('home.trips.empty')}</p>
              <button className="pill secondary" onClick={() => nav.setTab('map')}><MapIcon size={18} />{L('home.trips.cta')}</button>
            </div>
          ) : (
            <div className="list">{d.trips().map((t) => <TripRow key={t.id} t={t} />)}</div>
          )}
        </section>

        <section style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          <h2>{L('home.tips')}</h2>
          <div className="list" style={{ padding: '4px 18px' }}>
            {tips.map(([id, Icon]) => (
              <div key={id} className="row" style={{ padding: '14px 0', alignItems: 'flex-start', gap: 14 }}>
                <span style={{ width: 44, height: 44, borderRadius: 14, background: C.fjordLight, color: C.fjord, display: 'grid', placeItems: 'center', flex: 'none' }}><Icon size={19} /></span>
                <div>
                  <h3 style={{ fontSize: 16 }}>{L(`tip.${id}.title`)}</h3>
                  <p className="muted small" style={{ margin: '3px 0 0' }}>{L(`tip.${id}.body`)}</p>
                </div>
              </div>
            ))}
          </div>
        </section>
      </div>
    </main>
  );
}

const LevelIcon = ({ l }: { l: Level }) => { const I = levelIcon[l]; return <I size={16} />; };

function nextStep(level: Level, total: number, capping: string | null) {
  if (capping) return level === 'none' ? L('home.capped.car', L(`mode.phrase.${capping}`)) : L('home.capped', L(`mode.phrase.${capping}`), levelTitle(level));
  const left = levelLimitKg[level] * 1000 - total;
  if (level === 'foret') return L('home.next', fmt.co2(left), levelTitle('prairie'));
  if (level === 'prairie') return L('home.next', fmt.co2(left), levelTitle('ville'));
  if (level === 'ville') return L('home.next.end', fmt.co2(left));
  return L('home.next.over', fmt.co2(total - BUDGET));
}

function Header() {
  const profile = useProfile();
  const d = useDay();
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const close = (e: PointerEvent) => { if (!ref.current?.contains(e.target as Node)) setOpen(false); };
    document.addEventListener('pointerdown', close);
    return () => document.removeEventListener('pointerdown', close);
  }, []);
  return (
    <header className="row" style={{ alignItems: 'flex-start', paddingTop: 8 }}>
      <div style={{ flex: 1 }}>
        <div className="muted small" style={{ fontWeight: 500 }}>{fmt.today()}</div>
        <h1>{L('home.hello', displayName(profile))}</h1>
      </div>
      <div ref={ref} style={{ position: 'relative' }}>
        <button className="icon-btn" aria-label={L('home.menu')} aria-expanded={open} onClick={() => setOpen(!open)}><MoreHorizontal size={20} /></button>
        {open && (
          <div className="menu" role="menu">
            <div className="menu-row muted small"><Globe size={16} />{L('settings.language')}</div>
            {(['fr', 'da'] as Lang[]).map((l) => <button key={l} onClick={() => setLang(l)} style={{ paddingLeft: 40 }}>{langNames[l]}</button>)}
            <button onClick={() => saveProfile(null)}><UserRoundPen size={16} />{L('home.menu.profile')}</button>
            <button onClick={() => { d.example(); setOpen(false); }}><CalendarPlus size={16} />{L('home.menu.example')}</button>
            <button className="danger" onClick={() => { if (confirm(L('home.reset.title'))) { d.reset(); setOpen(false); } }}><RotateCcw size={16} />{L('home.menu.reset')}</button>
          </div>
        )}
      </div>
    </header>
  );
}

function TripRow({ t }: { t: Trip }) {
  const Icon = modeIcon[t.mode];
  const car = t.mode === 'car';
  return (
    <div className="row" style={{ padding: '10px 16px', gap: 14 }}>
      <span style={{ width: 44, height: 44, borderRadius: '50%', display: 'grid', placeItems: 'center', background: car ? 'rgba(181,80,46,.1)' : C.mossLight, color: car ? C.car : C.moss, flex: 'none' }}><Icon size={18} /></span>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontWeight: 600, fontSize: 15 }}>{t.title}</div>
        <div className="muted" style={{ fontSize: 13 }}>{L('trip.row', L(`mode.phrase.${t.mode}`), fmt.km(t.km), fmt.time(new Date(t.date)))}</div>
      </div>
      <strong style={{ fontSize: 15, color: t.grams === 0 ? C.moss : C.ink }}>{fmt.co2(t.grams)}</strong>
    </div>
  );
}

/** Ringen er rabatsystemet: sporet er delt i Forêt (0–2 kg), Prairie (2–5) og Ville (5–8). */
export function ZoneRing({ grams }: { grams: number }) {
  const size = 144, line = 12, r = (size - line) / 2, c = 2 * Math.PI * r, gap = 0.012;
  const zones: [number, number, number][] = [[0, 2 / 8, 0.5], [2 / 8, 5 / 8, 0.28], [5 / 8, 1, 0.14]];
  const f = Math.min(1, grams / BUDGET);
  const color = grams > BUDGET ? '#F0A07F' : C.highlight;
  const arc = (from: number, to: number) => ({ strokeDasharray: `${(to - from) * c} ${c}`, strokeDashoffset: -from * c });
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} role="img" aria-label={L('home.ring.a11y', fmt.co2(grams), fmt.co2(BUDGET))} style={{ flex: 'none' }}>
      <g transform={`rotate(-90 ${size / 2} ${size / 2})`} fill="none" strokeWidth={line}>
        {zones.map(([a, b, o]) => <circle key={a} cx={size / 2} cy={size / 2} r={r} stroke={C.highlight} strokeOpacity={o} {...arc(a + gap / 2, b - gap / 2)} />)}
        <circle cx={size / 2} cy={size / 2} r={r} stroke={color} strokeLinecap="round" {...arc(0, Math.max(0.002, f))} style={{ transition: 'stroke-dasharray .9s cubic-bezier(.2,.8,.2,1)' }} />
      </g>
      {[2, 5].map((kg) => { const a = (kg / 8) * 2 * Math.PI - Math.PI / 2; return <text key={kg} x={size / 2 + Math.cos(a) * (r - 20)} y={size / 2 + Math.sin(a) * (r - 20) + 4} textAnchor="middle" fill="rgba(255,255,255,.75)" fontSize="11" fontWeight="600">{kg}</text>; })}
      <text x={size / 2} y={size / 2 + 2} textAnchor="middle" fill="#fff" style={{ font: '800 24px var(--display)' }}>{fmt.co2(grams)}</text>
      <text x={size / 2} y={size / 2 + 20} textAnchor="middle" fill="rgba(255,255,255,.8)" fontSize="12" fontWeight="500">{L('home.ring.of', fmt.co2(BUDGET))}</text>
    </svg>
  );
}

