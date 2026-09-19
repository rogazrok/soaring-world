# Pallet → Route 1 → Viridian vertical slice

`SOAR WORLD` now starts in an authored 128×224 pixel miniature rather than the
old synthetic 96×128 test. Its world scale is seven units per data pixel:
896×1568 world units. Oak's Lab/Pallet is at (56, 181); Viridian's central
landmarks are around (47–76, 47–76). They preserve the important Red
relationship: Pallet is south of Viridian and Route 1 runs between them.

At the shipped `flight_speed=180`, the direct Oak's Lab → Viridian Center trip
is about 4.4 seconds of uninterrupted movement. This leaves room for fields
and woods while keeping the slice compact enough to read from above. Set
`world_scale` or `flight_speed` in `world/config.lua` if that feel needs
adjusting.

## Visual composition

* **Pallet** is a small coastal settlement: ocean, shallow sand, Oak's Lab,
  Player/Rival houses, a dock, and the northbound road.
* **Route 1** is a narrow road through grass with forest on both sides and
  modest terrain variation around its edges.
* **Viridian** is a larger elevated town footprint with a Gym, Pokémon Center,
  three houses, roads, greenery, and nearby northern woods.
* Two large coarse hill masses and the sea extend beyond the playable route,
  so a high view reads as a region fragment rather than an arena.

Terrain uses seven quantized height levels. Water is at height 0; Pallet and
Route 1 are mostly low ground; the Viridian plateau is one step higher; the
surrounding hills are several steps higher. The water surface has a small,
deterministic pixel ripple. Buildings are simple box props with distinct
footprints and relative heights: homes, Oak's Lab, Pokémon Center, and Gym.

## Verified camera views

These captures were made through the real gen1recomp game modules in an
isolated imported-Red test install. The game loaded the mod as version 0.3.2.

| Height | Intended reading | Capture |
|---|---|---|
| 130 | Pallet shoreline, nearby props, local terrain | [low](evidence/stylized-vertical-low.png) |
| 340 | Route 1, woods and terrain ahead | [medium](evidence/stylized-vertical-medium.png) |
| 850 | Pallet, Route 1, Viridian and both hill masses | [high](evidence/stylized-vertical-high.png) |

The normal scene has no free development camera. D-pad moves the flyer, A/B
adjust altitude, and Start/Select exits. `camera_altitude`, `camera_distance`,
and altitude limits are editable config values.

## Authoring remains data-only

Use `Launch-World-Editor.cmd`; no renderer code needs changing for these jobs:
paint `kanto_height.png` to raise/lower terrain, paint `kanto_terrain.png` to
move forests/roads/coasts, and move or resize rows in `kanto_objects.lua`.
Save in the editor, return to the flight scene, and press `R` to reload.

## Full-Kanto outlook

The data format and editor can expand map-by-map. A full Kanto should be a
larger height/terrain image with city and route anchors derived from the real
Red connection graph; flight-only terrain fills the spaces between those
anchors. The current renderer rebuilds a mesh for the visible authoring slice
every frame. It is suitable for 128×224, but a full region will need terrain
chunks and distance/level-of-detail before it is performance-ready. The
editable files, prop library, height quantization, flight control, and hot
reload remain valid for that next step.

## Texture and landmark pass

Version 0.3.2 reads the installed player's `OVERWORLD` atlas through an
approved asset-transform recipe. The ZIP still contains no imported game art:
the recipe writes a local derived copy only after the player has imported Red.
Terrain uses sparse detail rather than a tile on every terrain cell, because
the latter produces moiré at 160×144. Simplified building surfaces use selected
materials from the installed Red atlas without reproducing complete map blocks.
The red Pokémon Center and blue Poké Mart roof colors are authored in
`world/palette.lua` and their landmark props remain editable in
`world/kanto_objects.lua`.

## Readability polish — 0.3.3

The scene keeps the same projection and stepped terrain, but surface texture
density is lower so that grass and forest read as intentional large planes at
160×144. Forest is now primarily a dark biome mass, with two sparse tree
silhouettes: round broadleaf trees and layered pines. Buildings have layered
primitive profiles: the Lab is wider with a cap, the Gym has a dark roof and
central mark, and the red Center / blue Mart are recognizable landmarks.

Road detail is also sparse, preserving Route 1 as a clear line without making
it the visual subject. At the far end of the draw range the existing palette is
mixed slightly toward the background colour. This is per-vertex palette
attenuation only: no blur, depth-of-field, fog shader, or smoothing is added.

The current four reference views are retained as evidence: Pallet from low
altitude, Route 1 from medium altitude, the full slice from high altitude, and
Viridian at landmark distance. They were captured through the real isolated
gen1recomp Red playtest.
