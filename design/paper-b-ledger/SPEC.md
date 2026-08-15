# Paper B — “Ledger”

A proposed replacement for the `pixel` panel family. Variant **B** of three: the
balanced middle — barer than C, more scaffolded than A.

Companion previews live next to this file (`tokens.html`, `widgets.html`, `bar.html`,
…). Every one is self-contained (inline CSS, inline SVG, no scripts, no network) and
renders in the real fonts, which are all installed on this machine.

Scope: this covers the **same surfaces, data and interactions** documented in
`design/current-pixels/SPEC.md`. Only the visual language changes. Behavioural
contracts — `GlobalStates` flags, IPC target names, focus-grab lifetimes, the fixed
media-controls surface height, click-through tooltip windows — carry over unchanged.

---

## 1. Design language in one paragraph

A shell that behaves like a **well-kept ledger** or a lab notebook. A warm paper ground
with a barely-there grain, ink text, and structure carried almost entirely by **1 px
hairlines** — card borders, row separators, section rules, dotted leaders. Data lines up
the way bookkeeping does: a letterspaced small-caps key on the left, a monospaced figure
with tabular numerals on the right, a dotted leader running between them. There are
exactly **two accent inks**: ink blue means *interactive / selected / on*, stamp red
means *warning, failure, or a record you cannot undo*. Hover is a wash of one step of
paper; selection is a **2 px blue mark** (an underline or a left rule), never an
inversion and never a heavy fill. No gradients, no blurs, at most one whisper of shadow
on surfaces that genuinely float over the desktop. Small, precise type: 13 px body,
10 px caps labels, 16 px line icons at a 1.25 stroke. The page is quiet; the marks are
exact.

### What distinguishes B from its siblings

* **A (barer)** would drop the card borders and rely on whitespace and rules alone.
* **C (richer)** would add tinted section bands, a third accent, heavier headers.
* **B keeps the scaffolding but keeps it thin**: every block *has* a border, but the
  border is a hairline; every section *has* a header, but the header is 10 px caps and a
  rule; every value *has* a home, but the home is a dotted leader rather than a table.

---

## 2. Design tokens

### 2.1 Colour — Paper (light, primary)

| Token | Hex | Used for |
|---|---|---|
| `--paper` | `#F6F2E9` | Desktop ground, bar body, sidebar panels, scrim base |
| `--paper-raise` | `#FBF8F1` | Every card, panel, popup, field, chip — the sheet on the desk |
| `--paper-sunk` | `#EFEADD` | Wells, hover wash, log boxes, weekend calendar columns |
| `--paper-edge` | `#E8E2D2` | Pressed state, table header bands, tile backing |
| `--ink` | `#22201C` | Primary text, values, active line icons |
| `--ink-2` | `#5A5449` | Secondary text, resting line icons, body copy |
| `--ink-3` | `#857D6E` | Micro-labels, captions, units, status lines |
| `--ink-4` | `#A9A08D` | Faintest: dotted leaders, disabled text, out-of-month days |
| `--rule` | `#DDD6C6` | **The hairline.** Card borders, row separators, dividers |
| `--rule-2` | `#C6BCA6` | Stronger hairline: panel outline, field border, table head rule |
| `--blue` | `#2C557E` | **Accent 1 — ink blue.** Interactive, selected, on, focused |
| `--blue-2` | `#4E7BA6` | Ink blue at reduced weight: sublabels on a blue wash |
| `--blue-wash` | `#E7ECF3` | Selected fill. The only tinted fill in the system |
| `--red` | `#A33726` | **Accent 2 — stamp red.** Warnings, failures, destructive |
| `--red-2` | `#C3604A` | Stamp red border weight, hover on destructive |
| `--red-wash` | `#F5E6E1` | Stamp field, failed log box, remove-confirmation panel |
| `--on-accent` | `#FBF8F1` | Text and icons on a filled blue or red ground |

### 2.2 Colour — Dusk Paper (dark)

Same structure, inverted ground. **Warm charcoal, never black; warm bone, never white** —
paper under a desk lamp. One logic inversion: `--paper-sunk` is *darker* than the card,
so a hover wash still reads as “pressed into the sheet”.

| Token | Hex | Token | Hex |
|---|---|---|---|
| `--paper` | `#16140F` | `--rule` | `#2F2B23` |
| `--paper-raise` | `#1D1A15` | `--rule-2` | `#463F34` |
| `--paper-sunk` | `#100F0B` | `--blue` | `#8FB3D9` |
| `--paper-edge` | `#25211A` | `--blue-2` | `#6E93BC` |
| `--ink` | `#EDE6D7` | `--blue-wash` | `#1B2530` |
| `--ink-2` | `#ADA593` | `--red` | `#D97B62` |
| `--ink-3` | `#867E6D` | `--red-2` | `#B85F47` |
| `--ink-4` | `#5E5749` | `--red-wash` | `#2C1B16` |
| | | `--on-accent` | `#15130F` |

Dark mode follows the shell-wide `Appearance.m3colors.darkmode` boolean, exactly as the
pixel family does. No wallpaper-derived colour ever enters the palette.

### 2.3 Translucency

Only four surfaces are translucent, and all four are `--paper`:

