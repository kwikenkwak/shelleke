//! pixelscape — an auto-playing, pure 1-bit black-and-white scrolling map
//! rendered headlessly for the "pixel" quickshell family's background.
//!
//! This is one continuous, zoomed-out landscape (no tile grid / no seams)
//! built from hand-authored pixel-art sprites blitted 1:1, so every element is
//! crisp and deliberate at the target resolution. A coarse value-noise biome
//! layer groups terrain naturally — woodlands (many forests together), mountain
//! ranges (chains of peaks), and settled plains (villages/towns/castles) — and
//! features are jittered so the underlying tile lattice never shows. Settlements
//! are linked by a wandering, zig-zagging road network. The view pans gently
//! rightward each tick, so features scroll off the left and new terrain enters
//! from the right.
//!
//! The world is deterministic and hash-based, so it is perfectly stable as it
//! scrolls. Bevy drives the loop (MinimalPlugins + ScheduleRunnerPlugin at
//! 2 FPS), headless, no GPU/window. Sprites are pure black-on-transparent
//! bitmaps composited onto a white canvas; the final frame is thresholded so it
//! contains **only pure black (0) and pure white (255)** — no anti-aliased
//! grays — giving crisp 1-bit pixel-art that quickshell upscales
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

mod sprites;
use sprites::Sprite;

// ---------------------------------------------------------------------------
// World layout constants.
// ---------------------------------------------------------------------------

/// Spacing between feature slots in world units (== pixels at 1:1). Zoomed
/// out so much open landscape sits between settlements.
const SLOT: i64 = 64;
/// World units the camera pans (rightward, +X) per tick. Small = slow drift.
const PAN_PER_TICK: i64 = 3;

#[derive(Resource)]
struct Cfg {
    width: u32,
    height: u32,
    out: PathBuf,
}

#[derive(Resource, Default)]
struct Scene {
    /// World X offset of the left edge of the viewport. Grows each tick (the
    /// camera advances along +X, so the world pans leftward past the window).
    pan: i64,
}

/// A 1-bit canvas: one byte per pixel, 0 = white (background), 1 = black.
struct Canvas {
    w: i64,
    h: i64,
    px: Vec<u8>,
}

impl Canvas {
    fn new(w: u32, h: u32) -> Self {
        Canvas {
            w: w as i64,
            h: h as i64,
            px: vec![0u8; (w * h) as usize],
        }
    }
    #[inline]
    fn set(&mut self, x: i64, y: i64) {
        if x >= 0 && y >= 0 && x < self.w && y < self.h {
            self.px[(y * self.w + x) as usize] = 1;
        }
    }
    /// Blit a sprite so its center lands at world->screen (cx, cy). `flip_x`
    /// mirrors horizontally (cheap extra variant). Black cells are drawn; '.'
    /// cells are transparent.
    fn blit(&mut self, s: &Sprite, cx: i64, cy: i64, flip_x: bool) {
        let ox = cx - (s.w as i64) / 2;
        let oy = cy - (s.h as i64) / 2;
        for ry in 0..s.h as i64 {
            for rx in 0..s.w as i64 {
                let srx = if flip_x { s.w as i64 - 1 - rx } else { rx };
                if s.get(srx as usize, ry as usize) {
                    self.set(ox + rx, oy + ry);
                }
            }
        }
    }
}

fn main() {
    let args: Vec<String> = std::env::args().collect();

    // One-shot SEGMENT mode (used by quickshell's smooth scroller):
    //   pixelscape segment <k> <OUT_PNG> <WIDTH> <HEIGHT>
    // Renders exactly one seamless slice of the world — the segment whose left
    // edge is world X = k*WIDTH — then exits. Adjacent segments tile perfectly
    // because the scene is a pure function of pan, so quickshell can lay several
    // side by side and slide them continuously.
    if args.get(1).map(|s| s.as_str()) == Some("segment") {
        let k: i64 = args.get(2).and_then(|s| s.parse().ok()).unwrap_or(0);
        let out = PathBuf::from(
            args.get(3)
                .cloned()
                .unwrap_or_else(|| "/tmp/quickshell/pixel-bg/seg.png".to_string()),
        );
        let width: u32 = args.get(4).and_then(|s| s.parse().ok()).unwrap_or(480);
        let height: u32 = args.get(5).and_then(|s| s.parse().ok()).unwrap_or(270);
        // Optional per-session seed: a shared world-X offset so every launch
        // shows a different stretch of the (infinite, deterministic) world. All
        // segments in a session pass the SAME seed, so they still tile seamlessly.
        // Multiplied by a large stride so nearby seeds look very different.
        let seed: i64 = args.get(6).and_then(|s| s.parse().ok()).unwrap_or(0);
        let world_x0 = seed.wrapping_mul(7_919).wrapping_add(k * width as i64);
        if let Some(parent) = out.parent() {
            let _ = std::fs::create_dir_all(parent);
        }
        let lib = sprites::Library::build();
        let gray = render_frame(world_x0, width, height, &lib);
        atomic_write(&out, gray);
        return;
    }

    // Legacy continuous mode (self-scrolling single frame), kept for back-compat.
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

    let lib = sprites::Library::build();

    App::new()
        .add_plugins(
            MinimalPlugins.set(ScheduleRunnerPlugin::run_loop(Duration::from_secs_f64(0.5))),
        )
        .insert_resource(Cfg { width, height, out })
        .insert_resource(Scene::default())
        .insert_resource(lib)
        .add_systems(Update, (advance, render).chain())
        .run();
}

