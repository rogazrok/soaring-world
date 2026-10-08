-- Select encounter data for the engine's active imported edition.
-- Apply BEFORE HiddenAreas.load validates/registers definitions.
-- Does not enable games, modify saves, register maps or change lifecycle.
local M={}
local function clone(v)
  if type(v)~='table' then return v end
  local r={};for k,x in pairs(v) do r[k]=clone(x) end;return r
end
function M.apply(defs,edition,profiles)
  assert(edition=='red' or edition=='blue' or edition=='yellow','Unsupported edition')
  assert(type(defs)=='table' and type(defs.areas)=='table','Missing area definitions')
  assert(type(profiles)=='table' and type(profiles[edition])=='table','Missing edition profile')
  local result=clone(defs)
  for _,area in ipairs(result.areas) do
    if area.kind=='regular' then
      local pool=assert(profiles[edition][area.id],'Missing area profile: '..area.id)
      area.encounterPool=clone(pool)
      for _,profile in ipairs(area.encounterProfiles) do
        profile.species={}
        for _,row in ipairs(pool) do profile.species[#profile.species+1]=row.species end
      end
    end
  end
  return result
end
return M