* session-screen scrim — `rgba(paper, .90)`
* worktrees scrim — `rgba(paper, .90)`
* overview scrim — `rgba(paper, .90)`
* nothing else. Panels are opaque.

The scrim is deliberately **light and high-opacity**: the desktop goes quiet under a
sheet of tracing paper, it does not go dark under a dimmer.

### 2.4 Texture

One inline fractal-noise tile (`feTurbulence`, `baseFrequency .85`, 3 octaves, 140 px,
`stitchTiles`) multiplied over every paper surface at **3 %** opacity in light mode and
**5.5 %** in dusk. It is below the threshold of notice at arm’s length — you feel it, you
do not see it. In QML this is one cached `ShaderEffectSource` tile shared by all surfaces.

The desktop wallpaper is out of scope for this variant (the pixelscape renderer can stay,
or be replaced by a plain `--paper` fill with the same grain; the previews use a neutral
warm band with faint 22 px ruling to stand in for it).

### 2.5 Type

Three faces, three jobs, no overlap. All three ship on Fedora and are installed here.

| Role | Face | Notes |
|---|---|---|
| Titles | **Bitstream Charter** | Matthew Carter’s screen-tuned transitional serif (`bitstream-charter-fonts`). Fine but robust serifs that survive at 15–16 px; it is what makes a panel feel like a bound book rather than a control panel. Weights 400 / 700. |
| UI text | **Adwaita Sans** | Fedora’s Inter-derived system sans. Neutral, tight, excellent at 10–13 px, and it takes `.13em` tracking in caps without falling apart. Weights 400 / 500 / 600 — never 700, so it stays light beside the serif. |
| Figures | **Source Code Pro** | Every number, identifier, path, timestamp, resolution and log line, always with `tabular-nums`, so columns align down the page. Weights 300 / 400 / 500. |

Fallback stacks: `Inter, Noto Sans, Cantarell, system-ui` · `Charter, STIX Two Text,
Noto Serif, Georgia` · `JetBrains Mono, Noto Sans Mono, ui-monospace`.

#### Type scale

| Token | px | Face / weight | Where |
|---|---|---|---|
| `--t-mega` | 52 | mono 300 | Pomodoro digits (the only display figure in the shell) |
| `--t-display` | 30 | serif 700 | `Session` heading |
| `--t-xl` | 20 | serif 700 | Overlay headings |
| `--t-lg` | 16 | serif 700 | Panel titles, media track title, popup headings, back bars |
| `--t-md` | 14 | sans 600 / mono 500 | Row titles, notification summaries; bar values, clock, battery |
| `--t-base` | 13 | sans 400 | Default body, list rows, search entries, paragraphs |
| `--t-sm` | 12 | sans 400/600 | Secondary lines, tile titles, statuses, buttons |
| `--t-cap` | 11 | mono 400 | Technical captions, key/value figures, relative times |
| `--t-micro` | 10 | sans 600, `.13em`, uppercase | Section headers, micro-labels, chips, verbs, accelerators |

Off-scale, deliberately: 9 px mono for workspace numbers, stat keys and tile
accelerators; 40 px mono for the pomodoro inside the 340 px sidebar; the overview
workspace watermark at `tileHeight × 0.4` in Charter.

Line-height is **1** for chrome rows and **1.45** for copy. Micro-labels are the only
tracked text in the system.

### 2.6 Spacing

2 px base, main step 4.

`2` hairline gaps · `4` icon-to-label, workspace cell gap · `6` chip gaps, card stacks ·
`8` row gaps, card padding · `10` section gap, notification stack · `12` panel padding,
bar divider margins · `14` dialog padding, media card padding · `16` card padding,
session tile gap · `20 / 24` unrelated blocks · `32` popup column gap.

Panels pad **12**; cards pad **8–10**; sections sit **10** apart with a hairline between
them; two unrelated blocks are **16–20** apart.

### 2.7 Rules, radii, elevation

| Token | Value | Where |
|---|---|---|
| `--hair` | 1 px `--rule` | Row separators, card borders, dividers, section rules |
| — | 1 px `--rule-2` | Panel outline, field border, table head rule, bar bottom |
| mark | 2 px `--blue` | **Selection.** Underline (tiles, tabs, calendar today, workspaces) or left rule (list rows, lyrics, critical toasts) |
| leader | 1 px dotted `--ink-4` | Key/value leader |
| dashed | 1 px dashed `--rule-2` / `--blue` | Empty slot / drag drop-target |
| `--r1` | 2 px | Cards, chips, buttons, fields, plates, tiles |
| `--r2` | 3 px | Floating panels and popups |
| — | 0 | The bar, full-height sidebars, all rules |
| `--shadow` | `0 1px 1px rgba(34,32,28,.045), 0 5px 14px -6px rgba(34,32,28,.10)` | **Only** on surfaces that float over the desktop: bar popups, toasts, OSD, media card, search sheet, worktrees dialog. Sidebars and inline cards get none. |

Depth is capped at two levels: **panel → card**. A panel never contains a panel.

### 2.8 Icons

**65 thin-stroke line icons**, inline SVG, drawn on a **16 × 16 grid** with a **1.25 unit
stroke**, `stroke-linecap: round`, `stroke-linejoin: round`, `fill: none` (except four
solid marks: `play`, `pause`, `prev`/`next` triangles, and the small dots inside `robot`,
`keyboard`, `wifi`, `lock`). All content stays inside a **1.6 unit margin** so nothing
touches the box.

