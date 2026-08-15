# Paper A — “Hairline”

Design specification for variant **A** of the `paper` theme family, the proposed
replacement for the `pixel` panel family documented in
`design/current-pixels/SPEC.md`.

Hairline is the **most minimal** of the three paper variants. It covers the same
surfaces, the same data and the same interactions as the pixel theme; only the
visual language changes. Companion HTML previews live next to this file
(`tokens.html`, `widgets.html`, `bar.html`, …) and recreate every surface at real
proportions with realistic data.

Every number in this document is a design decision, not a description of existing
code — nothing is implemented yet.

---

## 1. Design language in one paragraph

Fine print on paper. A warm off-white ground, near-black warm ink, and generous
whitespace where the pixel theme had borders. **The hairline — one 1 px rule — is
the only structural device in the system.** There are no filled panels, no boxes,
no cards, no shadows, no gradients, no texture and no border radius; a surface is
an opaque sheet of paper with a single 1 px rule around it, and everything inside
it is separated by whitespace or by another 1 px rule. Icons are thin-stroke line
drawings on a 16-unit grid whose apparent stroke never changes from 1.25 px at any
optical size. The pixel theme’s single interaction rule — *a filled square means
on* — is replaced by three, in this order of loudness: **ink weight**
(`ink-3` → `ink`), **a 1 px underline**, and **a 6 px dot**. Nothing else is
permitted to say “on”, which is enforced by one hard constraint: **ink is never
used as a background larger than 6 px**, with a single documented exception (the
battery level fill, which encodes a quantity rather than a state). One muted hue,
a seal red, exists for critical states only and appears perhaps twice in a normal
day of use. Album art remains the sole place third-party colour reaches the screen.

---

## 2. Design tokens

### 2.1 Colours

Two palettes, twelve tokens each, identical names. Nothing in the system encodes
“light” or “dark” beyond these values; the same markup renders in either. Light
(“Paper”) is the **primary** palette — this is the first theme in the shell that
is designed light-first — and “Dusk Paper” is the companion, since
`Appearance.m3colors.darkmode` still drives the switch.

| Token | Paper (light) | Dusk Paper (dark) | Used for |
|---|---|---|---|
| `paper` | `#FAF8F3` | `#1B1917` | The single opaque ground: bar, every popup, every panel, every overlay backdrop |
| `paper-sunk` | `#F4F1E9` | `#232019` | Recessed ground. Exactly three uses: album-art well, worktrees log box, search-result scroll region |
| `wash` | `#EFEBE1` | `#262320` | Hover on list rows only (≈ ink at 4 %) |
| `wash-2` | `#E7E2D6` | `#302C27` | Press and text selection (≈ ink at 9 %) |
| `ink` | `#1C1A17` | `#EDE7DA` | Primary text, active icons, active rules |
| `ink-2` | `#56514A` | `#A9A192` | Secondary text, resting icons, notification bodies |
| `ink-3` | `#8A8379` | `#756E63` | Meta, statuses, section labels, placeholders |
| `ink-4` | `#B7B0A3` | `#4E483F` | Disabled, out-of-month days, empty workspaces, past lyrics |
| `rule` | `#DCD6C9` | `#35302A` | The hairline. Panel borders, list separators, section dividers |
| `rule-2` | `#C3BCAC` | `#4A443B` | A hairline the user must be able to aim at: field underlines, switch rail, hover underline, thumbnail frames |
| `alert` | `#8E3B2F` | `#CE8272` | Seal red. Critical only — see §2.2 |
| `alert-soft` | `#C89A90` | `#6E4137` | Alert at rest (non-urgent warning) |

Dusk Paper is **not an inversion**. The ground warms rather than blackens and the
ink goes to bone, so the paper metaphor survives; the hairline gets *lighter* than
the ground rather than darker; and the accent lifts in value, because seal red
goes muddy on a dark ground.

Translucency exists in exactly three places, all of `paper`:

| Token | Light | Dark | Where |
|---|---|---|---|
| `scrim` | `rgba(250,248,243,.62)` | `rgba(27,25,23,.66)` | Overview. The desktop is **bleached**, not darkened |
| `scrim-2` | `rgba(250,248,243,.92)` | `rgba(27,25,23,.92)` | Session screen, worktrees dialog |
| `wash` / `wash-2` | see above | see above | The only two background changes any control makes |

**Contrast.** On `paper`: `ink` ≈ 16:1, `ink-2` ≈ 7.5:1, `ink-3` ≈ 3.5:1 (meta and
statuses only, never body), `ink-4` ≈ 2:1 (disabled and decorative only). On
`paper` in Dusk: `ink` ≈ 14:1, `ink-2` ≈ 7:1, `ink-3` ≈ 3.2:1.

### 2.2 Accent policy

There is one hue in the system and it is spent on almost nothing. `alert` is
permitted on, and only on:

* battery ≤ 15 % (glyph and percent, in the bar and in the battery popup);
* a failed daemon or script operation (`Monitors.lastMessage`, the worktrees log);
* an urgent notification’s 6 px dot;
* the two session-screen warnings;
* a field that failed validation (its underline plus the message beneath it);
* the confirming verb of a destructive confirmation.

It is **never** used for “on”, “active”, “selected”, “connected”, “focused”,
“playing”, “primary” or “recording”. Those are ink weight, underlines and dots.

### 2.3 Fonts

Two families. No display face at all.

* **Body / UI — `PaperText`: Inter.** Packaged everywhere on Linux
  (`google-inter-fonts` on Fedora, `ttf-inter` on Arch, `fonts-inter` on Debian).
  Chosen over IBM Plex Sans because Inter’s x-height and hinting survive 10–11 px
  on Wayland, which the theme leans on heavily; chosen over a text serif because
  Hairline is the *minimal* variant and a serif is character the other two
  variants can spend. Weights used: 300, 400, 500. `Text.NativeRendering`,
  `hintingPreference: Font.PreferFullHinting`.
