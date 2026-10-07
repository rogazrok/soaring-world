-- Read-only Soaring overlay using Pokémon Red's imported Town Map renderer.
local TownMap=require('src.ui.TownMap')
local Sound=require('src.core.Sound')
local PaletteFX=require('src.render.PaletteFX')
local Font=require('src.render.Font')

local M={}
local function nativePoint(loc)
  return loc.x*8+16,loc.y*8+8
end

function M.new(game,parent,locations,markerImage)
  local town=TownMap.new(game,{})
  town.playerLoc=nil -- origin town is not Dragonite's position
  if markerImage then markerImage:setFilter('nearest','nearest') end
  local screen={game=game,parent=parent,town=town,locations=locations,markerImage=markerImage,isOpaque=true}
  function screen:sgbPalettes() return self.town:sgbPalettes(self.game) end
  function screen:onKeyPressed(key) self.game.input:keypressed(key) end
  function screen:onGamepadPressed(button) self.game.input:gamepadpressed(nil,button) end
  function screen:update(dt)
    local input=self.game.input
    if input:wasPressed('b') or input:wasPressed('start') then
      Sound.play(self.game.data,'Press_AB')
      if self.game.stack:top()==self then self.game.stack:pop() end
      return
    end
    self.town:update(dt)
  end
  function screen:draw(colorize)
    local g=love.graphics
    g.push('all')
    -- The full-window HUD pass bypasses the engine's UI palette compositor.
    -- Reuse its native Town Map palette for that pass, then draw true-color
    -- city/player markers and the black/white frame without shade remapping.
    local palette=colorize and PaletteFX.pal(self.game.data,'TOWNMAP')
    local shader=palette and PaletteFX.shader()
    if shader then PaletteFX.sendColors(shader,palette);g.setShader(shader) end
    self.town:draw()
    g.pop()
    if self.town.mode~='grid' or not self.town.bg then return end
    -- Mark cities; gold marks native destinations already visited and landable.
    for _,loc in ipairs(self.locations.locations or {}) do
      if loc.kind~='hidden' and loc.enabled then
        local town=self.town.byMap[loc.id]
        if town and town.x and town.y then
          local x,y=nativePoint(town)
          local visited=(game.save.visited or {})[loc.id]==true or loc.id=='PALLET_TOWN'
          g.push('all')
          if visited then g.setColor(.82,.57,.12,1) else g.setColor(.18,.20,.24,1) end
          g.rectangle('fill',x-2,y-2,5,5)
          g.setColor(1,1,1,1);g.rectangle('fill',x-1,y-1,3,3)
          g.pop()
        end
      end
    end
    -- Interpolate the player marker from the city anchors without exposing
    -- a Hidden Area as a separate map destination.
    local loX,hiX,loY,hiY=math.huge,-math.huge,math.huge,-math.huge
    local loMX,hiMX,loMY,hiMY=math.huge,-math.huge,math.huge,-math.huge
    for _,loc in ipairs(self.locations.locations or {}) do
      local t=loc.kind~='hidden' and self.town.byMap[loc.id]
      if t and t.x and t.y then
        loX=math.min(loX,loc.center.x);hiX=math.max(hiX,loc.center.x)
        loY=math.min(loY,loc.center.y);hiY=math.max(hiY,loc.center.y)
        loMX=math.min(loMX,t.x);hiMX=math.max(hiMX,t.x)
        loMY=math.min(loMY,t.y);hiMY=math.max(hiMY,t.y)
      end
    end
    if loX<hiX and loY<hiY then
      local fx=(parent.flight.x-loX)/(hiX-loX);local fy=(parent.flight.y-loY)/(hiY-loY)
      local mapX=loMX+fx*(hiMX-loMX);local mapY=loMY+fy*(hiMY-loMY)
      local x,y=nativePoint({x=mapX,y=mapY})
      if self.markerImage then
        g.setColor(1,1,1,1)
        g.draw(self.markerImage,math.floor(x-8+.5),math.floor(y-8+.5))
      else
        g.setColor(1,0,0,1);g.rectangle('fill',x-2,y-2,5,5)
      end
    end
    g.push('all');g.setColor(1,1,1,1)
    g.rectangle('fill',0,0,160,16);g.rectangle('fill',0,128,160,16)
    g.setColor(0,0,0,1);g.rectangle('line',1.5,1.5,157,13);g.rectangle('line',1.5,129.5,157,13)
    Font.draw('SOARING MAP',36,4);Font.draw('B/START: BACK',24,132)
    g.pop()
  end
  function screen:drawWindow() self:draw(true) end
  return screen
end
return M