Optical sizes: **12** (inline meta) · **14** (rows, buttons, bar controls) · **15–16**
(tiles, section headers, toggles) · **18–20** (search, OSD) · **28** (session tiles).

Colour is `currentColor`: `--ink-2` at rest, `--ink` when the row is active, `--blue`
when the control is on, `--red` for warnings, `--ink-4` when disabled.

The set, by group:

* **navigation** `chevL chevR chevU chevD arrowR plus minus check close search apps grip`
* **system** `wifi bluetooth battery bolt cpu ram proc robot cloud nodes swap refresh
  power lock logout moon snow sun flashoff gear sliders display server branch terminal
  keyboard coffee dropper crop fullscreen puzzle warn info`
* **content** `bell message note lines todo calendar clock timer heart sparkle pencil
  trash speaker speakeroff mic micoff play pause prev next`

This intentionally closes every gap the pixel set had: there is a real `lock`, `logout`,
`search`, `display`, `branch`, `arrowR` and `warn`, so **no glyph is ever substituted for
another**.

**App / tray / window icons** keep their own artwork but pass through
`grayscale(.55) contrast(.95)` and sit on a hairline plate, so a pasted-in logo reads like
a stamp on the page rather than a sticker. **Album art is the single exception** and
renders at full saturation — the ledger is allowed one colour plate.

### 2.9 Control sizes

| Control | Size |
|---|---|
| Button, default | 26 tall · 10 side padding |
| Button, compact / prominent | 22 · 30 |
| Icon button | 26 × 26 (22 × 22 inline, 20 × 20 in a list row) |
| Field | 28 tall · 8 side padding |
| Checkbox / marker | 14 × 14 |
| Chip | 20 tall · 7 side padding |
| Segment cell | 24 tall |
| Icon plate | 24 (tile) · 26 (monitor card) · 28 (notification) · 32 (empty state) |
| Toggle tile | fill × 42 |
| Quick-settings square button | 34 × 42 (row A/B), fill × 34 (row C) |
| Quick-layout mode button | fill × 50 |
| Arrangement picker | fill × 52 |
| Calendar mode button | 58 × 46 |
| Calendar day cell | fill × 23 |
| Bar control | 22 × 22 with a 15 px glyph |
| Workspace cell | 22 × 24, 4 gap, 14 px app plate |
| Session tile | 116 × 116, 16 gap |
| Notification toast | 344 wide |
| Media transport | 38 / grow / 38, all 28 tall |

### 2.10 Surface sizes

Bar full width × **34** · Quick settings **340** × screen height (right) · Displays
**360** × screen height (left) · Notification window **368**, toasts **344** · Media card
**440 × 164**, **440 × 370** with lyrics · Search field and sheet **560** wide, sheet
capped at **480** · Worktrees dialog **460** wide, capped at **880** · OSD **268** ·
Session tiles 6 × 116.

### 2.11 Motion

| Token | Value | Applies to |
|---|---|---|
| `--m-fast` | 90 ms | Hover wash on rows, buttons, chips |
| `--m-base` | 140 ms | Selection mark, toggle colour change, focus underline, workspace indicator slide |
| `--m-slow` | 260 ms | Overlay cross-fade, notification enter/leave, section expand |
| `--m-card` | 300 ms | Media card height (lyrics reveal) |
| `--m-scroll` | 420 ms | Lyrics auto-scroll to the active line |
| `--ease` | `cubic-bezier(.2,.7,.3,1)` | The only easing in the system |

Animated properties are restricted to **opacity, colour, and position under 4 px**.
Nothing scales, nothing bounces, nothing blurs. A selection mark growing from 0 to 2 px
in 140 ms is the largest movement in the shell.

---

## 3. Shared widget catalog

See `widgets.html` for every state rendered.

**`PaperPanel`** — the floating container. `--paper-raise`, 1 px `--rule-2`, radius 3,
`--shadow`. Used for bar popups, toasts, OSD, media card, search field + sheet, overview
panel, worktrees dialog, tooltips.

**`PaperCard`** — the inline container. `--paper-raise`, 1 px `--rule`, radius 2, no
shadow. `on` variant: `--blue` border over `--blue-wash`. Used for toggle tiles, monitor
cards, profile rows, repo rows, notification rows, session tiles, workspace tiles.

**`PaperWell`** — recessed. `--paper-sunk`, 1 px `--rule`, radius 2. Log boxes, empty
states, scroll bodies. Never shadowed.

**`PaperSectionHeader`** — the structural workhorse. A 10 px `.13em` uppercase label in
`--ink-3`, then a 1 px `--rule` running to the container’s right edge, with an optional
right-hand count/hint in 10 px mono *after* the rule. Every long panel is structured by
these and nothing else.

**`PaperKeyValue`** — the signature. `[caps key] ·············· [mono value]`, joined by
a 1 px dotted `--ink-4` leader on the baseline. Used in every popup, summary and info
block. It is why the shell reads as bookkeeping rather than as a dashboard.

