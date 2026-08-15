# Pixels — design specification of the CURRENT theme

Reference documentation of the `pixel` panel family as implemented in
`modules/pixel/` (~67 QML files). Every number here was read out of the QML; nothing
is inferred. Companion HTML mockups live next to this file (`bar.html`,
`quick-settings.html`, …) and recreate each surface at real proportions.

Source of truth for tokens: `modules/pixel/common/PixTheme.qml`.
Historical design notes: `modules/pixel/CONTRACT.md`, `modules/pixel/README.md` and
`modules/pixel/design/*.html` — **all three are stale** (they still claim Pixelify Sans
as the body font and list an older type scale). Trust `PixTheme.qml`.

---

## 1. Design language in one paragraph

Strictly monochrome, hard-edged, pixel-art. Two colours (background / foreground) plus
two greys, inverted between light and dark. Nothing is rounded (`radius: 0`
everywhere), nothing is antialiased (`antialiasing: false` on every rectangle and icon
cell), there are no shadows, gradients, blurs or accent colours. Borders are 2 px
(inline) or 3 px (popups/panels), always in the foreground colour. The entire
interaction language is one rule: **a filled square means active/used, a hollow
bordered square means inactive/free**, and whenever a control fills, its content flips
to the background colour. Icons are 7×7 bitmaps drawn from rectangles. Arbitrary app
icons are decoded at 16 px and fully desaturated so no third-party artwork introduces
colour — the single sanctioned colour in the whole shell is album art in the media
controls.

---

## 2. Design tokens

### 2.1 Colours (`PixTheme.colors`)

Dark mode is the default (`Appearance.m3colors.darkmode` defaults to `true`). The
pixel family reads **only** that boolean from the shell-wide Material-You service —
none of the wallpaper-derived accent colours the `ii` family uses reach it. The
palette is fixed, not dynamic.

| Token | Dark | Light | Used for |
|---|---|---|---|
| `bg` | `#0b0b0b` | `#ffffff` | Every panel / bar / popup fill; also the *content* colour on a filled control |
| `fg` | `#f4f4f4` | `#141414` | All primary text, icons, filled squares |
| `grey` | `#9b9b9b` | `#6e6e6e` | Secondary / muted text, inactive glyphs, placeholders, empty-workspace border |
| `grey2` | `#555555` | `#bdbdbd` | Faint: out-of-month calendar days, disabled steps, past lyric lines, workspace numbers, summary keys |
| `line` | `#f4f4f4` | `#141414` | Every border and rule — identical to `fg` by design |
| `onFill` | = `bg` | = `bg` | Convenience alias for content on a filled chip |

Translucency exists in exactly four places, all of `bg`:
* session screen scrim — 0.82 dark / 0.86 light
* worktrees dialog scrim — same values
* overview scrim — `rgba(bg, 0.45)`
* overview window hover / press wash — `rgba(line, 0.12)` / `rgba(line, 0.30)`;
  the workspace tile drop-target wash is `rgba(line, 0.12)`

### 2.2 Fonts

Bundled in `assets/fonts/`. Two roles:

* **Body — `PixText`**: `PixTheme.fontMain`, currently **Tiny5**
  (`fontMainChoice: "tiny5"`, a code-level switch with no UI). `Text.NativeRendering`,
  `weight: Font.Medium`, `hintingPreference: Font.PreferFullHinting`, vertical-centre
  aligned, colour `fg`.
* **Titles — `PixTitle`**: `PixTheme.fontTitle` = **Silkscreen Regular**.
  `weight: Font.Bold`, `letterSpacing: 1`, native rendering, default size 16.

Switchable alternates also shipped and wired into `PixTheme.mainFonts`: Pixelify Sans,
Departure Mono, Jersey 10, Press Start 2P, VT323, Handjet. Silkscreen Bold is loaded
but only Regular is referenced.

### 2.3 Type scale (`PixTheme.font.pixelSize`)

| Token | px | Where |
|---|---|---|
| `smallest` | 12 | Bar app-id line, session accelerator hints, workspace numbers, help text, info lines |
| `smaller` | 12 | Status sublabels, section labels, chips, times, past/upcoming lyric lines |
| `small` | 14 | Notification app names, list rows, button labels, calendar days, hint lines |
| `normal` | 14 | Default body size — row titles, tile titles, summaries, OSD label |
| `large` | 16 | System-monitor values, to-do popup text, current lyric line |
| `larger` | 16 | Bar stat values, popup rows, battery percent, media title in the bar |
| `title` | 16 | `PixTitle` default — section headings, clock, media track title |
| `huge` | 24 | `SESSION` heading; doubled to 48 for the pomodoro digits |

Bold (`font.bold: true`) is applied per-use, most often to values and row titles.
Explicit off-scale sizes: 9 px (calendar mini-button labels, `letterSpacing: 1`),
48 px (`huge * 2`, pomodoro), and the overview workspace number
(`max(16, tileHeight * 0.4)`).

### 2.4 Borders, radii, motion

