local M={}

-- Soaring session state machine (item 3, gameplay-state pass). Six explicit
-- states, transitions only through Controller:update/failTransition/
-- markGame -- no other file writes self.state.
--
--   OUTSIDE    -- flying, not near a landing zone.        ~ "FLYING"
--   BANNER     -- just entered a zone; showing its name.  ~ "FLYING" (zone named)
--   LANDING    -- inside a low-altitude landing radius. A asks the injected
--                 eligibility rule before opening the prompt.
--   CONFIRM    -- landing prompt is up (YES/NO).           ~ "LANDING_PROMPT"
--   TRANSITION -- confirmed; the warp is in flight.        ~ "LANDING"
--   GAME       -- warp completed; control handed back      ~ "EXITING" (terminal)
--                 to the overworld.
--
-- OUTSIDE/BANNER <-> LANDING is driven by position + altitude every frame.
-- LANDING -> CONFIRM needs INTERACT. CONFIRM -> TRANSITION needs
-- LANDING_CONFIRM with YES selected; PROMPT_CANCEL or LANDING_CONFIRM with
-- NO selected returns to LANDING/OUTSIDE (cancelConfirm). TRANSITION and
-- GAME both stop this file's own per-frame updates (main.lua drives what
-- happens next: the warp callback, then closing the Soaring screen).
local STATES={OUTSIDE=true,BANNER=true,LANDING=true,CONFIRM=true,TRANSITION=true,GAME=true}
local function number(v) return type(v)=='number' and v==v and v~=math.huge and v~=-math.huge end
local function copy(t)
  local out={}
  for k,v in pairs(t or {}) do out[k]=type(v)=='table' and copy(v) or v end
  return out
end
local function parse(read)
  local text=assert(read('world/locations.lua'),'Missing world/locations.lua')
  return assert(assert(loadstring(text,'@world/locations.lua'))(),'Empty world/locations.lua')
end
-- Falls back to loading the real action map via the same `read` this file
-- was given, so an older caller that has not been updated to pass `actions`
-- explicitly (e.g. a DevKit test built against target/) still resolves the
-- one real soaring_actions.lua instead of a second, hand-duplicated table.
local function loadActionsFallback(read)
  local ok,mod=pcall(function()
    return assert(loadstring(assert(read('soaring_actions.lua')),'@soaring_actions'))()
  end)
  return ok and mod or nil
end

local Controller={};Controller.__index=Controller