**`PaperButton`** — 26 tall, 1 px `--rule`, radius 2, 12 px label at weight 500,
6 px icon-to-label gap. States: rest → `hov` (`--paper-sunk`) → `press` (`--paper-edge`);
`on` = blue border + blue ink + blue wash; `pri` = filled `--blue` with `--on-accent`
(**at most one per surface**); `dgr` = red ink at rest, red wash only on hover; `dis` =
`--ink-4`; `ghost` = transparent border until hovered. A stacked variant (icon over a
10 px caps label) is used for mode buttons: quick layout, arrangement, calendar modes,
session tiles.

**`PaperSegment`** — a hairline-divided row of equal cells inside one 1 px border. The
current cell takes blue ink, a blue wash and a **2 px blue underline**. Invalid cells
(e.g. a zoom step that would not divide the panel into whole logical pixels) drop to 35 %
and stop responding.

**`PaperChip`** — 20 tall, 10 px caps, for *picking from a set* (monitors, servers, zoom
steps, counts). `on` takes a blue tick plus the blue treatment.

**`PaperField`** — 28 tall, 1 px `--rule-2`, radius 2, 12 px text, `--ink-4` placeholder.
**Focus does not merely recolour the border — it adds a 2 px blue underline inside the
box**, like ruling a line under an entry. Invalid uses the same mark in stamp red with a
red hint line beneath.

**`PaperCheckbox`** — 14 × 14, 1 px `--rule-2`. On = solid `--blue` with an `--on-accent`
check. The only place a solid blue fill appears at small size: it is the ledger tick.
A square-cornered variant (radius 1) is the profile “active” marker.

**`PaperPlate`** — the bordered square that carries a line icon inside tiles and rows
(24/26/28/32). `on` = blue border, blue wash, blue glyph. `PaperAppPlate` is the same box
holding a desaturated third-party icon.

**`PaperListRow`** — 32–42 tall, 8 px side padding, hairline-separated **inside** a card
(never separated by gaps). Rest → hover wash → selected (wash + 2 px blue left rule +
blue ink). This one component covers Wi-Fi networks, Bluetooth devices, search results,
reopen tasks and monitor lists.

**`PaperMeter`** — a ruler. A 1 px `--rule-2` track, a 3 px fill, a 1 px pin at the exact
value, and a scale of 21 ticks below with every fifth drawn taller. **Ink** when
read-only (volume, brightness, CPU, RAM), **ink blue** when draggable (media seek,
pomodoro). Replaces the pixel theme’s 20 discrete cells everywhere.

**`PaperStepper`** — `[−][value][+]` sharing hairlines so it reads as one ruled object,
with a label and help line to its left.

**`PaperTooltip`** — its own click-through window with an empty input region (so it can
never steal hover), 1 px `--rule-2`, radius 2, 4/8 padding, 11 px `--ink-2`, 14 px from
the anchor edge, 350 ms show delay, 120 ms hide debounce.

**`PaperStamp`** — 9 px caps in `--red` on `--red-wash` inside a 1 px `--red-2` border,
rotated **−1.1°**. The only rotated element in the system and the only place stamp red
carries a fill. Session warnings and hard failures only. Never clickable.

**`PaperText` / `PaperTitle` / `PaperMono`** — the three faces of §2.5.

**`PaperIcon`** — §2.8.

**`PaperBatteryGlyph`** — one 17 px icon: a rounded 11 × 6 body with a 1.25 stroke, a
2-unit cap, and an inner solid bar drawn to the charge. Charging swaps the bar for a
bolt. Below 10 % the glyph *and* its percentage turn stamp red.

---

## 4. Surface inventory

### 4.1 Bar — `bar.html`

One `PanelWindow` per screen, top/left/right, **34 px** tall with a matching exclusive
zone. Opaque `--paper`; the only chrome is a **1 px `--rule-2` bottom hairline**. Content
inset 14 px each side. Clusters are separated by a 1 × 16 px vertical hairline with 12 px
margins. Scrolling the left half changes brightness ±0.05 and raises the brightness OSD;
the right half does the same for volume.

**Left** — tray: one 20 × 20 hit area per pinned item holding a 15 px app plate, 6 px
apart; left click activates, right click opens the item menu, hover shows its tooltip.
Hairline. **Stats**, as caps-key/mono-figure pairs 14 px apart: `RAM 38%`, `CPU 17%`,
`CLAUDE 61%` (the last only when `ClaudeUsage.available`) — a 9 px `.13em` key in
`--ink-3`, 5 px gap, a 12 px mono figure in `--ink`. **There are no icons in the bar
stats: the label is the icon**, which is what makes the strip read as a column of
accounts. Hovering the group opens the system-monitor popup. Hairline. **Now playing**: a
13 px `note` glyph and the current MPRIS title in 12 px `--ink-2`, elided at 190 px, or
“No media”; click opens the media controls.

**Centre** — ten **22 × 24** workspace cells, 4 px apart, all sitting on one **ruled
baseline**. Empty = 1 px `--rule` baseline and a faint 9 px mono number. Occupied = a
`--rule-2` baseline and the 14 px app plate of the biggest window. **Focused = the
baseline thickens to 2 px ink blue** and the cell takes a blue wash; the mark slides
between cells in 140 ms. Nothing inverts, nothing fills. Click switches; scrolling the
row cycles workspaces.

