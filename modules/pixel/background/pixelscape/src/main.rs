//! pixelscape — an auto-playing, pure 1-bit black-and-white scrolling map
//! rendered headlessly for the "pixel" quickshell family's background.
//!
//! This is a *top-down* Carcassonne-style board view: a grid of square tiles,
//! each carrying terrain — fields (with the odd grazing sheep), walled cities
//! and towns, villages, castles, monasteries/cloisters, forests and mountains —
//! linked by a road network that crosses tile edges. The whole board pans
//! rightward once per tick, so features scroll off the left edge and new
//! terrain continuously enters from the right.
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

/// Side length of a Carcassonne tile, in world units (== pixels at 1:1). Small
/// enough that several tiles fit on screen so the board reads as a grid.
const TILE: i64 = 60;
/// World units the camera pans (rightward, +X) per tick.
const PAN_PER_TICK: i64 = 6;
/// Rendered side length of the main per-tile feature, in pixels.
const FEATURE_PX: f32 = 50.0;
/// Rendered side length of small scatter sprites (lone trees, sheep), in pixels.
const SMALL_PX: f32 = 18.0;
/// Rendered size of a bird, in pixels.
const BIRD_PX: f32 = 14.0;

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

/// Hash keyed on the *edge* shared by two horizontally-adjacent tiles
/// (gx,gy)|(gx+1,gy). Order-independent because both neighbours compute the
/// same key, so road connections always agree across the seam.
fn edge_h_hash(gx: i64, gy: i64) -> u64 {
    hash(0x51_u64.wrapping_mul(0x100000001B3) as i64 ^ hash2(gx, gy) as i64 ^ hash2(gx + 1, gy).rotate_left(17) as i64)
}

