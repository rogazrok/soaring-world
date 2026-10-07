-- Outdoor Pokémon Red map -> authored Soaring-space position.
-- Paths run in the same direction as increasing source-map cell coordinates.
-- Coordinates are world units (the current miniature uses 7 units/pixel).
--
-- City centers are NOT repeated here: they live only in world/locations.lua.
-- {location='ID', spread=...} places a town at that location's center, and a
-- string in a path (e.g. 'PEWTER_CITY') stands for that location's center.
-- Literal {x,y} points are for route waypoints and non-landing Safari maps.
local townSpread={x=86,y=62}
return {maps={
  PALLET_TOWN={location='PALLET_TOWN',spread=townSpread},
  VIRIDIAN_CITY={location='VIRIDIAN_CITY',spread=townSpread},
  PEWTER_CITY={location='PEWTER_CITY',spread=townSpread},
  CERULEAN_CITY={location='CERULEAN_CITY',spread=townSpread},
  CELADON_CITY={location='CELADON_CITY',spread=townSpread},
  SAFFRON_CITY={location='SAFFRON_CITY',spread=townSpread},
  LAVENDER_TOWN={location='LAVENDER_TOWN',spread=townSpread},
  VERMILION_CITY={location='VERMILION_CITY',spread=townSpread},
  FUCHSIA_CITY={location='FUCHSIA_CITY',spread=townSpread},
  CINNABAR_ISLAND={location='CINNABAR_ISLAND',spread=townSpread},
  INDIGO_PLATEAU={location='INDIGO_PLATEAU',spread=townSpread},

  ROUTE_1={axis="y",cross=58,path={{616,1010},'PALLET_TOWN'}},
  ROUTE_2={axis="y",cross=62,path={'PEWTER_CITY','VIRIDIAN_CITY'}},
  ROUTE_3={axis="x",cross=60,path={'PEWTER_CITY',{1040,700}}},
  ROUTE_4={axis="x",cross=60,path={{1040,700},'CERULEAN_CITY'}},
  ROUTE_5={axis="y",cross=58,path={'CERULEAN_CITY','SAFFRON_CITY'}},
  ROUTE_6={axis="y",cross=58,path={'SAFFRON_CITY','VERMILION_CITY'}},
  ROUTE_7={axis="x",cross=58,path={'CELADON_CITY','SAFFRON_CITY'}},
  ROUTE_8={axis="x",cross=58,path={'SAFFRON_CITY','LAVENDER_TOWN'}},
  ROUTE_9={axis="x",cross=64,path={'CERULEAN_CITY',{1780,650},{1880,715}}},
  ROUTE_10={axis="y",cross=60,path={{1880,715},{1930,820},'LAVENDER_TOWN'}},
  ROUTE_11={axis="x",cross=60,path={'VERMILION_CITY',{1945,1230}}},
  ROUTE_12={axis="y",cross=60,path={'LAVENDER_TOWN',{1975,1328}}},
  ROUTE_13={axis="x",cross=58,path={{1750,1400},{1975,1328}}},
  ROUTE_14={axis="y",cross=58,path={{1750,1400},{1650,1500}}},
  ROUTE_15={axis="x",cross=58,path={'FUCHSIA_CITY',{1650,1500}}},
  ROUTE_16={axis="x",cross=55,path={{1080,930},'CELADON_CITY'}},
  ROUTE_17={axis="y",cross=48,path={{1080,930},{1080,1430}}},
  ROUTE_18={axis="x",cross=55,path={{1080,1430},'FUCHSIA_CITY'}},
  ROUTE_19={axis="y",cross=58,path={'FUCHSIA_CITY',{1360,1665}}},
  ROUTE_20={axis="x",cross=70,path={'CINNABAR_ISLAND',{930,1700},{1360,1665}}},
  ROUTE_21={axis="y",cross=70,path={'PALLET_TOWN','CINNABAR_ISLAND'}},
  ROUTE_22={axis="x",cross=58,path={{350,1080},'VIRIDIAN_CITY'}},
  ROUTE_23={axis="y",cross=62,path={'INDIGO_PLATEAU',{365,850},{350,1080}}},
  ROUTE_24={axis="y",cross=55,path={{1568,450},'CERULEAN_CITY'}},
  ROUTE_25={axis="x",cross=55,path={{1568,450},{1970,470}}},

  -- These are outdoor maps under the same Fly-surface test. They share the
  -- compact reserve north of Fuchsia in the regional miniature.
  SAFARI_ZONE_CENTER={point={x=1379,y=1450},spread={x=70,y=55}},
  SAFARI_ZONE_EAST={point={x=1445,y=1450},spread={x=70,y=55}},
  SAFARI_ZONE_NORTH={point={x=1379,y=1390},spread={x=70,y=55}},
  SAFARI_ZONE_WEST={point={x=1315,y=1450},spread={x=70,y=55}},
}}