function M.load(read,mapExists,actions,canLandAt,isVisible,onApproach,extraLocations)
  local raw=parse(read)
  local settings=copy(raw.settings)
  settings.banner_seconds=number(settings.banner_seconds) and settings.banner_seconds or 2
  settings.landing_max_altitude=number(settings.landing_max_altitude) and settings.landing_max_altitude or 380
  settings.fade_out_seconds=number(settings.fade_out_seconds) and settings.fade_out_seconds or .28
  settings.fade_in_seconds=number(settings.fade_in_seconds) and settings.fade_in_seconds or .32
  local self=setmetatable({settings=settings,locations={},warnings={},state='OUTSIDE',confirmIndex=1,
    actions=actions or loadActionsFallback(read),canLandAt=canLandAt or function() return true end,
    isVisible=isVisible or function() return true end,
    onApproach=onApproach or function() end},Controller)
  local seen={}
  local rows={}
  for _,row in ipairs(raw.locations or {}) do rows[#rows+1]=row end
  for _,row in ipairs(extraLocations or {}) do rows[#rows+1]=row end
  for index,row in ipairs(rows) do
    local ok=type(row)=='table' and type(row.id)=='string' and row.id~='' and not seen[row.id]
      and type(row.name)=='string' and type(row.center)=='table' and number(row.center.x) and number(row.center.y)
      and number(row.banner_radius) and row.banner_radius>0 and number(row.landing_radius)
      and row.landing_radius>0 and row.landing_radius<=row.banner_radius
    if ok then
      local loc=copy(row);loc.enabled=loc.enabled~=false;seen[loc.id]=true
      -- City ids are native Fly-town ids; their arrival cell comes from
      -- field.flyWarps. Hidden rows specify their registered mapId.
      loc.destinationValid=not mapExists or not not mapExists(loc.mapId or loc.id)
      if not loc.destinationValid then
        self.warnings[#self.warnings+1]='Invalid landing destination for '..loc.id
      end
      self.locations[#self.locations+1]=loc
    else
      self.warnings[#self.warnings+1]='Ignored malformed or duplicate location row '..index
    end
  end
  return self
end

function Controller:setState(state)
  assert(STATES[state],'Unknown Soaring location state '..tostring(state))
  self.state=state
end

function Controller:nearest(x,y,radiusKey)
  local best,bestD2
  for _,loc in ipairs(self.locations) do
    if loc.enabled and self.isVisible(loc) then
      local dx,dy=x-loc.center.x,y-loc.center.y
      local d2=dx*dx+dy*dy;local r=loc[radiusKey]
      if d2<=r*r and (not bestD2 or d2<bestD2) then best,bestD2=loc,d2 end
    end
  end
  return best,bestD2
end

function Controller:landingEligible(loc,altitude)
  return loc and loc.destinationValid and altitude<=(loc.landing_max_altitude or self.settings.landing_max_altitude)
end

function Controller:cancelConfirm()
  self.confirmIndex=1
  self:setState(self:landingEligible(self.landing,self.lastAltitude) and 'LANDING' or 'OUTSIDE')
end

function Controller:landingAllowed(loc)
  if not (loc and loc.destinationValid) then return false,'destination unavailable' end
  return self.canLandAt(loc)
end

function Controller:denyLanding(reason)
  self.notice=reason=='unvisited' and 'NOT VISITED YET' or 'LAND UNAVAILABLE'
  self.noticeTimer=2.2
end

-- Returns "land", location only when YES is accepted. Flight ownership stays
-- with the caller; CONFIRM and TRANSITION states deliberately consume input.
function Controller:update(player,input,dt)
  dt=math.max(0,math.min(dt or 0,.1));self.lastAltitude=player.altitude
  if self.state=='TRANSITION' or self.state=='GAME' then return end
  local actions=self.actions
  if self.state=='CONFIRM' then
    if actions.pressed(input,'PROMPT_UP') then self.confirmIndex=1 end
    if actions.pressed(input,'PROMPT_DOWN') then self.confirmIndex=2 end
    if actions.pressed(input,'PROMPT_CANCEL') then self:cancelConfirm();return 'cancel' end
    if actions.pressed(input,'LANDING_CONFIRM') then
      if self.confirmIndex==1 and self.landing then
        local allowed,reason=self:landingAllowed(self.landing)
        if allowed then self:setState('TRANSITION');return 'land',self.landing end
        self:cancelConfirm();self:denyLanding(reason)
        return 'unavailable',self.landing
      end
      self:cancelConfirm();return 'cancel'
    end
    return
  end

  local landing=self:nearest(player.x,player.y,'landing_radius')
  -- If radii overlap, the location whose landing radius contains the
  -- player owns the banner too. Within either class nearest center wins.
  local banner=landing or self:nearest(player.x,player.y,'banner_radius')
  self.nearestBanner,self.landing=banner,landing
  local bannerId=banner and banner.id or nil
  if bannerId~=self.insideId then
    self.insideId=bannerId;self.zone=banner;self.bannerTimer=0
    if banner then
      self.onApproach(banner)
      self.bannerTimer=self.settings.banner_seconds;self:setState('BANNER')
    else self:setState('OUTSIDE') end
  elseif self.state=='BANNER' then
    self.bannerTimer=math.max(0,(self.bannerTimer or 0)-dt)
    if self.bannerTimer<=0 then self:setState(self:landingEligible(landing,player.altitude) and 'LANDING' or 'OUTSIDE') end
  else
    self:setState(self:landingEligible(landing,player.altitude) and 'LANDING' or 'OUTSIDE')
  end
  local inRange=self:landingEligible(landing,player.altitude)
  local allowed,reason=self:landingAllowed(landing)
  self.landingUnavailable=inRange and not allowed or false
  self.landingReason=self.landingUnavailable and reason or nil
  if (self.state=='LANDING' or self.state=='BANNER') and inRange
      and actions.pressed(input,'INTERACT') then
    if not allowed then self:denyLanding(reason);return 'unavailable',landing end
    self.confirmIndex=1;self:setState('CONFIRM');return 'confirm',landing
  end
end

function Controller:failTransition(message)
  self.error=tostring(message or 'LANDING FAILED');self.errorTimer=2.5
  self:setState(self:landingEligible(self.landing,self.lastAltitude) and 'LANDING' or 'OUTSIDE')
end

function Controller:tickMessage(dt)
  if self.errorTimer then
    self.errorTimer=math.max(0,self.errorTimer-dt)
    if self.errorTimer==0 then self.errorTimer=nil;self.error=nil end
  end
  if self.noticeTimer then
    self.noticeTimer=math.max(0,self.noticeTimer-dt)
    if self.noticeTimer==0 then self.noticeTimer=nil;self.notice=nil end
  end
end

function Controller:markGame() self:setState('GAME') end
return M
