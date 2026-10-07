local Flight = {}
local function clamp(n, a, b) return math.max(a, math.min(b, n)) end
function Flight.new(world)
  local start = world.byId.PALLET_TOWN
  return { x = start.x + start.width / 2, y = start.y + start.height / 2,
    altitude = (world.config and world.config.camera_altitude) or 180, cameraX = start.x + start.width / 2,
    cameraY = start.y + start.height / 2, heading = -math.pi / 2,
    cameraHeading = -math.pi / 2, cameraMode = "CHASE", time = 0 }
end
local function angleDelta(a, b) return (b - a + math.pi) % (math.pi * 2) - math.pi end
function Flight.update(p, world, input, dt)
  local c = world.config or {}
  -- Handling constants live in world/config.lua (flight_*); the fallbacks are the
  -- original hard-coded values, so configs written before 0.10.3 behave the same.
  dt = clamp(dt, 0, c.flight_max_dt or 0.05) -- no catch-up jump after focus loss
  local turn = (input:isDown("right") and 1 or 0) - (input:isDown("left") and 1 or 0)
  local turnSpeed = c.flight_turn_speed or 1.85
  p.heading = (p.heading + turn * turnSpeed * dt + math.pi) % (math.pi * 2) - math.pi
  local thrust = (input:isDown("up") and 1 or 0) - (input:isDown("down") and 1 or 0)
  local speed = c.flight_speed or 160
  if thrust < 0 then speed = speed * (c.flight_reverse_scale or .65) end
  local forwardX,forwardY=math.cos(p.heading),math.sin(p.heading)
  p.x = clamp(p.x + forwardX * thrust * speed * dt, world.minX, world.maxX - 1)
  p.y = clamp(p.y + forwardY * thrust * speed * dt, world.minY, world.maxY - 1)
  local vertical = (input:isDown("a") and 1 or 0) - (input:isDown("b") and 1 or 0)
  p.altitude = clamp(p.altitude + vertical * (c.flight_climb_speed or 160) * dt, c.flight_min_altitude or 80, c.flight_max_altitude or 600)
  local blend = 1 - math.exp(-(c.flight_camera_follow or 8) * dt)
  p.cameraX = p.cameraX + (p.x - p.cameraX) * blend
  p.cameraY = p.cameraY + (p.y - p.cameraY) * blend
  local turnBlend = 1 - math.exp(-(c.flight_camera_turn_follow or 5) * dt)
  p.cameraHeading = p.cameraHeading + angleDelta(p.cameraHeading, p.heading) * turnBlend
  p.time = p.time + dt
end
return Flight
