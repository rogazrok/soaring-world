-- Large authored ridge spines in 320x320 world-image coordinates. Each line
-- drives a broad foothill profile across surrounding land plus a narrower
-- crest. Surface material remains independent, so brown texture boundaries
-- never become artificial vertical walls.
return {
  {name='INDIGO_WEST',
 points={{35,78},{38,91},{38,108},{41,124}},
 width=10,height=48},

{name='INDIGO_NORTH',
 points={{39,82},{50,77},{62,79},{72,87}},
 width=9,height=46},

{name='INDIGO_EAST',
 points={{72,87},{75,98},{74,111},{69,123}},
 width=9,height=42},
  {name='MT_MOON_RIDGE',points={{92,82},{119,70},{148,77},{173,68}},width=21,height=72},
  {name='NORTH_RIM',points={{145,49},{178,42},{218,49}},width=18,height=56},
  -- Extended farther east so Route 10 and the Power Plant sit inside a readable
  -- mountain corridor instead of a flat shelf.
  {name='ROCK_TUNNEL_RIDGE',
 points={{231,77},{251,84},{267,82},{274,94},{278,100}},
 width=10,height=42},
  -- A narrower ridge east of Lavender Town helps the town read as nestled
  -- against the Route 10 / coastal mountain wall without turning the town
  -- center itself into a sharp mesa.

}
