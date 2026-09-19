# Low oblique flight camera — 0.4.2

Only the projection coefficients in `world/art.lua` changed. The palette,
Pokémon Red atlas motifs, terrain mesh, buildings, LOD and authored world data
remain the same as 0.4.1.

The camera now uses `shear=.10`, `slope=.08`, and `depth=.54`. Reducing ground
depth from .82 to .54 compresses distance on screen and exposes more vertical
relief, producing a lower forward-looking aerial view. Reduced shear keeps the
world aligned with the player's direction instead of turning it into a strong
isometric view.

This is an ORAS-inspired composition, not a copy of its camera system. The
prototype remains orthographic and has no perspective vanishing point, horizon,
sky, camera rotation or depth-dependent object scaling. Those features would
require a later perspective-camera renderer rather than another projection
coefficient adjustment.
