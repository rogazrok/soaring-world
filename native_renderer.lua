-- Window-resolution presentation adapter; camera equations match 0.5.1.
local M={}
local format={{'VertexPosition','float',3},{'VertexTexCoord','float',2},{'VertexColor','float',4},{'VertexLight','float',1}}
-- One inexpensive composite transforms the completed scene (terrain, water,
-- horizon, haze, clouds and rider together). HUD is drawn afterwards.
local shaderSource=[[
varying vec2 WorldXY;
varying float ViewDepth;
varying float FaceLight;
#ifdef VERTEX
attribute float VertexLight;
uniform vec3 Camera;
uniform vec2 Direction;
uniform vec2 Pitch;
uniform float Focal;
uniform float Quality;
uniform float Far;
uniform bool Top;
uniform vec2 FrameCenter;
uniform vec4 TopCamera;
uniform vec3 TopProject;
vec4 position(mat4 tp, vec4 v) {
  WorldXY=v.xy;FaceLight=VertexLight;ViewDepth=0.0;
  if (Top) {
    float x=v.x-TopProject.x*v.y;
    float y=TopProject.y*v.x+TopProject.z*v.y-v.z;
    vec4 p=tp*vec4(FrameCenter.x+(x-TopCamera.x)*TopCamera.z,FrameCenter.y+(y-TopCamera.y)*TopCamera.z,0.0,1.0);
    p.z=-(v.x*TopProject.x+v.y+v.z*(TopProject.z+TopProject.y*TopProject.x))/100000.0;return p;
  }
  vec3 d=v.xyz-Camera;
  float side=dot(d.xy,vec2(-Direction.y,Direction.x));
  float forward=dot(d.xy,Direction);
  float depth=forward*Pitch.x-d.z*Pitch.y;
  ViewDepth=depth;
  float up=forward*Pitch.y+d.z*Pitch.x;
  vec4 p=tp*vec4(FrameCenter.x*depth+side*Focal*Quality,FrameCenter.y*depth-up*Focal*Quality,0.0,depth);
  p.z=(Far+4.0)/(Far-4.0)*depth-8.0*Far/(Far-4.0);
  return p;
}
#endif
#ifdef PIXEL
uniform vec3 Tone0;uniform vec3 Tone1;uniform vec3 Tone2;uniform vec3 Tone3;
uniform float FxTime;
uniform vec3 Haze; // start, end, blend amount
uniform vec3 HazeColor;
uniform float WaterLayers;uniform float WaterSpeed;uniform float WaterBlend;uniform bool WaterSurface;
uniform vec2 ShadowVelocity;uniform float ShadowScale;uniform float ShadowAmount;
uniform float LightAmount;
vec4 effect(vec4 color,Image tex,vec2 uv,vec2 screen) {
  float sampleValue=Texel(tex,uv).r;
  if (WaterSurface && WaterLayers>0.0) {
    vec2 flow=vec2(1.0,0.28)*FxTime*WaterSpeed;
    sampleValue=Texel(tex,uv+flow).r;
    if (WaterLayers>1.5) sampleValue=mix(sampleValue,Texel(tex,uv-flow*0.43+vec2(0.23,0.17)).r,WaterBlend);
  }
  float v=clamp(sampleValue*color.r,0.0,1.0)*3.0;
  vec3 tone=v<1.0?mix(Tone3,Tone2,v):(v<2.0?mix(Tone2,Tone1,v-1.0):mix(Tone1,Tone0,v-2.0));
  if (LightAmount>0.0) tone*=1.0-FaceLight*LightAmount;
  if (ShadowAmount>0.0) {
    vec2 q=(WorldXY-FxTime*ShadowVelocity)/ShadowScale;
    float field=sin(q.x)*sin(q.y*0.83)+0.42*sin(q.x*0.53+q.y*0.37);
    tone*=1.0-smoothstep(0.25,0.9,field)*ShadowAmount;
  }
  if (Haze.z>0.0) {
    float fog=clamp(smoothstep(Haze.x,Haze.y,ViewDepth)*Haze.z,0.0,1.0);
    // A flat atmosphere avoids copying panorama silhouettes onto distant terrain.
    tone=mix(tone,HazeColor,fog);
  }
  return vec4(tone,1.0);
}
#endif
]]
function M.new(w,Stylized,getImage,tileset,font,effects,options)
  local g=love.graphics
  local yieldBuild=options and options.yieldBuild
  local buildWork=0
  local function buildCheckpoint(amount)
    if not yieldBuild then return end
    buildWork=buildWork+(amount or 1)
    if buildWork>=700 then buildWork=0;yieldBuild() end
  end
  local supported,compiled=pcall(g.newShader,shaderSource)
  local shaderError
  if not supported then
    shaderError=tostring(compiled)
    -- Preserve the original tone mapper if a platform rejects the FX fragment.
    local originalPixel=[[#ifdef PIXEL
uniform vec3 Tone0;uniform vec3 Tone1;uniform vec3 Tone2;uniform vec3 Tone3;
vec4 effect(vec4 color,Image tex,vec2 uv,vec2 screen) {
  float v=clamp(Texel(tex,uv).r*color.r,0.0,1.0)*3.0;
  vec3 tone=v<1.0?mix(Tone3,Tone2,v):(v<2.0?mix(Tone2,Tone1,v-1.0):mix(Tone1,Tone0,v-2.0));
  return vec4(tone,1.0);
}
#endif]]
    compiled=g.newShader((shaderSource:gsub('#ifdef PIXEL.*#endif',originalPixel)))
    print('[Soaring] Atmosphere shader unavailable; original rendering kept: '..shaderError)
  end
  local DayNight=assert(loadstring(w.readAsset('day_night.lua'),'@day_night.lua'))()
  local nightShader,nightShaderError=DayNight.newShader(g)
  if not nightShader then print('[Soaring] Night composite shader unavailable; using a simple tint fallback: '..tostring(nightShaderError)) end
  local self={world=w,batches={},font=font,shader=compiled,nightShader=nightShader,
    atmosphereSupported=supported,atmosphereFallback=shaderError,textures={},width=0,objectPositions={},effects=effects,editor=options and options.editor}
  local Atmosphere=assert(loadstring(w.readAsset('atmosphere.lua'),'@atmosphere.lua'))()
  self.atmosphere=Atmosphere.load(w.readAsset)
  if not supported then self.atmosphere.enabled=false end
  function self:setAtmosphere(raw)
    self.atmosphere=Atmosphere.resolve(raw)
    if not self.atmosphereSupported then self.atmosphere.enabled=false end
    if self.effects and self.effects.setAtmosphere then self.effects:setAtmosphere(self.atmosphere) end
  end
  if self.effects and self.effects.setAtmosphere then self.effects:setAtmosphere(self.atmosphere) end
  if not self.editor then
    local Clouds=assert(loadstring(w.readAsset('world_clouds.lua'),'@world_clouds.lua'))()
    self.worldClouds=Clouds.new(w)
  end
  local anisotropy=math.min(8,g.getSystemLimits().textureanisotropy or 1)
  if w.config.soaring_horizon_enabled and not self.editor then
    local Horizon=assert(loadstring(w.readAsset('horizon.lua'),'@horizon.lua'))()
    self.horizon=Horizon.new(w.readAsset)
  end
  -- Isolate imported tiles before building mipmaps. No neighbour can bleed
  -- into the mip tail; nearest enlargement retains the source pixel motifs.
  local source=getImage(tileset.image);local sw,sh=source:getDimensions()
  self.texture=source
  local flightSpritePath='generated/dragonite_red_flight_sheet.png'
  local flightFrameW,flightFrameH=48,48
  local function loadFlightSprite()
    local bytes=w.readAsset and w.readAsset(flightSpritePath)
    if not bytes then return end
    local ok,fileData=pcall(love.filesystem.newFileData,bytes,flightSpritePath)
    if not ok then return end
    local okImage,imageData=pcall(love.image.newImageData,fileData)
    if not okImage then return end
    local image=g.newImage(imageData,{mipmaps=false})
    image:setFilter('nearest','nearest',1)
    local iw,ih=image:getDimensions()
    if iw<flightFrameW*3 or ih<flightFrameH then imageData:release();image:release();return end
    self.flightSprite=image
    self.flightSpriteQuads={
      g.newQuad(0,0,flightFrameW,flightFrameH,iw,ih),
      g.newQuad(flightFrameW,0,flightFrameW,flightFrameH,iw,ih),
      g.newQuad(flightFrameW*2,0,flightFrameW,flightFrameH,iw,ih)
    }
    self.textures[#self.textures+1]=image
    imageData:release()
  end
  loadFlightSprite()
  local tiles={}
  local function tileImage(id,sizeX,sizeY)
    sizeX,sizeY=sizeX or 42,sizeY or 42
    local key=id..':'..sizeX..':'..sizeY
    if tiles[key] then return tiles[key] end
    local canvas=g.newCanvas(sizeX,sizeY,{dpiscale=1})
    g.push('all');g.setCanvas(canvas);g.origin();g.setColor(1,1,1);g.clear(1,1,1)
    if id>=0 then
      local mn,mg,an=source:getFilter();source:setFilter('nearest','nearest')
      local q=g.newQuad(id%16*8,math.floor(id/16)*8,8,8,sw,sh);g.draw(source,q,0,0,0,sizeX/8,sizeY/8);q:release();source:setFilter(mn,mg,an)
    end
    g.pop();local pixels=canvas:newImageData();local image=g.newImage(pixels,{mipmaps=true});pixels:release();canvas:release()
    image:setFilter('linear','nearest',anisotropy);image:setMipmapFilter('linear');image:setWrap('repeat','repeat');tiles[key]=image;self.textures[#self.textures+1]=image
    if yieldBuild then yieldBuild() end -- canvas/filter state was restored above
    return image
  end
  local function motifImage(m,sizeX,sizeY)
    if #m.tiles==1 then return tileImage(m.tiles[1],sizeX,sizeY) end
    local key='motif:'..m.cols..':'..table.concat(m.tiles,',')..':'..sizeX..':'..sizeY
    if tiles[key] then return tiles[key] end
    local rows=math.ceil(#m.tiles/m.cols)
    local canvas=g.newCanvas(sizeX,sizeY,{dpiscale=1})
    local mn,mg,an=source:getFilter()
    g.push('all');g.setCanvas(canvas);g.origin();g.setColor(1,1,1);g.clear(1,1,1)
    source:setFilter('nearest','nearest')
    for y=0,rows-1 do for x=0,m.cols-1 do
      local id=m.tiles[y*m.cols+x+1] or 0
      local q=g.newQuad(id%16*8,math.floor(id/16)*8,8,8,sw,sh)
      g.draw(source,q,x*sizeX/m.cols,y*sizeY/rows,0,sizeX/m.cols/8,sizeY/rows/8);q:release()
    end end
    source:setFilter(mn,mg,an);g.pop()
    local pixels=canvas:newImageData();local image=g.newImage(pixels,{mipmaps=true});pixels:release();canvas:release()
    image:setFilter('linear','nearest',anisotropy);image:setMipmapFilter('linear');image:setWrap('repeat','repeat')
    tiles[key]=image;self.textures[#self.textures+1]=image
    if yieldBuild then yieldBuild() end
    return image
  end
  local groups={}
  local function add(points,uvs,col,shade,texture,objectName,category,chunk,objectKey,water)
    local key=tostring(texture)..':'..col..':'..(objectName or '')..':'..(category or '')..':'..(chunk or '')..':'..(self.editor and objectKey or '')
    if groups[key] and groups[key].water~=(water or false) then key=key..':water:'..tostring(water or false) end
    local b=groups[key];if not b then b={vertices={},col=col,texture=texture,objectName=objectName,category=category,chunk=chunk,objectKey=objectKey,water=water or false};groups[key]=b end
    local a,bp,c=points[1],points[2],points[3]
    local ux,uy,uz=bp[1]-a[1],bp[2]-a[2],bp[3]-a[3]
    local vx,vy,vz=c[1]-a[1],c[2]-a[2],c[3]-a[3]
    local nx,ny,nz=uy*vz-uz*vy,uz*vx-ux*vz,ux*vy-uy*vx
    local length=math.max(.000001,math.sqrt(nx*nx+ny*ny+nz*nz));local sun=self.atmosphere.sun
    local light=1-math.max(0,(nx*sun[1]+ny*sun[2]+nz*sun[3])/length)
    for j=2,#points-1 do for _,i in ipairs({1,j,j+1}) do
      local p,u=points[i],uvs[i];b.vertices[#b.vertices+1]={p[1],p[2],p[3],u[1],u[2],shade or 1,1,1,1,light}
    end end
  end
  local faces=Stylized.build(w,tileset,true,{yieldBuild=yieldBuild})
  local s=w.config.world_scale
  -- Terrain side walls are now closed globally by Stylized.build.
  local function addFace(f)
    local sx,sy=42,42
    if f.worldPattern and f.motif then
      sx=w.art.pattern_cells*s
      sy=w.art.pattern_cells*s
    elseif f.terrainCell and f.motif then
      sx=math.max(1,math.floor(w.art.pattern_cells*s/f.motif.cols+.5))
      sy=math.max(1,math.floor(w.art.pattern_cells*s/math.ceil(#f.motif.tiles/f.motif.cols)+.5))
    end
    -- Exterior patches repeat the entire motif in world UVs, not its blank first tile.
    local atlas=f.worldPattern and f.motif and motifImage(f.motif,sx,sy) or tileImage(f.textured and f.tile or -1,sx,sy)
    local u0,v0,u1,v1
    if f.textured and f.tile then
      u0,v0,u1,v1=0,0,1,1
      if f.uvCrop then local a=f.uvCrop;local du,dv=u1-u0,v1-v0;u0=u0+du*a[1];v0=v0+dv*a[2];u1=u0+du*a[3];v1=v0+dv*a[4] end
      if f.worldPattern then
        local minx,maxx,miny,maxy=math.huge,-math.huge,math.huge,-math.huge
        for _,p in ipairs(f.points) do minx=math.min(minx,p[1]);maxx=math.max(maxx,p[1]);miny=math.min(miny,p[2]);maxy=math.max(maxy,p[2]) end
        local period=f.worldPatternPeriod or w.art.pattern_cells*s
        u0,u1,v0,v1=minx/period,maxx/period,miny/period,maxy/period
      elseif f.uvRepeat then u1=u0+f.uvRepeat[1];v1=v0+f.uvRepeat[2] end
    else u0,v0,u1,v1=.5,.5,.5,.5 end
    local chunk=self.editor and f.terrainCell and (math.floor(f.terrainCell[1]/32)..':'..math.floor(f.terrainCell[2]/32)) or nil
    local uvs={{u0,v0},{u1,v0},{u1,v1},{u0,v1}}
    if f.worldPattern then
      local period=f.worldPatternPeriod or w.art.pattern_cells*s
      uvs={};for _,p in ipairs(f.points) do uvs[#uvs+1]={p[1]/period,p[2]/period} end
    end
    add(f.points,uvs,f.col,f.shade,atlas,f.backdrop and '__BACKDROP__' or nil,f.category,chunk,f.objectKey,f.biome==1 and not f.backdropWall)
  end
  for _,f in ipairs(faces) do
    addFace(f)
    if yieldBuild then buildCheckpoint(1) end
  end
  local addGeneratedObject
  if w.buildings then
    local textures={}
    for name,model in pairs(w.buildings.models) do
      textures[name]={}
      for region in pairs(model.regions) do
      local levels={}
      for level=0,7 do
        local path='generated/'..name..'-'..region..'-'..level..'.png'
        levels[#levels+1]=love.image.newImageData(love.filesystem.newFileData(assert(w.readAsset(path)),path))
      end
      local image=g.newImage(levels,{mipmaps=true});image:setFilter('linear','nearest',anisotropy);image:setMipmapFilter('linear')
      textures[name][region]=image;self.textures[#self.textures+1]=image
      for _,d in ipairs(levels) do d:release() end
      if yieldBuild then yieldBuild() end
      end
    end
    addGeneratedObject=function(o)
      if o.hidden then return end
      local archetype,instance=Stylized.archetype(w,o)
      if archetype then
        local model=w.buildings.models[archetype];local x,y,z=Stylized.anchor(w,o)
        local angle=math.rad(o.rotation or 0);local co,si=math.cos(angle),math.sin(angle)
        local scale=(o.scale or 1)*((instance or o.archetype) and 1 or ((w.buildings.type_scales or {})[o.type] or 1))
        if o.name then self.objectPositions[o.name]={x,y,z} end
        for _,f in ipairs(model.faces) do
          local points={};for _,p in ipairs(f.points) do points[#points+1]={x+(p[1]*co-p[2]*si)*scale,y+(p[1]*si+p[2]*co)*scale,z+p[3]*scale} end
          local size=model.regions[f.region].pixels;local uvs={}
          for _,u in ipairs(f.uv) do uvs[#uvs+1]={(24+u[1]*size[1])/128,(24+u[2]*size[2])/128} end
          local facingY=archetype=='cave_entrance' and (f.normal[1]*si+f.normal[2]*co) or f.normal[2]
          local shade=f.normal[3]>.2 and 1 or (facingY>.2 and .95 or .8)
          local col=f.region=='ROOF' and (model.roof_col or 5) or (f.region=='DETAILS' and (model.detail_col or model.wall_col or 4) or (f.region=='DOOR' and (model.door_col or model.wall_col or 4) or (model.wall_col or 4)))
          local category=(o.type:find('tree') or o.type:find('forest')) and 'vegetation' or ((o.type:find('rock') or o.type=='cave') and 'details' or 'buildings')
          add(points,uvs,col,shade,textures[archetype][f.region],o.name,category,nil,Stylized.objectKey(o))
          if yieldBuild then buildCheckpoint(1) end
        end
      end
    end
    for _,o in ipairs(w.objects) do addGeneratedObject(o) end
    for _,o in ipairs(w.generatedDetails or {}) do addGeneratedObject(o) end
  end
  local function finalize()
    self.batches={};self.verticesByObject={}
    for _,b in pairs(groups) do
      if b.vertices then
        b.mesh=g.newMesh(format,b.vertices,'triangles',(self.editor and b.objectKey) and 'dynamic' or 'static');b.mesh:setTexture(b.texture)
        if self.editor and b.objectKey then b.vertexData=b.vertices end
        b.vertices=nil
        if yieldBuild then yieldBuild() end
      end
      self.batches[#self.batches+1]=b
      if self.editor and b.objectKey and b.vertexData then
        local v=self.verticesByObject[b.objectKey] or {};self.verticesByObject[b.objectKey]=v
        for _,point in ipairs(b.vertexData) do v[#v+1]=point end
      end
    end
  end
  finalize()
  function self:updateTerrainCells(x0,y0,x1,y1)
    assert(self.editor,'Terrain chunk updates are editor-only')
    local cx0,cy0=math.max(0,math.floor((x0-1)/32)),math.max(0,math.floor((y0-1)/32))
    local cx1,cy1=math.min(math.ceil(w.width/32)-1,math.floor(x1/32)),math.min(math.ceil(w.depth/32)-1,math.floor(y1/32))
    local changed={}
    for cy=cy0,cy1 do for cx=cx0,cx1 do changed[cx..':'..cy]=true end end
    for key,b in pairs(groups) do
      if b.chunk and changed[b.chunk] then b.mesh:release();groups[key]=nil end
    end
    for cy=cy0,cy1 do for cx=cx0,cx1 do
      local bounds={cx*32,cy*32,math.min(w.width-1,(cx+1)*32-1),math.min(w.depth-1,(cy+1)*32-1)}
      local localFaces=Stylized.build(w,tileset,true,{terrainOnly=true,bounds=bounds})
      for _,f in ipairs(localFaces) do addFace(f) end
    end end
    finalize()
    -- Rebuild only nearby snapped props; Free Z objects retain absolute height.
    for _,list in ipairs({w.objects,w.generatedVegetation,w.generatedDetails}) do
      for _,o in ipairs(list) do
        if not o.hidden and o.z_mode~='free' and o.x>=x0-12 and o.x<=x1+12 and o.y>=y0-12 and o.y<=y1+12 then self:updateObject(o) end
      end
    end
  end
  local function removeObject(key)
    for id,b in pairs(groups) do if b.objectKey==key then b.mesh:release();groups[id]=nil end end
  end
  local function addObject(o)
    if o.hidden then return end
    if addGeneratedObject then addGeneratedObject(o) end
    for _,f in ipairs(Stylized.build(w,tileset,true,{objectsOnly=true,objectList={o}})) do addFace(f) end
  end
  function self:removeObject(key)
    assert(self.editor,'Object updates are editor-only')
    removeObject(key);finalize()
  end
  function self:updateObject(o,oldKey)
    assert(self.editor,'Object updates are editor-only')
    removeObject(oldKey or Stylized.objectKey(o));addObject(o);finalize()
  end
  function self:refreshObjects()
    assert(self.editor,'Object updates are editor-only')
    for id,b in pairs(groups) do if b.objectKey then b.mesh:release();groups[id]=nil end end
    for _,list in ipairs({w.objects,w.generatedVegetation,w.generatedDetails}) do for _,o in ipairs(list) do addObject(o) end end
    finalize()
  end
  function self:objectVertices(key) return self.verticesByObject[key] or {} end
  function self:release()
    if self.worldClouds then self.worldClouds:release() end
    if self.horizon then self.horizon:release() end
    for _,b in ipairs(self.batches) do b.mesh:release() end
    for _,t in ipairs(self.textures) do t:release() end
    if self.flightSpriteQuads then for _,q in ipairs(self.flightSpriteQuads) do q:release() end end
    if self.canvas then self.canvas:release();self.depth:release() end
    self.shader:release();if self.nightShader then self.nightShader:release() end;if self.hud then self.hud:release() end
  end
  function self:drawWindow(p,viewport,riderMotion,dayNight)
    -- Soaring owns the complete window.  The regular game still uses the
    -- engine viewport; this presentation path only runs while the flight
    -- screen is on top of the stack.
    local width,height=g.getDimensions()
    local pw,ph=math.floor(width*(viewport.dpiX or 1)+.5),math.floor(height*(viewport.dpiY or 1)+.5)
    if pw~=self.width or ph~=self.height then
      if self.canvas then self.canvas:release();self.depth:release() end
      local samples=math.min(4,g.getSystemLimits().canvasmsaa or 0)
      self.canvas=g.newCanvas(pw,ph,{msaa=samples,dpiscale=1});self.depth=g.newCanvas(pw,ph,{format='depth24',readable=false,msaa=self.canvas:getMSAA(),dpiscale=1})
      self.width,self.height=pw,ph;self.msaa=self.canvas:getMSAA()
    end
    -- Keep the original 144-line vertical composition and reveal additional
    -- world at the sides on widescreen displays.  Geometry is never stretched.
    local quality=ph/144;local frameX,frameY=pw/2,78*quality
    local logicalWidth=pw/quality
    local editorCamera=p.editorCamera
    local mode=p.cameraMode or 'CHASE';local top=mode=='DEBUG_TOP'
    local cfg=w.art.camera_modes[mode] or w.art.camera_modes.CHASE
    local heading=p.cameraHeading or p.heading;local fx,fy=math.cos(heading),math.sin(heading)
    local pitch=editorCamera and editorCamera.pitch or math.rad(cfg.pitch);local cp,sp=math.cos(pitch),math.sin(pitch);local focal=80/math.tan(math.rad(editorCamera and editorCamera.fov or cfg.fov)*.5)
    local horizon=78-focal*math.tan(pitch)
    local ground=w:getGroundHeight(p.x,p.y);local z=ground+p.altitude*.2
    local cam={(p.cameraX or p.x)-fx*cfg.back,(p.cameraY or p.y)-fy*cfg.back,z+cfg.above}
    if editorCamera then
      cam={editorCamera.x,editorCamera.y,editorCamera.z}
      fx,fy=math.cos(editorCamera.heading),math.sin(editorCamera.heading)
      top=false
    end
    -- Offline QA only. Never set by gameplay controls or world data.
    if self.inspect then
      local center=assert(self.objectPositions[self.inspect.name]);local view=self.inspect.view
      local yaw=({FRONT=-math.pi/2,BACK=math.pi/2,LEFT=0,RIGHT=math.pi,TOP=-math.pi/2,CURRENT=-math.pi/2})[view]
      fx,fy=math.cos(yaw),math.sin(yaw);pitch=view=='TOP' and math.rad(89.9) or (view=='CURRENT' and math.rad(cfg.pitch) or math.rad(5))
      cp,sp=math.cos(pitch),math.sin(pitch);cam={center[1]-fx*80*cp,center[2]-fy*80*cp,center[3]+8+80*sp};top=false
    end
    local shader=self.shader
    local atmosphere=self.atmosphere
    local active=atmosphere.enabled and not top and not editorCamera and not self.inspect
    if self.atmosphereSupported then
    shader:send('FxTime',p.time or 0)
    shader:send('Haze',{atmosphere.haze_start,atmosphere.haze_end,active and atmosphere.hazeAmount or 0})
    shader:send('HazeColor',{.392,.549,.580})
    shader:send('WaterLayers',active and atmosphere.waterLayers or 0)
    shader:send('WaterSpeed',atmosphere.water_speed);shader:send('WaterBlend',atmosphere.water_blend)
    shader:send('ShadowVelocity',atmosphere.shadow_velocity);shader:send('ShadowScale',atmosphere.shadow_scale)
    shader:send('ShadowAmount',active and atmosphere.shadowAmount or 0)
    shader:send('LightAmount',active and atmosphere.lightAmount or 0)
    end
    g.push('all');g.setCanvas({self.canvas,depthstencil=self.depth});g.origin();g.setShader();g.setScissor();g.setColor(1,1,1)
    g.clear(w.art.ramps[1][1][1],w.art.ramps[1][1][2],w.art.ramps[1][1][3],1,0,1)
    g.setColor(w.art.ramps[1][3]);g.rectangle('fill',0,horizon*quality,pw,ph)
    g.setColor(w.art.ramps[1][2]);g.rectangle('fill',0,math.max(0,horizon-2)*quality,pw,4*quality)
    if self.horizon and not top and not editorCamera and not self.inspect then
      self.horizon:draw(pw,ph,quality,horizon,{world=w,camera=cam,heading=heading,
        logicalWidth=logicalWidth,focal=focal,pitch=pitch,far=cfg.far*1.2,time=p.time})
    end
    local clouds=self.worldClouds
    local cloudsActive=active and clouds and clouds.supported and atmosphere.cloud_mode=='WORLD'
      and (not self.effects or self.effects.config.enabled)
    local riderDepth=((p.x-cam[1])*fx+(p.y-cam[2])*fy)*cp-(z-cam[3])*sp
    local cloudContext={camera=cam,direction={fx,fy},pitch={cp,sp},focal=focal,
      quality=quality,far=cfg.far*1.2,frameCenter={frameX,frameY},riderDepth=riderDepth}
    local inside=0
    if cloudsActive then
      clouds:prepare(cloudContext,p.time or 0,atmosphere)
      inside=clouds:density(cam,p.time or 0,atmosphere)
    end
    self.cloudStats=cloudsActive and clouds.stats or {cards=0,front=0,back=0}
    self.cloudInside=inside
    local effectContext={quality=quality,logicalWidth=logicalWidth,horizon=horizon,top=top,worldClouds=cloudsActive}
    if self.effects then self.effects:drawSky(p,effectContext) end
    shader:send('Camera',cam);shader:send('Direction',{fx,fy});shader:send('Pitch',{cp,sp});shader:send('Focal',focal);shader:send('Quality',quality);shader:send('Far',cfg.far*1.2);shader:send('Top',top);shader:send('FrameCenter',{frameX,frameY})
    local ac=w.art.camera;local cx,cy=Stylized.project(w.maxX/2,w.maxY/2,0,ac)
    shader:send('TopCamera',{cx,cy,math.min((pw-12*quality)/(w.maxX+ac.shear*w.maxY),(ph-29*quality)/(w.maxY*ac.depth+w.maxX*ac.slope+w.config.max_height)),0});shader:send('TopProject',{ac.shear,ac.slope,ac.depth})
    g.setShader(shader);g.setDepthMode('less',true);g.setMeshCullMode('none');g.setColor(1,1,1)
    for _,b in ipairs(self.batches) do if (not top or b.objectName~='__BACKDROP__') and (not self.inspect or b.objectName==self.inspect.name) and (not self.editorHidden or not self.editorHidden[b.category]) then
      if self.atmosphereSupported then shader:send('WaterSurface',b.water) end
      local ramps=(b.category=='buildings' and w.originalSoaringRamps) or w.art.ramps
      for i=1,4 do shader:send('Tone'..i-1,ramps[b.col][i]) end;g.draw(b.mesh)
    end end
    g.setShader();g.setDepthMode()
    if self.effects and not self.inspect then self.effects:drawWorld(p,effectContext) end
    if cloudsActive then clouds:draw(cloudContext,false) end
    if not top and not self.inspect and not editorCamera then
      local dxs,dys,dzs=p.x-cam[1],p.y-cam[2],ground-cam[3]
      local fs=dxs*fx+dys*fy;local ds=fs*cp-dzs*sp
      if ds>4 then
        g.setColor(w.palette[1]);g.ellipse('fill',frameX+(-dxs*fy+dys*fx)*focal/ds*quality,frameY-(fs*sp+dzs*cp)*focal/ds*quality,4*quality,quality)
      end
      local dx,dy,dz=p.x-cam[1],p.y-cam[2],z-cam[3];local forward=dx*fx+dy*fy;local depth=forward*cp-dz*sp
      if depth>4 then
        local bx=frameX+(-dx*fy+dy*fx)*focal/depth*quality;local by=frameY-(forward*sp+dz*cp)*focal/depth*quality
        if self.flightSprite and self.flightSpriteQuads then
          local cycle={1,2,3,2}
          local frame=cycle[math.floor((p.time or 0)/0.15)%#cycle+1]
          local logicalSize=cfg.flight_sprite_size or 24
          local scale=logicalSize/flightFrameW*quality
          local visual=riderMotion and riderMotion:presentation(mode,w.config) or {roll=0,bob=0,scaleY=1,pitchOffset=0}
          local visualY=visual.bob+visual.pitchOffset
          effectContext.riderRect={bx/quality-logicalSize/2-6,by/quality+visualY-logicalSize*.52-6,
            bx/quality+logicalSize/2+6,by/quality+visualY+logicalSize*.48+6}
          g.setColor(1,1,1,1)
          g.draw(self.flightSprite,self.flightSpriteQuads[frame],bx,by+visualY*quality,visual.roll,
            scale,scale*visual.scaleY,flightFrameW/2,flightFrameH*.52)
        else
          effectContext.riderRect={bx/quality-14,by/quality-10,bx/quality+14,by/quality+10}
          g.setColor(w.palette[1]);g.polygon('fill',bx-8*quality,by,bx-2*quality,by-3*quality,bx,by-2*quality,bx+2*quality,by-3*quality,bx+8*quality,by,bx+2*quality,by+2*quality,bx,by+4*quality,bx-2*quality,by+2*quality)
          g.setColor(w.palette[5]);g.polygon('fill',bx-6*quality,by,bx-2*quality,by-2*quality,bx,by,bx+2*quality,by-2*quality,bx+6*quality,by,bx,by+2*quality)
          g.setColor(w.palette[6]);g.rectangle('fill',bx-quality,by-2*quality,2*quality,4*quality)
        end
      end
    end
    if cloudsActive then clouds:draw(cloudContext,true);clouds:drawInside(inside,pw,ph) end
    if self.effects and not self.inspect then self.effects:drawForeground(p,effectContext) end
    g.pop();g.push('all');g.origin();g.setShader();g.setColor(1,1,1)
    local nightAmount=dayNight and not editorCamera and not self.inspect
      and dayNight:effectiveAmount(w.config) or 0
    if self.nightShader and nightAmount>.001 then
      self.nightShader:send('NightAmount',nightAmount);g.setShader(self.nightShader)
    end
    g.draw(self.canvas,0,0,0,width/pw,height/ph)
    g.setShader()
    if not self.nightShader and nightAmount>.001 then
      -- Shader fallback keeps the scene readable on a device rejecting this
      -- tiny composite. It affects only the scene blit, never its HUD.
      g.setColor(.08,.12,.25,math.min(.34,nightAmount*.34));g.rectangle('fill',0,0,width,height)
    end
    g.setColor(1,1,1,1)
    -- The editor skips the gameplay HUD, but must still unwind this draw pass.
    if editorCamera then g.pop();return end
    local hudWidth=math.max(160,math.floor(logicalWidth+.5))
    if not self.hud or self.hudWidth~=hudWidth then
      if self.hud then self.hud:release() end
      self.hud=g.newCanvas(hudWidth,144,{dpiscale=1});self.hud:setFilter('nearest','nearest');self.hudWidth=hudWidth
    end
    local hudX=math.floor((hudWidth-160)/2)
    g.setCanvas(self.hud);g.origin();g.clear(0,0,0,0);g.setColor(1,1,1,1)
    g.rectangle('fill',0,0,hudWidth,8);g.rectangle('fill',0,136,hudWidth,8)
    font.draw(mode:gsub('_',' ')..' ALT '..math.floor(p.altitude),hudX,0);font.draw('PAD FLY A/B ALT',hudX,136)
    if riderMotion and riderMotion.noticeTime>0 then
      g.setColor(.1,.16,.18,.96);g.rectangle('fill',hudX,9,104,8)
      g.setColor(1,1,1,1);font.draw(riderMotion.notice or 'RIDER MOTION',hudX+1,9)
    end
    if dayNight and dayNight.noticeTime>0 then
      local label=dayNight.notice or 'TOD TEST'
      local box=math.min(158,#label*8+2)
      g.setColor(.1,.16,.18,.96);g.rectangle('fill',hudX,18,box,8)
      g.setColor(1,1,1,1);font.draw(label,hudX+1,18)
    end
    g.pop();g.push('all');g.origin();g.setShader();g.setColor(1,1,1);g.draw(self.hud,0,0,0,width/hudWidth,height/144);g.pop()
  end
  return self
end
return M
