# `paper` panel family — API contract

**Status: complete and integrated.** All ten surfaces are implemented, the
widget set is built and shared, and the tree has been consolidated. Nothing here
is owned by a particular agent any more — **every widget in
`modules/paper/widgets/` is shared, and any surface may extend one.** If you
change a widget, re-render the affected call sites (§8) before you trust it.

Read this file, then the doc comment at the top of the file you are changing,
then the SPEC for the surface.

**Read in this order**

1. `design/current-pixels/SPEC.md` — the behavioural contract. Every surface,
   its data, its interactions. **Unchanged** by the paper redesign.
2. `design/paper-a-hairline/SPEC.md` — variant `hairline`
3. `design/paper-b-ledger/SPEC.md` — variant `ledger`
4. `design/paper-c-broadsheet/SPEC.md` — variant `broadsheet`
   …each with `widgets.html` / `tokens.html` / `<surface>.html` previews next to
   it, rendered at real proportions with realistic data. Open the one for your
   surface; they are the spec, not decoration.

---

## 0. The one rule

**One module tree, one panel family, three variants.** There is no `paper-a`
module. `Config.options.paper.variant ∈ {"hairline","ledger","broadsheet"}`
selects the design, it is persisted, and it is switchable **live at runtime**.

Therefore: **every piece of styling must flow through a binding on
`PaperTheme`.** Never snapshot a token into a plain `var`, never compute a
palette in `Component.onCompleted`, never `if (variant === …) createObject(…)`.
A variant change must restyle the running shell without a reload. The harness
that validated this foundation switched all three variants and both dark modes
against one live object tree; keep that property.

---

## 1. The tree

```
modules/paper/
  HANDOFF.md                        ← this file
  common/
    PaperTheme.qml                  singleton: variant, palettes, type, metrics, motion
    PaperPlates.qml                 singleton: the desktop plate of the day
    paper_icons_data.js             87 glyphs × 3 variants (generated)
    paper_plates_data.js            backdrop plate catalog (generated)
  widgets/                          26 shared widgets — see §3
  background/PaperBackground.qml    paper ground + the plate of the day
  bar/                  PaperBar.qml + BarBatteryChip BarBatteryPopup BarClock
                        BarClockPopup BarColumnHead BarControlButton BarDivider
                        BarPopup BarStats BarSystemMonitorPopup BarTray
                        BarTrayItem BarValueRow BarWorkspaces
  quickSettings/        PaperQuickSettings.qml + PaperQuickSettingsContent
                        QsAudioManager QsBluetoothManager QsCalendarArea
                        QsTimerView QsTodoView QsToggleTile QsWifiManager
  notificationPopup/    PaperNotificationPopup.qml + NotifToast
  onScreenDisplay/      PaperOnScreenDisplay.qml + OsdPanel
  overview/             PaperOverview.qml + OvExpose OvSearchRow OvSearchWidget
                        OvWindowThumbnail
  mediaControls/        PaperMediaControls.qml + MediaLyricsView
  monitors/             PaperMonitors.qml + PaperMonitorsContent MonMonitorChips
                        MonMonitorRow MonProfileEditor MonProfileRow
                        MonQuickLayout MonSettingsScreen MonZoomPicker
  sessionScreen/        PaperSessionScreen.qml + SessionColumn SessionTile
                        SessionWarning
  worktrees/            PaperWorktrees.qml + PaperWorktreesContent WtRepoRow
                        WtTaskRow

assets/fonts/  Inter-{Light,Regular,Medium}.ttf, XCharter-{Roman,Bold,Italic}.otf
assets/images/paper-grain.png       140 px noise tile, shared by every surface
assets/images/paper-plates/*.png    the backdrop collection — see §11
scripts/paper/extract_icons.py      regenerates paper_icons_data.js from the previews
scripts/paper/fetch_plates.py       regenerates the plates + paper_plates_data.js
modules/common/Config.qml           + Config.options.paper.variant
shell.qml                           + paper family, IpcHandler "paperVariant",
                                      GlobalShortcut "paperVariantCycle"
```

The ten components `shell.qml` instantiates are exactly `PaperBar`,
`PaperQuickSettings`, `PaperNotificationPopup`, `PaperOnScreenDisplay`,
`PaperOverview`, `PaperMediaControls`, `PaperMonitors`, `PaperSessionScreen`,
`PaperWorktrees`, `PaperBackground`. Each is a `Scope` holding its own windows.
A file prefixed with its surface group (`Bar…`, `Qs…`, `Ov…`, `Mon…`,
`Session…`, `Wt…`, `Media…`, `Notif…`, `Osd…`) is **surface-local by
convention**; anything shared lives in `widgets/` with a `Paper` prefix.

**There are no `qmldir` files.** The repo has none anywhere — Quickshell scans
the config directory and generates them itself, so `import qs.modules.paper.common`
and `import qs.modules.paper.widgets` just work, and `pragma Singleton` is all
`PaperTheme` needs. Do not add qmldir files; you will fight the generator.

---

## 2. Tokens — `import qs.modules.paper.common`

### 2.1 Variant

| API | Meaning |
|---|---|
| `PaperTheme.variant` | `"hairline"` / `"ledger"` / `"broadsheet"` |
| `PaperTheme.isHairline` / `.isLedger` / `.isBroadsheet` | structural branching |
| `PaperTheme.dark` | follows `Appearance.m3colors.darkmode` |
| `PaperTheme.pick(a, b, c)` | per-variant value: `pick(hairline, ledger, broadsheet)` |
| `PaperTheme.cycleVariant()` / `.setVariant(name)` / `.variants` | switching |

`pick()` is a *function called from a binding*, and QML tracks the dependency on
`variant` through it. Use it for numbers and layout:

```qml
implicitHeight: PaperTheme.pick(56, 42, 48)
columns: PaperTheme.isHairline ? 1 : 3
```

### 2.2 Colour — flat, resolved for variant + dark mode

Ground: `paper` `paperRaise` `paperSunk` `paperEdge` `wash` `wash2`
Ink: `ink` `ink2` `ink3` `ink4`
Rules: `rule` `rule2`
Accent: `accent` `accentSoft` `accentWash` `onAccent`
Connected: `link` `linkWash`
Failure: `alert` `alertSoft` `alertWash`
Stamp: `seal` `sealWash`
Other: `selection` `scrim` (overview) `scrim2` (session, worktrees)

Every token exists in every variant, which is the point — you never have to ask
"does this variant have an accent wash?". What differs is what they resolve to:

* **hairline** has no hue for "on": `accent == ink`, `accentWash == wash`,
  `link == accent`, `alertWash == transparent`, `seal == ink3`,
  `paperRaise == paper`.
* **ledger** `accent == link ==` ink blue, `alert == seal ==` stamp red,
  `paperRaise` is a genuinely raised sheet, `paperSunk` is *darker* than the card
  in dusk.
* **broadsheet** `accent == alert ==` oxblood, `link ==` ink blue,
  `seal ==` sepia (warning), `paperRaise == paper`.

`PaperTheme.palette` exposes the whole active palette object if you need to pass
one around. Do not read `pHairlineLight` and friends directly.

**Accent policy, hairline (§2.2 of its SPEC).** `alert` is permitted on *only*:
battery ≤ 15 %, a failed daemon/script operation, an urgent notification's dot,
the two session warnings, a failed field, and the confirming verb of a
destructive confirmation. It is **never** "on", "active", "selected",
"connected", "focused", "playing" or "primary". Those are ink weight, underlines
and dots. The other two variants are looser but still ration colour hard.

### 2.3 Type

Faces: `fontSans` `fontSerif` `fontMono` and the role aliases `fontBody`
`fontTitle` `fontFigure` `fontFootnote`.