**Right** — clock: `21:48` in 13 px mono with tabular figures (so the strip never
reflows) followed by `Tue 12 Aug` at 11 px `--ink-3`; hover opens the clock popup.
Hairline. Controls, 8 px apart: 15 px `crop` (region screenshot), 15 px `moon`/`sun`
(dark-mode toggle), then the battery pair — `PaperBatteryGlyph` plus a 12 px mono
percent, hover opens the battery popup, click opens quick settings.

#### Bar hover popups

Each is its own overlay window hanging `barHeight + 6` = **40 px** from the top, centred
under its target (left-aligned for the stats popup), drawn as a `PaperPanel` with 12–13 px
padding. Alive only while the target is hovered.

* **Clock** (296 wide) — a 15 px `calendar` glyph and the full date in Charter 15;
  key/value leaders for `UPTIME` and `WEEK`; a hairline; a `TO DO` section header with
  the pending count after the rule; then up to five items, each a 10 px mono index and
  the task in 12 px `--ink-2`, or “No pending tasks”.
* **Battery** (252 wide) — the battery glyph, `Battery` in Charter 15, the percent in
  14 px mono on the right, a ruler meter, a hairline, then leaders for `STATE`, `DRAW`,
  `TO EMPTY`, `HEALTH`.
* **System monitor** (600 wide) — three columns divided by hairlines, each headed by a
  15 px line icon and a 10 px caps label over a `--rule-2` hairline. **Memory** is a
  right-aligned figure table (Used / Free, then Total ruled off above by a hairline —
  exactly how a column of sums is closed in a ledger). **Processor** is `LOAD` with a
  ruler meter, then `PROCS` and `SWAP` leaders. **Claude** is four leaders: session,
  week, opus, updated (with “(stale)” appended on error).

### 4.2 Quick settings — `quick-settings.html`

`PanelWindow` top+right+bottom, full screen height, **340 px** wide, gated by
`sidebarRightOpen`, closed by click-out or Escape. Not a floating panel: a **page pinned
to the right edge** — `--paper` ground, one 1 px `--rule-2` hairline down its left side,
12 px padding, 10 px section gaps. Only the notification list flex-grows, so the calendar
always sits at the bottom of the screen where the hand expects it.

1. **Header** — an uptime card (26 tall, `clock` glyph, `UP` caps key, mono value) and
   four 26 px ghost icon buttons: `pencil` Edit, `refresh` Refresh, `gear` Settings,
   `power` Power. Hairline.
2. **Connectivity** section header. Row A: **Internet** tile, **Bluetooth** tile, a
   34 × 42 `coffee` keep-awake button. Row B: a 34 × 42 `mic` button, **Output** tile,
   **Night light** tile. Row C: five equal 34 px buttons — `cloud` WARP, `fullscreen`
   Game mode, `sliders` Easy Effects, `flashoff` Anti-flashbang, `dropper` Colour picker.
   Toggle tile = 42 tall, a 24 px icon plate, a 12 px title over an 11 px status line.
   **The status line always carries the real value** — the SSID, the sink name and volume
   — never the word “On”; colour already says on.
3. **Notifications** section header with the count after the rule. One card per app
   group, 8 px apart. Collapsed: a 26 px app plate, a header row of app name / mono
   relative time / count chip, then the latest summary (12 px 600) and body (11 px
   `--ink-2`), each single-line elided. Expanded: the chevron flips and the card rules out
   one hairline-separated entry per notification, each with a 20 px discard button.
   Footer: a 32 px `bell` mark-all-read, a non-interactive count button, a 32 px red-ink
   `trash` clear-all. Hairline.
4. **Calendar area** — a left stack of three 58 × 46 mode buttons (`calendar` CAL,
   `todo` TODO, `timer` TIME; the active one takes the standard blue treatment) switching
   the pane on the right:
   * **Calendar** — Charter 15 month title with two 22 px ghost nav buttons; a 7-column
     grid with a 9 px caps weekday header over a `--rule-2` hairline, 23 px day cells in
     mono, weekend columns tinted `--paper-sunk`, out-of-month days at `--ink-4`.
     **Today is not a filled block** — it is a blue wash with a 2 px blue underline, the
     same selection mark used everywhere else.
   * **To do** — a `TASKS` header with the open count, then rows of a 14 px checkbox, the
     task at 12 px (struck through and `--ink-4` when done) and a 20 px trash, separated
     by hairlines; a 24 px “Add task…” field and a 24 px `plus` button at the bottom.
   * **Timer** — the phase in 10 px blue caps beside `cycle 3 of 4` in mono; the
     remaining time in **40 px mono 300** with tabular figures; a blue ruler meter for the
     phase; then `Pause` (on) and `Reset`.

**Management overlays** — tapping Internet or Bluetooth *replaces the panel body* rather
than floating a dialog: same paper, same padding, a back chevron and a Charter 16 title
where the header was, a radio `On` toggle and a `refresh` rescan, then one card of
hairline-ruled rows. Each row: a 15 px `wifi`/`bluetooth` glyph, the name at 12 px 600
over an 11 px status, a `lock` glyph for secured networks and the signal percent in mono.
**The connected entry carries the ordinary selected mark**, so “connected” looks identical
to “selected” anywhere else in the shell. Empty states: “Scanning…” / “Wi-Fi off” /
“Discovering…” / “Bluetooth off”.