| Token | Value | Where |
|---|---|---|
| `borderWidth` | 2 px | Chips, cards, list rows, inline panels, most buttons, rules |
| `popupBorderWidth` | 3 px | Popups, sidebars, overlays, session tiles, search field, media card |
| `barBorderWidth` | 3 px | The bar's bottom rule (the bar has no other border) |
| radius | 0 | Everywhere, without exception |
| `antialiasing` | false | Every rectangle and icon cell |
| shadow / gradient / blur | none | Not used anywhere |
| `barHeight` | 46 px | Bar height + exclusive zone |
| `animation.duration` | 110 ms | `PixButton` fill, notification chevron flip, focused-workspace indicator |
| `animation.type` | `Easing.OutQuad` | The only easing token |

Off-token animations: media card expand/collapse 300 ms `OutCubic`; lyrics auto-scroll
400 ms `OutCubic`; search-list highlight move 80 ms; background scroll is a linear
`NumberAnimation` at 22 screen-px/second.

Horizontal rules are plain 2 px `line` rectangles spanning the container width.
Vertical bar dividers are 2 × 22 px with 14 px margin either side (30 px total).

### 2.5 Spacing steps actually in use

`4 / 5 / 6` icon-to-label gaps, list-row spacing, calendar gaps · `7 / 8 / 9` popup
row gaps, tile padding (8), button rows · `10 / 11` quick-settings section gap (11),
notification row gap (10), toast padding (11) · `12 / 13 / 14` panel padding (12 for
quick settings / monitors, 14 for worktrees and bar popups), bar control gap (13), bar
side padding (12) · `16 / 18` media card side padding (16), system-monitor popup
padding (16), overview column gap (18), session tile gap (18) · `26 / 30` session
column gap (26), system-monitor popup column gap (30).

### 2.6 Icons

`PixIcon` renders one of **40** 7×7 bitmaps from
`modules/pixel/common/pixicons_data.js` as a `Repeater` of square `Rectangle` cells.
The requested `size` is snapped to a multiple of 7 (`cell = round(size/7)`), so 16 and
15 both render at 14, 18 and 21 both render at 21. Default colour `fg`.

Names: `robot crop bell bluetooth bolt calendar chevD chevL chevR clock coffee cpu
dropper flashoff fullscreen gear heart keyboard message mic moon nodes note pencil
power proc puzzle ram refresh sliders snow sparkle speaker sun swap terminal timer
todo trash wifi`.

There are no arrows, no lock and no logout glyph; the codebase substitutes
(`chevL`/`chevR` rotated 90° for reorder, `gear` for Lock, `swap` for Logout, two
squares for screen arrangement).

Common icon sizes: 9 (notification chevron), 12–13 (inline row icons), 14–16 (buttons,
bar controls), 18 (quick-settings toggles, workspace app icons), 21 (OSD, search
field), 28 (search result app icon), 42 (session tiles).

### 2.7 Control sizes

| Control | Size |
|---|---|
| `PixButton` default | 34 × 34 |
| Header / overlay back button | 38 × 34 |
| Small square button | 30 × 28 · 34 × 30 |
| Inline icon button (dismiss, add, checkbox) | 22 × 22 · 26 × 26 |
| Quick-settings icon column button | 44 × 46 |
| Quick-settings extras row | fill × 38 |
| Notification footer buttons | 44 × 36 |
| Toggle tile | fill × 46 |
| Calendar mini button | 64 × 54 |
| Quick-layout mode button | fill × 54 |
| Timer Start/Reset | 96 × 34 |
| Session tile | 132 × 132 |
| Bar control button | 22 × 22 (16 px glyph) |
| Workspace cell | 24 × 24, 6 px gap, 18 px icon |
| Notification app-icon square | 34 × 34 (22–24 px icon) |
| Toggle-tile icon square | 30 × 30 (16 px glyph) |

### 2.8 Surface sizes

Bar full-width × 46 · Quick settings 360 × screen height (right) · Displays 380 ×
screen height (left) · Notification toast 356 wide inside a 380 window · Media
controls 460 × 170 (+210 lyrics) · Search field & results 560 wide (results capped at
520 tall) · Worktrees dialog 440 wide, capped at 900 tall · Session tiles 6 × 132 with
18 gap.

---

## 3. Shared widget catalog (`modules/pixel/widgets/`)

**`PixButton`** — `Rectangle`, radius 0, 2 px `line` border, default 34 × 34.
Transparent by default; fills with `line` when `filled`, `checked`, or (if
`interactive && fillOnHover`) hovered; fills with `grey` while pressed. Exposes
`contentColor` (`bg` when active, `fg` otherwise) which children bind their colour to,
plus `hovered`. `clicked()` / `rightClicked()`. Fill colour animates 110 ms OutQuad.
Used for: every toggle, chip, segmented option, list row, checkbox, session tile,
notification action, dialog button.

**`PixPanel`** — the container primitive: `bg` fill, `line` border, radius 0, no
shadow. `borderWidth` defaults to 3 (popup) and is set to 2 for inline cards.
Used for: quick settings, monitors, worktrees, media card, search field/results,
overview background, notification toasts, OSD, toggle tiles, profile rows, monitor
cards, bar popups, tooltips.

**`PixField`** — 32 px tall single-line input, 2 px border that brightens from `line`
to `fg` on focus, 8 px side padding, body font at `normal`, grey placeholder,
selection = `fg` fill with `bg` text. `accepted()` and `edited(text)` signals.
Used in the profile editor and worktrees dialog. (The to-do adder uses its own inline
26 px variant with 6 px padding and a `grey2` placeholder.)

**`PixText`** — `Text` subclass, described in §2.2.
**`PixTitle`** — Silkscreen `Text` subclass, described in §2.2.

