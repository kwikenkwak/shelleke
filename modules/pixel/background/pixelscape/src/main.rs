//! pixelscape — an auto-playing, pure 1-bit black-and-white scrolling map
//! rendered headlessly for the "pixel" quickshell family's background.
//!
//! This is one continuous, zoomed-out landscape (no tile grid) drawn in the
//! illustrative 3/4 bird's-eye style of Carcassonne tile artwork: walled cities
//! with church spires, castles with round conical-roofed towers and a keep,
//! little clusters of pitched-roof village houses, monasteries with a bell
//! tower, plus forests, mountains, scattered field trees and grazing sheep —
//! all linked by a road network between settlements. The view pans gently
//! rightward each tick, so features scroll off the left edge and new terrain
//! continuously enters from the right.
//!
//! The world is deterministic and hash-based, so it is perfectly stable as it
//! scrolls. Bevy drives the loop (MinimalPlugins + ScheduleRunnerPlugin at
//! 2 FPS), headless, no GPU/window. Each frame is rendered to a tiny-skia
//! Pixmap (white background, black shapes), then **every pixel is thresholded
//! to pure black (0) or pure white (255)** — no anti-aliased grays survive — so
//! the saved PNG is crisp 1-bit pixel-art that quickshell upscales
//! nearest-neighbour. Everything is black on white; quickshell inverts it for
//! dark mode.
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
const SVG_TREE: &str = include_str!("../assets/tree.svg");
const SVG_VILLAGE: &str = include_str!("../assets/village.svg");
const SVG_CITY: &str = include_str!("../assets/city.svg");
const SVG_CASTLE: &str = include_str!("../assets/castle.svg");
const SVG_MONASTERY: &str = include_str!("../assets/monastery.svg");
const SVG_SHEEP: &str = include_str!("../assets/sheep.svg");
const SVG_BIRD: &str = include_str!("../assets/bird.svg");

// ---------------------------------------------------------------------------
// World layout constants.
// ---------------------------------------------------------------------------

/// Spacing between feature slots in world units (== pixels at 1:1). Zoomed
/// out: a large slot so much open landscape (fields/forests/mountains) sits
/// between settlements and many slots fit on screen.
const SLOT: i64 = 90;
/// World units the camera pans (rightward, +X) per tick. Small for a slow,
/// gentle drift.
const PAN_PER_TICK: i64 = 3;
/// Rendered side length of the main feature sprite, in pixels (smaller than the
/// slot, so features read as little illustrations dotted over the landscape).
const FEATURE_PX: f32 = 38.0;
/// Rendered side length of small scatter sprites (lone trees, sheep), in pixels.
const SMALL_PX: f32 = 14.0;
/// Rendered size of a bird, in pixels.
const BIRD_PX: f32 = 12.0;

#[derive(Resource)]
struct Cfg {
    width: u32,
    height: u32,
    out: PathBuf,
}

#[derive(Resource, Default)]
struct Scene {
    /// World X offset of the left edge of the viewport. Grows each tick (the
    /// camera advances along +X, so the board pans leftward past the window).
    pan: i64,
    /// Tick counter, used to animate birds.
    tick: u64,
}

/// Pre-rendered SVG pixmaps, rasterized once at startup.
#[derive(Resource)]
struct Assets {
    mountain: Pixmap,
    forest: Pixmap,
    tree: Pixmap,
    village: Pixmap,
    city: Pixmap,
    castle: Pixmap,
    monastery: Pixmap,
    sheep: Pixmap,
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
        tree: rasterize_svg(SVG_TREE, SMALL_PX as u32),
        village: rasterize_svg(SVG_VILLAGE, FEATURE_PX as u32),
        city: rasterize_svg(SVG_CITY, FEATURE_PX as u32),
        castle: rasterize_svg(SVG_CASTLE, FEATURE_PX as u32),
        monastery: rasterize_svg(SVG_MONASTERY, FEATURE_PX as u32),
        sheep: rasterize_svg(SVG_SHEEP, SMALL_PX as u32),
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
    Field,
    Mountain,
    Forest,
    Village,
    City,
    Castle,
    Monastery,
}

/// What terrain occupies slot (gx, gy). The landscape is continuous — slots are
/// just a placement lattice, not drawn tiles — and mostly open country so the
/// zoomed-out view shows lots of fields/forests/mountains between settlements.
fn cell_kind(gx: i64, gy: i64) -> Kind {
    let h = hash2(gx, gy);
    match h % 40 {
        0 | 1 | 2 | 3 => Kind::Mountain,
        4 | 5 | 6 | 7 | 8 | 9 => Kind::Forest,
        10 | 11 | 12 => Kind::Village,
        13 | 14 => Kind::City,
        15 => Kind::Castle,
        16 | 17 => Kind::Monastery,
        // Remainder: open fields (occasionally with a grazing sheep / tree).
        _ => Kind::Field,
    }
}

fn is_settlement(k: Kind) -> bool {
    matches!(k, Kind::Village | Kind::City | Kind::Castle | Kind::Monastery)
}

