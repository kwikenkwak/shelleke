//! pixelscape — an auto-playing, black-and-white scrolling map rendered
//! headlessly for the "pixel" quickshell family's background.
//!
//! This is a *top-down* map view: imagine looking straight down at terrain
//! that pans past once per tick, so new terrain continuously enters the top
//! edge. The world is a deterministic, hash-based procedural grid of slots
//! (in X and Y); each populated slot holds a small top-down feature —
//! mountain, forest, village or castle — rasterized from an embedded SVG and
//! composited onto a tiny-skia canvas. Nearby settlements are joined by a
//! black road network, and a few birds drift across the map.
//!
//! Bevy drives the loop (MinimalPlugins + ScheduleRunnerPlugin at 2 FPS),
//! headless, no GPU/window. Each frame is rendered to a tiny-skia Pixmap
//! (white background, black shapes), converted to grayscale and written
//! atomically to a PNG that quickshell reloads. Everything is black on white;
//! quickshell inverts it for dark mode.
//!
//! Usage: pixelscape [OUT_PNG] [WIDTH] [HEIGHT]
//!   defaults: /tmp/quickshell/pixel-bg/frame.png 480 270

use bevy::app::ScheduleRunnerPlugin;
use bevy::prelude::*;
use image::{GrayImage, Luma};
use std::path::PathBuf;
use std::time::Duration;
use tiny_skia::{
    Color, Paint, PathBuilder, Pixmap, Stroke, Transform as SkTransform,
};
use usvg::Transform as UTransform;

// ---------------------------------------------------------------------------
// Embedded SVG assets (top-down, black on transparent).
// ---------------------------------------------------------------------------

const SVG_MOUNTAIN: &str = include_str!("../assets/mountain.svg");
const SVG_FOREST: &str = include_str!("../assets/forest.svg");
const SVG_VILLAGE: &str = include_str!("../assets/village.svg");
const SVG_CASTLE: &str = include_str!("../assets/castle.svg");
const SVG_BIRD: &str = include_str!("../assets/bird.svg");

// ---------------------------------------------------------------------------
// World layout constants.
// ---------------------------------------------------------------------------

/// Spacing between feature slots in world units (both axes). Zoomed out: small
/// spacing so many features fit on screen at once.
const SLOT: i64 = 56;
/// World units the camera pans (downward through the world) per tick.
const PAN_PER_TICK: i64 = 5;
/// Rendered side length of a feature, in pixels.
const FEATURE_PX: f32 = 34.0;
/// Rendered size of a bird, in pixels.
const BIRD_PX: f32 = 16.0;

#[derive(Resource)]
struct Cfg {
    width: u32,
    height: u32,
    out: PathBuf,
}

#[derive(Resource, Default)]
struct Scene {
    /// World Y offset of the top of the viewport. Grows each tick (pan down).
    pan: i64,
    /// Tick counter, used to animate birds.
    tick: u64,
}

/// Pre-rendered SVG pixmaps, rasterized once at startup.
#[derive(Resource)]
struct Assets {
    mountain: Pixmap,
    forest: Pixmap,
    village: Pixmap,
    castle: Pixmap,
    bird: Pixmap,
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let out = PathBuf::from(
        args.get(1)
            .cloned()
            .unwrap_or_else(|| "/tmp/quickshell/pixel-bg/frame.png".to_string()),
    );
    let width: u32 = args.get(2).and_then(|s| s.parse().ok()).unwrap_or(480);
    let height: u32 = args.get(3).and_then(|s| s.parse().ok()).unwrap_or(270);
    if let Some(parent) = out.parent() {
        let _ = std::fs::create_dir_all(parent);
    }

    let assets = Assets {
        mountain: rasterize_svg(SVG_MOUNTAIN, FEATURE_PX as u32),
        forest: rasterize_svg(SVG_FOREST, FEATURE_PX as u32),
        village: rasterize_svg(SVG_VILLAGE, FEATURE_PX as u32),
        castle: rasterize_svg(SVG_CASTLE, FEATURE_PX as u32),
        bird: rasterize_svg(SVG_BIRD, BIRD_PX as u32),
    };

    App::new()
        .add_plugins(
            MinimalPlugins.set(ScheduleRunnerPlugin::run_loop(Duration::from_secs_f64(0.5))),
        )
        .insert_resource(Cfg { width, height, out })
        .insert_resource(Scene::default())
        .insert_resource(assets)
        .add_systems(Update, (advance, render).chain())
        .run();
}

