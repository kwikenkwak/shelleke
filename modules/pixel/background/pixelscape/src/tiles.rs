//! Carcassonne-style 1-bit tile mode.
//!
//! Loads the 64x64 white-on-black tile PNGs from assets/tiles (filenames carry
//! the NESW edge code, e.g. `09-city-cap-n.CGGG.png`) and lays them out on an
//! infinite grid so every shared edge matches (G grass / R road / C city /
//! W water). Tiles are never rotated — the set ships every orientation with
//! buildings upright.
//!
//! The layout is generated column-by-column from a fixed origin with a
//! deterministic seeded ordering and full backtracking: at each cell the
//! candidates are the tiles whose W edge matches the left neighbour's E edge
//! and whose N edge matches the upper neighbour's S edge, tried in a
//! weight-biased random order. Backtracking is genuinely required — e.g. no
//! tile has water on both its N and W edge, so a greedy pass can dead-end.
//! Because the whole layout is a pure function of (seed, rows), any segment of
//! it can be re-derived independently and adjacent segments tile seamlessly.

use image::GenericImageView;
use std::path::PathBuf;

pub const TILE: i64 = 64;

pub struct Tile {
    /// 1-bit ink bitmap, already inverted to the canvas convention
    /// (true = black ink on the white canvas).
    pub bits: Vec<bool>,
    /// Edge terrain as bytes b'G' b'R' b'C' b'W', in N E S W order.
    pub edges: [u8; 4],
    /// Sampling weight: how eagerly the layouter tries this tile.
    pub weight: f64,
}

pub struct TileSet {
    pub tiles: Vec<Tile>,
}

impl TileSet {
    /// Load every `*.png` under the assets/tiles directory next to the source
    /// tree. Resolution order: $PIXELSCAPE_ASSETS, then ../../assets/tiles
    /// relative to the executable (target/release/pixelscape -> crate root).
    pub fn load() -> Result<TileSet, String> {
        let dir = Self::assets_dir().ok_or("cannot locate assets/tiles directory")?;
        let mut names: Vec<PathBuf> = std::fs::read_dir(&dir)
            .map_err(|e| format!("read {}: {e}", dir.display()))?
            .filter_map(|e| e.ok().map(|e| e.path()))
            .filter(|p| p.extension().is_some_and(|x| x == "png"))
            .collect();
        names.sort();
        let mut tiles = Vec::with_capacity(names.len());
        for path in &names {
            let stem = path.file_stem().and_then(|s| s.to_str()).unwrap_or("");
            // "09-city-cap-n.CGGG" -> code is the part after the last '.'
            let (name, code) = match stem.rsplit_once('.') {
                Some((n, c)) if c.len() == 4 => (n, c),
                _ => continue,
            };
            let img = image::open(path).map_err(|e| format!("{}: {e}", path.display()))?;
            let (w, h) = img.dimensions();
            if (w as i64, h as i64) != (TILE, TILE) {
                return Err(format!("{}: expected 64x64, got {w}x{h}", path.display()));
            }
            let mut bits = vec![false; (TILE * TILE) as usize];
            for (x, y, p) in img.to_luma8().enumerate_pixels() {
                // Source art is white-on-black; canvas ink is black-on-white.
                bits[(y as i64 * TILE + x as i64) as usize] = p.0[0] > 127;
            }
            let e = code.as_bytes();
            tiles.push(Tile {
                bits,
                edges: [e[0], e[1], e[2], e[3]],
                weight: weight_for(name),
            });
        }
        if tiles.is_empty() {
            return Err(format!("no tiles found in {}", dir.display()));
        }
        Ok(TileSet { tiles })
    }

    fn assets_dir() -> Option<PathBuf> {
        if let Ok(p) = std::env::var("PIXELSCAPE_ASSETS") {
            return Some(PathBuf::from(p));
        }
        let exe = std::env::current_exe().ok()?;
        // target/release/pixelscape -> ../../../assets/tiles == crate/assets/tiles
        Some(exe.parent()?.parent()?.parent()?.join("assets/tiles"))
    }
}

/// How often each tile should appear, keyed on its descriptive name. Open
/// countryside dominates; rare showpieces (full city, crossroads) stay rare.
fn weight_for(name: &str) -> f64 {
    // Strip the leading "NN-" index.
    let n = name.splitn(2, '-').nth(1).unwrap_or(name);
    match () {
        _ if n == "field" => 30.0,
        _ if n == "village" => 6.0,
        _ if n.starts_with("village-road") => 3.0,
        _ if n == "monastery" => 2.0,
        _ if n.starts_with("monastery-road") => 1.0,
        _ if n == "road-straight" || n == "road-curve" => 10.0,
        _ if n == "road-t" => 2.0,
        _ if n == "road-cross" => 1.0,
        _ if n.starts_with("road-end") => 1.5,
        _ if n.starts_with("city-cap-road") => 2.0,
        _ if n.starts_with("city-cap-curve") || n.starts_with("city-cap-t") => 1.0,
        _ if n.starts_with("city-cap") => 4.0,
        _ if n.starts_with("city-gate") => 1.5,
        _ if n.starts_with("city-corner-road") => 1.0,
        _ if n.starts_with("city-corner") => 2.0,
        _ if n.starts_with("city-band") || n.starts_with("city-two-caps") => 1.0,
        _ if n.starts_with("city-three") => 0.5,
        _ if n == "city-full" => 0.3,
        _ if n.starts_with("river-straight") => 8.0,
        _ if n.starts_with("river-curve") => 6.0,
        _ if n.starts_with("river-bridge") => 2.0,
        _ if n.starts_with("river-city") => 1.0,
        _ if n.starts_with("river-monastery") => 1.0,
        _ if n == "river-spring" || n == "river-lake" => 1.5,
        _ => 1.0,
    }
}

