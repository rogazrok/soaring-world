# Changelog

## 0.5.1 — heading-relative flight controls

- Left/right now yaw the craft and chase camera instead of moving on world X.
- Up flies forward along the current camera heading; down reverses along it at
  65% speed. A/B continue to climb and descend.
- Added editable turn speed and reverse-speed scale with defaults compatible
  with existing user config files.
- Updated the in-flight HUD to describe flight and altitude controls.

## 0.5.0 — perspective gameplay camera

- Replaced the gameplay map projection with a perspective chase camera behind
  and above the flying placeholder.
- Movement now sets flight heading; camera position and rotation follow with
  separate exponential smoothing and a forward look direction.
- Added CHASE, HIGH_SOAR and DEBUG_TOP modes. Press C or Select to cycle them;
  Start still exits safely.
- Added a restrained sky, horizon haze and sea continuation behind distant
  terrain so the vertical slice no longer appears suspended in empty space.
- Increased forward draw range for the two gameplay modes without changing the
  world mesh, palette, materials, props or authoring data.
- Kept DEBUG_TOP as a full-slice inspection view rather than gameplay camera.

## 0.4.2 — low oblique flight camera

- Lowered the fixed orthographic camera to a forward-looking aerial angle
  inspired by the readable Soaring view in Pokémon ORAS.
- Kept the 0.4.1 palette, Red atlas motifs, geometry, supersampling, LOD and HUD.
- Changed no authored height, biome or object data.

## 0.4.1 — modern display quality

- Render the Soaring scene internally at 320×288 and reduce it once to the
  engine's 160×144 playfield, while keeping the native HUD sharp.
- Added material-specific distance LOD so dense forest, mountain and ground
  motifs become calm color masses before they can shimmer.
- Added editable `render_scale`, `texture_scale`, `smooth_downsample`,
  `pattern_cells`, and `lod_pixels` controls in `world/art.lua`.
- Kept terrain geometry and the user's height, biome and object data unchanged.

## 0.4.0 — Red art integration

- Runtime Red tile motifs for terrain, roofs, facades, trees and rocks.
- Four discrete tones per material; custom host palettes use a raw gray frame.
- More top-down orthographic tilt, reduced building relief, real Gen 1 HUD font.
- Removed hashed terrain noise, animated noise ripples and hashed tree scatter.
- Retained recovered author layout; no world image or object coordinate edits.
- Verified R reload, unchanged serialized save and editor operations on copied data.

## 0.3.4 — 2026-09-19

- Removed the obsolete `SOAR TEST` item from the normal Start menu. The only
  player-facing entry is now `SOAR WORLD`, preventing accidental entry into the
  older original-map prototype.

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