* **Numerals / identifiers — `PaperMono`: JetBrains Mono.** Already installed on
  this machine. Used for anything the eye has to compare or a machine produced:
  clocks, percentages, resolutions, coordinates, durations, paths, bookmarks,
  branch names, log output, workspace numbers, keyboard accelerators, the pomodoro
  digits. Weights used: 200, 400. Tabular figures are the default, which is the
  point.
* **Titles.** There is no title face. A title is body type in **micro-caps**
  (10 px / 500 / `+0.16em` / uppercase). This is deliberate: it is the cheapest
  possible way to signal hierarchy and it removes an entire font from the shell.

Neither font needs to be bundled; both are packaged. If Inter is missing, the
fallback chain is `Adwaita Sans` (an Inter derivative shipped with GNOME) →
`Noto Sans` → `system-ui`.

### 2.4 Type scale

| Token | px / weight / tracking | Colour | Where |
|---|---|---|---|
| `micro` | 10 / 500 / +.16em / UPPER | `ink-3` | Section labels, tab labels, verbs, caps buttons, accelerators, thumbnail captions, app names in notifications |
| `meta` | 11 / 400 | `ink-3` | Times, statuses, hints, help lines, secondary mono values, log output |
| `small` | 12 / 400 | `ink-2` | Notification bodies, list subtext, help paragraphs, summary values |
| `body` | 13 / 400 | `ink` | Default. Row titles, labels, calendar days, search results, lyrics (past/upcoming) |
| `lead` | 15 / 400 | `ink` | Bar clock, popup titles, month name, media title, current lyric |
| `title` | 18 / 400 | `ink` | Battery percent in its popup, big single values |
| `display` | 24 / 300 / +.18em / UPPER | `ink` | One use: the `SESSION` heading |
| `numeral` | 40 / 200 mono | `ink` | One use: the pomodoro clock |

Two off-scale sizes exist: **16 px** for the search query (it is the only text the
user types full-screen) and **9–9.5 px** micro-caps inside the quick-settings
extras row and the arrange picker, where five or four columns share 332 px.

**Optical weight rule: as size goes up, weight comes down.** ≤11 px → 500,
12–18 px → 400, 24 px → 300, 40 px → 200. Bold is not in the system; emphasis is
carried by ink weight and case.

### 2.5 Rules, radii, motion

| Token | Value | Where |
|---|---|---|
| `rule.hair` | 1 px, `rule` | Default. Panel border, list separators, section dividers, calendar header rule |
| `rule.hair-half` | 0.5 px (1 physical px @ 2×; 1 px @ 55 % opacity on 1×), `rule` | Dense lists |
| `rule.hair-find` | 1 px, `rule-2` | A hairline the user aims at: field underlines, switch rail, hover underline, window-thumbnail frames |
| `rule.hair-ink` | 1 px, `ink` | The selected / active / focused marker. Nothing else in the system is ink-weight |
| `rule.hair-alert` | 1 px, `alert` | Failed field validation. The only coloured rule |
| radius | **0** everywhere | The only curves in the system are icon strokes and the 6 px state dots |
| shadow / gradient / blur | none | Not used anywhere |
| `barHeight` | **38 px** | Bar height + exclusive zone (was 46) |
| `t-fast` | 90 ms | Ink colour change on hover, icon colour, meter head |
| `t-base` | 140 ms | Underline draw (`scaleX` from the left), switch knob travel, tab change, focused-workspace rule |
| `t-slow` | 240 ms | Section reveal, manager overlay, notification enter/exit |
| `t-card` | 280 ms | Media card height 168 ↔ 392 |
| `ease` | `cubic-bezier(.2,0,0,1)` | Everything entering or changing state |
| `ease-exit` | `cubic-bezier(.4,0,1,1)` | Everything leaving |
| `max-travel` | **4 px** | Hard ceiling. Nothing slides further than 4 px, ever |

Off-token: lyrics auto-scroll 400 ms `ease` (suspended 4 s after a manual scroll).
The underline is the only animated *shape* in the system — it grows from its left
edge — which is why “selected” never needs a fill to be noticed.

There is no 2 px rule and no 3 px rule. The pixel family’s `borderWidth` /
`popupBorderWidth` / `barBorderWidth` triple collapses to one value.

### 2.6 Spacing scale — base 4

`2` hair gaps · `4` icon↔label · `6` underline offset · `8` row gaps, exposé tile
gaps · `12` list gaps, notification gutter · `16` block gaps, icon↔label in rows ·
`20` bar side padding, toast padding, popup padding · `24` panel padding, section
gaps, chip gaps · `32` surface top offsets · `40` session column width unit,
sysmon column gap · `56` reserved.

Whitespace is the substitute for the borders that were removed: the pixel bar
padded 12 px and Hairline pads 20; pixel panels padded 12 and Hairline pads 20–24.

### 2.7 Icons

**Grid.** 16 × 16 viewBox, live area inset 1 u, key strokes on the half-unit grid.
Round caps, round joins, `fill: none`. The only fills are 1.9 u dots where a glyph
genuinely terminates in a point (Wi-Fi, regex, list bullets, ellipsis).

**Stroke.** Apparent stroke is a **constant 1.25 px at every optical size**:
`stroke-width = 20 / renderedSize` in the 16-unit viewBox. A 28 px session glyph is
drawn with the same pen as a 12 px row glyph, so large icons read as fine
engravings rather than heavy pictograms. This is the single most characteristic
rule of the variant.

**Optical sizes.** 12 (dense rows, secondary marks) · 14 (default: stats, inline
row icons, steppers) · 16 (controls, toggles, headers, tray) · 20 (OSD, transport,
search results, quick-layout) · 28 (session tiles). Bar tray items render at 15.

**Set — 76 glyphs**, a superset of the 40 pixel bitmaps:

```
nav      chev-d chev-u chev-l chev-r arrow-r arrow-l close plus minus check
         dot ring ellipsis drag warn
system   cpu ram robot proc clock calendar timer bolt heart refresh gear
         sliders terminal keyboard power lock logout moon sun snow coffee
         sparkle nodes swap fullscr crop dropper flashoff puzzle display
         laptop layers grid
comms    bell bell-off message mic mic-off speaker speaker-x wifi wifi-off
         bt globe
content  note pencil trash todo square search folder branch image play
         pause prev next regex list battery bat-chg
```

