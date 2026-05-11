// MenuBar dropdown — a custom popover (not native NSMenu) so we can do hover
// previews, monochrome icons, count chips, and inline kbd hints.

const KBD = ({ children, dim }) => (
  <span style={{
    fontFamily: 'ui-monospace, "SF Mono", Menlo, monospace',
    fontSize: 11, fontWeight: 500,
    padding: '2px 5px', minWidth: 16, textAlign: 'center',
    borderRadius: 4,
    color: dim ? 'var(--text-subtle)' : 'var(--text-mid)',
    background: dim ? 'var(--fill-soft)' : 'var(--fill-2)',
    border: '1px solid var(--stroke)',
    boxShadow: 'inset 0 -1px 0 var(--shadow-strong)',
    lineHeight: 1,
  }}>{children}</span>
);

// The menubar host — barely visible status bar background to anchor the popover.
const StatusBarStrip = ({ active = 0 }) => {
  const items = [
    { i: 'clip', active: true },
    { i: 'wand' },
    { i: 'house' },
    { i: 'shield' },
    { i: 'scissors' },
    { i: 'A' },
  ];
  return (
    <div style={{
      height: 28, padding: '0 10px',
      display: 'flex', alignItems: 'center', gap: 14,
      background: 'var(--statusbar-bg)',
      backdropFilter: 'blur(20px) saturate(140%)',
      WebkitBackdropFilter: 'blur(20px) saturate(140%)',
      borderBottom: '1px solid var(--stroke-soft)',
      color: 'var(--text-mid)',
    }}>
      {items.map((it, i) => (
        <div key={i} style={{
          width: 20, height: 20, borderRadius: 4,
          display: 'grid', placeItems: 'center',
          background: i === active ? 'var(--fill-2)' : 'transparent',
          color: i === active ? 'var(--text-strong)' : 'var(--text-mid)',
        }}>
          {it.i === 'clip' && (
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
              {/* back clipboard */}
              <rect x="9"  y="6"  width="11" height="13" rx="2"/>
              <path d="M12.5 6V5"/>
              {/* front clipboard */}
              <rect x="4"  y="3"  width="11" height="13" rx="2" fill="currentColor" stroke="none" opacity=".95"/>
              <rect x="7.5" y="2"  width="4" height="2" rx=".7" fill="currentColor" stroke="none"/>
            </svg>
          )}
          {it.i === 'A' && <span style={{ fontSize: 11, fontWeight: 700 }}>A</span>}
          {it.i === 'wand' && <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"><path d="m4 20 14-14M14 4h2v2M18 8h2v2M9 11l4 4"/></svg>}
          {it.i === 'house' && <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="m4 11 8-7 8 7v8a1 1 0 0 1-1 1h-4v-6h-6v6H5a1 1 0 0 1-1-1Z"/></svg>}
          {it.i === 'shield' && <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M12 3 5 6v6c0 5 3 8 7 9 4-1 7-4 7-9V6Z"/></svg>}
          {it.i === 'scissors' && <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"><circle cx="6" cy="7" r="2.5"/><circle cx="6" cy="17" r="2.5"/><path d="M8 9l12 8M8 15 20 7"/></svg>}
        </div>
      ))}
    </div>
  );
};

// shared popover shell
const Popover = ({ children, width = 340, style }) => (
  <div style={{
    width,
    borderRadius: 12,
    background: 'var(--popover-bg)',
    backdropFilter: 'blur(28px) saturate(160%)',
    WebkitBackdropFilter: 'blur(28px) saturate(160%)',
    boxShadow: 'var(--popover-shadow)',
    color: 'var(--text)',
    fontFamily: '"SF Pro Text", "Inter", -apple-system, system-ui, sans-serif',
    fontSize: 13,
    overflow: 'hidden',
    ...style,
  }}>{children}</div>
);

const SearchField = ({ value = '', dir = 'ltr', placeholder = 'Search clips & snippets' }) => (
  <div style={{ padding: '8px 8px 6px' }}>
    <div style={{
      display: 'flex', alignItems: 'center', gap: 8,
      height: 28, padding: '0 10px',
      background: 'var(--input-bg)',
      border: '1px solid var(--stroke)',
      borderRadius: 7,
      direction: dir,
    }}>
      <span style={{ color: 'var(--text-subtle)', display: 'flex' }}><IconSearch size={13} stroke={1.8}/></span>
      <input
        defaultValue={value}
        placeholder={placeholder}
        dir={dir}
        style={{
          flex: 1, background: 'transparent', border: 0, outline: 'none',
          color: 'var(--text)', fontSize: 13,
          fontFamily: 'inherit',
        }}
      />
      <KBD dim>⌘F</KBD>
    </div>
  </div>
);

const Section = ({ label, right }) => (
  <div style={{
    padding: '6px 14px 4px',
    display: 'flex', alignItems: 'center', justifyContent: 'space-between',
    fontSize: 10.5, fontWeight: 600, letterSpacing: '.06em',
    textTransform: 'uppercase',
    color: 'var(--text-label)',
  }}>
    <span>{label}</span>
    {right}
  </div>
);

const Divider = () => (
  <div style={{ height: 1, background: 'var(--stroke)', margin: '4px 0' }}/>
);

// Row in simple mode: thumbnail / glyph + main + numeric kbd
const ClipRow = ({ kbd, kind, title, sub, right, active, dir = 'ltr', accent }) => {
  const bg = active ? 'rgba(120,116,255,.22)' : 'transparent';
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 10,
      padding: '6px 10px', margin: '0 6px', borderRadius: 6,
      background: bg,
      direction: dir,
    }}>
      <div style={{
        width: 26, height: 26, borderRadius: 5,
        background: 'var(--fill-1)',
        display: 'grid', placeItems: 'center', flexShrink: 0,
        color: 'var(--text-mid)',
        overflow: 'hidden',
      }}>{kind}</div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{
          fontSize: 13, color: 'var(--text-strong)',
          whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
          fontWeight: active ? 500 : 400,
        }}>{title}</div>
        {sub && <div style={{
          fontSize: 11, color: 'var(--text-label)',
          whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
          marginTop: 1,
        }}>{sub}</div>}
      </div>
      {right ?? (kbd != null && <KBD dim={!active}>{kbd}</KBD>)}
    </div>
  );
};

