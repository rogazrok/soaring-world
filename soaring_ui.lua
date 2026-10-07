local M={}
local UI={};UI.__index=UI
local Theme=require('src.ui.Theme')
local function box(font,x,y,w,h)
  if font.drawBox then font.drawBox(x,y,w,h) else love.graphics.rectangle('line',x*8,y*8,w*8,h*8) end
end
local function text(font,s,x,y) font.draw(tostring(s),x,y) end
local function centered(font,s,row,width)
  s=tostring(s);width=width or 160;text(font,s,math.floor((width-#s*8)/2),row*8)
end
function M.new(font)
  return setmetatable({font=font,canvas=love.graphics.newCanvas(160,144,{dpiscale=1}),
    actionCanvas=love.graphics.newCanvas(160,144,{dpiscale=1})},UI)
end
function UI:release()
  for _,key in ipairs({'canvas','actionCanvas'}) do
    if self[key] then self[key]:release();self[key]=nil end
  end
end
local function debugPoint(world,x,y,z)
  local ac=world.art.camera
  local function project(px,py,pz) return px-ac.shear*py,ac.slope*px+ac.depth*py-pz end
  local cx,cy=project(world.maxX/2,world.maxY/2,0)
  local scale=math.min(148/(world.maxX+ac.shear*world.maxY),115/(world.maxY*ac.depth+world.maxX*ac.slope+world.config.max_height))
  local px,py=project(x,y,z or 0)
  return 80+(px-cx)*scale,78+(py-cy)*scale,scale
end
local function present(g,canvas,width,height,x,y)
  local scale=math.min(height/200,width/300)
  g.draw(canvas,x or math.floor((width-160*scale)/2+.5),y or 8*scale,0,scale,scale)
end
function UI:draw(screen)
  local g=love.graphics;local c=screen.locations
  g.push('all');g.setCanvas(self.canvas);g.origin();g.clear(0,0,0,0)
  local debug=screen.flight.cameraMode=='DEBUG_TOP' and c
  local banner=not debug and c and c.state=='BANNER' and c.zone
  if debug then
    for _,loc in ipairs(c.locations) do if loc.enabled then
      local x,y,s=debugPoint(screen.world,loc.center.x,loc.center.y,0)
      g.setColor(.82,.87,.56,.72);g.ellipse('line',x,y,loc.banner_radius*s,loc.banner_radius*s*.78)
      g.setColor(.82,.22,.18,.88);g.ellipse('line',x,y,loc.landing_radius*s,loc.landing_radius*s*.78)
    end end
    if c.nearestBanner then
      g.setColor(1,1,1,.9);g.rectangle('fill',0,8,160,8);g.setColor(0,0,0,1)
      text(self.font,'ZONE '..c.nearestBanner.name,0,8)
    end
  elseif banner then
    g.setColor(1,1,1,1);g.rectangle('fill',0,0,144,24)
    box(self.font,0,0,18,3);g.setColor(0,0,0,1);centered(self.font,banner.name,1,144)
  end
  g.pop()
  g.push('all');g.setCanvas(self.actionCanvas);g.origin();g.clear(0,0,0,0)
  local prompt
  if not debug and c and c.state=='LANDING' and c.landing and not c.landingUnavailable then
    prompt={w=96,h=24};g.setColor(1,1,1,1);g.rectangle('fill',0,0,prompt.w,prompt.h)
    box(self.font,0,0,12,3);g.setColor(0,0,0,1);centered(self.font,'A: LAND',1,prompt.w)
  elseif not debug and c and c.landingUnavailable then
    prompt={w=144,h=24};g.setColor(1,1,1,1);g.rectangle('fill',0,0,prompt.w,prompt.h)
    box(self.font,0,0,18,3);g.setColor(0,0,0,1)
    centered(self.font,c.landingReason=='unvisited' and 'VISIT CITY FIRST' or 'LAND UNAVAILABLE',1,prompt.w)
  elseif not debug and c and c.state=='CONFIRM' and c.landing then
    prompt={w=152,h=64};g.setColor(1,1,1,1);g.rectangle('fill',0,0,prompt.w,prompt.h)
    box(self.font,0,0,19,8);g.setColor(0,0,0,1)
    centered(self.font,c.landing.kind=='hidden' and 'LAND AT' or 'LAND IN',1,prompt.w)
    centered(self.font,c.landing.name..'?',2,prompt.w);text(self.font,'YES',32,40);text(self.font,'NO',32,48)
    if self.font.drawCode then self.font.drawCode(Theme.cursor,24,c.confirmIndex==1 and 40 or 48)
    else local cy=c.confirmIndex==1 and 40 or 48;g.polygon('fill',24,cy,24,cy+8,30,cy+4) end
  end
  if not debug and c and c.error then
    prompt={w=144,h=32};g.clear(0,0,0,0);g.setColor(1,1,1,1);g.rectangle('fill',0,0,prompt.w,prompt.h)
    box(self.font,0,0,18,4);g.setColor(0,0,0,1);centered(self.font,'LANDING FAILED',1,prompt.w)
  elseif not debug and c and c.notice then
    prompt={w=144,h=32};g.clear(0,0,0,0);g.setColor(1,1,1,1);g.rectangle('fill',0,0,prompt.w,prompt.h)
    box(self.font,0,0,18,4);g.setColor(0,0,0,1);centered(self.font,c.notice,1,prompt.w)
  end
  g.pop();g.push('all');g.origin();g.setColor(1,1,1,1)
  local width,height=g.getDimensions();local scale=math.min(height/200,width/300)
  if debug then present(g,self.canvas,width,height)
  elseif banner then present(g,self.canvas,width,height,nil,8*scale) end
  if prompt then
    local margin=math.max(8,math.floor(10*scale+.5));local bottom=math.max(margin,math.floor(13*scale+.5))
    g.draw(self.actionCanvas,math.floor(width-prompt.w*scale-margin+.5),
      math.floor(height-prompt.h*scale-bottom+.5),0,scale,scale)
  end
  g.pop()
end
return M