### 4.3 Notification popups — `notifications.html`

Overlay window on the focused screen, top+right+bottom, **368 px** wide, click-through
except over the toasts. The stack starts at `barHeight + 12` = 46 px from the top, 12 px
from the right, items **344 px** wide and **10 px** apart.

Each toast is a `PaperPanel` with 11 px padding: a 28 px plate (app icon, or a line glyph
for shell-owned notifications), then a header row of app name (12 px 600, elided) and a
10 px mono relative time, the summary at 13 px 600 single-line, the body at 12 px
`--ink-2` clamped to two lines, and one equal-width 26 px button per **labelled** action,
8 px apart. The unlabelled default action is never drawn.

**Critical notifications** differ by exactly one thing: a **2 px stamp-red rule down the
left edge** and a `warn` glyph on the plate. No red fill, no flashing, no larger type —
urgency is a margin mark, the way an accountant flags a line.

Hovering pauses the auto-dismiss; clicking the toast runs the default action and dismisses
it; clicking an action runs it and dismisses. Enter and leave are a fade plus a 4 px
slide.

### 4.4 On-screen display — `osd.html`

One **268 px** panel on the focused screen, horizontally centred, `barHeight + 14` = 48 px
below the top (or above the bottom when the bar is bottom-anchored). Raised by any volume
or brightness change for `osd.timeout` (1000 ms); hovering dismisses it. Region-masked.

12 px padding, 12 px gap: a 20 px glyph (`speaker` / `speakeroff` / `sun`), then a column
of a label row (12 px 600 left, the value in 12 px mono right) over the **ruler meter**.
When muted, the glyph, label and figure all drop to `--ink-4` and the fill is omitted —
the ruler is empty rather than zeroed.

### 4.5 Overview / launcher — `overview.html`

Full-screen overlay per screen with a focus grab; Escape or a scrim click closes it,
←/→ switch workspaces while the query is empty. Scrim = paper at 90 %. A centred column
starts at 12 % of screen height with 18 px between the two widgets.

**Search** — a **560 × 46** panel: an 18 px `search` glyph, the query at 15 px, and a
right-hand hint (`⏎` chip when empty, `N results` in mono while typing). The results sheet
hangs directly beneath: **the field and the sheet are one object** — the field loses its
bottom corners, the sheet loses its top border, and a single hairline runs across the
seam. Rows are 42 px, hairline-separated, capped at 480 px total. Each row: an icon
(22 px app plate, or a 16 px line glyph for non-app entries), the entry type in 10 px caps
(hidden for apps) over the entry at 13 px, and — **only on the current row** — the verb
(Open / Run / Copy / Search) in 10 px blue caps on the right. The current row takes the
standard selected mark. Focus adds a blue search glyph and a blue underline. Typing
anywhere routes into the field; Ctrl+J/K move; Enter runs. Data comes from the same
`LauncherSearch` singleton, so app / run / math / clipboard / emoji / web / action
prefixes behave identically.

**Workspace exposé** — hidden while a query is typed. A `PaperPanel` with 12 px padding
around a `rows × columns` grid (default 2 × 5) of `monitorSize × overview.scale` tiles
(346 × 186 at 0.18 on 1920 × 1080), 6 px apart. Each tile is a hairline card whose
workspace number is set in **Charter at 40 % of the tile height in `--ink-4` at half
opacity** — a watermark on the page, not a label. Live `ScreencopyView` thumbnails sit at
their real scaled positions inside a 1 px `--rule-2` frame with a centred app plate and
the window title beneath in 9 px, so a workspace of unrendered thumbnails still reads as a
list of what is open. Hover = `--paper-sunk` wash + blue hairline, with a tooltip of
`title` over `[class]`. Windows on another monitor render at 42 % opacity. The drag
drop-target tile takes a **dashed blue border over a blue wash**. The focused workspace
takes a blue hairline, a 2 px blue underline and a blue number; the mark animates between
cells in 140 ms. Left click focuses and closes, middle click closes the window, dragging
moves it (`movetoworkspacesilent`) or repositions a floating one (`movewindowpixel`).

### 4.6 Media controls — `media-controls.html`

`PanelWindow` anchored **top-left**, `barHeight + 6` = 40 px down, flush with the left
edge, **440 px** wide. Flush means its left border is dropped and only the right corners
are rounded — a sheet slid halfway out of the drawer. The layer surface keeps a fixed
height and only the inner card animates between **164** and **370 px** over 300 ms,
clipping the lyrics in and out. Masked to the card. With no player: a 32 px `note` plate,
“No active player” in Charter 15, and an 11 px explanation.

**Player** (164 px, 14/16 padding, 14 px gap): a **132 px album cover** behind a 1 px
`--rule-2`, radius 2 — **the one place full colour is allowed in the entire shell**, and
the border keeps it reading as a plate pasted onto the page. The info column holds the
cleaned title in Charter 16, the artist at 12 px `--ink-2`, the album and year in 10 px
caps, and a 26 × 24 lyrics toggle on the right; then, pushed to the bottom, `elapsed` /
`total` in 10 px mono at the two ends, the **blue ruler meter** (click or drag to seek,
ticked once a second while playing), and the transport row: `prev` 38, play/pause
fill, `next` 38, all 28 tall. Play/pause is the wide centre button, not a circle — the row
is a ruled cell of three like every other button group.

