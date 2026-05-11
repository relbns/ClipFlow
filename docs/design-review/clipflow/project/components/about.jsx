// About ClipFlow — small focused window
const AboutLink = ({ icon, label }) => (
  <span style={{
    display: 'inline-flex', alignItems: 'center', gap: 6,
    color: 'oklch(.68 .17 272)',
    fontSize: 13, fontWeight: 500,
    padding: '4px 8px', borderRadius: 6,
  }}>
    <span style={{ display: 'flex' }}>{icon}</span>
    {label}
  </span>
);

const CreditRow = ({ icon, name, role, accent }) => (
  <div style={{ display: 'grid', gridTemplateColumns: '32px 1fr', gap: 12, alignItems: 'center', padding: '8px 0' }}>
    <div style={{
      width: 28, height: 28, borderRadius: 8,
      display: 'grid', placeItems: 'center',
      background: `color-mix(in oklab, ${accent} 22%, transparent)`,
      color: accent,
    }}>{icon}</div>
    <div>
      <div style={{ fontSize: 13, color: 'var(--text-strong)', fontWeight: 500 }}>{name}</div>
      <div style={{ fontSize: 12, color: 'var(--text-muted)' }}>{role}</div>
    </div>
  </div>
);

const About = () => (
  <Window title="About ClipFlow" width={560} height={680}>
    <div style={{
      flex: 1, padding: '36px 32px 22px',
      background: 'var(--surface)', overflow: 'auto',
      display: 'flex', flexDirection: 'column', alignItems: 'center',
    }}>
      {/* hero */}
      <div style={{
        position: 'relative',
        width: 128, height: 128,
        borderRadius: 28,
        display: 'grid', placeItems: 'center',
        background: 'linear-gradient(135deg, oklch(.74 .17 280), oklch(.5 .19 268))',
        boxShadow: '0 30px 50px -12px oklch(.45 .19 270 / .55), inset 0 1px 0 rgba(255,255,255,.18)',
      }}>
        <ClipFlowMark size={92} rounded={false}/>
        {/* gloss */}
        <div style={{
          position: 'absolute', inset: 1, borderRadius: 27,
          background: 'linear-gradient(180deg, rgba(255,255,255,.22), transparent 40%)',
          pointerEvents: 'none',
        }}/>
      </div>

      <div style={{ marginTop: 22, fontSize: 28, fontWeight: 700, letterSpacing: '-.01em', color: 'var(--text-strong)' }}>
        ClipFlow
      </div>
      <div style={{ marginTop: 4, fontSize: 13.5, color: 'var(--text-muted)' }}>
        Modern clipboard manager + text expander
      </div>
      <div style={{
        marginTop: 10, display: 'flex', alignItems: 'center', gap: 8,
        fontSize: 12, color: 'var(--text-subtle)',
      }}>
        <span>Version 1.0.0</span>
        <span style={{
          fontSize: 10.5, fontWeight: 600, letterSpacing: '.06em',
          padding: '2px 7px', borderRadius: 999,
          background: 'color-mix(in oklab, oklch(.7 .17 60) 25%, transparent)',
          color: 'oklch(.7 .15 60)',
          textTransform: 'uppercase',
        }}>Alpha</span>
      </div>

      <div style={{ width: '100%', height: 1, background: 'var(--stroke-soft)', margin: '24px 0 16px' }}/>

      {/* credits */}
      <div style={{ width: '100%' }}>
        <div style={{
          fontSize: 10.5, fontWeight: 700, letterSpacing: '.08em',
          textTransform: 'uppercase', color: 'var(--text-label)',
          marginBottom: 4,
        }}>Credits</div>
        <CreditRow accent="oklch(.65 .17 272)" icon={
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"><circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/></svg>
        } name="Ariel Benesh" role="Creator & Developer"/>

        <div style={{ height: 14 }}/>
        <div style={{
          fontSize: 11.5, color: 'var(--text-muted)',
          marginBottom: 4,
        }}>Built on the shoulders of giants</div>
        <CreditRow accent="oklch(.7 .14 145)" icon={
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"><circle cx="6" cy="7" r="2.5"/><circle cx="6" cy="17" r="2.5"/><path d="M8 9l12 8M8 15 20 7"/></svg>
        } name="Clipy" role="Core clipboard architecture"/>
        <CreditRow accent="oklch(.72 .14 30)" icon={
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><rect x="6" y="4" width="12" height="14" rx="2"/><path d="M9 4V3h6v1M9 9h6M9 12h6M9 15h4"/></svg>
        } name="Flycut" role="UI/UX inspiration for Simple mode"/>
      </div>

      <div style={{ flex: 1 }}/>

      <div style={{ width: '100%', display: 'flex', justifyContent: 'center', gap: 6, paddingTop: 18,
        borderTop: '1px solid var(--stroke-soft)', marginTop: 10 }}>
        <AboutLink icon={<IconLink size={13}/>} label="GitHub"/>
        <AboutLink icon={<IconText size={13}/>} label="Full Credits"/>
        <AboutLink icon={<IconGear size={13}/>} label="License"/>
      </div>
      <div style={{ marginTop: 12, fontSize: 11, color: 'var(--text-faint)' }}>
        © 2026 ClipFlow · Made with care in Tel Aviv
      </div>
    </div>
  </Window>
);

Object.assign(window, { About });
