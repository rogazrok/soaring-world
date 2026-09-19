local Flight = {}
local function clamp(n, a, b) return math.max(a, math.min(b, n)) end
function Flight.new(world)
  local start = world.byId.PALLET_TOWN
  return { x = start.x + start.width / 2, y = start.y + start.height / 2,
    altitude = (world.config and world.config.camera_altitude) or 180, cameraX = start.x + start.width / 2,
    cameraY = start.y + start.height / 2, time = 0 }
end
function Flight.update(p, world, input, dt)
  dt = clamp(dt, 0, 0.05) -- no catch-up jump after focus loss
  local x = (input:isDown("right") and 1 or 0) - (input:isDown("left") and 1 or 0)
  local y = (input:isDown("down") and 1 or 0) - (input:isDown("up") and 1 or 0)
  local length = math.sqrt(x*x + y*y)
  if length > 0 then x, y = x / length, y / length end
  local c = world.config or {}
  local speed = c.flight_speed or 160
  p.x = clamp(p.x + x * speed * dt, world.minX, world.maxX - 1)
  p.y = clamp(p.y + y * speed * dt, world.minY, world.maxY - 1)
  local vertical = (input:isDown("a") and 1 or 0) - (input:isDown("b") and 1 or 0)
  p.altitude = clamp(p.altitude + vertical * 160 * dt, c.flight_min_altitude or 80, c.flight_max_altitude or 600)
  local blend = 1 - math.exp(-8 * dt)
  p.cameraX = p.cameraX + (p.x - p.cameraX) * blend
  p.cameraY = p.cameraY + (p.y - p.cameraY) * blend
  p.time = p.time + dt
end
return Flight