**Lyrics** — a hairline, then 12/16 padding under a `LYRICS · synced` section header.
The current line is **Charter 15 bold in `--ink` with a 2 px ink-blue rule in the left
margin** — the same selection mark as list rows, so “where we are” is always the same
gesture. Past lines fall to `--ink-4`, upcoming lines sit at `--ink-3`, 5 px apart;
clicking a line seeks to it. The view scrolls to keep the active line centred over 420 ms,
suspended for 4 s after a manual scroll. Placeholders (“Searching for lyrics…”, “No
lyrics”, “Couldn’t load lyrics”, “Instrumental”) render as one 12 px `--ink-3` line, never
as centred hero text.

### 4.7 Displays overlay — `monitors.html`

`PanelWindow` top+left+bottom, full screen height, **360 px** wide, `keyboardFocus:
OnDemand`, gated by `monitorsOpen`, keybind/IPC only. A GUI over **hyprdynamicmonitors**;
every write goes through the `Monitors` service → `hdm-control.py`. 12 px padding, 10 px
gaps. Three screens — main, profile editor, settings — the latter two replacing the body
in place.

**Main**
1. Header: `Displays` in Charter 16 over the micro-label `hyprdynamicmonitors`; a
   `refresh` and a `gear` ghost button.
2. Status row: a 6 px dot (blue when the daemon is up), “Daemon running” at 11 px
   `--ink-3`, and `active: <profile>` / `quick: <mode>` / `no profile` in 10 px mono on
   the right, elided at 180 px. Hairline.
3. **QUICK LAYOUT** — three equal 50 px stacked buttons: `nodes` Extend, `swap` Mirror,
   `fullscreen` Single. With Single active, a wrapping chip row picks which output stays
   on. With Extend and more than one screen, **OTHER SCREENS GO** offers four 52 px
   arrangement pickers, each a **two-rectangle diagram** in which the filled rectangle is
   the primary screen and the hairline one is where the others go, over a 9 px caps label.
   Extend and Mirror also expose **PRIMARY SCREEN** as a chip row. Any quick layout
   exposes **ZOOM**: one row per output, the connector in 10 px mono in a 58 px column and
   a five-cell segment 1 / 1.25 / 1.5 / 1.75 / 2×; steps that would not divide the panel
   into whole logical pixels drop to 35 % and stop responding. Finally a full-width 30 px
   **Auto (my profiles)** button that clears the quick override.
4. **CONNECTED (n)** — one card per output: a 26 px `display` plate (blue when enabled),
   `NAME · description` at 12 px, and `WIDTH×HEIGHT@Hz  +x,y  Nx` on one 10 px mono line
   (or `mirror → NAME`) so two outputs can be compared by eye down the column. A disabled
   output drops the whole card to 60 % and says “Disabled” in words.
5. **PROFILES** with a `+ New` button after the rule. One row per profile: a 14 px square
   marker (ticked = the profile HDM currently has active), the name at 12 px with an
   `active` / `disabled` micro-suffix, and a 10 px mono summary written in the same syntax
   as the config file (`~` = regex, `+` = and, `[…]` = conditions), plus a `chevR`.
   Disabled profiles render at 50 %. Empty: “No profiles yet — press + New or pick a quick
   layout”.
6. Status line at the bottom: a `check` glyph and `Monitors.lastMessage` in 10 px mono
   (stamp red on failure).

**Profile editor** — a back bar (`chevL`, the profile name in Charter 16, a filled
**Save**); **NAME** (a sunken read-only field for existing profiles, with a hint);
**TYPE** segment Template/Static; a full-width 30 px capture/apply button; **REQUIRED
MONITORS** with a `+` after the rule and, per entry, a card holding a Name/Desc segment, a
`.*` regex toggle, a red-ink trash, and the value field below; then a wrapping row of
`+ NAME` chips for connected monitors. **CONDITIONS** — Power (Any/AC/Battery) and Lid
(Any/Open/Closed) segments with a 38 px caps label column. **TEMPLATE VALUES** —
key/value mono field pairs with a per-row trash. Finally a hairline and a row of
`Disable`, two reorder icon buttons (`chevU`/`chevD`, with tooltips), and a red-ink
`Remove`, under a hint explaining tie-breaking.

Removing opens a confirmation on a **red-wash panel inside a red hairline**: a `warn`
glyph and “Remove profile ‘x’” in Charter 15 red, an explanatory line, a blue checkbox
“also delete its template file” (it is a setting, not the danger), then `Cancel` and a
filled stamp-red `Remove`. This is the only red field in the shell.

**Settings** — back bar + `Settings`; **DAEMON** with a status dot, a mono pid, and three
equal buttons Validate / Reapply / Reload; **PROFILE SCORING** with an 11 px explanation
and four steppers (Name / Description / Power state / Lid state match) plus `Apply
scoring`; **NOTIFICATIONS** with a checkbox “Notify on profile switch”, a Timeout (ms)
stepper (step 1000, max 60000) and `Apply notifications`; **INFO** as read-only key/value
leaders for the destination path, the debounce and the config path.