**`PixIcon`** — §2.6.

**`PixAppIcon`** — any app / tray / notification / window icon. Decodes the source at
`pixelResolution` (default 16) and upscales with `smooth: false, mipmap: false`, then
applies `Desaturate { desaturation: 1.0 }` — fully grayscale. Falls back to a
`puzzle` glyph (notifications override it to `message`) at 85 % size when the icon
cannot be resolved.

**`PixBatteryGlyph`** — 18 × 11 body with a 2 px border, an inner fill inset 1 px and
proportional to `percent` (max 12 px wide, 5 px tall), a 2 × 5 nub on the right, and a
`bolt` glyph replacing the fill while charging. `u` scales the whole glyph in whole
pixels; total footprint 20 u × 11 u.

**`PixTooltip`** — a hover hint in its own click-through `PopupWindow` (empty input
region, so it can never steal hover). 2 px border, 8 px horizontal / 4 px vertical
padding around the label (window = `label + 16` × `label + 8`), text at `small` (14),
14 px gap from the anchor edge, 350 ms show delay, 120 ms hide debounce. Default
visibility follows the parent's `containsMouse` / `hovered`; sidebar controls anchor it
to their left edge.

**Composite widgets** (not in `widgets/` but reused across surfaces):
`PixToggleTile` (§4.3), `PixSegment` (row of equal buttons, current one filled),
`StepperRow` (label + help, then `[−] value [+]`), `MonitorChips` (wrapping chip row),
`PixSysHeader` / `PixSysIconRow` / `PixSysSwatchRow` (system-monitor popup rows),
`PixStatItem` (icon + bold value), `PixBarDivider`, `PixControlButton`.

---

## 4. Surface inventory

### 4.1 Background — `background/PixelBackground.qml`

One bottom-layer `PanelWindow` per screen, filling the whole output, colour `bg`.
Displays a **1-bit black-and-white top-down landscape** generated by a separate Rust
binary (`background/pixelscape`, tile PNGs under `pixelscape/assets/tiles/`). The
renderer draws one screen-wide *segment* at a time (`pixelscape segment <k> <out> <w>
<h> <seed>`, rendered at 480 × 270 and stretched). Three tiles are laid side by side
and slid continuously leftwards at **22 screen-px/second** (linear); a tile that
exits the left edge is recycled to the right with the next segment index and
re-rendered off-screen. A random world seed is drawn once per shell start and shared
by all monitors, so every launch shows a different landscape while tiles still abut
seamlessly. The whole stack goes through `LevelAdjust`, which is identity in light
mode and swaps output levels in dark mode (black-on-white → white-on-black).

*Data shown:* nothing but the procedural landscape. No interaction.

### 4.2 Bar — `bar/PixelBar.qml` (see `bar.html`)

One `PanelWindow` per screen, anchored top/left/right, `implicitHeight = 46`,
`exclusiveZone = 46`, visible while `GlobalStates.barOpen && !screenLocked`. The
window is transparent; the bar is a `bg` rectangle whose only chrome is a **3 px
bottom border** in `line`. Content is inset 12 px left and right and 3 px from the
bottom (above the border).

Two invisible scroll regions cover the halves of the bar: scrolling the **left** half
changes brightness by ±0.05 and raises the brightness OSD; the **right** half changes
volume and raises the volume OSD. Both close their OSD on `movedAway`.

**Left cluster** (row, spacing 0):
1. **Tray** (`PixTray`, spacing 13) — one 20 × 20 hit area per pinned
   `SystemTrayItem` holding an 18 px grayscale `PixAppIcon`. Left click activates,
   right click opens the item's menu (`QsMenuAnchor` below the item), hover shows the
   item's tooltip text. Three further glyphs exist in the code (idle-inhibitor `snow`,
   `wifi`, `bluetooth`, each dimmed to grey when off and clickable) but are currently
   `visible: false`.
2. **Divider** — 2 × 22 line, 14 px margins.
3. **Stats** (`PixStats`) — hovering this group opens the system-monitor popup
   (left-aligned). Row spacing 14: `ram` icon + memory-used percent (bold 16),
   `cpu` icon + CPU percent, `robot` icon + Claude session percent (only when
   `ClaudeUsage.available`). Then a **media indicator**: another 2 × 22 divider and the
   current MPRIS track title in grey 16, elided at 200 px, or "No media". Clicking it
   opens the media controls; it has a "Media controls" tooltip.

**Centre cluster** — `PixWorkspaces`: ten 24 × 24 cells, 6 px apart, mapped to the
current group of 10 workspaces on this monitor. The fill is always transparent so the
grayscale app icon stays legible; states are carried by the border:
* **focused** — 3 px `fg` border plus a 1 px inner border inset 3 px
* **occupied** — 2 px `fg` border
* **empty** — 2 px `grey` border and a faint `grey2` 12 px workspace number
Occupied cells show an 18 px `PixAppIcon` of the **biggest window** on that workspace
(via `HyprlandData` / `hyprctl clients` → `AppSearch.guessIcon`). Click switches to
the workspace, scrolling anywhere over the row cycles workspaces (`workspace r±1`).

