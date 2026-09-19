# Stylized Soaring World — quick authoring guide

This is a separate experimental scene for Pokémon Red. It does not use the
original Red maps as terrain geometry. The earlier `SOAR TEST` item remains for
the map-connection experiment; use **SOAR WORLD** for this new authoring world.
The scene does not run overworld scripts, write the save, or create encounters.

## Run the prototype

1. Install the mod folder as usual and enable **Soaring World Red - Experimental**
   for Red in the mod manager. It is experimental and is off by default.
2. Open a normal Red overworld save, press Start, and select **SOAR WORLD**.
3. The D-pad moves; A/B change flight altitude; Start or Select returns to the
   normal game. Press **R** to reread the world data while already flying.

For the isolated local demonstration, run `Launch-Stylized-World.cmd`. It uses
the disposable `playtest` installation and creates no normal game save.

## Edit the world in five minutes

Run `Launch-World-Editor.cmd`. It opens the **same files** that `SOAR WORLD`
loads in the isolated playtest mod folder.

* `Tab` switches between the editable map and the pixel-art 3D preview.
* `H` paints an absolute grayscale height. Use `,` and `.` to select the gray
  value, then paint with the left mouse button. `U`, `J`, and `K` raise, lower,
  and smooth with a soft circular brush. `[` and `]` change its radius.
* `T` paints terrain type. Keys `1`–`7` select water, grass, forest, mountain,
  sand, city, and road. The legend is displayed at the top.
* `O` selects and drags an object. `N` adds the type shown in the help panel;
  `Q` cycles types. Arrows move the selected object, `+`/`-` scale it,
  PageUp/PageDown adjust its height, `E` turns it, `D`/`F` change a forest
  cluster's density, and Delete removes it.
* `Ctrl+Z` and `Ctrl+Y` undo and redo. `S` saves. The editor makes a `.bak`
  copy before replacing each changed data file. `R` reloads files from disk.

Save, return to the running `SOAR WORLD`, then press **R**. The heightmap,
terrain map, and objects reload without restarting Red.

## Files you can edit directly

All authoring data is in `mods/soaring_world_red/world/`:

| File | What it controls |
|---|---|
| `kanto_height.png` | Grayscale elevation: black is sea/low ground, white is maximum height. |
| `kanto_terrain.png` | Flat-color biome map. The palette legend in the editor gives the seven accepted colors. |
| `kanto_objects.lua` | One plain table per city, house, landmark, tree cluster, dock, cave, and so on. |
| `props.lua` | Reusable primitive dimensions and proxy-city layouts. |
| `palette.lua` | The fixed Game Boy-style colors, including red Pokémon Center and blue Poké Mart roofs. |
| `config.lua` | Global editable settings. |

`config.lua` exposes `world_scale` (world distance per PNG pixel),
`terrain_height_scale`, `max_height`, `height_levels`, `sea_level`,
`water_height`, `extrusion`, `city_scale`, `prop_scale`, `tree_density`,
`flight_speed`, `camera_altitude`, `camera_distance`, `flight_min_altitude`,
`flight_max_altitude`, `draw_distance`, and `fade_distance`. Height is
quantized to `height_levels` steps, giving the terrain a deliberately stepped
Game Boy-like form. `world_scale` and `flight_speed` are the two practical
controls for how long a route takes to cross.

`config.lua` also contains `material_tiles`: IDs from the **locally imported**
Red `OVERWORLD` atlas. The renderer reads that atlas at runtime for sparse
ground detail and selected simplified building materials. The atlas is not
copied into this mod or its ZIP. `terrain_detail_density`,
`water_detail_density`, and `road_detail_density` control how often those
details appear; keep them low at the 160×144 presentation resolution.
`distance_fade_strength` is a small palette-only fade for distant terrain; it
deliberately uses no blur or smooth fog.

The shipped PNGs are a 128×224 vertical slice: a low Pallet shoreline, a long
Route 1 road, a larger Viridian, forests, and coarse hill masses. Pallet is
south of Viridian, matching the real Pokémon Red map connections, but the
scenery is an authored flight miniature rather than copied game maps. Reference
images were used only for the broad design principles: readable coast, large
forest and mountain masses, routes, and simple settlements. No reference
names, buildings, map layout, or image pixels are included in the mod.

## Editing objects by hand

An object is a single readable Lua table. For example:

```lua
{type='house_small', name='TEST_HOUSE', x=60, y=76, scale=1, z=0, rotation=0},
```

`x` and `y` are pixels in the PNG maps. `z` is an extra height above terrain.
`scale` changes its size; `rotation` is degrees. A `tree_cluster` also accepts
`radius` and `density`. The available types are `house_small`, `house_large`,
`pokemon_center`, `poke_mart`, `gym`, `oak_lab`, `tree`, `tree_pine`,
`tree_cluster`, `rock`,
`mountain_peak`, `dock`, `cave`, `city`, and `pallet`.

## Current limits

This milestone proves the data pipeline, not the finished Kanto. Props are
simple colored boxes and trees; there is no landing, visited-map tracking,
full-region layout, detailed buildings, collision, or automatic conversion from
original Red maps. The first full-Kanto pass should use the real Red map
connections to establish city/route anchor coordinates, then place authoring
PNG terrain around those anchors. That preserves actual Red layout while giving
room for flight-only forests, coasts, mountains, and sea.

## Visual vocabulary in 0.3.3

The renderer remains the same fixed-angle, nearest-neighbour pixel scene. This
pass makes its visual hierarchy explicit: forest biome is a broad dark-green
mass; isolated broadleaf and pine trees are used as landmarks; roads are narrow
light routes; and buildings use layered box silhouettes. Small homes, Oak's
Lab, the Gym, red Pokémon Center, and blue Poké Mart therefore remain distinct
when viewed from flight altitude. These are authoring data and primitive
layers, not a second renderer or a 3D model system.
