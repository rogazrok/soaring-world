-- Fixed oblique projection. Shared by terrain, camera, marker and ground shadow.
local Renderer = {}
function Renderer.project(x,y,z) return x-0.35*y, 0.58*y+0.203*x-(z or 0) end
function Renderer.new(world,getTileset,getImage,World)
  local self={batches={},stats={cells=0,walls=0,seamWalls=0,vertices=0}}
  function self:release()
    for _,b in ipairs(self.batches) do if b.mesh then b.mesh:release() end;if b.texture then b.texture:release() end end
    self.batches={}
  end
  local ok,err=pcall(function()
    local cells={}
    for _,m in ipairs(world.maps) do
      local cell=m.elevation and m.elevation.cell or 32
      for y=0,m.height-cell,cell do for x=0,m.width-cell,cell do
        cells[#cells+1]={m=m,x=m.x+x,y=m.y+y,lx=x,ly=y,size=cell}
      end end
    end
    table.sort(cells,function(a,b)
      local da,db=a.y+0.35*a.x,b.y+0.35*b.x
      if da~=db then return da<db end
      return a.x<b.x
    end)
    local current,vertices
    local function flush()
      if current and #vertices>0 then
        current.mesh=love.graphics.newMesh(vertices,'triangles','static')
        current.mesh:setTexture(current.texture)
        self.stats.vertices=self.stats.vertices+#vertices
      end
    end
    local function height(x,y)
      if not world.getGroundHeight then return 0 end
      return world:getGroundHeight(x,y)
    end
    for _,c in ipairs(cells) do
      local ts=assert(getTileset(c.m.def.tileset),'Missing tileset')
      if not current or current.id~=c.m.def.tileset then
        flush()
        local image=getImage(assert(ts.image,'Missing atlas'))
        local iw,ih=image:getDimensions()
        current={id=c.m.def.tileset,iw=iw,ih=ih,perRow=ts.tilesPerRow or math.floor(iw/8)}
        self.batches[#self.batches+1]=current;vertices={}
        -- One extra white row supplies solid wall colors in the same mesh draw.
        current.texture=love.graphics.newCanvas(iw,ih+1)
        current.texture:setFilter('nearest','nearest')
        love.graphics.push('all')
        love.graphics.setCanvas(current.texture);love.graphics.origin();love.graphics.setShader()
        love.graphics.setScissor();love.graphics.setColor(1,1,1,1);love.graphics.clear(0,0,0,0)
        love.graphics.setBlendMode('alpha','premultiplied')
        love.graphics.draw(image,0,0);love.graphics.rectangle('fill',0,ih,iw,1)
        love.graphics.pop()
      end
      local function vertex(x,y,z,u,v,r,g,b)
        local px,py=Renderer.project(x,y,z)
        return {px,py,u,v,r or 1,g or 1,b or 1,1}
      end
      local function quad(a,b,c,d)
        vertices[#vertices+1]=a;vertices[#vertices+1]=b;vertices[#vertices+1]=c
        vertices[#vertices+1]=a;vertices[#vertices+1]=c;vertices[#vertices+1]=d
      end
      local z=height(c.x+0.1,c.y+0.1)
      for dy=0,c.size-8,8 do for dx=0,c.size-8,8 do
        local tile=World.tileAt(c.m.def,ts,(c.lx+dx)/8,(c.ly+dy)/8)
        local u,v=(tile%current.perRow)*8,math.floor(tile/current.perRow)*8
        assert(u+8<=current.iw and v+8<=current.ih,'Tile outside atlas')
        local u0,u1=u/current.iw,(u+8)/current.iw
        local v0,v1=v/(current.ih+1),(v+8)/(current.ih+1)
        local x,y=c.x+dx,c.y+dy
        quad(vertex(x,y,z,u0,v0),vertex(x+8,y,z,u1,v0),vertex(x+8,y+8,z,u1,v1),vertex(x,y+8,z,u0,v1))
      end end
      -- Sample edges in tile-size segments, also supporting 8/16 grids next door.
      local function wall(x1,y1,x2,y2,nx,ny,shade)
        local nz,id=height(nx,ny)
        if not id then nz=-32 end -- outer foundation, not a false seam between maps
        if z<=nz then return end
        local u,v=0.5/current.iw,(current.ih+0.5)/(current.ih+1)
        local function at(x,y,h) return vertex(x,y,h,u,v,shade,shade*0.86,shade*0.64) end
        quad(at(x1,y1,z),at(x2,y2,z),at(x2,y2,nz),at(x1,y1,nz))
        self.stats.walls=self.stats.walls+1
        if id and id~=c.m.id then self.stats.seamWalls=self.stats.seamWalls+1 end
      end
      for a=0,c.size-8,8 do
        wall(c.x+a,c.y+c.size,c.x+a+8,c.y+c.size,c.x+a+4,c.y+c.size+0.1,0.53)
        wall(c.x+c.size,c.y+a+8,c.x+c.size,c.y+a,c.x+c.size+0.1,c.y+a+4,0.38)
      end
      self.stats.cells=self.stats.cells+1
    end
    flush()
  end)
  if not ok then self:release();error(err,0) end
  function self:draw(p)
    local g=love.graphics;local scale=70/p.altitude
    local cx,cy=Renderer.project(p.cameraX,p.cameraY,0)
    g.setColor(0.12,0.16,0.21,1);g.rectangle('fill',0,0,160,144)
    g.push();g.translate(80,108);g.scale(scale);g.translate(-cx,-cy)
    g.setColor(1,1,1,1)
    for _,b in ipairs(self.batches) do g.draw(b.mesh) end
    g.pop()
    local px,py=Renderer.project(p.x,p.y,0)
    local sx,sy=80+(px-cx)*scale,108+(py-cy)*scale
    local ground=world.getGroundHeight and world:getGroundHeight(p.x,p.y) or 0
    g.setColor(0,0,0,0.5);g.ellipse('fill',sx,sy-ground*scale,5,2)
    -- Absolute flight altitude: never derived from the heightmap (max ground=48).
    local birdY=sy-p.altitude*scale+math.sin(p.time*3)*1.2
    g.setColor(1,0.85,0.2,1);g.polygon('fill',sx,birdY-4,sx-7,birdY+3,sx,birdY+1,sx+7,birdY+3)
    g.setColor(0.08,0.08,0.08,1);g.setLineWidth(1);g.polygon('line',sx,birdY-4,sx-7,birdY+3,sx,birdY+1,sx+7,birdY+3)
    g.setColor(1,1,1,1)
  end
  return self
end
return Renderer