const FooterRow = ({ icon, label, kbd, danger }) => (
  <div style={{
    display: 'flex', alignItems: 'center', gap: 10,
    padding: '6px 14px', height: 28,
    color: danger ? '#ff7a73' : 'var(--text)',
    fontSize: 13,
  }}>
    <span style={{ width: 16, color: 'var(--text-muted)', display: 'flex' }}>{icon}</span>
    <span style={{ flex: 1 }}>{label}</span>
    {kbd && <KBD dim>{kbd}</KBD>}
  </div>
);

// ---------- A: Simple mode (flat list) ----------
const MenubarSimple = () => (
  <Popover width={340}>
    <SearchField placeholder="Search clipboard…" />
    <Section label="Recent clips" right={<span style={{ fontSize: 10.5, color: 'var(--text-subtle)', textTransform: 'none', letterSpacing: 0 }}>14 items</span>}/>
    <div style={{ paddingBottom: 4 }}>
      <ClipRow kbd="1" active kind={<IconLink size={14}/>}
        title="github.com/relbns/ClipFlow"
        sub="copied 12s ago • Safari" />
      <ClipRow kbd="2" kind={<IconText size={14}/>}
        title="Thanks for the quick turnaround — I&rsquo;ll review the…"
        sub="copied 2m ago • Mail" />
      <ClipRow kbd="3" kind={
        <div style={{ width: 16, height: 16, borderRadius: 3, background: '#FF5733', boxShadow: 'inset 0 0 0 1px var(--shadow-strong)' }}/>
      } title="#FF5733" sub="hex color • Figma" />
      <ClipRow kbd="4" kind={
        <div style={{
          width: '100%', height: '100%', backgroundImage:
            'linear-gradient(135deg, #6f7fc7 0%, #c39bd3 100%)',
        }}/>
      } title="Screenshot 2026‑05‑10 at 14.22" sub="PNG · 1840×1040 · 312 KB" />
      <ClipRow kbd="5" kind={<IconBracket size={14}/>}
        title={<span style={{ fontFamily: 'ui-monospace, "SF Mono", Menlo, monospace', fontSize: 12 }}>const result = await fetch(url)</span>}
        sub="3 lines • Xcode" />
      <ClipRow kbd="6" kind={<IconText size={14}/>}
        title="Order #A‑10847 confirmed"
        sub="copied 14m ago" />
      <ClipRow kbd="7" kind={<IconText size={14}/>}
        title="ronen.benami@example.com"
        sub="email • Slack" />
      <ClipRow kbd="8" kind={<IconLink size={14}/>}
        title="figma.com/file/Xc9…/ClipFlow"
        sub="3 minutes ago" />
      <ClipRow kbd="9" kind={<IconText size={14}/>}
        title="48.8566° N, 2.3522° E"
        sub="coordinates" />
      <ClipRow kbd="0" kind={<IconText size={14}/>}
        title="Apt 4B, 221B Baker Street, London"
        sub="address" />
    </div>
    <Divider/>
    <FooterRow icon={<IconSparkles size={14}/>} label="Snippet Editor…" kbd="⌘E"/>
    <FooterRow icon={<IconGear size={14}/>}     label="Preferences…"     kbd="⌘,"/>
    <Divider/>
    <FooterRow icon={<IconTrash size={14}/>} label="Clear history" />
    <FooterRow icon={<IconPower size={14}/>} label="Quit ClipFlow" kbd="⌘Q"/>
    <div style={{ height: 6 }}/>
  </Popover>
);

