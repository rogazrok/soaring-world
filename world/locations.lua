-- Native city/Fly zones. The one active Hidden Area is appended at runtime
-- from world/hidden_areas.lua + world/hidden_spawn_anchors.lua.
-- Centers/radii are world units (the current authored map uses 7 units/pixel).
-- City ids are native Gen 1 Fly-town map ids; their arrival cells come from
-- game.data.field.flyWarps. Hidden rows own a registered map and entry cell.
return {
  settings = {
    banner_seconds = 2.0,
    landing_max_altitude = 380,
    fade_out_seconds = 0.28,
    fade_in_seconds = 0.32,
  },
  locations = {
    { id="PALLET_TOWN", name="PALLET TOWN", center={x=612.5,y=1407}, banner_radius=135, landing_radius=62, enabled=true },
    { id="VIRIDIAN_CITY", name="VIRIDIAN CITY", center={x=616,y=1120}, banner_radius=150, landing_radius=70, enabled=true },
    { id="PEWTER_CITY", name="PEWTER CITY", center={x=616,y=742}, banner_radius=145, landing_radius=68, enabled=true },
    { id="CERULEAN_CITY", name="CERULEAN CITY", center={x=1568,y=658}, banner_radius=150, landing_radius=70, enabled=true },
    { id="CELADON_CITY", name="CELADON CITY", center={x=1281,y=931}, banner_radius=150, landing_radius=72, enabled=true },
    { id="SAFFRON_CITY", name="SAFFRON CITY", center={x=1568,y=931}, banner_radius=165, landing_radius=78, enabled=true },
    { id="LAVENDER_TOWN", name="LAVENDER TOWN", center={x=1967,y=938}, banner_radius=145, landing_radius=68, enabled=true },
    { id="VERMILION_CITY", name="VERMILION CITY", center={x=1568,y=1225}, banner_radius=150, landing_radius=70, enabled=true },
    { id="FUCHSIA_CITY", name="FUCHSIA CITY", center={x=1379,y=1519}, banner_radius=155, landing_radius=72, enabled=true },
    { id="CINNABAR_ISLAND", name="CINNABAR ISLAND", center={x=609,y=1736}, banner_radius=145, landing_radius=68, enabled=true },
    { id="INDIGO_PLATEAU", name="INDIGO PLATEAU", center={x=420,y=651}, banner_radius=135, landing_radius=62, enabled=true },
  },
}
