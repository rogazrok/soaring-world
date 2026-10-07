return {
  -- The approved Soaring palette is B. No palette setting is stored in the save.
  soaring_palette='B',
  soaring_horizon_enabled=true,
  -- Follow the active engine's timeOfDay() state using one scene composite.
  soaring_day_night=true, soaring_night_strength=0.86, soaring_time_follow=2.2,
  -- World units per heightmap pixel. Keep this high enough that Route 1 has
  -- distance, while cities stay compact landmarks from a high flight altitude.
  world_scale=7, terrain_scale=7, terrain_height_scale=1,
  max_height=42, height_levels=7, sea_level=18, water_height=0, extrusion=1,
  -- Rocky biomes use a taller, finer stepped profile than ordinary land.
  -- The ridge curve keeps high source pixels dominant and drops shoulders.
  mountain_height_scale=1.25, mountain_height_levels=18, mountain_ridge_power=1.55,
  -- Forest itself is a large dark mass. Individual tree icons are reserved for
  -- edges and authored clusters, so the high-altitude view stays legible.
  city_scale=0.74, prop_scale=0.74, tree_density=0.07,
  flight_speed=180, flight_turn_speed=1.85, flight_reverse_scale=0.65,
  camera_altitude=260, camera_distance=108,
  -- Flight handling. Defaults equal the values that were hard-coded before 0.10.3.
  flight_climb_speed=160,       -- A/B altitude rate, world units per second
  flight_camera_follow=8,       -- camera position smoothing rate (1/s)
  flight_camera_turn_follow=5,  -- camera heading smoothing rate (1/s)
  flight_max_dt=0.05,           -- longest simulated frame; no catch-up after focus loss
  flight_terrain_clearance=30,  -- minimum altitude kept above the ground under the craft
  flight_min_altitude=105, flight_max_altitude=950,
  -- Presentation-only Dragonite/rider movement; values do not affect flight state.
  rider_motion_enabled=true, -- set false to compare against the static sprite
  rider_roll_max=9,           -- degrees, clamped to 0..12
  rider_roll_follow=7.5,      -- smoothing rate per second
  rider_bob_amplitude=1.0,   -- logical screen pixels (0..3)
  rider_bob_speed=1.5,       -- gentle sine speed in radians per second
  rider_pitch_visual=3,      -- maximum visual pitch in degrees (0..8)
  draw_distance=1550, fade_distance=1180,
  -- Decorative mainland continues beyond the playable north/west borders.
  -- Flight bounds remain unchanged; this is visual-only geometry rendered to the horizon.
  backdrop_enabled=true, backdrop_north=true, backdrop_west=true,
  backdrop_distance=3200,
  -- Number of visual-only continuation bands. More bands preserve
  -- topographic variation instead of turning the mainland into one flat slab.
  -- Cell size of the continuous visual heightfield. The first apron still
  -- matches every playable edge cell exactly; farther out a coarse grid keeps
  -- the backdrop inexpensive without exposing giant parallel strips.
  backdrop_grid_stride=4,
  -- Tile IDs from the player's imported Red OVERWORLD atlas. They are read at
  -- runtime and are never packed into this mod. Change them to tune the look.
  material_tiles={water=10,grass=35,forest=57,mountain=40,sand=44,city=17,road=35,cliff=40},
  -- One authentic tile detail every few cells is enough at the 160x144 target.
  -- Larger, clean colour fields read better than a dense checkerboard.
  terrain_detail_density=0.025, water_detail_density=0.07, road_detail_density=0.10,
  -- A restrained palette fade makes distant terrain recede without blur/fog.
  distance_fade_strength=0.16,
}
