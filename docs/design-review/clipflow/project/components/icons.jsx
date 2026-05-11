// Monochrome line icons in the SF Symbols spirit — strokes scale with currentColor.
const I = ({ children, size = 16, stroke = 1.6 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none"
    stroke="currentColor" strokeWidth={stroke}
    strokeLinecap="round" strokeLinejoin="round">
    {children}
  </svg>
);

const IconSearch    = (p) => <I {...p}><circle cx="11" cy="11" r="6.5"/><path d="m20 20-4-4"/></I>;
const IconClock     = (p) => <I {...p}><circle cx="12" cy="12" r="8.5"/><path d="M12 7v5l3.5 2.5"/></I>;
const IconImage     = (p) => <I {...p}><rect x="3.5" y="4.5" width="17" height="15" rx="2.5"/><circle cx="9" cy="10" r="1.6"/><path d="m4 17 4.5-4.5L13 17l3-3 4 4"/></I>;
const IconText      = (p) => <I {...p}><path d="M5 6h14M9 6v13M5 13h8"/></I>;
const IconLink      = (p) => <I {...p}><path d="M10 14a4 4 0 0 0 5.66 0l3-3a4 4 0 1 0-5.66-5.66l-1.5 1.5"/><path d="M14 10a4 4 0 0 0-5.66 0l-3 3a4 4 0 1 0 5.66 5.66l1.5-1.5"/></I>;
const IconSwatch    = (p) => <I {...p}><rect x="4" y="4" width="16" height="16" rx="3"/></I>;
const IconBolt      = (p) => <I {...p}><path d="M13 3 5 14h6l-1 7 8-11h-6l1-7Z"/></I>;
const IconStar      = (p) => <I {...p}><path d="m12 4 2.5 5.2 5.7.8-4.1 4 1 5.7L12 17l-5.1 2.7 1-5.7-4.1-4 5.7-.8L12 4Z"/></I>;
const IconPin       = (p) => <I {...p}><path d="M14 3 9 8H6l4.5 4.5L4 19l6.5-6.5L15 17v-3l5-5-6-6Z"/></I>;
const IconFolder    = (p) => <I {...p}><path d="M3.5 7.5a2 2 0 0 1 2-2H10l2 2h6.5a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2h-13a2 2 0 0 1-2-2v-10Z"/></I>;
const IconChevron   = (p) => <I {...p}><path d="m9 6 6 6-6 6"/></I>;
const IconChevronDn = (p) => <I {...p}><path d="m6 9 6 6 6-6"/></I>;
const IconPlus      = (p) => <I {...p}><path d="M12 5v14M5 12h14"/></I>;
const IconCmd       = (p) => <I {...p}><path d="M8 6a2 2 0 1 0 0 4h8a2 2 0 1 0 0-4M8 14a2 2 0 1 1 0 4h8a2 2 0 1 1 0-4M8 10v4M16 10v4"/></I>;
const IconGear      = (p) => <I {...p}><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1A1.7 1.7 0 0 0 4.6 15a1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1A1.7 1.7 0 0 0 9 4.6 1.7 1.7 0 0 0 10 3.1V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8 1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1Z"/></I>;
const IconTrash     = (p) => <I {...p}><path d="M4 7h16M9 7V5a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2v2M6 7l1 12a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2l1-12"/></I>;
const IconPower     = (p) => <I {...p}><path d="M12 4v8M7 7a7 7 0 1 0 10 0"/></I>;
const IconCloud     = (p) => <I {...p}><path d="M7 18h10a4 4 0 0 0 0-8 6 6 0 0 0-11.6-1.5A3.5 3.5 0 0 0 7 18Z"/></I>;
const IconCheck     = (p) => <I {...p}><path d="m5 12 4.5 4.5L19 7"/></I>;
const IconCircle    = (p) => <I {...p}><circle cx="12" cy="12" r="8.5"/></I>;
const IconKey       = (p) => <I {...p}><circle cx="8" cy="14" r="3.5"/><path d="m11 11 8-8 2 2-2 2 2 2-2 2-2-2-3 3"/></I>;
const IconSparkles  = (p) => <I {...p}><path d="M12 4v4M12 16v4M4 12h4M16 12h4M6.3 6.3l2.8 2.8M14.9 14.9l2.8 2.8M6.3 17.7l2.8-2.8M14.9 9.1l2.8-2.8"/></I>;
const IconBracket   = (p) => <I {...p}><path d="M9 4H5v16h4M15 4h4v16h-4"/></I>;
const IconArrowDown = (p) => <I {...p}><path d="M12 5v14M6 13l6 6 6-6"/></I>;
const IconLock      = (p) => <I {...p}><rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/></I>;
const IconDot       = (p) => <I {...p}><circle cx="12" cy="12" r="3" fill="currentColor"/></I>;
const IconHebrew    = (p) => <I {...p}><path d="M6 6v9a3 3 0 0 0 3 3h0a3 3 0 0 0 3-3V8M18 6v12M12 6h6"/></I>;

Object.assign(window, {
  IconSearch, IconClock, IconImage, IconText, IconLink, IconSwatch, IconBolt,
  IconStar, IconPin, IconFolder, IconChevron, IconChevronDn, IconPlus, IconCmd,
  IconGear, IconTrash, IconPower, IconCloud, IconCheck, IconCircle, IconKey,
  IconSparkles, IconBracket, IconArrowDown, IconLock, IconDot, IconHebrew,
});