The gaps the pixel family papered over are closed: `lock` and `logout` exist (they
were `gear` and `swap`), vertical chevrons exist (they were `chev-l`/`chev-r`
rotated 90°), and `check` / `plus` / `minus` / `close` / `search` / `display` /
`branch` replace improvised squares.

**Third-party app icons — `PaperAppIcon`.** Where a mapping exists (terminal,
browser, editor, chat, files, image viewer, music player) the shell substitutes
its own line glyph. Everything else is the real `.desktop` icon desaturated **and
multiplied to `ink-2`** at 14–16 px — one ink, no third-party colour, the same
policy as the pixel theme’s greyscale rule. Unresolvable icons fall back to
`puzzle`, or `message` inside notifications.

### 2.8 Control sizes

| Control | Size |
|---|---|
| Icon button (`PaperIconButton`) | 24 × 24 hit area, 16 px glyph, **nothing drawn** |
| Caps / text button | Type only; ≥ 24 px hit area, 26–34 px between buttons |
| Switch (`PaperSwitch`) | 26 × 9 rail, 6 px knob, 20 px travel |
| Check (`PaperCheck`) | 12 px ring, 6 px inner dot |
| State dot | 6 px |
| Toggle row | fill × 56 |
| List row | fill × 40–48 |
| Notification row / toast | fill; toast 372 wide |
| Workspace cell | 26 × 26, 10 px gap, 16 px glyph |
| Bar vertical divider | 1 × 14, 20 px margins either side |
| Session column | 120 wide, separated by full-height 1 px rules |
| Exposé tile | `monitorSize × overview.scale`, 8 px gaps |
| Album art | 128 × 128 |
| Battery glyph | 19 × 9 |
| Meter | full width × 1 px track, 4 px head |

### 2.9 Surface sizes

Bar full-width × **38** · Quick settings **380** × screen height (right) ·
Displays **400** × screen height (left) · Notification toast **372** inside a 400
window · Media controls **480 × 168** (+224 lyrics → 392) · Search **600** wide,
results capped at 520 tall · Worktrees dialog **480** wide, capped at 900 ·
OSD **300 × 62** · Session columns 6 × 120.

Displays grew from 380 to 400 and worktrees from 440 to 480: chips and fields are
now type rather than boxes, and type needs the room that borders used to imply.

---

## 3. Shared widget catalog

See `widgets.html` for every state rendered.

**`PaperSurface`** — replaces `PixPanel`. Opaque `paper` ground, one 1 px `rule`
border, radius 0, no shadow, no second border weight. A surface that touches a
screen edge drops the border on that edge and keeps only the inboard hairline: the
bar keeps its bottom rule, quick settings its left rule, displays its right rule.
Padding 20 (toasts, popups) or 24 (sidebars, dialogs).

**`PaperButton`** — replaces `PixButton`. There is no box and no fill state; a
button is its label. Three shapes:

* **caps** — micro-caps, for dialog actions, destructive verbs, section actions.
  Rest `ink-2`; hover gains a `rule-2` underline; active/primary is `ink` with an
  ink underline; disabled drops to `ink-4` and loses the rule entirely, so “not
  yet” reads as “not yet underlined”.
* **text** — 12 px, same states, for inline secondary actions.
* **icon** — 24 × 24 hit area, 16 px glyph, no visible bounds. `ink-2` at rest,
  `ink` when active, `ink-4` when disabled, `alert` while a destructive one is
  pressed.

**`PaperSwitch`** — new; the pixel family had no switch because everything was a
fill. 26 px rail, 6 px knob, 140 ms travel. Off: `rule-2` rail, hollow `ink-3`
knob at the left. On: `ink` rail, solid `ink` knob at the right. The knob is the
largest solid ink mark in the system.

**`PaperCheck`** — a 12 px ring that fills to a 6 px dot. To-dos, repo selection,
“also delete the template file”. A completed to-do additionally takes a 1 px
strike (a rule, on brand) and drops to `ink-4`.

**`PaperSegment`** — replaces the row of filled `PixButton`s. Options are plain
type, 22–24 px apart; the current one is `ink` with a 1 px underline. Impossible
options (a zoom step that would not divide the resolution into whole logical
pixels) drop to `ink-4` and lose the rule.

**`PaperField`** — replaces `PixField`. A micro-caps label, the value, and a single
hairline underneath — no box, ever. Rest `rule-2`; focus `ink` plus a 1 px caret;
invalid `alert` with the message directly beneath in `alert` at 11 px; read-only
keeps `rule` and `ink-2`. Selection is a `wash-2` band. A borderless variant (no
label, full width, leading glyph) serves search and the to-do adder.

**`PaperMeter`** — replaces the 20-cell discrete bar. A 1 px `rule-2` track, a 1 px
`ink` fill, and a **4 px head dot**; the head is what makes a 1 px line readable at
a glance and it doubles as the seek handle in the media card. Used by the OSD,
media progress, RAM/CPU in the system-monitor popup, and the pomodoro.

**`PaperText`** / **`PaperMono`** — §2.3–2.4. `PaperText` exposes the eight scale
roles as named states rather than raw sizes.

**`PaperIcon`** — §2.7.

**`PaperAppIcon`** — §2.7.

**`PaperBattery`** — 19 × 9: a 16 × 9 hairline body with a 2 × 4 nub, and a level
fill inset 1.5 px. The level fill is the **one solid ink mark allowed to exceed
6 px**, because it encodes a quantity, not a state. Charging replaces the fill with
a 10 px `bolt`. ≤ 15 % turns body, fill and percent `alert`.

**`PaperTooltip`** — `paper`, 1 px `rule-2`, 5 px vertical / 9 px horizontal
padding, 11 px `ink-2`, 10 px from the anchor edge, 350 ms show delay, 120 ms hide
debounce, empty input region so it can never steal hover. Identical behaviour to
`PixTooltip`, one-third the chrome.