| variant | body | title | figures | footnote |
|---|---|---|---|---|
| hairline | Inter | Inter (micro-caps) | JetBrains Mono | Inter |
| ledger | Adwaita Sans | XCharter | Source Code Pro | Adwaita Sans |
| broadsheet | Lato | TeX Gyre Pagella | Pagella `onum tnum` | Pagella *italic* |

Sizes — `PaperTheme.font.size.*`: `micro` 10 · `meta` 11 · `small` 12 ·
`body` 13 · `lead` 15/14/15 · `title` 18/16/17 · `headline` 20/20/21 ·
`display` 24/30/26 · `folio` 40/40/46.

Weights — `PaperTheme.font.weight.{light,normal,medium,bold,title}`. Note
**hairline has no bold**: its `bold` resolves to Medium. Emphasis there is ink
weight and case, never weight.

Features — `PaperTheme.font.features.{figures,lining,smallCaps,none}`. Put
`figures` on **every** numeral run or the bar clock and the stat column jitter.
`PaperTheme.titleIsSmallCaps` and `.italicPlaceholders` are the two structural
type switches.

Tracking — `PaperTheme.tracking(em, pixelSize)`, plus
`PaperTheme.font.trackingEm.{micro,display}` and the ready-made
`font.microLetterSpacing`.

In practice **you should almost never set a font by hand** — use `PaperText`
and `PaperTitle` (§3).

### 2.4 Rules, radii, ornament

`ruleWidth` 1 · `markWidth` 1/2/2 (the selection mark) · `changeBarWidth` and
`changeBarIndent` (the selected-row left gutter) · `oxfordThick` 2 · `ruleGap` 1.

`radiusControl` 0/2/2 · `radiusSheet` 0/3/0 · `radiusCard` 0/2/0 ·
`radiusPill` 0/0/999 (broadsheet medallions).

`PaperTheme.ornament.*` — **branch on these, not on `variant`**, whenever the
question is "does this variant do X":

| token | h | l | b | meaning |
|---|---|---|---|---|
| `grain` / `grainOpacity` | – | ✓ | ✓ | the shared noise tile |
| `shadow` | – | ✓ | ✓ | floating surfaces take a whisper of shadow |
| `cornerTicks` | – | – | ✓ | 6 px L-ticks on a floating sheet |
| `doubleRules` / `oxfordRules` | – | – | ✓ | block close / masthead |
| `stamps` / `stampRotation` | – | ✓ | ✓ | PaperStamp draws a real stamp |
| `dottedLeaders` | – | ✓ | – | PaperKV's key···value leader |
| `meterTicks` / `meterHead` | –/✓ | ✓/– | ✓/– | ruler ticks vs. head dot |
| `dottedDisabled` | – | – | ✓ | dotted rule instead of an opacity drop |
| `framedControls` | – | ✓ | ✓ | a control draws a frame at rest |
| `tintedFills` | – | ✓ | ✓ | a tinted fill may say "on" |

`PaperTheme.shadow.{color,radius,verticalOffset}` if you build your own shadow.

`PaperTheme.backdrop.*` styles the desktop picture (§11): `plateOpacity`
0.34/0.38/0.42 light, 0.58/0.62/0.66 dusk (dusk costs more: ink on a near-black
ground can never exceed `opacity × ink`) · `plateInk` = `ink`, except broadsheet
which inks its plate in `seal` sepia like the rest of its ornament ·
`deskRuling` / `deskRulingPitch` (22) — broadsheet's desk ruling, which
`PaperBackground` drops while a plate hangs.

### 2.5 Spacing and sizes

`PaperTheme.spacing.{hair,tiny,xs,small,sm,medium,large,xl,xxl,huge}` = 2 4 6 8
10 12 16 20 24 32.

`PaperTheme.pad.{sheet,panel,card,bar,dialog}` and
`PaperTheme.gap.{section,row,icon,value,chip,tile}` are the per-variant presets.
**Hairline pads roughly twice as much as the others** — whitespace is what it
substitutes for the borders it removed. Use the presets rather than literals so
that difference lands automatically.

`PaperTheme.barHeight` (38/34/42) and `PaperTheme.barPopupOffset` (barHeight + 8/6/6).

`PaperTheme.size.*`: `quickSettings` `monitors` `notificationWindow` `toast`
`toastGap` `toastTop` `mediaWidth` `mediaCollapsed` `mediaExpanded` `albumArt`
`searchWidth` `searchResultsMax` `worktrees` `worktreesMax` `osdWidth`
`osdHeight` `osdTop` `sessionTile` `sessionGap` `workspaceCellWidth`
`workspaceCellHeight` `workspaceGap` `button` `iconButton` `field` `listRow`
`toggleRow` `chip` `dot`.

### 2.6 Icons and app icons

`PaperTheme.icon.{stroke,strokeLarge,strokeLargeAbove,roundCaps,tiny,row,control,large,session,tray}`.
`PaperTheme.appIcon.{desaturation,contrast,tint,tintStrength,plate}`.

### 2.7 Motion

`PaperTheme.motion.{fast,base,slow,card,scroll,scrollSuspend,maxTravel,type,bezierCurve,exitBezierCurve}`.

```qml
Behavior on color {
    ColorAnimation {
        duration: PaperTheme.motion.base
        easing.type: PaperTheme.motion.type
        easing.bezierCurve: PaperTheme.motion.bezierCurve
    }
}
```

`maxTravel` is 4 px and it is a **hard ceiling in all three variants**. Nothing
slides further than 4 px, nothing scales, nothing bounces, nothing blurs. The
largest movement permitted in the shell is a selection mark growing from 0 to
2 px in 140 ms.

`PaperTheme.tooltip.{showDelay,hideDebounce,gap}` — 350 / 120 / 10–14.

---

## 3. Widgets — `import qs.modules.paper.widgets`

Uniform API, variant-aware internals. **Reach for a widget before you reach for
`isHairline`.** They already encode the three specs' disagreements; a surface
that branches on the variant to restyle a button is doing the widget's job
badly.

### `PaperText` — body text (replaces `PixText`)
```qml
PaperText { text: "Internet" }                               // body / ink
PaperText { role: "micro"; text: "Connectivity" }            // section label, auto-UPPERCASED + tracked
PaperText { role: "meta"; tone: "ink3"; text: "2 m" }
PaperText { mono: true; role: "meta"; text: "3840×2160@60" }
PaperText { figure: true; role: "title"; text: "21:48" }     // tabular/oldstyle numerals
PaperText { footnote: true; tone: "ink4"; text: "No lyrics" } // italic in broadsheet
PaperText { struck: true; tone: "ink4"; text: "done task" }
```
`role` ∈ micro meta small body lead title headline display folio ·
`tone` ∈ ink ink2 ink3 ink4 accent accentSoft link alert seal onAccent (defaults
per role) · `mono` `figure` `footnote` `struck`. It is a `Text`, so `elide`,
`wrapMode`, `maximumLineCount` and even `font.pixelSize` still work.

**Use `figure: true` for every number the eye compares.** Use `role: "micro"` for
every section label, verb, chip, accelerator and app name.

### `PaperTitle` — a title (replaces `PixTitle`)
```qml
PaperTitle { text: "Displays" }                    // micro-caps in A, Charter 16 in B, Pagella smallcaps 17 in C
PaperTitle { role: "display"; text: "Session" }    // the masthead
```

### `PaperRule` — the hairline
```qml
PaperRule { width: parent.width }                     // 1 px `rule`
PaperRule { width: parent.width; weight: "fine" }     // 1 px `rule2` — aimable
PaperRule { width: parent.width; weight: "double" }   // closes a block (single rule in A/B)
PaperRule { width: parent.width; weight: "oxford" }   // a masthead (single rule in A/B)
PaperRule { width: 120; weight: "mark"; tone: "accent" }   // the selection underline
PaperRule { vertical: true; length: 14 }              // bar divider
PaperRule { width: 80; dotted: true }                 // broadsheet's disabled edge
PaperRule { weight: "oxford"; colorOverride: PaperTheme.paper }  // on a dark scrim
```
`double` and `oxford` degrade to a plain hairline where the variant has no such
ornament, so **write `weight: "oxford"` for your masthead unconditionally**.

