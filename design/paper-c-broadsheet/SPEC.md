# Paper C — "Broadsheet"

A design specification for variant **C** of the `paper` theme, the proposed replacement for the
`pixel` panel family. It covers the same surfaces, the same data and the same interactions as
`design/current-pixels/SPEC.md` — only the visual language changes. Companion HTML mockups live
next to this file and render every surface at real proportions with real fake data.

Variants A and B of `paper` are more minimal. **C is the richest of the three**: it keeps the warm
sheet and the hairline structure and adds real typographic ornament — double and Oxford rules,
corner ticks, letterspaced small-cap section heads, oldstyle figures, sepia seals — plus a
two-colour editorial accent. The ornament is always *thin* and always marks structure. If a rule
is not separating something, or a tick is not marking a focused surface, it does not get drawn.

---

## 1. Design language in one paragraph

A beautifully typeset broadsheet, laid on the desktop. Every panel is an opaque sheet of warm
paper with a 1 px hairline edge, a whisper of grain and no rounding — a sheet is *cut*, not
rounded. Structure is carried by rules rather than boxes: a hairline separates, a double rule
closes a block, an Oxford rule (2 px over a hairline) is a masthead. Type does the rest: a
serif display face (TeX Gyre Pagella) sets titles, clock and all numerals in genuine oldstyle
figures; a humanist sans (Lato) sets labels, statuses and control text; letterspaced small caps
announce sections, and Pagella italic is the voice of placeholders, footnotes, tooltips and
"busy". Icons are a single 1.25 px keyline on a 20-unit grid, which never scales — a 40 px
session glyph is drawn with the same hairline as a 12 px row glyph, so the set reads as engraving
rather than as UI. Colour is rationed to three inks: **oxblood** for active / selected / danger,
**ink blue** for "connected to something out there", and **sepia** for stamps and ornament, each
with a paper-tinted wash. Interaction is a wash step, a rule-colour change, an accent underline
or a 2 px change bar in the left margin — never an invert, never a shadow, never a glow. The one
place colour is allowed to run free is the album art in the media controls, and it is mounted
like a plate in a book.

---

## 2. Design tokens

Light ("paper") is the primary palette; dark ("dusk paper") is a full companion, not an
inversion. The theme reads only `Appearance.m3colors.darkmode`, exactly as the pixel family does;
no wallpaper-derived colour reaches it.

### 2.1 Colours

| Token | Paper (light) | Dusk paper (dark) | Used for |
|---|---|---|---|
| `paper` | `#F6F2E9` | `#17140F` | The sheet: every panel, popup, bar, toast, tile ground |
| `paper2` | `#EFEADD` | `#1E1A14` | Inset cards, control rest fill, tinted rows |
| `paper3` | `#E6DFCE` | `#26211A` | Hover wash (one step) |
| `paper4` | `#DCD3BE` | `#302A21` | Press wash (two steps) |
| `ink` | `#241F1A` | `#EDE6D8` | Headlines, values, solid fills |
| `ink2` | `#57503F` | `#C3BAA8` | Body copy, control labels |
| `ink3` | `#7E7565` | `#938A79` | Kickers, metadata, statuses |
| `ink4` | `#B0A794` | `#6A6252` | Footnotes, disabled, out-of-month days |
| `rule` | `#CFC6B2` | `#39322A` | The hairline: every border, every separator |
| `rule2` | `#B3A991` | `#564E42` | Stronger hairline: sheet edge, gauge baseline, Oxford's thin half |
| `accent` (oxblood) | `#7B2A24` | `#C9736A` | Active, selected, seek, danger, change bars |
| `accentWash` | `#F0E4DF` | `#2E211E` | Tint behind an active control |
| `blue` (ink blue) | `#27456E` | `#93B0D4` | Connected, informational, the focus keyline |
| `blueWash` | `#E2E6EE` | `#1B2029` | Tint behind a connected control |
| `seal` (sepia) | `#8A6A3B` | `#C6A470` | Stamps, seals, ornament, warning |
| `sealWash` | `#EFE7D6` | `#26201A` | Stamp ground |
| `selection` | `#DED6C2` | `#2C261E` | Text selection, keyboard-selected row ground |

Dusk paper keeps a warm-brown ground rather than neutral black; the accents are lifted in
lightness and dropped in saturation so they never glow, and the hairlines move *closer* to the
ground so rules whisper.

Translucency exists in exactly four places:

* session-screen scrim — `rgba(28,24,19,.72)` light / `rgba(8,7,5,.78)` dusk
* worktrees-dialog scrim — same values
* overview scrim — same colour at `.55`
* overview window hover / press wash — `paper3` / `paper4` behind the thumbnail, not an alpha wash

Grain: a fractal-noise tile (140 px, `saturate 0`, alpha `.055`) multiplied over every paper
ground and the wallpaper. It is invisible until looked for, and it is what stops a 360 × 1080
panel from reading as plastic.

### 2.2 Fonts

Three libre faces, all packaged on Fedora and all bundled in `assets/fonts/` exactly as the pixel
family bundles its bitmap faces.

* **Display — `PaperTitle` / all numerals: TeX Gyre Pagella** (Palatino lineage, GUST font
  licence). Chosen because it is the rare libre text serif that ships **real** `smcp` small caps,
  `onum` oldstyle figures, `tnum` tabular figures, `lnum` and `frac`, and because Palatino's
  broad, calligraphic forms stay warm at 13 px where a Garamond would go thin. Fallback stack:
  Palatino Linotype → URW Palladio L → Libertinus Serif → Bitstream Charter → Noto Serif →
  Georgia.
  Qt applies the features via `Font.features` (`{"onum":1,"tnum":1}` for figures,
  `{"smcp":1,"c2sc":1}` for small caps).
* **Data — `PaperText`: Lato.** Humanist, slightly narrow, quiet at 11–13 px, and warm enough to
  sit beside Palatino. Weights used: 400, 600, 700 (700 only for letterspaced small-cap kickers).
* **Micro — `PaperMono`: Source Code Pro.** Paths, connector names, modes, resolutions, key/value
  values and the worktrees log. Never prose.

Role split, the newspaper model:

| Role | Face | Example |
|---|---|---|
| Kicker (section head, app name, field label) | Lato 700, caps, `letterSpacing 0.15em` | `CONNECTED (3)` |
| Headline (row title, notification summary) | Pagella 400 | *Marta — "landing 18:40"* |
| Deck (body copy) | Pagella 400 | notification bodies, explanatory paragraphs |
| Agate (metadata, status) | Lato 400 | `Connected · 92%` |
| Figures (clock, percent, dates, counters) | Pagella `onum tnum` | `09:42` `82%` |
| Footnote (hint, placeholder, busy, empty state) | Pagella italic | *Searching for lyrics…* |
| Micro-data | Source Code Pro | `3840×2160@60  0,0  1.5×` |

### 2.3 Type scale

| Token | px | Face | Where |
|---|---|---|---|
| `micro` | 10 | Lato 700 caps | kickers, section heads, accelerators, stamps (9.5) |
| `agate` | 11 | Lato 400 / Source Code Pro | metadata, statuses, captions, workspace numerals |
| `small` | 12 | Lato 400/600 | control labels, chips, calendar days, secondary rows |
| `body` | 13 | Lato 400; Pagella for prose | default body, list-row names |
| `lede` | 15 | Pagella 400 | row titles, notification summaries, stat values |
| `title` | 17 | Pagella 400 | panel titles, bar clock, media track title |
| `display` | 21 | Pagella 400 `onum` | OSD value, search field, big stat numerals |
| `banner` | 26 | Pagella 400 `smcp` | the SESSION masthead |
| `folio` | 46 | Pagella 400 `lnum tnum` | pomodoro digits |

Off-scale: 9 px for the bar's stat kickers and the quick-settings mini-button labels; 66 px for
the workspace numeral inside an exposé tile (`min(66, tileHeight * 0.36)`); 38 px for session
glyphs.

### 2.4 Rules, radii, elevation

| Token | Value | Where |
|---|---|---|
| `ruleHair` | 1 px `rule` | every border, every list separator |
| `ruleFine` | 1 px `rule2` | sheet edge, gauge baseline, panel outline |
| `ruleDouble` | 1 px + 1 px gap + 1 px `rule2` (3 px) | closes a block that owns a whole section |
| `ruleOxford` | 2 px `ink` + 1 px gap + 1 px `rule2` (4 px) | every masthead, and the bar's bottom edge |
| `changeBar` | 2 px `accent`, full row height, flush left | hover / selection / current lyric |
| `cornerTick` | 6 × 6 px L, 1 px `rule2`, inset 4 px | a floating or focused sheet; 4 px inset −1 on a workspace cell |
| radius (controls) | 2 px | buttons, chips, slots, fields |
| radius (sheets) | 0 | panels, popups, toasts, tiles — paper is cut |
| radius (medallions) | 999 px | battery, seals, OSD glyph, profile markers |
| `shade` | `0 1px 1px rgba(36,31,26,.05), 0 10px 26px rgba(36,31,26,.09)` | floating surfaces only; always with a 1 px edge |
| `shadeSm` | `0 1px 2px rgba(36,31,26,.07)` | tooltips, album plate, window thumbnails |
| disabled | text → `ink4`, border → **dotted** `rule`, no fill | never a blanket opacity |
| `barHeight` | 42 px (exclusive zone 42) | the bar, Oxford rule included |