**Composite widgets:** `PaperSectionHeader` (micro-caps label + a hairline running
to the container edge + an optional right-hand meta or caps button — the theme’s
only heading device), `PaperToggleRow` (§4.3), `PaperListRow` (separator between
rows, never around them; selected takes an 11 px left gutter with a 1 px ink rule;
hover takes the 4 % `wash`), `PaperTabs`, `PaperStepper` (label + help, then
`−  value  +` as two icon buttons around a mono numeral), `PaperKeyValue`
(micro-caps keys, mono values), `PaperStat` (14 px glyph + mono value),
`PaperChipRow` (wrapping type chips), `PaperDivider` (1 × 14 vertical),
`PaperEmpty` (`ink-4` at 11 px between two rules).

**Mapping from the pixel family**

| Pixel | Paper A | Change |
|---|---|---|
| `PixPanel` | `PaperSurface` | 3 px / 2 px border → one 1 px rule |
| `PixButton` | `PaperButton` | Fill-on-active → underline-on-active; no bounds drawn |
| `PixField` | `PaperField` | 32 px box → label + single underline |
| `PixIcon` | `PaperIcon` | 7 × 7 bitmaps → 16-grid line glyphs, constant 1.25 px stroke |
| `PixAppIcon` | `PaperAppIcon` | Desaturate → desaturate + multiply to `ink-2` |
| `PixBatteryGlyph` | `PaperBattery` | 20 u × 11 u pixel body → 19 × 9 hairline body |
| `PixTooltip` | `PaperTooltip` | 2 px border → 1 px `rule-2`; identical timings |
| `PixText` / `PixTitle` | `PaperText` | Tiny5 + Silkscreen → Inter + JetBrains Mono; titles become micro-caps of the body face |
| `PixToggleTile` | `PaperToggleRow` | 46 px bordered tile → borderless 56 px row + switch |
| `PixSegment` | `PaperSegment` | Row of filled buttons → underlined type |
| — | `PaperSwitch` | New |
| — | `PaperMeter` | 20 discrete cells → 1 px track + head dot |

---

## 4. Surface inventory

### 4.1 Background

Unchanged in role, replaced in content. The 1-bit pixelscape is not part of this
variant: Hairline expects a still wallpaper (the user’s own) and draws nothing over
it. If a generated background is wanted later it should be a **paper-toned** field
— no imagery, no motion, no scrolling — because a moving landscape competes with a
theme whose entire vocabulary is a 1 px line.

*Data shown:* nothing. No interaction.

### 4.2 Bar — see `bar.html`

One `PanelWindow` per screen, top/left/right, `implicitHeight = 38`,
`exclusiveZone = 38`, visible while `GlobalStates.barOpen && !screenLocked`. The
bar is an opaque `paper` rectangle whose only chrome is a **1 px bottom rule** in
`rule`. Content inset 20 px left and right, vertically centred above the rule.
The bar does **not** tint or blur the wallpaper — it reads as a strip of printed
page laid over the desktop, which is the conceit of the whole variant.

The two invisible scroll regions are unchanged: the left half changes brightness
by ±0.05, the right half changes volume, both raising the OSD and closing it on
`movedAway`.

**Left cluster**

1. **Tray** — one 20 × 20 hit area per pinned `SystemTrayItem` holding a 15 px
   `PaperAppIcon`, 18 px apart. Left click activates, right click opens the item
   menu, hover shows its tooltip. The three coded-but-hidden status glyphs
   (idle inhibitor `snow`, `wifi`, `bt`) become visible in this variant: they cost
   a hairline of ink each and drop to `ink-4` when off.
2. **Divider** — 1 × 14 `rule`, 20 px margins.
3. **Stats** — hovering the group opens the system-monitor popup, left-aligned.
   Row spacing 20; each item is a 14 px glyph in `ink-2` plus a mono 12 px value in
   `ink`: `ram` memory-used %, `cpu` load %, `robot` Claude session % (only when
   `ClaudeUsage.available`).
4. **Divider**, then the **media indicator**: a 14 px `note` glyph plus the current
   MPRIS title at 12 px `ink-2`, elided at 190 px, or “No media” in `ink-4`.
   Clicking opens the media controls; tooltip “Media controls”.

**Centre — workspaces.** Ten 26 × 26 cells, 10 px apart, mapped to the current
group of ten. The bordered-square language is gone:

* **occupied** — a 16 px `PaperAppIcon` of the biggest window, in `ink-2`;
* **empty** — its number in mono 11 px `ink-4`;
* **focused** — the glyph goes to `ink` and a 1 px `ink` rule sits 3 px under the
  cell, sliding between cells in 140 ms.

Click switches; scrolling anywhere over the row cycles (`workspace r±1`).

**Right cluster**

1. **Clock** — `HH:mm` in mono 15 px `ink` (the largest type on the bar) followed
   by `ddd dd MMM` at 11 px `ink-3`, 10 px apart. Hover opens the clock popup.
2. **Divider**.
3. **Controls**, 18 px apart: `crop` region screenshot (when
   `bar.utilButtons.showScreenSnip`, tooltip “Screenshot region”); `moon` / `sun`
   palette toggle, drawn as the mode you would switch *to* (tooltip “Toggle dark
   mode”). Then the **battery chip** — `PaperBattery` plus the rounded percent in
   mono 12 px, 8 px apart, hidden when no battery. Hover opens the battery popup;
   click opens quick settings.

There is still no bar entry point for Displays or Worktrees — both stay
keybind/IPC only.

#### Bar hover popups

Each is its own overlay `PanelWindow` hanging `barHeight + 8` = 46 px from the top,
horizontally centred under the hover target (left-aligned for stats), a
`PaperSurface` with **20 px** padding, content-sized, alive only while the target
is hovered.

* **Clock popup** (360 wide) — `calendar` glyph + full date in `lead`;
  `clock` glyph + “System uptime” + the value in mono; a hairline; a
  `To do · N pending` section header; then up to 5 items as a mono `ink-4` numeral
  and the text at 12 px, with “… and N more” beneath, or “No pending tasks”.
