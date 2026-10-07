-- Authored lowland cuts in 320x320 world-image coordinates.
-- These cap terrain height near rivers so mountain ridge uplift does not turn
-- a watercourse into a sheer vertical trench. Values are world height units.
return {
  {
    name='CERULEAN_RIVER',
    points={{214,86},{222,80},{240,80},{258,80},{275,82},{290,90}},
    width=18,
    channel=3,
    floor=6,
    rise=4,
  },
}