fn hash(n: i64) -> u64 {
    let mut x = (n as u64).wrapping_add(0x9E3779B97F4A7C15);
    x = (x ^ (x >> 30)).wrapping_mul(0xBF58476D1CE4E5B9);
    x = (x ^ (x >> 27)).wrapping_mul(0x94D049BB133111EB);
    x ^ (x >> 31)
}

/// Edge-matched layout: `grid[c * rows + r]` is the tile index at column c,
/// row r. The board is a horizontal cylinder of `cols` columns — the east edge
/// of the last column matches the west edge of the first — so world column
/// `wx.div_euclid(64).rem_euclid(cols)` scrolls forever with no seam and any
/// segment re-derives the exact same board from (seed, rows, cols).
pub struct Layout {
    pub rows: usize,
    pub cols: usize,
    pub grid: Vec<u16>,
}

/// Generate a `cols`×`rows` cylindrical board via backtracking. Deterministic
/// in (seed, rows, cols, tiles): candidate order at each cell is a weighted
/// shuffle keyed on (seed, cell), and the DFS itself is deterministic.
///
/// Backtracking is genuinely required: with the real tile set a greedy
/// left-to-right, top-to-bottom fill can paint itself into a corner (e.g. a
/// cell whose west neighbour ends in water and whose north neighbour ends in
/// city has no legal tile, since no tile carries water on one edge and city on
/// the orthogonal one), and the wrap-around seam adds a further constraint on
/// the final column. The DFS retracts and re-tries until every edge matches.
pub fn generate(set: &TileSet, seed: i64, rows: usize, cols: usize) -> Layout {
    let ncells = cols * rows;
    let mut grid: Vec<u16> = vec![0; ncells];
    // Per-cell candidate list + how many of them we've consumed.
    let mut cand: Vec<Vec<u16>> = vec![Vec::new(); ncells];
    let mut tried: Vec<usize> = vec![0; ncells];

    // Column 0 is pinned to an all-grass "gutter": every edge is grass. This
    // makes the cylinder always closeable — the last column only needs a grass
    // east edge (abundant) and column 1 only needs a grass west edge — so the
    // wrap seam is guaranteed seamless without an exponential search. Grass is
    // the dominant terrain, so one guaranteed grass column per period reads as
    // ordinary open countryside. DFS then fills columns 1..cols.
    let grass = set
        .tiles
        .iter()
        .position(|t| t.edges == [b'G', b'G', b'G', b'G'])
        .unwrap_or(0) as u16;
    for r in 0..rows {
        grid[r] = grass;
    }
    let floor = rows; // never retract into the pinned column 0

    // Weighted deterministic shuffle: order by u^(1/w) with u uniform from the
    // cell/tile hash (the classic weighted-reservoir key), descending. `east`
    // is the wrap constraint on the final column (its east edge must equal the
    // first column's west edge on this row); None everywhere else.
    let order_candidates =
        |cell: usize, west: Option<u8>, north: Option<u8>, east: Option<u8>| -> Vec<u16> {
            let c = (cell / rows) as i64;
            let r = (cell % rows) as i64;
            let mut keyed: Vec<(f64, u16)> = set
                .tiles
                .iter()
                .enumerate()
                .filter(|(_, t)| {
                    west.is_none_or(|w| t.edges[3] == w)
                        && north.is_none_or(|n| t.edges[0] == n)
                        && east.is_none_or(|e| t.edges[1] == e)
                })
                .map(|(i, t)| {
                    let h =
                        hash(seed ^ c.wrapping_mul(0x100000001B3) ^ (r << 40) ^ ((i as i64) << 52));
                    let u = (h % (1 << 53)) as f64 / (1u64 << 53) as f64;
                    (u.powf(1.0 / t.weight.max(0.01)), i as u16)
                })
                .collect();
            keyed.sort_by(|a, b| b.0.partial_cmp(&a.0).unwrap_or(std::cmp::Ordering::Equal));
            keyed.into_iter().map(|(_, i)| i).collect()
        };

    let mut cell = floor;
    // Generous step budget; layouts of this size solve in ~ncells steps.
    let mut steps = ncells * 400 + 50_000;
    while cell < ncells {
        if tried[cell] == 0 {
            let r = cell % rows;
            let west = set.tiles[grid[cell - rows] as usize].edges[1];
            let north = (r != 0).then(|| set.tiles[grid[cell - 1] as usize].edges[2]);
            // Last column wraps onto the first: its east edge must match the
            // west edge of column 0 on the same row (grass, since col 0 is the
            // pinned gutter).
            let east = (cell / rows == cols - 1).then(|| set.tiles[grid[r] as usize].edges[3]);
            cand[cell] = order_candidates(cell, Some(west), north, east);
        }
        if tried[cell] < cand[cell].len() && steps > 0 {
            grid[cell] = cand[cell][tried[cell]];
            tried[cell] += 1;
            cell += 1;
        } else if cell > floor && steps > 0 {
            // Dead end: retract this cell and re-try the previous one.
            tried[cell] = 0;
            cell -= 1;
        } else {
            // Budget exhausted or stuck at the origin (can't happen with this
            // tile set, but never hang): drop the constraint for this cell.
            grid[cell] = cand[cell].first().copied().unwrap_or(0);
            tried[cell] = usize::MAX; // marker; never revisited
            cell += 1;
        }
        steps = steps.saturating_sub(1);
    }
    Layout { rows, cols, grid }
}