* **Battery popup** (300 wide) — the percent in `title` 18 px beside a `Battery`
  micro-cap and the glyph, a hairline, then three rows of glyph + label + mono
  value: time to full/empty (hidden when meaningless), charge state and watts,
  health.
* **System-monitor popup** — three columns 40 px apart, each headed by a
  micro-caps label with a hairline running to the column edge.
  **RAM**: a filled 6 px dot + “Used”, a hollow dot + “Free”, a `ram` glyph +
  “Total”, then a meter of the used fraction. **CPU**: `bolt` + “Load”, a meter,
  `proc` + process count, `timer` + uptime. **Claude** (only when available):
  `clock` + session, `calendar` + week, `sparkle` + Opus, `refresh` + “Updated”
  (+ “ (stale)” on error). The pixel theme’s filled-vs-hollow 9 px swatch survives,
  shrunk to the 6 px state dot.

### 4.3 Quick settings — see `quick-settings.html`

`PanelWindow` anchored top + right + bottom, **380 px** wide, `exclusiveZone: 0`,
gated by `GlobalStates.sidebarRightOpen`, closed by `HyprlandFocusGrab` click-out
or Escape. A `PaperSurface` with a **left** rule only, 24 px padding. All sections
fixed height except the notification list, which flex-grows.

1. **Header** — a `clock` glyph and “Up *3 d 14 h*” (mono) at the left; four icon
   buttons at the right, 16 px apart, with tooltips: `pencil` Edit, `refresh`
   Refresh, `gear` Settings, `power` Power.
2. Hairline.
3. **Connectivity** section header, then six **toggle rows**, replacing the pixel
   build’s 46 px bordered tiles in a 3 × 2 grid. Same information, more of it
   visible, and the switch carries the state so the title never has to invert:
   * **Internet** (`wifi`, status = network name / “Connected” / “Not connected”) →
     chevron, opens the Wi-Fi overlay;
   * **Bluetooth** (status from the toggle model) → chevron, opens the Bluetooth
     overlay;
   * **Keep awake** (`coffee`, idle inhibitor) → switch;
   * **Microphone** (`mic`, source mute) → switch;
   * **Audio output** (`speaker`, mute + volume) → switch;
   * **Night light** (`moon`) → switch.
4. **Toggles** section header, then a five-column row of glyph over 9.5 px
   micro-cap, active columns underlined: `nodes` Cloudflare WARP, `fullscr` Game
   mode, `sliders` Easy Effects, `flashoff` Anti-flashbang, `dropper` Colour
   picker. Each carries a left-anchored tooltip.
5. Hairline.
6. **Notifications** section header with the count in its right slot (the pixel
   build’s non-interactive full-width “N notification(s)” button disappears).
   The list flex-grows, min 60 px; “No notifications” in `ink-4` when empty.
7. Footer: two caps buttons, “Mark all read” and “Clear all”, 26 px apart.
8. Hairline.
9. **Calendar area** — a tab row sitting on the rule that already separated the
   section.

**`PaperToggleRow`** — 56 px, no border, no fill: a 16 px glyph (`ink` when on,
`ink-3` when off, unchanged 1.25 px stroke), a 13 px title (`ink` / `ink-2`) over
an 11 px status in `ink-3`, then a switch or a chevron. The whole row is clickable
and carries a left-anchored tooltip.

**`PaperNotifRow`** — a 16 px `PaperAppIcon`, 12 px gutter, then: a header line of
optional 6 px alert dot + app name in **micro-caps** + relative time in mono
`ink-3` +, for groups larger than one, a mono count and a chevron (no chip border);
then the latest summary at 13 px `ink` and the body at 12 px `ink-2`, both single
line elided. Clicking expands a group or dismisses a single notification. Expanded,
it lists every notification newest-first — summary 13 px, body 12 px wrapped to
3 lines — indented 29 px, one hairline apart, each with a 14 px `trash` icon
button. The chevron flips in 140 ms.

**Calendar area** — three micro-cap tabs (Calendar / To do / Timer) over a
continuous hairline; the active tab owns the 1 px above it.

* **Calendar** — “August *2026*” in `lead` (the year in `ink-3`) with `chev-l` /
  `chev-r` icon buttons; a 7-column weekday header in 9 px micro-caps; a hairline;
  then 42 day cells in mono 12 px. Today is `ink` with an 18 px underline instead
  of a filled rectangle; out-of-month days are `ink-4`; the rest are `ink-2`.
* **To do** — rows of `PaperCheck` + text + a `trash` icon button, one hairline
  apart; done items drop to `ink-4` and take a 1 px strike. Bottom: the borderless
  field variant with a leading `plus`, an “Add task…” placeholder in `ink-4` and a
  trailing `arrow-r`. “No tasks” when empty.
* **Timer** — `TimerService`. Phase in micro-caps (`Focus` / `Break` /
  `Long break`) beside `#cycle` in mono; the remaining `MM:SS` at **40 px / weight
  200** in JetBrains Mono; a 150 px meter of the elapsed fraction of the phase
  (new, and free, because the meter already exists); then two caps buttons,
  Start/Pause (underlined while running) and Reset.

**Management overlays** — tapping Internet or Bluetooth covers the panel on an
opaque `paper` ground. A back bar of `chev-l` plus the section name in micro-caps;
no title bar, no bordered manager panel inside a bordered sidebar.

* **Wi-Fi** — a hairline, a “Wi-Fi” row with the radio switch and a `refresh` icon
  button (disabled while scanning), then 40 px network rows one hairline apart.
  Each row: a 6 px dot gutter (filled for the connected network), a `wifi` glyph,
  the SSID at 13 px over its status (“Connected” / “Connecting…” / “NN %”), and a
  12 px `lock` in `ink-4` when secured. The connected network is `ink`; the rest
  `ink-2`. Click connects, or disconnects the active one. Empty: “Scanning…” /
  “Wi-Fi off”.
* **Bluetooth** — the same shell with a `bt` radio switch and `refresh` rescan.
  Rows show the device name over “Connected [· NN %]” / “Paired” / “Tap to
  connect”; connected devices take the dot and `ink`. Discovery runs while the
  screen is visible. Empty: “Searching…” / “Bluetooth off”.