Docked panels (quick settings, displays) get **no** shadow — only the edge rule against the
screen edge. Floating ones (popups, toasts, OSD, media, dialogs, search) get `shade`.

### 2.5 Spacing scale

`2 · 4 · 6 · 8 · 10 · 12 · 16 · 20 · 24 · 32`

In practice: sheet padding **14** (bar 12, toasts 12/13, popups 14, dialogs 14); section gap
**12**; row gap **8**; icon-to-label **8**; label-to-value **6**; chip and button rows **6**;
tile grids **6**; session tile gap **18**; system-monitor column gap **26**.

### 2.6 Icons

`PaperIcon` — inline SVG, **20 × 20 unit grid**, `fill: none`, `stroke: currentColor`,
**stroke-width 1.25 with non-scaling stroke** (1.4 above 26 px), round caps and joins. Only the
Wi-Fi dot and the transport triangles are filled. Colour defaults to `ink2`.

Set (58 glyphs): `arrowD arrowU battery bell bluetooth bolt branch calendar check chevD chevL
chevR chevU clock close coffee cpu crop dropper expand eye flashoff folder gear grid heart info
keyboard lock logout message mic minus mirror monitor moon next nodes note pause pencil phone
play plus power prev ram refresh robot search server sliders snow sparkle speaker sun swap
terminal timer todo trash warn wifi wifioff`.

Unlike the 7 × 7 bitmap set, this one has real `lock`, `logout`, `monitor`, `mirror`, `search`,
`phone`, `play/pause/prev/next`, `plus/minus/check/close` and `arrowU/arrowD` glyphs, so the
substitutions listed in the pixel spec (§2.6) all disappear.

Sizes: 10–11 (stamps), 12–13 (inline row glyphs), 14–15 (buttons, bar), 16–17 (slots, tiles,
managers), 20 (search), 26 (empty-state), 38 (session tiles).

Icons may sit bare, in a **square slot** (1 px hairline, 2 px radius) or in a **medallion**
(circle) — see §3.4.

### 2.7 Control sizes

| Control | Size |
|---|---|
| `PaperButton` default | height 30, padding 0 10 |
| inline / row button | height 24 · 26 · 28 |
| primary button | height 32 · 34 |
| square icon button | 30 × 28 (headers) · 26 × 26 (inline) · 44 × 48 (quick-settings column) |
| icon slot | 28 × 28 (tiles, cards) · 32 × 32 (app icon) · 18–20 (checkbox) |
| toggle tile | fill × 48 |
| quick-settings utility button | fill × 34 |
| notification footer buttons | 40 × 30 |
| calendar mini-button | 58 × 50 |
| quick-layout mode button | fill × 52 |
| arrangement picker | fill × 50 |
| chip | height 24 · 26 |
| field | height 30 (26 inline, 28 in editors) |
| session tile | 128 × 128 |
| bar workspace cell | 26 × 24, 5 px gap, 17 px icon |
| media transport | 42 × 30 sides, fill × 30 centre |

### 2.8 Surface sizes

Bar full width × 42 · bar popups content-sized, hung 48 from the top · quick settings 360 ×
screen height (right) · displays 380 × screen height (left) · notification toast 356 inside a 380
window, 10 apart, first at 58 · media controls 460 × 172, 388 with lyrics · search 560 wide,
results capped at 520 · exposé tiles 346 × 186 in a 2 × 5 grid, 6 apart · worktrees 440 wide,
capped at 900 · session tiles 6 × 128, 18 apart · OSD content-sized, centred, 56 from the top.

### 2.9 Motion

| Token | Value | Where |
|---|---|---|
| `dur1` | 90 ms | tint washes: hover, press, row highlight |
| `dur2` | 160 ms | rule and colour changes, accent underline, chevron rotation, the focus keyline travelling between workspace cells |
| `dur3` | 280 ms | real geometry: the media card growing lyrics, an overlay covering a panel |
| — | 420 ms | lyric auto-scroll (suspended 4 s after a manual scroll) |
| — | 110 ms | search-list selection travel |
| `ease` | `cubic-bezier(.2,.7,.3,1)` | the only curve; nothing bounces, nothing overshoots |

