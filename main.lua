return function(mod)
  -- The manager can force an unsupported game; keep this experiment Red-only.
  if require("src.core.GameVersion").get() ~= "red" then return end
  local function module(name)
    return assert(loadstring(assert(mod:read(name .. ".lua")), "@soaring/" .. name))()
  end
  local World, Flight, Renderer = module("world"), module("flight"), module("renderer")
  local Elevation = module("elevation")
  local Stylized = module("stylized")
  local NativeRenderer = module("native_renderer")
  local LocationController = module("location_controller")
  local SoaringUI = module("soaring_ui")
  local OriginResolver = module("origin_resolver")
  local FlightEffects = module("flight_effects")
  local Actions = module("soaring_actions")
  local Progression = module("progression")
  local HiddenAreas = module("hidden_areas")
  local HiddenDebug = module("hidden_debug")
  local DragonTakeoff = module("dragon_takeoff")
  local LoadingAnimation = module("loading_animation")
  local LoadingWings = module("loading_wings")
  local RiderMotion = module("rider_motion")
  local DayNight = module("day_night")
  local LoadingBuilder = module("loading_builder")
  local SoaringMap = module("soaring_map")
  local hiddenRegistry = HiddenAreas.load(function(path) return mod:read(path) end)
  -- Recover pre-0.10.19 fixed rewards before any map/NPC is restored.
  -- Existing item selections and claim bits are left intact.
  mod.migrations:add('0.10.19',HiddenAreas.migrateLegacyRewards)
  HiddenAreas.register(mod,hiddenRegistry)
  -- Native arrival tails and battle restoration resolve music by map ID.
  for _,area in ipairs(hiddenRegistry.areas) do
    if area.music then mod.content.map_songs:register(area.mapId,area.music) end
  end
  local function canLand(game,loc,origin)
    return Progression.canLandAt(game,loc,origin,HiddenAreas,mod,hiddenRegistry)
  end
  local function loadLocations(game,origin)
    local activeLocation=HiddenAreas.activeLocation(mod,hiddenRegistry)
    return LocationController.load(function(path) return mod:read(path) end,
      function(mapId) return game.data and game.data.maps and game.data.maps[mapId] ~= nil end,
      Actions,function(loc) return canLand(game,loc,origin) end,
      function(loc) return HiddenAreas.isVisible(mod,hiddenRegistry,loc) end,
      function(loc) HiddenAreas.onApproach(mod,hiddenRegistry,loc) end,
      activeLocation and {activeLocation} or {})
  end
  local Map = require("src.world.Map")
  local FieldDefaults = require("src.world.FieldDefaults")
  local Music = require("src.core.Music")
  local MUSIC_STEP = 1 / 60
  -- Runtime diagnostics go through the sanctioned mod.log (lines attributed to the
  -- mod id). Plain print is only the fallback if the logger is missing or throws.
  local function log(level, fmt, ...)
    local logger = mod.log
    local fn = logger and logger[level]
    if type(fn) == "function" and pcall(fn, logger, fmt, ...) then return end
    local ok, text = pcall(string.format, fmt, ...)
    print("[soaring_world_red] " .. level .. ": " .. (ok and text or tostring(fmt)))
  end
  -- Fly's departure (OverworldState:flyTo) unconditionally dismounts the Bicycle and
  -- ends Surf. Soaring can be cancelled, so capture those flags before takeoff and
  -- restore them when control returns to the same overworld. A landing is a real
  -- Fly-style arrival on foot, so it never restores.
  local function captureRideState(game, ow)
    local save, player = game.save, ow and ow.player
    return { ow = ow, onBike = save and save.onBike, forcedBike = save and save.forcedBike,
      surfing = player and player.surfing }
  end
  local function restoreRideState(game, ow, ride)
    if not ride or not ow or ow ~= ride.ow then return end
    local save, player = game.save, ow.player
    if save then save.onBike = ride.onBike; save.forcedBike = ride.forcedBike end
    if player then player.surfing = ride.surfing end
    if type(ow.syncSurfingPikachu) == "function" then pcall(ow.syncSurfingPikachu, ow) end
  end
  local originResolver = OriginResolver.load(function(path) return mod:read(path) end)
  for _, warning in ipairs(originResolver.warnings or {}) do log("warn", "takeoff: %s", warning) end
  local screenId = "SoaringWorldRedExperiment"
  local active, drain, pendingLaunch, launchCover, hiddenExitInProgress = nil, false, nil, nil, nil
  local lanceEventRunning=false
  local lanceReplayRequested=false
  local buttons = { "up", "down", "left", "right", "a", "b", "start", "select" }
  local function anyDown(input)
    for _, key in ipairs(buttons) do if input:isDown(key) then return true end end
    return false
  end
  local function close(screen)
    if screen.game.stack:top() == screen then screen.game.stack:pop() end
  end
  local function cycleCamera(screen)
    local mode=screen.flight.cameraMode
    if mode=='CHASE' then screen.flight.cameraMode='HIGH_SOAR'
    elseif mode=='HIGH_SOAR' and hiddenRegistry.config.debugEnabled then screen.flight.cameraMode='DEBUG_TOP'
    else screen.flight.cameraMode='CHASE' end
  end

  -- Ask the same live OverworldState used by normal maps. Vanilla Red safely
  -- answers DAY; an optional world.tod hook can supply its current label.
  local function currentEngineTimeOfDay()
    local ok,ow=pcall(function() return mod.world and mod.world:overworld() end)
    if ok and ow and type(ow.timeOfDay)=='function' then
      local read,value=pcall(ow.timeOfDay,ow)
      if read and type(value)=='string' and value~='' then return value end
      if type(ow.tod)=='string' and ow.tod~='' then return ow.tod end
    end
    return 'DAY'
  end
  local function currentTransitionNightAmount()
    local _,amount=DayNight.normalize(currentEngineTimeOfDay())
    local strength=.86
    local enabled=true
    local ok,cfg=pcall(function()
      return assert(loadstring(assert(mod:read('world/config.lua')),'@world/config.lua'))()
    end)
    if ok and type(cfg)=='table' then
      strength=tonumber(cfg.soaring_night_strength) or strength
      enabled=cfg.soaring_day_night~=false
    end
    if not enabled then return 0 end
    return math.max(0,math.min(1,amount*math.max(0,math.min(1,strength))))
  end

  local function newScreen(game, stylized, launch, yieldBuild)
    local screen = { game = game, isOpaque = true, armed = false }
    -- Set before anything can fail: a diagnostic screen dismissed with START must
    -- still hand back the Bike/Surf state that takeoff cleared.
    screen.ride = launch and launch.ride or nil
    -- Own the scene's colors instead of inheriting the hidden overworld palette.
    function screen:sgbPalettes() return nil end
    -- Construct everything before activation. A missing cache leaves a dismissible
    -- diagnostic screen, never a half-active overworld or partial state restore.
    local function construct()
      if stylized then
        screen.world = Stylized.load(function(path) return mod:read(path) end)
        if yieldBuild then yieldBuild() end
        HiddenAreas.decorateWorld(mod,hiddenRegistry,screen.world)
        if yieldBuild then yieldBuild() end
        screen.flight = Flight.new(screen.world)
        screen.riderMotion = RiderMotion.new(screen.world.config)
        screen.dayNight = DayNight.new(screen.world.config)
        if launch and launch.spawn then
          local spawn=launch.spawn
          screen.flight.x=math.max(screen.world.minX,math.min(screen.world.maxX-1,spawn.x))
          screen.flight.y=math.max(screen.world.minY,math.min(screen.world.maxY-1,spawn.y))
          screen.flight.cameraX,screen.flight.cameraY=screen.flight.x,screen.flight.y
          if spawn.altitude then screen.flight.altitude=spawn.altitude end
          screen.flight.heading=spawn.heading or screen.flight.heading
          screen.flight.cameraHeading=screen.flight.heading
        end
        screen.effects = FlightEffects.new(function(path) return mod:read(path) end, screen.world.config)
        if yieldBuild then yieldBuild() end
        screen.renderer = NativeRenderer.new(screen.world, Stylized, require("src.render.Assets").image, mod.content.tilesets:get("OVERWORLD"), mod.ui.Font,screen.effects,
          yieldBuild and {yieldBuild=yieldBuild} or nil)
        screen.origin = launch and launch.origin or mod.world:current()
        screen.locations = loadLocations(game,screen.origin)
        screen.soaringUI = SoaringUI.new(mod.ui.Font)
        for _,warning in ipairs(screen.locations.warnings) do log("warn", "locations: %s", warning) end
        return
      end
      screen.world = World.build(function(id) return mod.content.maps:get(id) end,
        { "PALLET_TOWN", "ROUTE_1", "VIRIDIAN_CITY" }, "PALLET_TOWN")
      screen.flight = Flight.new(screen.world)
      Elevation.attach(screen.world, function(path) return mod:read(path) end)
      for _, warning in ipairs(screen.world.elevationWarnings) do log("warn", "elevation: %s", warning) end
      -- Public mod.assets:image only resolves files owned by this mod.
      -- One explicit private adapter resolves the user's imported atlas.
      local Assets = require("src.render.Assets")
      screen.renderer = Renderer.new(screen.world,
        function(id) return mod.content.tilesets:get(id) end, Assets.image, World)
    end
    if yieldBuild then
      -- The loading builder runs in its own coroutine. Avoid pcall around this
      -- path because some Lua runtimes cannot yield across a protected C call.
      construct()
    else
      local ok, err = pcall(construct)
      if not ok then screen.problem = tostring(err); log("error", "Soaring failed to start: %s", screen.problem) end
    end
    function screen:enter()
      active=self
      if stylized then
        -- Initialize before the first flight frame; no temporary daytime flash.
        self.dayNight:enter(currentEngineTimeOfDay())
        self.soaringSong=Music.special(self.game.data,'surf') or 'Music_Surfing'
        Music.play(self.game.data,self.soaringSong,true,{reason='soaring_world'})
      end
    end
    -- Route mapped controls directly while this screen owns input. Engine
    -- quick-save/load, mod-reload and display hotkeys must not mutate the session.
    function screen:onKeyPressed(key)
      -- Physical keys, including Esc, follow the player's action bindings.
      if hiddenRegistry.config.debugEnabled and stylized and key == "m" and self.riderMotion then
        self.riderMotion:toggleDebug()
        log("info","rider motion comparison: %s",self.riderMotion.enabled and "ON" or "OFF")
        return
      end
      if hiddenRegistry.config.debugEnabled and stylized and key == "t" and self.dayNight then
        local preview=self.dayNight:cyclePreview()
        log("info","Soaring time-of-day preview: %s",preview)
        return
      end
      if hiddenRegistry.config.debugEnabled and stylized and key == "c" and self.flight then
        cycleCamera(self)
        return
      end
      if hiddenRegistry.config.debugEnabled and stylized and key == "r" then
        local ok, message = pcall(function()
          local nextWorld = Stylized.load(function(path) return mod:read(path) end)
          HiddenAreas.decorateWorld(mod,hiddenRegistry,nextWorld)
          local nextEffects = FlightEffects.new(function(path) return mod:read(path) end, nextWorld.config)
          local nextRenderer = NativeRenderer.new(nextWorld, Stylized, require("src.render.Assets").image, mod.content.tilesets:get("OVERWORLD"), mod.ui.Font,nextEffects)
          local nextLocations = loadLocations(self.game,self.origin)
          if self.renderer then self.renderer:release() end
          if self.effects then self.effects:release() end
          self.world, self.renderer, self.locations, self.effects = nextWorld, nextRenderer, nextLocations, nextEffects
          self.flight.x = math.min(self.flight.x, nextWorld.maxX-1)
          self.flight.y = math.min(self.flight.y, nextWorld.maxY-1)
          self.problem = nil
        end)
        if ok then self.reloadMessage = nil else self.reloadMessage = tostring(message) end
        if ok and self.riderMotion then
          self.riderMotion.enabled=self.world.config.rider_motion_enabled~=false
          self.riderMotion.debugOverride=nil
        end
        if not ok then log("warn", "reload failed: %s", self.reloadMessage) end
        return
      end
      self.game.input:keypressed(key)
    end
    function screen:onGamepadPressed(button)
      self.game.input:gamepadpressed(nil, button)
    end
    function screen:exit()
      if self.renderer then self.renderer:release(); self.renderer = nil end
      if self.effects then self.effects:release();self.effects=nil end
      if self.soaringUI then self.soaringUI:release();self.soaringUI=nil end
      -- Cancelled or failed flight: hand back the Bike/Surf state takeoff cleared.
      -- (A successful landing reaches locations.state=='GAME' and arrives on
      -- foot, like Fly, so it never restores.)
      if not (self.locations and self.locations.state=='GAME') and self.ride then
        local okRestore, restoreErr = pcall(function()
          restoreRideState(self.game, mod.world:overworld(), self.ride)
        end)
        if not okRestore then log("warn", "could not restore Bike/Surf state: %s", tostring(restoreErr)) end
      end
      if self.soaringSong then
        local ow=mod.world:overworld()
        if ow and ow.map then
          Music.playMap(self.game.data,ow.map.id,self.game.save.onBike,
            ow.player and ow.player.surfing,nil)
        end
        self.soaringSong=nil
      end
      if active == self then active = nil end
      drain = true
    end
    function screen:beginLanding(location)
      self.landingFade={alpha=0,duration=self.locations.settings.fade_out_seconds,requested=false}
    end
    function screen:requestLandingWarp()
      -- self.locations.landing is frozen from here on: Controller:update
      -- returns immediately for TRANSITION/GAME (location_controller.lua)
      -- and never recomputes it, so this is the same location beginLanding
      -- was called with -- no separate copy needed on screen.
      local location=self.locations.landing
      local allowed,reason,d=canLand(self.game,location,self.origin)
      if not (allowed and location and location.destinationValid) then
        log("warn", "landing at %s refused: %s", tostring(location and location.id),tostring(reason))
        self.locations:failTransition(reason or 'INVALID DESTINATION');self.landingFade={alpha=1,duration=.2,recover=true}
        return
      end
      local completed=false
      local called,ok,reason=pcall(function()
        return mod.world:warpTo(d.map,d.x,d.y,d.facing,{onDone=function()
          if completed then return end;completed=true
          if location.kind=='hidden' then
            local checkpoint=self.origin
            if self.ride and self.ride.surfing then checkpoint=nil end
            HiddenAreas.saveReturn(mod,hiddenRegistry,location,self.flight,checkpoint)
            HiddenAreas.onEntered(mod,hiddenRegistry,hiddenRegistry.byId[location.id],game)
          end
          self.locations:markGame();self.transitionCover=false
          close(self)
          local ow=game.overworld
          -- Native warp still owns map/arrival coordinates. Replace only its
          -- bird animation, for both cities and authored hidden destinations.
          ow.player.onBike=false;ow.player.surfing=false;ow.forcedBike=nil
          ow.player.inputLocked=false
          game.stack:push(DragonTakeoff.new(game,mod,ow,function() drain=true end,nil,true,currentTransitionNightAmount()))
        end})
      end)
      if not called or not ok then
        log("warn", "landing at %s failed: %s", tostring(location.id), tostring(called and reason or ok))
        self.transitionCover=false
        self.locations:failTransition(called and reason or ok)
        self.landingFade={alpha=1,duration=.22,recover=true}
        return
      end
      self.transitionCover=true
      self.landingFade=nil
    end
    function screen:update(dt)
      local input = self.game.input
      if stylized and self.dayNight then self.dayNight:update(currentEngineTimeOfDay(),dt,self.world.config) end
      if self.effects then self.effects:update(self.flight,dt) end
      if not self.armed then self.armed = not anyDown(input); return end
      -- A diagnostic ("SOARING ERROR") screen has no flight session to
      -- cancel out of -- START here only dismisses that screen, and is the
      -- only thing this screen still does with START. Checked first and
      -- exclusively: START/SELECT no longer cancel a normal flight (see
      -- SOARING_GAMEPLAY_STATE_PASS.md item 1) and neither key does
      -- anything else while a diagnostic is showing.
      if self.problem then
        if Actions.pressed(input,"DIAGNOSTIC_DISMISS") then close(self) end
        return
      end
      if Actions.pressed(input,"START_ACTION") and not self.landingFade
          and (not self.locations or self.locations.state~='TRANSITION') then
        self.mapScreen=SoaringMap.new(self.game,self,self.locations,
          mod.assets:image('assets/dragonite_town_map.png'))
        self.game.stack:push(self.mapScreen)
        return
      end
      if Actions.pressed(input,"CAMERA_CYCLE") and not (self.locations and self.locations.state=='CONFIRM') then
        if stylized then cycleCamera(self) end
        return
      end
      if stylized and self.locations then
        self.locations:tickMessage(dt)
        if self.landingFade then
          local f=self.landingFade
          if f.recover then
            f.alpha=math.max(0,f.alpha-dt/f.duration)
            if f.alpha<=0 then self.landingFade=nil end
          else
            f.alpha=math.min(1,f.alpha+dt/f.duration)
            if f.alpha>=1 and not f.requested then f.requested=true;self:requestLandingWarp() end
          end
          return
        end
        local action,location=self.locations:update(self.flight,input,dt)
        if action=='land' then self:beginLanding(location);return end
        if action or self.locations.state=='CONFIRM' or self.locations.state=='TRANSITION' then return end
      end
      local oldAltitude=self.flight.altitude
      Flight.update(self.flight, self.world, input, dt)
      if stylized then
        local climbed=self.flight.altitude-oldAltitude
        self.flight.altitude = math.max(self.flight.altitude,self.world:getGroundHeight(self.flight.x,self.flight.y)+(self.world.config.flight_terrain_clearance or 30))
        if self.riderMotion then self.riderMotion:update(input,dt,self.world.config,climbed) end
      end
    end
    function screen:draw()
      local g = love.graphics
      g.push("all")
      local success, message = pcall(function()
        if self.renderer and not self.problem then
          if not stylized then self.renderer:draw(self.flight) end
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
          -- Show the captured constructor/runtime error in-game. This makes
          -- release regressions diagnosable from a screenshot without asking
          -- players to locate the engine log.
          g.rectangle("fill", 0, 0, 160, 128)
          Font.draw("SOARING ERROR", 0, 0)
          local msg=tostring(self.problem):gsub("\n"," ")
          local lines={}
          while #msg>0 and #lines<12 do
            local cut=math.min(19,#msg)
            if #msg>19 then
              local chunk=msg:sub(1,19)
              local sp=chunk:match("^.*() ")
              if sp and sp>6 then cut=sp-1 end
            end
            lines[#lines+1]=msg:sub(1,cut)
            msg=msg:sub(cut+1):gsub("^ +","")
          end
          for i,line in ipairs(lines) do Font.draw(line,0,i*8) end
          Font.draw("START: RETURN",0,120)
        else
          local name = World.mapAt(self.world, self.flight.x, self.flight.y) or "OUTSIDE MAPS"
          Font.draw(name:gsub("_", " "), 0, 0)
          Font.draw("ALT " .. math.floor(self.flight.altitude), 0, 8)
          Font.draw("PAD MOVE  A/B HEIGHT", 0, 128)
        end
      end)
      g.pop()
      if not success then
        local text = tostring(message)
        if self.problem ~= text then log("error", "Soaring draw failed: %s", text) end
        self.problem = text
      end
    end
    return screen
  end

  -- core.update is intentionally bypassed while Soaring owns the stack so
  -- NPCs, encounters, scripts, play time and autosave remain frozen. Music's
  -- chip synthesizer normally advances from that same function, however, and
  -- needs its own real-time 60 Hz clock here or a selected song never fills
  -- its first audio buffer until flight ends.
  local function updateSoaringMusic(screen, dt)
    screen.musicAccum=math.min((screen.musicAccum or 0)+math.max(0,dt or 0),.25)
    while screen.musicAccum>=MUSIC_STEP do
      screen.musicAccum=screen.musicAccum-MUSIC_STEP
      Music.update(screen.game.data)
    end
  end

  local function isFlySurface(game,origin)
    local def=origin and game.data and game.data.maps and game.data.maps[origin.mapId]
    return not not (def and Map.isOutside(def,FieldDefaults.field(game.data,"outsideTilesets")))
  end

  local function launchInfo(game)
    local count=game.save and game.save.inventory and game.save.inventory.DRAGON_CALL or 0
    if not (type(count)=='number' and count>0) and not hiddenRegistry.config.debugEnabled then return nil end
    local origin=mod.world:current()
    if not isFlySurface(game,origin) or not originResolver:has(origin.mapId) then return nil end
    -- Prepared, currently-permissive progression gate (item 6): see
    -- progression.lua. Checked here so a future badge/visited-city
    -- requirement needs no other call site touched.
    if not Progression.canSoar(game,origin) then return nil end
    local spawn=originResolver:resolve(origin,game.data.maps[origin.mapId])
    if not spawn then return nil end
    return {game=game,origin=origin,spawn=spawn,elapsed=0}
  end

  local function pushLoadingCover(game,launch)
    local ok,animation=pcall(LoadingAnimation.new,mod,LoadingWings,DayNight,currentTransitionNightAmount())
    if not ok then log('warn','Dragonite loading animation unavailable: %s',tostring(animation));animation=nil end
    local cover={game=game,isOpaque=true,drew=false,animation=animation,builder=nil,scene=nil,sceneReady=false}
    function cover:enter()
      local song=Music.special(game.data,'surf') or 'Music_Surfing'
      Music.play(game.data,song,true,{reason='soaring_loading'})
    end
    function cover:update(dt)
      if not self.drew then return end
      if self.animation then self.animation:update(dt) end
      updateSoaringMusic(self,dt)
      if not self.builder then
        self.builder=LoadingBuilder.new(function(checkpoint)
          return newScreen(game,true,launch,checkpoint)
        end)
      end
      if not self.sceneReady then
        self.builder:step(dt)
        if self.builder.ready then
          if self.builder.error then
            log('error','Soaring loading build failed: %s',self.builder.error)
            self.scene=newScreen(game,true,launch)
          else self.scene=self.builder.result end
          self.sceneReady=true
          log('info','Soaring loading ready: wall=%.3fs work=%.3fs updates=%d checkpoints=%d',
            self.builder.wallSeconds,self.builder.workSeconds,self.builder.updates,self.builder.resumes)
        end
      end
      -- The animation covers real work only; readiness never waits for the clip.
      if self.sceneReady then
        if game.stack:top()==self then game.stack:pop() end
        game.stack:push(self.scene)
      end
    end
    function cover:draw() self.drew=true end
    function cover:exit()
      if self.animation then self.animation:release();self.animation=nil end
      self.builder=nil
      if launchCover==self then launchCover=nil end
    end
    launchCover=cover;game.stack:push(cover)
  end

  -- The native overworld must not remain a completed custom map under flight.
  -- New visits store its pre-landing checkpoint. Old 0.10.14 visits use a
  -- native Fly destination as a compatibility checkpoint (not flight position).
  local function normalCheckpoint(game,instance)
    local p=instance and instance.returnOverworld
    if p and game.data.maps[p.mapId] and not hiddenRegistry.byMap[p.mapId] then return p end
    local field=game.data.field or {}
    for _,id in ipairs(field.flyOrder or {}) do
      local spot=field.flyWarps and field.flyWarps[id]
      if spot and ((game.save.visited or {})[id] or id=='PALLET_TOWN') then
        return {mapId=id,x=spot.x,y=spot.y,facing='down'}
      end
    end
  end
  local function completeHiddenDeparture(game,area)
    -- Native Fly remembers its departure outdoor map for dynamic door warps.
    -- A completed custom map must never remain that native return target.
    local ow=mod.world:overworld()
    if ow and ow.lastOutdoor and hiddenRegistry.byMap[ow.lastOutdoor.id] then
      ow:rememberOutdoor(ow.map.id,ow.player.cellX,ow.player.cellY)
    end
    return HiddenAreas.completeActive(mod,hiddenRegistry,area,game)
  end
  local function startDragonDeparture(game,launch,onDone)
    if active or pendingLaunch or launchCover then return false end
    local ow=mod.world:overworld()
    if not ow or not ow.player or ow.player.moving or ow.player.inputLocked then return false end
    launch.ride=captureRideState(game,ow)
    local ok,sequence=pcall(DragonTakeoff.new,game,mod,ow,function()
      pendingLaunch=nil
      onDone()
    end,function()
      pendingLaunch=nil;hiddenExitInProgress=nil
      restoreRideState(game,ow,launch.ride)
      Music.playMap(game.data,ow.map.id,game.save.onBike,ow.player.surfing,nil)
    end,false,currentTransitionNightAmount())
    if not ok then log('error','Dragonite animation unavailable: %s',tostring(sequence));return false end
    -- Remove menu layers only after sequence construction succeeds.
    while game.stack:top() and game.stack:top()~=ow do game.stack:pop() end
    game.save.onBike=false;game.save.forcedBike=nil;ow.player.surfing=false
    if ow.syncSurfingPikachu then ow:syncSurfingPikachu() end
    pendingLaunch=launch;game.stack:push(sequence)
    return true
  end
  local function leaveHiddenAreaToSoaring(game)
    local current=mod.world:current()
    local area=current and hiddenRegistry.byMap[current.mapId]
    if not area or active or launchCover or hiddenExitInProgress then return false end
    local instance=HiddenAreas.active(mod,hiddenRegistry)
    local checkpoint=normalCheckpoint(game,instance)
    if not checkpoint then log('error','No native return checkpoint');return false end
    local spawn=HiddenAreas.returnSpawn(mod,hiddenRegistry,area)
      or HiddenAreas.fallbackSpawn(hiddenRegistry,area)
    local launch={game=game,origin=current,spawn=spawn}
    local started=startDragonDeparture(game,launch,function()
      -- Rebase the native map only after frame 9 and the black cover.
      -- Lifecycle commits only after a successful native transition.
      HiddenAreas.syncReward(mod,game,area)
      local ok,reason=mod.world:warpTo(checkpoint.mapId,checkpoint.x,checkpoint.y,
        checkpoint.facing,{onDone=function()
          completeHiddenDeparture(game,area)
          hiddenExitInProgress=nil
          pushLoadingCover(game,{game=game,origin=mod.world:current(),spawn=spawn})
        end})
      if not ok then
        hiddenExitInProgress=nil;restoreRideState(game,mod.world:overworld(),launch.ride)
        Music.playMap(game.data,area.mapId,game.save.onBike,false,nil)
        log('error','Hidden exit failed: %s',tostring(reason))
      end
    end)
    if started then hiddenExitInProgress=true end
    return started
  end
  local function beginTakeoff(game)
    local launch=launchInfo(game);if not launch then return false end
    return startDragonDeparture(game,launch,function() pushLoadingCover(game,launch) end)
  end

  local function maybeStartLanceMeeting(game)
    local flags=game.save and game.save.flags or {}
    local inventory=game.save and game.save.inventory or {}
    local replay=hiddenRegistry.config.debugEnabled and lanceReplayRequested
    if (not replay and (not flags.EVENT_BEAT_CHAMPION_RIVAL
        or mod.save:get('story.lanceDragonCallReceived',false)==true
        or ((type(inventory.DRAGON_CALL)=='number' and inventory.DRAGON_CALL>0))))
        or lanceEventRunning then return end
    local ow=game.overworld
    if not ow or not ow.map or ow.map.id~='PALLET_TOWN' or game.stack:top()~=ow
        or not ow.player or ow.player.moving or ow.player.inputLocked
        or (ow.runner and ow.runner.isRunning and ow.runner:isRunning())
        or #(ow.scriptMoves or {})>0 then return end
    local p=ow.player;local x,y=p.cellX,p.cellY
    local directions={down={0,1,'up'},up={0,-1,'down'},right={1,0,'left'},left={-1,0,'right'}}
    local approach,run,seen=nil,0,{}
    for _,side in ipairs({p.facing or 'down','down','right','left','up'}) do
      if not seen[side] then
        seen[side]=true;local v=directions[side];local clear=0
        for step=1,4 do
          local cx,cy=x+v[1]*step,y+v[2]*step
          if not ow.map:isWalkableCell(cx,cy) or ow:npcAtCell(cx,cy) then break end
          clear=step
        end
        if clear>0 then approach,run=side,clear;break end
      end
    end
    if not approach then return end
    local v=directions[approach];local spawnX,spawnY,dir=x+v[1]*run,y+v[2]*run,v[3]
    local npcId=ow:addRuntimeObject('PALLET_TOWN',{
      sprite='SPRITE_LANCE',movement='STAY',range=dir:upper(),
      text='_SWR_LANCE_POSTGAME',x=spawnX,y=spawnY},mod.manifest.id)
    local npc=ow:npcAtCell(spawnX,spawnY)
    if not npcId or not npc then return end
    lanceReplayRequested=false;lanceEventRunning=true;p.inputLocked=true
    -- Stop one tile short of Red, then face each other for the conversation.
    ow:scriptMove(npc,dir,run-1,function()
      p.facing=approach
      npc:facePlayer(p)
      local TextBox=require('src.render.TextBox');local Bag=require('src.inventory.Bag')
      local name=(game.save.player and game.save.player.name) or 'RED'
      local function leaveScene()
        local candidates={approach,'up','down','left','right'}
        local seen,bestDirection,bestSteps={},nil,0
        for _,direction in ipairs(candidates) do
          if not seen[direction] then
            seen[direction]=true
            local v=directions[direction];local clear=0
            for step=1,8 do
              local cx=npc.cellX+v[1]*step;local cy=npc.cellY+v[2]*step
              if not ow.map:isWalkableCell(cx,cy) or (cx==p.cellX and cy==p.cellY) then break end
              local other=ow:npcAtCell(cx,cy)
              if other and other~=npc then break end
              clear=step
            end
            if clear>bestSteps then bestDirection,bestSteps=direction,clear end
          end
        end
        local function finish()
          ow:removeRuntimeObject(npcId,mod.manifest.id)
          p.inputLocked=false;lanceEventRunning=false
        end
        if bestSteps==0 then finish();return end
        -- Retrace the approach when possible, walking far enough to leave view.
        ow:scriptMove(npc,bestDirection,bestSteps,finish)
      end
      -- Explicit two-line pages keep the approved dialogue within the native text box.
      local function showLastPages()
        game.stack:push(TextBox.new(game,table.concat({
          "Use it outdoors,\nand a DRAGONITE",
          "will come to carry\nyou into the sky.",
          "You can return to\nplaces you know...",
          "Or see what else\nis out there!",
          "Even in KANTO,\nthere are places",
          "you won't find by\nfollowing the",
          "roads.",
          "A forest\nclearing... An",
          "island beyond the\nshore...",
          "From a DRAGONITE's\nback, you might",
          "spot a place\nyou've never seen",
          "before.",
          "If you land\nsomewhere without",
          "a way back, use\nthe DRAGON CALL",
          "again. DRAGONITE\nwill take you out.",
          "You've conquered\nthe LEAGUE,",
          ""..name..".",
          "Now, let's see how\nfar you and your",
          "POKéMON can go!"},'\f'),leaveScene))
      end
      local firstPages=table.concat({
        "LANCE: Ah,\n"..name.."!",
        "Our new CHAMPION!",
        "I still find it\nhard to believe",
        "you defeated my\ndragons!",
        "But there's more\nto a DRAGONITE",
        "than its strength\nin battle.",
        "I have something\nfor you. I think",
        "you've earned it.",
        "Take this. It's a\nDRAGON CALL."},'\f')
      game.stack:push(TextBox.new(game,firstPages,function()
        local hasCall=type(game.save.inventory.DRAGON_CALL)=='number' and game.save.inventory.DRAGON_CALL>0
        if not hasCall and not Bag.add(game.save,'DRAGON_CALL',1,game.data) then
          game.stack:push(TextBox.new(game,'There is no room\nfor the DRAGON CALL.',leaveScene))
          return
        end
        mod.save:set('story.lanceDragonCallReceived',true)
        if not hasCall then require('src.core.Sound').play(game.data,'Get_Key_Item') end
        -- Award the key item after the introduction, then continue the dialogue.
        showLastPages()
      end))
    end)
  end
  mod.content.sfx:register('SWR_DRAGON_WHISTLE',{file=mod.assets:path('assets/dragon_whistle.wav')})
  mod.content.item_effects:register('SWR_DRAGON_CALL',{field=true,battle=false,use=function()
    return 'kept',{}
  end})
  mod.content.items:register('DRAGON_CALL',{id='DRAGON_CALL',name='DRAGON CALL',price=0,keyItem=true,
    tossable=false,needsTarget=false,effect='SWR_DRAGON_CALL'})
  mod.hooks:wrap('item.use',function(next,game,battle,id,target,list,moveIndex,picker)
    if id~='DRAGON_CALL' or battle then return next(game,battle,id,target,list,moveIndex,picker) end
    local current=mod.world:current()
    local hidden=current and hiddenRegistry.byMap[current.mapId]
    if active or pendingLaunch or launchCover or not (hidden or launchInfo(game)) then
      game.stack:push(require('src.render.TextBox').new(game,"Can't call here!"))
      return
    end
    return hidden and leaveHiddenAreaToSoaring(game) or beginTakeoff(game)
  end)
  mod.events:on('world.stepped',function(ev)
    local area=ev and hiddenRegistry.byMap[ev.mapId]
    if area or active or launchCover or pendingLaunch or hiddenExitInProgress then return end
    local ow=mod.world:overworld()
    local runner=ow and ow.runner
    local scripted=(runner and runner.isRunning and runner:isRunning())
      or (ow and #(ow.scriptMoves or {})>0)
      or (ow and (ow.engaging or ow.emote or ow.teleportOut))
      or (ow and ow.player and ow.player.inputLocked)
    local game=ow and ow.player and require('src.core.Game')
    HiddenAreas.onStep(mod,hiddenRegistry,ow and ow.map and ow.map.id==ev.mapId
      and game and game.stack:top()==ow
      and not scripted)
  end)
  mod.events:on('map.entered',function(ev)
    local area=ev and hiddenRegistry.byMap[ev.mapId]
    local departed=ev and hiddenRegistry.byMap[ev.fromMapId]
    if not area and departed and (ev.via=='fly'
        or (departed.staticEncounter and not hiddenExitInProgress)) then
      -- Native Party FLY and compatible mod APIs use this successful arrival.
      completeHiddenDeparture(require('src.core.Game'),hiddenRegistry.byMap[ev.fromMapId])
    end
    if area then
      HiddenAreas.adoptLegacy(mod,hiddenRegistry,area)
      local game=require('src.core.Game')
      HiddenAreas.onEntered(mod,hiddenRegistry,area,game)
      -- Start the authored theme immediately on entry; the registered
      -- map song also covers native arrival tails and battle restoration.
      if area.music then
        local ow=mod.world:overworld()
        Music.playMap(game.data,area.mapId,game.save.onBike,
          ow and ow.player and ow.player.surfing or false,nil,area.music)
      end
    end
  end)
  mod.events:on('world.interacted',function(ev)
    local area=ev and hiddenRegistry.byMap[ev.mapId]
    if area and ev.kind=='npc' then
      -- Engine item balls set save.itemsTaken in the native talk path and
      -- then emit world.interacted. Mirror that bit immediately so the
      -- active repeatable instance is current before a save or debug query.
      HiddenAreas.syncReward(mod,require('src.core.Game'),area)
    end
  end)
  local mewBattle
  mod.events:on('battle.started',function(ev)
    local current=mod.world:current()
    if current and current.mapId=='SWR_FORGOTTEN_PIER_01' and ev.species=='MEW' then
      mewBattle=ev.battle
      -- Consume only after the native battle really started, never on menu open.
      HiddenAreas.consumeMew(mod,hiddenRegistry,require('src.core.Game'))
    end
  end)
  mod.events:on('pokemon.caught',function(ev)
    if ev.battle==mewBattle and ev.species=='MEW' then mod.save:set('hidden.mew.captured',true) end
  end)
  mod.events:on('battle.ended',function(ev)
    if ev.battle==mewBattle then
      HiddenAreas.consumeMew(mod,hiddenRegistry,require('src.core.Game'));mewBattle=nil
    end
  end)
  mod.hooks:wrap('world.talk',function(next,ow,npc)
    local mapId=ow and ow.map and ow.map.id
    local area=mapId and hiddenRegistry.byMap[mapId]
    if area and area.staticEncounter and npc and npc.def and npc.def.pokemon=='MEW'
        and HiddenAreas.mewStatus(mod,hiddenRegistry).consumed then
      HiddenAreas.syncMew(mod,hiddenRegistry,require('src.core.Game'));return
    end
    if area then HiddenAreas.applyInstanceReward(mod,hiddenRegistry,area,npc) end
    return next(ow,npc)
  end)
  mod.hooks:wrap('encounter.roll',function(next,encounterDef,ctx)
    if ctx and hiddenRegistry.byMap[ctx.mapId] then
      -- Numeric mod-map indexes fall in the engine's indoor range. Secret
      -- Shore uses OVERWORLD tiles, so suppress that generic floor roll;
      -- only authored grass cells should use its saved profile.
      if ctx.terrain=='indoor' and hiddenRegistry.byMap[ctx.mapId].template~='summit' then return nil end
      local rolled=next(HiddenAreas.profileEncounter(mod,hiddenRegistry,ctx.mapId),ctx)
      return rolled and HiddenAreas.weightedEncounter(mod,hiddenRegistry,ctx.mapId,ctx.rng,require('src.core.Game').save) or nil
    end
    return next(encounterDef,ctx)
  end)
  if hiddenRegistry.config.debugEnabled then
    -- Direct scene entry bypasses Dragon Call and its departure/loading lifecycle.
    -- Keep these DevKit entry points out of the release screen registry.
    mod.content.screens:register(screenId, {new=function(game) return newScreen(game,false) end})
    mod.content.screens:register("SoaringStylizedRed", {new=function(game) return newScreen(game,true) end})
    mod.content.screens:register('SWRHiddenDebug',
      {new=function(game) return HiddenDebug.new(game,mod,hiddenRegistry,HiddenAreas) end})
  end

  mod.hooks:wrap('ui.party.submenu',function(next,game,items,mon,ctx)
    local out=next(game,items,mon,ctx)
    if ctx and ctx.battle then return out end
    local current=mod.world:current()
    local hidden=current and hiddenRegistry.byMap[current.mapId]
    if not active and not hidden then return out end
    local filtered={}
    for _,row in ipairs(out or {}) do
      -- A suspended overworld cannot run field animations during flight.
      -- Hidden-map exits remain the explicitly supported menu path and native Fly.
      local field=row.action=='fly' or row.action=='escape' or row.action=='surf'
        or row.action=='cut' or row.action=='strength' or row.action=='flash'
      if not ((active and field) or (hidden and row.action=='escape')) then
        filtered[#filtered+1]=row
      end
    end
    return filtered
  end)
  mod.hooks:wrap("ui.start_menu.items", function(next, game, items)
    local out = next(game, items)
    local base = game.stack and game.stack.states and game.stack.states[1]
    if type(out) ~= "table" or not (base and base.isOverworld) or game.linkSession or game.linkNet then return out end
    local current=mod.world:current()
    local hidden=current and hiddenRegistry.byMap[current.mapId]
    if hidden and not active then
      out=mod.ui.insertBefore(out,'SAVE',{label='SOARING WORLD',onSelect=function()
        leaveHiddenAreaToSoaring(game)
      end})
    elseif not active and hiddenRegistry.config.debugEnabled and launchInfo(game) then
      out = mod.ui.insertBefore(out, "SAVE", {label="SOAR WORLD", onSelect=function()
        beginTakeoff(game)
      end})
    end
    if hiddenRegistry.config.debugEnabled then
      out=mod.ui.insertBefore(out,'SAVE',{label='HIDDEN DEBUG',onSelect=function()
        require('src.ui.Screens').push(game,'SWRHiddenDebug')
      end})
    end
    -- The legacy scene is registered only in debug builds, without a Start row.
    return out
  end)

  -- Pause the entire simulation clock, not only NPC update: no RNG, playTime,
  -- map scripts, encounters, autosave or sync updates from Game:update.
  -- Read the engine's mapped buttons at real frame rate; fast-forward has no effect.
  mod.hooks:wrap("core.update", function(next, game, dt)
    local cinematic=game.stack:top()
    if cinematic and cinematic.dragonLanding then
      game.input:step();cinematic:update(dt)
      return -- no walking, encounters or scripted movement before dismount
    end
    if active and active.game == game and not active.transitionCover then
      game.input:step()
      updateSoaringMusic(active,dt)
      local top=game.stack:top()
      local ok, err = pcall(function() if top and top.update then top:update(dt) end end)
      if not ok then
        log("error", "Soaring update failed: %s", tostring(err))
        active.problem = tostring(err); close(active)
      end
      return
    end
    if pendingLaunch and pendingLaunch.game==game then
      game.input:step()
      local top=game.stack:top()
      if top and top.update then top:update(dt) end
      return -- no overworld steps/scripts/fast-forward during departure
    end
    if launchCover and launchCover.game==game then
      game.input:step()
      launchCover:update(dt)
      return -- keep the map simulation paused while the visible load animation runs
    end
    if drain then
      game.input:step()
      if not anyDown(game.input) then drain = false end
      return -- released exit/movement buttons never reach the overworld
    end
    local result=next(game, dt)
    maybeStartLanceMeeting(game)
    local current=mod.world:current()
    local hidden=current and hiddenRegistry.byMap[current.mapId]
    if hidden then
      HiddenAreas.adoptLegacy(mod,hiddenRegistry,hidden)
      HiddenAreas.syncReward(mod,game,hidden)
    end
    return result
  end, 100)

  mod.exports.leaveHiddenAreaToSoaring=leaveHiddenAreaToSoaring
  mod.exports.status = function()
    return { active = active ~= nil, problem = active and active.problem or nil,
      launching=pendingLaunch~=nil or launchCover~=nil,
      locationState=active and active.locations and active.locations.state or nil,
      location=active and active.locations and active.locations.insideId or nil,
      origin=active and active.origin or nil }
  end
  mod.exports.hiddenAreaStatus=function(id)
    local area=hiddenRegistry.byId[id]
    if not area then return nil end
    local spawn=HiddenAreas.active(mod,hiddenRegistry)
    local own=spawn and spawn.areaId==id and spawn or nil
    return {active=own~=nil,anchorId=own and own.anchorId or nil,
      profileId=own and own.profileId or nil,
      rewardProfileId=own and own.rewardProfileId or nil,
      rewardItem=own and own.rewardItem or nil,
      discovered=HiddenAreas.isDiscovered(mod,area),
      visited=own and own.visited or false,
      rewardClaimed=HiddenAreas.rewardClaimed(mod,area),
      completed=HiddenAreas.hasCompleted(mod,area)}
  end
  mod.exports.hiddenSpawnStatus=function()
    local status=HiddenAreas.status(mod,hiddenRegistry)
    status.discoveredCount=HiddenAreas.discoveryCount(mod,hiddenRegistry)
    status.mew=HiddenAreas.mewStatus(mod,hiddenRegistry)
    return status
  end
  if hiddenRegistry.config.debugEnabled then
    -- QA harness and DevKit tools can drive the same actions as the debug menu.
    mod.exports.hiddenDebugAction=function(action,opts)
      if action=='replayLance' then
        local game=opts and opts.game;local ow=game and game.overworld
        if not ow or not ow.map or ow.map.id~='PALLET_TOWN' then return nil,'PALLET TOWN ONLY' end
        if active or pendingLaunch or lanceEventRunning then return nil,'SCENE BUSY' end
        lanceReplayRequested=true
        return true
      elseif action=='giveDragonCall' then
        local game=opts and opts.game
        if not game then return nil,'game required' end
        if game.save.inventory.DRAGON_CALL then return true end
        return require('src.inventory.Bag').add(game.save,'DRAGON_CALL',1,game.data)
      elseif action=='force' then
        opts=opts or {};opts.debugBypass=true
        return HiddenAreas.forceSpawn(mod,hiddenRegistry,opts)
      elseif action=='forceMew' then return HiddenAreas.forceSpawn(mod,hiddenRegistry,
        {areaId='FORGOTTEN_PIER_01',debugBypass=true,replace=true})
      elseif action=='resetMew' then return HiddenAreas.resetMew(mod,hiddenRegistry,opts and opts.game)
      elseif action=='discovery' then return HiddenAreas.debugDiscovery(mod,hiddenRegistry,opts)
      elseif action=='step' then return HiddenAreas.debugSteps(mod,hiddenRegistry,opts)
      elseif action=='complete' then return HiddenAreas.completeActive(mod,hiddenRegistry,nil,opts and opts.game)
      elseif action=='resetActive' then return HiddenAreas.resetActive(mod,hiddenRegistry)
      elseif action=='resetAll' then return HiddenAreas.resetAll(mod,hiddenRegistry,opts and opts.game)
      elseif action=='testAll' then return HiddenAreas.startTestAll(mod,hiddenRegistry)
      elseif action=='nextTestCase' then return HiddenAreas.nextTestCase(mod,hiddenRegistry) end
      return nil,'unknown debug action'
    end
  end
  mod.hooks:wrap("render.hud", function(next,game,viewport)
    next(game,viewport)
    if hiddenExitInProgress and not pendingLaunch then
      love.graphics.push('all');love.graphics.origin();love.graphics.setColor(0,0,0,1)
      love.graphics.rectangle('fill',0,0,love.graphics.getDimensions());love.graphics.pop()
      return
    end
    if launchCover and launchCover.game==game and game.stack:top()==launchCover then
      love.graphics.push('all');love.graphics.origin()
      if launchCover.animation then launchCover.animation:draw()
      else
        love.graphics.setColor(0,0,0,1)
        love.graphics.rectangle('fill',0,0,love.graphics.getDimensions())
      end
      love.graphics.pop()
      return
    end
    if active and active.game==game and not active.problem then
      local top=game.stack:top()
      if top==active.mapScreen then
        -- The Soaring renderer extends past the classic 160x144 UI canvas.
        -- Present the native Town Map as a real full-screen overlay so flight
        -- scenery and contextual flight prompts do not remain visible around it.
        love.graphics.push('all');love.graphics.origin()
        local w,h=love.graphics.getDimensions()
        love.graphics.setColor(0,0,0,1);love.graphics.rectangle('fill',0,0,w,h)
        local scale=math.min(w/160,h/144)
        love.graphics.translate(math.floor((w-160*scale)/2),math.floor((h-144*scale)/2))
        love.graphics.scale(scale,scale);top:drawWindow()
        love.graphics.pop()
        return
      elseif top==active and active.renderer and active.renderer.drawWindow then
        active.renderer:drawWindow(active.flight,viewport,active.riderMotion,active.dayNight)
        if active.soaringUI then active.soaringUI:draw(active,viewport) end
      end
      local alpha=active.transitionCover and 1 or (top==active and active.landingFade and active.landingFade.alpha or 0)
      if alpha and alpha>0 then
        love.graphics.push('all');love.graphics.origin();love.graphics.setColor(0,0,0,alpha)
        love.graphics.rectangle('fill',0,0,love.graphics.getDimensions())
        love.graphics.pop()
      end
    end
  end)
end
