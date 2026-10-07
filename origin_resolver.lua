local M={}
local Resolver={};Resolver.__index=Resolver

local function finite(v)return type(v)=='number'and v==v and v~=math.huge and v~=-math.huge end
local function clamp(v,a,b)return math.max(a,math.min(b,v))end
local facingHeading={right=0,down=math.pi/2,left=math.pi,up=-math.pi/2}

local function readData(read)
  local text=assert(read('world/takeoff.lua'),'Missing world/takeoff.lua')
  return assert(assert(loadstring(text,'@world/takeoff.lua'))(),'Empty world/takeoff.lua')
end

local function validatePoint(p)
  return type(p)=='table'and finite(p.x or p[1])and finite(p.y or p[2])
end

-- City centers are authored once, in world/locations.lua. takeoff.lua refers to
-- them by location id ({location='ID'} rows and string path points) instead of
-- repeating the coordinates. A missing or unreadable locations file only means no
-- symbolic references resolve; rows with literal coordinates keep working.
local function readCenters(read)
  local centers={}
  local ok,text=pcall(read,'world/locations.lua')
  if not(ok and type(text)=='string')then return centers end
  local chunk=loadstring(text,'@world/locations.lua');if not chunk then return centers end
  local okRun,data=pcall(chunk)
  if not(okRun and type(data)=='table')then return centers end
  for _,loc in ipairs(data.locations or {})do
    local c=type(loc)=='table'and loc.center
    if type(loc.id)=='string'and type(c)=='table'and finite(c.x)and finite(c.y)then centers[loc.id]={x=c.x,y=c.y}end
  end
  return centers
end

-- Returns the normalized row (literal points only) or nil, reason.
local function normalizeRow(mapId,row,centers)
  if type(mapId)~='string'or type(row)~='table'then return nil end
  if row.location~=nil then
    local c=centers[row.location]
    if not c then return nil,'unknown location '..tostring(row.location)end
    local out={};for k,v in pairs(row)do out[k]=v end
    out.location=nil;out.point={x=c.x,y=c.y};return out
  end
  if row.point then
    if validatePoint(row.point)then return row end
    return nil
  end
  if row.path then
    if not((row.axis=='x'or row.axis=='y')and type(row.path)=='table'and #row.path>=2)then return nil end
    local out={};for k,v in pairs(row)do out[k]=v end
    out.path={}
    for i,p in ipairs(row.path)do
      if type(p)=='string'then
        local c=centers[p];if not c then return nil,'unknown location '..p end
        out.path[i]={x=c.x,y=c.y}
      elseif validatePoint(p)then out.path[i]=p
      else return nil end
    end
    return out
  end
  return nil
end

function M.load(read)
  local raw=readData(read);local self=setmetatable({maps={},warnings={}},Resolver)
  local centers=readCenters(read)
  for mapId,row in pairs(raw.maps or {})do
    local normalized,reason=normalizeRow(mapId,row,centers)
    if normalized then self.maps[mapId]=normalized
    else self.warnings[#self.warnings+1]='Ignored invalid takeoff mapping '..tostring(mapId)..(reason and(' ('..reason..')')or'')end
  end
  return self
end

function Resolver:has(mapId)return self.maps[mapId]~=nil end

local function normalizedCell(value,blocks)
  local last=math.max(1,(tonumber(blocks)or 1)*2-1)
  return clamp((tonumber(value)or 0)/last,0,1)
end

local function pointXY(p)return p.x or p[1],p.y or p[2]end

local function pathPoint(path,t)
  local lengths,total={},0
  for i=1,#path-1 do
    local x1,y1=pointXY(path[i]);local x2,y2=pointXY(path[i+1])
    local length=math.sqrt((x2-x1)^2+(y2-y1)^2);lengths[i]=length;total=total+length
  end
  local target=t*total;local used=0
  for i,length in ipairs(lengths)do
    if target<=used+length or i==#lengths then
      local x1,y1=pointXY(path[i]);local x2,y2=pointXY(path[i+1])
      local u=length>0 and clamp((target-used)/length,0,1)or 0
      return x1+(x2-x1)*u,y1+(y2-y1)*u,x2-x1,y2-y1
    end
    used=used+length
  end
  local x,y=pointXY(path[#path]);return x,y,1,0
end

function Resolver:resolve(origin,mapDef)
  if not origin then return nil,'NO ORIGIN'end
  local row=self.maps[origin.mapId];if not row then return nil,'UNMAPPED OUTDOOR MAP '..tostring(origin.mapId)end
  local nx=normalizedCell(origin.x,mapDef and mapDef.width)
  local ny=normalizedCell(origin.y,mapDef and mapDef.height)
  local x,y,tx,ty
  if row.point then
    x,y=pointXY(row.point);local spread=row.spread or {}
    x=x+(nx-.5)*(spread.x or spread[1]or 0);y=y+(ny-.5)*(spread.y or spread[2]or 0)
  else
    local t=row.axis=='x'and nx or ny
    if row.reverse then t=1-t end
    x,y,tx,ty=pathPoint(row.path,t)
    local cross=(row.axis=='x'and ny or nx)-.5
    local length=math.sqrt(tx*tx+ty*ty)
    if length>0 then x=x-ty/length*cross*(row.cross or 0);y=y+tx/length*cross*(row.cross or 0)end
  end
  return {x=x,y=y,heading=facingHeading[origin.facing]or(tx and math.atan2(ty,tx))or-math.pi/2,mapId=origin.mapId}
end

return M