**Right cluster** (row, spacing 0):
1. **Clock** — `HH:mm · ddd, dd/MM`, bold 16. Hover opens the clock popup.
2. **Divider**.
3. **Controls** (row, spacing 13): `crop` = region screenshot (only when
   `bar.utilButtons.showScreenSnip`, tooltip "Screenshot region"); `sun` = toggle dark
   mode (active/full-brightness in light mode, tooltip "Toggle dark mode"); then the
   **battery chip** — `PixBatteryGlyph` + rounded percent in bold 16, spacing 6,
   hidden when no battery. Hovering it opens the battery popup; clicking opens quick
   settings.

There is no bar entry point for the Displays or Worktrees panels — both are
keybind/IPC only.

#### Bar hover popups — `bar/PixelBarPopup.qml`

Each is an overlay `PanelWindow` hanging `barHeight + 6` = 52 px from the top,
horizontally centred under the hover target (or left-aligned for the stats popup),
drawn as a 3 px `PixPanel` with **14 px** padding on all sides (16 px for the system
monitor). Content-sized. Alive only while the target is hovered.

* **Clock popup** — `calendar` icon + full date (`dddd, MMMM dd, yyyy`, bold 16);
  `clock` icon + "System uptime: " + uptime (bold); a 2 px rule; `todo` icon +
  "To Do" (bold); then up to 5 pending to-do items numbered `1. …`, indented 23 px in
  grey 16, with "… and N more" when there are more, or "No pending tasks".
* **Battery popup** — battery glyph + "Battery · N%" (bold 16); `timer` icon +
  "Time to full/empty: " + formatted duration (hidden when meaningless); `bolt` icon +
  "Fully charged" / "Charging · X.XW" / "Discharging · X.XW"; `heart` icon +
  "Health: " + percent.
* **System-monitor popup** — three columns 30 px apart, each column spacing 9. Each
  column starts with a header (16 px icon + bold 16 label + 2 px rule under it).
  **RAM**: a filled 9 × 9 swatch + "Used: N GB", a hollow swatch + "Free: N GB", a
  `ram` icon + "Total: N GB". **CPU**: `bolt` + "Load: N%". **Claude** (only when
  available): `clock` + "Session: N% · reset", `calendar` + "Week: N% · reset",
  `sparkle` + "Opus: N%", `refresh` + "Updated: Xm ago" (+ " (stale)" on error).

### 4.3 Quick settings — `quickSettings/` (see `quick-settings.html`)

`PanelWindow` anchored top+right+bottom (full screen height), **360 px** wide,
`exclusiveZone: 0`, gated by `GlobalStates.sidebarRightOpen`, closed by
`HyprlandFocusGrab` click-out or Escape. Content is a 3 px `PixPanel` with 12 px
padding and an 11 px `ColumnLayout` gap. All sections are fixed height except the
notification list, which flex-grows.

Top to bottom:
1. **Header** (34 px) — left: a 2 px-bordered uptime chip, 30 px tall, `note` icon +
   "Up " + `DateTime.uptime` in bold 16, 10 px side padding. Right: four 38 × 34
   buttons with tooltips — `pencil` "Edit" (stub), `refresh` "Refresh" (stub), `gear`
   "Settings" (launches `settings.qml` and closes the panel), `power` "Power" (opens
   the session screen and closes the panel).
2. **Connectivity row A** (8 px gaps) — **Internet** tile (`wifi`, status = network
   name / "Connected" / "Not connected", active when Wi-Fi connected or ethernet;
   click opens the Wi-Fi overlay), **Bluetooth** tile (status from the toggle model;
   click opens the Bluetooth overlay), and a 44 × 46 `coffee` button = keep-awake
   (idle inhibitor).
3. **Row B** — a 44 × 46 `mic` button (filled while the source is unmuted), an
   **Audio output** tile (`speaker`, "Muted"/"Unmuted", click toggles mute), a
   **Night Light** tile (`moon`, "Active"/"Inactive").
4. **Row C** — five equal-width 38 px buttons: `nodes` Cloudflare WARP, `fullscreen`
   Game mode, `sliders` Easy Effects, `flashoff` Anti-flashbang, `dropper` Color
   picker. Each is filled while its toggle is on and has a left-anchored tooltip.
5. 2 px rule.
6. **Notifications** (flex-grows, min 60 px) — a scrolling list of one
   `PixNotifRow` per app group, 8 px apart; "No notifications" in grey 14 when empty.
7. **Footer** — 44 × 36 `bell` "Mark all read", a non-interactive full-width 36 px
   button reading "N notification(s)" in bold 14, and a 44 × 36 `trash` "Clear all".
8. 2 px rule.
9. **Calendar area** (`PixCalendar`), described below.

**`PixToggleTile`** — 2 px border, 46 px tall, 8 px padding, 9 px gap: a 30 × 30 icon
square (filled `fg` with a `bg` glyph when active, hollow otherwise) then a bold 14
title over a grey 12 status line, both elided. The whole tile is clickable and carries
a left-anchored tooltip.

**`PixNotifRow`** — a 34 × 34 hollow square with a 22 px grayscale app icon (fallback
`message`), 10 px gap, then a column: an 18 px title row of app name (bold 14, elided)
· relative time (grey 14) · and, for groups larger than one, a count chip (2 px border,
18 px tall, number + `chevD` at 9 px, inverting on hover, chevron rotating 180° in
110 ms when expanded). Collapsed, the row shows the latest summary in bold 14 and the
body in grey 14, both single-line elided; clicking expands a multi-item group or
dismisses a single notification. Expanded, it lists every notification newest-first
with summary (bold 14) + body (grey 14, wrapped, max 3 lines) and a 22 × 22 `trash`
button per entry.

