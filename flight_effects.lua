local M={};local FX={};FX.__index=FX
local function clamp(v,a,b)return math.max(a,math.min(b,v))end
local function smooth(a,b,v)
  if b<=a then return v>=b and 1 or 0 end
  local t=clamp((v-a)/(b-a),0,1);return t*t*(3-2*t)
end
local function number(v,d)return type(v)=='number' and v==v and v or d end
local function hash(i,s)return ((i*73+s*151)%997)/997 end
local hazeFormat={{'VertexPosition','float',2},{'VertexTexCoord','float',2},{'VertexColor','float',4}}
local defaults={
 enabled=true,altitude={low=150,middle=380,high=760},
 haze={start=430,full=900,max_alpha=.075,color={.76,.84,.82}},
 clouds={
  far={count=5,min_altitude=180,alpha=.18,scale_min=1.3,scale_max=2,drift=1.1,parallax=.018,color={.91,.94,.88}},
  middle={count=4,min_altitude=270,alpha=.13,scale_min=.8,scale_max=1.35,drift=2,parallax=.045,color={.94,.96,.91}},
  near={count=2,min_altitude=500,alpha=.10,scale_min=1,scale_max=1.5,drift=3.6,parallax=.095,color={.97,.98,.94}},
 },wind={base_count=4,fast_count=8,min_alpha=.10,max_alpha=.27,short_length=5,long_length=14,travel_speed=1.15,color={.88,.94,.91}}
}
local function merge(dst,src)
 for k,v in pairs(src or {})do
  if type(v)=='table' and type(dst[k])=='table'then merge(dst[k],v)else dst[k]=v end
 end
 return dst
end
local function copy(t)local n={};for k,v in pairs(t)do n[k]=type(v)=='table' and copy(v)or v end;return n end
local function wrap(v,span)return v-math.floor(v/span)*span end
local function color(c,a)love.graphics.setColor(c[1]or 1,c[2]or 1,c[3]or 1,a)end

-- opts (all optional): flight_speed / flight_max_dt from world/config.lua, so the
-- wind response tracks the craft's real top speed instead of a fixed 180.
function M.new(read,opts)
 local cfg=copy(defaults)
 local ok,raw=pcall(function()
  return assert(loadstring(assert(read('world/flight_effects.lua')),'@soaring/world/flight_effects.lua'))()
 end)
 if ok and type(raw)=='table'then merge(cfg,raw)end
 cfg.altitude.low=number(cfg.altitude.low,150);cfg.altitude.middle=number(cfg.altitude.middle,380);cfg.altitude.high=number(cfg.altitude.high,760)
 local maxSpeed=number(opts and opts.flight_speed,180);if maxSpeed<=0 then maxSpeed=180 end
 local maxDt=number(opts and opts.flight_max_dt,.05);if maxDt<=0 then maxDt=.05 end
 local hazeMesh;local meshOk,mesh=pcall(love.graphics.newMesh,hazeFormat,6,'triangles','stream')
 if meshOk then hazeMesh=mesh end
 return setmetatable({config=cfg,time=0,speed=0,lastX=nil,lastY=nil,maxSpeed=maxSpeed,maxDt=maxDt,hazeMesh=hazeMesh},FX)
end

function FX:update(p,dt)
 dt=clamp(number(dt,0),0,self.maxDt);self.time=self.time+dt
 if self.lastX then
  local distance=math.sqrt((p.x-self.lastX)^2+(p.y-self.lastY)^2)
  local target=clamp(distance/math.max(.001,self.maxSpeed*dt),0,1.25)
  self.speed=self.speed+(target-self.speed)*(1-math.exp(-6*dt))
 end
 self.lastX,self.lastY=p.x,p.y
end

function FX:setAtmosphere(config) self.atmosphere=config end

-- This mesh belongs to the flight session, unlike the engine's shared atlas.
function FX:release()
 if self.hazeMesh then self.hazeMesh:release();self.hazeMesh=nil end
end

local function cloud(g,x,y,s,c,a)
 -- Two-tone stepped silhouette: broad readable masses, no noisy texture.
 color(c,a*.68);g.rectangle('fill',x-9*s,y-2*s,18*s,4*s)
 g.rectangle('fill',x-6*s,y-4*s,12*s,4*s);g.rectangle('fill',x-2*s,y-6*s,5*s,3*s)
 color(c,a);g.rectangle('fill',x-7*s,y-2*s,14*s,3*s)
 g.rectangle('fill',x-4*s,y-4*s,9*s,3*s);g.rectangle('fill',x-1*s,y-6*s,3*s,3*s)
end

function FX:layerAmount(p,layer)
 local a=self.config.altitude
 local start=layer.min_altitude or a.low
 return smooth(start,math.max(start+1,a.high),p.altitude or 0)
end

