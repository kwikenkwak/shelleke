# Pixel family — implementation contract

You are building part of the **`pixel`** Quickshell panel family: a strictly
**monochrome, retro pixel-art** restyle of the `ii` shell. Read this fully.

## Aesthetic rules (non-negotiable)
- **Monochrome only.** Black-on-white (light) / white-on-black (dark). No accent
  colors anywhere. The ONLY exception in the whole shell is music cover art in
  media controls (not your concern unless told).
- **Hard edges.** `radius: 0` everywhere. 2px or 3px solid borders. `antialiasing: false`
  on rectangles/icons. **No drop shadows, no gradients, no blur.**
- **Fonts:** body = Pixelify Sans (via `PixText`), titles/labels = Silkscreen (via `PixTitle`).
- **Icons:** 7×7 bitmap `PixIcon`s for UI glyphs. App/tray/notification icons use
  `PixAppIcon` (grayscale + pixelated) so arbitrary apps contribute NO color.

## Foundation API (already built — DO NOT modify these files)
`import qs.modules.pixel.common` →
- `PixTheme.dark` — bool, follows global dark mode.
- `PixTheme.colors.{bg,fg,grey,grey2,line,onFill}` — colors. `grey`=muted text, `grey2`=faint.
- `PixTheme.borderWidth`(2), `.popupBorderWidth`(3), `.barBorderWidth`(3), `.barHeight`(46).
- `PixTheme.fontMain`, `PixTheme.fontTitle` — family-name strings.
- `PixTheme.font.pixelSize.{smallest=10,smaller=11,small=12,normal=13,large=14,larger=15,title=16,huge=20}`
- `PixTheme.animation.{duration=110,type}`

`import qs.modules.pixel.widgets` →
- `PixIcon { name; size; color }` — names: bell, bluetooth, bolt, calendar, chevD,
  chevL, chevR, clock, coffee, cpu, dropper, flashoff, fullscreen, gear, heart,
  keyboard, message, mic, moon, nodes, note, pencil, power, proc, puzzle, ram,
  refresh, sliders, snow, sparkle, speaker, sun, swap, terminal, timer, todo,
  trash, wifi. (`size` snaps to a multiple of 7 internally.) Default color = fg.
- `PixText { ... }` — a `Text` subclass (set `text`, `font.pixelSize`, `font.bold`, `color`).
- `PixTitle { ... }` — a `Text` subclass in Silkscreen.
- `PixPanel { borderWidth }` — bordered square container (bg fill + line border).
- `PixButton { filled; checked; interactive; fillOnHover; contentColor(readonly); signal clicked(); signal rightClicked() }`
  Bordered square. When active (filled/checked/hover) it fills with `line` and
  `contentColor` flips to `bg`. **Bind child icon/text `color: someButton.contentColor`**
  so content inverts. Put content as children (anchored/centered yourself).
- `PixAppIcon { icon; source; size; pixelResolution }` — grayscale+pixelated app icon.
  Use `icon` (theme name → Quickshell.iconPath) OR `source` (url). USE FOR ALL APP ICONS.
- `PixBatteryGlyph { percent; charging; color; u }` — battery glyph (u = pixel unit scale).

"Filled square = active/used, hollow (bordered) square = inactive/free" is the
core visual language — use `PixButton{filled:...}` or fill a 30×30 box with `fg`
and put a `PixIcon{color: bg}` inside.

## Quickshell conventions — READ THESE REFERENCE FILES before coding
- Bar window + Variants over screens + exclusiveZone: `modules/ii/bar/Bar.qml`, `modules/ii/bar/BarContent.qml`
- Right-sidebar PanelWindow + HyprlandFocusGrab + open/close: `modules/waffle/actionCenter/WaffleActionCenter.qml`
- System tray + tooltip: `modules/ii/bar/SysTrayItem.qml`, `services/TrayService.qml`
- Hover popup pattern: `modules/ii/bar/StyledPopup.qml`, `ResourcesPopup.qml`, `BatteryPopup.qml`, `ClockWidgetPopup.qml`
- Resource stats: `services/ResourceUsage.qml`, `modules/ii/bar/Resources.qml`, `Resource.qml`
- Battery: `services/Battery.qml`, `modules/ii/bar/BatteryIndicator.qml`
- Date/time/uptime: `services/DateTime.qml`, `services/SystemInfo.qml`
- Media: `services/MprisController.qml`, `modules/ii/bar/Media.qml`
- Network / Bluetooth / Audio: `services/Network.qml`, `services/BluetoothStatus.qml`, `services/Audio.qml`
- Notifications: `services/Notifications.qml`, `modules/common/widgets/NotificationListView.qml`, `modules/ii/notificationPopup/`
- Claude usage: `services/ClaudeUsage.qml`, `modules/ii/bar/ClaudeUsageResource.qml`
- Workspaces (Hyprland): grep `modules/ii/bar` for the workspace widget; use `Quickshell.Hyprland`
- Quick toggles backing models: `modules/common/models/quickToggles/`
- OSD: `modules/ii/onScreenDisplay/`; Session/power: `modules/ii/sessionScreen/`, `services/SessionWarnings.qml`

## Shared open-state contract (singleton `GlobalStates`, `import qs`)
- Bar visibility: `GlobalStates.barOpen && !GlobalStates.screenLocked`.
- Quick settings (right sidebar) open flag: **`GlobalStates.sidebarRightOpen`**.
  The bar opens it; the quick-settings panel is gated by it and closes on focus loss.
- Overview: `GlobalStates.overviewOpen`. Session/power menu: `GlobalStates.sessionOpen`.
- OSD: `GlobalStates.osdVolumeOpen`, `GlobalStates.osdBrightnessOpen`.
- **Do NOT edit GlobalStates.qml, Config.qml, or shell.qml** — the orchestrator wires those.
  Use only existing flags. For per-panel toggles, expose IpcHandler + GlobalShortcut like the reference files.

## Validation (must pass before you finish)
Run: `bash /tmp/claude-1000/-home-willem--config-quickshell-ii/6e113c3f-38ae-49de-b826-696a512f9d92/scratchpad/validate.sh <your .qml files>`
Every file must print `OK (syntax)`. The `qs.*` import warnings from qmllint are
expected and fine; only real syntax/parse errors fail. Fix until clean.

## Style
4-space indent, no tabs, max ~110 col. Match the existing codebase idioms.
Keep components small and composed. Comment sparingly, like neighbors.