### 4.4 Notification popups — see `notifications.html`

Overlay `PanelWindow` on the focused screen, top + right + bottom, **400 px** wide,
visible only while `Notifications.popupList` is non-empty and the screen is not
locked, click-through except over the toasts. The stack starts `barHeight + 12` =
50 px from the top, 14 px from the right, items **372 px** wide and **12 px** apart.

Each toast is a `PaperSurface` with 15 px vertical / 18 px horizontal padding:

* a 16 px `PaperAppIcon` (fallback `message`), top-aligned, 12 px gutter;
* a header row: optional 6 px `alert` dot, app name in micro-caps, relative time in
  mono `ink-3` (`now` / `Nm` / `Nh` / `Nd`, refreshed every 30 s), and for a group
  the count plus a chevron;
* the summary at 13 px `ink`, single line, elided;
* the body at 12 px `ink-2`, wrapped, clamped to 2 lines;
* one **caps button per labelled action**, 26 px apart, 11 px below the body. The
  first action carries the ink underline as the implied default; the rest sit at
  `ink-2`. The unlabelled “default” action is still never drawn.

Hovering applies the 4 % `wash` and cancels auto-dismiss; clicking the toast fires
the default action and dismisses; clicking an action fires it and dismisses.

### 4.5 On-screen display — see `osd.html`

One overlay on the focused screen, horizontally centred, `barHeight + 14` = 52 px
from the top (or the bottom when the bar is bottom-anchored). Raised by volume or
brightness changes for `Config.options.osd.timeout`; hovering dismisses it at once;
region-masked to the panel.

A `PaperSurface` **300 × 62**, 16 px vertical / 20 px horizontal padding, row gap
16: a 20 px glyph (`speaker` for volume, `speaker-x` when muted, `sun` for
brightness), then a column of a label row (13 px `ink` left, the rounded percent in
mono 13 px right) over a `PaperMeter`. Muted drops glyph, label and value to
`ink-3` and empties the track.

### 4.6 Overview / launcher — see `overview.html`

One full-screen overlay per screen, gated by `GlobalStates.overviewOpen`, with
`HyprlandFocusGrab`; Escape or a scrim click closes, ←/→ switch workspaces while
the query is empty. The scrim is `paper` at 62 % — the desktop is **bleached**
rather than darkened, the light-mode counterpart of the pixel theme’s 45 % black
wash. A centred column starts at 12 % of screen height, 24 px between the two
widgets.

**Search** — a **600 px** `PaperSurface` with no inner box: a 18 px `search` glyph,
the query at 16 px, an optional result count in micro-caps at the right, and the
field’s own 1 px underline (`rule-2` at rest, `ink` while typing) which doubles as
the seam between the field and the result list. Results hang directly beneath in
the same surface, capped at 520 px, one hairline apart.

Each row is `content + 20` tall with 22 px side padding and a 14 px gutter: the
icon (a 20 px `PaperAppIcon` for apps; a `PaperIcon` mapped from the entry kind for
run/math/clipboard/emoji/web/action entries, which fixes the pixel build’s
“everything is a terminal glyph” fallback since there is no symbol font), then the
entry type in micro-caps (hidden for apps) over the entry name at 13 px, and — only
while selected — the verb (“Open”, “Run”, “Search”, …) in micro-caps `ink` on the
right. The active row takes `ink`, an 11 px left gutter and a 1 px ink rule; there
is no inversion and no fill. Typing anywhere routes into the field, Backspace
edits, Ctrl+J/K move, Enter runs. Data still comes from `LauncherSearch`.

**Workspace exposé** — hidden while a query is typed. A `PaperSurface` with 20 px
padding around a grid of `overview.rows × overview.columns` (default 2 × 5) tiles,
8 px apart. Each tile is `monitorSize × overview.scale`, drawn as a 1 px `rule`
outline with the workspace number in mono 11 px `ink-4` at the top-left. Live
`ScreencopyView` thumbnails sit at their real scaled positions inside a 1 px
`rule-2` frame with the app glyph and an elided title in micro-caps beneath it.
Windows on another monitor render at 0.4 opacity. Hover shows the
`title\n[class]` tooltip; left click focuses and closes, middle click closes the
window, dragging moves it (`movetoworkspacesilent`) or repositions a floating
window (`movewindowpixel`). The drop-target tile takes the 4 % `wash` plus an
`ink` outline. Clicking an empty tile switches to that workspace. The **focused**
workspace’s outline and number go to `ink` — no 5 px ring, no animated frame beyond
the 140 ms colour change.

### 4.7 Media controls — see `media-controls.html`

`PanelWindow` anchored top-left, `barHeight + 8` = 46 px down, flush with the left
edge, width **480**. The layer surface keeps a fixed height so it never resizes;
only the inner card animates between **168 px** and **392 px** over 280 ms as the
lyrics open. Masked to the card; `HyprlandFocusGrab` + Escape close it; gated by
`GlobalStates.mediaControlsOpen`. With no player it shows a 24 px `note` glyph over
“No active player”, both `ink-4`, centred in a 168 px card.

**Player area** (fixed 168 px, 20 px padding, 18 px gap):

* **Album art** — 128 × 128 in a `paper-sunk` well with a 1 px `rule-2` frame,
  `PreserveAspectCrop`. **This is the only colour in the entire shell**, unchanged
  from the pixel theme; it is what makes the art read as an artefact laid on the
  page. Without art, a `note` glyph in `ink-4`.
* **Info column** — the cleaned track title in `lead` (elided) with a 16 px
  `message` lyrics toggle at the right (`ink` while lyrics are shown); the artist
  at 12 px `ink-2`; the album and year at 11 px `ink-3`; a spacer; `elapsed` and
  `total` in mono 11 px at either end of a row; the **`PaperMeter`**, clickable to
  seek, ticked once a second while playing; then transport at 20 px, 26 px apart —
  `prev`, `play`/`pause` in `ink`, `next` — with the player identity in micro-caps
  pushed to the right.