**`PixCalendar`** — a left column of three 64 × 54 mini-buttons (`calendar` "CAL",
`todo` "TODO", `timer` "TIME"; icon 16 over a 9 px bold letter-spaced label; the
active one is filled) switching the 178 px-tall area on the right:
* **Calendar** — title row: `chevD` glyph, "MMMM yyyy" in Silkscreen 16 (elided), and
  two 30 × 28 month-nav buttons (`chevL`, `chevR`). Grid: 7 columns, a 22 px weekday
  header row (Mo–Su, grey 12), then 42 day cells of 26 px. Today is a 24 × 22 solid
  `fg` rectangle with bold `bg` text; out-of-month days are `grey2`; other days `fg`
  at 14 px.
* **To Do** — a scrolling list; each row is a 22 × 22 checkbox (filled with a `todo`
  glyph when done, hollow otherwise), the task text (14 px, grey when done, wrapped)
  and a 22 × 22 `trash` button. Bottom: a 26 px input box with an "Add task…"
  `grey2` placeholder and a 26 × 26 `pencil` add button. "No tasks" when empty.
* **Timer** — a pomodoro backed by `TimerService`: phase (`FOCUS` / `BREAK` /
  `LONG BREAK`, Silkscreen 14 grey) + "#cycle" (bold 14 grey), the remaining `MM:SS` in
  Silkscreen **48 px**, and two 96 × 34 buttons — START/PAUSE (filled while running)
  and RESET.

**Management overlays** — tapping Internet or Bluetooth covers the whole panel with an
opaque `bg` rectangle (inset by the 3 px border) plus a 34 px back bar (38 × 34
`chevL` button, then "INTERNET" / "DEVICES" in Silkscreen 16 at 50 px from the left)
and a 2 px-bordered manager panel filling the rest:
* **`PixWifiManager`** — 8 px padding, header row "WI-FI" + a 30 × 28 radio toggle
  (filled when enabled) + a 30 × 28 `refresh` (disabled while scanning), a 2 px rule,
  then a list of 40 px network rows 6 px apart. Each row: `wifi` icon 16, SSID (bold
  14) over status ("Connected" / "Connecting…" / "NN%"), and a `bolt` glyph at 12 px
  when the network is secured. The connected network is permanently filled. Click
  connects, or disconnects the active one. Empty state: "Scanning…" / "Wi-Fi off".
* **`PixBluetoothManager`** — same shell with "BLUETOOTH", a `bluetooth` radio toggle
  and `refresh` rescan. Rows show the device name over "Connected [- NN%]" / "Paired"
  / "Tap to connect"; connected devices are filled. Discovery is turned on while the
  panel is visible. Empty state: "Searching…" / "Bluetooth off".

### 4.4 Notification popups — `notificationPopup/` (see `notifications.html`)

An overlay `PanelWindow` on the focused screen anchored top+right+bottom, **380 px**
wide, visible only while `Notifications.popupList` is non-empty and the screen is not
locked. The window is click-through except over the toasts (region mask). The stack is
a column starting `barHeight + 12` = 58 px from the top, 12 px from the right, item
width 356 px, **10 px** apart.

Each toast (`PixelNotificationItem`) is a 3 px `PixPanel`, height =
`content + 22`, content inset 11 px, columns 11 px apart:
* a 34 × 34 hollow square with a 24 px grayscale app icon (fallback `message`),
  top-aligned;
* a header row: app name (bold 14, elided, fills width) + relative time in grey 14
  (`now` / `Nm` / `Nh` / `Nd`, refreshed every 30 s);
* the summary in bold 14, single line, elided;
* the body in grey 14, word-wrapped, max 2 lines, elided;
* one full-width 28 px `PixButton` per **labelled** action (2 px border, 14 px text),
  8 px apart, 4 px above. The unlabelled "default" action is never drawn.

Hovering cancels the service's auto-dismiss timer; clicking the toast invokes the
default action and dismisses it; clicking an action button invokes it and dismisses.

### 4.5 On-screen display — `onScreenDisplay/` (see `osd.html`)

A single overlay panel on the focused screen, horizontally centred, `barHeight + 14` =
60 px from the top (or bottom when the bar is bottom-anchored). Shown by volume or
brightness changes (bar scroll, media keys, IPC, global shortcuts) for
`Config.options.osd.timeout` (default 1000 ms); hovering it dismisses it immediately.
Region-masked to the panel.

3 px `PixPanel` sized `row + 28` × `row + 22`. Contents (row spacing 14):
* a 21 px glyph — `speaker` for volume, `flashoff` when muted, `sun` for brightness;
* a column (spacing 8) of a label row ("Volume" / "Brightness" bold 14, left, and the
  rounded percent bold 14, right) over a **discrete meter**: 20 cells of 9 × 16 with a
  2 px border, 3 px apart, filled solid `fg` up to `round(value * 20)`.

### 4.6 Overview / launcher — `overview/` (see `overview.html`)

One full-screen overlay `PanelWindow` per screen, gated by
`GlobalStates.overviewOpen`, with `HyprlandFocusGrab`; Escape or a scrim click closes
it, ←/→ switch workspaces when the search box is empty. The scrim is `bg` at 45 %
opacity. A centred column starts at **12 % of screen height**, 18 px between the two
widgets.

