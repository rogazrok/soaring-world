-- Red OVERWORLD tile IDs, zero based. Art is read from the player's import.
-- Each motif is an 8px tile matrix. Four tones per material, light to dark.
return {
 -- Modern-display quality pass. The 3D scene renders at 2x Game Boy
 -- resolution and is reduced once, while the native HUD stays at 160x144.
 -- Set render_scale=1 and texture_scale=1 for the old hard-pixel mode.
 render_scale=2, texture_scale=2, smooth_downsample=true,
 unit=2, pattern_cells=12, relief_scale=.72,
 -- Minimum projected motif size in final 160x144 pixels. Dense forest and
 -- mountain patterns disappear earlier than grass/water to prevent shimmer.
 lod_pixels={10,11,19,17,13,13,99},
 camera={shear=.10, slope=.08, depth=.54}, -- DEBUG_TOP only
 camera_modes={
  -- Default third-person framing: closer and slightly higher behind Dragonite.
  -- The Town Map remains readable ahead; HIGH_SOAR preserves the old wide view.
  CHASE={pitch=23,fov=50,back=52,above=34,look_ahead=102,flight_sprite_size=34,far=1900},
  HIGH_SOAR={pitch=25,fov=58,back=105,above=75,look_ahead=150,far=2400},
 },
 ramps={
  {{.76,.82,.72},{.48,.65,.64},{.26,.43,.46},{.10,.19,.23}},
  {{.78,.84,.60},{.51,.64,.32},{.27,.43,.20},{.10,.22,.12}},
  {{.85,.89,.65},{.64,.75,.43},{.39,.54,.26},{.17,.29,.16}},
  {{.89,.88,.69},{.73,.74,.51},{.49,.53,.32},{.23,.29,.18}},
  {{.94,.91,.74},{.79,.76,.56},{.55,.53,.36},{.24,.25,.18}},
  {{.84,.79,.64},{.65,.56,.43},{.43,.35,.27},{.21,.20,.17}},
  {{.76,.82,.72},{.48,.65,.64},{.26,.43,.46},{.10,.19,.23}},
  {{.94,.85,.69},{.77,.42,.32},{.57,.23,.21},{.23,.18,.16}},
  {{.88,.89,.75},{.45,.59,.71},{.24,.36,.55},{.15,.20,.28}},
  {{.88,.78,.93},{.62,.42,.72},{.42,.24,.54},{.20,.13,.28}}, -- Lavender violet
  {{.97,.86,.52},{.81,.61,.25},{.57,.39,.15},{.28,.22,.13}}, -- Saffron gold
  {{.88,.91,.73},{.55,.72,.49},{.31,.51,.32},{.15,.29,.20}}, -- Celadon teal / green
 },
 terrain={
  {cols=1,tiles={20}}, -- wave motif
  {cols=2,tiles={0,0,0,57}}, -- regular short grass tufts
  {cols=2,tiles={0,0,0,57}}, -- dark forest floor; 3D canopies carry tree identity
  {cols=2,tiles={58,59,58,59}}, -- rock face
  {cols=2,tiles={0,0,57,0}}, -- sparse shore
  {cols=2,tiles={0,0,0,57}}, -- town earth
  {cols=1,tiles={0}}, -- Red paths are intentionally plain
 },
 roofs={
  house={cols=6,tiles={5,6,7,7,8,9,21,22,23,23,24,25}},
  house_large={cols=6,tiles={5,6,7,7,8,9,21,22,23,23,24,25}},
  lab={cols=6,tiles={5,6,7,7,8,9,21,22,23,23,24,25}},
  center={cols=6,tiles={5,6,7,7,8,9,21,22,23,23,24,25}},
  mart={cols=6,tiles={5,6,7,7,8,9,21,22,23,23,24,25}},
  gym={cols=6,tiles={5,6,7,7,8,9,21,22,23,23,24,25}},
 },
 facade={cols=4,tiles={10,11,12,10,26,27,28,26}},
 trees={cols=2,tiles={80,81,64,65}},
 rock={cols=2,tiles={58,59}},
}