**Lyrics** — separated by a single hairline, 18 px vertical / 20 px horizontal
padding. Synced lines scroll so the active line stays vertically centred (400 ms,
suspended 4 s after a manual scroll). The current line is `lead` 15 px `ink`;
upcoming lines are 13 px `ink-3`; **past lines fall to `ink-4`**, so reading
direction is encoded purely as a fade from behind you to ahead of you. Clicking a
line seeks to it. Unsynced lyrics render as one wrapped 12 px `ink-2` block.
Placeholders in `ink-4`: “Searching for lyrics…”, “No lyrics”, “Couldn’t load
lyrics”, “Instrumental”.

### 4.8 Displays overlay — see `monitors.html`

`PanelWindow` anchored top + left + bottom, **400 px** wide,
`keyboardFocus: OnDemand`, gated by `GlobalStates.monitorsOpen`, closed by focus
loss or Escape. Keybind/IPC only. A `PaperSurface` with a **right** rule only,
24 px padding. Every write still goes through the `Monitors` service →
`hdm-control.py`. Three screens: main, profile editor, settings; the latter two
cover the panel on an opaque `paper` ground.

**Main**

1. Header — “Displays” in micro-caps `ink`, plus `refresh` (“Refresh”) and `gear`
   (“Settings & daemon”) icon buttons.
2. Status row — a 6 px dot (filled when the HDM daemon is running) + “Daemon
   running / not running” at 11 px; at the right, “Quick: *mode*” or “Active:
   *profile*” or “No profile”, elided at 200 px with the value in `ink`.
3. Hairline, then a scrolling body:
   * **Quick layout** — three equal columns of an 18 px glyph over a micro-cap,
     underlined when active: `nodes` Extend, `swap` Mirror, `fullscr` Single. The
     same construction as the quick-settings extras row, so the two panels read as
     siblings. With **Single** active, a wrapping chip row picks which output stays
     on. With more than one screen, **Extend** adds *Other screens go* — four
     `PaperArrange` pickers, each a two-rectangle diagram (the **ink-bordered**
     rectangle is the primary screen and the other is `rule-2`; stacked for
     Above/Below) over a 9 px micro-cap. Extend and Mirror expose *Primary screen*
     as a chip row. Any quick layout exposes *Zoom*: one row per screen with the
     output name in mono 11 px (62 px column) and five equal chips
     1 / 1.25 / 1.5 / 1.75 / 2×; steps that would not divide the resolution into
     whole logical pixels drop to `ink-4` and lose their underline. Finally a
     `refresh` glyph + the caps button **“Auto — my profiles”**, which clears the
     quick override and is underlined while no quick mode is active.
   * **Connected (n)** — one row per output, one hairline apart: a 16 px `display`
     glyph, `NAME · description` at 13 px over `WIDTH×HEIGHT@Hz   x,y   Nx` in mono
     11 px (plus `mirror→NAME` when mirroring, or “Disabled”), and a **switch** for
     enabled. The pixel build could only express “enabled” by filling a 30 × 30
     square.
   * **Profiles** — the section header carries a “+ New” caps button in its right
     slot. One row per profile: a 6 px dot (filled = the profile HDM currently has
     active), the profile name at 13 px with an “Active” micro-cap suffix, an 11 px
     summary of required monitors (`~` prefix for regex, joined by “+”) and
     conditions in brackets, and a `chev-r` in `ink-4`. Disabled profiles render at
     0.45 opacity. The whole row opens the editor. Empty: “No profiles yet — press
     **+ New** or pick a quick layout”.
4. Status line — “Working…” while busy, otherwise `Monitors.lastMessage` at 11 px
   `ink-3`, turning **alert** when the last operation failed.

**Profile editor** — scrolling. A back bar (`chev-l`, the profile name in
micro-caps `ink`, a “Save” caps button in `ink`); a **Name** field (read-only for
existing profiles); a **Type** segment Template/Static; a `layers` glyph + a caps
button that toggles “capture current layout” for new profiles or applies the live
layout to an existing one; **Required monitors** with a “+ Add” caps button and,
per entry, a Name/Desc segment, a `regex` icon button (tooltip “Match with a
regular expression”, `ink` when armed), a `trash` icon button, and the value on its
own underline (placeholder “connector, e.g. DP-1” / “description, e.g. Dell
U2720Q”); a wrapping row of “+ NAME” chips to add a connected monitor;
**Conditions** — Power (Any/AC/Battery) and Lid (Any/Open/Closed) segments with a
48 px micro-cap label column; **Template values** — key/value pairs where the key
sits on a `rule` and the value on a `rule-2`, so the weight difference tells you
which one you are meant to edit, each with a `trash`; and for existing profiles a
footer of a Disable/Enable caps button, `chev-u` / `chev-d` reorder icon buttons
(tooltips “Higher in file (lower priority on ties)” / “Lower in file (wins ties)”)
and an `alert`-coloured `trash`. Removal opens a full-cover confirmation:
“Remove profile” in micro-caps, an explanatory line, a `PaperCheck` for “also
delete its template file”, a hairline, then **Cancel** in `ink` and **Remove** in
`alert` with an alert underline — the safe action is deliberately the visually
stronger of the two.

**Settings** — back bar + “Settings”; **Daemon** — the 6 px dot, a status line, and
three caps buttons Validate / Reapply / Reload; **Profile scoring** — an
explanatory 11 px paragraph and four `PaperStepper`s (Name match, Description
match, Power state match, Lid state match) plus an “Apply scoring” caps button;
**Notifications** — a switch row “Desktop notification on profile switch”, a
Timeout stepper (step 1000, max 60000) and “Apply notifications”; **Info** — a
read-only key/value grid of destination path, debounce and config path.

### 4.9 Session screen — see `session-screen.html`

Full-screen, keyboard-exclusive overlay on the focused screen, gated by
`GlobalStates.sessionOpen`. Scrim: `paper` at **92 %** — near-opaque, so the six
choices sit on a clean page. Clicking the scrim cancels.

