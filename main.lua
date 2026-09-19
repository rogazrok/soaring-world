return function(mod)
  -- The manager can force an unsupported game; keep this experiment Red-only.
  if require("src.core.GameVersion").get() ~= "red" then return end
  local function module(name)
    return assert(loadstring(assert(mod:read(name .. ".lua")), "@soaring/" .. name))()
  end
  local World, Flight, Renderer = module("world"), module("flight"), module("renderer")
  local Elevation = module("elevation")
  local Stylized = module("stylized")
  local screenId = "SoaringWorldRedExperiment"
  local active, drain = nil, false
  local buttons = { "up", "down", "left", "right", "a", "b", "start", "select" }
  local function anyDown(input)
    for _, key in ipairs(buttons) do if input:isDown(key) then return true end end
    return false
  end
  local function close(screen)
    if screen.game.stack:top() == screen then screen.game.stack:pop() end
  end
  local cameraModes = {CHASE="HIGH_SOAR", HIGH_SOAR="DEBUG_TOP", DEBUG_TOP="CHASE"}
  local function cycleCamera(screen)
    screen.flight.cameraMode = cameraModes[screen.flight.cameraMode] or "CHASE"
  end

  local function newScreen(game, stylized)
    local screen = { game = game, isOpaque = true, armed = false }
    -- Own the scene's colors instead of inheriting the hidden overworld palette.
    function screen:sgbPalettes() return nil end
    -- Construct everything before activation. A missing cache leaves a dismissible
    -- diagnostic screen, never a half-active overworld or partial state restore.
    local ok, err = pcall(function()
      if stylized then
        screen.world = Stylized.load(function(path) return mod:read(path) end)
        screen.flight = Flight.new(screen.world)
        screen.renderer = Stylized.renderer(screen.world, require("src.render.Assets").image, mod.content.tilesets:get("OVERWORLD"), mod.ui.Font)
        return
      end
      screen.world = World.build(function(id) return mod.content.maps:get(id) end,
        { "PALLET_TOWN", "ROUTE_1", "VIRIDIAN_CITY" }, "PALLET_TOWN")
      screen.flight = Flight.new(screen.world)
      Elevation.attach(screen.world, function(path) return mod:read(path) end)
      for _, warning in ipairs(screen.world.elevationWarnings) do print('[soaring elevation] '..warning) end
      -- Public mod.assets:image only resolves files owned by this mod.
      -- One explicit private adapter resolves the user's imported atlas.
      local Assets = require("src.render.Assets")
      screen.renderer = Renderer.new(screen.world,
        function(id) return mod.content.tilesets:get(id) end, Assets.image, World)
    end)
    if not ok then screen.problem = tostring(err); print("[soaring_world_red] " .. screen.problem) end
    function screen:enter() active = self end
    -- Route mapped controls directly while this screen owns input. Engine
    -- quick-save/load, mod-reload and display hotkeys must not mutate the session.
    function screen:onKeyPressed(key)
      if key == "escape" then close(self); return end
      if stylized and key == "c" and self.flight then
        cycleCamera(self)
        return
      end
      if stylized and key == "r" then
        local ok, message = pcall(function()
          local nextWorld = Stylized.load(function(path) return mod:read(path) end)
          local nextRenderer = Stylized.renderer(nextWorld, require("src.render.Assets").image, mod.content.tilesets:get("OVERWORLD"), mod.ui.Font)
          if self.renderer then self.renderer:release() end
          self.world, self.renderer = nextWorld, nextRenderer
          self.flight.x = math.min(self.flight.x, nextWorld.maxX-1)
          self.flight.y = math.min(self.flight.y, nextWorld.maxY-1)
          self.problem = nil
        end)
        if ok then self.reloadMessage = nil else self.reloadMessage = tostring(message) end
        if not ok then print('[soaring reload] '..self.reloadMessage) end
        return
      end
      self.game.input:keypressed(key)
    end
    function screen:onGamepadPressed(button)
      self.game.input:gamepadpressed(nil, button)
    end
    function screen:exit()
      if self.renderer then self.renderer:release(); self.renderer = nil end
      if active == self then active = nil end
      drain = true
    end
    function screen:update(dt)
      local input = self.game.input
      if not self.armed then self.armed = not anyDown(input); return end
      if input:wasPressed("start") then close(self); return end
      if input:wasPressed("select") then
        if stylized then cycleCamera(self) else close(self) end
        return
      end
      if self.problem then return end
      Flight.update(self.flight, self.world, input, dt)
      if stylized then self.flight.altitude = math.max(self.flight.altitude,self.world:getGroundHeight(self.flight.x,self.flight.y)+30) end
    end
    function screen:draw()
      local g = love.graphics
      g.push("all")
      local success, message = pcall(function()
        if self.renderer and not self.problem then self.renderer:draw(self.flight)
        else g.setColor(0, 0, 0, 1); g.rectangle("fill", 0, 0, 160, 144) end
        if stylized and not self.problem then
          return
        end
        g.setColor(1, 1, 1, 1)
        -- Imported Gen 1 font glyphs are black, so give HUD text a light backing.
        g.rectangle("fill", 0, 0, 160, self.problem and 64 or 16)
        g.rectangle("fill", 0, 128, 160, 16)
        local Font = mod.ui.Font
        if self.problem then
          Font.draw("SOARING UNAVAILABLE", 0, 16)
          Font.draw("SEE ENGINE LOG", 0, 32)
          Font.draw("START: RETURN", 0, 48)
        else
          local name = World.mapAt(self.world, self.flight.x, self.flight.y) or "OUTSIDE MAPS"
          Font.draw(name:gsub("_", " "), 0, 0)
          Font.draw("ALT " .. math.floor(self.flight.altitude), 0, 8)
          Font.draw("PAD MOVE  A/B HEIGHT", 0, 128)
          Font.draw("START/SELECT RETURN", 0, 136)
        end
      end)
      g.pop()
      if not success then self.problem = tostring(message); print("[soaring_world_red] " .. self.problem) end
    end
    return screen
  end
  mod.content.screens:register(screenId, {new=function(game) return newScreen(game,false) end})
  mod.content.screens:register("SoaringStylizedRed", {new=function(game) return newScreen(game,true) end})

  mod.hooks:wrap("ui.start_menu.items", function(next, game, items)
    local out = next(game, items)
    local base = game.stack and game.stack.states and game.stack.states[1]
    if type(out) ~= "table" or not (base and base.isOverworld) or game.linkSession or game.linkNet then return out end
    out = mod.ui.insertBefore(out, "SAVE", {label="SOAR WORLD", onSelect=function()
      if not active then mod.ui.push(game,"SoaringStylizedRed") end
    end})
    -- SOAR TEST stays registered only as an internal compatibility experiment.
    -- Keeping it out of Start prevents players from entering the obsolete scene.
    return out
  end)

  -- Pause the entire simulation clock, not only NPC update: no RNG, playTime,
  -- map scripts, encounters, autosave or sync updates from Game:update.
  -- Read the engine's mapped buttons at real frame rate; fast-forward has no effect.
  mod.hooks:wrap("core.update", function(next, game, dt)
    if active and active.game == game and game.stack:top() == active then
      game.input:step()
      local ok, err = pcall(active.update, active, dt)
      if not ok then active.problem = tostring(err); close(active) end
      return
    end
    if drain then
      game.input:step()
      if not anyDown(game.input) then drain = false end
      return -- released exit/movement buttons never reach the overworld
    end
    return next(game, dt)
  end, 100)

  mod.exports.status = function()
    return { active = active ~= nil, problem = active and active.problem or nil }
  end
end
