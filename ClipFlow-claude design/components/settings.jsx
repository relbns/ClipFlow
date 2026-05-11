// Settings & Welcome screens

const SettingsTab = ({ icon, label, active, accent }) => (
  <div style={{
    display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4,
    padding: '8px 12px', minWidth: 70,
    borderRadius: 7,
    background: active ? 'var(--fill-1)' : 'transparent',
  }}>
    <div style={{
      width: 28, height: 28, borderRadius: 7,
      background: `linear-gradient(180deg, color-mix(in oklab, ${accent} 65%, white 0%), color-mix(in oklab, ${accent} 85%, black 10%))`,
      display: 'grid', placeItems: 'center', color: 'var(--text-strong)',
      boxShadow: 'inset 0 1px 0 var(--inset-hi)',
    }}>{icon}</div>
    <div style={{ fontSize: 11, color: active ? 'var(--text-strong)' : 'var(--text-mid)' }}>{label}</div>
  </div>
);

const SettingsRow = ({ label, hint, children, last }) => (
  <div style={{
    display: 'grid', gridTemplateColumns: '180px 1fr', gap: 18, alignItems: 'start',
    padding: '12px 0',
    borderBottom: last ? 'none' : '1px solid var(--stroke-soft)',
  }}>
    <div style={{ paddingTop: 4 }}>
      <div style={{ fontSize: 13, color: 'var(--text)' }}>{label}</div>
      {hint && <div style={{ fontSize: 11.5, color: 'var(--text-subtle)', marginTop: 2 }}>{hint}</div>}
    </div>
    <div>{children}</div>
  </div>
);

const Slider = ({ value, min = 10, max = 100 }) => {
  const pct = ((value - min) / (max - min)) * 100;
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 12, maxWidth: 360 }}>
      <span style={{ fontSize: 11, color: 'var(--text-subtle)', width: 22, textAlign: 'right' }}>{min}</span>
      <div style={{ flex: 1, position: 'relative', height: 4, background: 'var(--fill-2)', borderRadius: 999 }}>
        <div style={{ position: 'absolute', inset: 0, width: pct + '%', background: 'oklch(.6 .17 272)', borderRadius: 999 }}/>
        <div style={{
          position: 'absolute', top: '50%', left: pct + '%',
          transform: 'translate(-50%, -50%)',
          width: 14, height: 14, borderRadius: '50%',
          background: 'var(--knob)', boxShadow: 'var(--knob-shadow)',
        }}/>
      </div>
      <span style={{ fontSize: 11, color: 'var(--text-subtle)', width: 22 }}>{max}</span>
      <span style={{
        fontSize: 12, color: 'var(--text-strong)', fontVariantNumeric: 'tabular-nums',
        padding: '2px 8px', borderRadius: 4, background: 'var(--fill-1)',
        minWidth: 32, textAlign: 'center',
      }}>{value}</span>
    </div>
  );
};

const Banner = ({ tone, icon, title, body, action }) => {
  const palette = tone === 'warn'
    ? { bg: 'color-mix(in oklab, oklch(.7 .17 60) 20%, transparent)', stroke: 'color-mix(in oklab, oklch(.7 .17 60) 40%, transparent)', icon: 'oklch(.85 .15 60)' }
    : { bg: 'color-mix(in oklab, oklch(.6 .17 272) 18%, transparent)', stroke: 'color-mix(in oklab, oklch(.6 .17 272) 35%, transparent)', icon: 'oklch(.85 .12 272)' };
  return (
    <div style={{
      display: 'flex', gap: 12, padding: 14,
      background: palette.bg, border: `1px solid ${palette.stroke}`,
      borderRadius: 10,
    }}>
      <div style={{ color: palette.icon, display: 'flex', alignItems: 'flex-start', paddingTop: 1 }}>{icon}</div>
      <div style={{ flex: 1 }}>
        <div style={{ fontSize: 13, fontWeight: 600, color: 'var(--text-strong)' }}>{title}</div>
        <div style={{ fontSize: 12, color: 'var(--text-mid)', marginTop: 2, lineHeight: 1.5 }}>{body}</div>
      </div>
      {action}
    </div>
  );
};

