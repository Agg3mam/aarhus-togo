import { useState } from 'react';
import { PlusCircle } from 'lucide-react';
import { C, grams, isBike, levelPercent, levelTitle, modes, type Mode } from '../lib/data';
import { fmt, L } from '../lib/i18n';
import { useDay } from '../lib/store';
import { LeafBadge, levelIcon, modeIcon } from '../ui/common';

/** CO₂-beregner: vælg rejseform og distance, se udledningen mod bilen og rabatniveauet bagefter. */
export default function TripCalculator() {
  const d = useDay();
  const [mode, setMode] = useState<Mode>('bike');
  const [dist, setDist] = useState(5);
  const g = grams(mode, dist), car = grams('car', dist);
  const after = d.levelAdding(g, mode);
  const AfterIcon = levelIcon[after];

  return (
    <main className="screen">
      <div className="stack">
        <div style={{ paddingTop: 8 }}>
          <h1>{L('trip.title')}</h1>
          <p className="muted" style={{ margin: '4px 0 0' }}>{L('trip.subtitle')}</p>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 10 }}>
          {modes.map((m) => {
            const on = m === mode, I = modeIcon[m];
            return (
              <button key={m} aria-pressed={on} onClick={() => setMode(m)} style={{ minHeight: 76, borderRadius: 16, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 6,
                background: on ? (m === 'car' ? C.car : C.moss) : C.surface, color: on ? '#fff' : m === 'car' ? C.car : C.ink, fontSize: 13, fontWeight: 600 }}>
                {on && isBike(m) ? <LeafBadge size={34} /> : <I size={20} />}{L(`mode.short.${m}`)}
              </button>
            );
          })}
        </div>

        <div className="card" style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          <div className="row"><span className="muted" style={{ fontWeight: 600 }}>{L('trip.distance')}</span><span className="spacer" /><strong style={{ font: '800 24px var(--display)' }}>{fmt.km(dist)}</strong></div>
          <input type="range" min={0.5} max={60} step={0.5} value={dist} onChange={(e) => setDist(+e.target.value)} aria-label={L('trip.distance')} style={{ accentColor: C.moss }} />
          <div className="row" style={{ gap: 8 }}>
            {[2, 5, 10, 25, 44].map((v) => <button key={v} onClick={() => setDist(v)} style={{ flex: 1, minHeight: 44, borderRadius: 99, fontWeight: 600, fontSize: 13, background: dist === v ? C.fjord : C.bg, color: dist === v ? '#fff' : C.ink }}>{fmt.km(v)}</button>)}
          </div>
        </div>

        <div className="card dark" style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
          <div className="row" style={{ alignItems: 'baseline' }}><strong style={{ font: '800 40px var(--display)' }}>{fmt.co2(g)}</strong><span style={{ color: 'rgba(255,255,255,.85)' }}>{L('trip.co2')}</span></div>
          <Bar label={L(`mode.${mode}`)} g={g} max={car} color={mode === 'car' ? '#F0A07F' : C.highlight} />
          {mode !== 'car' && <>
            <Bar label={L('mode.car')} g={car} max={car} color="#F0A07F" />
            <span style={{ color: C.highlight, fontWeight: 600 }}>{L('trip.saved', fmt.co2(car - g), Math.round(((car - g) / car) * 100))}</span>
          </>}
          <hr style={{ border: 0, borderTop: '1px solid rgba(255,255,255,.15)', margin: 0, width: '100%' }} />
          <div className="row" style={{ gap: 12 }}>
            <span style={{ width: 44, height: 44, borderRadius: '50%', background: C.highlight, color: C.night, display: 'grid', placeItems: 'center' }}><AfterIcon size={18} /></span>
            <div style={{ flex: 1 }}>
              <div className="small" style={{ color: 'rgba(255,255,255,.85)' }}>{L('trip.after')}</div>
              <strong style={{ font: '700 18px var(--display)' }}>{levelPercent[after] ? `${levelTitle(after)}, −${levelPercent[after]} %` : levelTitle(after)}</strong>
            </div>
            <span className="small" style={{ color: 'rgba(255,255,255,.85)', textAlign: 'right', whiteSpace: 'pre-line' }}>{L('trip.day.total', fmt.co2(d.total() + g))}</span>
          </div>
        </div>

        <button className="pill primary" onClick={() => d.add({ title: L('trip.free', fmt.km(dist)), mode, km: dist, grams: g })}><PlusCircle size={18} />{L('trip.add')}</button>
      </div>
    </main>
  );
}

function Bar({ label, g, max, color }: { label: string; g: number; max: number; color: string }) {
  return (
    <div>
      <div className="row small" style={{ fontWeight: 600 }}><span>{label}</span><span className="spacer" /><span>{fmt.co2(g)}</span></div>
      <div style={{ height: 10, borderRadius: 5, background: 'rgba(255,255,255,.12)', marginTop: 5 }}>
        <div style={{ height: 10, borderRadius: 5, background: color, width: `${Math.max(2, max ? (g / max) * 100 : 0)}%`, transition: 'width .4s' }} />
      </div>
    </div>
  );
}
