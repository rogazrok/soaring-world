# Perspective gameplay camera — 0.5.0

## Result

The default Soaring view is now a perspective chase camera. The flying
placeholder stays below the center of the frame while the road, terrain and
distant landmarks converge toward a visible horizon. The old orthographic view
is retained only as `DEBUG_TOP`.

No terrain art, palette, prop definition, heightmap, biome map or authored
object position was changed.

## Camera model

`flight.lua` stores a movement heading and a separately smoothed camera
heading. Position uses exponential smoothing with a faster response than
rotation, preventing abrupt quarter-turns when the player changes direction.
The renderer places the camera behind and above the placeholder, then projects
world vertices through a moderate perspective FOV.

The camera looks along the smoothed heading toward a point in front of the
player. This gives the frame useful look-ahead space instead of centering the
ground directly under the player.

Modes are data in `world/art.lua`:

- `CHASE`: pitch 22°, FOV 54°, close gameplay view, 1900-unit forward range.
- `HIGH_SOAR`: pitch 25°, FOV 58°, farther and higher, 2400-unit range.
- `DEBUG_TOP`: the previous orthographic full-slice inspection projection.

Press `C` or Select to cycle modes. Start or Escape returns to the ordinary
game. Height remains controlled by A/B and is independent of camera mode.

## Relative flight controls

Version 0.5.1 couples navigation to the craft/camera heading. Left/right apply
yaw at 1.85 radians per second. Up applies forward thrust along that heading;
down applies reverse thrust at 65% speed. A/B still climb and descend. Camera
heading follows the same yaw with exponential smoothing, so turning changes
both what the player sees and where forward movement goes.

## Distant background

The perspective view draws three flat palette bands before terrain: sky,
horizon haze and sea continuation. This is deliberately not a skybox. It closes
the empty area beyond the current Pallet–Route 1–Viridian slice and preserves
the existing Gen 1 pixel-art presentation.

## Limits

This is CPU-side perspective projection of the existing 2.5D mesh. Near-plane
crossing quads are conservatively culled rather than geometrically clipped.
Textures use screen-space interpolation, which is sufficient for this small
prototype but is not full perspective-correct material mapping. Full Kanto will
need chunk/frustum culling before using the HIGH_SOAR distance everywhere.