// ---------- B: Organized mode ----------
const GroupRow = ({ icon, label, count, accent, kbd }) => (
  <div style={{
    display: 'flex', alignItems: 'center', gap: 10,
    padding: '6px 10px', margin: '0 6px', borderRadius: 6,
  }}>
    <div style={{
      width: 22, height: 22, borderRadius: 6,
      display: 'grid', placeItems: 'center',
      background: `color-mix(in oklab, ${accent} 22%, transparent)`,
      color: accent,
    }}>{icon}</div>
    <span style={{ flex: 1, fontSize: 13 }}>{label}</span>
    <span style={{
      fontSize: 11, color: 'var(--text-subtle)',
      padding: '1px 6px', borderRadius: 999,
      background: 'var(--fill-1)',
    }}>{count}</span>
    <span style={{ color: 'var(--text-faint)', display: 'flex' }}><IconChevron size={14} stroke={1.8}/></span>
  </div>
);

const MenubarOrganized = () => (
  <Popover width={340}>
    <SearchField placeholder="Search clipboard…" />

    <Section label="Pinned"/>
    <div>
      <ClipRow kind={<IconPin size={13}/>} title="API key — staging"
        sub="••••••••••••••••a83f" right={<KBD dim>⌘1</KBD>}/>
      <ClipRow kind={<IconPin size={13}/>} title="ronen@clipflow.app"
        sub="email" right={<KBD dim>⌘2</KBD>}/>
    </div>

    <Section label="Categories"/>
    <div style={{ paddingBottom: 2 }}>
      <GroupRow accent="oklch(.78 .14 70)"  icon={<IconClock  size={13}/>} label="Recent"  count="14"/>
      <GroupRow accent="oklch(.74 .14 200)" icon={<IconImage  size={13}/>} label="Images"  count="3"/>
      <GroupRow accent="oklch(.78 .14 145)" icon={<IconLink   size={13}/>} label="Links"   count="6"/>
      <GroupRow accent="oklch(.78 .12 320)" icon={<IconSwatch size={13}/>} label="Colors"  count="4"/>
      <GroupRow accent="oklch(.78 .12 30)"  icon={<IconText   size={13}/>} label="Text"    count="22"/>
    </div>

    <Section label="Snippets"/>
    <div style={{ paddingBottom: 4 }}>
      <ClipRow kind={<IconBolt size={13}/>}
        title="Email signature"
        sub=".sig — Mail, Slack" right={
          <span style={{ fontFamily:'ui-monospace, Menlo, monospace', fontSize:11, color:'var(--text-subtle)' }}>.sig</span>
        }/>
      <ClipRow kind={<IconBolt size={13}/>}
        title="Today's date"
        sub=".dd — anywhere" right={
          <span style={{ fontFamily:'ui-monospace, Menlo, monospace', fontSize:11, color:'var(--text-subtle)' }}>.dd</span>
        }/>
    </div>

    <Divider/>
    <FooterRow icon={<IconSparkles size={14}/>} label="Snippet Editor…" kbd="⌘E"/>
    <FooterRow icon={<IconGear size={14}/>}     label="Preferences…"     kbd="⌘,"/>
    <Divider/>

    {/* Mode toggle inline */}
    <div style={{ padding: '6px 10px 10px' }}>
      <div style={{
        display: 'grid', gridTemplateColumns: '1fr 1fr',
        background: 'var(--input-bg)', borderRadius: 7, padding: 2,
        border: '1px solid var(--stroke-soft)',
      }}>
        {['Simple', 'Organized'].map((m, i) => (
          <div key={m} style={{
            textAlign: 'center', padding: '5px 0', fontSize: 12,
            borderRadius: 5,
            background: i === 1 ? 'var(--seg-selected)' : 'transparent',
            color: i === 1 ? 'var(--text-strong)' : 'var(--text-muted)',
            boxShadow: i === 1 ? 'var(--seg-shadow)' : 'none',
            fontWeight: i === 1 ? 500 : 400,
          }}>{m}</div>
        ))}
      </div>
    </div>
  </Popover>
);

