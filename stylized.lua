-- Data-driven authoring scene. Coordinates in image pixels; z in world units.
local M={}
function M.objectKey(o) return o.name or o._source_ref or o._editorKey or tostring(o) end
function M.archetype(w,o)
  local instance=w.buildings and w.buildings.instances[o.name]
  return o.archetype or (instance and instance.archetype) or (w.buildings and w.buildings.type_models and w.buildings.type_models[o.type]),instance
end
function M.anchor(w,o)
  local _,instance=M.archetype(w,o)
  local offset=o.model_offset or (not o.archetype and instance and instance.offset) or {0,0}
  local x,y=(o.x+offset[1])*w.config.world_scale,(o.y+offset[2])*w.config.world_scale
  local z=o.z_mode=='free' and (o.z or 0) or (w:getGroundHeight(x,y)+(o.z or 0))
  return x,y,z
end
M.codes={{20,40,80},{120,180,80},{30,100,45},{130,120,110},{230,210,130},{190,110,100},{210,180,140}}
-- Fallback Game Boy-inspired palette; the native renderer uses world palettes
-- and imported texture motifs for the current scene.
M.palette={{.07,.14,.15},{.14,.27,.18},{.33,.47,.25},{.57,.67,.34},{.82,.87,.56},{.43,.32,.22},{.14,.28,.31},{.82,.22,.18},{.18,.36,.78}}
local function clamp(x,a,b) return math.max(a,math.min(b,x)) end
local function data(s,name)
  -- Load mod-owned Lua definitions through the engine's loadstring API.
  local f=assert(loadstring(assert(s,'Missing '..name),'@'..name))
  return assert(f(),'Empty '..name)