`weight` `tone` `vertical` `length` `dotted` · `colorOverride` /
`secondaryColorOverride`. The Oxford weight hardcodes `ink` for its thick half,
which is right on paper and wrong on a scrim — `colorOverride` is the escape
hatch for exactly that case (the session screen's masthead) and nothing else.
`null` keeps the palette colour, so ordinary call sites never touch it.

### `PaperPanel` — the container (replaces `PixPanel`)
Not a window. Build your own `PanelWindow` and put this inside it.
```qml
PaperPanel { anchors.fill: parent; floating: true; ticks: true }     // a popup / toast
PaperPanel { anchors.fill: parent; edgeRight: false }                 // right-docked sidebar
PaperPanel { kind: "card" }                                          // inline card (draws NOTHING in hairline)
PaperPanel { kind: "well" }                                          // recessed log box
PaperPanel { edgeTop: false; edgeLeft: false; edgeRight: false
             bottomWeight: "oxford" }                                // the bar
```
`kind` ∈ sheet card well · `floating` (shadow, ledger/broadsheet only) · `ticks`
(broadsheet) · `tickColor` · `edgeTop/Bottom/Left/Right` · `edgeWeight` /
`bottomWeight` · `frameTone` (an active card, a failed log box) · `grain`.

`tickColor` defaults to `rule2` — the resting tick that says "this floats". A
**selected** sheet ticks in `accent` instead (`ticks: selected; tickColor:
PaperTheme.accent` — that is how the session tile marks its choice). `ticks` is
already gated on `ornament.cornerTicks` inside the widget, so you never have to
ask whether the variant has them.

Docked panels get **no** shadow — only the edge rule against the screen edge.
Drop the border on any edge that meets a screen edge.

### `PaperButton` (replaces `PixButton`)
```qml
PaperButton { label: "Validate"; onClicked: Monitors.validate() }
PaperButton { label: "Extend"; checked: true }
PaperButton { label: "Save"; primary: true }              // at most ONE per surface
PaperButton { label: "Remove"; destructive: true }
PaperButton { label: "Reapply"; enabled: false }
PaperButton { shape: "text"; label: "Mark all read" }
PaperButton { shape: "icon"; icon: "refresh"; PaperTooltip { text: "Refresh" } }
PaperButton { shape: "stacked"; icon: "nodes"; label: "Extend"; checked: true }
PaperButton { label: "Connected"; checked: true; connected: true }   // uses `link`
```
`shape` ∈ caps text icon stacked · `checked` `primary` `destructive` `connected`
`ghost` · disabled via the inherited `enabled`. Read `contentColor` /
`hovered` / `pressed` from outside; add children and bind their colour to
`contentColor`.

In hairline there is no box: the button IS its label, and "on" is a 1 px ink
underline that grows from the left in 140 ms. That underline **tracks the
content, not the item** — a button stretched to a container's full width still
underlines its (centred) label rather than a strip of empty paper. So a
full-width `Layout.fillWidth` button is safe; you do not need the
natural-width-plus-spacers dance.

### `PaperSwitch`
```qml
PaperSwitch { checked: !Audio.sink?.audio?.muted; onToggled: Audio.toggleMute() }
```
The **caller owns the state** — the switch does not flip itself, because every
real toggle here is a round-trip through a service.

### `PaperCheck`
```qml
PaperCheck { checked: item.done; onToggled: Todo.markDone(index) }
```
A ring→dot in hairline, the ledger tick in ledger, an oxblood check in broadsheet.

### `PaperMeter` (replaces the 20-cell bar and the 7-cell progress bar)
```qml
PaperMeter { width: 200; value: volume }
PaperMeter { width: 200; value: pos / len; interactive: true; onSeek: v => player.position = v * len }
PaperMeter { width: 200; value: 0.92; alert: true }
PaperMeter { width: 120; value: 0.4; dense: true }        // narrow popup columns
```
`value` 0..1 · `interactive` (seek + accent fill) · `alert` · `dense` · `ticks`.
Hairline draws a 1 px track with a 4 px head dot; ledger a ruler with 21 ticks;
broadsheet a rule gauge. A **muted** OSD should set `value: 0` so the track reads
empty rather than zeroed.

### `PaperField` (replaces `PixField`)
```qml
PaperField {
    width: parent.width
    label: "Task name"
    placeholder: "hairline-theme"
    invalid: !nameValid
    invalidMessage: "letters, digits, . _ - only"
    onEdited: t => name = t
    onAccepted: create()
}
PaperField { width: parent.width; borderless: true; icon: "search"
             placeholder: "Search, calculate or run" }
PaperField { label: "Name"; readOnly: true; hint: "read-only for existing profiles" }
```
`text` `label` `placeholder` `icon` `numeric` `readOnly` `invalid`
`invalidMessage` `hint` `borderless` · `focusInput()` `clear()` · `focused`.
Call `focusInput()` — the panels that host fields use
`WlrKeyboardFocus.OnDemand`, which is what makes typing work.

### `PaperKV` — key/value
```qml
PaperKV { width: parent.width; key: "Path"; value: "~/pleevi/x" }
PaperKV { width: parent.width; key: "Uptime"; value: DateTime.uptime; figure: true }
```
The dotted leader appears in ledger only; hairline and broadsheet degrade to
whitespace / a fixed 74 px key column, which is exactly what their SPECs ask
for. Give it an explicit `width`.

### `PaperStamp`
```qml
PaperStamp { text: "Charging"; icon: "bolt" }
PaperStamp { text: "Daemon on"; tone: "link" }
PaperStamp { text: "Download in progress"; tone: "alert" }
```
`tone` ∈ seal accent link alert. In hairline it renders as plain micro-caps text
with no frame, fill or rotation — so use it unconditionally.

### `PaperTooltip`
```qml
PaperButton { shape: "icon"; icon: "gear"; PaperTooltip { text: "Settings" } }
MouseArea { hoverEnabled: true; PaperTooltip { text: "Media controls"; subtext: "[kitty]" } }
PaperTooltip { text: "Colour picker"; anchorEdges: Edges.Left; anchorGravity: Edges.Left }
```
A **child** of the control. Visibility follows the parent's `containsMouse` or
`hovered`; override `visibleCondition` for anything else. It escapes the parent
window through a `PopupWindow` with an **empty input region**, so it can never
steal hover.

### `PaperIcon`
```qml
PaperIcon { name: "wifi" }                                  // 16 px, ink2
PaperIcon { name: "power"; size: PaperTheme.icon.session; color: PaperTheme.accent }
PaperIcon { name: "gear"; variantOverride: "broadsheet" }    // rarely needed
```
Set `size`, never `scale` or `width`/`height` — the widget divides the stroke by
its own scale factor so the **apparent stroke is a constant 1.25 px at every
optical size** (1.4 above 26 px in broadsheet). That constant pen is the single
most characteristic rule of the family.

### `PaperAppIcon` (replaces `PixAppIcon`)
```qml
PaperAppIcon { icon: trayItem.icon; size: PaperTheme.icon.tray; plate: false }
PaperAppIcon { icon: appClass; size: 16; fallbackIcon: "message" }   // notifications
PaperAppIcon { icon: appClass; size: 20; plateSize: 32 }             // an absolute plate
```
`icon` (theme name) or `source` (explicit url; `source` wins) · `size` · `plate`
· `plateSize` · `fallbackIcon` / `fallbackColor`.

Desaturates, and (hairline / broadsheet) multiplies toward `ink2`.
`plateSize` defaults to the glyph plus the variant's own margin (+0/8/10); set
it when a SPEC gives the plate an **absolute** size instead — notifications
specify 28 px in hairline and 32 px in the other two. Do not override
`implicitWidth`/`implicitHeight` to get there; that decouples the plate from the
glyph it is supposed to contain.

**Album art is not this widget** — cover art is the one place full colour is
allowed in the whole shell; render it with a plain `Image` inside a framed well.

### The composites — all built, all shared

Twelve more widgets live beside the primitives. They are thin compositions of
them, and they encode the three SPECs' disagreements so a surface does not have
to.

#### `PaperSectionHeader` — the **only** heading device in all three variants
```qml
PaperSectionHeader { width: parent.width; label: "Connectivity" }
PaperSectionHeader { width: parent.width; label: "Notifications"; meta: "5" }
PaperSectionHeader { width: parent.width; label: "Profiles"        // a control in the slot
                     PaperButton { shape: "text"; label: "Reload" } }
```
`label` (uppercased by the micro role) · `meta` (the right-hand cut-in: a count,
"3 open") · `rule` · `ruleWeight` · children go into the trailing slot after the
meta. The cut-in is **`meta:`** — an earlier draft called it `note:`; nothing
should still say `note`.

The inline rule defaults to `!isBroadsheet`, because broadsheet separates blocks
with a rule **above** the header rather than through it. Write
`PaperRule { weight: "double" }` before the header and it degrades correctly in
the two variants that have no double rule.

Used dozens of times. When it is a *column* head in a table — ruled **under**
itself — see `bar/BarColumnHead` instead, and read the promotion note below.

#### `PaperListRow` — a row in a list
```qml
PaperListRow {
    width: parent.width
    icon: "wifi"; title: net.ssid; subtitle: "Connected"
    on: net.active; connected: true
    separator: index > 0
    onActivated: Network.connectToWifiNetwork(net)
    PaperIcon { name: "lock"; size: 12; color: PaperTheme.ink4 }   // trailing slot
}
```
`icon` / `iconSize` · `title` / `subtitle` · `titleRole` / `subtitleRole` ·
`on` · `selected` · `connected` · `dotColumn` / `dotFilled` · `separator` ·
`interactive` · `minHeight` · `tooltip` · signals `activated` / `rightActivated`
· default slot = trailing.

Two things to know before you reach for it: the **separator draws ABOVE the
row** (pass `index > 0`, never `index < count - 1`), and **selection animates a
`changeBarIndent`** — the content slides in by the change bar's width. That is
right for a pointer-driven settings list and wrong for anything a keyboard
cursor races down; the launcher's `OvSearchRow` is separate for that reason
among others.

`on` = "this row's subject is active"; `selected` = "this row is the current
one". They render almost identically on purpose — the family has one selection
mark.

#### `PaperToggleRow` — a settings row that carries its own state
```qml
PaperToggleRow {
    width: parent.width
    icon: "coffee"; title: "Keep awake"; status: idle.toggled ? "Idle inhibited" : "Idle allowed"
    on: idle.toggled; tooltip: "Keep system awake"
    onToggled: idle.mainAction()
}
PaperToggleRow { icon: "wifi"; title: "Internet"; status: Network.networkName
                 on: connected; control: "chevron"; onActivated: overlay = "wifi" }
```
Extends `PaperListRow`, so it inherits everything above. Adds `control` ∈
switch | chevron | none, `status` (an alias of `subtitle`, spelled the way the
SPECs spell it) and the `toggled` signal. Height is `size.toggleRow`.

A **switch** row fires `toggled` from a click anywhere on the band; a
**chevron** row fires `activated`, because it navigates. The switch never flips
itself — `on` is the caller's state.

#### `PaperTabs` — a mode switcher, in two shapes
```qml
PaperTabs {
    width: parent.width
    orientation: PaperTheme.isHairline ? "horizontal" : "vertical"
    model: [{ key: "calendar", label: "Calendar", icon: "calendar" }, …]
    current: view
    onSelected: key => view = key
}
```
`model` = `[{ key, label, icon?, tip? }]` · `current` · `orientation` ·
`underline` · `tabWidth` / `tabHeight` · signal `selected(key)`.

Horizontal = micro-caps labels over ONE continuous hairline, the active tab
owning the pixel above it. Vertical = a left stack of 58 px glyph-over-caps
`PaperButton { shape: "stacked" }`. Selection is the caller's state.

#### `PaperNotifRow` — one notification GROUP in a list
```qml
PaperNotifRow {
    width: list.width
    group: Notifications.groupsByAppName[appName]
    separator: index > 0
    onDismiss: id => Notifications.discardNotification(id)
}
```
`group` (`{ appName, appIcon, notifications }`) · `separator` · `card` ·
`expanded` · signals `dismiss(id)` / `activated`.

Owns only its expansion state; every mutation leaves through a signal. Note
`Notifications.qml` stores urgency as the **stringified enum**, so the urgent
test is `urgency === NotificationUrgency.Critical.toString()` — not the word
`"critical"`. Compare that way anywhere else you test urgency.

A **toast** is not this widget: see `notificationPopup/NotifToast`.

#### `PaperEmpty` — an empty / busy state
```qml
PaperEmpty { width: parent.width; text: "No notifications" }
PaperEmpty { width: parent.width; text: "Scanning…"; rules: false }
```
`text` · `rules` (hairline brackets the message with a hairline above and below;
that is what stops an empty region reading as a broken panel) · `align`.

It is a **one-line list placeholder**, sized to sit inside a list. A surface
whose empty state is its whole body — the media card's "No active player" hero —
composes that itself; do not force it through here.

#### `PaperChip` — one member of a set you pick from
```qml
PaperChip { label: "DP-1"; checked: target === "DP-1"; onClicked: Monitors.setQuick("single", "DP-1") }
PaperChip { label: "1.5×"; mono: true; checked: scale === "1.5"; enabled: fits }
PaperChip { label: "⏎"; interactive: false }        // a resting field hint
```
`label` · `checked` · `tick` (the ledger check inside a picked chip) · `mono` ·
`connected` · `interactive` · signal `clicked` · read `contentColor` for
children.

A chip is a **noun**; `PaperButton` is a verb. Use the inherited `enabled` for an
option that exists and is impossible — the widget draws the variant's own
not-available mark (a dotted frame in broadsheet) rather than an opacity drop.
`interactive: false` is different: it keeps the chip body but takes no hover, no
cursor and no click, for a hint or a status marker.

#### `PaperSegment` — pick exactly one of a small fixed set
```qml
PaperSegment {
    width: parent.width
    options: [{ label: "Template", value: "template" }, { label: "Static", value: "static" }]
    value: configType
    onPicked: v => configType = v
}
```
`options` (`{ label, value, enabled? }`) · `value` · `equal` · `cellHeight` ·
`mono` · signal `picked(value)`. Nothing slides — the mark is redrawn under the
new cell, never animated across it.

#### `PaperStat` — a labelled figure
```qml
PaperStat { icon: "ram"; label: "Ram"; value: "38 %" }
PaperStat { icon: "cpu"; label: "Load"; value: "17 %"; spread: true; width: 180 }
```
`icon` · `label` · `value` · `alert` · `spread` (fill `width`, figure
right-aligned — the popup form) · `showIcon` / `showLabel` · `labelSize` /
`valueSize` / `valueTone`.

Write all three parts and let the variant drop what it does not use: hairline
prints glyph + figure, ledger prints label + figure and **no glyph at all**
("the label is the icon"), broadsheet prints all three. Use `PaperKV` instead
when the two really are a key and its value.

#### `PaperBattery` — the battery glyph
```qml
PaperBattery { id: batt; percent: Battery.percentage * 100; charging: Battery.isCharging }
PaperText { figure: true; text: "78 %"; color: batt.statusColor }
```
`percent` · `charging` · `criticalAt` · read `statusColor` for any text that must
agree with the glyph. The geometry is fixed per variant, so there is no `size`.
The level fill is the one solid ink mark allowed to exceed 6 px — it encodes a
quantity, not a state.

#### `PaperStepper` — a labelled integer stepper
```qml
PaperStepper { width: parent.width; label: "Name match"; help: "exact connector name (eDP-1)"
               value: scName; onChanged: v => scName = v }
```
`label` · `help` · `value` · `from` / `to` / `step` · signal `changed(v)`. The
caller owns the value; the widget does not mutate it.

#### `PaperArrange` — the two-rectangle arrangement picker
```qml
PaperArrange { direction: "right"; label: "Right"
               checked: Monitors.quickArrange === "right"; onClicked: Monitors.setArrange("right") }
```
`direction` ∈ right | left | up | down · `label` · `checked` · signal `clicked`.
The diagram is the point: the primary screen is the marked rectangle.

---

### Promotion candidates

These are surface-local today because **only one surface uses each**. The rule
is: promote to `widgets/` the moment a second surface wants the shape, and not
before. Each was assessed during integration and deliberately left where it is.

| Component | Shape | Why not promoted |
|---|---|---|
| `bar/BarColumnHead` | micro-caps label + leading glyph, ruled **UNDER** itself (a double rule in broadsheet) | Only the system-monitor popup. A rule under a head makes the rows beneath it a *table*, which `PaperSectionHeader` (rule *through*/above) deliberately is not. If a second table appears, add an `underline:` mode plus a leading `icon:` to `PaperSectionHeader` rather than creating a second heading device. |
| `bar/BarValueRow` | the three-way reported-line idiom: hairline glyph+label+mono / ledger `PaperKV` dotted leader / broadsheet agate+oldstyle figure | Used three times, but all three are bar popups — one surface. Genuinely the strongest candidate; promote as `PaperValueRow` the first time quick settings or the displays overlay wants it. |
| `quickSettings/QsToggleTile` | icon slot + title-over-status hairline card (ledger/broadsheet, where hairline uses `PaperToggleRow`) | The one candidate second user — the displays overlay's quick-layout tiles — turned out to be `PaperArrange` diagrams and stacked `PaperButton`s, not title-over-status cards. |
| `notificationPopup/NotifToast` | a floating sheet holding ONE notification with action buttons | Shares a *type stack* with `PaperNotifRow` (kicker · time · summary · body), not a shape: a toast is a sheet, a notif row is a ruled list row with an expander. If the stack drifts between them, factor out the stack, not the row. |
| `sessionScreen/SessionWarning` | a `PaperStamp` on a paper backing plate, over a dark scrim | The plate exists because a sepia frame on a 72 % dark scrim is unreadable. One surface has a dark ground; if a second gets one, this becomes `plate:` on `PaperStamp`. |
| `overview/OvSearchRow` | the launcher result row | Evaluated against `PaperListRow` and kept separate: it needs three alternative leading renderings, a kicker *above* the title, no selection indent under a keyboard cursor, and a different ledger selected ground. The move, if a second list ever wants it, is an optional leading-content slot + a `kickerFirst` mode on `PaperListRow`. |

Also unpromoted and unlikely to move: `overview/OvExpose`'s focused-tile corner
ticks (drawn on a plain focus-ring `Rectangle`, not a `PaperPanel`, so
`PaperPanel.tickColor` does not reach them).

---

## 4. When to branch on the variant

**Do not branch** for: colours, fonts, rule weights, radii, shadow, grain,
padding, gaps, motion, control heights, surface widths. Those are tokens.

**Do not branch** for: button/field/switch/check/meter/stamp/leader appearance.
Those are widgets.

**Do branch** — with `isHairline` / `isLedger` / `isBroadsheet` or an
`ornament.*` flag — when the *structure* differs:

* quick settings' connectivity block is **six 56 px toggle rows** in hairline but
  a **3-row grid of tiles and square buttons** in ledger/broadsheet;
* the calendar switcher is **three tabs over a continuous hairline** in hairline
  but a **left stack of three 58 px mode buttons** in ledger/broadsheet;
* the session screen is **six 120 px columns divided by full-height vertical
  rules** in hairline but **six square tiles** in the others;
* bar stats are **glyph + value** in hairline and broadsheet but
  **caps-key + figure with no icon at all** in ledger ("the label is the icon");
* the exposé workspace number is a small corner numeral in hairline but a
  **watermark at 36–40 % of the tile height** in ledger/broadsheet;
* broadsheet adds mastheads (Oxford rules), corner ticks and stamps that the
  others simply do not have — gate those on `ornament.oxfordRules`,
  `ornament.cornerTicks`, `ornament.stamps`.

Where a structure is variant-specific and large, prefer one `Loader` with a
`sourceComponent: PaperTheme.isHairline ? rowsComponent : gridComponent` over a
forest of `visible:` bindings. It stays reactive and it reads.

---

## 5. Windowing, gating and service wiring

The behavioural contract is `design/current-pixels/SPEC.md` and it is unchanged.
The pixel implementation is the reference; read the matching file under
`modules/pixel/` before you write yours.

### 5.1 GlobalStates (`import qs` — it is a root singleton)

Reuse these; **add none**. Only one family loads at a time.

`barOpen` `screenLocked` `sidebarRightOpen` `overviewOpen` `sessionOpen`
`mediaControlsOpen` `monitorsOpen` `worktreesOpen` `osdVolumeOpen`
`osdBrightnessOpen` `superReleaseMightTrigger`.

Side effects that live in `GlobalStates.qml`, not in the panels: opening
`sidebarRightOpen` calls `Notifications.timeoutAll()` + `markAllRead()`, and
`Notifications.popupInhibited` is true while it is open.

### 5.2 IPC targets and GlobalShortcut names

**Mirror the pixel names exactly**, so the user's existing Hyprland binds keep
working. Two families never load simultaneously, so the names cannot collide at
runtime.

| Surface | IpcHandler target | functions | GlobalShortcuts |
|---|---|---|---|
| quickSettings | `sidebarRight` | toggle close open | `sidebarRightToggle` `sidebarRightOpen` `sidebarRightClose` |
| overview | `search` | toggle workspacesToggle close open toggleReleaseInterrupt clipboardToggle | `searchToggle` `searchToggleRelease` `searchToggleReleaseInterrupt` `overviewWorkspacesToggle` `overviewWorkspacesClose` `overviewClipboardToggle` `overviewEmojiToggle` |
| sessionScreen | `session` | toggle close open | `sessionToggle` `sessionOpen` `sessionClose` |
| mediaControls | `mediaControls` | toggle close open | `mediaControlsToggle` `mediaControlsOpen` `mediaControlsClose` |
| monitors | `monitors` | toggle close open | `monitorsToggle` `monitorsOpen` `monitorsClose` |
| worktrees | `worktrees` | toggle close open | `worktreesToggle` `worktreesOpen` `worktreesClose` |
| onScreenDisplay | `pixelOsdVolume` (trigger hide toggle), `pixelOsdBrightness` (trigger hide) | | `pixelOsdVolumeTrigger` `pixelOsdBrightnessTrigger` `pixelOsdHide` |

The OSD names are the one wart: they are pixel-specific because the user's
keybinds point at them. Keep them, and add a comment saying so. Nothing in the
bar, the notification popup or the background declares IPC or shortcuts.

Already declared in `shell.qml` — do **not** redeclare: `panelFamily`,
`TEST_ALIVE`, `paperVariant` (`cycle` / `set` / `get`), `paperPlate`
(`next` / `previous` / `pin` / `daily` / `get`, see §11), and the
`panelFamilyCycle` / `paperVariantCycle` shortcuts. `zoom` and `workspaceNumber`
live in `GlobalStates.qml`.

Bind the variant cycle from Hyprland with e.g.
`bind = SUPER SHIFT, P, global, quickshell:paperVariantCycle`, or call
`qs -c ii ipc call paperVariant cycle`.

### 5.3 The five gotchas that will cost you an afternoon

1. **Focus-grab lifetime.** `HyprlandFocusGrab` only attaches if the window is
   *already mapped* when the grab activates. Quick settings and the displays
   overlay therefore keep the `PanelWindow` alive permanently and toggle
   `visible`; only the *content* lives in a `Loader`. A `Loader`-created window
   maps at the same instant the grab activates, the grab never attaches, and
   click-out-to-close silently breaks. The overview needs a further hack: a
   `Timer` of `Config.options.hacks.arbitraryRaceConditionDelay` before setting
   `grab.active`, and it must only grab on the focused monitor
   (`grab.canBeActive`). The session screen and worktrees dodge the problem
   entirely with `keyboardFocus: Exclusive` + a scrim `MouseArea`.
2. **`keyboardFocus` is per-surface and touchy.** Quick settings: leave
   `WlrLayershell.keyboardFocus` **unset** (setting it breaks the mouse grab on
   Hyprland 0.49). Displays: `OnDemand`, so `PaperField.focusInput()` works.
   Session screen and worktrees: `Exclusive`. Overview: unset, keys on a focused
   `FocusScope`.
3. **Region masking.** Any overlay that must be click-through except over its
   content sets `mask: Region { item: <content> }` — the notification column,
   the OSD panel, the media card, each bar popup. Tooltips go further with
   `mask: Region { item: null }`.
4. **Never resize a layer surface to animate.** Media controls keep
   `implicitHeight` fixed and animate only the inner card's `height` with
   `clip: true`. Resizing the surface flickers on Hyprland.
5. **Release screencopy.** `captureSource: GlobalStates.overviewOpen ? toplevel
   : null`. Binding it unconditionally captures every window forever.

Plus two smaller ones: use `screen.width/height` from the `ShellScreen` rather
than the window's `width`/`height` (a layer surface can still be 0 × 0 shortly
after a reload), and never name a custom signal `clicked` on a `MouseArea`
subclass — it shadows `MouseArea.clicked(MouseEvent)` and silently unwires
`onClicked`.

