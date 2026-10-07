-- Soaring-only experiments. Palette and camera settings are independent.
-- Set enabled=false to restore the 0.10.24 presentation, including legacy FX.
-- LOW: haze + one water sample. MEDIUM/HIGH: shadows and optional rare wind.
return {
  enabled=true, quality='MEDIUM',
  -- WORLD: positioned cloud/mist banks; SCREEN: previous 0.10.25; OFF: no clouds.
  cloud_mode='WORLD', local_mist=true,
  cloud_density=.18, cloud_opacity=.11, cloud_velocity={2.2,.8},
  haze=true, animated_water=true, cloud_shadows=true,
  directional_shading=false, wind_streaks=true,
  -- Distant terrain dissolves into the fixed panorama before the far clip edge.
  haze_start=650, haze_end=2600, haze_intensity=1,
  water_speed=.008, water_blend=.18,
  shadow_scale=480, shadow_intensity=.075, shadow_velocity={8,3},
  directional_intensity=.10,
  -- A fixed light direction; changing it requires renderer rebuild/reload.
  sun_direction={-.55,-.35,.76},
}
