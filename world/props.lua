-- Box primitives: w/d in image pixels, h in world height units.
-- Templates contain data only. Change dimensions or city layout here.
return {
 -- The four blocks are the real Player/Rival house roof/facade blocks from
 -- imported Red. They are fetched at runtime, never included in the mod.
 house_small={w=6,d=5,h=9,top=5,sideA=6,sideB=2,topTile=60,wallTile=61,kind='house'},
 house_large={w=8,d=6,h=12,top=5,sideA=6,sideB=2,topTile=60,wallTile=61,kind='house_large'},
 -- 8 = red roof, 9 = blue roof in Stylized.palette. These landmark colors
 -- are deliberately data-driven and separate from imported game tiles.
 pokemon_center={w=8,d=6,h=13,top=8,sideA=8,sideB=6,topTile=64,wallTile=65,kind='center'},
 poke_mart={w=7,d=5,h=11,top=9,sideA=9,sideB=6,topTile=64,wallTile=65,kind='mart'},
 gym={w=10,d=8,h=16,top=6,sideA=5,sideB=1,topTile=80,wallTile=81,kind='gym'},
 oak_lab={w=11,d=7,h=14,top=4,sideA=6,sideB=2,topTile=62,wallTile=63,kind='lab'},
 -- Vegetation has real 360-degree geometry. tree/tree_cluster remain as
 -- compatibility aliases for older authored worlds.
 tree_single={w=2.6,d=2.6,h=12,top=2,sideA=1,sideB=1,kind='tree_broadleaf'},
 tree={w=2.6,d=2.6,h=12,top=2,sideA=1,sideB=1,kind='tree_broadleaf'},
 forest_tree={w=2.35,d=2.35,h=10.5,top=2,sideA=1,sideB=1,kind='tree_broadleaf'},
 tree_pine={w=1.65,d=1.65,h=23,top=2,sideA=1,sideB=1,kind='tree_pine'},
 tree_group={parts={
   {type='tree_single',x=-1.7,y=.4,scale=.92},
   {type='tree_single',x=1.5,y=.8,scale=1.04},
   {type='tree_single',x=.2,y=-1.5,scale=.86},
 }},
 tree_cluster={},
 forest_cluster={},
 rock={w=3,d=3,h=5,top=4,sideA=2,sideB=1},
 -- Reusable world-dressing rocks. These were introduced by the 0.7.7
 -- generator; keep them explicit so generated/details.lua can be validated
 -- before the scene is constructed.
 rock_single={w=2.7,d=2.5,h=4.2,top=4,sideA=2,sideB=1},
 rock_group={parts={
   {type='rock_single',x=-1.5,y=.2,scale=.88},
   {type='rock_single',x=1.2,y=.5,scale=1.03},
   {type='rock_single',x=.1,y=-1.3,scale=.72},
 }},
 mountain_peak={w=5,d=5,h=18,top=5,sideA=6,sideB=1},
 -- Modular bridge: ground origin at the feet; local +Y follows the roadway.
 bridge_segment={w=4.5,d=12,h=22,kind='bridge_segment'},
 -- Single 90-degree corner; identical roadway width and pier/deck height.
 bridge_corner_90={w=4.5,d=12,h=22,kind='bridge_segment',turn=90},
 dock={w=3,d=10,h=2,top=5,sideA=2,sideB=1},
 cave={w=4,d=3,h=5,top=1,sideA=1,sideB=1},
 -- Runtime fallback silhouettes. Normal builds replace these named instances
 -- with closed, atlas-textured models from generated/buildings.lua.
 pokemon_tower={w=15,d=14,h=48,top=10,sideA=5,sideB=5,topTile=60,wallTile=61},
 power_plant={w=34,d=18,h=12,top=7,sideA=6,sideB=5,topTile=64,wallTile=65},
 city_midrise={w=18,d=14,h=28,top=11,sideA=6,sideB=5,topTile=60,wallTile=61},
 city_highrise={w=21,d=16,h=35,top=11,sideA=6,sideB=5,topTile=60,wallTile=61},
 silph_tower={w=30,d=22,h=47,top=11,sideA=6,sideB=5,topTile=60,wallTile=61},
 pallet={parts={{type='house_small',x=-5,y=-3},{type='house_small',x=5,y=-3},{type='oak_lab',x=3,y=3}}},
 city={parts={{type='house_small',x=-6,y=3},{type='house_large',x=5,y=4},
   {type='pokemon_center',x=-6,y=-4},{type='gym',x=5,y=-4},{type='tree',x=-10,y=0}}},
}