### 4.8 Session screen — `session-screen.html`

Full-screen, keyboard-exclusive overlay on the focused screen, gated by `sessionOpen`.
Scrim = paper at 90 %; clicking it cancels. Centred column, 22 px gaps:

1. `Session` in Charter 30, with a mono sub-line beneath:
   `heron · 12 Aug 2027 · 21:48 · up 6d 04:12`.
2. A 748 px `--rule-2` hairline.
3. Six **116 × 116** tiles, 16 px apart: **Lock** (`lock`, 1), **Log out** (`logout`, 2),
   **Suspend** (`moon`, 3), **Hibernate** (`snow`, 4), **Restart** (`refresh`, 5),
   **Shut down** (`power`, 6). Each is a hairline card with the number accelerator boxed
   in a 15 px hairline square in the top-left corner — a line number in the margin — a
   28 px line icon, and a 10 px caps label. The selection is the ordinary mark: blue
   hairline, blue wash, blue ink, 2 px blue underline, sliding between tiles in 140 ms.
   **Every action is named by its own glyph**; nothing is substituted.
4. A hint line at 11 px `--ink-3`.
5. Session warnings as **stamps**, each rotated barely more than a degree so the row reads
   as marks pressed onto the page: “package manager running”, “download in progress”.

Keys: ←/→/↑/↓/Tab move, Home/End jump, Enter/Space run, 1–6 select and run immediately,
Escape cancels. Hover also moves the selection.

### 4.9 Worktrees dialog — `worktrees.html`

A centred modal on the focused screen, keyboard-exclusive so the name field is typeable
immediately, over the same 90 % paper scrim. Escape or a scrim click closes it;
keybind/IPC only. `PaperPanel`, **460 px** wide, 14 px padding, 10 px gaps, capped at
880 px. This is the surface where the ledger metaphor is most literal: everything above
the Create button is the entry being written, everything below it is the record of what
has already been written.

1. `New worktree` in Charter 17 with an `ESC` caps button; `--rule-2` hairline.
2. **TASK NAME** header + field (focused, blue underline). Invalid names take the red
   underline and a red hint “letters, digits, . _ - only”.
3. **REPOS** header with the base branch after the rule (`from main@origin`). One row per
   discovered repo: a 14 px checkbox, the name at 12 px, and `N srv` in mono. Ticking a
   repo turns the whole row into the selected state (blue hairline over blue wash) and
   unfolds a **three-column grid of server chips**; a repo with no servers says
   “no vitulina servers — gets a shell tab” instead of showing an empty grid. Below, a
   hint naming repos that need `jj git init --colocate`. Empty: “No git repos found in
   ~/pleevi”.
4. Hairline. **SUMMARY** as key/value leaders: `PATH`, `BOOKMARK`, `ENV`, `SETUP`, `TABS`
   (total plus the breakdown). The dotted leader is doing real work here — it lets the eye
   run from a short key to a long path without a table border.
5. **Actions**: a full-width 30 px filled **Create** (reads “Working…” while busy, drops
   to `dis` until the name is valid and at least one repo is ticked) and a 90 px `Cancel`.
6. Hairline. **REOPEN** header with the task count after the rule, then a card of
   hairline-ruled 32 px rows — a `branch` glyph, the task name, the repos joined by
   commas, and `N tabs` in mono — capped at 150 px. Empty: “No task folders in ~/pleevi
   yet”.
7. **Log box** — a well, 10 px mono, auto-scrolled, capped at ~104 px. On failure the
   border and the text both move to stamp red. No icon, no banner.

---

## 5. Behavioural contracts preserved

* `GlobalStates` flags: `barOpen`, `screenLocked`, `sidebarRightOpen`, `overviewOpen`,
  `sessionOpen`, `mediaControlsOpen`, `monitorsOpen`, `worktreesOpen`, `osdVolumeOpen`,
  `osdBrightnessOpen`.
* IPC targets / shortcut names shared with the `ii` family: `sidebarRight`, `search`,
  `session`, `mediaControls`, `monitors`, `worktrees`, plus the two OSD targets.
* Panels that must survive a focus grab (quick settings, displays) keep their
  `PanelWindow` alive and toggle `visible`.
* Hover popups are separate overlay windows; tooltips use an empty input region so they
  never steal hover.
* The media-controls surface height is fixed; only the inner card animates.
* Notification, OSD, overview and session windows stay region-masked / click-through
  outside their content.

## 6. Notes for implementation

* The grain, the dotted leader and the ruler meter are the three components worth building
  once and reusing everywhere; they carry most of the theme’s character.
* `tabular-nums` must be enabled on every mono run (`font.features: { "tnum": 1 }` in
  QML), or the bar clock and the stat column will jitter.
* Charter has no italic in the Fedora package; the design never asks for one.
* The 1 px hairline must be a *device* pixel. On fractional-scale outputs, snap rule
  rectangles to the device grid or they will render as a soft 2 px smear and the whole
  theme loses its edge.
* Hairlines in dusk are `#2F2B23` on `#16140F` — a 4 % luminance step. Do not “fix” this
  by brightening; the theme depends on the rule being felt rather than seen.