**Search (`PixelSearchWidget`)** — a 560 × 48 `PixPanel` (3 px border) with 12 px side
padding and 10 px spacing: a `puzzle` glyph at 21 px and a borderless text field at
16 px, placeholder "Search, calculate or run" in grey. Results hang directly beneath
in a second 3 px panel whose top border overlaps by −3 px (with a 3 px `line`
separator drawn across the seam), inner margin 6 px, capped at
`min(520, contentHeight + 12)`, rows 2 px apart.

Each row (`PixelSearchItem`) is `content + 12` tall with 12 px side padding and 10 px
spacing: an icon (28 px grayscale `PixAppIcon` for system icons; a `terminal` glyph for
Material-symbol entries, since the family has no symbol font; raw text for text icons
such as emoji; a 4 px spacer otherwise), then a column of the entry type in 12 px
(grey; hidden for apps) over the entry name at 14 px, and — only while
selected/hovered — the verb ("Open", "Run", "Search", …) in Silkscreen 12 on the right.
The active row inverts to a solid `line` fill with `bg` content; pressing turns it
`grey`. Typing anywhere routes into the field, Backspace edits, Ctrl+J/K move the
selection, Enter runs the current row. Data comes from the same `LauncherSearch`
singleton as the `ii` family, so app / run / math / clipboard / emoji / web-search /
action prefixes behave identically.

**Workspace exposé (`PixelOverviewWidget`)** — hidden while a query is typed. A 3 px
`PixPanel` with 12 px padding around a grid of `overview.rows × overview.columns`
(default **2 × 5**) tiles, 6 px apart. Each tile is
`monitorSize * overview.scale` (default 0.18 → 346 × 186 on 1920 × 1080) with a 2 px
`grey2` border and the workspace number centred in Silkscreen `grey2` at
`max(16, height * 0.4)`. Live `ScreencopyView` thumbnails of every window in the
current workspace group sit at their real scaled positions with a 1 px `line` border
(2 px plus a 12 % / 30 % white wash while hovered / pressed) and a centred grayscale
app icon at 40 % of the smaller side (70 % in compact mode). Windows on another
monitor render at 0.4 opacity. Hovering a thumbnail shows a tooltip of
`title\n[class]`. Left click focuses the window and closes the overview, middle click
closes it, dragging moves it to another workspace (`movetoworkspacesilent`) or
repositions a floating window (`movewindowpixel`); the drop-target tile lights up with
a 12 % wash and an `fg` border. Clicking an empty tile switches to that workspace. The
focused workspace is ringed by a **5 px** (`popupBorderWidth + 2`) `fg` border that
animates between cells in 110 ms.

### 4.7 Media controls — `mediaControls/` (see `media-controls.html`)

`PanelWindow` anchored **top-left**, `barHeight + 6` = 52 px down, flush with the left
edge, width **460**. The layer surface keeps a fixed height (`170 + 210` when lyrics
are enabled) to avoid resize flicker; only the inner card animates its height between
170 and 380 px over 300 ms `OutCubic`, clipping/revealing the lyrics. Masked to the
card, so the transparent remainder is click-through. `HyprlandFocusGrab` + Escape
close it. Gated by `GlobalStates.mediaControlsOpen`.

The card is a 3 px `PixPanel`. With no player it shows "No active player" in grey 16.

**Player area** (fixed 170 px, 14 px top margin, 16 px sides, 14 px gap):
* **Album art** — a 142 × 142 (`playerHeight − 28`) `PixPanel` with a 2 px border
  holding the cover image inset by the border, `PreserveAspectCrop`, unsmoothed and
  un-mipmapped. **This is the only colour in the entire shell.** Without art, a grey
  `note` glyph at 28 px.
* **Info column** (spacing 8): the cleaned track title in Silkscreen 16 (elided) with
  a 30 × 26 lyrics-toggle button (`message` glyph, filled while lyrics are shown);
  the artist in grey 14; a spacer; `elapsed / total` in grey 12; the **progress bar** —
  a row of 7 × 12 px cells 3 px apart, as many as fit, filled solid up to the play
  position (unfilled cells keep their 2 px border), clickable to seek, ticked once a
  second while playing; then transport controls (spacing 10): a 44 × 32 `chevL`
  previous, a full-width 32 px play/pause (two 4 × 14 bars when playing, a
  canvas-drawn triangle when paused), and a 44 × 32 `chevR` next.

**Lyrics (`PixLyricsView`)** — separated by a 2 px rule at y = 170, then 16 px side
margins. Synced lyrics scroll so the active line stays vertically centred (400 ms
`OutCubic`, suspended for 4 s after any manual scroll); the current line is bold 16 in
`fg`, past lines are `grey2` 14, upcoming lines are `grey` 14, 4 px apart, and clicking
a line seeks to it. Unsynced lyrics render as one wrapped grey block. Placeholders:
"Searching for lyrics…", "No lyrics", "Couldn't load lyrics", "Instrumental".

### 4.8 Displays overlay — `monitors/` (see `monitors.html`)