### 5.4 Bar hover popups

They are **not** `PopupWindow`s. Copy `modules/pixel/bar/PixelBarPopup.qml`: a
`LazyLoader` whose `active` is bound directly to `hoverTarget.containsMouse` and
whose component is an Overlay-layer `PanelWindow` positioned by mapping the
hover target's x:

```qml
margins.left: root.QsWindow?.mapFromItem(root.hoverTarget,
    alignLeft ? 0 : ((hoverTarget.width - panel.implicitWidth) / 2), 0).x ?? 0
margins.top: PaperTheme.barPopupOffset
```

### 5.5 Services (`import qs.services`, `import qs.modules.common`)

Used by the pixel family and needed again, with the properties that matter:

* `TrayService.pinnedItems`, `.getTooltipForItem(item)`; menus via
  `QsMenuAnchor { menu: item.menu }`.
* `ResourceUsage.{memoryUsedPercentage,memoryUsed,memoryFree,memoryTotal,cpuUsage}`.
* `ClaudeUsage.{available,sessionPercent,weekPercent,opusPercent,sessionResetsAt,weekResetsAt,lastUpdatedAgo,lastError,formatReset(iso)}`.
* `Battery.{available,percentage,isCharging,chargeState,energyRate,timeToFull,timeToEmpty,health}`.
* `Audio.{sink,source,ready,toggleMute(),incrementVolume(),decrementVolume()}`;
  `Brightness.getMonitorForScreen(screen)` → `.brightness` / `.setBrightness(v)`
  plus `Connections { target: Brightness; function onBrightnessChanged() }`.