---

## 3. Shared widget catalog

See `widgets.html` for every state of every widget.

### 3.1 `PaperSheet` — the container primitive
`paper` fill + grain, 1 px `rule2` edge, radius 0. `floating: true` adds `shade`; `ticks: true`
adds the four corner ticks. Used for: quick settings, displays, worktrees, media card, search
field and results, toasts, OSD, bar popups, session tiles, exposé container, tooltips.

`PaperCard` is its inset sibling: `paper2` fill, 1 px `rule` edge — monitor cards, profile rows,
repo rows, toggle tiles. `PaperCard { quiet: true }` inverts the pairing (paper on a tinted
parent) for the worktrees log well and the lyric well.

### 3.2 `PaperButton`
Rest: `paper2` fill, 1 px `rule` edge, 2 px radius, label `ink2` at 12.
Hover: fill → `paper3`, edge → `rule2`, label → `ink`, and a 1 px accent underline drawn inside
the frame (`--dur2`). Press: fill → `paper4`, edge → `ink3`.
`checked` / `active`: edge, label and a 600 weight in `accent` over `accentWash`; the `blue`
variant is used when the state means "connected to something outside the machine".
`solid`: `ink` fill, `paper` label — reserved for the single committing action on a surface
(Save, Create). `solid accent` for destructive confirmation (Remove).
`disabled`: `ink4` label, dotted `rule` edge, no fill.
The frame weight never changes, only its colour, so nothing shifts by a pixel under the pointer.

### 3.3 `PaperField`
30 px, `paper` fill, 1 px `rule` with a `rule2` bottom, 9 px side padding, Lato 13.
Focus thickens the **bottom** hairline to 2 px `accent`; nothing else moves. Placeholders are
Pagella italic in `ink4` — visibly an editor's pencil note rather than your text. Invalid keeps
the 2 px oxblood underline and prints the reason as an oxblood italic footnote below.
Selection uses `selection` ground with `ink` text.

### 3.4 `PaperSlot` / `PaperMedallion`
A square hairline slot (2 px radius) or a circle. Rest `paper` + `rule` + `ink2`; active
`accentWash` + `accent`; connected `blueWash` + `blue`; solid `ink` + `paper`.
**Rule of thumb:** square slots hold *settings* (Wi-Fi toggle, night light, an output being
enabled); medallions hold *states of the world* (battery, the OSD subject, a profile marker, a
charging seal).

### 3.5 `PaperStamp` / `PaperSeal`
A stamp is a 1 px `seal` frame over `sealWash`, letterspaced 9.5 px caps, optionally rotated
−3.5°, used for a state you would rubber-stamp on paper: `Charging`, `Daemon on`, `Connected`,
`Mirror`, `Running`. `accent` and `blue` variants exist. A seal is the circular version
(a double ring) and is used once per surface at most.

### 3.6 `PaperGauge` — the rule gauge
A hairline baseline in `rule2`, tick marks every 5 % (major, taller and darker, every 25 %), and
a 4 px `ink` bar overprinted from the left up to the value; `accent` when the value is a warning
or the subject is muted. Popups use a 10 % tick spacing so a 120 px column does not go grey.
It is the scale on the edge of a chart, which is exactly why it can serve the OSD, the
system-monitor popup, the pomodoro and the media progress bar (there without ticks, with a 2 px
oxblood bar and a 1 px oxblood upright at the play head) without changing costume.

### 3.7 `PaperRow`
Bare paper with hairline separators. Hover: `paper2` ground plus a 2 px oxblood **change bar** in
the left margin, and the primary label goes italic. Keyboard selection: `selection` ground, the
change bar stays, the label goes 600. This is the manuscript change-bar idiom, and it is the same
in the Wi-Fi list, the search results, the reopen list and the profile list.

### 3.8 `PaperTooltip`
A floating sheet, 1 px `rule2`, `shadeSm`, 4/9 px padding, Pagella **italic** 12, 350 ms delay,
120 ms hide debounce, 14 px from the anchor, click-through input region. A marginal gloss, not a
system label. A second line may be `mono` 10.5 in `ink3` (window class, priority hints).

### 3.9 `PaperAppIcon`
Real app artwork is desaturated and duotoned `ink2 → paper` — a newsprint halftone — then set in
a hairline slot at 17 / 26 / 30 / 32 px. Unresolvable icons fall back to the app's initial set in
Pagella inside the same slot, or to the `grid` glyph (`message` for notifications). Tray icons
are drawn **without** the slot so the bar stays airy.

