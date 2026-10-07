-- Maps the live engine time-of-day label to a restrained scene treatment.
-- This module never reads the clock or changes overworld/save state.
local M={}

local labels={
  AUTO={name='AUTO',amount=nil},
  MORNING={name='MORNING',amount=.10}, DAWN={name='DAWN',amount=.10},
  DAY={name='DAY',amount=0}, NOON={name='DAY',amount=0},
  DUSK={name='DUSK',amount=.42}, EVENING={name='DUSK',amount=.42}, SUNSET={name='DUSK',amount=.42},
  NIGHT={name='NIGHT',amount=1}, NITE={name='NIGHT',amount=1},
  DARK={name='NIGHT',amount=1}, DARKNESS={name='NIGHT',amount=1},
}
local previews={'AUTO','MORNING','DAY','DUSK','NIGHT'}
local function normalize(state)
  if type(state)~='string' or state=='' then state='DAY' end
  local key=state:upper():gsub('[^%w]+','_'):gsub('^_+',''):gsub('_+$','')
  local result=labels[key]
  if result then return result.name,result.amount,key end
  -- Unknown labels are preserved for QA but safely keep the daytime treatment.
  return key,0,key
end

local nightShaderSource=[[
extern number NightAmount;
vec4 effect(vec4 color,Image tex,vec2 uv,vec2 screen) {
  vec4 source=Texel(tex,uv)*color;
  float lum=dot(source.rgb,vec3(0.299,0.587,0.114));
  vec3 cool=source.rgb*vec3(0.50,0.63,0.84)
    +vec3(0.008,0.014,0.028)*(1.0-smoothstep(0.01,0.20,lum));
  return vec4(mix(source.rgb,cool,clamp(NightAmount,0.0,1.0)),source.a);
}
]]

-- Shared scene composite used by Soaring and its loading artwork.
function M.newShader(graphics)
  if not graphics or type(graphics.newShader)~='function' then return nil,'graphics shader API unavailable' end
  local ok,result=pcall(graphics.newShader,nightShaderSource)
  if ok then return result end
  return nil,tostring(result)
end

function M.new(config)
  return setmetatable({
    enabled=not (config and config.soaring_day_night==false),
    follow=config and config.soaring_time_follow or 2.2,
    strength=config and config.soaring_night_strength or .86,
    amount=0,initialized=false,engineLabel='DAY',label='DAY',
    previewIndex=1,notice='',noticeTime=0,
  },{__index=M})
end

function M:enter(engineState)
  local label,amount=normalize(engineState)
  self.engineLabel=label
  local selected=self.previewIndex>1 and labels[previews[self.previewIndex]] or nil
  self.label=selected and selected.name or label
  local target=self.enabled and ((selected and selected.amount) or amount) or 0
  self.amount=target;self.initialized=true
  return self.label
end

function M:update(engineState,dt,config)
  if config then
    self.enabled=config.soaring_day_night~=false
    self.follow=math.max(.1,math.min(10,tonumber(config.soaring_time_follow) or 2.2))
    self.strength=math.max(0,math.min(1,tonumber(config.soaring_night_strength) or .86))
  end
  local label,target=normalize(engineState)
  self.engineLabel=label
  local selected=self.previewIndex>1 and labels[previews[self.previewIndex]] or nil
  self.label=selected and selected.name or label
  target=self.enabled and ((selected and selected.amount) or target) or 0
  if not self.initialized then self.amount=target;self.initialized=true
  else
    dt=math.max(0,math.min(tonumber(dt) or 0,.1))
    self.amount=self.amount+(target-self.amount)*(1-math.exp(-dt*self.follow))
  end
  self.noticeTime=math.max(0,self.noticeTime-(tonumber(dt) or 0))
  return self.amount
end

function M:cyclePreview()
  self.previewIndex=self.previewIndex%#previews+1
  local value=previews[self.previewIndex]
  self.notice=value=='AUTO' and 'TOD AUTO' or ('TOD TEST '..value)
  self.noticeTime=1.8
  return value
end

function M:effectiveAmount(config)
  if not self.enabled or (config and config.soaring_day_night==false) then return 0 end
  local strength=config and tonumber(config.soaring_night_strength) or self.strength or .86
  return math.max(0,math.min(1,self.amount*math.max(0,math.min(1,strength))))
end

function M:previewName() return previews[self.previewIndex] end
M.normalize=normalize
M.previews=previews
return M
