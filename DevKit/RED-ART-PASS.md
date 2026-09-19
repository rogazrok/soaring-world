# Pokémon Red visual integration — 0.4.0

The existing terrain builder, authoring images, flight controller and depth mesh
remain. No layout coordinates or authored height/terrain pixels were changed.
The recovered Pallet / Viridian object table remains byte-for-byte unchanged.

## Materials and props

`world/art.lua` defines zero-based OVERWORLD tile IDs in 8-pixel motif matrices.
The runtime reads the player's imported atlas through the existing asset
transform. No extracted atlas is distributed. Materials use water tile 20,
grass strokes 57, the 80/81/64/65 tree crown, rock 58/59, roof pieces 5–9 and
21–25, facade windows 10–12 / 26–28 and landmark sign fragments. Paths deliberately
use blank tile 0, like the light paths separating denser Red grass patterns.

House, large house, lab, Center, Mart and Gym now carry assembled roof motifs
on low box geometry and a separate front facade. Center/Mart retain red/blue
ramps. Rock tops and forest canopy use atlas motifs. Tree clusters use a regular
spacing grid; hashed terrain speckles, hashed tree placement and time-dependent
pixel water speckles were removed. Water waves come from the tile itself.

An 8px tile is the texture unit. `unit=2` authoring pixels is the prop dimension
module before user scale; position and scale overrides are preserved exactly.
This intentionally does not snap or rewrite the user's object coordinates.
Forest/rock terrain loses fine detail when the projected tile falls below four
screen pixels, preventing high-altitude moiré. Transitions are discrete.

## Four shades and camera

The material shader quantizes source intensity to four indices and maps these
to four RGB entries per material in `art.lua`. Fixed face shade multipliers
quantize to the same four entries: no realistic light, gradients, or fog.
The old continuous distance fade is no longer used. `palette.lua` still controls
background/placeholder/editor accents; surface ramps now live in `art.lua`.

The host's custom palette (`PaletteFX.customRamp`) receives a raw four-gray
frame, so gen1recomp applies its chosen ramp once. Tested with a grayscale ramp.
Automatic per-tile GBC/SGB coloring is not mirrored: default colorized Soaring
uses its authored material ramps. This is not yet exact color parity with every
host color mode or third-party color mod.

The existing orthographic projection is more top-down: shear .18, slope .14,
depth .82, in editable `art.camera`. Buildings use .72 relief scale. There was
never a perspective lens in this scene, so this adjusts tilt, not lens FOV.

## HUD and editor

In-game HUD uses `mod.ui.Font.draw`, the real imported Gen 1 glyph path, on
8px top/bottom strips. Standalone editor retains its dev font and untextured
3D preview when no game atlas is available; final materials are checked in game.
Terrain brushes, object movement/scaling, undo, saving and reload remain intact.
`R` also fixes an old Lua boolean-expression bug that showed a false reload error.

## Evidence and limits

- `evidence/red-ordinary.png`: ordinary Red in this isolated install's color mode.
- `evidence/red-art-pallet.png`: low flight, restored authored Pallet.
- `evidence/red-art-viridian.png`: red Center, blue Mart, Gym and houses.
- `evidence/red-art-high.png`: maximum test altitude, full slice.
- `evidence/red-art-mono.png`: shared custom grayscale palette.
- Earlier `stylized-polish-*` captures remain for comparison, but use the older
  layout and tilt, so they are not a controlled pixel-for-pixel A/B comparison.

Verified: real Red engine launch, atlas present, R reload preserves atlas,
restored Oak coordinate, serialized save unchanged on exit, same overworld
return, standalone editor paint/undo/object-save/reload/mesh on disposable data.
The three live authoring files were hash-checked against the pre-pass backup.

At 160x144, tiny house windows and sign lettering still merge at high altitude.
Roof silhouettes/color landmarks remain the reliable cues. Broad forest and
mountain patterns are simplified at maximum altitude. This pass does not solve
full-Kanto mesh/chunk performance or make every building a detailed replica.

## Updating safely

The active local installation receives code plus `world/art.lua` only. Its
`kanto_height.png`, `kanto_terrain.png`, `kanto_objects.lua`, existing palettes,
config and props are preserved. Do not replace your edited world folder with
a release sample. Full archives contain the reference world for fresh installs.