### 3.10 `PaperBattery`
A 24 × 11 body, 1 px `rule2`, 2 px radius, plus a 2 × 5 cap. The fill is `ink`, inset 1.5 px,
width proportional to charge; it turns `accent` below 15 % or while charging, and a `Chg` stamp
with a `bolt` glyph is printed beside the percentage while charging. Percentage is always Pagella
`onum tnum`.

### 3.11 Section heads
`kicker` + a hairline that runs to the measure. A block that owns a whole section closes with a
double rule; a masthead sits over an Oxford rule. An optional right-hand note (`from main@origin`,
`3 unread`, `+ New`) sits between two runs of hairline — the newspaper "cut-in" idiom.

### 3.12 Composites
`PaperToggleTile` (§4.3), `PaperSegment` (one frame, hairline dividers, the current cell washed
and lettered in oxblood — no sliding pill), `PaperStepper` (label + footnote, then a framed
`[−] value [+]` with the value in oldstyle figures), `PaperChipRow`, `PaperKeyValue` (small-caps
keys in a 74 px column, mono values), `PaperStat` (glyph + 9 px kicker + oldstyle value),
`PaperDivider` (1 px × 18 with 13 px margins), `PaperPlate` (album art: 3 px paper mount, 1 px
frame, 1 px printed inside the image).

---

## 4. Surface inventory

Data, states and interactions are unchanged from `design/current-pixels/SPEC.md` §4; what follows
describes the paper layout of each.

### 4.1 Background
Unchanged in behaviour, replaced in content: the procedural 1-bit landscape does not belong to
this language. Broadsheet ships **no** background of its own and leaves the user's wallpaper
alone; a paper shell is designed to be laid *on* something. (If a generated background is wanted
later, the natural move is a large-format engraved plate on the paper ground, not a scroller.)

### 4.2 Bar — `bar.html`
42 px, opaque paper + grain, content inset 12 px, and an **Oxford rule** along the bottom edge:
2 px `ink`, 1 px gap, 1 px `rule2`. That rule is the strongest single piece of structure in the
shell, and it is what makes the bar read as a masthead rather than a widget strip. Scroll regions
(left = brightness, right = volume) are unchanged.

**Left** — tray: one 19 px halftoned app icon per pinned item, 12 px apart, no slot; right-click
opens the item menu, hover shows its tooltip. Divider (1 × 18, 13 px margins). Stats, 15 px
apart: `ram` / `cpu` / `robot` glyph at 14, a 9 px letterspaced kicker (`mem` `cpu` `claude`) and
the value in Pagella `onum` 15. Divider. Media: `note` glyph at 13 and the current track in
**Pagella italic 13**, elided at 220 — italic because it is a title, and because it is the one
piece of the bar that is quoting something else.

**Centre** — ten 26 × 24 workspace cells, 5 px apart, all sitting on one hairline baseline (the
row has a bottom `rule`). Occupied: the halftoned icon of the biggest window at 17. Empty: the
workspace number in Pagella `onum` 12 at `ink4`. Focused: a 1 px `blue` frame with `blueWash`
plus four `blue` corner ticks, travelling between cells in 160 ms. There is no fill and no
inversion — the icons stay legible.

**Right** — the clock in Pagella `onum tnum` 17, a 1 × 14 hairline, the date in agate 11.
Divider. `crop` and `sun` glyphs at 16, 13 px apart. Divider. The battery glyph, the percentage
in Pagella `onum` 15, and the `Chg` stamp while charging.

**Hover popups** — floating sheets with corner ticks, 14 px padding, hung 48 px from the top,
centred under the target (left-aligned for the stats popup).
* **Clock** — `dddd, d MMMM yyyy` as a Pagella 17 masthead over an Oxford rule; `System uptime`
  as a kicker with the value right-aligned in oldstyle figures; a double rule; `To do` +
  `N pending`; then up to five items, each an oxblood oldstyle numeral in a 14 px right-aligned
  column and the task in Pagella 12.5, with "… and N more" as a footnote.
* **Battery** — a 38 px seal holding the `bolt` glyph, the `Battery` kicker over the percentage in
  Pagella 21, and the charging stamp tilted at the right; Oxford rule; then `Time to full`,
  `Rate`, `Health` as kicker/value rows.