fn advance(mut scene: ResMut<Scene>) {
    scene.pan = scene.pan.wrapping_add(PAN_PER_TICK);
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
    hash(gx.wrapping_mul(0x100000001B3).wrapping_add(gy).wrapping_add(0x51ED))
}

/// Smooth value noise in [0,1] over coarse cells of side `period` slots, using
/// bilinear interpolation of per-lattice-point random values. Salt picks an
/// independent noise field.
fn value_noise(gx: i64, gy: i64, period: i64, salt: i64) -> f32 {
    let fx = gx.div_euclid(period);
    let fy = gy.div_euclid(period);
    let tx = (gx.rem_euclid(period)) as f32 / period as f32;
    let ty = (gy.rem_euclid(period)) as f32 / period as f32;
    let corner = |cx: i64, cy: i64| -> f32 {
        (hash(hash2(cx, cy) as i64 ^ salt.wrapping_mul(0x2545F4914F6CDD1D)) % 1000) as f32 / 1000.0
    };
    let v00 = corner(fx, fy);
    let v10 = corner(fx + 1, fy);
    let v01 = corner(fx, fy + 1);
    let v11 = corner(fx + 1, fy + 1);
    // smoothstep the interpolants for organic blobs
    let sx = tx * tx * (3.0 - 2.0 * tx);
    let sy = ty * ty * (3.0 - 2.0 * ty);
    let a = v00 + (v10 - v00) * sx;
    let b = v01 + (v11 - v01) * sx;
    a + (b - a) * sy
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum Biome {
    Plains,   // open fields + settlements
    Woodland, // dense forests
    Range,    // mountain chains
}

/// Coarse biome for a slot, from two low-frequency noise fields. The dominant
/// field decides forest vs mountain vs open; thresholds keep plains common so
/// settlements have room.
fn biome(gx: i64, gy: i64) -> Biome {
    let forest = value_noise(gx, gy, 6, 1);
    let mountain = value_noise(gx, gy, 7, 2);
    // Mountains form ridges: bias toward a chain by sampling an elongated field.
    let ridge = value_noise(gx, gy * 3, 9, 5);
    if mountain * 0.45 + ridge * 0.55 > 0.62 {
        Biome::Range
    } else if forest > 0.55 {
        Biome::Woodland
    } else {
        Biome::Plains
    }
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

/// What occupies slot (gx, gy), conditioned on its biome so terrain clusters
/// naturally (woodland -> mostly forest, range -> mostly mountains, plains ->
/// fields with the occasional settlement).
fn cell_kind(gx: i64, gy: i64) -> Kind {
    let h = hash2(gx, gy);
    match biome(gx, gy) {
        Biome::Range => match h % 10 {
            0 | 1 | 2 | 3 | 4 | 5 | 6 => Kind::Mountain,
            7 => Kind::Forest,
            8 => Kind::Castle, // a fortress guarding the pass
            _ => Kind::Field,
        },
        Biome::Woodland => match h % 10 {
            0 | 1 | 2 | 3 | 4 | 5 | 6 => Kind::Forest,
            7 => Kind::Monastery, // a cloister in the woods
            8 => Kind::Village,
            _ => Kind::Field,
        },
        Biome::Plains => match h % 18 {
            0 | 1 | 2 => Kind::Village,
            3 | 4 => Kind::City,
            5 => Kind::Castle,
            6 => Kind::Monastery,
            7 => Kind::Forest, // a stray copse
            8 => Kind::Mountain, // a lone hill
            _ => Kind::Field,
        },
    }
}

fn is_settlement(k: Kind) -> bool {
    matches!(k, Kind::Village | Kind::City | Kind::Castle | Kind::Monastery)
}

/// World-space center of the feature in slot (gx, gy), jittered so the lattice
/// never reads as a grid.
fn cell_center(gx: i64, gy: i64) -> (i64, i64) {
    let h = hash2(gx, gy);
    let span = SLOT * 3 / 5; // jitter up to +-(span/2) within the slot
    let jx = (h % span as u64) as i64 - span / 2;
    let jy = ((h >> 12) % span as u64) as i64 - span / 2;
    (gx * SLOT + SLOT / 2 + jx, gy * SLOT + SLOT / 2 + jy)
}

// ---------------------------------------------------------------------------
// Zig-zagging roads
// ---------------------------------------------------------------------------

/// Draw a naturally wandering path from (ax,ay) to (bx,by) in *screen* space by
/// recursive midpoint displacement: the midpoint is nudged perpendicular to the
/// segment by a deterministic, hash-seeded amount, recursing until segments are
/// short, then the polyline is rasterized 1:1 with a 1px Bresenham line. Seed
/// keeps the same path stable while scrolling.
fn draw_wandering(canvas: &mut Canvas, ax: i64, ay: i64, bx: i64, by: i64, seed: u64) {
    let mut pts: Vec<(f32, f32)> = vec![(ax as f32, ay as f32), (bx as f32, by as f32)];
    // 4 rounds of displacement.
    for round in 0..4u32 {
        let mut next: Vec<(f32, f32)> = Vec::with_capacity(pts.len() * 2 - 1);
        for i in 0..pts.len() - 1 {
            let (x0, y0) = pts[i];
            let (x1, y1) = pts[i + 1];
            next.push((x0, y0));
            let mx = (x0 + x1) * 0.5;
            let my = (y0 + y1) * 0.5;
            let dx = x1 - x0;
            let dy = y1 - y0;
            let len = (dx * dx + dy * dy).sqrt().max(1.0);
            // perpendicular unit vector
            let px = -dy / len;
            let py = dx / len;
            let hh = hash(seed as i64 ^ (round as i64 * 7919) ^ (i as i64 * 104729));
            // displacement shrinks with each round (and never overshoots short segs)
            let amp = (len * 0.28).min(11.0) / (round as f32 + 1.0);
            let disp = ((hh % 2000) as f32 / 1000.0 - 1.0) * amp;
            next.push((mx + px * disp, my + py * disp));
        }
        next.push(*pts.last().unwrap());
        pts = next;
    }
    for i in 0..pts.len() - 1 {
        line(canvas, pts[i].0 as i64, pts[i].1 as i64, pts[i + 1].0 as i64, pts[i + 1].1 as i64);
    }
}

/// Bresenham 1px line, 1-bit.
fn line(canvas: &mut Canvas, x0: i64, y0: i64, x1: i64, y1: i64) {
    let dx = (x1 - x0).abs();
    let dy = -(y1 - y0).abs();
    let sx = if x0 < x1 { 1 } else { -1 };
    let sy = if y0 < y1 { 1 } else { -1 };
    let mut err = dx + dy;
    let (mut x, mut y) = (x0, y0);
    loop {
        canvas.set(x, y);
        if x == x1 && y == y1 {
            break;
        }
        let e2 = 2 * err;
        if e2 >= dy {
            err += dy;
            x += sx;
        }
        if e2 <= dx {
            err += dx;
            y += sy;
        }
    }
}

// ---------------------------------------------------------------------------
// Render
// ---------------------------------------------------------------------------

fn render(cfg: Res<Cfg>, scene: Res<Scene>, lib: Res<sprites::Library>) {
    let gray = render_frame(scene.pan, cfg.width, cfg.height, &lib);
    atomic_write(&cfg.out, gray);
}

/// Atomically write a grayscale PNG (tmp + rename) so readers never see a torn frame.
fn atomic_write(out: &std::path::Path, gray: GrayImage) {
    let tmp = out.with_extension("png.tmp");
    if image::DynamicImage::ImageLuma8(gray)
        .save_with_format(&tmp, image::ImageFormat::Png)
        .is_ok()
    {
        let _ = std::fs::rename(&tmp, out);
    }
}

/// Render one seamless frame whose viewport left edge is at world X = `pan`.
/// Pure function of `pan` + the deterministic world, so segment k (pan = k*w)
/// tiles perfectly with segment k+1.
fn render_frame(pan: i64, w: u32, h: u32, lib: &sprites::Library) -> GrayImage {
    let mut canvas = Canvas::new(w, h);

    // Visible slot range (+ margin so features straddling edges still draw).
    let margin = SLOT;
    let gx0 = (pan - margin).div_euclid(SLOT);
    let gx1 = (pan + w as i64 + margin).div_euclid(SLOT);
    let gy0 = (-margin).div_euclid(SLOT);
    let gy1 = (h as i64 + margin).div_euclid(SLOT);

    let to_screen = |wx: i64, wy: i64| -> (i64, i64) { (wx - pan, wy) };

    // --- 1. Roads: each settlement links to nearby settlements via a wandering
    // path, forming a connected, zig-zagging network. Drawn first so sprites
    // sit on top. ---
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
                    // Seed on world coords (not screen) so the wander is stable.
                    let seed = hash2(gx, gy) ^ hash2(ngx, ngy).rotate_left(21);
                    draw_wandering(&mut canvas, sax, say, sbx, sby, seed);
                }
            }
        }
    }

    // Helper to pick a deterministic sprite variant for a slot.
    let pick = |slot: &[Sprite], gx: i64, gy: i64| -> usize {
        if slot.is_empty() {
            0
        } else {
            (hash2(gx, gy).rotate_left(33) as usize) % slot.len()
        }
    };

    // --- 2. Terrain first (mountains, forests), then settlements on top. ---
    let draw_pass = |canvas: &mut Canvas, want: Kind| {
        for gx in gx0..=gx1 {
            for gy in gy0..=gy1 {
                let k = cell_kind(gx, gy);
                if k != want {
                    continue;
                }
                let (wx, wy) = cell_center(gx, gy);
                let (sx, sy) = to_screen(wx, wy);
                let h0 = hash2(gx, gy);
                let flip = (h0 >> 50) & 1 == 1;
                let slot: &[Sprite] = match k {
                    Kind::Mountain => &lib.mountain,
                    Kind::Forest => &lib.forest,
                    Kind::Village => &lib.village,
                    Kind::City => &lib.city,
                    Kind::Castle => &lib.castle,
                    Kind::Monastery => &lib.monastery,
                    Kind::Field => continue,
                };
                let idx = pick(slot, gx, gy);
                canvas.blit(&slot[idx], sx, sy, flip);
            }
        }
    };
    draw_pass(&mut canvas, Kind::Mountain);
    draw_pass(&mut canvas, Kind::Forest);

    // Field scatter: lone trees / grazing sheep spread across open field slots.
    for gx in gx0..=gx1 {
        for gy in gy0..=gy1 {
            if cell_kind(gx, gy) != Kind::Field {
                continue;
            }
            let h0 = hash2(gx, gy);
            let n = (h0 % 4) as i64; // 0..3 scatter items
            let spread = SLOT - 16;
            for i in 0..n {
                let hi = hash(h0 as i64 ^ (i * 0x9E37));
                let jx = (hi % spread as u64) as i64 - spread / 2;
                let jy = ((hi >> 20) % spread as u64) as i64 - spread / 2;
                let (wx, wy) = cell_center(gx, gy);
                let (sx, sy) = to_screen(wx + jx, wy + jy);
                let flip = (hi >> 41) & 1 == 1;
                if (hi >> 40) & 1 == 0 {
                    let idx = (hi as usize) % lib.tree.len();
                    canvas.blit(&lib.tree[idx], sx, sy, flip);
                } else {
                    canvas.blit(&lib.sheep, sx, sy, flip);
                }
            }
        }
    }

    draw_pass(&mut canvas, Kind::Village);
    draw_pass(&mut canvas, Kind::City);
    draw_pass(&mut canvas, Kind::Castle);
    draw_pass(&mut canvas, Kind::Monastery);

    // --- 3. Birds: sparse fliers placed in WORLD space (deterministic), so they
    // tile across segment boundaries and scroll smoothly with the map. ---
    let bcell: i64 = 96;
    let bx0 = (pan - 40).div_euclid(bcell);
    let bx1 = (pan + w as i64 + 40).div_euclid(bcell);
    for bk in bx0..=bx1 {
        let hh = hash(bk.wrapping_mul(2731).wrapping_add(17));
        if hh % 3 == 0 {
            continue; // gaps so birds stay irregular/sparse
        }
        let wx = bk * bcell + (hh % bcell as u64) as i64;
        let sky = ((h as u64) / 2).max(1);
        let wy = 8 + ((hh >> 16) % sky) as i64; // upper-half sky
        let sx = wx - pan;
        let idx = (hh as usize) % lib.bird.len();
        canvas.blit(&lib.bird[idx], sx, wy, (hh >> 3) & 1 == 1);
    }

    // --- 4. Emit pure 1-bit gray (only 0 and 255). The canvas is already 1-bit,
    // so this is a direct map: black cell -> 0, else -> 255. No AA ever entered. ---
    let mut gray = GrayImage::new(w, h);
    for y in 0..h {
        for x in 0..w {
            let on = canvas.px[(y as i64 * canvas.w + x as i64) as usize] == 1;
            gray.put_pixel(x, y, Luma([if on { 0 } else { 255 }]));
        }
    }
    gray
}
