import { createContext, useContext, useEffect, useState } from 'react';
import { ChevronRight, Compass, House, Leaf, Map as MapIcon, Ticket } from 'lucide-react';
import { levelOrder, levelPercent, levelTitle, type Place } from './lib/data';
import { L } from './lib/i18n';
import { useCelebration, useLang, useProfile, day } from './lib/store';
import { LeafBadge } from './ui/common';
import Home from './screens/Home';
import MapScreen from './screens/MapScreen';
import Explore from './screens/Explore';
import TripCalculator from './screens/TripCalculator';
import Discounts from './screens/Discounts';
import Onboarding from './screens/Onboarding';

export type Tab = 'home' | 'map' | 'explore' | 'trip' | 'discounts';
interface Nav { tab: Tab; setTab: (t: Tab) => void; focus: Place | null; show: (p: Place) => void; clearFocus: () => void }
const NavContext = createContext<Nav>(null!);
export const useNav = () => useContext(NavContext);

const tabs: { id: Tab; icon: typeof House }[] = [
  { id: 'home', icon: House }, { id: 'map', icon: MapIcon }, { id: 'explore', icon: Compass },
  { id: 'trip', icon: Leaf }, { id: 'discounts', icon: Ticket },
];

export default function App() {
  const lang = useLang();
  const profile = useProfile();
  const [tab, setTab] = useState<Tab>('home');
  const [focus, setFocus] = useState<Place | null>(null);
  useEffect(() => { document.documentElement.lang = lang; }, [lang]);

  if (!profile) return <Onboarding key={lang} />;

  const nav: Nav = { tab, setTab, focus, show: (p) => { setFocus(p); setTab('map'); }, clearFocus: () => setFocus(null) };
  return (
    <NavContext.Provider value={nav}>
      <div key={lang} style={{ height: '100%' }}>
        {tab === 'home' && <Home />}
        {tab === 'map' && <MapScreen />}
        {tab === 'explore' && <Explore />}
        {tab === 'trip' && <TripCalculator />}
        {tab === 'discounts' && <Discounts />}
        <nav className="tabbar" aria-label="Navigation">
          {tabs.map(({ id, icon: Icon }) => (
            <button key={id} className={`tab ${tab === id ? 'on' : ''}`} onClick={() => setTab(id)} aria-current={tab === id ? 'page' : undefined}>
              <Icon size={22} strokeWidth={tab === id ? 2.4 : 1.9} />{L(`tab.${id}`)}
            </button>
          ))}
        </nav>
        <Banner />
      </div>
    </NavContext.Provider>
  );
}

/** Banner efter "J'y suis !" / "Ajouter à ma journée". */
function Banner() {
  const c = useCelebration();
  const nav = useNav();
  useEffect(() => {
    if (!c) return;
    const t = setTimeout(day.dismissCelebration, 7000);
    return () => clearTimeout(t);
  }, [c]);
  if (!c) return null;
  const up = c.before === null || levelOrder.indexOf(c.before) > levelOrder.indexOf(c.after);
  const pct = levelPercent[c.after];
  return (
    <button key={c.id} className="banner" onClick={() => { day.dismissCelebration(); nav.setTab('discounts'); }}>
      <LeafBadge size={44} />
      <span style={{ flex: 1 }}>
        <strong style={{ font: '700 17px var(--display)', display: 'block' }}>{up ? L('celebrate.unlocked', levelTitle(c.after)) : L('celebrate.added')}</strong>
        <span style={{ color: 'var(--hl)', fontSize: 14, fontWeight: 500 }}>{pct > 0 ? L('celebrate.discount', pct) : L('celebrate.nodiscount')}</span>
      </span>
      <ChevronRight color="var(--hl)" />
    </button>
  );
}
