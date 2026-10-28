import { useState } from 'react';
import { Briefcase, Building2, Check, ChevronLeft, Drama, Leaf, ShoppingBag, User, Users, UsersRound, UtensilsCrossed, Baby } from 'lucide-react';
import { lang, langNames, L, setLang, type Lang } from '../lib/i18n';
import { emptyProfile, saveProfile, useLang, type Company, type Interest, type Profile } from '../lib/store';
import { LeafBadge } from '../ui/common';

const interests: [Interest, typeof Leaf][] = [['cuisine', UtensilsCrossed], ['shopping', ShoppingBag], ['musee', Building2], ['nature', Leaf], ['activite', Drama]];
const companies: [Company, typeof Leaf][] = [['family', Users], ['friends', UsersRound], ['familyKids', Baby], ['solo', User], ['agency', Briefcase]];
const QUESTIONS = 4;

/** Spørgeskemaet ved første besøg: sprog og navn, interesser, budget, alder og rejsefølge. */
export default function Onboarding() {
  useLang();
  const [step, setStep] = useState(0);
  const [p, setP] = useState<Profile>(emptyProfile);
  const next = () => (step < QUESTIONS ? setStep(step + 1) : saveProfile(p));
  const toggle = (i: Interest) => setP({ ...p, interests: p.interests.includes(i) ? p.interests.filter((x) => x !== i) : [...p.interests, i] });

  return (
    <main className="onb">
      {step > 0 && (
        <div style={{ maxWidth: 560, width: '100%', margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 8 }}>
          <div className="progress">{Array.from({ length: QUESTIONS }, (_, i) => <span key={i} className={i < step ? 'on' : ''} />)}</div>
          <div className="row">
            <button className="row" onClick={() => setStep(step - 1)} style={{ color: 'var(--hl)', fontWeight: 600, minHeight: 44, gap: 4 }}><ChevronLeft size={18} />{L('go.back.info')}</button>
            <span className="spacer" />
            <span className="small" style={{ color: 'rgba(255,255,255,.8)' }}>{L('onb.step', step, QUESTIONS)}</span>
          </div>
        </div>
      )}

      <div className="content" key={step}>
        {step === 0 && <>
          <LeafBadge size={64} />
          <h1 style={{ fontSize: 38 }}>{L('onb.welcome.title')}</h1>
          <p style={{ margin: 0, fontSize: 17, color: 'rgba(255,255,255,.85)' }}>{L('onb.welcome.sub')}</p>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            <span className="small" style={{ color: 'var(--hl)', fontWeight: 600 }}>{L('settings.language')}</span>
            <div className="row">{(['fr', 'da'] as Lang[]).map((l) => <button key={l} className={`choice ${lang() === l ? 'on' : ''}`} aria-pressed={lang() === l} onClick={() => setLang(l)}>{langNames[l]}</button>)}</div>
          </div>
          <label style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            <span className="small" style={{ color: 'var(--hl)', fontWeight: 600 }}>{L('onb.name')}</span>
            <input type="text" autoComplete="given-name" value={p.name} placeholder={L('onb.name.placeholder')} onChange={(e) => setP({ ...p, name: e.target.value })} onKeyDown={(e) => e.key === 'Enter' && next()} />
          </label>
        </>}

        {step === 1 && <>
          <Title t={L('onb.interests')} sub={L('onb.interests.sub')} />
          <div className="row" style={{ flexWrap: 'wrap' }}>
            {interests.map(([i, I]) => <button key={i} className={`choice ${p.interests.includes(i) ? 'on' : ''}`} aria-pressed={p.interests.includes(i)} onClick={() => toggle(i)}><I size={18} />{L(`profile.interest.${i}`)}</button>)}
          </div>
        </>}

        {step === 2 && <>
          <Title t={L('onb.budget')} sub={L('onb.budget.sub')} />
          <div className="big">{p.budgetEuro >= 5000 ? '5 000 € +' : `${p.budgetEuro.toLocaleString(lang() === 'fr' ? 'fr-FR' : 'da-DK')} €`}</div>
          <input type="range" min={0} max={5000} step={50} value={p.budgetEuro} onChange={(e) => setP({ ...p, budgetEuro: +e.target.value })} aria-label={L('onb.budget')} />
          <div className="row small" style={{ color: 'rgba(255,255,255,.8)' }}><span>0 €</span><span className="spacer" /><span>5 000 €</span></div>
        </>}

        {step === 3 && <>
          <Title t={L('onb.age')} />
          <div className="big">{L('onb.age.value', p.age)}</div>
          <input type="range" min={15} max={70} step={1} value={p.age} onChange={(e) => setP({ ...p, age: +e.target.value })} aria-label={L('onb.age')} />
          <div className="row small" style={{ color: 'rgba(255,255,255,.8)' }}><span>15</span><span className="spacer" /><span>70</span></div>
        </>}

        {step === 4 && <>
          <Title t={L('onb.company')} />
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {companies.map(([c, I]) => (
              <button key={c} className={`choice ${p.company === c ? 'on' : ''}`} aria-pressed={p.company === c} onClick={() => setP({ ...p, company: c })} style={{ width: '100%' }}>
                <I size={18} />{L(`profile.company.${c}`)}<span className="spacer" />{p.company === c && <Check size={18} />}
              </button>
            ))}
          </div>
        </>}
      </div>

      <div className="row" style={{ maxWidth: 560, width: '100%', margin: '16px auto 0', gap: 12 }}>
        {step > 0 && step < QUESTIONS && <button onClick={next} style={{ minWidth: 100, minHeight: 52, color: 'rgba(255,255,255,.85)', fontWeight: 600 }}>{L('onb.skip')}</button>}
        <button onClick={next} style={{ flex: 1, minHeight: 52, borderRadius: 99, background: 'var(--hl)', color: 'var(--night)', fontWeight: 700, fontSize: 17 }}>
          {step === QUESTIONS ? L('onb.done') : L('onb.next')}</button>
      </div>
    </main>
  );
}

function Title({ t, sub }: { t: string; sub?: string }) {
  return <div><h1 style={{ fontSize: 32 }}>{t}</h1>{sub && <p style={{ margin: '8px 0 0', fontSize: 16, color: 'rgba(255,255,255,.85)' }}>{sub}</p>}</div>;
}