* **System monitor** — three columns 26 px apart. Each column: glyph + kicker + a double rule,
  then agate/value rows with the rule gauge under any row that is a proportion. A hairline, then
  a footnote line with the update age and the reset times.

### 4.3 Quick settings — `quick-settings.html`
360 px, docked right, full height, no shadow, 14 px padding, 12 px section gap.

1. **Masthead** — `Uptime` kicker over the value in Pagella `onum` 15; four 30 × 28 icon buttons
   (`pencil` Edit, `refresh` Refresh, `gear` Settings, `power` Power). **Oxford rule.**
2. **Row A** — Internet tile, Bluetooth tile, and a 44 × 48 `coffee` button (keep awake).
3. **Row B** — a 44 × 48 `mic` button, Audio-out tile, Night-light tile.
4. **Row C** — five equal 34 px buttons (`nodes` WARP, `expand` Game mode, `sliders` Easy
   Effects, `flashoff` Anti-flashbang, `dropper` Colour picker) with a footnote naming them, so
   the row needs no tooltips to be readable at a glance (tooltips remain).
5. **Double rule**, then **Notifications** — kicker + `N unread` footnote, then one row per app
   group separated by hairlines; the list flex-grows.
6. **Footer** — a 40 × 30 `bell`, a full-width non-interactive dotted button reading
   `N NOTIFICATIONS` as a kicker, a 40 × 30 `trash`.
7. **Double rule**, then the **calendar block**: a left column of three 58 × 50 mini-buttons
   (`Cal` / `To do` / `Time`, glyph over a 9 px letterspaced label, the active one oxblood), and
   the 178 px pane on the right.

**Toggle tile** — a 48 px card, 28 px slot, a 12.5 px Lato 600 title over an 11 px agate status.
Active is carried by three quiet signals at once — slot wash, frame colour, title colour — never
by a fill that swallows the tile.

**Notification row** — a 30 px app icon, then kicker (app) · agate (age) · optional count chip
with a chevron that rotates 180° in 160 ms · headline (latest summary, Pagella 15) · deck (body,
Pagella 12). Expanded, each entry gets its summary, a wrapped 3-line body and a 22 px `trash`.

**Calendar pane** — title row: `MMMM yyyy` in Pagella `onum` 17 with two 26 × 24 nav buttons; a
hairline; then a 7-column grid, weekday header in 9 px letterspaced caps, day cells 23 px in
Pagella `onum` 13, out-of-month at `ink4`, **today framed in 1 px oxblood over `accentWash` with
oxblood figures** (no solid block — a circled date in a diary).
**To do** — 18 px checkbox (a `check` in oxblood when done), the task in Pagella 12.5 (struck and
`ink4` when done), a `trash`; then a 26 px field with an italic `Add task…` placeholder and a 26
px `plus`.
**Timer** — `Focus` / `Break` / `Long break` as an oxblood kicker with `cycle 3 of 4` as a
footnote, the remaining time in Pagella `lnum tnum` **46**, the rule gauge showing the phase
progress, then Pause (active) and Reset.

**Management overlays** — cover the panel on an opaque paper ground, sliding in over 280 ms. Back
bar: `chevL`, the title in Pagella small caps, `refresh`, and the radio state as a stamp-button —
the same masthead grammar as the panel, one level down. Rows are `PaperRow`s: glyph, name over
status, and a `lock` glyph for secured networks / a `On`–`Linked` blue stamp for the connected
one. Empty states are Pagella italic footnotes (*Scanning…*, *Wi-Fi off*, *Searching…*).

### 4.4 Notification popups — `notifications.html`
356 px toasts in a 380 px click-through window, 10 px apart, the first 58 px from the top; each a
floating sheet with corner ticks, 12/13 px padding. Contents are the four levels of an editorial
item: a 32 px app icon at the left, then kicker (app name) with the age in agate on the right, the
summary as a Pagella 15 headline, the body as a Pagella 12.5 deck clamped to two lines, and one
full-width equal-width button per **labelled** action, 8 px apart. Hover holds the auto-dismiss
timer and marks only the hovered action.

### 4.5 On-screen display — `osd.html`
A content-sized floating sheet with corner ticks, centred, 56 px from the top, 12/16 px padding.
A 34 px medallion holding `speaker` / `flashoff` / `sun`, then a 216 px column: the kicker
(`Volume` / `Brightness`) with the value in Pagella `onum` 15 right-aligned, over the rule gauge.
Muted turns the medallion and the gauge oxblood and sets the value as the **word** *muted* rather
than `0%`.