// ---------- C: Hebrew RTL ----------
const MenubarHebrew = () => (
  <Popover width={340} style={{ direction: 'rtl' }}>
    <SearchField placeholder="חיפוש בלוח ובקטעים…" dir="rtl"/>
    <Section label="פריטים אחרונים" right={<span style={{ fontSize: 10.5, color: 'var(--text-subtle)', textTransform: 'none', letterSpacing: 0 }}>‎12 פריטים</span>}/>
    <div style={{ paddingBottom: 4 }}>
      <ClipRow dir="rtl" kbd="1" active kind={<IconText size={14}/>}
        title="שלום רונן, צירפתי את המסמך לבדיקה"
        sub="הועתק לפני דקה • Mail" />
      <ClipRow dir="rtl" kbd="2" kind={<IconHebrew size={14}/>}
        title="ת״ז: 039 824 167"
        sub="‎.תז — קטע מורחב" />
      <ClipRow dir="rtl" kbd="3" kind={<IconText size={14}/>}
        title={<span>John: שלום, מתי תהיה זמין?</span>}
        sub="‎דו־לשוני • Slack" />
      <ClipRow dir="rtl" kbd="4" kind={<IconText size={14}/>}
        title="י״א באייר ה׳תשפ״ו"
        sub="לוח עברי" />
      <ClipRow dir="rtl" kbd="5" kind={<IconLink size={14}/>}
        title="clipflow.app/he"
        sub="‎לפני 3 דק׳ • Safari" />
      <ClipRow dir="rtl" kbd="6" kind={
        <div style={{ width: 16, height: 16, borderRadius: 3, background: '#2A6FDB' }}/>
      } title="‎#2A6FDB" sub="‎צבע" />
    </div>
    <Divider/>
    <div style={{ direction: 'rtl' }}>
      <FooterRow icon={<IconSparkles size={14}/>} label="עורך הקטעים…" kbd="⌘E"/>
      <FooterRow icon={<IconGear     size={14}/>} label="העדפות…"      kbd="⌘,"/>
      <Divider/>
      <FooterRow icon={<IconTrash    size={14}/>} label="ניקוי היסטוריה" />
      <FooterRow icon={<IconPower    size={14}/>} label="יציאה מ־ClipFlow" kbd="⌘Q"/>
    </div>
    <div style={{ height: 6 }}/>
  </Popover>
);

// ---------- Composed artboard renderer ----------
const MenubarStage = ({ children, w = 540, h = 640, theme = 'dark' }) => (
  <div style={{
    width: w, height: h,
    background: theme === 'light'
      ? 'radial-gradient(120% 80% at 30% 0%, #cdd7ee 0%, #b6c3e0 50%, #8fa1c8 100%)'
      : 'radial-gradient(120% 80% at 30% 0%, #4b3c66 0%, #2a2440 40%, #18141f 100%)',
    position: 'relative',
    overflow: 'hidden',
  }}>
    {/* faux desktop wallpaper texture */}
    <div style={{
      position: 'absolute', inset: 0,
      background: theme === 'light'
        ? 'radial-gradient(60% 40% at 80% 90%, rgba(255,200,160,.55), transparent 60%),'
          + 'radial-gradient(40% 30% at 10% 80%, rgba(180,210,255,.55), transparent 60%)'
        : 'radial-gradient(60% 40% at 80% 90%, rgba(180,120,255,.20), transparent 60%),'
          + 'radial-gradient(40% 30% at 10% 80%, rgba(120,180,255,.18), transparent 60%)',
      pointerEvents: 'none',
    }}/>
    <StatusBarStrip/>
    <div style={{ position: 'absolute', top: 30, left: 18 }}>
      {/* anchor caret */}
      <div style={{
        width: 10, height: 10, transform: 'rotate(45deg)',
        background: 'var(--popover-bg-solid)',
        marginLeft: 6, marginBottom: -5,
        boxShadow: 'var(--caret-shadow)',
      }}/>
      {children}
    </div>
  </div>
);

Object.assign(window, { MenubarSimple, MenubarOrganized, MenubarHebrew, MenubarStage, KBD, Popover });