function FX:drawCloudLayer(p,ctx,layerName,zone)
 if ctx.worldClouds or (self.atmosphere and self.atmosphere.enabled and self.atmosphere.cloud_mode=='OFF') then return end
 local layer=self.config.clouds[layerName];if not layer then return end
 local amount=self:layerAmount(p,layer);if amount<=.01 then return end
 local g=love.graphics;local w=ctx.logicalWidth;local horizon=ctx.horizon
 local heading=p.cameraHeading or p.heading or 0
 local side=-(p.cameraX or p.x)*math.sin(heading)+(p.cameraY or p.y)*math.cos(heading)
 local forward=(p.cameraX or p.x)*math.cos(heading)+(p.cameraY or p.y)*math.sin(heading)
 local margin=42;local span=w+margin*2
 local count=math.max(0,math.floor(layer.count or 0))
 local at=self.atmosphere;local drift=layer.drift or 0
 if at and at.enabled then
  local velocity=at.shadow_velocity
  drift=(-velocity[1]*math.sin(heading)+velocity[2]*math.cos(heading))*(layer.parallax or 0)
  forward=forward-self.time*(velocity[1]*math.cos(heading)+velocity[2]*math.sin(heading))
 end
 for i=1,count do
  -- Even spacing prevents random clusters from becoming one bright block;
  -- the small deterministic jitter keeps the row from looking mechanical.
  local sx=((i-.5)+(hash(i,11)-.5)*.55)/math.max(1,count)
  local sy=hash(i,29);local ss=hash(i,47)
  local x=wrap(sx*span+self.time*drift-side*(layer.parallax or 0),span)-margin
  local y
  if zone=='sky'then y=math.max(10,horizon-24)+sy*18-forward*(layer.parallax or 0)*.018
  elseif zone=='world'then y=math.max(horizon+7,30)+sy*math.max(12,116-math.max(horizon+7,30))
  else y=24+sy*100 end
  local scale=(layer.scale_min or 1)+ss*((layer.scale_max or 1)-(layer.scale_min or 1))
  cloud(g,math.floor(x+.5),math.floor(y+.5),scale,layer.color,layer.alpha*amount)
 end
end

function FX:drawSky(p,ctx)
 if not self.config.enabled or ctx.top then return end
 local g=love.graphics;g.push();g.scale(ctx.quality,ctx.quality)
 self:drawCloudLayer(p,ctx,'far','sky');g.pop()
end

function FX:drawWorld(p,ctx)
 if not self.config.enabled or ctx.top then return end
 local g=love.graphics;g.push();g.scale(ctx.quality,ctx.quality)
 local h=self.config.haze;local haze=smooth(h.start,h.full,p.altitude or 0)*(h.max_alpha or 0)
 if haze>0 then
  -- Interpolate vertex alpha over one quad; stacked bands caused visible seams.
  local top=math.max(0,ctx.horizon);local bottom=136
  if self.hazeMesh then
   local c=h.color;local topAlpha=haze*.04;local bottomAlpha=haze
   self.hazeMesh:setVertices({
    {0,top,0,0,c[1],c[2],c[3],topAlpha},
    {ctx.logicalWidth,top,1,0,c[1],c[2],c[3],topAlpha},
    {ctx.logicalWidth,bottom,1,1,c[1],c[2],c[3],bottomAlpha},
    {0,top,0,0,c[1],c[2],c[3],topAlpha},
    {ctx.logicalWidth,bottom,1,1,c[1],c[2],c[3],bottomAlpha},
    {0,bottom,0,1,c[1],c[2],c[3],bottomAlpha},
   })
   self.hazeMesh:setDrawRange(1,6);g.setColor(1,1,1,1);g.draw(self.hazeMesh)
  else
   color(h.color,haze*.5);g.rectangle('fill',0,top,ctx.logicalWidth,bottom-top)
  end
 end
 self:drawCloudLayer(p,ctx,'middle','world');g.pop()
end

function FX:drawForeground(p,ctx)
 if not self.config.enabled or ctx.top then return end
 local g=love.graphics;g.push();g.scale(ctx.quality,ctx.quality)
 self:drawCloudLayer(p,ctx,'near','near')
 local wind=self.config.wind;local altitude=smooth(self.config.altitude.low,self.config.altitude.high,p.altitude or 0)
 local motion=clamp(self.speed,0,1);local count=math.floor((wind.base_count or 0)+(wind.fast_count or 0)*motion+.5)
 local at=self.atmosphere
 if at and at.enabled then count=math.floor(at.windCount*smooth(.4,1,motion)+.5) end
 local alpha=((wind.min_alpha or .1)+((wind.max_alpha or .25)-(wind.min_alpha or .1))*motion)*(.3+.7*altitude)
 local cx,cy=ctx.logicalWidth*.5,math.max(28,ctx.horizon+8)
 local rider=ctx.riderRect or {cx-30,44,cx+30,128}
 for i=1,count do
  local phase=wrap(hash(i,67)+self.time*(wind.travel_speed or 1.1)*(1+motion*.9),1)
  local side=(hash(i,83)*2-1);local x=cx+side*(18+phase*(ctx.logicalWidth*.52))
  local y=cy+phase*(132-cy);local vx=side*(2+phase*5);local vy=5+phase*8
  local len=(wind.short_length or 5)+((wind.long_length or 14)-(wind.short_length or 5))*motion
  local norm=math.sqrt(vx*vx+vy*vy);color(wind.color,alpha*(.55+phase*.45));g.setLineWidth(1)
  local x0,y0=x-vx/norm*len,y-vy/norm*len
  -- Keep the entire segment outside the rider's central screen rectangle.
  if not (at and at.enabled) or math.max(x,x0)<rider[1] or math.min(x,x0)>rider[3] or math.max(y,y0)<rider[2] or math.min(y,y0)>rider[4] then
    g.line(math.floor(x0)+.5,math.floor(y0)+.5,math.floor(x)+.5,math.floor(y)+.5)
  end
 end
 g.pop();g.setLineWidth(1)
end

return M
