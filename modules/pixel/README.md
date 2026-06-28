# Pixel

A third panel family for this Quickshell config — a strictly **monochrome,
retro pixel-art** restyle, alongside `ii` and `waffle`. Based on the "Pixel Top
Bar" Claude Design.

## Switching to it
The pixel family is live-switchable like the others:

```sh
qs -c ii ipc call panelFamily cycle   # cycles ii -> waffle -> pixel -> ii
```

or set `panelFamily: "pixel"` in your config (`~/.config/illogical-impulse/config.json`),
which also sets `enabledPanels` to the pixel set.

## What it provides
- **`bar/`** — the top bar (active window, system stats + media, pinned apps,
  workspaces, clock, controls, system tray) with hover popups (system monitor,
  clock/uptime/to-do, battery).
- **`quickSettings/`** — the right-side panel (connectivity, audio, night light,
  quick toggles, notifications, calendar). Toggle with the bar or `pixelSidebar` IPC.
- **`notificationPopup/`**, **`onScreenDisplay/`**, **`sessionScreen/`** — pixel-styled
  toasts, volume/brightness OSD, and power menu.
- Reuses `ii` for the pieces the design doesn't cover (background, overview,
  cheatsheet, lock, media controls, OSK, overlay, wallpaper selector, screen corners).

## Design rules
- **Monochrome only.** Black-on-white (light) / white-on-black (dark), following
  the global dark-mode toggle. No accent colors anywhere.
- **Hard edges:** `radius: 0`, 2px/3px solid borders, no shadows/gradients/blur.
- **Fonts:** Pixelify Sans (body), Silkscreen (titles) — bundled under `assets/fonts/`.
- **Icons:** 7×7 bitmap `PixIcon`s for UI glyphs; arbitrary app/tray/notification
  icons are rendered grayscale + pixelated via `PixAppIcon` so they contribute no
  color. The only color in the shell is music cover art in the (reused) media controls.

## Structure
- `common/PixTheme.qml` — theme singleton (colors, fonts, sizes); `pixicons_data.js`
  — 7×7 bitmap data (generated from the design's `icons.js`).
- `widgets/` — `PixIcon`, `PixText`, `PixTitle`, `PixPanel`, `PixButton`,
  `PixAppIcon`, `PixBatteryGlyph`.
- `CONTRACT.md` — the foundation API + conventions used while building this.
- `design/` — the source design specs (HTML) the implementation follows.