fn advance(mut scene: ResMut<Scene>) {
    scene.pan = scene.pan.wrapping_add(PAN_PER_TICK);
    scene.tick = scene.tick.wrapping_add(1);
}

// ---------------------------------------------------------------------------
// SVG rasterization
// ---------------------------------------------------------------------------

/// Rasterize an SVG string into a square `size`×`size` premultiplied pixmap,
/// scaling the SVG to fit. Black-on-transparent.
fn rasterize_svg(svg: &str, size: u32) -> Pixmap {
    let opt = usvg::Options::default();
    let tree = usvg::Tree::from_str(svg, &opt).expect("valid embedded SVG");
    let mut pixmap = Pixmap::new(size.max(1), size.max(1)).expect("nonzero pixmap");
    let ts = tree.size();
    let sx = size as f32 / ts.width();
    let sy = size as f32 / ts.height();
    let scale = sx.min(sy);
    let tx = (size as f32 - ts.width() * scale) * 0.5;
    let ty = (size as f32 - ts.height() * scale) * 0.5;
    let transform = UTransform::from_scale(scale, scale).post_translate(tx, ty);
    resvg::render(&tree, transform, &mut pixmap.as_mut());
    pixmap
}

// ---------------------------------------------------------------------------
// Procedural world (deterministic, hash-based)
// ---------------------------------------------------------------------------

/// Deterministic hash (splitmix64-ish) so the world is stable as it scrolls.
fn hash(n: i64) -> u64 {
    let mut x = (n as u64).wrapping_add(0x9E3779B97F4A7C15);
    x = (x ^ (x >> 30)).wrapping_mul(0xBF58476D1CE4E5B9);
    x = (x ^ (x >> 27)).wrapping_mul(0x94D049BB133111EB);
    x ^ (x >> 31)
}

