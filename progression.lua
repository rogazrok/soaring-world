-- Soaring progression. Native Red fly-town data owns both visit flags and
-- arrival cells; Soaring only supplies the matching world-space zone id.
local M = {}
local Map = require('src.world.Map')

function M.canSoar(game, origin)
  -- The future badge gate belongs here. It is intentionally disabled.
  return true
end

-- loc.id is the engine map id for every ordinary destination in locations.lua.
-- flyWarps also contains dungeon-escape spots, so use flyOrder and isFlyTown
-- as well: the ordinary Fly picker applies the same restrictions.
function M.destination(game, loc)
  local id = loc and loc.id
  local data = game and game.data
  local field = data and data.field or {}
  local def = data and data.maps and data.maps[id]
  local spot = field.flyWarps and field.flyWarps[id]
  if not (def and spot and Map.isFlyTown(def)
      and type(spot.x)=='number' and type(spot.y)=='number') then
    return nil, 'destination unavailable'
  end
  local listed = false
  for _, flyId in ipairs(field.flyOrder or {}) do
    if flyId == id then listed = true; break end
  end
  if not listed then return nil, 'destination unavailable' end
  return {map=id, x=spot.x, y=spot.y, facing='down'}
end

-- No mod-owned visited table. The sole compatibility rule covers an older
-- save that has reached Pallet outdoors but lacks its initial visited bit:
-- a flight launched FROM Pallet may land back there. Other unvisited towns
-- remain locked, including Pallet when the player started elsewhere.
function M.canLandAt(game, loc, origin, hiddenAreas, mod, hiddenRegistry)
  if loc and loc.kind=='hidden' then
    return hiddenAreas.canLandAt(mod,game,hiddenRegistry,loc)
  end
  local destination, reason = M.destination(game, loc)
  if not destination then return false, reason end
  local visited = game and game.save and game.save.visited
  if visited and visited[destination.map] then return true, nil, destination end
  if destination.map == 'PALLET_TOWN' and origin
      and origin.mapId == 'PALLET_TOWN' then
    return true, nil, destination
  end
  return false, 'unvisited'
end

return M
