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
 -- The three silhouettes remain readable after the scene is reduced to 160x144.
 tree={w=3,d=3,h=8,top=2,sideA=1,sideB=1,kind='tree_broadleaf'},
 tree_pine={w=3,d=3,h=10,top=2,sideA=1,sideB=1,kind='tree_pine'},
 tree_cluster={},
 rock={w=3,d=3,h=5,top=4,sideA=2,sideB=1},
 mountain_peak={w=5,d=5,h=18,top=5,sideA=6,sideB=1},
 dock={w=3,d=10,h=2,top=5,sideA=2,sideB=1},
 cave={w=4,d=3,h=5,top=1,sideA=1,sideB=1},
 pallet={parts={{type='house_small',x=-5,y=-3},{type='house_small',x=5,y=-3},{type='oak_lab',x=3,y=3}}},
 city={parts={{type='house_small',x=-6,y=3},{type='house_large',x=5,y=4},
   {type='pokemon_center',x=-6,y=-4},{type='gym',x=5,y=-4},{type='tree',x=-10,y=0}}},
}