end
function M.load(read)
  local paletteText=read('world/palette.lua')
  local w={config=data(read('world/config.lua'),'config'),objects=data(read('world/kanto_objects.lua'),'objects'),props=data(read('world/props.lua'),'props'),palette=paletteText and data(paletteText,'palette') or M.palette}
  local landmarksText=read('world/landmarks.lua')
  w.landmarks=landmarksText and data(landmarksText,'landmarks') or {}
  local ridgesText=read('world/mountain_ridges.lua')
  w.mountainRidges=ridgesText and data(ridgesText,'mountain_ridges') or {}
  local valleysText=read('world/river_valleys.lua')
  w.riverValleys=valleysText and data(valleysText,'river_valleys') or {}
  local function png(path) return love.image.newImageData(love.filesystem.newFileData(assert(read(path),'Missing '..path),path)) end
  w.height=png('world/kanto_height.png');w.terrain=png('world/kanto_terrain.png')
  w.width,w.depth=w.height:getDimensions();local tw,th=w.terrain:getDimensions()
  assert(tw==w.width and th==w.depth,'PNG dimensions differ');assert(w.width>=2 and w.depth>=2 and w.width<=512 and w.depth<=512,'PNG size must be 2..512')
  w.bridgeSegment=data(read('bridge_segment.lua'),'bridge_segment')
  w.art=data(read('world/art.lua'),'art')
  w.soaringPalettes=data(read('world/soaring_palettes.lua'),'soaring_palettes')
  w.soaringPalettes.apply(w,w.config.soaring_palette)
  w.backdrop=data(read('backdrop.lua'),'backdrop')
  w.readAsset=read
  local buildings=read('generated/buildings.lua')
  if buildings then w.buildings=data(buildings,'buildings');w.readAsset=read end
  local vegetation=read('generated/vegetation.lua')
  if vegetation then
    w.generatedVegetation=data(vegetation,'vegetation')
    assert(type(w.generatedVegetation)=='table','generated/vegetation.lua must return a table')
  else w.generatedVegetation={} end
  local details=read('generated/details.lua')
  if details then
    w.generatedDetails=data(details,'details')
    assert(type(w.generatedDetails)=='table','generated/details.lua must return a table')
  else w.generatedDetails={} end
  -- Authored overrides retain generated source data and stable source indices.
  local overridden={}
  for _,o in ipairs(w.objects) do if o.source_ref then overridden[o.source_ref]=true end end
  for _,entry in ipairs({{'vegetation',w.generatedVegetation},{'details',w.generatedDetails}}) do
    local filtered={}
    for i,o in ipairs(entry[2]) do
      o._source_ref=entry[1]..':'..i
      if not overridden[o._source_ref] then filtered[#filtered+1]=o end
    end
    if entry[1]=='vegetation' then w.generatedVegetation=filtered else w.generatedDetails=filtered end
  end
  local c=w.config
  assert(type(w.art.render_scale)=='number' and w.art.render_scale>=1 and w.art.render_scale<=4,'art.render_scale must be 1..4')
  assert(type(w.art.texture_scale)=='number' and w.art.texture_scale>=1 and w.art.texture_scale<=4,'art.texture_scale must be 1..4')
  assert(type(w.art.lod_pixels)=='table' and #w.art.lod_pixels==7,'art.lod_pixels must contain seven values')
  assert(type(w.art.camera_modes)=='table' and w.art.camera_modes.CHASE and w.art.camera_modes.HIGH_SOAR,'art.camera_modes must define CHASE and HIGH_SOAR')
  for name,cam in pairs(w.art.camera_modes) do
    for _,key in ipairs({'pitch','fov','back','above','look_ahead','far'}) do assert(type(cam[key])=='number',name..'.'..key..' must be numeric') end
    assert(cam.flight_sprite_size==nil or (type(cam.flight_sprite_size)=='number' and cam.flight_sprite_size>=16 and cam.flight_sprite_size<=48),name..'.flight_sprite_size must be 16..48')
    assert(cam.pitch>=15 and cam.pitch<=40 and cam.fov>=35 and cam.fov<=75 and cam.far>0,'Invalid perspective camera '..name)
  end
  c.world_scale=c.world_scale or c.terrain_scale
  c.terrain_scale=c.world_scale
  c.terrain_height_scale=c.terrain_height_scale or 1
  c.mountain_height_scale=c.mountain_height_scale or 1
  c.mountain_height_levels=c.mountain_height_levels or c.height_levels
  c.mountain_ridge_power=c.mountain_ridge_power or 1
  c.prop_scale=c.prop_scale or 1
  c.camera_distance=c.camera_distance or 90
  c.flight_turn_speed=c.flight_turn_speed or 1.85
  c.flight_reverse_scale=c.flight_reverse_scale or .65
  c.flight_climb_speed=c.flight_climb_speed or 160
  c.flight_camera_follow=c.flight_camera_follow or 8
  c.flight_camera_turn_follow=c.flight_camera_turn_follow or 5
  c.flight_max_dt=c.flight_max_dt or .05
  if c.flight_terrain_clearance==nil then c.flight_terrain_clearance=30 end
  for _,k in ipairs({'world_scale','terrain_height_scale','mountain_height_scale','mountain_height_levels','mountain_ridge_power','max_height','height_levels','extrusion','city_scale','prop_scale','flight_speed','flight_turn_speed','flight_reverse_scale','camera_altitude','camera_distance','flight_min_altitude','flight_max_altitude','draw_distance','fade_distance','tree_density','sea_level','water_height','terrain_detail_density','water_detail_density','road_detail_density','distance_fade_strength'}) do assert(type(c[k])=='number' and c[k]==c[k],k..' must be numeric') end
  assert(type(c.material_tiles)=='table','material_tiles must be a table')
  assert(c.world_scale>0 and c.terrain_height_scale>=0 and c.mountain_height_scale>=1 and c.mountain_height_levels>=2 and c.mountain_height_levels<=256 and c.mountain_ridge_power>=1 and c.height_levels>=2 and c.height_levels<=256 and c.max_height>=0 and c.extrusion>=0,'Invalid terrain settings')
  assert(c.draw_distance>c.fade_distance and c.fade_distance>=0 and c.tree_density>=0 and c.tree_density<=1 and c.road_detail_density>=0 and c.road_detail_density<=1 and c.distance_fade_strength>=0 and c.distance_fade_strength<=1,'Invalid fade/density settings')
  assert(c.flight_turn_speed>0 and c.flight_reverse_scale>0 and c.flight_reverse_scale<=1,'Invalid relative flight controls')
  for _,k in ipairs({'flight_climb_speed','flight_camera_follow','flight_camera_turn_follow','flight_max_dt','flight_terrain_clearance'}) do assert(type(c[k])=='number' and c[k]==c[k],k..' must be numeric') end
  assert(c.flight_climb_speed>0 and c.flight_camera_follow>0 and c.flight_camera_turn_follow>0 and c.flight_max_dt>0 and c.flight_terrain_clearance>=0,'Invalid flight handling constants')
  assert(c.sea_level>=0 and c.sea_level<255,'sea_level must be 0..254')
  for i,v in ipairs(w.palette) do assert(type(v)=='table' and #v==3 and type(v[1])=='number' and type(v[2])=='number' and type(v[3])=='number','Invalid palette color '..i) end
  for _,list in ipairs({w.objects,w.generatedVegetation,w.generatedDetails}) do
    for _,o in ipairs(list) do assert(w.props[o.type],'Unknown prop '..tostring(o.type));for _,k in ipairs({'x','y'}) do assert(type(o[k])=='number','Object missing '..k) end end
  end
  for i,o in ipairs(w.landmarks) do
    assert(type(o)=='table' and type(o.type)=='string','Landmark '..i..' missing type')
    assert(o.type=='raised_road','Unknown landmark type '..tostring(o.type))
    assert(type(o.points)=='table' and #o.points>=2,'Landmark '..i..' needs at least two points')
    assert(type(o.width)=='number' and o.width>0 and type(o.rise)=='number','Invalid landmark dimensions at '..i)
    for j,p in ipairs(o.points) do assert(type(p)=='table' and type(p[1])=='number' and type(p[2])=='number','Invalid landmark point '..i..':'..j) end
  end
  for i,r in ipairs(w.mountainRidges) do
    assert(type(r.points)=='table' and #r.points>=2 and type(r.width)=='number' and r.width>0 and type(r.height)=='number' and r.height>=0,'Invalid mountain ridge '..i)
  end
  for i,v in ipairs(w.riverValleys) do
    assert(type(v.points)=='table' and #v.points>=2 and type(v.width)=='number' and v.width>0,'Invalid river valley '..i)
    assert(type(v.floor)=='number' and v.floor>=0 and type(v.rise)=='number' and v.rise>0,'Invalid river valley profile '..i)
    v.channel=v.channel or 0
  end
  function w:biome(x,y)
    local r,g,b=self.terrain:getPixel(clamp(math.floor(x),0,self.width-1),clamp(math.floor(y),0,self.depth-1));local best,dist=1,math.huge
    for i,v in ipairs(M.codes) do local d=(r*255-v[1])^2+(g*255-v[2])^2+(b*255-v[3])^2;if d<dist then best,dist=i,d end end
    return best
  end
  function w:ridgeHeight(x,y)
    local uplift=0
    for _,rdef in ipairs(self.mountainRidges) do
      for i=1,#rdef.points-1 do
        local a,b=rdef.points[i],rdef.points[i+1];local dx,dy=b[1]-a[1],b[2]-a[2]
        local t=clamp(((x-a[1])*dx+(y-a[2])*dy)/math.max(.001,dx*dx+dy*dy),0,1)
        local qx,qy=a[1]+dx*t,a[2]+dy*t;local dist=math.sqrt((x-qx)^2+(y-qy)^2)
        -- A wide smooth foothill profile begins well outside the brown biome;
        -- a narrower quadratic crest keeps the actual ridge readable.
        local outer=rdef.width*2.2
        local ft=clamp(1-dist/outer,0,1);local smooth=ft*ft*(3-2*ft)
        local ct=clamp(1-dist/rdef.width,0,1)
        uplift=math.max(uplift,rdef.height*(.62*smooth+.38*ct*ct))
      end
    end
    -- Keep the silhouette stepped and batch-friendly instead of emitting a
    -- unique wall height at every pixel of a mathematically smooth slope.
    return math.floor(uplift/6+.5)*6
  end
  function w:valleyCap(x,y)
    local cap=nil
    for _,vdef in ipairs(self.riverValleys) do
      local best=math.huge
      for i=1,#vdef.points-1 do
        local a,b=vdef.points[i],vdef.points[i+1];local dx,dy=b[1]-a[1],b[2]-a[2]
        local t=clamp(((x-a[1])*dx+(y-a[2])*dy)/math.max(.001,dx*dx+dy*dy),0,1)
        local qx,qy=a[1]+dx*t,a[2]+dy*t;best=math.min(best,math.sqrt((x-qx)^2+(y-qy)^2))
      end
      if best<=vdef.width then
        local h=vdef.floor+math.max(0,best-(vdef.channel or 0))*vdef.rise
        h=math.floor(h/6+.5)*6
        cap=cap and math.min(cap,h) or h
      end
    end
    return cap
  end
  -- v/base replicate the same quantised heightmap->world-unit mapping for both
  -- land and inland water, so a flat patch of kanto_height.png always produces
  -- a flat surface regardless of which biome is painted over it.
  local function baseHeight(r)
    local v=clamp((r*255-c.sea_level)/(255-c.sea_level),0,1)
    return c.water_height+math.floor(v*(c.height_levels-1)+.5)/(c.height_levels-1)*c.max_height*c.extrusion*c.terrain_height_scale
  end
  function w:ground(x,y)
    x,y=clamp(math.floor(x),0,self.width-1),clamp(math.floor(y),0,self.depth-1)
    local r=self.height:getPixel(x,y)
    -- Ocean/open sea: any pixel at or below sea_level is the single flat
    -- global sea level, exactly as before, regardless of painted biome.
    if r*255<=c.sea_level then return c.water_height end
    if self:biome(x,y)==1 then
      -- Inland water (a lake, pond or river painted above sea_level): sits at
      -- the elevation authored in kanto_height.png, using the same
      -- quantisation as land, so it reads as one flat plane wherever the
      -- heightmap under it is flat. It deliberately skips ridgeHeight and
      -- valleyCap: mountain-ridge uplift and river-valley carving are land-only
      -- effects and must never deform the water surface itself.
      return baseHeight(r)
    end
    -- Surface colour and elevation are deliberately independent. Earlier
    -- builds lifted every brown mountain-material cell, turning its hard
    -- texture boundary into a vertical mesa wall. The authored ridge profile
    -- below already supplies broad foothills and a narrow crest, while the
    -- source heightmap supplies the underlying regional slope.
    local base=baseHeight(r)
    local ground=base+self:ridgeHeight(x,y)
    local valleyCap=self:valleyCap(x,y)
    if valleyCap then ground=math.min(ground,valleyCap) end
    return ground
  end
  w.minX=0;w.minY=0;w.maxX=w.width*c.world_scale;w.maxY=w.depth*c.world_scale
  w.byId={PALLET_TOWN={x=w.maxX*.5,y=w.maxY*.8,width=1,height=1}}
  for _,o in ipairs(w.objects) do if o.name=='OAK_LAB' then w.byId.PALLET_TOWN.x=o.x*c.world_scale;w.byId.PALLET_TOWN.y=o.y*c.world_scale end end
  function w:getGroundHeight(x,y) return self:ground(x/c.world_scale,y/c.world_scale) end
  return w
end
function M.encode(objects)
  local lines={'return {'}
  for _,o in ipairs(objects) do
    local fields={};for _,k in ipairs({'type','name','x','y','z','scale','rotation','radius','density','treeType','seed','city','archetype','z_mode','source_ref','hidden'}) do
      local v=o[k];if v~=nil then fields[#fields+1]=k..'='..(type(v)=='string' and string.format('%q',v) or tostring(v)) end
    end
    lines[#lines+1]='  {'..table.concat(fields,',')..'},'
  end
  lines[#lines+1]='}';return table.concat(lines,'\n')..'\n'
end
function M.project(x,y,z,c) c=c or {shear=.18,slope=.14,depth=.82};return x-c.shear*y,c.slope*x+c.depth*y-z end
function M.build(w,gameTileset,replacePallet,opts)
  local faces={};local c=w.config;local s=c.world_scale
  opts=opts or {}
  local yieldBuild=opts.yieldBuild
  local buildWork=0
  local function buildCheckpoint(amount)
    if not yieldBuild then return end
    buildWork=buildWork+(amount or 1)
    if buildWork>=500 then buildWork=0;yieldBuild() end
  end
  -- Build-local memoization of terrain lookups. The World Editor mutates w.height /
  -- w.terrain in memory between builds, so nothing is cached on `w`: these tables
  -- exist only for this call and are dropped when it returns, and w:ground /
  -- w:biome / w:getGroundHeight themselves stay uncached. Keys are the same
  -- clamped integer cell that w:ground / w:biome floor to, so results are identical.
  local groundCache,biomeCache={},{}
  local function ground(x,y)
    x,y=clamp(math.floor(x),0,w.width-1),clamp(math.floor(y),0,w.depth-1)
    local key=y*w.width+x;local z=groundCache[key]
    if z==nil then z=w:ground(x,y);groundCache[key]=z end
    return z
  end
  local function biome(x,y)
    x,y=clamp(math.floor(x),0,w.width-1),clamp(math.floor(y),0,w.depth-1)
    local key=y*w.width+x;local v=biomeCache[key]
    if v==nil then v=w:biome(x,y);biomeCache[key]=v end
    return v
  end
  local function groundAtWorld(x,y) return ground(x/c.world_scale,y/c.world_scale) end
  local function face(points,col,depth,cx,cy)
    local f={points=points,col=col,depth=depth,cx=cx,cy=cy};faces[#faces+1]=f;return f
  end
  local function quad(x,y,sz,z,col,biome)
    local f=face({{x,y,z},{x+sz,y,z},{x+sz,y+sz,z},{x,y+sz,z}},col,y+.5*sz+.5*(x+.5*sz),x,y);f.biome=biome;return f
  end
  local bounds=opts.bounds or {0,0,w.width-1,w.depth-1}
  if not opts.objectsOnly then
  for y=bounds[2],bounds[4] do for x=bounds[1],bounds[3] do
    local z=ground(x,y);local b=biome(x,y);local col=({1,3,2,6,5,4,5})[b]
    local tile=({c.material_tiles.water,c.material_tiles.grass,c.material_tiles.forest,c.material_tiles.mountain,c.material_tiles.sand,c.material_tiles.city,c.material_tiles.road})[b]
    local f=quad(x*s,y*s,s,z,col,b);f.tile=tile
    f.textured=true;f.motif=w.art.terrain[b];f.terrainCell={x,y}
    -- Close every terrain height discontinuity. 0.6.1 only emitted the
    -- south/east wall when *this* cell was the higher one, so a higher
    -- neighbour left a literal gap. Generate one wall per shared edge using
    -- the higher and lower heights regardless of which side owns the cell.
    local function terrainWall(points,shade)
      local wf=face(points,6,(y+.5)*s+.5*(x+.5)*s,x*s,y*s)
      wf.tile=c.material_tiles.cliff;wf.textured=true;wf.shade=shade;wf.terrainCell={x,y}
    end
    local nz=y==w.depth-1 and c.water_height or ground(x,y+1)
    if math.abs(z-nz)>.001 then
      local hi,lo=math.max(z,nz),math.min(z,nz)
      terrainWall({{x*s,(y+1)*s,hi},{(x+1)*s,(y+1)*s,hi},{(x+1)*s,(y+1)*s,lo},{x*s,(y+1)*s,lo}},.66)
    end
    nz=x==w.width-1 and c.water_height or ground(x+1,y)
    if math.abs(z-nz)>.001 then
      local hi,lo=math.max(z,nz),math.min(z,nz)
      terrainWall({{(x+1)*s,y*s,hi},{(x+1)*s,(y+1)*s,hi},{(x+1)*s,(y+1)*s,lo},{(x+1)*s,y*s,lo}},.42)
    end
    -- The outer north/west borders do not have a neighbour cell that can
    -- contribute their wall, so close those two edges explicitly as well.
    if y==0 and not (c.backdrop_enabled and c.backdrop_north) and math.abs(z-c.water_height)>.001 then
      local hi,lo=math.max(z,c.water_height),math.min(z,c.water_height)
      terrainWall({{x*s,y*s,hi},{(x+1)*s,y*s,hi},{(x+1)*s,y*s,lo},{x*s,y*s,lo}},.72)
    end
    if x==0 and not (c.backdrop_enabled and c.backdrop_west) and math.abs(z-c.water_height)>.001 then
      local hi,lo=math.max(z,c.water_height),math.min(z,c.water_height)
      terrainWall({{x*s,y*s,hi},{x*s,(y+1)*s,hi},{x*s,(y+1)*s,lo},{x*s,y*s,lo}},.52)
    end
    if yieldBuild then buildCheckpoint(1) end
  end end

  end -- terrain
  if not opts.terrainOnly then

  -- Visual-only continuation owns shared seams and flat water tops.
  if not opts.objectsOnly and c.backdrop_enabled then
    w.backdrop.build(w,ground,biome,face,yieldBuild)
  end

  local function box(x,y,z,a,b,h,rotation,style)
    local angle=math.rad(rotation or 0);local co,si=math.cos(angle),math.sin(angle)
    local function p(dx,dy,dz) return {x+dx*co-dy*si,y+dx*si+dy*co,z+dz} end
    local bottom={p(-a/2,-b/2,0),p(a/2,-b/2,0),p(a/2,b/2,0),p(-a/2,b/2,0)}
    local top={p(-a/2,-b/2,h),p(a/2,-b/2,h),p(a/2,b/2,h),p(-a/2,b/2,h)}
    for i=1,4 do local j=i%4+1;local dx,dy=bottom[j][1]-bottom[i][1],bottom[j][2]-bottom[i][2]
      if dy*.18-dx>0 then local cx,cy=(bottom[i][1]+bottom[j][1])/2,(bottom[i][2]+bottom[j][2])/2;local f=face({top[i],top[j],bottom[j],bottom[i]},i%2==0 and (style.sideA or 1) or (style.sideB or 2),cy+.5*cx+.001,x,y);f.tile=style.wallTile or c.material_tiles.cliff;f.textured=style.wallTile~=nil;f.shade=.66 end
    end
    local f=face(top,style.top or 4,y+.5*x+.002,x,y);f.tile=style.topTile or c.material_tiles.city;f.textured=style.topTile~=nil
  end
  local function patch(points,motif,col,x,y)
    local f=face(points,col,y+.5*x+.01,x,y);f.motif=motif;f.textured=true
  end
  local function landmark(x,y,z,d,sc,rotation)
    local u=w.art.unit
    local a=math.max(u,math.floor(d.w/u+.5)*u)*sc*s
    local b=math.max(u,math.floor(d.d/u+.5)*u)*sc*s
    local h=d.h*sc*w.art.relief_scale
    local angle=math.rad(rotation);local co,si=math.cos(angle),math.sin(angle)
    local function p(dx,dy,dz)return {x*s+dx*co-dy*si,y*s+dx*si+dy*co,z+dz}end
    box(x*s,y*s,z,a,b,h,rotation,{top=d.top,sideA=6,sideB=5})
    patch({p(-a/2,-b/2,h+.02),p(a/2,-b/2,h+.02),p(a/2,b/2,h+.02),p(-a/2,b/2,h+.02)},w.art.roofs[d.kind],d.top,x*s,y*s)
    patch({p(-a/2,b/2+.02,h),p(a/2,b/2+.02,h),p(a/2,b/2+.02,0),p(-a/2,b/2+.02,0)},w.art.facade,5,x*s,y*s)
    if d.kind=='center' or d.kind=='gym' or d.kind=='mart' then
      local tile=d.kind=='gym' and 47 or (d.kind=='center' and 33 or 66)
      patch({p(-a*.14,b/2+.04,h*.80),p(a*.14,b/2+.04,h*.80),p(a*.14,b/2+.04,h*.28),p(-a*.14,b/2+.04,h*.28)},{cols=1,tiles={tile}},5,x*s,y*s)
    end
  end
  -- Full 360-degree tree geometry for the chase camera. Buildings are authored
  -- as closed meshes in Python; vegetation uses a lightweight runtime primitive
  -- so single trees, small groups and generated forests share one visual language.
  local function closedBox(x,y,z,a,b,h,rotation,style)
    local angle=math.rad(rotation or 0);local co,si=math.cos(angle),math.sin(angle)
    local function p(dx,dy,dz) return {x+dx*co-dy*si,y+dx*si+dy*co,z+dz} end
    local bottom={p(-a/2,-b/2,0),p(a/2,-b/2,0),p(a/2,b/2,0),p(-a/2,b/2,0)}
    local top={p(-a/2,-b/2,h),p(a/2,-b/2,h),p(a/2,b/2,h),p(-a/2,b/2,h)}
    for i=1,4 do
      local j=i%4+1
      local f=face({top[i],top[j],bottom[j],bottom[i]},i%2==0 and (style.sideA or 1) or (style.sideB or 2),y+.5*x+.003,x,y)
      f.tile=style.wallTile or c.material_tiles.cliff;f.textured=style.wallTile~=nil;f.shade=style.shade or .72
    end
    local f=face(top,style.top or 4,y+.5*x+.004,x,y)
    f.tile=style.topTile or c.material_tiles.city;f.textured=style.topTile~=nil;f.shade=style.topShade or 1
  end
  local function treeIcon(x,y,z,d,sc,rotation)
    local a=(d.w or 3)*sc*s;local b=(d.d or d.w or 3)*sc*s
    local h=(d.h or 12)*sc
    local pine=d.kind=='tree_pine'
    local trunkH=h*(pine and .34 or .42)
    local trunkW=math.max(1.5,a*(pine and .12 or .16))
    closedBox(x*s,y*s,z,trunkW,trunkW,trunkH,rotation,{top=6,sideA=6,sideB=6,shade=.78})
    local crownBottom=z+h*(pine and .20 or .30)
    if pine then
      -- Narrow tapered boughs form a conifer silhouette instead of box tiers.
      local tiers={{1.00,.23},{.78,.22},{.57,.21},{.38,.19},{.20,.17}}
      local angle=math.rad(rotation or 0);local co,si=math.cos(angle),math.sin(angle)
      local function p(dx,dy,zz)return {x*s+dx*co-dy*si,y*s+dx*si+dy*co,zz}end
      local zz=crownBottom
      for i,t in ipairs(tiers) do
        local ch=h*t[2];local aa,bb=a*t[1],b*t[1]
        local tip=i==#tiers and .035 or .60
        local bottom={p(-aa/2,-bb/2,zz),p(aa/2,-bb/2,zz),p(aa/2,bb/2,zz),p(-aa/2,bb/2,zz)}
        local top={p(-aa*tip/2,-bb*tip/2,zz+ch),p(aa*tip/2,-bb*tip/2,zz+ch),p(aa*tip/2,bb*tip/2,zz+ch),p(-aa*tip/2,bb*tip/2,zz+ch)}
        for j=1,4 do local k=j%4+1
          local f=face({top[j],top[k],bottom[k],bottom[j]},2,y*s+.5*x*s+.003,x*s,y*s)
          f.tile=64;f.textured=true;f.shade=.57
        end
        local f=face(top,2,y*s+.5*x*s+.004,x*s,y*s)
        f.tile=80;f.textured=true;f.shade=.74
        zz=zz+ch*.74
      end
    else
      -- Broadleaf crowns deliberately overlap into a chunky toy-like canopy.
      local layers={{.84,.23,-.04},{1.00,.28,0},{.68,.26,.04}}
      local zz=crownBottom
      for _,t in ipairs(layers) do
        local ch=h*t[2]
        closedBox(x*s,y*s,zz,a*t[1],b*t[1],ch,rotation,{top=2,sideA=2,sideB=2,topTile=80,wallTile=64,shade=.82,topShade=1})
        zz=zz+ch*.68
      end
    end
  end
  local function prop(o)
    if o.hidden then return end
    if replacePallet and M.archetype(w,o) then return end
    local first=#faces+1
    local def=w.props[o.type];local sc=(o.scale or 1)*c.prop_scale*((o.city or o.type=='city' or o.type=='pallet') and c.city_scale or 1);local rot=math.rad(o.rotation or 0)
    local function part(p)
      local dx,dy=(p.x or 0)*sc,(p.y or 0)*sc;local x=o.x+dx*math.cos(rot)-dy*math.sin(rot);local y=o.y+dx*math.sin(rot)+dy*math.cos(rot)
      local partType=p.type or o.type;local d=w.props[partType];local psc=sc*(p.scale or 1);local z=(o.z_mode=='free' and (o.z or 0) or ground(x,y)+(o.z or 0))+(p.z or 0)*sc
      if d.kind=='tree_broadleaf' or d.kind=='tree_pine' then treeIcon(x,y,z,d,psc,(o.rotation or 0)+(p.rotation or 0))
      elseif d.kind=='bridge_segment' then w.bridgeSegment.build(face,x,y,z,d,psc,s,(o.rotation or 0)+(p.rotation or 0))
      elseif d.kind then landmark(x,y,z,d,psc,(o.rotation or 0)+(p.rotation or 0))
      else
        box(x*s,y*s,z,d.w*psc*s,d.d*psc*s,d.h*psc,(o.rotation or 0)+(p.rotation or 0),d)
        if partType=='rock' or partType=='rock_single' or partType=='mountain_peak' then
          local a,b=d.w*psc*s/2,d.d*psc*s/2;patch({{x*s-a,y*s-b,z+d.h*psc+.05},{x*s+a,y*s-b,z+d.h*psc+.05},{x*s+a,y*s+b,z+d.h*psc+.05},{x*s-a,y*s+b,z+d.h*psc+.05}},w.art.rock,6,x*s,y*s)
        end
      end
    end
    if def.parts then for _,p in ipairs(def.parts) do part(p) end
    elseif o.type=='tree_cluster' or o.type=='forest_cluster' then
      local radius=o.radius or 8
      local spacing=math.max(4,math.floor(6/math.sqrt(math.max(.05,o.density or c.tree_density))))
      local treeType=o.treeType or (o.type=='forest_cluster' and 'forest_tree' or 'tree_single')
      for dy=-radius,radius,spacing do for dx=-radius,radius,spacing do
        if dx*dx+dy*dy<=radius*radius then part({type=treeType,x=dx,y=dy}) end
      end end
    else part({}) end
    local category=(o.type:find('tree') or o.type:find('forest')) and 'vegetation' or ((o.type:find('rock') or o.type=='cave') and 'details' or 'buildings')
    for i=first,#faces do
      faces[i].category=category;faces[i].objectKey=M.objectKey(o)
      if yieldBuild then buildCheckpoint(1) end
    end
  end
  local function raisedRoad(o)
    local half=o.width*.5*s;local normals,lengths={},{ };local left,right,zs,barriers,supports={},{},{},{},{}
    -- Densify long authored spans. This lets the road follow map-height steps
    -- in short sections instead of stretching one face through whole cliffs.
    local points,along={{o.points[1][1],o.points[1][2]}},{0};local totalLength=0
    for i=1,#o.points-1 do
      local a,b=o.points[i],o.points[i+1];local dx,dy=b[1]-a[1],b[2]-a[2];local len=math.sqrt(dx*dx+dy*dy)
      assert(len>0,'Zero-length landmark segment '..o.name)
      local pieces=math.max(1,math.ceil(len/.5))
      for j=1,pieces do
        local t=j/pieces;local p={a[1]+dx*t,a[2]+dy*t}
        local prev=points[#points];local ddx,ddy=p[1]-prev[1],p[2]-prev[2]
        totalLength=totalLength+math.sqrt(ddx*ddx+ddy*ddy)*s
        points[#points+1]=p;along[#along+1]=totalLength
      end
    end
    for i=1,#points-1 do
      local a,b=points[i],points[i+1];local dx,dy=b[1]-a[1],b[2]-a[2];local len=math.sqrt(dx*dx+dy*dy)
      normals[i]={-dy/len,dx/len};lengths[i]=len*s
    end
    -- Mitered shared vertices turn the densified polyline into one ribbon.
    for i,p in ipairs(points) do
      local nx,ny,scale
      if i==1 then nx,ny,scale=normals[1][1],normals[1][2],half
      elseif i==#points then nx,ny,scale=normals[#normals][1],normals[#normals][2],half
      else
        nx,ny=normals[i-1][1]+normals[i][1],normals[i-1][2]+normals[i][2]
        local nl=math.sqrt(nx*nx+ny*ny);nx,ny=nx/nl,ny/nl
        scale=math.min(half*1.8,half/math.max(.35,nx*normals[i][1]+ny*normals[i][2]))
      end
      local lx,ly=p[1]*s+nx*scale,p[2]*s+ny*scale
      local rx,ry=p[1]*s-nx*scale,p[2]*s-ny*scale
      -- Sample the full width, not only its centerline. Heightmap cells are
      -- stepped; dense lateral samples keep either deck edge above the shore.
      local support=c.water_height
      for j=0,8 do local v=j/8;support=math.max(support,ground((lx+(rx-lx)*v)/s,(ly+(ry-ly)*v)/s)) end
      supports[i]=support
      left[i]={lx,ly,0};right[i]={rx,ry,0}
    end
    -- Each short ribbon section is lifted above every terrain sample beneath
    -- it. The approach ramp additionally reaches the Fuchsia shore before the
    -- last abrupt height step; it no longer asks one long face to bridge it.
    local landingLength=(o.landing_length or 0)*s
    local landingFinish=clamp(o.landing_finish_fraction or .82,.2,1)
    local endRise=o.end_rise or 0
    local landingDeck=supports[#points]+endRise
    local approachDeck=c.water_height+o.rise
    local function rampAt(distance,support)
      local remaining=totalLength-distance
      if landingLength>0 and remaining<landingLength then
        local progress=clamp((1-remaining/landingLength)/landingFinish,0,1)
        local eased=progress*progress*(3-2*progress)
        return math.max(support+endRise,approachDeck+(landingDeck-approachDeck)*eased),(o.barrier or 1)*(1-eased)
      end
      return support+o.rise,o.barrier or 1
    end
    local segmentDeck={}
    for i=1,#points-1 do
      local maxDeck=c.water_height
      for ti=0,4 do
        local t=ti/4;local l=left[i];local r=right[i]
        local lx=l[1]+(left[i+1][1]-l[1])*t;local ly=l[2]+(left[i+1][2]-l[2])*t
        local rx=r[1]+(right[i+1][1]-r[1])*t;local ry=r[2]+(right[i+1][2]-r[2])*t
        for vi=0,8 do
          local v=vi/8;local wx=(lx+(rx-lx)*v)/s;local wy=(ly+(ry-ly)*v)/s
          local support=ground(wx,wy);local distance=along[i]+lengths[i]*t
          local deck=rampAt(distance,support);maxDeck=math.max(maxDeck,deck)
        end
      end
      segmentDeck[i]=maxDeck
    end
    for i=1,#points do
      local remaining=totalLength-along[i]
      local z,rail=rampAt(along[i],supports[i])
      if i>1 then z=math.max(z,segmentDeck[i-1]) end
      if i<#points then z=math.max(z,segmentDeck[i]) end
      if landingLength>0 and remaining<landingLength then
        local progress=clamp((1-remaining/landingLength)/landingFinish,0,1);local eased=progress*progress*(3-2*progress)
        rail=(o.barrier or 1)*(1-eased)
      end
      zs[i]=z;barriers[i]=rail;left[i][3]=z;right[i][3]=z
    end
    local function mix(a,b,t,zOffset)
      return {a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t,a[3]+(b[3]-a[3])*t+(zOffset or 0)}
    end
    local function surfacePoint(i,t,v,zOffset)
      return mix(mix(left[i],right[i],v),mix(left[i+1],right[i+1],v),t,zOffset)
    end
    local dashSpacing=8*s;local nextDash=dashSpacing
    for i=1,#points-1 do
      local a,b=points[i],points[i+1];local dx,dy=b[1]-a[1],b[2]-a[2];local len=math.sqrt(dx*dx+dy*dy)
      local cx,cy=(a[1]+b[1])*s*.5,(a[2]+b[2])*s*.5
      local depth=cy+.5*cx
      -- Match the ordinary Red road surface (biome 7 uses ramp 5) and keep
      -- the deck untextured: repeating a full 8x8 tile on every 0.5-cell
      -- section produced shimmer and apparent pinholes as the camera moved.
      local main=face({left[i],left[i+1],right[i+1],right[i]},5,depth,cx,cy)
      main.shade=1.0;main.landmark=o.name
      -- Narrow, continuous edge guides give the route a cycling-lane identity
      -- without the broad, high-contrast striped shoulders from the old pass.
      for _,band in ipairs({{.055,.082},{.918,.945}}) do
        local stripe=face({surfacePoint(i,0,band[1],.018),surfacePoint(i,1,band[1],.018),surfacePoint(i,1,band[2],.018),surfacePoint(i,0,band[2],.018)},4,depth+.001,cx,cy)
        stripe.shade=.96;stripe.landmark=o.name
      end
      -- A slim dashed center guide echoes the original Cycling Road markings.
      local halfDash=.52*s
      while nextDash<along[i+1]-halfDash do
        local d=nextDash-along[i]
        if d>halfDash then
          local t0=(d-halfDash)/lengths[i];local t1=(d+halfDash)/lengths[i]
          local mark=face({surfacePoint(i,t0,.486,.03),surfacePoint(i,t0,.514,.03),surfacePoint(i,t1,.514,.03),surfacePoint(i,t1,.486,.03)},4,depth+.003,cx,cy)
          mark.shade=.96
          mark.landmark=o.name
        end
        nextDash=nextDash+dashSpacing
      end
    end
    -- Slim paired bridge piers replace the continuous cliff-textured wall.
    -- Their spacing is authored in map cells; each rests on sampled terrain or
    -- the sea plane, so the road reads as a bridge instead of a solid slab.
    local spacing=(o.pier_spacing or 4.5)*s
    local pierWidth=o.pier_width or 1.25
    local distance=spacing*.5
    local seg=1
    while distance<totalLength-spacing*.25 do
      while seg<#points-1 and along[seg+1]<distance do seg=seg+1 end
      local t=clamp((distance-along[seg])/math.max(.001,lengths[seg]),0,1)
      local centerX=(points[seg][1]+(points[seg+1][1]-points[seg][1])*t)*s
      local centerY=(points[seg][2]+(points[seg+1][2]-points[seg][2])*t)*s
      local deckZ=zs[seg]+(zs[seg+1]-zs[seg])*t
      for _,sign in ipairs({-1,1}) do
        local px=centerX+normals[seg][1]*half*.68*sign
        local py=centerY+normals[seg][2]*half*.68*sign
        local base=groundAtWorld(px,py)
        local height=deckZ-base-.08 -- stop just below the deck; avoid a z-fighting cap
        if height>1.0 then
          local firstPillarFace=#faces+1
          closedBox(px,py,base,pierWidth,pierWidth,height,0,{top=5,sideA=6,sideB=6,shade=.78,topShade=.86})
          for fi=firstPillarFace,#faces do faces[fi].landmark=o.name;faces[fi].category='details' end
        end
      end
      distance=distance+spacing
    end
  end
  if not opts.objectsOnly then for _,o in ipairs(w.landmarks or {}) do if o.type=='raised_road' then raisedRoad(o) end end end
  if opts.objectList then for _,o in ipairs(opts.objectList) do prop(o) end
  else
    for _,o in ipairs(w.objects) do prop(o) end
    for _,o in ipairs(w.generatedVegetation or {}) do prop(o) end
    for _,o in ipairs(w.generatedDetails or {}) do prop(o) end
  end
  end -- static backdrop, landmarks and objects are not rebuilt for terrain chunks
  local expanded={}
  for _,f in ipairs(faces) do
    if f.motif and not f.worldPattern then
      local m=f.motif;local rows=math.ceil(#m.tiles/m.cols)
      if f.terrainCell then
        local period=w.art.pattern_cells
        local ux=(f.terrainCell[1]%period)/period*m.cols
        local uy=(f.terrainCell[2]%period)/period*rows
        f.tile=m.tiles[math.floor(uy)*m.cols+math.floor(ux)+1]
        f.uvCrop={ux%1,uy%1,m.cols/period,rows/period}
        expanded[#expanded+1]=f
        if yieldBuild then buildCheckpoint(1) end
      else
        local function point(u,v)
          local p={};for k=1,3 do p[k]=f.points[1][k]*(1-u)*(1-v)+f.points[2][k]*u*(1-v)+f.points[3][k]*u*v+f.points[4][k]*(1-u)*v end;return p
        end
        for y=0,rows-1 do for x=0,m.cols-1 do
          expanded[#expanded+1]={points={point(x/m.cols,y/rows),point((x+1)/m.cols,y/rows),point((x+1)/m.cols,(y+1)/rows),point(x/m.cols,(y+1)/rows)},col=f.col,depth=f.depth,cx=f.cx,cy=f.cy,tile=m.tiles[y*m.cols+x+1],textured=true,category=f.category,objectKey=f.objectKey,backdrop=f.backdrop,backdropDecoration=f.backdropDecoration,shade=f.backdrop and f.shade or nil}
          if yieldBuild then buildCheckpoint(1) end
        end end
      end
    else
      expanded[#expanded+1]=f
      if yieldBuild then buildCheckpoint(1) end
    end
  end
  faces=expanded
  if yieldBuild then
    -- Stable bottom-up merge sort lets the loading screen yield during the
    -- expensive depth ordering step instead of freezing on low-powered devices.
    local source,dest=faces,{}
    local width,n=1,#source
    while width<n do
      local first=1
      while first<=n do
        local left,mid,last=first,math.min(first+width,n+1),math.min(first+2*width,n+1)
        local i,j=left,mid
        for k=left,last-1 do
          if i<mid and (j>=last or source[i].depth<=source[j].depth) then dest[k]=source[i];i=i+1
          else dest[k]=source[j];j=j+1 end
          buildCheckpoint(1)
        end
        first=last
      end
      source,dest=dest,source;width=width*2
    end
    faces=source
  else
    table.sort(faces,function(a,b) return a.depth<b.depth end)
  end
  return faces
end
function M.renderer(w,getImage,gameTileset,gameFont)
  local quality=w.art.render_scale or 1
  local self={faces=M.build(w,gameTileset),world=w,font=love.graphics.newFont(8),quality=quality}
  self.canvas=love.graphics.newCanvas(160*quality,144*quality,{dpiscale=1})
  self.canvas:setFilter(w.art.smooth_downsample and 'linear' or 'nearest',w.art.smooth_downsample and 'linear' or 'nearest')
  self.depth=love.graphics.newCanvas(160*quality,144*quality,{format='depth24',readable=false,dpiscale=1})
  self.shader=love.graphics.newShader([[#ifdef VERTEX
    attribute float TerrainDepth;
    vec4 position(mat4 transform_projection, vec4 vertex_position) {
      vec4 p=transform_projection*vertex_position;p.z=TerrainDepth;return p;
    }
#endif
#ifdef PIXEL
    uniform vec3 Tone0;
    uniform vec3 Tone1;
    uniform vec3 Tone2;
    uniform vec3 Tone3;
    vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) {
      float v=Texel(tex,uv).r * color.r;
      vec3 tone=v>.83?Tone0:(v>.50?Tone1:(v>.17?Tone2:Tone3));
      return vec4(tone,1.0);
    }
#endif
]])
  if getImage and gameTileset and gameTileset.image then
    -- The engine-owned tileset record supplies the asset path. The mod never
    -- hardcodes or distributes a ROM-cache path; Assets resolves this through
    -- our assets_transforms-derived copy at runtime.
    local ok,image=pcall(getImage,gameTileset.image)
    if ok and image then
      local iw,ih=image:getDimensions()
      local tq=w.art.texture_scale or quality
      self.textureScale=tq
      self.textureWidth,self.textureHeight=iw*tq,(ih+1)*tq
      self.texture=love.graphics.newCanvas(self.textureWidth,self.textureHeight,{dpiscale=1})
      self.texture:setFilter('nearest','nearest')
      love.graphics.push('all');love.graphics.setCanvas(self.texture);love.graphics.origin();love.graphics.setColor(1,1,1,1);love.graphics.clear(0,0,0,0);love.graphics.draw(image,0,0,0,tq,tq);love.graphics.rectangle('fill',0,ih*tq,iw*tq,tq);love.graphics.pop()
      self.ownsTexture=true
    end
  end
  function self:release() if self.mesh then self.mesh:release() end;if self.ownsTexture then self.texture:release() end;self.font:release();self.canvas:release();self.depth:release();self.shader:release() end
  function self:draw(p,overview)
    local g=love.graphics;local c=w.config;local palette=w.palette or M.palette
    local mode=overview and 'DEBUG_TOP' or (p.cameraMode or 'CHASE')
    local perspective=mode~='DEBUG_TOP'
    local topView=overview or mode=='DEBUG_TOP'
    local scale,project,cx,cy,camCfg,horizonY
    local ground=w:getGroundHeight(p.x,p.y)
    local flyerZ=ground+p.altitude*.20
    if perspective then
      camCfg=w.art.camera_modes[mode] or w.art.camera_modes.CHASE
      local heading=p.cameraHeading or p.heading or -math.pi/2
      local fx,fy=math.cos(heading),math.sin(heading)
      local rx,ry=-fy,fx
      local pitch=math.rad(camCfg.pitch)
      local cp,sp=math.cos(pitch),math.sin(pitch)
      local focal=80/math.tan(math.rad(camCfg.fov)*.5)
      local camX=(p.cameraX or p.x)-fx*camCfg.back
      local camY=(p.cameraY or p.y)-fy*camCfg.back
      local camZ=flyerZ+camCfg.above
      horizonY=78-focal*math.tan(pitch)
      project=function(x,y,z)
        local dx,dy,dz=x-camX,y-camY,z-camZ
        local side=dx*rx+dy*ry
        local forward=dx*fx+dy*fy
        local depth=forward*cp-dz*sp
        local up=forward*sp+dz*cp
        if depth<=4 then return 0,0,depth,false end
        return 80+side*focal/depth,78-up*focal/depth,depth,true
      end
      scale=focal/math.max(4,camCfg.back)
    else
      scale=topView and math.min(148/(w.maxX+w.art.camera.shear*w.maxY),115/(w.maxY*w.art.camera.depth+w.maxX*w.art.camera.slope+c.max_height)) or c.camera_distance/math.max(1,p.altitude)
      project=function(x,y,z)
        local px,py=M.project(x,y,z,w.art.camera)
        return 80+(px-cx)*scale,78+(py-cy)*scale,0,true
      end
      cx,cy=M.project(topView and w.maxX/2 or p.cameraX,topView and w.maxY/2 or p.cameraY,0)
    end
    local batches={};for i=1,#palette do batches[i]={} end
    local ok,fx=pcall(require,'src.render.PaletteFX')
    for _,f in ipairs(self.faces) do
      local dist=math.sqrt((f.cx-p.cameraX)^2+(f.cy-p.cameraY)^2)
      local drawFar=perspective and camCfg.far or c.draw_distance
      if topView or dist<drawFar then
        local col=f.col
        local cr,cg,cb=f.shade or 1,1,1
        local verts=batches[col]
        local vv={}
        local u0,v0,u1,v1=0,0,0,0
        local _,_,centerDepth,centerVisible=project(f.cx,f.cy,0)
        local faceScale=perspective and (centerVisible and 80/math.tan(math.rad(camCfg.fov)*.5)/centerDepth or 0) or scale
        local lod=f.biome and w.art.lod_pixels[f.biome] or 0
        local detailVisible=not f.terrainCell or w.art.pattern_cells*c.world_scale*faceScale/(f.motif.cols or 1)>=lod
        if not detailVisible then cr=.72 end
        if self.texture and f.textured and f.tile and detailVisible then
          local tq=self.textureScale or 1
          local tx,ty=(f.tile%16)*8*tq,math.floor(f.tile/16)*8*tq
          if tx+8*tq<=self.textureWidth and ty+8*tq<self.textureHeight then u0,v0=tx/self.textureWidth,ty/self.textureHeight;u1,v1=(tx+8*tq)/self.textureWidth,(ty+8*tq)/self.textureHeight end
        elseif self.texture then
          -- The white trailing pixel preserves vertex color on plain terrain.
          u0,v0,u1,v1=.5/self.textureWidth,(self.textureHeight-.5)/self.textureHeight,.5/self.textureWidth,(self.textureHeight-.5)/self.textureHeight
        end
        if f.uvCrop and detailVisible then
          local c=f.uvCrop;local du,dv=u1-u0,v1-v0
          u0,v0=u0+du*c[1],v0+dv*c[2];u1,v1=u0+du*c[3],v0+dv*c[4]
        end
        local uvs={{u0,v0},{u1,v0},{u1,v1},{u0,v1}}
        local faceVisible=true
        for i,v in ipairs(f.points) do
          local x,y,depth,visible=project(v[1],v[2],v[3]);if not visible then faceVisible=false end
          local z=perspective and math.min(.99,depth/(camCfg.far*1.2)) or -(v[1]*w.art.camera.shear+v[2]+v[3]*(w.art.camera.depth+w.art.camera.slope*w.art.camera.shear))/100000
          vv[#vv+1]={x*quality,y*quality,uvs[i][1],uvs[i][2],cr,cg,cb,1,z}
        end
        if faceVisible then for _,i in ipairs({1,2,3,1,3,4}) do verts[#verts+1]=vv[i] end end
      end
    end
    if self.mesh then self.mesh:release();self.mesh=nil end
    g.push('all');g.setCanvas({self.canvas,depthstencil=self.depth});g.origin()
    if perspective then
      local sky=w.art.ramps[1][1];local sea=w.art.ramps[1][3];local haze=w.art.ramps[1][2]
      g.clear(sky[1],sky[2],sky[3],1,0,1)
      g.setColor(sea);g.rectangle('fill',0,math.max(0,horizonY)*quality,160*quality,144*quality)
      g.setColor(haze);g.rectangle('fill',0,math.max(0,horizonY-2)*quality,160*quality,4*quality)
    else g.clear(palette[1][1],palette[1][2],palette[1][3],1,0,1) end
    g.setColor(1,1,1);g.setDepthMode('less',true);g.setShader(self.shader)
    for col,verts in ipairs(batches) do if #verts>0 then
      local ramp=w.art.ramps[col]
      if ok and fx.customRamp then ramp={{1,1,1},{.667,.667,.667},{.333,.333,.333},{0,0,0}} end -- host applies its selected ramp once
      for i=1,4 do self.shader:send('Tone'..(i-1),ramp[i]) end
      local mesh=g.newMesh({{'VertexPosition','float',2},{'VertexTexCoord','float',2},{'VertexColor','float',4},{'TerrainDepth','float',1}},verts,'triangles','stream')
      if self.texture then mesh:setTexture(self.texture) end;g.draw(mesh);mesh:release()
    end end
    g.setDepthMode();g.setShader()
    if not topView then
      local x,y,_,shadowVisible=project(p.x,p.y,ground)
      if shadowVisible then g.setColor(palette[1]);g.ellipse('fill',x*quality,y*quality,4*quality,quality) end
      local bx,by,_,birdVisible=project(p.x,p.y,flyerZ)
      if birdVisible then
        bx,by=bx*quality,by*quality
        g.setColor(palette[1]);g.polygon('fill',bx-8*quality,by,bx-2*quality,by-3*quality,bx,by-2*quality,bx+2*quality,by-3*quality,bx+8*quality,by,bx+2*quality,by+2*quality,bx,by+4*quality,bx-2*quality,by+2*quality)
        g.setColor(palette[5]);g.polygon('fill',bx-6*quality,by,bx-2*quality,by-2*quality,bx,by,bx+2*quality,by-2*quality,bx+6*quality,by,bx,by+2*quality)
        g.setColor(palette[6]);g.rectangle('fill',bx-quality,by-2*quality,2*quality,4*quality)
      end
    end
    g.pop()
    g.push('all');g.setColor(1,1,1);g.draw(self.canvas,0,0,0,1/quality,1/quality)
    if gameFont then
      g.setColor(1,1,1);g.rectangle('fill',0,0,160,8);g.rectangle('fill',0,136,160,8)
      gameFont.draw(mode:gsub('_',' ')..' ALT '..math.floor(p.altitude),0,0)
      gameFont.draw('PAD FLY A/B ALT',0,136)
    else
      g.setFont(self.font);g.setColor(palette[5]);g.print('SOAR ALT '..math.floor(p.altitude),2,2)
    end
    g.pop()
  end
  return self
end
return M
