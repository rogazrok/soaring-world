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
  local c=w.config
  c.world_scale=c.world_scale or c.terrain_scale
  c.terrain_scale=c.world_scale
  c.terrain_height_scale=c.terrain_height_scale or 1
  c.prop_scale=c.prop_scale or 1
  c.camera_distance=c.camera_distance or 90
  for _,k in ipairs({'world_scale','terrain_height_scale','max_height','height_levels','extrusion','city_scale','prop_scale','flight_speed','camera_altitude','camera_distance','flight_min_altitude','flight_max_altitude','draw_distance','fade_distance','tree_density','sea_level','water_height','terrain_detail_density','water_detail_density','road_detail_density','distance_fade_strength'}) do assert(type(c[k])=='number' and c[k]==c[k],k..' must be numeric') end
  assert(type(c.material_tiles)=='table','material_tiles must be a table')
  assert(c.world_scale>0 and c.terrain_height_scale>=0 and c.height_levels>=2 and c.height_levels<=256 and c.max_height>=0 and c.extrusion>=0,'Invalid terrain settings')
  assert(c.draw_distance>c.fade_distance and c.fade_distance>=0 and c.tree_density>=0 and c.tree_density<=1 and c.road_detail_density>=0 and c.road_detail_density<=1 and c.distance_fade_strength>=0 and c.distance_fade_strength<=1,'Invalid fade/density settings')
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
function M.project(x,y,z) return x-.45*y,.30*x+.60*y-z end
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
    local detail=((x*73+y*137)%101)/100
    -- Dense game tiles on every cell make an illegible moiré at 160x144.
    -- Road is lightly textured; broad surfaces get only sparse authentic detail.
    f.textured=(b==7 and detail<c.road_detail_density) or (b==1 and detail<c.water_detail_density) or (b~=1 and b~=7 and detail<c.terrain_detail_density)
    local nz=w:ground(x,y+1);if y==w.depth-1 then nz=c.water_height end
    if z>nz then face({{x*s,(y+1)*s,z},{(x+1)*s,(y+1)*s,z},{(x+1)*s,(y+1)*s,nz},{x*s,(y+1)*s,nz}},2,(y+1)*s+.5*(x+.5)*s,x*s,y*s) end
    nz=w:ground(x+1,y);if x==w.width-1 then nz=c.water_height end
    if z>nz then face({{(x+1)*s,y*s,z},{(x+1)*s,(y+1)*s,z},{(x+1)*s,(y+1)*s,nz},{(x+1)*s,y*s,nz}},1,(y+.5)*s+.5*(x+1)*s,x*s,y*s) end
  end end
  local function box(x,y,z,a,b,h,rotation,style)
    local angle=math.rad(rotation or 0);local co,si=math.cos(angle),math.sin(angle)
    local function p(dx,dy,dz) return {x+dx*co-dy*si,y+dx*si+dy*co,z+dz} end
    local bottom={p(-a/2,-b/2,0),p(a/2,-b/2,0),p(a/2,b/2,0),p(-a/2,b/2,0)}
    local top={p(-a/2,-b/2,h),p(a/2,-b/2,h),p(a/2,b/2,h),p(-a/2,b/2,h)}
    for i=1,4 do local j=i%4+1;local dx,dy=bottom[j][1]-bottom[i][1],bottom[j][2]-bottom[i][2]
      if dy*.45-dx>0 then local cx,cy=(bottom[i][1]+bottom[j][1])/2,(bottom[i][2]+bottom[j][2])/2;local f=face({top[i],top[j],bottom[j],bottom[i]},i%2==0 and (style.sideA or 1) or (style.sideB or 2),cy+.5*cx+.001,x,y);f.tile=style.wallTile or c.material_tiles.cliff;f.textured=true end
    end
    local f=face(top,style.top or 4,y+.5*x+.002,x,y);f.tile=style.topTile or c.material_tiles.city;f.textured=true
  end
  local function stampGameBlocks(x,y,z,a,b,rotation,style)
    if not gameTileset or not style.gameBlocks then return end
    local cols=style.gameBlockColumns or 1
    local rows=math.ceil(#style.gameBlocks/cols)
    local angle=math.rad(rotation or 0);local co,si=math.cos(angle),math.sin(angle)
    local function point(dx,dy) return {x+dx*co-dy*si,y+dx*si+dy*co,z} end
    for gy=0,rows*4-1 do for gx=0,cols*4-1 do
      local bi=math.floor(gy/4)*cols+math.floor(gx/4)+1
      local block=gameTileset.blocks[style.gameBlocks[bi]+1]
      local tile=block and block[(gy%4)*4+(gx%4)+1]
      if tile then
        local x0,x1=-a/2+a*gx/(cols*4),-a/2+a*(gx+1)/(cols*4)
        local y0,y1=-b/2+b*gy/(rows*4),-b/2+b*(gy+1)/(rows*4)
        local f=face({point(x0,y0),point(x1,y0),point(x1,y1),point(x0,y1)},style.top or 4,y+.5*x+.004,x,y)
        f.tile,f.textured=tile,true
      end
    end end
  end
  -- Buildings are deliberately signs in the landscape: a pale house, a broad
  -- laboratory, red Center, blue Mart, and a dark Gym read before any texture
  -- detail does. They use the same box primitive as the original prototype.
  local function landmark(x,y,z,d,sc,rotation)
    local function layer(width,depth,height,style)
      box(x*s,y*s,z,width*sc*s,depth*sc*s,height*sc,rotation,style)
      z=z+height*sc
    end
    if d.kind=='house' or d.kind=='house_large' then
      layer(d.w,d.d,d.h*.42,{top=4,sideA=6,sideB=2})
      layer(d.w*.90,d.d*.90,d.h*.58,d)
    elseif d.kind=='lab' then
      layer(d.w,d.d,d.h*.42,{top=4,sideA=6,sideB=2})
      layer(d.w*.94,d.d*.94,d.h*.48,d)
      layer(d.w*.38,d.d*.54,d.h*.10,{top=5,sideA=5,sideB=6})
    elseif d.kind=='center' then
      layer(d.w,d.d,d.h*.44,{top=5,sideA=6,sideB=2})
      layer(d.w*.92,d.d*.92,d.h*.49,d)
      layer(d.w*.30,d.d*.62,d.h*.07,{top=5,sideA=5,sideB=8})
    elseif d.kind=='mart' then
      layer(d.w,d.d,d.h*.46,{top=5,sideA=6,sideB=2})
      layer(d.w*.90,d.d*.90,d.h*.54,d)
    elseif d.kind=='gym' then
      layer(d.w,d.d,d.h*.48,{top=5,sideA=6,sideB=2})
      layer(d.w*.94,d.d*.94,d.h*.43,d)
      layer(d.w*.34,d.d*.34,d.h*.09,{top=4,sideA=5,sideB=6})
    else
      layer(d.w,d.d,d.h,d)
    end
  end
  local function treeIcon(x,y,z,d,sc,rotation)
    box(x*s,y*s,z,.52*sc*s,.52*sc*s,2.5*sc,rotation,{top=6,sideA=6,sideB=1})
    z=z+2.5*sc
    if d.kind=='tree_pine' then
      box(x*s,y*s,z,3.4*sc*s,3.4*sc*s,2.2*sc,rotation,{top=2,sideA=2,sideB=1});z=z+2.2*sc
      box(x*s,y*s,z,2.55*sc*s,2.55*sc*s,2.2*sc,rotation,{top=3,sideA=2,sideB=1});z=z+2.2*sc
      box(x*s,y*s,z,1.55*sc*s,1.55*sc*s,2.4*sc,rotation,{top=3,sideA=2,sideB=1})
    else
      box(x*s,y*s,z,3.2*sc*s,3.2*sc*s,2.8*sc,rotation,{top=2,sideA=2,sideB=1});z=z+2.8*sc
      box(x*s,y*s,z,2.25*sc*s,2.25*sc*s,2.2*sc,rotation,{top=3,sideA=2,sideB=1})
    end
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
        stampGameBlocks(x*s,y*s,z+d.h*sc+.01,d.w*sc*s,d.d*sc*s,(o.rotation or 0),d)
      end
    end
    if def.parts then for _,p in ipairs(def.parts) do part(p) end
    elseif o.type=='tree_cluster' then
      local radius=o.radius or 8;local count=math.floor(radius*radius*(o.density or c.tree_density)*.2)
      for i=1,math.min(500,count) do local angle=i*2.399963;local r=radius*math.sqrt(i/math.max(1,count));part({type=o.treeType or 'tree',x=math.cos(angle)*r,y=math.sin(angle)*r}) end
    else part({}) end
  end
  for _,o in ipairs(w.objects) do prop(o) end
  for y=2,w.depth-3,5 do for x=2,w.width-3,5 do
    if w:biome(x,y)==3 and ((x*73+y*137)%101)/100<c.tree_density then prop({type=((x+y)%2==0 and 'tree_pine' or 'tree'),x=x,y=y,scale=.55}) end
  end end
  table.sort(faces,function(a,b) return a.depth<b.depth end)
  return faces
end
function M.renderer(w,getImage,gameTileset)
  local self={faces=M.build(w,gameTileset),world=w,font=love.graphics.newFont(8)}
  self.canvas=love.graphics.newCanvas(160,144);self.canvas:setFilter('nearest','nearest')
  self.depth=love.graphics.newCanvas(160,144,{format='depth24',readable=false})
  self.shader=love.graphics.newShader([[attribute float TerrainDepth;
    vec4 position(mat4 transform_projection, vec4 vertex_position) {
      vec4 p=transform_projection*vertex_position;p.z=TerrainDepth;return p;
    }]])
  if getImage and gameTileset and gameTileset.image then
    -- The engine-owned tileset record supplies the asset path. The mod never
    -- hardcodes or distributes a ROM-cache path; Assets resolves this through
    -- our assets_transforms-derived copy at runtime.
    local ok,image=pcall(getImage,gameTileset.image)
    if ok and image then
      local iw,ih=image:getDimensions()
      self.textureWidth,self.textureHeight=iw,ih+1
      self.texture=love.graphics.newCanvas(iw,ih+1)
      self.texture:setFilter('nearest','nearest')
      love.graphics.push('all');love.graphics.setCanvas(self.texture);love.graphics.origin();love.graphics.setColor(1,1,1,1);love.graphics.clear(0,0,0,0);love.graphics.draw(image,0,0);love.graphics.rectangle('fill',0,ih,iw,1);love.graphics.pop()
      self.ownsTexture=true
    end
  end
  function self:release() if self.mesh then self.mesh:release() end;if self.ownsTexture then self.texture:release() end;self.font:release();self.canvas:release();self.depth:release();self.shader:release() end
  function self:draw(p,overview)
    local g=love.graphics;local c=w.config;local palette=w.palette or M.palette
    local scale=overview and math.min(148/(w.maxX+.45*w.maxY),115/(w.maxY*.6+w.maxX*.3+c.max_height)) or c.camera_distance/math.max(1,p.altitude)
    local cx,cy=M.project(overview and w.maxX/2 or p.cameraX,overview and w.maxY/2 or p.cameraY,0)
    local verts={}
    for _,f in ipairs(self.faces) do
      local dist=math.sqrt((f.cx-p.cameraX)^2+(f.cy-p.cameraY)^2)
      if overview or dist<c.draw_distance then
        local col=f.col
        if f.biome==1 and ((math.floor(f.cx/c.world_scale)+math.floor(f.cy/c.world_scale)+math.floor((p.time or 0)*2))%11==0) then col=7 end
        local color=palette[col];local cr,cg,cb=color[1],color[2],color[3]
        if not overview and dist>c.fade_distance then
          local fade=clamp((dist-c.fade_distance)/(c.draw_distance-c.fade_distance),0,1)*c.distance_fade_strength
          cr=cr+(palette[1][1]-cr)*fade;cg=cg+(palette[1][2]-cg)*fade;cb=cb+(palette[1][3]-cb)*fade
        end
        local vv={}
        local u0,v0,u1,v1=0,0,0,0
        if self.texture and f.textured and f.tile then
          local tx,ty=(f.tile%16)*8,math.floor(f.tile/16)*8
          if tx+8<=self.textureWidth and ty+8<self.textureHeight then u0,v0=tx/self.textureWidth,ty/self.textureHeight;u1,v1=(tx+8)/self.textureWidth,(ty+8)/self.textureHeight end
        elseif self.texture then
          -- The white trailing pixel preserves vertex color on plain terrain.
          u0,v0,u1,v1=.5/self.textureWidth,(self.textureHeight-.5)/self.textureHeight,.5/self.textureWidth,(self.textureHeight-.5)/self.textureHeight
        end
        local uvs={{u0,v0},{u1,v0},{u1,v1},{u0,v1}}
        for i,v in ipairs(f.points) do local x,y=M.project(v[1],v[2],v[3]);vv[#vv+1]={80+(x-cx)*scale,78+(y-cy)*scale,uvs[i][1],uvs[i][2],cr,cg,cb,1,-(v[1]*.45+v[2]+v[3]*.735)/100000} end
        for _,i in ipairs({1,2,3,1,3,4}) do verts[#verts+1]=vv[i] end
      end
    end
    if self.mesh then self.mesh:release();self.mesh=nil end
    g.push('all');g.setCanvas({self.canvas,depthstencil=self.depth});g.origin();g.clear(palette[1][1],palette[1][2],palette[1][3],1,0,1);g.setColor(1,1,1);g.setDepthMode('less',true);g.setShader(self.shader)
    if #verts>0 then self.mesh=g.newMesh({{'VertexPosition','float',2},{'VertexTexCoord','float',2},{'VertexColor','float',4},{'TerrainDepth','float',1}},verts,'triangles','stream');if self.texture then self.mesh:setTexture(self.texture) end;g.draw(self.mesh) end
    g.setDepthMode();g.setShader()
    if not overview then
      local ground=w:getGroundHeight(p.x,p.y)
      local x,y=M.project(p.x,p.y,ground);x,y=80+(x-cx)*scale,78+(y-cy)*scale
      g.setColor(palette[1]);g.ellipse('fill',x,y,3,1)
      local bx,by=M.project(p.x,p.y,ground+p.altitude*.20);bx,by=80+(bx-cx)*scale,78+(by-cy)*scale
      g.setColor(palette[5]);g.polygon('fill',bx-3,by,bx,by-2,bx+3,by,bx,by+2)
      g.setColor(palette[6]);g.rectangle('fill',bx-1,by-1,2,2)
    end
    g.setFont(self.font);g.setColor(palette[5]);g.print('SOARING  ALT '..math.floor(p.altitude),2,2)
    g.pop();g.setColor(1,1,1);g.draw(self.canvas,0,0)
  end
  return self
end
return M