### 4.6 Overview / launcher — `overview.html`
Scrim at 55 %. Column starts at 12 % of screen height, 18 px between the two widgets.

**Search** — a 560 × 48 floating sheet with corner ticks: a 20 px `search` glyph, the query in
Pagella 21 with a 1 px oxblood caret, and `ctrl+j / ctrl+k` as a right-aligned footnote. The
results sheet joins it seam-to-seam (−1 px) with a single hairline across the seam, 6 px inner
margin, capped at 520. Each row: a 26 px app icon or a glyph in a hairline slot, the entry type
as a kicker (hidden for apps) over the name at 13.5, and — only when selected — the verb
(*open*, *run*, *search*) in **Pagella small caps oxblood** on the right. The selected row takes
the selection ground and the change bar. A calculation result prints in oxblood oldstyle figures
at the right of the field itself.

**Exposé** — a floating sheet with 12 px padding around a 2 × 5 grid of 346 × 186 tiles, 6 px
apart. An empty tile is a `paper2` card with a hairline and the workspace number in Pagella
`onum` at 66 px / `ink4` / 50 % opacity. Window thumbnails are paper cards with a 1 px `rule2`
edge and `shadeSm`, carrying the halftoned app icon at 36 % of the smaller side; hover turns the
frame oxblood and washes the card, and a drop-target tile lights the same way. Windows on another
monitor drop to 45 %. The focused workspace takes a 1 px `blue` frame held off the tile by a 2 px
paper gap — a printed keyline, not a glow — plus blue corner ticks, travelling in 160 ms.

### 4.7 Media controls — `media-controls.html`
460 px, top-left, 52 px down; the layer surface keeps its full height and only the card animates
between 172 and 388 px over 280 ms.

Player area: the **album plate** at 132 px — a 3 px paper mount, a 1 px `rule2` frame and a 1 px
hairline printed just inside the image — then a column with the cleaned title in Pagella 17 and a
28 × 24 lyrics toggle, the artist in agate with the album in italic, a spacer, `elapsed / total`
in oldstyle figures at the two ends of a row, the progress rule, and the transport row (42 px
`prev`, a full-width play/pause, 42 px `next`). Without art the plate holds a `note` glyph on
`paper2`; without a player the card is 110 px with *No active player* in Pagella italic.

Lyrics: a double rule at the fold, then Pagella lines 3 px apart — past `ink4`, upcoming `ink3`,
and the current line at 16 px `ink` with a 2 px oxblood **change bar** and 9 px of indent. Auto
scroll 420 ms, suspended 4 s after a manual scroll; clicking a line seeks. Placeholders are
Pagella italic.

### 4.8 Displays overlay — `monitors.html`
380 px, docked left, no shadow, 14 px padding, 10 px gaps. Three screens (main, profile editor,
settings), all sharing one masthead grammar: optional back `chevL`, the title in Pagella small
caps, the actions on the right, **Oxford rule**.

**Main** — a status row with the daemon as a blue stamp and `Active · <profile>` in agate with the
profile name in italic. Then, each announced by a small-caps section head:
* **Quick layout** — three 52 px buttons (glyph over a 9 px letterspaced label).
* **Other screens go** — four 50 px arrangement pickers, each a two-square diagram (12 × 8, the
  filled square is the primary, stacked for Above/Below) over an 8.5 px label.
* **Primary screen** — a wrapping chip row.
* **Zoom** — one row per output: the connector in mono `ink3` in a 52 px column, then five equal
  chips `1× 1.25× 1.5× 1.75× 2×`. Steps that would not divide the resolution into whole logical
  pixels are **dotted disabled chips**, not dimmed ones.
* A full-width 34 px `Auto (my profiles)` button.
* **Connected (n)** — one card per output: a 28 px slot (oxblood when enabled), `NAME · description`
  at 13/600 with the description muted, and `WIDTH×HEIGHT@Hz  x,y  N×` in mono agate; a `mirror`
  stamp when mirroring, or simply `Disabled`.
* **Profiles** — the section head carries a `+ New` cut-in; each row is a card with a 13 px
  medallion (filled oxblood when this is the profile HDM has active), the name at 13/600 with
  `· active` / `· disabled` as footnotes, the requirement summary in agate (`~` for regex, joined
  by `+`, conditions in brackets) and a `chevR`.
* A hairline and the status line: `Monitors.lastMessage` as a footnote, oxblood when the last
  operation failed, with `hdm-control` in mono at the right.

