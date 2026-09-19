# Changelog

## 0.3.3 — 2026-09-19

- Polished the existing Game Boy-style scene without replacing its fixed camera,
  stepped terrain, palette workflow, or authored Pallet / Route 1 / Viridian layout.
- Reduced small surface detail; forest now reads as broad dark terrain with sparse
  broadleaf and pine landmarks instead of a noisy carpet of tiny props.
- Added layered, readable silhouettes for homes, Oak's Lab, the Gym, Pokémon
  Center, and Poké Mart; preserved editable red and blue landmark roofs.
- Added a restrained palette-only distance fade and separate road-detail density.
- Fixed in-scene `R` reload so it preserves the runtime-derived Red atlas source.

## 0.3.2 — 2026-09-19

- Runtime sampling of the player's imported Red OVERWORLD atlas for sparse terrain detail and house roof/facade stamps.
- Added an editable palette file, a red Pokémon Center roof, a blue Poké Mart roof, and a Viridian Poké Mart prop.
- Preserved the clean low-detail terrain base to avoid texture moiré at Game Boy resolution.

## 0.3.1 — 2026-09-19

- Replaced the synthetic starter rectangle with the Pallet → Route 1 → Viridian vertical slice.
- Longer authoring map, coastal Pallet, Route 1 fields/forest, larger Viridian, hills, and water ripple.
- Exposed world, terrain, prop, speed, altitude, and camera scale controls in config.
- Added distinct Oak's Lab and landmark prop dimensions plus verified low/medium/high camera captures.

## 0.3.0 — 2026-09-19

- New independent `SOAR WORLD` stylized scene, separate from original Red map geometry.
- Editable grayscale height PNG, biome PNG, object table, primitive prop table, and global config.
- Pixel-art terrain mesh with quantized height levels, water, forests, mountains, coast, road, and proxy props.
- Editor for height/biome brushes, smoothing, objects, object transform, save backups, undo/redo, and preview.
- In-scene R reload of authoring data.

## 0.2.0 — 2026-09-19

- Per-map text heightmaps, levels -1..3, block grid with 16/8px forward support.
- Mesh terrain with original tile tops and seam-aware south/east cliff walls.
- Ground-height query, absolute flight altitude and terrain-following shadow.
- Separate mouse editor with original map view, grid, brush, Undo/Redo and backed-up saving.
- Sample authored heights for Pallet, Route 1 and Viridian; no original map edits.
- Regression and editor-to-game tests, 34-map construction benchmark.

## 0.1.0 — 2026-09-19

- Isolated Red flight scene from connected original maps, debug menu and safe return.