`PanelWindow` anchored top+left+bottom (full screen height), **380 px** wide,
`keyboardFocus: OnDemand`, gated by `GlobalStates.monitorsOpen`, closed by focus loss
or Escape. Keybind/IPC only — the bar has no button for it. A GUI over
**hyprdynamicmonitors**; every write goes through the `Monitors` service →
`hdm-control.py`.

3 px `PixPanel`, 12 px padding, 10 px gaps. Three screens: **main**, **profile
editor**, **settings** (the latter two cover the panel on an opaque `bg` backdrop).

**Main**
1. Header — "DISPLAYS" in Silkscreen 16, a 34 × 30 `refresh` (tooltip "Refresh") and a
   34 × 30 `gear` (tooltip "Settings & daemon").
2. Status row — a 14 × 14 square (filled when the HDM daemon is running) + "Daemon
   on/off" in grey 12; on the right, "Quick: <mode>" or "Active: <profile>" or
   "No profile", elided at 200 px.
3. 2 px rule, then a scrolling body:
   * **QUICK LAYOUT** (`QuickModeBar`) — three full-width 54 px buttons with an 18 px
     glyph over a 14 px label: `nodes` Extend, `swap` Mirror, `fullscreen` Single. With
     Single active, a wrapping chip row (30 px, 6 px gaps) picks which output stays on.
     With more than one screen, Extend adds **OTHER SCREENS GO** — four 52 px
     `ArrangePicker` buttons, each a two-square diagram (13 × 9; the filled square is
     the primary screen, stacked for Above/Below) over a 12 px label
     Right/Left/Above/Below. Extend and Mirror also expose **PRIMARY SCREEN** as a chip
     row. Any quick layout exposes **ZOOM** (`ZoomPicker`): one row per screen with the
     output name in grey 12 (56 px column) and five equal 28 px chips
     1 / 1.25 / 1.5 / 1.75 / 2×; steps that would not divide the resolution into whole
     logical pixels are drawn at 0.3 opacity and disabled. Finally a full-width 38 px
     **"Auto (my profiles)"** button (`refresh` glyph) that clears the quick override;
     it is filled while no quick mode is active.
   * **CONNECTED (n)** — a `MonitorCard` per output: 2 px border, 8 px padding, a
     30 × 30 square (filled with a `bg` `fullscreen` glyph when the output is enabled)
     then `name · description` in bold 14 over `WIDTH×HEIGHT@Hz   x,y   Nx` in grey 12,
     plus `mirror→NAME` when mirroring, or just "Disabled".
   * **PROFILES** — the section label with a "+ New" button (28 px), then a
     `ProfileRow` per profile: 2 px border, 7 px padding, a 16 × 16 marker square
     (filled = the profile HDM currently has active), the profile name in bold 14 with
     "  · active" / "  · disabled" suffixes, a grey 12 line summarising the required
     monitors (`~` prefix for regex, joined by "+") and conditions in brackets, and a
     grey `chevR`. Disabled profiles render at 0.45 opacity. The whole row opens the
     editor. Empty state: "No profiles yet — tap + New or use a quick layout".
4. Status line — "Working…" while busy, otherwise `Monitors.lastMessage` (in `fg`
   rather than grey when the last operation failed).

**Profile editor (`ProfileEditor`)** — scrolling, 10 px gaps: a back bar (34 × 30
`chevL`, the profile name uppercased in Silkscreen 16, a filled 58 × 30 "Save");
**NAME** field (read-only for existing profiles); **TYPE** segment Template/Static; a
full-width 34 px button that toggles "capture current layout" for new profiles or
applies the live layout to an existing one; **REQUIRED MONITORS** with a 30 × 26 "+"
and, per entry, a 150 px Name/Desc segment, a 40 × 30 `.*` regex toggle (tooltip
"Match with a regular expression"), a 34 × 30 `trash`, and the value field below
(placeholder "connector, e.g. DP-1" / "description, e.g. Dell U2720Q"); a wrapping
row of "+ NAME" chips (26 px) to add a connected monitor; **CONDITIONS** — Power
(Any/AC/Battery) and Lid (Any/Open/Closed) segments with a 42 px label column;
**TEMPLATE VALUES** — key/value field pairs (110 px key) with per-row `trash`; and for
existing profiles a row of Disable/Enable, two 40 × 32 reorder buttons (`chevL`/`chevR`
rotated 90°, tooltips "Higher in file (lower priority on ties)" / "Lower in file (wins
ties)") and a `trash`. Removal opens a full-cover confirmation: "REMOVE PROFILE" in
Silkscreen, an explanatory line, a toggle "also delete its template file", then Cancel
and a filled Remove.

**Settings (`SettingsScreen`)** — back bar + "SETTINGS"; **DAEMON** status square and
three equal 32 px buttons Validate / Reapply / Reload; **PROFILE SCORING** with an
explanatory grey 12 paragraph and four `StepperRow`s (Name match, Description match,
Power state match, Lid state match) plus "Apply scoring"; **NOTIFICATIONS** — a filled
toggle button "✓ Desktop notifications on profile switch", a Timeout (ms) stepper
(step 1000, max 60000) and "Apply notifications"; **INFO** — read-only destination path
and debounce, grey 12.

### 4.9 Session screen — `sessionScreen/` (see `session-screen.html`)