/// Combine two grid coordinates into one hash input.
fn hash2(gx: i64, gy: i64) -> u64 {
    hash(gx.wrapping_mul(0x100000001B3).wrapping_add(gy))
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum Kind {
    Empty,
    Mountain,
    Forest,
    Village,
    Castle,
}

/// What (if anything) occupies the grid cell (gx, gy).
fn cell_kind(gx: i64, gy: i64) -> Kind {
    let h = hash2(gx, gy);
    // Roughly half the cells are empty land so the map stays uncluttered.
    match h % 16 {
        0 | 1 | 2 => Kind::Mountain,
        3 | 4 | 5 | 6 => Kind::Forest,
        7 | 8 => Kind::Village,
        9 => Kind::Castle,
        _ => Kind::Empty,
    }
}

/// World-space center of the feature in cell (gx, gy), with a deterministic
/// jitter so the grid doesn't look like a grid.
fn cell_center(gx: i64, gy: i64) -> (i64, i64) {
    let h = hash2(gx, gy);
    let jx = (h % 33) as i64 - 16;
    let jy = ((h >> 8) % 33) as i64 - 16;
    (gx * SLOT + SLOT / 2 + jx, gy * SLOT + SLOT / 2 + jy)
}

// ---------------------------------------------------------------------------
// Canvas compositing
// ---------------------------------------------------------------------------

/// Blit a feature pixmap centered at screen (cx, cy).
fn blit_centered(canvas: &mut Pixmap, sprite: &Pixmap, cx: f32, cy: f32) {
    let x = (cx - sprite.width() as f32 * 0.5).round();
    let y = (cy - sprite.height() as f32 * 0.5).round();
    canvas.draw_pixmap(
        x as i32,
        y as i32,
        sprite.as_ref(),
        &tiny_skia::PixmapPaint::default(),
        SkTransform::identity(),
        None,
    );
}

// ---------------------------------------------------------------------------
// Render
// ---------------------------------------------------------------------------

fn render(cfg: Res<Cfg>, scene: Res<Scene>, assets: Res<Assets>) {
    let (w, h) = (cfg.width, cfg.height);
    let pan = scene.pan;

    let mut canvas = Pixmap::new(w, h).expect("nonzero canvas");
    canvas.fill(Color::WHITE);

    // Visible grid range (+ margin so features straddling edges still draw).
    let margin = SLOT;
    let gx0 = (-margin).div_euclid(SLOT);
    let gx1 = (w as i64 + margin).div_euclid(SLOT);
    let gy0 = (pan - margin).div_euclid(SLOT);
    let gy1 = (pan + h as i64 + margin).div_euclid(SLOT);

    // World -> screen: x is identity (we pan along Y); y subtracts the pan.
    let to_screen = |wx: i64, wy: i64| -> (f32, f32) { (wx as f32, (wy - pan) as f32) };

    // --- 1. Roads: connect each settlement to its nearest settlement
    // neighbour to the right and below, forming a small network. Drawn first
    // so feature sprites sit on top of the roads. ---
    let mut paint = Paint::default();
    paint.set_color(Color::from_rgba8(0, 0, 0, 255));
    paint.anti_alias = true;
    let mut stroke = Stroke::default();
    stroke.width = 1.4;
    stroke.line_cap = tiny_skia::LineCap::Round;

    let is_settlement = |k: Kind| matches!(k, Kind::Village | Kind::Castle);

    let mut road = PathBuilder::new();
    let mut any_road = false;
    for gx in gx0..=gx1 {
        for gy in gy0..=gy1 {
            if !is_settlement(cell_kind(gx, gy)) {
                continue;
            }
            let (ax, ay) = cell_center(gx, gy);
            // Connect to the next settlement found scanning right, then down.
            for (ngx, ngy) in [(gx + 1, gy), (gx, gy + 1), (gx + 1, gy + 1)] {
                if is_settlement(cell_kind(ngx, ngy)) {
                    let (bx, by) = cell_center(ngx, ngy);
                    let (sax, say) = to_screen(ax, ay);
                    let (sbx, sby) = to_screen(bx, by);
                    road.move_to(sax, say);
                    road.line_to(sbx, sby);
                    any_road = true;
                }
            }
        }
    }
    if any_road {
        if let Some(path) = road.finish() {
            canvas.stroke_path(&path, &paint, &stroke, SkTransform::identity(), None);
        }
    }

    // --- 2. Feature sprites. Mountains first (they read as terrain), then
    // forests, then settlements on top. ---
    let draw_pass = |canvas: &mut Pixmap, want: Kind| {
        for gx in gx0..=gx1 {
            for gy in gy0..=gy1 {
                let k = cell_kind(gx, gy);
                if k != want {
                    continue;
                }
                let (wx, wy) = cell_center(gx, gy);
                let (sx, sy) = to_screen(wx, wy);
                let sprite = match k {
                    Kind::Mountain => &assets.mountain,
                    Kind::Forest => &assets.forest,
                    Kind::Village => &assets.village,
                    Kind::Castle => &assets.castle,
                    Kind::Empty => continue,
                };
                blit_centered(canvas, sprite, sx, sy);
            }
        }
    };
    draw_pass(&mut canvas, Kind::Mountain);
    draw_pass(&mut canvas, Kind::Forest);
    draw_pass(&mut canvas, Kind::Village);
    draw_pass(&mut canvas, Kind::Castle);

    // --- 3. Birds: a few sparse fliers drifting across the map. Each has a
    // deterministic base path; the tick advances it so they appear to move. ---
    const N_BIRDS: u64 = 4;
    for b in 0..N_BIRDS {
        let seed = hash(b as i64 * 131 + 7);
        // Slow drift; wrap around the screen with margin.
        let span_x = (w + 40) as f64;
        let span_y = (h + 40) as f64;
        let vx = 1.0 + (seed % 3) as f64 * 0.7;
        let vy = 0.6 + ((seed >> 8) % 3) as f64 * 0.5;
        let phase_x = (seed % 1000) as f64;
        let phase_y = ((seed >> 16) % 1000) as f64;
        let t = scene.tick as f64;
        let bx = ((phase_x + t * vx) % span_x) - 20.0;
        let by = ((phase_y + t * vy) % span_y) - 20.0;
        blit_centered(&mut canvas, &assets.bird, bx as f32, by as f32);
    }

    // --- 4. Convert canvas (premultiplied RGBA, black on white) to grayscale
    // and write atomically. ---
    let mut gray = GrayImage::new(w, h);
    for (i, px) in canvas.pixels().iter().enumerate() {
        // tiny-skia pixels are premultiplied; with an opaque white background
        // the channels are already straight. Luma from the demultiplied RGB.
        let a = px.alpha();
        let (r, g, b) = if a == 0 {
            (255, 255, 255)
        } else {
            (px.red(), px.green(), px.blue())
        };
        let lum = (0.299 * r as f32 + 0.587 * g as f32 + 0.114 * b as f32).round() as u8;
        let x = (i as u32) % w;
        let y = (i as u32) / w;
        gray.put_pixel(x, y, Luma([lum]));
    }

    let tmp = cfg.out.with_extension("png.tmp");
    if image::DynamicImage::ImageLuma8(gray)
        .save_with_format(&tmp, image::ImageFormat::Png)
        .is_ok()
    {
        let _ = std::fs::rename(&tmp, &cfg.out);
    }
}
