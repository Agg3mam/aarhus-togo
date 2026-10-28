import { QRCodeSVG } from 'qrcode.react';
import { Lock, Map as MapIcon } from 'lucide-react';
import { C, levelPercent, levelTitle, partnerList, summary, type Level } from '../lib/data';
import { L } from '../lib/i18n';
import { useDay } from '../lib/store';
import { useNav } from '../App';
import { catIcon, levelIcon, Tag } from '../ui/common';

/** QR-kupon med dagens rabat, de tre niveauer og partnerne. */
export default function Discounts() {
  const d = useDay();
  const nav = useNav();
  const level = d.level();
  const pct = level ? levelPercent[level] : 0;
  const date = new Date().toISOString().slice(0, 10).replace(/-/g, '');
  const code = `AARHUSTOGO-${date}-${pct}`;
  const LvIcon = level ? levelIcon[level] : Lock;
  const Store = catIcon.partenaire;

  return (
    <main className="screen">
      <div className="stack">
        <div style={{ paddingTop: 8 }}>
          <h1>{L('disc.title')}</h1>
          <p className="muted" style={{ margin: '4px 0 0' }}>{L('disc.subtitle')}</p>
        </div>

        <div className="card dark" style={{ display: 'flex', flexDirection: 'column', gap: 16, alignItems: 'center' }}>
          <div className="row" style={{ width: '100%', alignItems: 'flex-start' }}>
            <div style={{ flex: 1 }}>
              <div style={{ color: C.highlight, fontWeight: 600, fontSize: 14 }}>{L('disc.today')}</div>
              <div style={{ font: '800 48px/1.1 var(--display)' }}>{pct ? `−${pct} %` : '0 %'}</div>
              <div style={{ fontWeight: 600, color: 'rgba(255,255,255,.9)' }}>{level ? levelTitle(level) : L('home.level.locked')}</div>
            </div>
            <LvIcon size={30} color={C.highlight} />
          </div>
          <div style={{ position: 'relative' }}>
            <div style={{ background: '#fff', padding: 14, borderRadius: 20, filter: pct ? 'none' : 'blur(8px)', opacity: pct ? 1 : 0.35 }} role="img" aria-label={pct ? L('disc.qr.a11y', pct) : L('disc.locked')}>
              <QRCodeSVG value={code} size={180} />
            </div>
            {!pct && <div style={{ position: 'absolute', inset: 0, display: 'grid', placeItems: 'center', textAlign: 'center', padding: '0 24px', fontWeight: 600, fontSize: 14 }}>
              <div><Lock size={26} /><div style={{ marginTop: 8 }}>{d.trips().length ? L('disc.over') : L('disc.locked')}</div></div></div>}
          </div>
          <div className="small" style={{ color: 'rgba(255,255,255,.85)', fontVariantNumeric: 'tabular-nums' }}>{pct ? code : L('disc.hint')}</div>
          {!d.trips().length && <button className="pill secondary" onClick={() => nav.setTab('map')}><MapIcon size={18} />{L('home.trips.cta')}</button>}
        </div>

        <section style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          <h2>{L('disc.levels')}</h2>
          <p className="muted small" style={{ margin: 0 }}>{L('disc.nocar')}</p>
          {(['foret', 'prairie', 'ville'] as Level[]).map((l) => {
            const cur = level === l, I = levelIcon[l];
            return (
              <div key={l} className="card row" style={{ gap: 14, boxShadow: cur ? `inset 0 0 0 2px ${C.moss}` : undefined }}>
                <span style={{ width: 46, height: 46, borderRadius: '50%', display: 'grid', placeItems: 'center', background: cur ? C.moss : C.mossLight, color: cur ? '#fff' : C.moss, flex: 'none' }}><I size={19} /></span>
                <div style={{ flex: 1 }}>
                  <div className="row" style={{ gap: 6 }}><h3 style={{ fontSize: 17 }}>{levelTitle(l)}</h3>{cur && <Tag fg="#fff" bg={C.moss}>{L('disc.current')}</Tag>}</div>
                  <div className="muted small">{L(`disc.rule.${l}`)}</div>
                </div>
                <strong style={{ font: '800 20px var(--display)', color: C.moss }}>−{levelPercent[l]} %</strong>
              </div>
            );
          })}
        </section>

        <section style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          <h2>{L('disc.partners')}</h2>
          <div className="list">
            {partnerList.map((p) => (
              <button key={p.id} className="row" onClick={() => nav.show(p)} style={{ width: '100%', padding: '10px 16px', gap: 14, textAlign: 'left' }}>
                <span style={{ width: 44, height: 44, borderRadius: '50%', background: 'rgba(135,99,26,.12)', color: C.ochre, display: 'grid', placeItems: 'center', flex: 'none' }}><Store size={17} /></span>
                <span style={{ flex: 1 }}><strong style={{ fontSize: 15, display: 'block' }}>{p.name}</strong><span className="muted" style={{ fontSize: 13 }}>{summary(p)}</span></span>
                <MapIcon size={18} color={C.moss} />
              </button>
            ))}
          </div>
          <p className="muted" style={{ fontSize: 13, margin: 0 }}>{L('disc.partners.note')}</p>
        </section>
      </div>
    </main>
  );
}