/// Hash keyed on the edge shared by two vertically-adjacent tiles
/// (gx,gy)|(gx,gy+1).
fn edge_v_hash(gx: i64, gy: i64) -> u64 {
    hash(0xA7_u64.wrapping_mul(0x100000001B3) as i64 ^ hash2(gx, gy) as i64 ^ hash2(gx, gy + 1).rotate_left(17) as i64)
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

/// What terrain occupies tile (gx, gy).
fn cell_kind(gx: i64, gy: i64) -> Kind {
    let h = hash2(gx, gy);
    match h % 32 {
        0 | 1 | 2 => Kind::Mountain,
        3 | 4 | 5 | 6 | 7 => Kind::Forest,
        8 | 9 | 10 => Kind::Village,
        11 | 12 => Kind::City,
        13 => Kind::Castle,
        14 | 15 => Kind::Monastery,
        // Remainder: open fields (occasionally with a grazing sheep).
        _ => Kind::Field,
    }
}

fn is_settlement(k: Kind) -> bool {
    matches!(k, Kind::Village | Kind::City | Kind::Castle | Kind::Monastery)
}

/// World-space center of tile (gx, gy). Tiles are on a strict grid so the board
/// reads as Carcassonne tiles; only the *content* jitters, not the cell.
fn cell_center(gx: i64, gy: i64) -> (i64, i64) {
    (gx * TILE + TILE / 2, gy * TILE + TILE / 2)
}

/// Does a road leave this tile through its right / bottom edge? Keyed on the
/// shared-edge hash so the neighbour sees the same answer (network is
/// continuous). Roads are biased toward connecting settlements.
fn road_right(gx: i64, gy: i64) -> bool {
    let want = is_settlement(cell_kind(gx, gy)) || is_settlement(cell_kind(gx + 1, gy));
    let h = edge_h_hash(gx, gy);
    if want {
        h % 5 != 0 // strong link near settlements
    } else {
        h % 3 == 0 // sparser roads through open country
    }
}

fn road_down(gx: i64, gy: i64) -> bool {
    let want = is_settlement(cell_kind(gx, gy)) || is_settlement(cell_kind(gx, gy + 1));
    let h = edge_v_hash(gx, gy);
    if want {
        h % 5 != 0
    } else {
        h % 4 == 0
    }
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

    // Visible tile range (+ margin so features straddling edges still draw).
    let margin = TILE;
    let gx0 = (pan - margin).div_euclid(TILE);
    let gx1 = (pan + w as i64 + margin).div_euclid(TILE);
    let gy0 = (-margin).div_euclid(TILE);
    let gy1 = (h as i64 + margin).div_euclid(TILE);

    // World -> screen: pan along +X (subtract pan from world X); y is identity.
    let to_screen = |wx: i64, wy: i64| -> (f32, f32) { ((wx - pan) as f32, wy as f32) };

    let black = {
        let mut p = Paint::default();
        p.set_color(Color::from_rgba8(0, 0, 0, 255));
        p.anti_alias = true;
        p
    };

    // --- 1. Tile grid: a subtle thin lattice so the board reads as
    // Carcassonne tiles. Drawn faint-thin (it will threshold to crisp 1-px
    // lines after the 1-bit pass). ---
    {
        let mut grid = PathBuilder::new();
        for gx in gx0..=gx1 + 1 {
            let (sx, _) = to_screen(gx * TILE, 0);
            grid.move_to(sx, 0.0);
            grid.line_to(sx, h as f32);
        }
        for gy in gy0..=gy1 + 1 {
            let (_, sy) = to_screen(0, gy * TILE);
            grid.move_to(0.0, sy);
            grid.line_to(w as f32, sy);
        }
        if let Some(path) = grid.finish() {
            let mut s = Stroke::default();
            s.width = 1.0;
            canvas.stroke_path(&path, &black, &s, SkTransform::identity(), None);
        }
    }

    // --- 2. Roads. A road that crosses an edge is drawn as a segment from the
    // tile centre to the shared edge midpoint, on both tiles, so the network is
    // continuous across seams and links settlements. Drawn before sprites so
    // features sit on top. ---
    {
        let mut roads = PathBuilder::new();
        let mut any = false;
        let seg = |pb: &mut PathBuilder, ax: f32, ay: f32, bx: f32, by: f32| {
            pb.move_to(ax, ay);
            pb.line_to(bx, by);
        };
        for gx in gx0..=gx1 {
            for gy in gy0..=gy1 {
                let (cx, cy) = cell_center(gx, gy);
                let (scx, scy) = to_screen(cx, cy);
                if road_right(gx, gy) {
                    // edge midpoint on this tile's right side
                    let (ex, ey) = to_screen(gx * TILE + TILE, cy);
                    seg(&mut roads, scx, scy, ex, ey);
                    // mirror from the right neighbour's centre to the same point
                    let (ncx, ncy) = cell_center(gx + 1, gy);
                    let (nscx, nscy) = to_screen(ncx, ncy);
                    seg(&mut roads, nscx, nscy, ex, ey);
                    any = true;
                }
                if road_down(gx, gy) {
                    let (ex, ey) = to_screen(cx, gy * TILE + TILE);
                    seg(&mut roads, scx, scy, ex, ey);
                    let (ncx, ncy) = cell_center(gx, gy + 1);
                    let (nscx, nscy) = to_screen(ncx, ncy);
                    seg(&mut roads, nscx, nscy, ex, ey);
                    any = true;
                }
            }
        }
        if any {
            if let Some(path) = roads.finish() {
                let mut s = Stroke::default();
                s.width = 2.2;
                s.line_cap = tiny_skia::LineCap::Round;
                canvas.stroke_path(&path, &black, &s, SkTransform::identity(), None);
            }
        }
    }

    // --- 3. Feature sprites, painted terrain-first (mountains/forests) then
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

    // Field scatter: a couple of deterministic lone trees and/or a sheep per
    // open field tile, jittered within the tile, for fine extra detail.
    for gx in gx0..=gx1 {
        for gy in gy0..=gy1 {
            if cell_kind(gx, gy) != Kind::Field {
                continue;
            }
            let h0 = hash2(gx, gy);
            let n = (h0 % 4) as i64; // 0..3 scatter items
            for i in 0..n {
                let hi = hash(h0 as i64 ^ (i * 0x9E37));
                let jx = (hi % (TILE as u64 - 16)) as i64 - (TILE - 16) / 2;
                let jy = ((hi >> 20) % (TILE as u64 - 16)) as i64 - (TILE - 16) / 2;
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

    // --- 4. Birds: a few sparse fliers drifting across the map. ---
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

    // --- 5. Threshold the whole composite to pure 1-bit black/white. resvg /
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
