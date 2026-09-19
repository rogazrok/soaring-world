return {
  -- World units per heightmap pixel. Keep this high enough that Route 1 has
  -- distance, while cities stay compact landmarks from a high flight altitude.
  world_scale=7, terrain_scale=7, terrain_height_scale=1,
  max_height=42, height_levels=7, sea_level=18, water_height=0, extrusion=1,
  -- Forest itself is a large dark mass. Individual tree icons are reserved for
  -- edges and authored clusters, so the high-altitude view stays legible.
  city_scale=0.74, prop_scale=0.74, tree_density=0.07,
  flight_speed=180, camera_altitude=260, camera_distance=108,
  flight_min_altitude=105, flight_max_altitude=950,
  draw_distance=1550, fade_distance=1180,
  -- Tile IDs from the player's imported Red OVERWORLD atlas. They are read at
  -- runtime and are never packed into this mod. Change them to tune the look.
  material_tiles={water=10,grass=35,forest=57,mountain=40,sand=44,city=17,road=35,cliff=40},
  -- One authentic tile detail every few cells is enough at the 160x144 target.
  -- Larger, clean colour fields read better than a dense checkerboard.
  terrain_detail_density=0.025, water_detail_density=0.07, road_detail_density=0.10,
  -- A restrained palette fade makes distant terrain recede without blur/fog.
  distance_fade_strength=0.16,
}