const SettingsExpansion = () => (
  <Window title="ClipFlow Settings" width={760} height={620}>
    <div style={{
      padding: '10px 14px',
      borderBottom: '1px solid var(--stroke-soft)',
      display: 'flex', gap: 4,
      background: 'var(--titlebar-bg)',
    }}>
      <SettingsTab icon={<IconGear size={14}/>}     label="General"    accent="oklch(.55 .03 250)"/>
      <SettingsTab icon={<IconStar size={14}/>}     label="Appearance" accent="oklch(.65 .12 30)"/>
      <SettingsTab icon={<IconBolt size={14}/>}     label="Expansion"  accent="oklch(.6 .17 272)" active/>
      <SettingsTab icon={<IconKey size={14}/>}      label="Hotkeys"    accent="oklch(.55 .12 145)"/>
      <SettingsTab icon={<IconCloud size={14}/>}    label="Sync"       accent="oklch(.6 .14 220)"/>
      <SettingsTab icon={<IconLock size={14}/>}     label="Privacy"    accent="oklch(.55 .12 200)"/>
      <SettingsTab icon={<IconHebrew size={14}/>}   label="Language"   accent="oklch(.6 .14 320)"/>
    </div>

    <div style={{ padding: '18px 26px 22px', overflow: 'auto', flex: 1 }}>
      <Banner
        tone="warn"
        icon={<IconLock size={18}/>}
        title="Accessibility access required"
        body="ClipFlow needs Accessibility permission to watch keystrokes for snippet expansion. Without it, only clipboard history will work."
        action={<ToolbarBtn primary label="Open System Settings"/>}
      />

      <div style={{ height: 18 }}/>

      <SettingsRow label="Text expansion" hint="Replace abbreviations with snippets as you type.">
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <Toggle on/>
          <span style={{ fontSize: 12, color: 'var(--text-muted)' }}>On — using ⌥⌘V to undo last expansion</span>
        </div>
      </SettingsRow>

      <SettingsRow label="Default trigger" hint="Override per‑snippet in the Editor inspector.">
        <div style={{
          display: 'inline-grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: 4,
          padding: 2, background: 'var(--input-bg)', borderRadius: 7,
          border: '1px solid var(--stroke)', maxWidth: 480,
        }}>
          {[['Delimiter', false], ['Space', true], ['Any char', false], ['Tab', false], ['Enter', false]].map(([l, on]) => (
            <div key={l} style={{
              textAlign: 'center', fontSize: 12, padding: '6px 12px', borderRadius: 5,
              background: on ? 'var(--seg-selected)' : 'transparent',
              color: on ? 'var(--text-strong)' : 'var(--text-muted)',
              fontWeight: on ? 500 : 400,
              boxShadow: on ? 'inset 0 1px 0 var(--inset-hi)' : 'none',
            }}>{l}</div>
          ))}
        </div>
      </SettingsRow>

      <SettingsRow label="Sound feedback" hint="Quiet click when an abbreviation expands.">
        <Toggle/>
      </SettingsRow>

      <SettingsRow label="Backspace cancels" hint="Press backspace immediately after expansion to revert to the abbreviation.">
        <Toggle on/>
      </SettingsRow>

      <SettingsRow label="Excluded apps" hint="Snippets never expand inside these apps.">
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
          {['1Password', 'Terminal', 'Bitwarden'].map(a => (
            <span key={a} style={{
              fontSize: 12, padding: '3px 8px 3px 24px', borderRadius: 999,
              background: 'var(--fill-1)', border: '1px solid var(--stroke)',
              position: 'relative',
            }}>
              <span style={{
                position: 'absolute', left: 6, top: '50%', transform: 'translateY(-50%)',
                width: 12, height: 12, borderRadius: 3, background: 'var(--fill-2)',
              }}/>
              {a}
              <span style={{ marginLeft: 6, color: 'var(--text-faint)' }}>×</span>
            </span>
          ))}
          <span style={{
            fontSize: 12, padding: '3px 8px', borderRadius: 999,
            border: '1px dashed var(--stroke)', color: 'var(--text-muted)',
          }}>+ Add app</span>
        </div>
      </SettingsRow>

      <SettingsRow last label="Live preview" hint="See your snippet rendered with current variables before it fires.">
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <Toggle on/>
          <span style={{ fontSize: 12, color: 'var(--text-muted)' }}>Floating preview · 200 ms hold</span>
        </div>
      </SettingsRow>
    </div>
  </Window>
);