* `Network.{wifiStatus,networkName,ethernet,friendlyWifiNetworks,wifiScanning,wifiConnecting,wifiConnectTarget,toggleWifi(),rescanWifi(),connectToWifiNetwork(),disconnectWifiNetwork()}`;
  `BluetoothStatus.friendlyDeviceList`.
* `Notifications.{popupList,groupsByAppName,appNameList,list,markAllRead(),discardNotification(id),discardAllNotifications(),cancelTimeout(id),attemptInvokeAction(id,action)}`.
  The service owns the auto-dismiss timer. The unlabelled `"default"` action is
  never drawn as a button.
* `DateTime.{clock,uptime}`, `Todo.{list,addTask,markDone,markUnfinished,deleteItem}`,
  `TimerService.{pomodoroRunning,pomodoroBreak,pomodoroLongBreak,pomodoroCycle,pomodoroSecondsLeft,togglePomodoro(),resetPomodoro()}`.
* `MprisController.{activePlayer,isPlaying,togglePlaying(),next(),previous()}`;
  `LyricsService.{lines,plainLyrics,synced,status,instrumental,indexForPosition(pos)}`.
* `LauncherSearch.{query,results}`, `AppSearch.guessIcon(class)`,
  `StringUtils.{cleanMusicTitle,friendlyTimeForSeconds,cleanOnePrefix}`.
