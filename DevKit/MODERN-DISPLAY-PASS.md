# Modern display quality pass — 0.4.1

gen1recomp presents the game through a fixed 160×144 Game Boy playfield. A mod
scene cannot add final framebuffer pixels without changing the host engine.
This pass therefore improves the information that reaches that framebuffer.

The Soaring world renders at 320×288. Terrain edges, projected roofs and coast
lines are rasterized on this larger target, then reduced once with a linear
filter. The Gen 1 HUD is drawn after the reduction at 160×144, so text does not
become blurry. Geometry count is unchanged; render-target fill cost is about
four times the old world pass.

The imported Pokémon Red atlas is also copied to an internal 2× nearest-neighbor
atlas. This does not invent new game art. It gives the supersampled projection
stable texel boundaries before reduction. The result retains the Red motifs
while reducing diagonal stair steps.

Each terrain material has a projected-size LOD threshold in `world/art.lua`.
Fine forest and mountain motifs disappear earlier than grass and water. At high
altitude they become broad readable masses instead of alternating pixels. The
transition is discrete and deterministic, so movement no longer changes a
hashed/noise pattern from frame to frame.

Default controls in `world/art.lua`:

- `render_scale=2`: 320×288 scene target. Use `1` on a weak phone.
- `texture_scale=2`: 2× internal copy of the Red atlas. Use `1` with the old
  render scale.
- `smooth_downsample=true`: smooth one-step reduction. Set `false` for the old
  hard-pixel presentation.
- `pattern_cells=12`: spreads repeated terrain motifs over a larger world area.
- `lod_pixels`: per-material projected-size thresholds for water, grass,
  forest, mountains, sand, towns and roads.

The user's `kanto_height.png`, `kanto_terrain.png` and `kanto_objects.lua` are
not modified by this pass. Existing editor data remains compatible.
