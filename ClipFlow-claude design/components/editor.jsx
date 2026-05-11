// macOS-style window chrome, lightweight (we don't need full browser_window).
const Window = ({ title, width = 1080, height = 700, children, toolbar }) => (
  <div style={{
    width, height,
    borderRadius: 12,
    overflow: 'hidden',
    background: 'var(--surface)',
    boxShadow: 'var(--window-shadow)',
    color: 'var(--text)',
    fontFamily: '"SF Pro Text", "Inter", -apple-system, system-ui, sans-serif',
    fontSize: 13,
    display: 'flex', flexDirection: 'column',
  }}>
    <div style={{
      height: 38, padding: '0 12px',
      display: 'flex', alignItems: 'center', gap: 10,
      background: 'var(--titlebar-bg)',
      borderBottom: '1px solid var(--stroke-soft)',
      position: 'relative',
    }}>
      <div style={{ display: 'flex', gap: 8 }}>
        {['#ff5f57', '#febc2e', '#28c840'].map(c => (
          <div key={c} style={{ width: 12, height: 12, borderRadius: '50%', background: c, boxShadow: 'inset 0 0 0 .5px var(--shadow-soft)' }}/>
        ))}
      </div>
      <div style={{
        position: 'absolute', left: 0, right: 0, textAlign: 'center',
        fontSize: 13, color: 'var(--text-mid)', fontWeight: 500,
      }}>{title}</div>
      <div style={{ marginLeft: 'auto', display: 'flex', gap: 6 }}>{toolbar}</div>
    </div>
    <div style={{ flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column' }}>{children}</div>
  </div>
);

// ----- Snippet Editor -----
const SidebarItem = ({ icon, label, count, active, depth = 0 }) => (
  <div style={{
    display: 'flex', alignItems: 'center', gap: 8,
    padding: '4px 10px', margin: '0 6px', borderRadius: 6,
    paddingLeft: 10 + depth * 14,
    background: active ? 'rgba(123,113,255,.22)' : 'transparent',
    color: active ? 'var(--text-strong)' : 'var(--text)',
    fontSize: 13,
  }}>
    <span style={{ color: active ? '#b8b1ff' : 'var(--text-muted)', display: 'flex' }}>{icon}</span>
    <span style={{ flex: 1, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{label}</span>
    {count != null && <span style={{ fontSize: 11, color: 'var(--text-faint)' }}>{count}</span>}
  </div>
);

const InspectorBlock = ({ title, children }) => (
  <div style={{ padding: '14px 16px', borderTop: '1px solid var(--stroke-soft)' }}>
    <div style={{
      fontSize: 10.5, fontWeight: 600, letterSpacing: '.06em',
      textTransform: 'uppercase', color: 'var(--text-subtle)',
      marginBottom: 10,
    }}>{title}</div>
    {children}
  </div>
);

const Field = ({ label, children, hint }) => (
  <div style={{ marginBottom: 12 }}>
    <div style={{ fontSize: 11.5, color: 'var(--text-muted)', marginBottom: 4 }}>{label}</div>
    {children}
    {hint && <div style={{ fontSize: 11, color: 'var(--text-faint)', marginTop: 4 }}>{hint}</div>}
  </div>
);

const Input = ({ value, mono, prefix, suffix, dir }) => (
  <div style={{
    display: 'flex', alignItems: 'center', gap: 6,
    height: 26, padding: '0 8px',
    background: 'var(--input-bg)',
    border: '1px solid var(--stroke)',
    borderRadius: 6,
    direction: dir,
  }}>
    {prefix && <span style={{ color: 'var(--text-subtle)', fontSize: 12 }}>{prefix}</span>}
    <span style={{
      flex: 1, color: 'var(--text)', fontSize: 13,
      fontFamily: mono ? 'ui-monospace, "SF Mono", Menlo, monospace' : 'inherit',
      whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
    }}>{value}</span>
    {suffix}
  </div>
);

const Select = ({ value }) => (
  <div style={{
    display: 'flex', alignItems: 'center',
    height: 26, padding: '0 8px',
    background: 'var(--btn-bg)',
    border: '1px solid var(--stroke)',
    borderRadius: 6,
  }}>
    <span style={{ flex: 1, fontSize: 13 }}>{value}</span>
    <span style={{ color: 'var(--text-muted)', display: 'flex' }}><IconChevronDn size={12}/></span>
  </div>
);

const Toggle = ({ on }) => (
  <div style={{
    width: 32, height: 18, borderRadius: 999,
    background: on ? 'oklch(.6 .17 272)' : 'var(--fill-3)',
    position: 'relative',
    boxShadow: 'inset 0 0 0 .5px var(--shadow-strong)',
  }}>
    <div style={{
      position: 'absolute', top: 2, left: on ? 16 : 2,
      width: 14, height: 14, borderRadius: '50%',
      background: 'var(--knob)',
      boxShadow: '0 1px 2px var(--shadow-strong)',
      transition: 'left .18s',
    }}/>
  </div>
);

const VarChip = ({ children }) => (
  <span style={{
    display: 'inline-flex', alignItems: 'center', gap: 4,
    padding: '2px 8px', borderRadius: 4,
    background: 'color-mix(in oklab, oklch(.62 .15 272) 30%, transparent)',
    color: 'oklch(.86 .12 272)',
    fontFamily: 'ui-monospace, "SF Mono", Menlo, monospace',
    fontSize: 12,
    border: '1px solid color-mix(in oklab, oklch(.62 .15 272) 35%, transparent)',
  }}>{children}</span>
);

const ToolbarBtn = ({ icon, label, primary }) => (
  <div style={{
    display: 'inline-flex', alignItems: 'center', gap: 6,
    height: 24, padding: '0 9px',
    background: primary
      ? 'linear-gradient(180deg, oklch(.65 .17 272), oklch(.55 .19 272))'
      : 'var(--btn-bg)',
    border: '1px solid ' + (primary ? 'oklch(.5 .19 272)' : 'var(--fill-2)'),
    color: 'var(--text-strong)',
    borderRadius: 6,
    fontSize: 12,
    boxShadow: 'var(--btn-shadow)',
  }}>
    {icon && <span style={{ display: 'flex' }}>{icon}</span>}
    {label}
  </div>
);

const SnippetEditor = () => (
  <Window title="Snippet Editor — Email signature"
    toolbar={<>
      <ToolbarBtn icon={<IconPlus size={12}/>} label="New"/>
      <ToolbarBtn label="Duplicate"/>
      <div style={{ width: 1, background: 'var(--fill-1)', margin: '0 2px' }}/>
      <ToolbarBtn icon={<IconCloud size={12}/>} label="Synced"/>
    </>}
  >
    <div style={{ flex: 1, display: 'grid', gridTemplateColumns: '230px 1fr 280px', minHeight: 0 }}>
      {/* Sidebar */}
      <div style={{
        background: 'var(--surface-alt)',
        borderRight: '1px solid var(--stroke-soft)',
        display: 'flex', flexDirection: 'column',
      }}>
        <div style={{ padding: '10px 8px 6px' }}>
          <div style={{
            display:'flex', alignItems:'center', gap: 8, height: 26, padding: '0 8px',
            background: 'var(--input-bg)', borderRadius: 6, border: '1px solid var(--stroke)',
          }}>
            <IconSearch size={12} stroke={1.8}/>
            <span style={{ flex: 1, color: 'var(--text-subtle)', fontSize: 12 }}>Filter snippets</span>
          </div>
        </div>
        <div style={{ flex: 1, overflow: 'hidden', paddingTop: 6 }}>
          <div style={{ padding: '6px 14px 4px', fontSize: 10.5, fontWeight: 600, letterSpacing: '.06em', textTransform: 'uppercase', color: 'var(--text-label)' }}>Library</div>
          <SidebarItem icon={<IconStar size={13}/>} label="Favorites" count="6"/>
          <SidebarItem icon={<IconClock size={13}/>} label="Recently used" count="22"/>

          <div style={{ padding: '14px 14px 4px', fontSize: 10.5, fontWeight: 600, letterSpacing: '.06em', textTransform: 'uppercase', color: 'var(--text-label)', display:'flex', justifyContent:'space-between' }}>
            <span>Groups</span>
            <span style={{ color: 'var(--text-subtle)', display:'flex' }}><IconPlus size={12}/></span>
          </div>
          <SidebarItem icon={<IconChevronDn size={12}/>} label="Personal" />
          <SidebarItem depth={1} icon={<IconBolt size={12}/>} label="Email signature" active/>
          <SidebarItem depth={1} icon={<IconBolt size={12}/>} label="Address — home"/>
          <SidebarItem depth={1} icon={<IconBolt size={12}/>} label="Today's date"/>
          <SidebarItem icon={<IconChevronDn size={12}/>} label="Code"/>
          <SidebarItem depth={1} icon={<IconBolt size={12}/>} label="React component scaffold"/>
          <SidebarItem depth={1} icon={<IconBolt size={12}/>} label="console.log"/>
          <SidebarItem depth={1} icon={<IconBolt size={12}/>} label="Swift property wrapper"/>
          <SidebarItem icon={<IconChevron size={12}/>} label="Hebrew · עברית"/>
          <SidebarItem icon={<IconChevron size={12}/>} label="Customer support"/>
        </div>
        <div style={{
          height: 30, padding: '0 12px',
          display: 'flex', alignItems: 'center', gap: 6,
          fontSize: 11, color: 'var(--text-subtle)',
          borderTop: '1px solid var(--stroke-soft)',
        }}>
          <IconCloud size={12}/> iCloud · synced 2m ago
        </div>
      </div>

      {/* Center editor */}
      <div style={{ display: 'flex', flexDirection: 'column', minHeight: 0, background: 'var(--surface)' }}>
        {/* Header */}
        <div style={{ padding: '14px 22px 10px' }}>
          <input defaultValue="Email signature"
            style={{
              fontSize: 22, fontWeight: 600, color: 'var(--text-strong)',
              background: 'transparent', border: 0, outline: 'none',
              fontFamily: 'inherit', width: '100%',
            }}/>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 8, color: 'var(--text-subtle)', fontSize: 12 }}>
            <span style={{ display:'inline-flex', alignItems:'center', gap:4 }}><IconFolder size={12}/> Personal</span>
            <span style={{ width: 3, height: 3, borderRadius: '50%', background: 'var(--text-bullet)' }}/>
            <span>Used 184 times · saved ≈ 27 min</span>
            <span style={{ width: 3, height: 3, borderRadius: '50%', background: 'var(--text-bullet)' }}/>
            <span>Updated yesterday</span>
          </div>
        </div>

        {/* Trigger row */}
        <div style={{
          margin: '0 22px',
          padding: '10px 12px',
          background: 'var(--fill-soft)',
          border: '1px solid var(--stroke)',
          borderRadius: 8,
          display: 'grid', gridTemplateColumns: '1fr auto auto', gap: 10, alignItems: 'center',
        }}>
          <div>
            <div style={{ fontSize: 11, color: 'var(--text-subtle)', marginBottom: 4 }}>Abbreviation</div>
            <div style={{
              display: 'inline-flex', alignItems: 'center', gap: 4,
              fontFamily: 'ui-monospace, "SF Mono", Menlo, monospace',
              fontSize: 14, color: 'var(--text-strong)',
            }}>
              <span style={{ color: 'oklch(.78 .14 272)' }}>.</span>sig
              <span style={{ marginLeft: 8, fontSize: 11, color: 'var(--text-subtle)' }}>
                must start with <code>.</code> <code>;</code> or <code>/</code>
              </span>
            </div>
          </div>
          <div>
            <div style={{ fontSize: 11, color: 'var(--text-subtle)', marginBottom: 4 }}>Trigger</div>
            <Select value="Space, Tab or Enter"/>
          </div>
          <div>
            <div style={{ fontSize: 11, color: 'var(--text-subtle)', marginBottom: 4 }}>Status</div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
              <Toggle on/>
              <span style={{ fontSize: 12, color: 'var(--text-mid)' }}>Enabled</span>
            </div>
          </div>
        </div>

        {/* Variable toolbar */}
        <div style={{
          margin: '14px 22px 0',
          display: 'flex', alignItems: 'center', gap: 6,
          fontSize: 12,
        }}>
          <span style={{ color: 'var(--text-subtle)', marginRight: 4 }}>Insert</span>
          {['{date}', '{time}', '{clipboard}', '{cursor}', '{prompt:Name}'].map(v => (
            <VarChip key={v}>{v}</VarChip>
          ))}
          <div style={{ flex: 1 }}/>
          <span style={{ color: 'var(--text-faint)', fontSize: 11 }}>{'{date:yyyy‑MM‑dd}'} for custom format</span>
        </div>

        {/* Editor body */}
        <div style={{
          margin: '12px 22px 0', flex: 1,
          background: 'var(--surface-deep)',
          border: '1px solid var(--stroke)',
          borderRadius: 8,
          padding: 16,
          fontSize: 14, lineHeight: 1.55,
          color: 'var(--text)',
          overflow: 'hidden',
        }}>
          <div>Best,</div>
          <div style={{ height: 8 }}/>
          <div style={{ fontWeight: 600 }}>Ronen Ben‑Ami</div>
          <div>Product Engineer · ClipFlow</div>
          <div style={{ display: 'flex', gap: 6, alignItems: 'center', marginTop: 4 }}>
            <span style={{ color: 'var(--text-muted)' }}>m:</span>
            <VarChip>{'{prompt:Phone}'}</VarChip>
          </div>
          <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
            <span style={{ color: 'var(--text-muted)' }}>w:</span>
            <span>clipflow.app</span>
          </div>
          <div style={{ height: 14 }}/>
          <div style={{ display: 'flex', gap: 6, alignItems: 'center', color: 'var(--text-muted)' }}>
            <span>Sent on</span>
            <VarChip>{'{date:EEEE, MMM d}'}</VarChip>
            <span>at</span>
            <VarChip>{'{time:HH:mm}'}</VarChip>
            <span style={{ display:'inline-block', width: 1.5, height: 16, background: 'oklch(.78 .14 272)', marginLeft: 2 }}/>
          </div>
        </div>

        {/* Status bar */}
        <div style={{
          height: 28, padding: '0 22px',
          display: 'flex', alignItems: 'center', gap: 14,
          fontSize: 11, color: 'var(--text-subtle)',
          borderTop: '1px solid var(--stroke-soft)',
        }}>
          <span>Plain text</span>
          <span style={{ width: 3, height: 3, borderRadius: '50%', background: 'var(--text-bullet)' }}/>
          <span>9 lines · 142 chars</span>
          <span style={{ width: 3, height: 3, borderRadius: '50%', background: 'var(--text-bullet)' }}/>
          <span>2 variables</span>
          <div style={{ flex: 1 }}/>
          <span style={{ display:'inline-flex', alignItems:'center', gap:4 }}>
            <span style={{ width: 6, height: 6, borderRadius: '50%', background: 'oklch(.7 .17 145)' }}/>
            Saved
          </span>
        </div>
      </div>

      {/* Inspector */}
      <div style={{ background: 'var(--surface-alt)', borderLeft: '1px solid var(--stroke-soft)', overflow: 'hidden' }}>
        <div style={{ padding: '12px 16px 6px' }}>
          <div style={{ fontSize: 13, fontWeight: 600, color: 'var(--text-strong)' }}>Inspector</div>
          <div style={{ fontSize: 11, color: 'var(--text-subtle)', marginTop: 2 }}>How and where this snippet fires</div>
        </div>

        <InspectorBlock title="Trigger">
          <Field label="Abbreviation prefix">
            <Select value="Period (.)"/>
          </Field>
          <Field label="Fires on" hint="Choose when expansion runs after typing the abbreviation.">
            <div style={{
              display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 4,
              padding: 2, background: 'var(--input-bg)', borderRadius: 6,
              border: '1px solid var(--stroke)',
            }}>
              {[['Space', true], ['Tab', true], ['Enter', true], ['Punct.', false], ['Any', false], ['Manual', false]].map(([l, on]) => (
                <div key={l} style={{
                  textAlign: 'center', fontSize: 11, padding: '4px 0', borderRadius: 4,
                  background: on ? 'var(--fill-2)' : 'transparent',
                  color: on ? 'var(--text-strong)' : 'var(--text-subtle)',
                  boxShadow: on ? 'inset 0 1px 0 var(--inset-hi)' : 'none',
                }}>{l}</div>
              ))}
            </div>
          </Field>
          <Field label="Cursor placement">
            <Select value="Wherever {cursor} is"/>
          </Field>
        </InspectorBlock>

        <InspectorBlock title="App rules">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
            <span style={{ fontSize: 12, color: 'var(--text-mid)' }}>Restrict to apps</span>
            <Toggle on/>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
            {[['Mail', true], ['Slack', true], ['Safari', true], ['Xcode', false]].map(([n, on]) => (
              <div key={n} style={{
                display: 'flex', alignItems: 'center', gap: 8,
                padding: '4px 8px', borderRadius: 6,
                background: 'var(--fill-soft)',
                border: '1px solid var(--stroke-soft)',
              }}>
                <div style={{ width: 16, height: 16, borderRadius: 4, background: 'var(--fill-1)' }}/>
                <span style={{ flex: 1, fontSize: 12 }}>{n}</span>
                <span style={{ fontSize: 11, color: on ? 'oklch(.8 .14 145)' : 'var(--text-faint)' }}>{on ? 'allow' : 'deny'}</span>
              </div>
            ))}
          </div>
        </InspectorBlock>

        <InspectorBlock title="Statistics">
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
            {[['184', 'expansions'], ['27 min', 'time saved'], ['Mail', 'top app'], ['May 9', 'last used']].map(([v, l]) => (
              <div key={l} style={{
                padding: '8px 10px',
                background: 'var(--fill-soft)',
                border: '1px solid var(--stroke-soft)',
                borderRadius: 6,
              }}>
                <div style={{ fontSize: 14, fontWeight: 600, color: 'var(--text-strong)' }}>{v}</div>
                <div style={{ fontSize: 10.5, color: 'var(--text-subtle)' }}>{l}</div>
              </div>
            ))}
          </div>
        </InspectorBlock>
      </div>
    </div>
  </Window>
);

Object.assign(window, { Window, SnippetEditor, ToolbarBtn, Toggle, Select, Input, Field, InspectorBlock, SidebarItem, VarChip });