* `Hyprland`, `HyprlandData.{monitors,biggestWindowForWorkspace,windowByAddress}`,
  `ToplevelManager.toplevels.values`, `ScreencopyView`.
* `Monitors` — the whole displays API (state: `monitors profiles activeProfile
  daemonRunning quickActive quickApplied quickMode quickTarget quickArrange
  quickAnchor quickScales singleTargetCandidate destination scoring notifications
  general busy lastMessage lastOk`, signal `actionFinished(ok, message)`; actions:
  `refresh setQuick clearQuick setArrange setAnchor setScale snapshotQuick
  restoreQuick applyCurrent saveProfile removeProfile setProfileEnabled
  moveProfile setScoring setNotifications validate reapply reload`). See §5.6.
* `Worktrees.{repos,tasks,busy,log,lastOk,lastError,lastWarnings,refresh(),create(name,selection),open(name)}`.
* `SessionWarnings.{refresh(),packageManagerRunning,downloadRunning}` and
  `Session.{lock,logout,suspend,hibernate,reboot,poweroff}` from
  `qs.modules.common.functions`.
* `Idle.toggleInhibit()`, `Translation.tr(…)`.
* **Reuse, do not reimplement**, the nine shared toggle models in
  `qs.modules.common.models.quickToggles`: `BluetoothToggle`
  `IdleInhibitorToggle` `MicToggle` `NightLightToggle` `CloudflareWarpToggle`
  `GameModeToggle` `EasyEffectsToggle` `AntiFlashbangToggle`
  `ColorPickerToggle`. They encapsulate every shell-out.
* From `qs.modules.common.widgets` the pixel family imports exactly one thing:
  `FocusedScrollMouseArea` (`onScrollUp` / `onScrollDown` / `onMovedAway`) for
  the bar's scroll regions. Do not pull in `StyledText`, `MaterialSymbol` or the
  ii tooltips — the paper family has its own primitives.

`Monitors` and `Worktrees` are the only services that shell out to project
Python (`scripts/monitors/hdm-control.py`, `scripts/worktrees/worktree-setup.py`).
Treat them as read/act-only APIs; never call the scripts yourself.

### 5.6 The Displays overlay can black out the machine — the safety model

A quick **mode** change is the only thing this shell does that can leave the user
unable to see the panel they would need in order to undo it. It has already
happened once: a `Single` layout was written with `single_target = "DP-1"` while
only the laptop panel was attached, the managed profile still matched at the next
boot, and the template rendered `monitor=…,disable` for **every** screen. Four
layers now stand between a click and that outcome; do not remove one because
another looks sufficient.

1. **The profile requires its target.** `hdm-control.py` writes the `single`
   target's description into the managed profile's `required_monitors`, so the
   daemon cannot select the profile with the target unplugged — it falls through
   to the user's own profiles.
2. **The template cannot render an all-disabled config.** If `single_target`
   matches no connected monitor, the `single` branch degrades to "every screen
   on" instead of disabling everything.
3. **The command refuses.** `quick single <target>` fails (clean JSON error,
   nothing written) when the target is not connected; a target-less `quick single`
   resolves through the remembered target to the first *connected* output; and no
   quick write whose render would enable zero outputs is allowed.
