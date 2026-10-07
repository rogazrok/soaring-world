-- Lightweight, editable presentation settings. Values are in the native
-- 160x144 logical view; the full-window renderer scales them without blur.
return {
  enabled=true,
  altitude={low=150, middle=380, high=760},
  -- A subtle downward veil fades the map below the rider at near-maximum height.
  haze={start=720, full=950, max_alpha=.20, color={.76,.84,.82}},
  clouds={
    far={count=5, min_altitude=180, alpha=.18, scale_min=1.3, scale_max=2.0,
      drift=1.1, parallax=.018, color={.91,.94,.88}},
    middle={count=4, min_altitude=270, alpha=.13, scale_min=.8, scale_max=1.35,
      drift=2.0, parallax=.045, color={.94,.96,.91}},
    near={count=2, min_altitude=500, alpha=.10, scale_min=1.0, scale_max=1.5,
      drift=3.6, parallax=.095, color={.97,.98,.94}},
  },
  wind={base_count=4, fast_count=8, min_alpha=.10, max_alpha=.27,
    short_length=5, long_length=14, travel_speed=1.15,
    color={.88,.94,.91}},
}
