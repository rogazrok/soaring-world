-- Visual continuation only. Never changes the playable heightmap or flight bounds.
local M={}
local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
-- Shared source mapping for exterior geometry and the horizon's view probes.
-- Coordinates are terrain cells, not world units. nil means the exterior sea.
function M.sourceCell(w,x,y,stride)
  if x>=w.width or y>=w.depth then return nil end
  stride=stride or math.max(2,math.floor(w.config.backdrop_grid_stride or 4))
  local dx,dy=math.max(0,-x),math.max(0,-y)
  local sx=x<0 and dx*.42+math.sin(y*.031)*stride*1.5*clamp(dx/(stride*2),0,1) or x
  local sy=y<0 and dy*.42+math.sin(x*.035)*stride*1.5*clamp(dy/(stride*2),0,1) or y
  return clamp(math.floor(sx),0,w.width-1),clamp(math.floor(sy),0,w.depth-1)
end
function M.build(w,ground,biome,emit,yieldBuild)
  local c,s=w.config,w.config.world_scale
  local checkpoint
  if yieldBuild then
    local work=0
    checkpoint=function(amount)
      work=work+(amount or 1)
      if work>=128 then work=0;yieldBuild() end
    end
  end
  local reach=math.max(c.backdrop_distance or c.draw_distance,0)
  if reach==0 then return end
  local stride=math.max(2,math.floor(c.backdrop_grid_stride or 4))
  local edges={}
  local function material(b) return (b==5 or b==6 or b==7) and 2 or b end
  -- One sampler for north, west AND their corner. Material and elevation refer
  -- to the same source cell. Waves of relief are strictly a land-only effect.
  local function sample(x,y)
    local sx,sy=M.sourceCell(w,x,y,stride)
    if not sx then return c.water_height,1 end
    local dx,dy=math.max(0,-x),math.max(0,-y)
    local b=material(biome(sx,sy));local z=ground(sx,sy)
    if b~=1 then
      local blend=clamp((math.sqrt(dx*dx+dy*dy)-stride)/(stride*8),0,1)
      z=math.max(c.water_height,z+(math.sin(x*.035+y*.012)+math.sin(x*.011-y*.027)*.55)*c.max_height*.12*blend)
    end
    return z,b
  end
  -- Sparse, reproducible scenery only. Never use gameplay RNG or add destinations.
  local baseSample=sample
  local scenery={lakes={},houses={},trees={}}
  w.backdropDressing=scenery
  if c.backdrop_dressing_enabled~=false then
    local seed=c.backdrop_dressing_seed or 260
    assert(type(seed)=='number' and seed==seed and seed>=0 and seed<=1000000,'Invalid backdrop dressing seed')
    local function hash(i,k)
      local n=(i*73+k*151+math.floor(seed)*37)%997
      return ((n*n*17+n*53+97)%997)/997
    end
    local span=math.min(160,reach/s-16)
    local occupied={}
    local function place(kind,sector,limit,radius)
      local list=scenery[kind];local placed=0
      for i=1,120 do
        if placed>=limit or span<=20 then break end
        local key=i+sector*137+({lakes=11,houses=271,trees=541})[kind]
        local a,b=20+hash(key,3)*(span-20),20+hash(key,7)*(span-20)
        local x=sector==1 and hash(key,11)*w.width or -a
        local y=sector==2 and hash(key,13)*w.depth or -b
        local supported=(x>=0 or c.backdrop_west) and (y>=0 or c.backdrop_north)
        local clear=supported;local lo,hi=math.huge,-math.huge
        for _,d in ipairs({{0,0},{-radius,0},{radius,0},{0,-radius},{0,radius},{-radius,-radius},{radius,radius},{-radius,radius},{radius,-radius}}) do
          local z,biome=baseSample(x+d[1],y+d[2])
          if biome~=2 and biome~=3 then clear=false end
          lo=math.min(lo,z);hi=math.max(hi,z)
        end
        if hi-lo>(kind=='lakes' and 2.2 or kind=='houses' and 1.6 or 3) then clear=false end
        for _,other in ipairs(occupied) do
          if (x-other.x)^2+(y-other.y)^2<(radius+other.radius+5)^2 then clear=false;break end
        end
        if clear then
          local item={x=x,y=y,z=hi,radius=radius}
          if kind=='trees' then item.z=select(1,baseSample(x,y))-.2 end
          if kind=='lakes' then item.z=lo+.02;item.rx=radius;item.ry=radius*(.7+hash(key,17)*.25) end
          list[#list+1]=item;occupied[#occupied+1]=item;placed=placed+1
        end
        if checkpoint then checkpoint(1) end
      end
    end
    for sector=1,3 do place('lakes',sector,1,8) end
    for sector=1,3 do place('houses',sector,2,4) end
    for sector=1,3 do place('trees',sector,18,2) end
    sample=function(x,y)
      for _,lake in ipairs(scenery.lakes) do
        if ((x-lake.x)/lake.rx)^2+((y-lake.y)/lake.ry)^2<=1 then return lake.z,1,lake end
      end
      return baseSample(x,y)
    end
  end
  local function addFace(points,b,wall)
    local f=emit(points,({1,3,2,6,5,4,5})[b],0,points[1][1],points[1][2])
    f.backdrop=true;f.biome=b;f.textured=true;f.worldPattern=not wall
    f.motif=not wall and w.art.terrain[b] or nil
    f.tile=wall and c.material_tiles.cliff or f.motif.tiles[1]
    f.shade=wall and .65 or 1;f.backdropWall=wall or nil
    return f
  end
  local function edge(axis,pos,a,b,za,zb,side)
    local key=axis..':'..pos;local line=edges[key]
    if not line then line={axis=axis,pos=pos,low={},high={}};edges[key]=line end
    line[side][#line[side]+1]={a=a,b=b,za=za,zb=zb}
  end
  local function patch(x0,y0,x1,y1,z,b,lake)
    local p={{x0*s,y0*s,z[1]},{x1*s,y0*s,z[2]},{x1*s,y1*s,z[3]},{x0*s,y1*s,z[4]}}
    local f=addFace(p,b)
    if lake then f.worldPatternPeriod=w.art.pattern_cells*s*.25 end
    edge('H',y0,x0,x1,z[1],z[2],'low');edge('H',y1,x0,x1,z[4],z[3],'high')
    edge('V',x0,y0,y1,z[1],z[4],'low');edge('V',x1,y0,y1,z[2],z[3],'high')
  end
  local function rect(x0,y0,x1,y1)
    local z,b,lake=sample((x0+x1)/2,(y0+y1)/2)
    -- Every water top is horizontal, including ocean and elevated inland water.
    -- A water material can never inherit a neighbouring mountain vertex.
    local zz=b==1 and {z,z,z,z} or {sample(x0,y0),sample(x1,y0),sample(x1,y1),sample(x0,y1)}
    patch(x0,y0,x1,y1,zz,b,lake)
  end
  local function negativeAxis(enabled)
    local a={0};if not enabled then return a end
    table.insert(a,1,-1)
    local d=1
    while d<reach/s do d=math.min(reach/s,d+stride);table.insert(a,1,-d) end
    return a
  end
  local function positiveAxis(size)
    local a={0};local x=0
    while x<size do x=math.min(size,x+stride);a[#a+1]=x end
    -- The exterior south/east ocean is a plane; do not tessellate empty sea.
    a[#a+1]=size+reach/s
    return a
  end
  local xs,ys=negativeAxis(c.backdrop_west),negativeAxis(c.backdrop_north)
  for _,x in ipairs(positiveAxis(w.width)) do if x>0 then xs[#xs+1]=x end end
  for _,y in ipairs(positiveAxis(w.depth)) do if y>0 then ys[#ys+1]=y end end
  -- All exterior sectors share the same axes. Include the formerly missing
  -- [-1,0] corner strips. The fine apron meets every playable cell exactly.
  for iy=1,#ys-1 do for ix=1,#xs-1 do
    local x0,x1,y0,y1=xs[ix],xs[ix+1],ys[iy],ys[iy+1]
    if x0<0 or y0<0 or x0>=w.width or y0>=w.depth then
      if y0==-1 and y1==0 and x0>=0 and x1<=w.width then
        for x=x0,x1-1 do
          local b=material(biome(x,0));local z=ground(x,0)
          local a=sample(x0,-1);local d=sample(x1,-1)
          local z0=a+(d-a)*(x-x0)/(x1-x0);local z1=a+(d-a)*(x+1-x0)/(x1-x0)
          patch(x,-1,x+1,0,b==1 and {z,z,z,z} or {z0,z1,z,z},b);if checkpoint then checkpoint(1) end
        end
      elseif x0==-1 and x1==0 and y0>=0 and y1<=w.depth then
        for y=y0,y1-1 do
          local b=material(biome(0,y));local z=ground(0,y)
          local a=sample(-1,y0);local d=sample(-1,y1)
          local z0=a+(d-a)*(y-y0)/(y1-y0);local z1=a+(d-a)*(y+1-y0)/(y1-y0)
          patch(-1,y,0,y+1,b==1 and {z,z,z,z} or {z0,z,z,z1},b);if checkpoint then checkpoint(1) end
        end
      else rect(x0,y0,x1,y1);if checkpoint then checkpoint(1) end end
    end
    if checkpoint then checkpoint(1) end
  end end
  for x=0,w.width-1 do
    if c.backdrop_north then local z=ground(x,0);edge('H',0,x,x+1,z,z,'low') end
    local z=ground(x,w.depth-1);edge('H',w.depth,x,x+1,z,z,'high')
    if checkpoint then checkpoint(1) end
  end
  for y=0,w.depth-1 do
    if c.backdrop_west then local z=ground(0,y);edge('V',0,y,y+1,z,z,'low') end
    local z=ground(w.width-1,y);edge('V',w.width,y,y+1,z,z,'high')
    if checkpoint then checkpoint(1) end
  end
  local function height(e,t) return e.za+(e.zb-e.za)*(t-e.a)/(e.b-e.a) end
  local function close(line,a,b,za,zb,qa,qb)
    if math.max(math.abs(za-qa),math.abs(zb-qb))<.00001 then return end
    if (za-qa)*(zb-qb)<0 then
      local t=(za-qa)/((za-qa)-(zb-qb));local m=a+(b-a)*t;local z=za+(zb-za)*t
      close(line,a,m,za,z,qa,z);close(line,m,b,z,zb,z,qb);return
    end
    local function point(t,z) return line.axis=='H' and {t*s,line.pos*s,z} or {line.pos*s,t*s,z} end
    addFace({point(a,za),point(b,zb),point(b,qb),point(a,qa)},4,true)
  end
  -- Match both coarse/coarse and fine/coarse edges. This also closes apron
  -- height jumps and water/land transitions without bridging water uphill.
  for _,line in pairs(edges) do
    table.sort(line.low,function(a,b) return a.a<b.a end)
    table.sort(line.high,function(a,b) return a.a<b.a end)
    local i,j=1,1
    while line.low[i] and line.high[j] do
      local p,q=line.low[i],line.high[j];local a,b=math.max(p.a,q.a),math.min(p.b,q.b)
      if b>a then close(line,a,b,height(p,a),height(p,b),height(q,a),height(q,b)) end
      if p.b<=q.b then i=i+1 end
      if q.b<=p.b then j=j+1 end
      if checkpoint then checkpoint(1) end
    end
    if checkpoint then checkpoint(1) end
  end
  -- Reuse imported Red roof/facade/tree motifs; a handful of closed primitives.
  local function detail(points,col,tile,motif,shade)
    local f=emit(points,col,0,points[1][1],points[1][2])
    f.backdrop=true;f.backdropDecoration=true;f.col=col;f.tile=tile;f.motif=motif
    f.textured=true;f.shade=shade or 1
  end
  local function box(x,y,z,a,b,h,sideCol,topCol,wallTile,roofTile,roofMotif,wallMotif)
    local bottom={{x-a,y-b,z},{x+a,y-b,z},{x+a,y+b,z},{x-a,y+b,z}}
    local top={{x-a,y-b,z+h},{x+a,y-b,z+h},{x+a,y+b,z+h},{x-a,y+b,z+h}}
    for i=1,4 do local j=i%4+1
      detail({top[i],top[j],bottom[j],bottom[i]},sideCol,wallTile,wallMotif,i==1 and .72 or .85)
    end
    detail(top,topCol,roofTile,roofMotif)
  end
  for _,o in ipairs(scenery.houses) do
    local x,y=o.x*s,o.y*s
    box(x,y,o.z-2,17,13,2,6,6,c.material_tiles.cliff,c.material_tiles.cliff)
    box(x,y,o.z,17,13,11,5,8,nil,nil,w.art.roofs.house,w.art.facade)
  end
  for i,o in ipairs(scenery.trees) do
    local x,y=o.x*s,o.y*s;local h=11+(i%3)*1.5
    box(x,y,o.z,1.2,1.2,h*.45,6,6,c.material_tiles.cliff,c.material_tiles.cliff)
    for _,tier in ipairs({{6,0.30,.23},{7.5,.46,.28},{5,.66,.26}}) do
      box(x,y,o.z+h*tier[2],tier[1],tier[1],h*tier[3],2,2,64,80)
    end
  end
end
return M
