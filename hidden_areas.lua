-- Hidden Area content, saved spawn lifecycle and custom-map registration.
-- The existing location controller still owns banners, confirmation and landing.
local M={}
local PREFIX='hidden.lifecycle.'
local TAGS={forest=true,plains=true,mountain=true,coast=true,island=true,
  west=true,east=true,north=true,south=true}
local TEMPLATES={grove=true,summit=true,shore=true,pond=true,clearing=true,pier=true}
local MARKERS={grove=true,summit=true,shore=true,pond=true,clearing=true,pier=true}
local CONDITIONS={active=true,discovered=true,always=true}
local REWARD_PROFILE_ORDER={'common','rare','special'}
-- Fixed rewards shipped before 0.10.19. These are migration data only;
-- current definitions and newly rolled instances retain their own rewards.
local LEGACY_FIXED_REWARDS={HIDDEN_GROVE_01='POTION',
  ROCKY_SUMMIT_01='ANTIDOTE',SECRET_SHORE_01='POKE_BALL'}
function M.migrateLegacyRewards(data)
  local active=type(data)=='table' and data['hidden.lifecycle.active']
  if type(active)~='table' or type(active.rewardItem)=='string' then return end
  local item=LEGACY_FIXED_REWARDS[active.areaId]
  if item then active.rewardItem=item;active.rewardProfileId='legacy' end
end
-- Preserve the current fixed Summit pickup once; later visits use instance loot.
-- Historical completion/discovery stay intact and no RNG or steps are consumed.
function M.migrateRepeatableSummit(data,save)
  if type(data)~='table' or data['hidden.lifecycle.summitRepeatableVersion']==101 then return end
  local prefix='hidden.rocky_summit_01.'
  local key='SWR_ROCKY_SUMMIT_01_obj_1'
  local active=data['hidden.lifecycle.active']
  local taken=save and save.itemsTaken
  if type(active)=='table' and active.areaId=='ROCKY_SUMMIT_01' then
    if not active.rewardProfileId or active.rewardProfileId=='legacy' then
      active.rewardItem=active.rewardItem or 'MAX_REVIVE'
      active.rewardProfileId='legacy'
      active.rewardClaimed=active.rewardClaimed==true or data[prefix..'rewardClaimed']==true
        or (taken and taken[key]==true) or false
      active.rewardSyncInitialized=true
      if taken then taken[key]=active.rewardClaimed and true or nil end
    end
  elseif taken then taken[key]=nil end
  data[prefix..'globallyCompleted']=nil
  data[prefix..'rewardClaimed']=nil
  data['hidden.lifecycle.summitRepeatableVersion']=101
end
-- All blocks come from existing generated Red tilesets; no new pixel assets.
local BLOCKS={
  grove={T=2,['.']=27,g=1,r=6,s=33,f=40},
  summit={T=46,['.']=25,g=1,r=4,s=1,A=20,B=22,L=24,R=26,a=28,b=30,n=21,u=29},
  shore={W=67,h=31,['.']=1,g=11,r=19,s=1,b=28},
  pond={T=15,['.']=10,g=11,r=19,W=67,h=31,b=28,s=10},
  clearing={T=2,['.']=27,g=1,r=125,s=33,f=40,t=52},
  pier={['.']=12,W=13,d=21,c=3,b=2,r=17},
}
local MAP_STYLE={
  grove={tileset='FOREST',palette='GREENMON',border=2},
  summit={tileset='CAVERN',palette='BROWNMON',border=46},
  shore={tileset='OVERWORLD',palette='BROWNMON',border=67},
  pond={tileset='OVERWORLD',palette='PURPLEMON',border=15},
  clearing={tileset='FOREST',palette='BROWNMON',border=2},
  pier={tileset='SHIP_PORT',palette='VERMILION',border=13},
}
local LAYOUTS={
  grove={'TTTTTTTTT','TTTTgTTTT','TTggggTTT','TggTggggT','TTgg.g.gT',
    'TgT...ggT','Tgg...ggT','TTgg.sTTT','TTTTTTTTT'},
  summit={'TTTTTTTTT','TTAnnnBTT','TTr...RTT','TL.r..RRT','TL.r...RT',
    'TL..r..RT','TTa...bTT','TTTusuTTT','TTTTTTTTT'},
  shore={'WWWWWWWWW','WWWWWWWWW','WWW...WWW','WWb.g..WW','W.r.....W',
    'WW...g.WW','WW.....WW','WWh..sWWW','WWWWWWWWW'},
  pond={'TTTTTTTTT','TTTTggTTT','TTghhhgTT','TgWWWWggT','TgWWW...T',
    'TrWW..TgT','Tgg...ggT','TTg..sTTT','TTTTTTTTT'},
  clearing={'TTTTTTTTT','TTTg...TT','TTt...r.T','T...g...T','Tg......T',
    'T..r..tTT','T.......T','TTg..sTTT','TTTTTTTTT'},
  pier={'WWWWWWWWW','WWrrWWWWW','WW...c.WW','W..b...WW','WW......W',
    'WWW..dWWW','WWWW.dWWW','WWWWWdWWW','WWWWWWWWW'},
}
local MARKER_PARTS={
  pond={{'tree_group',-4,-3,.85},{'tree_group',4,-3,.85},
    {'rock_group',-2,2,1.1},{'rock_group',2,2,1.1}},
  clearing={{'tree_group',-4,-2,.65},{'tree_group',4,2,.65},
    {'rock_single',-2,3,.9},{'rock_single',2,-3,.9}},
  pier={{'dock',0,0,.85},{'rock_group',-3,2,.9},{'rock_group',3,2,.9}},
  grove={{'tree_group',-3,-2,.9},{'tree_group',3,-2,.9},
    {'tree_group',-3,2,.9},{'tree_group',3,2,.9},
    {'tree_group',0,-4,.85},{'tree_group',0,4,.85},
    {'rock_group',0,0,.8}},
  summit={{'rock_group',-3,-2,1.1},{'rock_group',3,-2,1.1},
    {'rock_group',-3,2,1.1},{'rock_group',3,2,1.1},
    {'rock_single',0,0,1.6}},
  shore={{'rock_group',-3,-1,.9},{'rock_group',3,-1,.9},
    {'tree_group',-3,3,.8},{'tree_group',3,3,.8},
    {'rock_single',0,1,1.2}},
}

