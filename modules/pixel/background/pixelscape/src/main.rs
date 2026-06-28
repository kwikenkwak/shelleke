//! pixelscape — an auto-playing, black-and-white scrolling landscape rendered
//! headlessly for the "pixel" quickshell family's background.
//!
//! Bevy drives the simulation/loop (MinimalPlugins + ScheduleRunnerPlugin at
//! 2 FPS). Each tick a procedurally-generated landscape (rolling ground,
//! mountains, forests, villages, castles and the roads between settlements) is
//! scrolled left, rasterized to a 1-bit-ish grayscale image, and written
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

const BLACK: u8 = 0;
const WHITE: u8 = 255;

#[derive(Resource)]
struct Cfg {
    width: u32,
    height: u32,
    baseline: i32,
    out: PathBuf,
    scroll_per_tick: i64,
}

#[derive(Resource, Default)]
struct Scene {
    scroll: i64,
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

    App::new()
        .add_plugins(
            MinimalPlugins.set(ScheduleRunnerPlugin::run_loop(Duration::from_secs_f64(0.5))),
        )
        .insert_resource(Cfg {
            width,
            height,
            baseline: (height as f32 * 0.72) as i32,
            out,
            scroll_per_tick: 6,
        })
        .insert_resource(Scene::default())
        .add_systems(Update, (advance, render).chain())
        .run();
}

fn advance(cfg: Res<Cfg>, mut scene: ResMut<Scene>) {
    scene.scroll = scene.scroll.wrapping_add(cfg.scroll_per_tick);
}

// ---------------------------------------------------------------------------
// Procedural helpers
// ---------------------------------------------------------------------------

/// Deterministic hash (splitmix64-ish) so the world is stable as it scrolls.
fn hash(n: i64) -> u64 {
    let mut x = (n as u64).wrapping_add(0x9E3779B97F4A7C15);
    x = (x ^ (x >> 30)).wrapping_mul(0xBF58476D1CE4E5B9);
    x = (x ^ (x >> 27)).wrapping_mul(0x94D049BB133111EB);
    x ^ (x >> 31)
}

/// Ground surface height (y) for a given world column.
fn ground_y(world_x: i64, baseline: i32) -> i32 {
    let x = world_x as f64;
    let hills = (x * 0.018).sin() * 9.0 + (x * 0.0052).sin() * 16.0 + (x * 0.043).sin() * 3.5;
    baseline - hills.round() as i32
}

#[derive(Clone, Copy, PartialEq)]
enum Kind {
    Mountain,
    Forest,
    Village,
    Castle,
}

const SLOT: i64 = 120;

fn slot_kind(k: i64) -> Kind {
    match hash(k * 2 + 1) % 10 {
        0 | 1 | 2 => Kind::Mountain,
        3 | 4 | 5 => Kind::Forest,
        6 | 7 => Kind::Village,
        _ => Kind::Castle,
    }
}

/// World-space center column of the feature in slot `k`.
fn slot_center(k: i64) -> i64 {
    k * SLOT + SLOT / 2 + (hash(k) % 40) as i64 - 20
}

// ---------------------------------------------------------------------------
// Raster helpers
// ---------------------------------------------------------------------------

#[inline]
fn put(img: &mut GrayImage, x: i32, y: i32, v: u8) {
    if x >= 0 && y >= 0 && (x as u32) < img.width() && (y as u32) < img.height() {
        img.put_pixel(x as u32, y as u32, Luma([v]));
    }
}

fn fill_rect(img: &mut GrayImage, x: i32, y: i32, w: i32, h: i32, v: u8) {
    for j in 0..h {
        for i in 0..w {
            put(img, x + i, y + j, v);
        }
    }
}

/// Filled isosceles triangle pointing up, apex at (cx, base_y - height).
fn tri_up(img: &mut GrayImage, cx: i32, base_y: i32, half: i32, height: i32, v: u8) {
    if height <= 0 {
        return;
    }
    for dy in 0..=height {
        let frac = dy as f32 / height as f32;
        let hw = (half as f32 * (1.0 - frac)).round() as i32;
        let y = base_y - dy;
        for x in (cx - hw)..=(cx + hw) {
            put(img, x, y, v);
        }
    }
}

// ---------------------------------------------------------------------------
// Feature drawing (all black silhouettes on white sky, sitting on the ground)
// ---------------------------------------------------------------------------

fn draw_mountain(img: &mut GrayImage, sx: i32, base_y: i32, seed: u64) {
    let half = 30 + (seed % 26) as i32;
    let height = 64 + (seed % 56) as i32;
    tri_up(img, sx, base_y, half, height, BLACK);
    // Snow cap: a small white triangle near the peak.
    let cap_h = (height / 4).max(6);
    tri_up(img, sx, base_y - (height - cap_h), (half * cap_h) / height, cap_h, WHITE);
}

fn draw_tree(img: &mut GrayImage, sx: i32, base_y: i32, h: i32) {
    // trunk
    fill_rect(img, sx - 1, base_y - 2, 2, 3, BLACK);
    // two stacked pine tiers
    tri_up(img, sx, base_y - 1, 5, h - 4, BLACK);
    tri_up(img, sx, base_y - (h / 2), 4, h - 6, BLACK);
}

