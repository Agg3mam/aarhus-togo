import { useState } from 'react';
import { Map as MapIcon, Sparkles } from 'lucide-react';
import { C, area, credits, km, places, roadKm, summary, type Place } from '../lib/data';
import { fmt, L } from '../lib/i18n';
import { useLocation } from '../lib/location';
import { score, useProfile } from '../lib/store';
import { useNav } from '../App';
import { CatBadge, Credit, ExampleTag, modeIcon, OrganicTag, Photo, Tag } from '../ui/common';

const filters = ['all', 'foryou', 'nature', 'musee', 'restaurant', 'activite', 'organic', 'secret', 'excursion', 'partenaire'] as const;
type Filter = typeof filters[number];

export default function Explore() {
  const [filter, setFilter] = useState<Filter>('all');
  const { origin } = useLocation();
  const profile = useProfile();
  const nav = useNav();
  const match = (p: Place) => {
    switch (filter) {
      case 'all': return true;
      case 'foryou': return !!profile && score(profile, p) > 0;
      case 'secret': return p.isHiddenGem;
      case 'organic': return !!p.organic;
      case 'restaurant': return p.category === 'restaurant' || p.category === 'cafe';
      default: return p.category === filter;
    }
  };
  const list = places.filter(match).sort((a, b) => km(origin, a) - km(origin, b));

  return (
    <main className="screen">
      <div className="stack" style={{ gap: 14 }}>
        <div style={{ paddingTop: 8 }}>
          <h1>{L('explore.title')}</h1>
          <p className="muted" style={{ margin: '4px 0 0' }}>{L('explore.subtitle')}</p>
        </div>
        <div className="chips" role="toolbar">
          {filters.map((f) => <button key={f} className={`chip ${filter === f ? 'on' : ''}`} aria-pressed={filter === f} onClick={() => setFilter(f)}>{L(`explore.filter.${f}`)}</button>)}
        </div>
        {list.map((p) => <PlaceCard key={p.id} p={p} dist={roadKm(origin, p)} onMap={() => nav.show(p)} />)}
      </div>
    </main>
  );
}

function PlaceCard({ p, dist, onMap }: { p: Place; dist: number; onMap: () => void }) {
  const secret = p.isHiddenGem;
  const M = modeIcon[p.greenTransport];
  const meta = secret ? C.highlight : C.ink2;
  return (
    <article style={{ background: secret ? C.night : C.surface, color: secret ? '#fff' : C.ink, borderRadius: 20, overflow: 'hidden' }}>
      {credits[p.id] && <Photo place={p} height={150} />}
      <div style={{ padding: 18, display: 'flex', flexDirection: 'column', gap: 12 }}>
        <div className="row" style={{ alignItems: 'flex-start', gap: 14 }}>
          <CatBadge c={p.category} />
          <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
            <h3>{p.name}</h3>
            <span style={{ fontSize: 13, fontWeight: 500, color: meta }}>{L('explore.meta', area(p), fmt.km(dist))}</span>
            {(secret || p.organic || p.demo) && <div className="row" style={{ gap: 6, flexWrap: 'wrap' }}>
              {p.organic && <OrganicTag dark={secret} />}
              {secret && <Tag fg={C.night} bg={C.highlight} icon={Sparkles}>{L('category.secret')}</Tag>}
              {p.demo && <ExampleTag />}
            </div>}
          </div>
        </div>
        <p style={{ margin: 0, fontSize: 15, color: secret ? 'rgba(255,255,255,.85)' : C.ink }}>{summary(p)}</p>
        <div className="row">
          <span className="row" style={{ gap: 6, fontSize: 13, fontWeight: 600, color: meta }}><M size={15} />{L(`mode.short.${p.greenTransport}`)}</span>
          <span className="spacer" />
          <button onClick={onMap} className="row" style={{ minHeight: 44, padding: '0 16px', borderRadius: 99, fontWeight: 600, fontSize: 14, gap: 6, background: secret ? C.highlight : C.mossLight, color: secret ? C.night : C.moss }}>
            <MapIcon size={16} />{L('explore.onmap')}</button>
        </div>
        {credits[p.id] && <Credit place={p} dark={secret} />}
      </div>
    </article>
  );
}