local function number(n) return type(n)=='number' and n==n and n~=math.huge and n~=-math.huge end
local function integer(n) return number(n) and n%1==0 end
local function bool(v) return v==true end
local function areaKey(area,field) return 'hidden.'..area.saveKey..'.'..field end
local function get(mod,key,default) return mod.save:get(PREFIX..key,default) end
local function set(mod,key,value) mod.save:set(PREFIX..key,value) end
local function readTable(read,path)
  return assert(assert(loadstring(assert(read(path),'missing '..path),'@'..path))(),
    'empty '..path)
end
local function hasTag(left,right)
  if type(left)~='table' or type(right)~='table' then return false end
  for _,a in ipairs(left or {}) do for _,b in ipairs(right or {}) do
    if a==b then return true end
  end end
  return false
end
local function point(p)
  return type(p)=='table' and integer(p.x) and integer(p.y)
    and p.x>=0 and p.y>=0 and p.x<18 and p.y<18
end

function M.validate(defs,anchors,config,cities)
  local errors,ids,maps,mapIndexes,saveKeys,anchorIds={},{},{},{},{},{}
  local areaRows=defs and defs.areas or {}
  local anchorRows=anchors and anchors.anchors or {}
  if type(areaRows)~='table' or #areaRows==0 then errors[#errors+1]='missing area definitions';areaRows={} end
  if type(anchorRows)~='table' or #anchorRows==0 then errors[#errors+1]='missing spawn anchors';anchorRows={} end
  if type(config)~='table' or not integer(config.minSteps) or not integer(config.maxSteps)
      or config.minSteps<1 or config.maxSteps<config.minSteps
      or type(config.debugEnabled)~='boolean' then
    errors[#errors+1]='invalid spawn config'
  end
  for i,a in ipairs(anchorRows) do
    local p='anchors['..i..']'
    if type(a)~='table' then errors[#errors+1]=p..': expected table' else
      if type(a.id)~='string' or a.id=='' then errors[#errors+1]=p..': missing id'
      elseif anchorIds[a.id] then errors[#errors+1]=p..': duplicate anchor id' end
      if type(a.id)=='string' then anchorIds[a.id]=true end
      if not number(a.x) or not number(a.y) or a.x<0 or a.y<0
          or a.x>=2240 or a.y>=2240 then errors[#errors+1]=p..': invalid coordinates' end
      if type(a.tags)~='table' or #a.tags==0 then errors[#errors+1]=p..': missing tags' else
        for _,tag in ipairs(a.tags) do if not TAGS[tag] then errors[#errors+1]=p..': unknown tag '..tostring(tag) end end
      end
    end
  end
  for i,area in ipairs(areaRows) do
    local p='areas['..i..']'
    if type(area)~='table' then errors[#errors+1]=p..': expected table' else
      if type(area.id)~='string' or area.id=='' then errors[#errors+1]=p..': missing id'
      elseif ids[area.id] then errors[#errors+1]=p..': duplicate area id' end
      if type(area.id)=='string' then ids[area.id]=true end
      if type(area.mapId)~='string' or area.mapId=='' then errors[#errors+1]=p..': missing map'
      elseif maps[area.mapId] then errors[#errors+1]=p..': duplicate map' end
      if type(area.mapId)=='string' then maps[area.mapId]=true end
      if not integer(area.mapIndex) or area.mapIndex<1000 then errors[#errors+1]=p..': invalid map index'
      elseif mapIndexes[area.mapIndex] then errors[#errors+1]=p..': duplicate map index'
      else mapIndexes[area.mapIndex]=true end
      if type(area.saveKey)~='string' or area.saveKey=='' then errors[#errors+1]=p..': missing save key'
      elseif saveKeys[area.saveKey] then errors[#errors+1]=p..': duplicate save key' end
      if type(area.saveKey)=='string' then saveKeys[area.saveKey]=true end
      if type(area.name)~='string' or area.name=='' then errors[#errors+1]=p..': missing name' end
      if type(area.music)~='string' or area.music=='' then errors[#errors+1]=p..': missing map music' end
      if not TEMPLATES[area.template] then errors[#errors+1]=p..': unknown template' end
      if not MARKERS[area.marker] then errors[#errors+1]=p..': unknown marker' end
      if type(area.tags)~='table' or #area.tags==0 then errors[#errors+1]=p..': missing tags' else
        for _,tag in ipairs(area.tags) do if not TAGS[tag] then errors[#errors+1]=p..': unknown tag '..tostring(tag) end end
      end
      if not number(area.weight) or area.weight<=0 or area.weight%1~=0 then errors[#errors+1]=p..': invalid weight' end
      if type(area.repeatable)~='boolean' then errors[#errors+1]=p..': invalid repeat policy' end
      if not CONDITIONS[area.visibleWhen] or not CONDITIONS[area.landableWhen]
          or area.completeWhen~='exit' then errors[#errors+1]=p..': unknown condition' end
      if not number(area.approachRadius) or not number(area.landingRadius)
          or area.landingRadius<=0 or area.approachRadius<area.landingRadius then
        errors[#errors+1]=p..': invalid radii'
      end
      if not point(area.landingPoint) then
        errors[#errors+1]=p..': missing landing destination'
      end
      if area.exitPoint~=nil then errors[#errors+1]=p..': physical exits are forbidden' end
      if area.kind~='special' and (type(area.reward)~='table' or type(area.reward.item)~='string'
          or not integer(area.reward.index) or not point(area.reward)) then
        errors[#errors+1]=p..': invalid reward'
      end
      if area.repeatable then
        if type(area.rewardProfiles)~='table' then
          errors[#errors+1]=p..': missing reward profiles'
        else
          for _,profileId in ipairs(REWARD_PROFILE_ORDER) do
            local rewardProfile=area.rewardProfiles[profileId]
            if type(rewardProfile)~='table' or not integer(rewardProfile.weight)
                or rewardProfile.weight<1 or type(rewardProfile.items)~='table'
                or #rewardProfile.items==0 then
              errors[#errors+1]=p..': invalid reward profile '..profileId
            else
              for _,item in ipairs(rewardProfile.items) do
                if type(item)~='string' or item=='' then
                  errors[#errors+1]=p..': invalid reward item in '..profileId
                end
              end
            end
          end
          for profileId in pairs(area.rewardProfiles) do
            if profileId~='common' and profileId~='rare' and profileId~='special' then
              errors[#errors+1]=p..': unknown reward profile '..tostring(profileId)
            end
          end
        end
      elseif area.rewardProfiles~=nil then
        errors[#errors+1]=p..': permanent reward cannot use instance profiles'
      end
      if type(area.encounterProfiles)~='table' or #area.encounterProfiles==0 then
        errors[#errors+1]=p..': missing encounter profiles'
      else
        local profiles={}
        for _,profile in ipairs(area.encounterProfiles) do
          if type(profile)~='table' or type(profile.id)~='string' or profile.id==''
              or profiles[profile.id] or not integer(profile.rate) or profile.rate<0
              or profile.rate>255 or not integer(profile.level) or profile.level<1
              or profile.level>100 or (area.kind=='regular' and
                (not integer(profile.maxLevel) or profile.maxLevel<profile.level or profile.maxLevel>100))
              or type(profile.species)~='table' or #profile.species==0 then
            errors[#errors+1]=p..': invalid encounter profile'
          else
            profiles[profile.id]=true
            for _,species in ipairs(profile.species) do
              if type(species)~='string' or species=='' then
                errors[#errors+1]=p..': invalid encounter species'
              end
            end
          end
        end
      end
      if area.kind~='regular' and area.kind~='special' then errors[#errors+1]=p..': invalid area kind' end
      if area.kind=='special' then
        local e=area.staticEncounter;local a=area.fixedAnchor
        if not (a and type(a.id)=='string' and number(a.x) and number(a.y)
            and a.x>=0 and a.y>=0 and a.x<2240 and a.y<2240) then
          errors[#errors+1]=p..': invalid fixed anchor'
        elseif anchorIds[a.id] then errors[#errors+1]=p..': duplicate anchor id'
        else anchorIds[a.id]=true end
        if a and a.tags then
          for _,tag in ipairs(a.tags) do if not TAGS[tag] then errors[#errors+1]=p..': unknown fixed anchor tag' end end
        end
        if not (e and e.species=='MEW' and e.level==70 and e.index==2 and point(e)
            and e.sprite=='SPRITE_MONSTER' and area.repeatable==false and area.reward==nil) then
          errors[#errors+1]=p..': invalid static encounter'
        end
      else
        local total=0;local species={}
        for _,row in ipairs(area.encounterPool or {}) do
          if type(row.species)~='string' or species[row.species] or not integer(row.weight) or row.weight<=0 then
            errors[#errors+1]=p..': invalid weighted encounter'
          else total=total+row.weight;species[row.species]=true end
        end
        if total~=100 then errors[#errors+1]=p..': encounter weights must sum to 100' end
      -- Optional starter gating: the chosen starter's share returns to a normal species.
      for _,row in ipairs(area.encounterPool or {}) do
        if row.excludeIfStarter~=nil and type(row.excludeIfStarter)~='boolean' then
          errors[#errors+1]=p..': invalid starter exclusion'
        elseif row.excludeIfStarter and ((row.species~='BULBASAUR'
            and row.species~='CHARMANDER' and row.species~='SQUIRTLE')
            or not species[row.fallbackSpecies] or row.fallbackSpecies==row.species) then
          errors[#errors+1]=p..': invalid starter fallback'
        end
      end
      -- End starter gating validation.
      end
      local compatible=area.fixedAnchor~=nil
      for _,anchor in ipairs(anchorRows) do
        if type(anchor)=='table' and hasTag(area.tags,anchor.tags) then compatible=true end
      end
      if not compatible then errors[#errors+1]=p..': no compatible anchor' end
    end
  end
  -- Reject landing-radius collisions up front; overlapping approach circles
  -- are handled by the shared deterministic location resolver.
  local checkedAnchors={}
  for _,anchor in ipairs(anchorRows) do checkedAnchors[#checkedAnchors+1]=anchor end
  for _,area in ipairs(areaRows) do
    if type(area)=='table' and area.fixedAnchor then checkedAnchors[#checkedAnchors+1]=area.fixedAnchor end
  end
  for _,anchor in ipairs(checkedAnchors) do
    if type(anchor)=='table' and number(anchor.x) and number(anchor.y) then
      for _,city in ipairs(cities and cities.locations or {}) do
        local c=city.center
        if c and number(c.x) and number(c.y) and number(city.landing_radius) then
          for _,area in ipairs(areaRows) do
            if type(area)=='table' and number(area.landingRadius)
                and (area.fixedAnchor and area.fixedAnchor.id==anchor.id
                  or not area.fixedAnchor and hasTag(area.tags,anchor.tags)) then
              local r=city.landing_radius+area.landingRadius+8
              if (anchor.x-c.x)^2+(anchor.y-c.y)^2<r*r then
                errors[#errors+1]='anchor '..tostring(anchor.id)..' overlaps city landing zone '..tostring(city.id)
              end
            end
          end
        end
      end
    end
  end
  return errors
end

function M.load(read,definitions)
  local defs=definitions or readTable(read,'world/hidden_areas.lua')
  local anchors=readTable(read,'world/hidden_spawn_anchors.lua')
  local config=readTable(read,'world/hidden_spawn_config.lua')
  local cities=readTable(read,'world/locations.lua')
  local errors=M.validate(defs,anchors,config,cities)
  assert(#errors==0,table.concat(errors,'; '))
  local reg={areas=defs.areas,anchors=anchors.anchors,config=config,
    byId={},byMap={},byAnchor={}}
  for _,a in ipairs(reg.areas) do
    reg.byId[a.id]=a;reg.byMap[a.mapId]=a
    if a.fixedAnchor then reg.byAnchor[a.fixedAnchor.id]=a.fixedAnchor end
  end
  for _,a in ipairs(reg.anchors) do reg.byAnchor[a.id]=a end
  return reg
end
function M.validateItems(reg,items)
  local errors={}
  if type(items)~='table' then return {'missing engine item catalogue'} end
  for _,area in ipairs(reg.areas) do
    local function check(item,where)
      if type(item)~='string' or not items[item] then
        errors[#errors+1]=area.id..': unknown Red item '..tostring(item)..' in '..where
      end
    end
    if area.reward then check(area.reward.item,'base reward') end
    for profileId,profile in pairs(area.rewardProfiles or {}) do
      for _,item in ipairs(profile.items or {}) do check(item,'reward profile '..profileId) end
    end
  end
  return errors
end

local function profileEncounter(profile)
  local slots={}
  for i=1,10 do slots[i]={level=profile.level,
    species=profile.species[(i-1)%#profile.species+1]} end
  return {grass={rate=profile.rate,slots=slots}}
end
function M.profileFor(reg,area,profileId)
  for _,p in ipairs(area.encounterProfiles) do if p.id==profileId then return p end end
end
local function buildMap(area)
  local blocks={}
  local blockIds=BLOCKS[area.template]
  for _,line in ipairs(LAYOUTS[area.template]) do
    assert(#line==9,'hidden template must be nine blocks wide')
    for i=1,9 do blocks[#blocks+1]=assert(blockIds[line:sub(i,i)]) end
  end
  local reward=area.reward
  local objects={}
  if reward then objects[1]={index=reward.index,item=reward.item,name='SWR_'..area.id..'_ITEM',
    movement='STAY',range='NONE',sprite='SPRITE_POKE_BALL',
    text='TEXT_SWR_HIDDEN_ITEM',x=reward.x,y=reward.y} end
  local e=area.staticEncounter
  if e then objects[#objects+1]={index=e.index,pokemon=e.species,level=e.level,
    name='SWR_MEW',movement='STAY',range='NONE',sprite=e.sprite,
    text='TEXT_SWR_MEW',x=e.x,y=e.y} end
  local style=MAP_STYLE[area.template]
  return {id=area.mapId,label=area.mapId,index=area.mapIndex,
    tileset=style.tileset,palette=style.palette,
    width=9,height=9,
    blocks=blocks,borderBlock=style.border,
    warps={},connections={},outdoor=true,
    signs={{x=10,y=14,text='TEXT_SWR_HIDDEN_RETURN_HELP'}},
    objects=objects}
end
function M.register(mod,reg)
  local Game=require('src.core.Game')
  local itemErrors=M.validateItems(reg,Game.data and Game.data.items)
  assert(#itemErrors==0,table.concat(itemErrors,'; '))
  mod.content.text:register('_SWRMew','Mew!')
  mod.content.text:register('_SWRHiddenReturnHelp','START: choose\nSOARING WORLD.')
  for _,area in ipairs(reg.areas) do
    mod.content.maps:register(area.mapId,buildMap(area))
    mod.content.text_pointers:patch(area.mapId,{
      TEXT_SWR_HIDDEN_RETURN_HELP={text='_SWRHiddenReturnHelp'},TEXT_SWR_MEW={text='_SWRMew'}})
    mod.content.encounters:register(area.mapId,profileEncounter(area.encounterProfiles[1]))
  end
end

local MODULUS=2147483647
local function randomState(mod)
  local state=get(mod,'rngState')
  if not integer(state) or state<=0 or state>=MODULUS then
    state=love.math.random(1,MODULUS-1);set(mod,'rngState',state)
  end
  return state
end
local function randomInt(mod,first,last)
  local state=(randomState(mod)*48271)%MODULUS
  set(mod,'rngState',state)
  return first+state%(last-first+1)
end
function M.ensure(mod,reg)
  local threshold=get(mod,'threshold')
  if not integer(threshold) or threshold<reg.config.minSteps
      or threshold>reg.config.maxSteps then
    threshold=randomInt(mod,reg.config.minSteps,reg.config.maxSteps)
    set(mod,'threshold',threshold)
  end
  if not integer(get(mod,'steps')) or get(mod,'steps')<0 then set(mod,'steps',0) end
  return threshold
end
function M.active(mod,reg)
  local active=get(mod,'active')
  if type(active)~='table' or not reg.byId[active.areaId]
      or not reg.byAnchor[active.anchorId] then return nil end
  return active
end
function M.rewardProfileIds(area)
  local out={}
  for _,id in ipairs(REWARD_PROFILE_ORDER) do
    if area and area.rewardProfiles and area.rewardProfiles[id] then out[#out+1]=id end
  end
  return out
end
-- A 0.10.13 save can resume while the player is inside the old fixed Grove.
-- Reconstruct that one in-progress visit so its exit still returns to Soaring.
function M.adoptLegacy(mod,reg,area)
  if M.active(mod,reg) or not area or area.id~='HIDDEN_GROVE_01' then return end
  if get(mod,'legacyAdopted',false) then return end
  local old=mod.save:get(areaKey(area,'return'))
  if type(old)~='table' then return end
  local anchor=reg.byAnchor.viridian_forest_west
  if not anchor then return end
  local spot=type(old)=='table' and number(old.x) and number(old.y)
    and old or {x=anchor.x,y=anchor.y}
  set(mod,'legacyAdopted',true)
  set(mod,'active',{areaId=area.id,anchorId=anchor.id,profileId='common',
    seed=1,rewardItem=LEGACY_FIXED_REWARDS[area.id],rewardProfileId='legacy',
    discovered=true,visited=true,completed=false,returnSpot=spot})
end
function M.status(mod,reg)
  local threshold=M.ensure(mod,reg)
  return {steps=get(mod,'steps',0),threshold=threshold,active=M.active(mod,reg),
    testAll=bool(get(mod,'testAll')),testCursor=get(mod,'testCursor',0)}
end
function M.hasCompleted(mod,area)
  return mod.save:get(areaKey(area,'completed'),false)==true
    or mod.save:get(areaKey(area,'globallyCompleted'),false)==true
end
function M.setCompleted(mod,area)
  mod.save:set(areaKey(area,'completed'),true)
  mod.save:set(areaKey(area,'completionCount'),
    mod.save:get(areaKey(area,'completionCount'),0)+1)
  if not area.repeatable then mod.save:set(areaKey(area,'globallyCompleted'),true) end
end
local function compatible(reg,area)
  if area.fixedAnchor then return {area.fixedAnchor} end
  local out={}
  for _,anchor in ipairs(reg.anchors) do
    if hasTag(area.tags,anchor.tags) then out[#out+1]=anchor end
  end
  return out
end
function M.eligibleAreas(mod,reg)
  local out={}
  for _,area in ipairs(reg.areas) do
    if area.kind=='regular' and (area.repeatable or not M.hasCompleted(mod,area)) and #compatible(reg,area)>0 then
      out[#out+1]=area
    end
  end
  return out
end
function M.validatePool(mod,reg)
  return #M.eligibleAreas(mod,reg)>0
end
function M.forceSpawn(mod,reg,opts)
  opts=opts or {}
  if M.active(mod,reg) and not opts.replace then return nil,'active instance exists' end
  M.ensure(mod,reg)
  local area=opts.areaId and reg.byId[opts.areaId] or nil
  if opts.areaId and not area then return nil,'unknown area' end
  if not area and M.mewStatus(mod,reg).unlocked and randomInt(mod,1,100)<=20 then
    area=reg.byId.FORGOTTEN_PIER_01
  end
  if area and area.kind=='special' and not (opts.debugBypass and reg.config.debugEnabled)
      and not M.mewStatus(mod,reg).unlocked then return nil,'Mew expedition locked or consumed' end
  if not area then
    local pool=M.eligibleAreas(mod,reg)
    if #pool==0 then return nil,'eligible pool exhausted' end
    local total=0
    for _,row in ipairs(pool) do total=total+row.weight end
    local pick=randomInt(mod,1,total)
    for _,row in ipairs(pool) do
      pick=pick-row.weight
      if pick<=0 then area=row;break end
    end
  end
  if opts.rewardProfileId and not area.repeatable then
    return nil,'area uses permanent reward'
  end
  local anchors=compatible(reg,area)
  local anchor
  if opts.anchorId then
    for _,a in ipairs(anchors) do if a.id==opts.anchorId then anchor=a end end
    if not anchor then return nil,'incompatible anchor' end
  else anchor=anchors[randomInt(mod,1,#anchors)] end
  local profile
  if opts.profileId then profile=M.profileFor(reg,area,opts.profileId)
  else profile=area.encounterProfiles[randomInt(mod,1,#area.encounterProfiles)] end
  if not profile then return nil,'invalid encounter profile' end
  local rewardProfile,rewardItem,rewardProfileId
  if area.repeatable then
    if opts.rewardProfileId then
      rewardProfileId=opts.rewardProfileId
      rewardProfile=area.rewardProfiles and area.rewardProfiles[rewardProfileId]
      if not rewardProfile then return nil,'invalid reward profile' end
    else
      local total=0
      for _,id in ipairs(REWARD_PROFILE_ORDER) do
        local row=area.rewardProfiles and area.rewardProfiles[id]
        if row then total=total+row.weight end
      end
      if total<1 then return nil,'reward profiles unavailable' end
      local pick=randomInt(mod,1,total)
      for _,id in ipairs(REWARD_PROFILE_ORDER) do
        local row=area.rewardProfiles and area.rewardProfiles[id]
        if row then
          pick=pick-row.weight
          if pick<=0 then rewardProfileId=id;rewardProfile=row;break end
        end
      end
    end
    if opts.rewardProfileId then
      -- Debug profile forcing is deterministic: it picks the first authored
      -- item so QA can test each profile without another random roll.
      rewardItem=rewardProfile.items[1]
    else
      rewardItem=rewardProfile.items[randomInt(mod,1,#rewardProfile.items)]
    end
  end
  local instanceId=get(mod,'instanceCounter',0)+1
  set(mod,'instanceCounter',instanceId)
  local active={areaId=area.id,anchorId=anchor.id,profileId=profile.id,
    seed=randomInt(mod,1,MODULUS-1),instanceId=instanceId,
    rewardProfileId=rewardProfileId,rewardItem=rewardItem,
    rewardClaimed=false,rewardSyncInitialized=false,
    discovered=false,visited=false,completed=false}
  set(mod,'active',active)
  return active
end
function M.onStep(mod,reg,eligible)
  if not eligible then return nil end
  local threshold=M.ensure(mod,reg)
  if M.active(mod,reg) then return nil end
  local steps=get(mod,'steps',0)+1
  set(mod,'steps',steps)
  if steps>=threshold then return M.forceSpawn(mod,reg) end
  return nil
end
-- A saved instance owns one gentle hint. Loading or opening the map does not
-- consume it; acknowledge only after the flight UI has actually displayed it.
function M.spawnNotice(mod,reg)
  local a=M.active(mod,reg)
  if not a or a.visited or a.noticeShown then return nil end
  if a.areaId=='FORGOTTEN_PIER_01' then
    return {instanceId=a.instanceId,areaId=a.areaId,lines={
      'DRAGONITE senses', 'a strange presence', 'near VERMILION...'}}
  end
  return {instanceId=a.instanceId,areaId=a.areaId,lines={
    'DRAGONITE senses', 'a hidden place', 'in KANTO...'}}
end
function M.acknowledgeNotice(mod,reg,notice)
  local a=M.active(mod,reg)
  if a and notice and a.instanceId==notice.instanceId and a.areaId==notice.areaId then
    a.noticeShown=true;set(mod,'active',a);return true
  end
  return false
end
function M.activeLocation(mod,reg)
  local active=M.active(mod,reg)
  if not active then return nil end
  local area,anchor=reg.byId[active.areaId],reg.byAnchor[active.anchorId]
  if area.kind=='special' and M.mewStatus(mod,reg).consumed then return nil end
  return {id=area.id,kind='hidden',name=M.isDiscovered(mod,area) and area.name or '???',enabled=true,
    center={x=anchor.x,y=anchor.y},banner_radius=area.approachRadius,
    landing_radius=area.landingRadius,mapId=area.mapId,
    landingPoint=area.landingPoint,
    anchorId=anchor.id,profileId=active.profileId,saveKey=area.saveKey}
end
local function condition(mod,reg,loc,rule)
  local active=M.active(mod,reg)
  if not (active and active.areaId==loc.id and active.anchorId==loc.anchorId) then
    return false
  end
  if rule=='always' or rule=='active' then return true end
  if rule=='discovered' then return active.discovered==true end
  return false
end
function M.isVisible(mod,reg,loc)
  if loc.kind~='hidden' then return true end
  local area=reg.byId[loc.id]
  if area and area.kind=='special' and M.mewStatus(mod,reg).consumed then return false end
  return area and condition(mod,reg,loc,area.visibleWhen) or false
end
function M.onApproach(mod,reg,loc)
  if loc.kind~='hidden' then return end
  local active=M.active(mod,reg)
  if active and active.areaId==loc.id and active.anchorId==loc.anchorId
      and not active.discovered then
    active.discovered=true;set(mod,'active',active)
    -- Approach reveals the active marker only; successful entry unlocks the definition name.
  end
end
function M.canLandAt(mod,game,reg,loc)
  if not M.isVisible(mod,reg,loc) then return false,'hidden' end
  local active=M.active(mod,reg)
  local area=reg.byId[active.areaId]
  if not condition(mod,reg,loc,area.landableWhen) then return false,'undiscovered' end
  if not (game and game.data and game.data.maps and game.data.maps[area.mapId]) then
    return false,'destination unavailable'
  end
  return true,nil,{map=area.mapId,x=area.landingPoint.x,y=area.landingPoint.y,
    facing='down'}
end
local function rewardItemKey(area)
  return area.mapId..'_obj_'..area.reward.index
end
function M.applyInstanceReward(mod,reg,area,npc)
  if not area or not area.reward or not npc or not npc.def
      or npc.id~=rewardItemKey(area) then return false end
  local active=get(mod,'active')
  if type(active)~='table' or active.areaId~=area.id then return false end
  if not area.repeatable and active.rewardProfileId~='legacy' then return false end
  -- Saves made by 0.10.17 can still contain a live fixed-item instance.
  -- Keep its former item instead of rerolling during the upgrade.
  if type(active.rewardItem)~='string' then
    active.rewardItem=LEGACY_FIXED_REWARDS[area.id] or area.reward.item
    active.rewardProfileId='legacy'
    active.rewardSyncInitialized=active.rewardSyncInitialized==true
    set(mod,'active',active)
  end
  npc.def.item=active.rewardItem
  return true
end
function M.onEntered(mod,reg,area,game)
  local active=M.active(mod,reg)
  if active and active.areaId==area.id then
    active.visited=true;set(mod,'active',active)
  end
  mod.save:set(areaKey(area,'visited'),true)
  mod.save:set(areaKey(area,'discovered'),true)
  mod.save:set(areaKey(area,'discoveryVersion'),19)
  if area.staticEncounter then M.syncMew(mod,reg,game);return end
  local taken=game and game.save and game.save.itemsTaken
  local oldTaken=area.repeatable and area.reward and taken
    and taken[rewardItemKey(area)]==true
  M.syncReward(mod,game,area)
  if area.reward and mod.world and mod.world.overworld then
    local ow=mod.world:overworld()
    if ow and ow.map and ow.map.id==area.mapId and ow.npcAtCell then
      local npc=ow:npcAtCell(area.reward.x,area.reward.y)
      -- The engine filters objects before map.entered. If instance sync just
      -- cleared a stale pickup bit, restore that authored object in this map.
      -- Claimed visits keep their bit and never enter this repair path.
      if oldTaken and not taken[rewardItemKey(area)]
          and ow.npcPool and ow.npcs and ow.entities then
        local id=rewardItemKey(area)
        local present=false
        for _,row in ipairs(ow.npcs) do
          if row.id==id then npc=row;present=true;break end
        end
        if not present then
          local Overworld=require('src.world.OverworldController')
          for _,obj in ipairs(ow.map.def.objects or {}) do
            if obj.index==area.reward.index and obj.item
                and Overworld.objectVisible(game.save,area.mapId,obj) then
              npc=Overworld.pooledNPC(ow.npcPool,game.data,area.mapId,obj)
              npc.frozen=false
              table.insert(ow.npcs,npc);table.insert(ow.entities,npc)
              break
            end
          end
        end
      end
      M.applyInstanceReward(mod,reg,area,npc)
    end
  end
end
function M.syncReward(mod,game,area)
  local taken=game and game.save and game.save.itemsTaken
  if not area.reward then return false end
  local key=rewardItemKey(area)
  if area.repeatable then
    local active=get(mod,'active')
    if type(active)~='table' or active.areaId~=area.id then return false end
    if type(active.rewardClaimed)~='boolean' then
      -- Upgrade an in-progress 0.10.16 save. That release kept only a
      -- save-wide flag plus the native object bit, so preserve the current
      -- visit once. New .17 instances always start clear below.
      active.rewardClaimed=mod.save:get(areaKey(area,'rewardClaimed'),false)==true
        or (taken and taken[key]==true) or false
      active.rewardSyncInitialized=true
      local counter=get(mod,'instanceCounter',0)+1
      set(mod,'instanceCounter',counter)
      active.instanceId=active.instanceId or counter
      if taken then taken[key]=active.rewardClaimed and true or nil end
      set(mod,'active',active)
    end
    if not active.rewardSyncInitialized then
      -- Native `itemsTaken` is keyed by map/object, so it would otherwise
      -- leak a pickup into the next Grove/Shore instance. Bind the engine bit
      -- to this saved instance once, when its map is first entered. New games
      -- may not have an itemsTaken table yet; mark the empty state initialized
      -- too, so the first pickup event is recorded instead of cleared.
      if taken then taken[key]=active.rewardClaimed and true or nil end
      active.rewardSyncInitialized=true
      set(mod,'active',active)
    elseif taken and active.rewardClaimed then
      taken[key]=true
    elseif taken and taken[key] then
      -- The engine raises this bit at the moment it awards the item. Capture
      -- that state in the active instance so a save/reload cannot respawn it.
      active.rewardClaimed=true
      set(mod,'active',active)
    end
    return active.rewardClaimed==true
  end
  -- Non-repeatable areas keep the permanent reward channel for unique items.
  if taken and taken[key] then
    mod.save:set(areaKey(area,'rewardClaimed'),true)
    return true
  end
  if mod.save:get(areaKey(area,'rewardClaimed'),false)==true then
    if taken then taken[key]=true end
    return true
  end
  return false
end
function M.rewardClaimed(mod,area)
  if not area.reward then return false end
  if area.repeatable then
    local active=get(mod,'active')
    return type(active)=='table' and active.areaId==area.id
      and active.rewardClaimed==true or false
  end
  return mod.save:get(areaKey(area,'rewardClaimed'),false)==true
end
function M.rewardStatus(mod,reg,area)
  local active=M.active(mod,reg)
  if area and active and active.areaId==area.id
      and (area.repeatable or active.rewardProfileId=='legacy') then
    local item=active.rewardItem or LEGACY_FIXED_REWARDS[area.id] or area.reward.item
    return active.rewardProfileId or 'legacy',item
  end
  return nil,area and not area.repeatable and area.reward and area.reward.item or nil
end
function M.permanentRewardClaimed(mod,area)
  return mod.save:get(areaKey(area,'rewardClaimed'),false)==true
end
function M.setPermanentRewardClaimed(mod,area,value)
  mod.save:set(areaKey(area,'rewardClaimed'),value and true or nil)
end
function M.saveReturn(mod,reg,loc,flight,origin)
  local active=M.active(mod,reg)
  if active and active.areaId==loc.id then
    active.returnSpot={x=flight.x,y=flight.y,
      altitude=flight.altitude,heading=flight.heading}
    if origin and not reg.byMap[origin.mapId] then
      active.returnOverworld={mapId=origin.mapId,x=origin.x,y=origin.y,facing=origin.facing}
    end
    set(mod,'active',active)
  end
end
function M.returnSpawn(mod,reg,area)
  local active=M.active(mod,reg)
  if not active or active.areaId~=area.id then return nil end
  local spot=active.returnSpot
  if type(spot)=='table' and number(spot.x) and number(spot.y) then return spot end
  local anchor=reg.byAnchor[active.anchorId]
  return {x=anchor.x,y=anchor.y}
end
function M.fallbackSpawn(reg,area)
  local anchors=compatible(reg,area)
  local anchor=anchors[1]
  return anchor and {x=anchor.x,y=anchor.y} or {x=686,y=952}
end
function M.nextTestCase(mod,reg)
  local cases={}
  for _,area in ipairs(reg.areas) do
    for _,profile in ipairs(area.kind=='regular' and area.encounterProfiles or {}) do
      cases[#cases+1]={areaId=area.id,profileId=profile.id}
    end
  end
  local i=get(mod,'testCursor',0)+1
  if i>#cases then set(mod,'testAll',false);return nil,'test cases complete' end
  set(mod,'testCursor',i)
  local case=cases[i]
  return M.forceSpawn(mod,reg,{areaId=case.areaId,profileId=case.profileId,replace=true})
end
function M.startTestAll(mod,reg)
  set(mod,'testCursor',0);set(mod,'testAll',true)
  return M.nextTestCase(mod,reg)
end
function M.completeActive(mod,reg,orphanArea,game)
  local active=M.active(mod,reg)
  if not active and not orphanArea then return nil,'no active instance' end
  local area=active and reg.byId[active.areaId] or orphanArea
  local spot=M.returnSpawn(mod,reg,area)
  if active then active.completed=true end
  M.setCompleted(mod,area)
  if area.staticEncounter then M.consumeMew(mod,reg,game) end
  -- The native pickup bit is keyed by map/object rather than instance. Once a
  -- repeatable instance ends, clear that bit before a future map load so its
  -- next instance can construct the object ball again.
  if area.repeatable and game and game.save and game.save.itemsTaken then
    game.save.itemsTaken[rewardItemKey(area)]=nil
  end
  set(mod,'active',nil);set(mod,'steps',0);set(mod,'threshold',nil)
  M.ensure(mod,reg)
  -- Explicit exit always ends the expedition, even in TEST ALL.
  -- The next debug case requires the separate Next Test Case action.
  mod.save:set(areaKey(area,'return'),nil)
  set(mod,'legacyAdopted',true)
  return spot
end
function M.resetActive(mod,reg)
  set(mod,'active',nil);set(mod,'steps',0)
  return M.ensure(mod,reg)
end
function M.resetAll(mod,reg,game)
  local current=mod.world and mod.world.current and mod.world:current()
  if current and current.mapId==reg.byId.FORGOTTEN_PIER_01.mapId then
    return nil,'leave Pier before reset'
  end
  M.resetMew(mod,reg,game)
  for _,area in ipairs(reg.areas) do
    for _,field in ipairs({'discovered','visited','rewardClaimed','completed',
        'completionCount','globallyCompleted','return','discoveryVersion'}) do
      mod.save:set(areaKey(area,field),nil)
    end
    if area.reward and game and game.save and game.save.itemsTaken then
      game.save.itemsTaken[rewardItemKey(area)]=nil
    end
  end
  for _,field in ipairs({'active','steps','threshold','rngState','testAll','testCursor','legacyAdopted'}) do
    set(mod,field,nil)
  end
  M.ensure(mod,reg)
  return true
end
function M.debugSteps(mod,reg,action)
  local threshold=M.ensure(mod,reg)
  if action=='add1' then set(mod,'steps',get(mod,'steps',0)+1)
  elseif action=='add100' then set(mod,'steps',get(mod,'steps',0)+100)
  elseif action=='before' then set(mod,'steps',math.max(0,threshold-1))
  elseif action=='trigger' then set(mod,'steps',threshold)
  else return nil,'unknown step action' end
  if not M.active(mod,reg) and get(mod,'steps',0)>=threshold then
    return M.forceSpawn(mod,reg)
  end
  return true
end
function M.profileEncounter(mod,reg,mapId)
  local active=M.active(mod,reg)
  local area=reg.byMap[mapId]
  if not area then return nil end
  local profile=active and active.areaId==area.id
    and M.profileFor(reg,area,active.profileId) or area.encounterProfiles[1]
  return profileEncounter(profile)
end
function M.decorateWorld(mod,reg,world)
  local active=M.active(mod,reg)
  if not active then return end
  local area,anchor=reg.byId[active.areaId],reg.byAnchor[active.anchorId]
  if area.kind=='special' and M.mewStatus(mod,reg).consumed then return end
  local scale=world.config.world_scale
  for i,part in ipairs(MARKER_PARTS[area.marker]) do
    world.objects[#world.objects+1]={type=part[1],name='SWR_ACTIVE_HIDDEN_'..i,
      x=anchor.x/scale+part[2],y=anchor.y/scale+part[3],scale=part[4]}
  end
end
function M.isDiscovered(mod,area)
  -- Earlier builds set discovered on approach. Migrate only successful visits.
  if mod.save:get(areaKey(area,'discoveryVersion'))~=19 then
    mod.save:set(areaKey(area,'discovered'),mod.save:get(areaKey(area,'visited'),false)==true)
    mod.save:set(areaKey(area,'discoveryVersion'),19)
  end
  return mod.save:get(areaKey(area,'discovered'),false)==true
end
function M.discoveryCount(mod,reg)
  local count=0
  for _,area in ipairs(reg.areas) do
    if area.kind=='regular' and M.isDiscovered(mod,area) then count=count+1 end
  end
  return count
end
function M.mewStatus(mod,reg)
  local consumed=mod.save:get('hidden.mew.encounterConsumed',false)==true
  return {unlocked=M.discoveryCount(mod,reg)==5 and not consumed,
    consumed=consumed,captured=mod.save:get('hidden.mew.captured',false)==true}
end
local function mewKey(reg)
  local area=reg.byId.FORGOTTEN_PIER_01
  return area.mapId..'_obj_'..area.staticEncounter.index
end
function M.syncMew(mod,reg,game)
  if not M.mewStatus(mod,reg).consumed then return end
  if game and game.save then
    game.save.defeatedTrainers=game.save.defeatedTrainers or {}
    game.save.defeatedTrainers[mewKey(reg)]=true
  end
  local ow=mod.world and mod.world:overworld()
  if ow and ow.map and ow.map.id==reg.byId.FORGOTTEN_PIER_01.mapId then
    for _,list in ipairs({ow.npcs or {},ow.entities or {}}) do
      for i=#list,1,-1 do if list[i].id==mewKey(reg) then table.remove(list,i) end end
    end
  end
end
function M.consumeMew(mod,reg,game)
  mod.save:set('hidden.mew.encounterConsumed',true)
  M.syncMew(mod,reg,game)
end
function M.resetMew(mod,reg,game)
  if not reg.config.debugEnabled then return nil,'debug disabled' end
  local area=reg.byId.FORGOTTEN_PIER_01
  local current=mod.world and mod.world:current()
  if current and current.mapId==area.mapId then return nil,'leave Pier before reset' end
  local active=M.active(mod,reg)
  if active and active.areaId==area.id then M.resetActive(mod,reg) end
  for _,field in ipairs({'discovered','visited','discoveryVersion','completed','globallyCompleted','completionCount','return'}) do
    mod.save:set(areaKey(area,field),nil)
  end
  mod.save:set('hidden.mew.encounterConsumed',nil);mod.save:set('hidden.mew.captured',nil)
  if game and game.save and game.save.defeatedTrainers then game.save.defeatedTrainers[mewKey(reg)]=nil end
  return true
end
function M.debugDiscovery(mod,reg,action)
  if not reg.config.debugEnabled then return nil,'debug disabled' end
  local active=M.active(mod,reg)
  for _,area in ipairs(reg.areas) do
    if action=='reset' or (action=='all' and area.kind=='regular')
        or (action=='current' and active and active.areaId==area.id) then
      mod.save:set(areaKey(area,'discovered'),action~='reset')
      mod.save:set(areaKey(area,'discoveryVersion'),19)
    end
  end
  return true
end
function M.weightedEncounter(mod,reg,mapId,rng,save)
  local area=reg.byMap[mapId]
  if not area or area.kind=='special' then return nil end
  local active=M.active(mod,reg)
  local profile=M.profileFor(reg,area,active and active.profileId) or area.encounterProfiles[1]
  rng=rng or love.math.random
  local pick=rng(1,100)
  for _,row in ipairs(area.encounterPool) do
    pick=pick-row.weight
    if pick<=0 then
      local excluded=row.excludeIfStarter and save and save.flags
        and save.flags['EVENT_CHOSE_'..row.species]==true
      return {species=excluded and row.fallbackSpecies or row.species,
        level=rng(profile.level,profile.maxLevel)}
    end
  end
end
M.buildMap=buildMap
M.compatibleAnchors=compatible
return M