fn draw_forest(img: &mut GrayImage, sx: i32, scroll: i64, baseline: i32, seed: u64) {
    let count = 5 + (seed % 4) as i32;
    let spacing = 11;
    let start = sx - (count * spacing) / 2;
    for i in 0..count {
        let tx = start + i * spacing;
        let gy = ground_y(scroll + tx as i64, baseline);
        let h = 14 + (hash(seed as i64 + i as i64) % 9) as i32;
        draw_tree(img, tx, gy, h);
    }
}

fn draw_house(img: &mut GrayImage, sx: i32, base_y: i32, w: i32, body_h: i32) {
    fill_rect(img, sx - w / 2, base_y - body_h, w, body_h, BLACK);
    // roof
    tri_up(img, sx, base_y - body_h, w / 2 + 2, w / 2 + 2, BLACK);
}

fn draw_village(img: &mut GrayImage, sx: i32, scroll: i64, baseline: i32, seed: u64) {
    let count = 2 + (seed % 3) as i32;
    let spacing = 18;
    let start = sx - (count * spacing) / 2;
    for i in 0..count {
        let hx = start + i * spacing;
        let gy = ground_y(scroll + hx as i64, baseline);
        let bh = 10 + (hash(seed as i64 + i as i64 * 7) % 5) as i32;
        draw_house(img, hx, gy, 13, bh);
    }
}

fn draw_castle(img: &mut GrayImage, sx: i32, base_y: i32, seed: u64) {
    let w = 30;
    let body_h = 24 + (seed % 8) as i32;
    let left = sx - w / 2;
    fill_rect(img, left, base_y - body_h, w, body_h, BLACK);
    // Two taller towers
    fill_rect(img, left - 4, base_y - body_h - 8, 7, body_h + 8, BLACK);
    fill_rect(img, left + w - 3, base_y - body_h - 8, 7, body_h + 8, BLACK);
    // Crenellations along the main wall top
    let top = base_y - body_h;
    let mut cx = left;
    while cx < left + w {
        fill_rect(img, cx, top - 4, 3, 4, BLACK);
        cx += 6;
    }
    // Gate (white notch)
    fill_rect(img, sx - 3, base_y - 9, 6, 9, WHITE);
    // Flag on the left tower
    fill_rect(img, left - 1, base_y - body_h - 16, 1, 8, BLACK);
    tri_up(img, left + 2, base_y - body_h - 11, 4, 4, BLACK);
}

// ---------------------------------------------------------------------------
// Render
// ---------------------------------------------------------------------------

fn render(cfg: Res<Cfg>, scene: Res<Scene>) {
    let (w, h, baseline, scroll) = (cfg.width, cfg.height, cfg.baseline, scene.scroll);
    let mut img = GrayImage::from_pixel(w, h, Luma([WHITE])); // white sky

    let k0 = scroll.div_euclid(SLOT) - 2;
    let k1 = (scroll + w as i64).div_euclid(SLOT) + 2;

    // 1. Mountains (far) — drawn first so the ground fill covers their base.
    for k in k0..=k1 {
        if slot_kind(k) == Kind::Mountain {
            let wc = slot_center(k);
            let sx = (wc - scroll) as i32;
            draw_mountain(&mut img, sx, ground_y(wc, baseline) + 6, hash(k * 7 + 3));
        }
    }

    // 2. Ground fill (black) below the rolling surface line.
    for sx in 0..w as i32 {
        let gy = ground_y(scroll + sx as i64, baseline);
        for y in gy..h as i32 {
            put(&mut img, sx, y, BLACK);
        }
    }

    // 3. Roads: a dashed white path on the ground between consecutive settlements.
    let mut prev_settlement: Option<i32> = None;
    for k in k0..=k1 {
        let kind = slot_kind(k);
        if kind == Kind::Village || kind == Kind::Castle {
            let sx = (slot_center(k) - scroll) as i32;
            if let Some(px) = prev_settlement {
                for x in px..=sx {
                    if (x / 3) % 2 == 0 {
                        let gy = ground_y(scroll + x as i64, baseline);
                        put(&mut img, x, gy + 2, WHITE);
                        put(&mut img, x, gy + 3, WHITE);
                    }
                }
            }
            prev_settlement = Some(sx);
        }
    }

    // 4. Foreground features (forests, villages, castles) on the surface.
    for k in k0..=k1 {
        let wc = slot_center(k);
        let sx = (wc - scroll) as i32;
        let gy = ground_y(wc, baseline);
        match slot_kind(k) {
            Kind::Forest => draw_forest(&mut img, sx, scroll, baseline, hash(k * 11 + 5)),
            Kind::Village => draw_village(&mut img, sx, scroll, baseline, hash(k * 13 + 9)),
            Kind::Castle => draw_castle(&mut img, sx, gy, hash(k * 17 + 2)),
            Kind::Mountain => {}
        }
    }

    // Atomic write so quickshell never reads a half-written frame.
    let tmp = cfg.out.with_extension("png.tmp");
    if image::DynamicImage::ImageLuma8(img)
        .save_with_format(&tmp, image::ImageFormat::Png)
        .is_ok()
    {
        let _ = std::fs::rename(&tmp, &cfg.out);
    }
}
