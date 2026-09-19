-- Data-driven authoring scene. Coordinates in image pixels; z in world units.
local M={}
M.codes={{20,40,80},{120,180,80},{30,100,45},{130,120,110},{230,210,130},{190,110,100},{210,180,140}}
-- Six fixed Game Boy-inspired shades: water, deep forest, grass, highlight,
-- pale roofs/sand, and dark cliff/roof faces. No filtered textures are used.
M.palette={{.07,.14,.15},{.14,.27,.18},{.33,.47,.25},{.57,.67,.34},{.82,.87,.56},{.43,.32,.22},{.14,.28,.31},{.82,.22,.18},{.18,.36,.78}}
local function clamp(x,a,b) return math.max(a,math.min(b,x)) end
local function data(s,name)
  -- gen1recomp currently runs Lua 5.4, whose loadstring has no setfenv.
  -- These files are owned mod data and contain only return-table literals.
  local f=assert(loadstring(assert(s,'Missing '..name),'@'..name))
  return assert(f(),'Empty '..name)
end
function M.load(read)
  local paletteText=read('world/palette.lua')
  local w={config=data(read('world/config.lua'),'config'),objects=data(read('world/kanto_objects.lua'),'objects'),props=data(read('world/props.lua'),'props'),palette=paletteText and data(paletteText,'palette') or M.palette}
  local function png(path) return love.image.newImageData(love.filesystem.newFileData(assert(read(path),'Missing '..path),path)) end
  w.height=png('world/kanto_height.png');w.terrain=png('world/kanto_terrain.png')
  w.width,w.depth=w.height:getDimensions();local tw,th=w.terrain:getDimensions()
  assert(tw==w.width and th==w.depth,'PNG dimensions differ');assert(w.width>=2 and w.depth>=2 and w.width<=512 and w.depth<=512,'PNG size must be 2..512')
  w.art=data(read('world/art.lua'),'art')
  local c=w.config
  assert(type(w.art.render_scale)=='number' and w.art.render_scale>=1 and w.art.render_scale<=4,'art.render_scale must be 1..4')
  assert(type(w.art.texture_scale)=='number' and w.art.texture_scale>=1 and w.art.texture_scale<=4,'art.texture_scale must be 1..4')
  assert(type(w.art.lod_pixels)=='table' and #w.art.lod_pixels==7,'art.lod_pixels must contain seven values')
  assert(type(w.art.camera_modes)=='table' and w.art.camera_modes.CHASE and w.art.camera_modes.HIGH_SOAR,'art.camera_modes must define CHASE and HIGH_SOAR')
  for name,cam in pairs(w.art.camera_modes) do
    for _,key in ipairs({'pitch','fov','back','above','look_ahead','far'}) do assert(type(cam[key])=='number',name..'.'..key..' must be numeric') end
    assert(cam.pitch>=15 and cam.pitch<=40 and cam.fov>=35 and cam.fov<=75 and cam.far>0,'Invalid perspective camera '..name)
  end
  c.world_scale=c.world_scale or c.terrain_scale
  c.terrain_scale=c.world_scale
  c.terrain_height_scale=c.terrain_height_scale or 1
  c.prop_scale=c.prop_scale or 1
  c.camera_distance=c.camera_distance or 90
  c.flight_turn_speed=c.flight_turn_speed or 1.85
  c.flight_reverse_scale=c.flight_reverse_scale or .65
  for _,k in ipairs({'world_scale','terrain_height_scale','max_height','height_levels','extrusion','city_scale','prop_scale','flight_speed','flight_turn_speed','flight_reverse_scale','camera_altitude','camera_distance','flight_min_altitude','flight_max_altitude','draw_distance','fade_distance','tree_density','sea_level','water_height','terrain_detail_density','water_detail_density','road_detail_density','distance_fade_strength'}) do assert(type(c[k])=='number' and c[k]==c[k],k..' must be numeric') end
  assert(type(c.material_tiles)=='table','material_tiles must be a table')
  assert(c.world_scale>0 and c.terrain_height_scale>=0 and c.height_levels>=2 and c.height_levels<=256 and c.max_height>=0 and c.extrusion>=0,'Invalid terrain settings')
  assert(c.draw_distance>c.fade_distance and c.fade_distance>=0 and c.tree_density>=0 and c.tree_density<=1 and c.road_detail_density>=0 and c.road_detail_density<=1 and c.distance_fade_strength>=0 and c.distance_fade_strength<=1,'Invalid fade/density settings')
  assert(c.flight_turn_speed>0 and c.flight_reverse_scale>0 and c.flight_reverse_scale<=1,'Invalid relative flight controls')
  assert(c.sea_level>=0 and c.sea_level<255,'sea_level must be 0..254')
  for i,v in ipairs(w.palette) do assert(type(v)=='table' and #v==3 and type(v[1])=='number' and type(v[2])=='number' and type(v[3])=='number','Invalid palette color '..i) end
  for _,o in ipairs(w.objects) do assert(w.props[o.type],'Unknown prop '..tostring(o.type));for _,k in ipairs({'x','y'}) do assert(type(o[k])=='number','Object missing '..k) end end
  function w:biome(x,y)
    local r,g,b=self.terrain:getPixel(clamp(math.floor(x),0,self.width-1),clamp(math.floor(y),0,self.depth-1));local best,dist=1,math.huge
    for i,v in ipairs(M.codes) do local d=(r*255-v[1])^2+(g*255-v[2])^2+(b*255-v[3])^2;if d<dist then best,dist=i,d end end
    return best
  end
  function w:ground(x,y)
    x,y=clamp(math.floor(x),0,self.width-1),clamp(math.floor(y),0,self.depth-1)
    local r=self.height:getPixel(x,y)
    if r*255<=c.sea_level or self:biome(x,y)==1 then return c.water_height end
    local v=clamp((r*255-c.sea_level)/(255-c.sea_level),0,1)
    return c.water_height+math.floor(v*(c.height_levels-1)+.5)/(c.height_levels-1)*c.max_height*c.extrusion*c.terrain_height_scale
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
    local fields={};for _,k in ipairs({'type','name','x','y','z','scale','rotation','radius','density','treeType','seed','city'}) do
      local v=o[k];if v~=nil then fields[#fields+1]=k..'='..(type(v)=='string' and string.format('%q',v) or tostring(v)) end
    end
    lines[#lines+1]='  {'..table.concat(fields,',')..'},'
  end
  lines[#lines+1]='}';return table.concat(lines,'\n')..'\n'
end
function M.project(x,y,z,c) c=c or {shear=.18,slope=.14,depth=.82};return x-c.shear*y,c.slope*x+c.depth*y-z end
function M.build(w,gameTileset)
  local faces={};local c=w.config;local s=c.world_scale
  local function face(points,col,depth,cx,cy)
    local f={points=points,col=col,depth=depth,cx=cx,cy=cy};faces[#faces+1]=f;return f
  end
  local function quad(x,y,sz,z,col,biome)
    local f=face({{x,y,z},{x+sz,y,z},{x+sz,y+sz,z},{x,y+sz,z}},col,y+.5*sz+.5*(x+.5*sz),x,y);f.biome=biome;return f
  end
  for y=0,w.depth-1 do for x=0,w.width-1 do
    local z=w:ground(x,y);local b=w:biome(x,y);local col=({1,3,2,6,5,4,5})[b]
    local tile=({c.material_tiles.water,c.material_tiles.grass,c.material_tiles.forest,c.material_tiles.mountain,c.material_tiles.sand,c.material_tiles.city,c.material_tiles.road})[b]
    local f=quad(x*s,y*s,s,z,col,b);f.tile=tile
    f.textured=true;f.motif=w.art.terrain[b];f.terrainCell={x,y}
    local nz=w:ground(x,y+1);if y==w.depth-1 then nz=c.water_height end
    if z>nz then face({{x*s,(y+1)*s,z},{(x+1)*s,(y+1)*s,z},{(x+1)*s,(y+1)*s,nz},{x*s,(y+1)*s,nz}},6,(y+1)*s+.5*(x+.5)*s,x*s,y*s).shade=.66 end
    nz=w:ground(x+1,y);if x==w.width-1 then nz=c.water_height end
    if z>nz then face({{(x+1)*s,y*s,z},{(x+1)*s,(y+1)*s,z},{(x+1)*s,(y+1)*s,nz},{(x+1)*s,y*s,nz}},6,(y+.5)*s+.5*(x+1)*s,x*s,y*s).shade=.33 end
  end end
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
  local function treeIcon(x,y,z,d,sc,rotation)
    local a=w.art.unit*2*sc*s;local h=d.h*sc*w.art.relief_scale
    if d.kind=='tree_pine' then a=a*.75 end
    box(x*s,y*s,z,a,a,h,rotation,{top=2,sideA=2,sideB=2})
    patch({{x*s-a/2,y*s-a/2,z+h+.02},{x*s+a/2,y*s-a/2,z+h+.02},{x*s+a/2,y*s+a/2,z+h+.02},{x*s-a/2,y*s+a/2,z+h+.02}},w.art.trees,2,x*s,y*s)
  end
  local function prop(o)
    local def=w.props[o.type];local sc=(o.scale or 1)*c.prop_scale*((o.city or o.type=='city' or o.type=='pallet') and c.city_scale or 1);local rot=math.rad(o.rotation or 0)
    local function part(p)
      local dx,dy=(p.x or 0)*sc,(p.y or 0)*sc;local x=o.x+dx*math.cos(rot)-dy*math.sin(rot);local y=o.y+dx*math.sin(rot)+dy*math.cos(rot)
      local d=w.props[p.type or o.type];local z=w:ground(x,y)+(o.z or 0)+(p.z or 0)*sc
      if d.kind=='tree_broadleaf' or d.kind=='tree_pine' then treeIcon(x,y,z,d,sc,(o.rotation or 0))
      elseif d.kind then landmark(x,y,z,d,sc,(o.rotation or 0))
      else
        box(x*s,y*s,z,d.w*sc*s,d.d*sc*s,d.h*sc,(o.rotation or 0),d)
        if o.type=='rock' or o.type=='mountain_peak' then
          local a,b=d.w*sc*s/2,d.d*sc*s/2;patch({{x*s-a,y*s-b,z+d.h*sc+.05},{x*s+a,y*s-b,z+d.h*sc+.05},{x*s+a,y*s+b,z+d.h*sc+.05},{x*s-a,y*s+b,z+d.h*sc+.05}},w.art.rock,6,x*s,y*s)
        end
      end
    end
    if def.parts then for _,p in ipairs(def.parts) do part(p) end
    elseif o.type=='tree_cluster' then
      local radius=o.radius or 8;local count=math.floor(radius*radius*(o.density or c.tree_density)*.2)
      local spacing=math.max(4,math.floor(6/math.sqrt(math.max(.05,o.density or c.tree_density))))
      for dy=-radius,radius,spacing do for dx=-radius,radius,spacing do
        if dx*dx+dy*dy<=radius*radius then part({type=o.treeType or 'tree',x=dx,y=dy}) end
      end end
    else part({}) end
  end
  for _,o in ipairs(w.objects) do prop(o) end
  local expanded={}
  for _,f in ipairs(faces) do
    if f.motif then
      local m=f.motif;local rows=math.ceil(#m.tiles/m.cols)
      if f.terrainCell then
        local period=w.art.pattern_cells
        local ux=(f.terrainCell[1]%period)/period*m.cols
        local uy=(f.terrainCell[2]%period)/period*rows
        f.tile=m.tiles[math.floor(uy)*m.cols+math.floor(ux)+1]
        f.uvCrop={ux%1,uy%1,m.cols/period,rows/period}
        expanded[#expanded+1]=f
      else
        local function point(u,v)
          local p={};for k=1,3 do p[k]=f.points[1][k]*(1-u)*(1-v)+f.points[2][k]*u*(1-v)+f.points[3][k]*u*v+f.points[4][k]*(1-u)*v end;return p
        end
        for y=0,rows-1 do for x=0,m.cols-1 do
          expanded[#expanded+1]={points={point(x/m.cols,y/rows),point((x+1)/m.cols,y/rows),point((x+1)/m.cols,(y+1)/rows),point(x/m.cols,(y+1)/rows)},col=f.col,depth=f.depth,cx=f.cx,cy=f.cy,tile=m.tiles[y*m.cols+x+1],textured=true}
        end end
      end
    else expanded[#expanded+1]=f end
  end
  faces=expanded
  table.sort(faces,function(a,b) return a.depth<b.depth end)
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