A full-screen, keyboard-exclusive overlay on the focused screen, gated by
`GlobalStates.sessionOpen`. Scrim: `bg` at **0.82** opacity (0.86 light); clicking it
cancels. Centred column, 26 px gaps:
1. "SESSION" in Silkscreen 24.
2. A row of six **132 × 132** tiles, 18 px apart, each a 3 px-bordered `PixButton`
   with an opaque `bg` backing so the scrim never shows through: the number
   accelerator in the top-left corner (12 px, grey until selected, 7 px top / 8 px left
   margin), then a 42 px glyph over a Silkscreen 14 label, 14 px apart. Actions in
   order: **Lock** (`gear`, 1), **Logout** (`swap`, 2), **Suspend** (`moon`, 3),
   **Hibernate** (`snow`, 4), **Reboot** (`refresh`, 5), **Shutdown** (`power`, 6) —
   the glyphs are substitutes, the 7×7 set has no lock or logout icon. The selected
   tile is fully inverted.
3. Hint line in grey 14: "Arrows or 1-6 to choose, Enter to confirm — Esc or click
   anywhere to cancel".
4. Session warnings as filled chips (`label + 28` × `label + 14`) in 12 px: "Your
   package manager is running", "There might be a download in progress".

Keys: ←/→/↑/↓/Tab move, Home/End jump, Enter/Space run, 1–6 select and run
immediately, Escape cancels. Hover also moves the selection.

### 4.10 Worktrees dialog — `worktrees/` (see `worktrees.html`)

A centred modal on the focused screen, keyboard-exclusive so the name field is
typeable immediately, over the same 0.82/0.86 `bg` scrim; Escape or a scrim click
closes it. Gated by `GlobalStates.worktreesOpen`; keybind/IPC only. The panel is a 3 px
`PixPanel` **440 px** wide, 14 px padding, 10 px gaps, height capped at 900 px.

Sections top to bottom:
1. "NEW WORKTREE" in Silkscreen 16 + a 34 × 30 "ESC" button; 2 px rule.
2. **TASK NAME** label (bold grey 12) + a `PixField`; a grey validation line
   "letters, digits, . _ - only" when the name fails `[A-Za-z0-9._-]+`.
3. **REPOS** label with the base branch on the right in `grey2` 12 ("from
   main@origin"). One `RepoRow` per discovered repo: a 2 px border that switches from
   `line` to `fg` when selected, 8 px padding, a 22 × 22 filled/hollow checkbox, the
   repo name in bold 14, and "N srv" in grey 12; when selected, a 3-column grid of
   26 px server chips (filled when picked) or the grey2 note "no vitulina servers —
   gets a shell tab". Clicking anywhere on the row toggles the repo. Empty state:
   "No git repos found in ~/pleevi". Below, a grey line naming repos that need
   `jj git init --colocate` first.
4. 2 px rule, then a **SUMMARY** key/value grid (12 px, keys in `grey2`): PATH
   (`~/pleevi/<name>`), BOOKMARK, ENV (`vitulina up --env <name>`), SETUP ("jj
   workspace, copy .env, direnv allow" + "pnpm i (…)" for node repos), TABS (total
   count and breakdown: shell, claude, N vitulina, N repo).
5. **Actions** — a full-width 34 px CREATE (bold 14; reads "WORKING…" while busy;
   non-interactive with `grey2` text until the name is valid and at least one repo is
   ticked) and an 84 × 34 CANCEL.
6. 2 px rule, **REOPEN** label with "N task(s)" in `grey2` on the right, then a
   scrolling list (max 150 px) of `TaskRow`s — full-width 32 px fill-on-hover buttons
   showing the task name (bold 14, max 170 px), the repos joined by commas, and
   "N tabs". Empty state: "No task folders in ~/pleevi yet".
7. **Log box** — a 2 px-bordered scrolling area (max 120 px) with the script output in
   grey 12, auto-scrolled to the bottom; on failure the border and the text switch to
   plain `fg`.

---

## 5. Behavioural notes a redesign must preserve

* **Open-state flags** (`GlobalStates`): `barOpen`, `screenLocked`,
  `sidebarRightOpen`, `overviewOpen`, `sessionOpen`, `mediaControlsOpen`,
  `monitorsOpen`, `worktreesOpen`, `osdVolumeOpen`, `osdBrightnessOpen`.
* **IPC targets / shortcut names are shared with the `ii` family** so the user's
  existing keybinds work: `sidebarRight`, `search`, `session`, `mediaControls`,
  `monitors`, `worktrees`, `pixelOsdVolume`, `pixelOsdBrightness`.
* Panels that must survive a focus grab (quick settings, monitors) keep their
  `PanelWindow` alive and toggle `visible`; creating them on demand breaks click-out
  closing.
* Hover popups are separate overlay windows; tooltips use an empty input region so
  they never steal hover.
* The media controls' surface height is fixed and only the inner card animates —
  resizing a layer surface flickers.

## 6. Known gaps in the current implementation

* The bar's tray-cluster status glyphs (idle inhibitor, Wi-Fi, Bluetooth) are coded
  but `visible: false`.
* Quick-settings header "Edit" and "Refresh" buttons are stubs.
* `MonitorCard.editable` is a phase-2 hook and unused.
* `PixelSearchItem` has no Material-symbol font, so those results fall back to a
  single `terminal` glyph.
* `CONTRACT.md` / `README.md` / `design/*.html` inside `modules/pixel/` describe an
  older token set (Pixelify Sans body font; type scale 10/11/12/13/14/15/16/20).
