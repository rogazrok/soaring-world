-- Data only. No executable Lua in user-authored elevation files.
local E = { STEP = 16, MIN = -1, MAX = 3 }
function E.blank(id, def, cell)
  cell = cell or 32
  local h = { id=id, cell=cell, width=def.width*32/cell, height=def.height*32/cell, rows={} }
  for y=1,h.height do h.rows[y]={};for x=1,h.width do h.rows[y][x]=0 end end
  return h
end
function E.parse(text, id, def)
  local lines={}
  for line in text:gmatch('[^\r\n]+') do
    line=line:gsub('#.*',''):match('^%s*(.-)%s*$')
    if line~='' then lines[#lines+1]=line end
  end
  assert(lines[1]=='SOAR_HEIGHTMAP 1','Expected SOAR_HEIGHTMAP 1')
  assert(lines[2]=='map '..id,'Map ID mismatch')
  local cell=tonumber((lines[3] or ''):match('^cell (%d+)$'))
  assert(cell==32 or cell==16 or cell==8,'cell must be 32, 16 or 8')
  local w,h=(lines[4] or ''):match('^size (%d+) (%d+)$');w,h=tonumber(w),tonumber(h)
  assert(w==def.width*32/cell and h==def.height*32/cell,'Dimensions do not match map')
  assert(#lines==h+4,'Wrong row count')
  local out=E.blank(id,def,cell)
  for y=1,h do
    local row={}
    for token in lines[y+4]:gmatch('%S+') do
      assert(token:match('^%-?%d+$'),'Height must be an integer')
      local n=tonumber(token);assert(n>=E.MIN and n<=E.MAX,'Height outside -1..3')
      row[#row+1]=n
    end
    assert(#row==w,'Wrong column count at row '..y);out.rows[y]=row
  end
  return out
end
function E.encode(h)
  local lines={'SOAR_HEIGHTMAP 1','map '..h.id,'cell '..h.cell,('size %d %d'):format(h.width,h.height)}
  for _,row in ipairs(h.rows) do lines[#lines+1]=table.concat(row,' ') end
  return table.concat(lines,'\n')..'\n'
end
function E.attach(world, read)
  world.elevationWarnings={}
  for _,m in ipairs(world.maps) do
    local ok,text=pcall(read,'heightmaps/'..m.id..'.heightmap')
    local h
    if ok and text then
      local valid,result=pcall(E.parse,text,m.id,m.def)
      if valid then h=result else world.elevationWarnings[#world.elevationWarnings+1]=m.id..': '..tostring(result) end
    end
    m.elevation=h or E.blank(m.id,m.def)
  end
  function world:getGroundHeight(x,y)
    for _,m in ipairs(self.maps) do
      if x>=m.x and y>=m.y and x<m.x+m.width and y<m.y+m.height then
        local h=m.elevation
        -- Near a seam, subtraction can round an interior point onto width/height.
        local iy=math.min(h.height,math.floor((y-m.y)/h.cell)+1)
        local ix=math.min(h.width,math.floor((x-m.x)/h.cell)+1)
        return h.rows[iy][ix]*E.STEP,m.id
      end
    end
    return 0,nil
  end
end
return E