4. **The GUI holds the change.** `MonQuickConfirm` (pixel: `QuickConfirm`) —
   snapshot → apply → a modal "Keep this monitor setup?" with a 15 s countdown.
   Keep dismisses; **Revert, the countdown expiring, or the overlay closing** all
   call `Monitors.restoreQuick(snapshot)`. A second mode change while one is
   pending keeps the ORIGINAL snapshot and restarts the countdown — never a
   second dialog.

So `MonQuickLayout` does **not** apply a mode itself: it emits
`modeRequested(mode, target)` and `PaperMonitorsContent` does
`quickConfirm.arm(); Monitors.setQuick(…)` — in that order, because `arm()` is
what takes the snapshot. Arrangement, primary screen and zoom are applied
directly; none of them can take a screen away. Confirmed alongside the three
modes: `Auto` (handing the layout back to the user's profiles moves screens too)
and picking a different **Single target** (it turns the screen you are looking at
off).

`Monitors.snapshotQuick()` returns
`{ active, mode, target, arrange, anchor, scales }` — including the "no quick
profile at all" state, which `restoreQuick` replays as `clear`. Per-output zoom
needs no replay: hdm-control.py carries `scale_<output>` over from the existing
managed profile.

If you ever add a **per-output enable switch** to `MonMonitorRow` (hairline's
§4.8 asks for one; there is no service action for it today), it must be disabled
with a hint on the last enabled output, for the same reason `Single` is disabled
when nothing is connected: no control in this overlay may be able to turn off the
final screen.

---

## 6. Icons — 87 canonical glyphs

Each of the three variants keeps **its own drawing** of every glyph it has: the
sets genuinely differ (ledger's `wifi` has a filled dot, broadsheet's `battery`
is a wider 20-grid body, hairline's `gear` is a finer cog), and preserving that
is what makes a live variant switch look like a different set of pens rather
than a recolour. A glyph a variant does not draw falls back to another variant's
drawing rather than disappearing.

Names are lowerCamelCase and unified; **every spelling the SPECs use is
accepted** via an alias table — hairline's kebab-case (`chev-d`, `speaker-x`,
`bat-chg`, `mic-off`, `wifi-off`, `bell-off`, `fullscr`, `bt`), ledger's
(`speakeroff`, `micoff`) and broadsheet's (`wifioff`, `monitor`, `expand`).

```
apps arrowD arrowL arrowR arrowU batCharging battery bell bellOff bluetooth
bolt branch calendar check chevD chevL chevR chevU clock close cloud coffee
cpu crop display dot drag dropper ellipsis eye flashoff folder fullscreen gear
globe grid grip heart image info keyboard laptop layers lines list lock logout
message mic micOff minus mirror moon next nodes note pause pencil phone play
plus power prev proc puzzle ram refresh regex ring robot search server sliders
snow sparkle speaker speakerOff square sun swap terminal timer todo trash warn
wifi wifiOff
```

Per-variant counts: hairline 76 · ledger 65 · broadsheet 64 → 87 canonical.
Glyphs missing from a variant (and therefore borrowed): hairline lacks
`apps arrowD arrowU cloud eye grip info lines mirror phone server`; ledger lacks
`arrowD arrowL arrowU batCharging bellOff dot drag ellipsis eye folder globe grid
image laptop layers list mirror phone regex ring square wifiOff`; broadsheet
lacks `apps arrowL arrowR batCharging bellOff cloud dot drag ellipsis globe grip
image laptop layers lines list micOff proc puzzle regex ring speakerOff square`.

An unknown name draws **nothing** — a missing icon should show as a hole in
review, not silently resolve to the wrong picture.

`paper_icons_data.js` is generated. If you need a glyph the previews do not
contain, add it to the design HTML and re-run
`python3 scripts/paper/extract_icons.py`, or hand-add it to the file and note it
there. The data shape is
`{ vb: 16|20, p: [ { d: "<svg path>", f: 1? }, … ] }`; `f: 1` marks a solid part.
`PaperIcons.paths(variant, name)` returns `{ vb, stroke, fill }`, which is all
`PaperIcon` consumes.

The pixel set's substitutions are all gone: there are real `lock`, `logout`,
`search`, `display`, `branch`, `check`, `plus`, `minus`, `close`, `regex`,
`mirror` and vertical chevrons, so **no glyph is ever a stand-in for another**.

---

## 7. Fonts — what is bundled and what is substituted

| Face | Status |
|---|---|
| **Inter** (hairline body) | **Bundled** — `assets/fonts/Inter-{Light,Regular,Medium}.ttf`, v4.1 from the official GitHub release. It was *not* installed on this machine. Fallback if the loader fails: `Adwaita Sans` (an Inter derivative). |
| **Bitstream Charter** (ledger titles) | **SUBSTITUTED → XCharter.** Charter *is* installed here, but only as Type 1 `.pfb` (`/usr/share/X11/fonts/Type1/c064*bt_.pfb`), which Qt renders badly at 15–16 px, and no freely-downloadable Charter TTF/OTF could be reached. `assets/fonts/XCharter-{Roman,Bold,Italic}.otf` (Michael Sharpe's CTAN extension of the same Carter design, with real oldstyle figures and small caps) is bundled instead. Visually the intended face; the family name at runtime is `XCharter`. |
| Adwaita Sans, JetBrains Mono, Source Code Pro, TeX Gyre Pagella, Lato | Installed system-wide, used as-is. |

Never hardcode a family name; read `PaperTheme.fontSans` / `fontSerif` /
`fontMono` (or just use `PaperText` / `PaperTitle`).

---

## 8. Validation without launching the shell

**Do not run `qs -c ii`.** The user runs the shell and tests the GUI himself.

What works instead:

* `qmllint-qt6 <file>` — catches syntax and property errors. Unresolved
  `qs.*` / `Quickshell` imports are expected noise; look for lines tagged
  `Error:`.
* An offscreen harness. The recipe used to validate this foundation:
  create a directory with stub `Quickshell` (a `Quickshell` singleton exposing
  `shellPath`/`iconPath`, and a `Singleton` type that is a `QtObject` with a
  default `list<QtObject> data`) and stub `qs/modules/common` (`Appearance` with
  `m3colors.darkmode`, `Config` with `options.paper.variant`), symlink the real
  `modules/paper/common` and `modules/paper/widgets` files in with hand-written
  `qmldir`s, then
  `QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software /usr/lib64/qt6/bin/qml -I <dir> gallery.qml`
  and `grabToImage(...).saveToFile(...)`. Flipping the stub `Config` and
  `Appearance` values between grabs proves the live variant/dark-mode switch.
  Use `qmlscene` rather than `qml` when you need to *see* the load errors —
  `qml` swallows them in this environment.
* Anything constructing a real `PanelWindow` / `Variants` / `ScreencopyView`
  cannot be harnessed: the Quickshell QML plugin needs its own engine. Validate
  those by `qmllint` plus close reading against the pixel equivalent.
  **`PopupWindow`, `Region`, `Edges` and `PopupAnchor` only need to RESOLVE**,
  though — `PaperTooltip` keeps its `PopupWindow` inside an inactive `Loader`,
  so four tiny stub types (`Margins`, `PopupAnchor`, `PopupWindow`, `Region`,
  plus an `Edges` type declaring `enum Edge`) are enough to load
  `PaperListRow` / `PaperToggleRow` / `PaperTabs` offscreen. Declare `margins`
  as a **named** stub type, not a bare `QtObject`, or the grouped-property
  assignment fails to compile.

* **Point `qmllint` at the harness.** `qmllint-qt6 -I <harnessDir> <files>`
  resolves `qs.modules.paper.*` through the harness's hand-written `qmldir`s and
  will then actually type-check property names on paper widgets. Without `-I`
  every `qs.*` import fails and qmllint degrades to a syntax checker — which is
  why a call site can carry a misspelled property and still lint clean. Filter
  the output for `not found on type "Paper…"`; grouped `PaperTheme` sub-objects
  (`motion.base`, `font.weight.medium`, …) produce unavoidable
  `Member … not found on type "QObject"` noise, because qmllint cannot see into
  an inline `QtObject`.

* **Grabbing across a variant switch:** `grabToImage` captures the *next*
  rendered frame, so changing the variant and grabbing in the same tick records
  the wrong one. Use two phases — apply on one tick, grab on the next.

---

## 9. Known quirks

Things that look like bugs and are not, plus the ones that are.

**`MultiEffect` on the software renderer.** `PaperPanel { floating: true }` uses
a `MultiEffect` for its shadow, which the *software* renderer cannot draw — the
sheet comes out black or blank in offscreen screenshots, taking its content with
it. On the real GPU path it is fine (the pixel family already ships
`Qt5Compat.GraphicalEffects`). In a harness, patch the harness's **copy** of
`PaperPanel.qml` to `layer.enabled: false` so the sheet's content is reviewable;
never do it in the repo. If it ever misbehaves on hardware, flip
`PaperTheme.ornament.shadow` to `false` and the whole family loses its shadows
cleanly.

**The exposé shadow is deliberately off.** The overview's workspace tiles do not
take `floating`'s shadow even in ledger/broadsheet. Dozens of small sheets each
with their own drop shadow reads as a pile of cards, not a page — and it is the
one place in the shell where that many floating surfaces are on screen at once.
This is a choice, not an omission; do not "fix" it.

**`pixelOsd*` IPC names.** The OSD's IpcHandler targets are `pixelOsdVolume` /
`pixelOsdBrightness` and its shortcuts are `pixelOsdVolumeTrigger` /
`pixelOsdBrightnessTrigger` / `pixelOsdHide`. They are pixel-specific names on a
paper surface because **the user's Hyprland keybinds point at them**. Two
families never load at once, so the names cannot collide. Leave them.

**XCharter substitutes for Bitstream Charter.** Ledger's title face resolves to
the family name `XCharter`, not `Charter` — Charter is installed here only as
Type 1 `.pfb`, which Qt renders badly at 15–16 px. XCharter is Michael Sharpe's
CTAN extension of the same Carter design, with real oldstyle figures and small
caps, bundled under `assets/fonts/`. Never hardcode either name; read
`PaperTheme.fontSerif`. See §7.

**Urgency is a stringified enum.** `Notifications.qml` stores
`notification.urgency.toString()`, so an urgency test must compare against
`NotificationUrgency.Critical.toString()` — comparing against `"critical"`
silently never matches. `qmllint` flags the correct form as
`"toString" is not an entry of enum "Enum"`; that warning is expected and the
rest of the repo carries it too (`modules/common/widgets/NotificationGroup.qml`).

**An unknown icon name draws nothing.** By design — a missing glyph should be a
hole in review, not a silently wrong picture. There is no runtime warning, so
audit literal names against `paper_icons_data.js` whenever you add one. As of
integration all 62 glyph names in use resolve, and every one is drawn by at
least one variant.

**Never name a custom signal `clicked` on a `MouseArea` subclass.** It shadows
`MouseArea.clicked(MouseEvent)` and silently unwires `onClicked`.

---

## 10. What every variant deliberately refuses

Worth internalising, because it is what makes the family coherent:

* No gradients, no blur, no glow, no coloured shadows.
* No inversion as a state. A filled control is either the single committing
  action on the surface or a solid `ink` marker; states are washes, frames,
  underlines and change bars.
* No green, no amber, no traffic lights. Success is ink or a blue stamp, warning
  is sepia or `alertSoft`, failure is `alert`.
* No opacity as a disabled treatment in broadsheet — a dotted rule instead.
* No decorative ornament. Every tick, double rule and seal marks something.
* No scrolling pixelscape background. The desktop plate (§11) is not a breach of
  that: it is a still picture drawn in one theme ink, not an image with colours
  of its own.
* **Album art is the only place third-party colour reaches the screen.**

---

## 11. The desktop plate

The paper desktop hangs a picture: one public-domain engraving, chart, map or
woodblock, held as **ink density only** — the PNGs in
`assets/images/paper-plates/` are black pixels plus an alpha channel and carry no
paper of their own. `PaperBackground` lays the plate on the variant's `paper` and
tints it through a `ColorOverlay` with `PaperTheme.backdrop.plateInk`, so **one
asset serves all three variants in both modes** and a live variant switch
re-inks the picture with no reload. That is the whole reason the assets are
alpha-only; do not "simplify" them into finished wallpapers.

**One plate per day, and the pick is a pure function of the local date**
(`PaperPlates.day` → `paper_plates_data.js:forDay()`). Not random per launch:
every screen must agree without sharing state, and the picture must survive a
reload — a wallpaper that changes on every reload reads as a bug. The catalog
steps by 7 rather than hashing, so consecutive days land far apart in the list
(no two Haeckel plates back to back) while every plate still comes up once per
cycle. `PaperPlates` holds an hourly `SystemClock`, which is what rolls the date
over at local midnight.

Two layouts, carried per plate in the catalog:

| layout | what it is | how it is drawn |
|---|---|---|
| `bleed` | a landscape scene, map or chart | slot sized to COVER the screen at the plate's aspect; the overhang falls outside the window |
| `motif` | a portrait print laid on the sheet | `scale` of screen height, `align`ed left/center/right with a 6 % inset, never wider than 88 % of the screen |

The slot always carries the plate's own aspect and the `Image` merely fills it —
**do not reach for a `fillMode`**. `ColorOverlay` samples the image's texture
directly, which bypasses `fillMode` entirely and would silently stretch a bleed
plate to the screen's aspect (39 % too wide on a 3440 × 1440 panel). Matched
geometry is what keeps the picture undistorted.

Opacity is `PaperTheme.backdrop.plateOpacity` × the plate's own `weight` ×
`Config.options.paper.backdrop.strength`.

Every plate is normalised to the same ink coverage so a delicate Ortelius map and
a black Piranesi aquatint hang at the same weight — **by gamma, never by a linear
scale**. `a ** g` pins 1 → 1, so the deepest bite of the engraving stays solid
and only the mid-tones thin out. This matters more than it sounds: the first cut
of this feature scaled alpha linearly, which left every plate peaking around 50 %
alpha, and at that ceiling the desktop showed a flat grey wash with no picture in
it however far the opacity was pushed. A plate with genuinely solid blacks cannot
be curved down to the target without losing them, so whatever coverage gamma
cannot take off is taken off the plate's catalog `weight` instead (the generator
computes that automatically; the `weight` in the PLATES list is only a hand
nudge on top).

If the wall is too strong or too faint for your screen, dial it live rather than
editing tokens: `qs -c ii ipc call paperPlate heavier` / `lighter` step
`strength` by 0.1, and `strength 1.4` sets it outright.

Config (`Config.options.paper.backdrop`): `enable` (false leaves the bare paper
ground), `plate` (a catalog file name pins it; empty rotates daily), `strength`.
To look through the collection now instead of one a day:

```
qs -c ii ipc call paperPlate next          # steps and pins
qs -c ii ipc call paperPlate pin hokusai-great-wave.png
qs -c ii ipc call paperPlate get           # file + credit line
qs -c ii ipc call paperPlate daily         # back to the plate of the day
```

To change the collection, edit the `PLATES` list in
`scripts/paper/fetch_plates.py` and re-run it — it fetches from Wikimedia
Commons (refusing anything it cannot confirm as public domain or CC0), caches the
scans under `~/.cache/quickshell/paper-plates-src`, rebuilds the PNGs and
rewrites `paper_plates_data.js` with each plate's provenance. `--sheet` renders a
contact sheet of the whole collection on light and dusk paper, which is how you
review a change without launching the shell (§8).