// ----- Welcome / Onboarding -----
const Step = ({ n, active, done, title, body }) => (
  <div style={{
    display: 'grid', gridTemplateColumns: '32px 1fr', gap: 14, padding: '14px 16px',
    background: active ? 'var(--fill-soft)' : 'transparent',
    border: active ? '1px solid rgba(123,113,255,.30)' : '1px solid transparent',
    borderRadius: 10,
  }}>
    <div style={{
      width: 28, height: 28, borderRadius: '50%',
      display: 'grid', placeItems: 'center',
      background: done
        ? 'oklch(.7 .17 145)'
        : active
          ? 'linear-gradient(180deg, oklch(.65 .17 272), oklch(.5 .19 272))'
          : 'var(--fill-1)',
      color: 'var(--text-strong)',
      fontSize: 12, fontWeight: 600,
      boxShadow: active ? '0 6px 14px -4px oklch(.55 .19 272 / .6)' : 'none',
    }}>
      {done ? <IconCheck size={14} stroke={2.4}/> : n}
    </div>
    <div>
      <div style={{ fontSize: 14, fontWeight: 500, color: 'var(--text-strong)' }}>{title}</div>
      <div style={{ fontSize: 12, color: 'var(--text-muted)', marginTop: 3, lineHeight: 1.5 }}>{body}</div>
    </div>
  </div>
);

const Welcome = () => (
  <Window title="" width={780} height={520}>
    <div style={{ flex: 1, display: 'grid', gridTemplateColumns: '1fr 1fr', minHeight: 0 }}>
      {/* Left — visual */}
      <div style={{
        position: 'relative', overflow: 'hidden',
        background:
          'radial-gradient(120% 80% at 30% 20%, oklch(.45 .15 285), oklch(.25 .08 280) 60%, oklch(.18 .04 270) 100%)',
        padding: 32,
        display: 'flex', flexDirection: 'column', justifyContent: 'space-between',
      }}>
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <ClipFlowMark size={32}/>
            <div style={{ fontSize: 18, fontWeight: 600 }}>ClipFlow</div>
          </div>
          <div style={{ fontSize: 28, fontWeight: 600, lineHeight: 1.15, marginTop: 26, letterSpacing: '-.01em' }}>
            Everything you copy.<br/>
            Anything you type often.
          </div>
          <div style={{ fontSize: 13, color: 'var(--text-mid)', marginTop: 12, lineHeight: 1.55, maxWidth: 280 }}>
            A quiet menubar app for clipboard history and abbreviation snippets — with first‑class Hebrew & RTL.
          </div>
        </div>
        {/* mini preview */}
        <div style={{
          position: 'absolute', right: -40, bottom: -40,
          transform: 'rotate(-6deg) scale(.78)',
          transformOrigin: 'bottom right',
          filter: 'drop-shadow(0 30px 50px var(--shadow-deep))',
          pointerEvents: 'none',
        }}>
          <Popover width={260}>
            <SearchField placeholder="Search clipboard…"/>
            <Section label="Recent"/>
            <ClipRow kbd="1" active kind={<IconLink size={13}/>} title="github.com/relbns/ClipFlow" sub="just now"/>
            <ClipRow kbd="2" kind={<IconText size={13}/>} title="Thanks for the quick…" sub="2 min"/>
            <ClipRow kbd="3" kind={<div style={{width:14,height:14,borderRadius:3,background:'#FF5733'}}/>} title="#FF5733" sub="hex"/>
          </Popover>
        </div>
      </div>

      {/* Right — steps */}
      <div style={{ padding: '28px 28px', display: 'flex', flexDirection: 'column', gap: 0, background: 'var(--surface)' }}>
        <div style={{ fontSize: 11, fontWeight: 600, letterSpacing: '.08em', textTransform: 'uppercase', color: 'var(--text-subtle)' }}>
          Three quick steps
        </div>
        <div style={{ height: 14 }}/>
        <Step done n="1" title="Pin ClipFlow to your menubar"
          body="ClipFlow lives up here — there's no Dock icon. Drag the menubar item to where you'd like."/>
        <Step active n="2" title="Grant Accessibility permission"
          body="Required so snippets can expand as you type. We never read passwords or secure fields."/>
        <Step n="3" title="Try your first snippet"
          body={<>We've added <code style={{fontFamily:'ui-monospace, Menlo, monospace', fontSize:11, padding:'1px 5px', borderRadius:4, background:'var(--fill-1)'}}>.dd</code> for today's date. Type it anywhere, then press space.</>}/>
        <div style={{ flex: 1 }}/>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <Toggle on/>
            <span style={{ fontSize: 12, color: 'var(--text-muted)' }}>Launch at login</span>
          </div>
          <div style={{ display: 'flex', gap: 8 }}>
            <ToolbarBtn label="Skip tour"/>
            <ToolbarBtn primary label="Open System Settings →"/>
          </div>
        </div>
      </div>
    </div>
  </Window>
);