/// World-space center of the feature in slot (gx, gy), with a deterministic
/// jitter so the placement lattice never reads as a grid (no tile seams).
fn cell_center(gx: i64, gy: i64) -> (i64, i64) {
    let h = hash2(gx, gy);
    let span = SLOT / 2; // jitter up to +-(span/2) within the slot
    let jx = (h % span as u64) as i64 - span / 2;
    let jy = ((h >> 12) % span as u64) as i64 - span / 2;
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

    // Visible slot range (+ margin so features straddling edges still draw).
    let margin = SLOT;
    let gx0 = (pan - margin).div_euclid(SLOT);
    let gx1 = (pan + w as i64 + margin).div_euclid(SLOT);
    let gy0 = (-margin).div_euclid(SLOT);
    let gy1 = (h as i64 + margin).div_euclid(SLOT);

    // World -> screen: pan along +X (subtract pan from world X); y is identity.
    let to_screen = |wx: i64, wy: i64| -> (f32, f32) { ((wx - pan) as f32, wy as f32) };

    let black = {
        let mut p = Paint::default();
        p.set_color(Color::from_rgba8(0, 0, 0, 255));
        p.anti_alias = true;
        p
    };

    // --- 1. Roads: connect each settlement to nearby settlements (the next
    // ones found scanning right, down, and diagonally), forming a continuous
    // network across the open landscape. Drawn first so feature sprites sit on
    // top. No tile grid — this is one continuous landscape. ---
    {
        let mut roads = PathBuilder::new();
        let mut any = false;
        for gx in gx0 - 1..=gx1 + 1 {
            for gy in gy0 - 1..=gy1 + 1 {
                if !is_settlement(cell_kind(gx, gy)) {
                    continue;
                }
                let (ax, ay) = cell_center(gx, gy);
                let (sax, say) = to_screen(ax, ay);
                for (ngx, ngy) in [(gx + 1, gy), (gx, gy + 1), (gx + 1, gy + 1), (gx + 1, gy - 1)] {
                    if is_settlement(cell_kind(ngx, ngy)) {
                        let (bx, by) = cell_center(ngx, ngy);
                        let (sbx, sby) = to_screen(bx, by);
                        roads.move_to(sax, say);
                        roads.line_to(sbx, sby);
                        any = true;
                    }
                }
            }
        }
        if any {
            if let Some(path) = roads.finish() {
                let mut s = Stroke::default();
                s.width = 1.6;
                s.line_cap = tiny_skia::LineCap::Round;
                canvas.stroke_path(&path, &black, &s, SkTransform::identity(), None);
            }
        }
    }

    // --- 2. Feature sprites, painted terrain-first (mountains/forests) then
    // settlements on top. Fields get small scatter (lone trees + sheep) for
    // density. ---
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
                    Kind::City => &assets.city,
                    Kind::Castle => &assets.castle,
                    Kind::Monastery => &assets.monastery,
                    Kind::Field => continue,
                };
                blit_centered(canvas, sprite, sx, sy);
            }
        }
    };
    draw_pass(&mut canvas, Kind::Mountain);
    draw_pass(&mut canvas, Kind::Forest);

    // Field scatter: a few deterministic lone trees and/or grazing sheep spread
    // across each open field slot, for fine extra detail over the open land.
    for gx in gx0..=gx1 {
        for gy in gy0..=gy1 {
            if cell_kind(gx, gy) != Kind::Field {
                continue;
            }
            let h0 = hash2(gx, gy);
            let n = (h0 % 5) as i64; // 0..4 scatter items
            let spread = SLOT - 24;
            for i in 0..n {
                let hi = hash(h0 as i64 ^ (i * 0x9E37));
                let jx = (hi % spread as u64) as i64 - spread / 2;
                let jy = ((hi >> 20) % spread as u64) as i64 - spread / 2;
                let (wx, wy) = cell_center(gx, gy);
                let (sx, sy) = to_screen(wx + jx, wy + jy);
                let sprite = if (hi >> 40) & 1 == 0 {
                    &assets.tree
                } else {
                    &assets.sheep
                };
                blit_centered(&mut canvas, sprite, sx, sy);
            }
        }
    }

    draw_pass(&mut canvas, Kind::Village);
    draw_pass(&mut canvas, Kind::City);
    draw_pass(&mut canvas, Kind::Castle);
    draw_pass(&mut canvas, Kind::Monastery);

    // --- 3. Birds: a few sparse fliers drifting across the map. ---
    const N_BIRDS: u64 = 5;
    for b in 0..N_BIRDS {
        let seed = hash(b as i64 * 131 + 7);
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

    // --- 4. Threshold the whole composite to pure 1-bit black/white. resvg /
    // tiny-skia anti-alias their edges into gray, which the user does not want;
    // we collapse every pixel to 0 or 255 (luma < 128 -> black, else white) so
    // the PNG contains only pure black and pure white. Then write atomically. ---
    let mut gray = GrayImage::new(w, h);
    for (i, px) in canvas.pixels().iter().enumerate() {
        let a = px.alpha();
        let (r, g, b) = if a == 0 {
            (255, 255, 255)
        } else {
            (px.red(), px.green(), px.blue())
        };
        let lum = 0.299 * r as f32 + 0.587 * g as f32 + 0.114 * b as f32;
        let bw: u8 = if lum < 128.0 { 0 } else { 255 };
        let x = (i as u32) % w;
        let y = (i as u32) / w;
        gray.put_pixel(x, y, Luma([bw]));
    }

    let tmp = cfg.out.with_extension("png.tmp");
    if image::DynamicImage::ImageLuma8(gray)
        .save_with_format(&tmp, image::ImageFormat::Png)
        .is_ok()
    {
        let _ = std::fs::rename(&tmp, &cfg.out);
    }
}