**Profile editor** — back bar with a solid `Save`; `Name` (read-only for existing profiles);
`Type` segment; a full-width capture/apply button; **Required monitors** with a `+` cut-in and one
card per entry (a 120 px Name/Desc segment, a `.*` regex toggle in mono, a `trash`, and the value
field below with an italic placeholder); a chip row of `+ NAME` shortcuts; **Conditions** as two
labelled segments; **Template values** as mono key/value field pairs with per-row `trash`; then
Disable, two reorder buttons (`arrowU` / `arrowD` — real arrows at last) and a `trash`, with the
tie-break rule as a footnote. Removal opens a full-cover confirmation: `Remove profile` in Pagella
small caps, a Pagella explanation, a checkbox line, then Cancel and a **solid oxblood** Remove.

**Settings** — Daemon (a `Running` stamp with pid/uptime as a footnote, then Validate / Reapply /
Reload); Profile scoring (a footnote paragraph, then four steppers and `Apply scoring`);
Notifications (an active toggle button with a `check`, a Timeout stepper, `Apply notifications`);
Info as a mono key/value block.

### 4.9 Session screen — `session-screen.html`
Warm scrim at 72 %, so the wallpaper survives as texture. Centred column, 22 px gaps:
`Session` in Pagella small caps 26 in paper white, letterspaced 0.18em, over a 200 px Oxford rule
in paper white; six 128 px paper tiles 18 px apart, each with its number accelerator in Pagella
oldstyle 12 at the top-left, a 38 px glyph and its name in Pagella small caps 14; the hint line in
Pagella italic at 72 % paper; and any warnings as paper-white stamps.
The selected tile **does not invert** — it takes an oxblood frame, oxblood corner ticks, an
oxblood glyph and an oxblood label, which is quieter and much easier to track while arrowing.
Actions and keys are unchanged: Lock 1, Log out 2, Suspend 3, Hibernate 4, Reboot 5, Shut down 6.

### 4.10 Worktrees dialog — `worktrees.html`
440 px floating sheet with corner ticks, 14 px padding, capped at 900.
`New worktree` in Pagella small caps with an `ESC` button, **Oxford rule**; the `Task name` kicker
and field, with the validation rule as a footnote (oxblood italic when it fails); a `Repos`
section head with `from main@origin` as a right-hand cut-in; one card per repo — a 19 px
checkbox, the name at 13, `N srv` in agate — where the **selected** repo is the only card with an
oxblood frame and opens a 3-column chip row of servers (or a footnote *no vitulina servers — gets
a shell tab*); a footnote naming repos that need `jj git init --colocate`; a double rule; the
`Summary` as a real table (9 px small-caps keys in a 74 px column, mono values); the actions —
one **solid** `CREATE` (italic *Working…* while busy, dotted-disabled until valid) and an 88 px
Cancel; a `Reopen` head with `N tasks` as a cut-in and a list of rows (name, repos in agate,
`N tabs` as a footnote); and the log in a **quiet paper well** (`PaperCard { quiet: true }`,
mono 10.5, max 120 px, auto-scrolled), whose frame and text turn oxblood on failure while the
sheet itself never changes colour.

---

## 5. Behavioural notes preserved

Everything in `design/current-pixels/SPEC.md` §5 holds unchanged: the `GlobalStates` flags, the
shared IPC targets and shortcut names, keeping quick-settings and displays windows alive and
toggling `visible`, hover popups as separate overlay windows, tooltips with an empty input
region, and the media surface keeping a fixed height while only the card animates.

Two additions this language depends on:

* **OpenType features must be enabled** on the display face (`Font.features` with `onum`, `tnum`,
  `smcp`). Without them Pagella falls back to lining figures and faux caps and the whole
  typographic argument weakens. A `PaperTitle` / `PaperFigure` wrapper should set them once.
* **Hairlines must not be snapped away.** Rules are 1 px logical; at fractional scale factors
  they should be drawn as `Rectangle { height: 1 / Screen.devicePixelRatio }`-style hairlines
  rather than rounded to 0.

## 6. What this variant deliberately does not do

* No gradients, no blur, no glow, no coloured shadows. The only shadow is a 5 %/9 % warm double
  drop on floating surfaces.
* No inversion as a state. A filled control is either the one committing action on the surface or
  a solid `ink` marker; states are washes, frames and change bars.
* No green, no amber, no traffic lights. Success is a blue stamp, warning is sepia, failure is
  oxblood.
* No opacity as a disabled treatment — a dotted rule instead.
* No decorative ornament. Every tick, double rule and seal is marking something: a floating
  sheet, the end of a block, a state you would stamp on paper.