// Brand mark — two stacked clipboards, indigo gradient, soft-shadow back.
const ClipFlowMark = ({ size = 28, rounded = true }) => {
  const id = 'cfg-' + size;
  return (
    <svg width={size} height={size} viewBox="0 0 64 64" fill="none">
      <defs>
        <linearGradient id={id+'-front'} x1="6" y1="6" x2="58" y2="58" gradientUnits="userSpaceOnUse">
          <stop offset="0"  stopColor="oklch(.74 .17 280)"/>
          <stop offset="1"  stopColor="oklch(.55 .19 270)"/>
        </linearGradient>
        <linearGradient id={id+'-back'} x1="14" y1="14" x2="50" y2="50" gradientUnits="userSpaceOnUse">
          <stop offset="0"  stopColor="oklch(.66 .17 280)"/>
          <stop offset="1"  stopColor="oklch(.50 .18 270)"/>
        </linearGradient>
        {rounded && (
          <linearGradient id={id+'-bg'} x1="0" y1="0" x2="64" y2="64" gradientUnits="userSpaceOnUse">
            <stop offset="0" stopColor="oklch(.32 .04 280)"/>
            <stop offset="1" stopColor="oklch(.20 .03 270)"/>
          </linearGradient>
        )}
      </defs>
      {rounded && <rect x="0" y="0" width="64" height="64" rx="14" fill={'url(#'+id+'-bg)'}/>}

      {/* Back clipboard */}
      <g transform="translate(28 16) rotate(8 14 18)">
        <rect x="0" y="2" width="28" height="36" rx="5" fill={'url(#'+id+'-back)'} opacity=".85"/>
        {/* clip head */}
        <rect x="9" y="-2" width="10" height="6" rx="1.4" fill={'url(#'+id+'-back)'} opacity=".85"/>
        {/* lines */}
        <rect x="6"  y="14" width="12" height="2" rx="1" fill="white" opacity=".55"/>
        <rect x="6"  y="20" width="16" height="2" rx="1" fill="white" opacity=".40"/>
      </g>

      {/* Front clipboard */}
      <g transform="translate(8 12)">
        {/* drop highlight */}
        <rect x="0" y="2" width="32" height="40" rx="6" fill={'url(#'+id+'-front)'}/>
        {/* clip head */}
        <rect x="10" y="-2" width="12" height="7" rx="1.6" fill={'url(#'+id+'-front)'}/>
        <rect x="12" y="-1" width="8"  height="3" rx="1"   fill="white" opacity=".25"/>
        {/* page lines */}
        <rect x="6"  y="14" width="20" height="2.2" rx="1.1" fill="white" opacity=".90"/>
        <rect x="6"  y="20" width="16" height="2.2" rx="1.1" fill="white" opacity=".70"/>
        <rect x="6"  y="26" width="12" height="2.2" rx="1.1" fill="white" opacity=".55"/>
        {/* glossy edge */}
        <rect x="0" y="2" width="32" height="40" rx="6" fill="white" opacity=".06"/>
      </g>
    </svg>
  );
};

Object.assign(window, { SettingsExpansion, Welcome, ClipFlowMark, Banner, Slider, SettingsRow, SettingsTab, Step });