1. **SESSION** in `display` (24 / 300 / +.18em / uppercase).
2. 40 px, then a row of six **120 px columns separated by full-height 1 px vertical
   rules** — the only vertical rules in the theme besides the bar dividers. Each
   column: the number accelerator in mono 10 px `ink-4` at the top-left, a 28 px
   glyph, and a micro-cap label 22 px below it. Actions in order: **Lock**
   (`lock`, 1), **Log out** (`logout`, 2), **Suspend** (`moon`, 3), **Hibernate**
   (`snow`, 4), **Reboot** (`refresh`, 5), **Shut down** (`power`, 6) — all six
   drawn properly for the first time; the pixel set had no lock and no logout and
   substituted `gear` and `swap`. The selected column takes `ink` on the glyph and
   label plus a 1 px underline, and its accelerator lifts to `ink-2`. Nothing
   inverts, nothing fills, and total travel is 0 px: only the underline moves.
3. 40 px, then the hint line at 11 px `ink-3`, with the key names in mono `ink-2`:
   “Arrows or 1–6 to choose · Enter to confirm · Esc or a click anywhere to
   cancel”.
4. Session warnings, 28 px apart, each a 6 px `alert` dot plus 11 px `alert` text:
   “Your package manager is running”, “There might be a download in progress”.

Keys: ←/→/↑/↓/Tab move, Home/End jump, Enter/Space run, 1–6 select and run
immediately, Escape cancels. Hover also moves the selection.

### 4.10 Worktrees dialog — see `worktrees.html`

Centred modal on the focused screen, keyboard-exclusive so the name field is
typeable immediately, over the same 92 % `paper` scrim; Escape or a scrim click
closes. Gated by `GlobalStates.worktreesOpen`; keybind/IPC only. A `PaperSurface`
**480 px** wide, 24 px padding, capped at 900 px with the repo and reopen lists
scrolling.

1. “New worktree” in micro-caps `ink` with an “Esc” caps button; hairline.
2. **Task name** field. Invalid input turns the underline `alert` and prints
   “letters, digits, . _ - only” beneath it in `alert` at 11 px.
3. **Repos** section header with the base branch in its right slot (“from
   *main@origin*”, the ref in mono). One row per discovered repo: a `PaperCheck`,
   the repo name at 13 px, and “N srv” (or “no servers”) in mono 11 px at the
   right. A selected repo takes the standard 11 px ink gutter and only then reveals
   its server chips — picked servers `ink` with an underline, the rest `ink-3` — or
   the note “no vitulina servers — gets a shell tab” in `ink-4`. Clicking anywhere
   on the row toggles it. Empty: “No git repos found in ~/pleevi”. Below, an 11 px
   `ink-4` line naming repos that need `jj git init --colocate` first.
4. Hairline, then a **Summary** key/value grid: micro-caps keys, mono 12 px values
   — Path (`~/pleevi/<name>`), Bookmark, Env (`vitulina up --env <name>`), Setup
   (“jj workspace, copy .env, direnv allow” + “pnpm i (…)” for node repos), Tabs
   (total plus the breakdown).
5. **Create** and **Cancel** caps buttons, 32 px apart. Create reads “Working…”
   while busy and stays at `ink-4` with no underline until the name validates and
   at least one repo is ticked.
6. Hairline, **Reopen** section header with “N tasks” at the right, then a
   scrolling list (max 150 px) of task rows: the task name at 13 px (max 170 px),
   the repos joined by commas at 11 px, and “N tabs” in mono. Hover takes the 4 %
   `wash`. Empty: “No task folders in ~/pleevi yet”.
7. Hairline, **Log** section header, then a `paper-sunk` region (no border — the
   tone shift is enough) capped at 118 px with the script output in mono 11 px
   `ink-3`, auto-scrolled to the bottom. On failure the failing lines turn `alert`
   and the ground stays put, which is legible; the pixel build switched both border
   and text to plain `fg`, which was indistinguishable from success.

---

## 5. Behavioural notes preserved from the pixel family

* **Open-state flags** (`GlobalStates`) unchanged: `barOpen`, `screenLocked`,
  `sidebarRightOpen`, `overviewOpen`, `sessionOpen`, `mediaControlsOpen`,
  `monitorsOpen`, `worktreesOpen`, `osdVolumeOpen`, `osdBrightnessOpen`.
* **IPC targets / shortcut names** unchanged so existing keybinds keep working:
  `sidebarRight`, `search`, `session`, `mediaControls`, `monitors`, `worktrees`,
  and the OSD targets.
* Panels that must survive a focus grab (quick settings, displays) keep their
  `PanelWindow` alive and toggle `visible`.
* Hover popups are separate overlay windows; tooltips use an empty input region so
  they never steal hover.
* The media controls’ surface height is fixed; only the inner card animates.
* Bar scroll regions, workspace scroll cycling, notification grouping and
  expansion, drag-to-move in the exposé, and every keyboard map are unchanged.

## 6. What this variant deliberately drops

* The scrolling 1-bit pixelscape background (§4.1).
* The `2 px` / `3 px` border distinction, and borders on anything that is not a
  surface edge or a separator.
* Every filled control state, every inversion, and the `onFill` token.
* The discrete 20-cell meter and the 7-cell progress bar.
* Bold as an emphasis mechanism.
* The dedicated title face.

## 7. Open questions for implementation

* `rule.hair-half` needs a `Screen.devicePixelRatio` branch: true 0.5 px on 2×
  outputs, 1 px at 55 % opacity on 1×. Worth measuring before committing to it —
  if it reads badly at 1× the token should collapse into `rule.hair`.
* `PaperAppIcon`’s multiply-to-`ink-2` step wants a `ColorOverlay` after
  `Desaturate`; confirm the cost at 16 px across a full tray.
* Inter should be listed as a package dependency rather than bundled; decide
  whether to ship a fallback stack or fail loudly if it is missing.
* The mapping table from `LauncherSearch` entry kinds to `PaperIcon` names (§4.6)
  needs to be written; it does not exist in the pixel build because everything fell
  back to one glyph.
