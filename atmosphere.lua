-- Small validated configuration, not a second effects/rendering framework.
local M={}
local defaults={enabled=true,quality='MEDIUM',haze=true,animated_water=true,
  cloud_shadows=true,directional_shading=false,wind_streaks=true,
  cloud_mode='WORLD',local_mist=true,cloud_density=.18,cloud_opacity=.11,cloud_velocity={2.2,.8},
  haze_start=650,haze_end=2200,haze_intensity=.16,water_speed=.008,water_blend=.18,
  shadow_scale=480,shadow_intensity=.075,shadow_velocity={8,3},
  directional_intensity=.10,sun_direction={-.55,-.35,.76}}
local profiles={LOW={haze=.7,water=1,shadow=0,wind=0},
  MEDIUM={haze=1,water=2,shadow=1,wind=2},HIGH={haze=1.15,water=2,shadow=1.2,wind=3}}
local function numeric(v,a,b,name)
  assert(type(v)=='number' and v==v and v>=a and v<=b,'Invalid atmosphere '..name)
  return v
end
function M.resolve(raw)
  local c={};for k,v in pairs(defaults) do c[k]=v end
  for k,v in pairs(raw or {}) do assert(defaults[k]~=nil,'Unknown atmosphere option '..tostring(k));c[k]=v end
  for _,key in ipairs({'enabled','haze','animated_water','cloud_shadows','directional_shading','wind_streaks','local_mist'}) do
    assert(type(c[key])=='boolean','Invalid atmosphere toggle '..key)
  end
  assert(c.cloud_mode=='WORLD' or c.cloud_mode=='SCREEN' or c.cloud_mode=='OFF','Invalid cloud_mode')
  numeric(c.cloud_density,0,.28,'cloud_density');numeric(c.cloud_opacity,0,.20,'cloud_opacity')
  assert(type(c.cloud_velocity)=='table' and #c.cloud_velocity==2,'Invalid cloud_velocity')
  for _,v in ipairs(c.cloud_velocity) do numeric(v,-10,10,'cloud_velocity') end
  local p=assert(profiles[c.quality],'Atmosphere quality must be LOW, MEDIUM or HIGH')
  numeric(c.haze_start,0,10000,'haze_start');numeric(c.haze_end,c.haze_start+1,20000,'haze_end')
  numeric(c.haze_intensity,0,1,'haze_intensity');numeric(c.water_speed,0,.05,'water_speed')
  numeric(c.water_blend,0,.35,'water_blend');numeric(c.shadow_scale,100,3000,'shadow_scale')
  numeric(c.shadow_intensity,0,.2,'shadow_intensity');numeric(c.directional_intensity,0,.2,'directional_intensity')
  assert(type(c.shadow_velocity)=='table' and #c.shadow_velocity==2,'Invalid shadow_velocity')
  for _,v in ipairs(c.shadow_velocity) do numeric(v,-50,50,'shadow_velocity') end
  assert(type(c.sun_direction)=='table' and #c.sun_direction==3,'Invalid sun_direction')
  local length=0;for _,v in ipairs(c.sun_direction) do numeric(v,-1,1,'sun_direction');length=length+v*v end
  assert(length>.001,'sun_direction cannot be zero')
  c.sun={};for i,v in ipairs(c.sun_direction) do c.sun[i]=v/math.sqrt(length) end
  local on=c.enabled
  c.hazeAmount=on and c.haze and math.min(1,c.haze_intensity*p.haze) or 0
  c.waterLayers=on and c.animated_water and c.water_speed>0 and p.water or 0
  c.shadowAmount=on and c.cloud_shadows and c.shadow_intensity*p.shadow or 0
  c.lightAmount=on and c.directional_shading and c.directional_intensity or 0
  c.cloudBanks=({LOW=10,MEDIUM=18,HIGH=24})[c.quality]
  c.cloudPuffs=c.quality=='LOW' and 3 or (c.quality=='MEDIUM' and 4 or 5)
  c.windCount=on and c.wind_streaks and p.wind or 0
  return c
end
function M.load(read)
  local bytes=read('world/atmosphere.lua')
  if not bytes then return M.resolve({enabled=false}) end
  return M.resolve(assert(loadstring(bytes,'@world/atmosphere.lua'))())
end
return M
