-- Pure visual-data adapter. One world unit = one source pixel (32/block).
-- No MapLoader, controllers, scripts, encounters, warps or save access.
local World = {}
local directions = { "north", "south", "west", "east" }

function World.build(getMap, ids, root)
  local world = { maps = {}, byId = {} }
  for _, id in ipairs(ids) do
    local def = assert(getMap(id), "Missing imported map: " .. id)
    assert(def.width > 0 and def.height > 0, "Invalid map dimensions: " .. id)
    assert(#def.blocks == def.width * def.height, "Incomplete blocks: " .. id)
    assert(def.tileset == "OVERWORLD", "Expected outdoor OVERWORLD map: " .. id)
    local m = { id = id, def = def, width = def.width * 32, height = def.height * 32 }
    world.maps[#world.maps + 1], world.byId[id] = m, m
  end
  local origin = assert(world.byId[root], "Missing layout root")
  origin.x, origin.y = 0, 0
  local queue, head = { origin }, 1
  while queue[head] do
    local m = queue[head]
    head = head + 1
    for _, dir in ipairs(directions) do
      local c = (m.def.connections or {})[dir]
      local n = c and world.byId[c.map]
      if n then
        local x, y = m.x, m.y
        local offset = assert(tonumber(c.offset), "Missing connection offset") * 32
        if dir == "north" then x, y = x + offset, y - n.height
        elseif dir == "south" then x, y = x + offset, y + m.height
        elseif dir == "west" then x, y = x - n.width, y + offset
        else x, y = x + m.width, y + offset end
        if n.x then
          assert(n.x == x and n.y == y, "Inconsistent connections: " .. m.id .. " -> " .. n.id)
        else
          n.x, n.y = x, y
          queue[#queue + 1] = n
        end
      end
    end
  end
  world.minX, world.minY, world.maxX, world.maxY = math.huge, math.huge, -math.huge, -math.huge
  for _, m in ipairs(world.maps) do
    assert(m.x, "Disconnected map: " .. m.id)
    world.minX, world.minY = math.min(world.minX, m.x), math.min(world.minY, m.y)
    world.maxX, world.maxY = math.max(world.maxX, m.x + m.width), math.max(world.maxY, m.y + m.height)
  end
  return world
end

function World.tileAt(def, tileset, tx, ty)
  local bx, by = math.floor(tx / 4), math.floor(ty / 4)
  local blockId = assert(def.blocks[by * def.width + bx + 1], "Missing block")
  local block = assert(tileset.blocks[blockId + 1], "Unknown block " .. tostring(blockId))
  return assert(block[(ty % 4) * 4 + tx % 4 + 1], "Missing tile")
end

function World.mapAt(world, x, y)
  for _, m in ipairs(world.maps) do
    if x >= m.x and y >= m.y and x < m.x + m.width and y < m.y + m.height then return m.id end
  end
end

return World
