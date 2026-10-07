-- Presentation-only Dragonite/rider motion. Never writes to flight/camera state.
local M={}
local function clamp(x,lo,hi) return math.max(lo,math.min(hi,x)) end
local function value(config,key,default,lo,hi)
  local n=config[key]
  if type(n)~='number' or n~=n then n=default end
  return clamp(n,lo,hi)
end
function M.new(config)
  config=config or {}
  local enabled=config.rider_motion_enabled~=false
  local self={roll=0,pitch=0,bob=0,time=0,enabled=enabled,
    debugOverride=nil,notice=nil,noticeTime=0}
  function self:setEnabled(value,debug)
    self.enabled=not not value
    if debug then self.debugOverride=self.enabled end
    if not self.enabled then self.roll,self.pitch,self.bob=0,0,0 end
    self.notice='RIDER MOTION '..(self.enabled and 'ON' or 'OFF')
    self.noticeTime=1.5
  end
  function self:toggleDebug()
    self:setEnabled(not self.enabled,true)
    return self.enabled
  end
  function self:update(input,dt,currentConfig,altitudeDelta)
    currentConfig=currentConfig or {}
    dt=clamp(dt or 0,0,.1)
    self.noticeTime=math.max(0,self.noticeTime-dt)
    if self.debugOverride==nil then self.enabled=currentConfig.rider_motion_enabled~=false end
    if not self.enabled then self.roll,self.pitch,self.bob=0,0,0;return end
    local follow=value(currentConfig,'rider_roll_follow',7.5,.1,20)
    local blend=1-math.exp(-follow*dt)
    local turn=(input and input:isDown('right') and 1 or 0)-
      (input and input:isDown('left') and 1 or 0)
    local maxRoll=math.rad(value(currentConfig,'rider_roll_max',9,0,12))
    self.roll=self.roll+(turn*maxRoll-self.roll)*blend
    local maxPitch=math.rad(value(currentConfig,'rider_pitch_visual',3,0,8))
    local delta=altitudeDelta or 0
    local climb=delta>0 and 1 or (delta<0 and -1 or 0)
    self.pitch=self.pitch+(climb*maxPitch-self.pitch)*blend
    local speed=value(currentConfig,'rider_bob_speed',1.5,.1,5)
    self.time=(self.time+dt)%(math.pi*2/speed)
    local amplitude=value(currentConfig,'rider_bob_amplitude',1.0,0,3)
    self.bob=math.sin(self.time*speed)*amplitude
  end
  function self:presentation(mode,currentConfig)
    if not self.enabled or mode=='DEBUG_TOP' then
      return {roll=0,bob=0,scaleY=1,pitchOffset=0}
    end
    currentConfig=currentConfig or {}
    local range=math.rad(value(currentConfig,'rider_pitch_visual',3,0,8))
    local pitch=range>0 and clamp(self.pitch/range,-1,1) or 0
    -- The supplied rider is a front-facing sprite: a small vertical squash and
    -- sub-pixel lift suggest pitch without tilting the camera or world.
    return {roll=self.roll,bob=self.bob,scaleY=1+pitch*.035,pitchOffset=-pitch*.65}
  end
  return self
end
return M
