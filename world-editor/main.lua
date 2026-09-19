local root,M,w,renderer,canvas,terrainImage,heightImage
local mode,selected,brush,radius,level='objects',nil,1,4,100
local status,dirty,preview,layer='Ready',false,false,'terrain'
local zoom,ox,oy=5,300,90
local history,redo={},{}
local kinds={'house_small','house_large','pokemon_center','poke_mart','gym','oak_lab','tree','tree_pine','tree_cluster','rock','mountain_peak','dock','cave','city','pallet'}
local kind=1
local function read(path) local f=io.open(root..'/'..path,'rb');if not f then return end;local s=f:read('*a');f:close();return s end
local function write(path,bytes)
 local dest=root..'/'..path;local old=read(path)
 if old then local f=assert(io.open(dest..'.bak','wb'));assert(f:write(old));f:close() end
 local f=assert(io.open(dest..'.tmp','wb'));assert(f:write(bytes));f:close()
 if old then assert(os.remove(dest)) end
 local ok,err=os.rename(dest..'.tmp',dest)
 if not ok then if old then local restore=assert(io.open(dest,'wb'));restore:write(old);restore:close() end;error(err) end
end
local function refresh()
 if terrainImage then terrainImage:release();heightImage:release() end
 terrainImage=love.graphics.newImage(w.terrain);heightImage=love.graphics.newImage(w.height)
 terrainImage:setFilter('nearest','nearest');heightImage:setFilter('nearest','nearest')
 if renderer then renderer:release() end;renderer=M.renderer(w)
end
local function snapshot()
 return {h=w.height:encode('png'):getString(),t=w.terrain:encode('png'):getString(),o=M.encode(w.objects)}
end
local function checkpoint() history[#history+1]=snapshot();if #history>30 then table.remove(history,1) end;redo={} end
local function restore(s)
 w.height:release();w.terrain:release()
 w.height=love.image.newImageData(love.filesystem.newFileData(s.h,'h.png'));w.terrain=love.image.newImageData(love.filesystem.newFileData(s.t,'t.png'))
 local f=assert(loadstring(s.o));w.objects=f();selected=nil;dirty=true;refresh()
end
local function reload()
 local nextWorld=M.load(read);local nextRenderer=M.renderer(nextWorld)
 if renderer then renderer:release() end
 if w then w.height:release();w.terrain:release() end
 w,renderer=nextWorld,nextRenderer;selected=nil;history={};redo={};dirty=false;refresh();status='Loaded world data'
end
local function save()
 write('world/kanto_height.png',w.height:encode('png'):getString())
 write('world/kanto_terrain.png',w.terrain:encode('png'):getString())
 write('world/kanto_objects.lua',M.encode(w.objects));dirty=false;status='Saved. In Soaring World press R.'
end
local function safely(fn) local ok,e=pcall(fn);if not ok then status=tostring(e) end;return ok end
local function pos(x,y) return (x-ox)/zoom,(y-oy)/zoom end
local function inside(x,y) return x>=0 and y>=0 and x<w.width and y<w.depth end
local function paint(x,y)
 for py=math.max(0,math.floor(y-radius)),math.min(w.depth-1,math.ceil(y+radius)) do
  for px=math.max(0,math.floor(x-radius)),math.min(w.width-1,math.ceil(x+radius)) do
   local d=math.sqrt((px-x)^2+(py-y)^2)
   if d<=radius then
    if mode=='terrain' then local c=M.codes[brush];w.terrain:setPixel(px,py,c[1]/255,c[2]/255,c[3]/255,1)
    else
     local old=w.height:getPixel(px,py);local v=level/255
     if mode=='raise' or mode=='lower' then v=old+(mode=='raise' and 1 or -1)*.035*(1-d/radius)
     elseif mode=='smooth' then
      local sum,n=0,0;for dy=-1,1 do for dx=-1,1 do if inside(px+dx,py+dy) then sum=sum+w.height:getPixel(px+dx,py+dy);n=n+1 end end end;v=sum/n
     end
     v=math.max(0,math.min(1,v));w.height:setPixel(px,py,v,v,v,1)
    end
   end
  end
 end
 dirty=true
end
local painting,drag=false,false
function love.load(args)
 root=assert(args[1],'Pass target mod folder');M=assert(loadfile(root..'/stylized.lua'))()
 canvas=love.graphics.newCanvas(160,144);canvas:setFilter('nearest','nearest');reload()
 if args[2]=='--selftest' then
  local original=snapshot();assert(w:getGroundHeight(0,0)>=0)
  checkpoint();mode='height';level=200;paint(48,60);assert(w.height:getPixel(48,60)>.7)
  restore(table.remove(history));assert(snapshot().h==original.h,'Undo height roundtrip')
  checkpoint();w.objects[#w.objects+1]={type='house_small',x=48,y=60,scale=1,z=3};dirty=true;save();reload();assert(w.objects[#w.objects].z==3)
  local n=#renderer.faces;assert(n>96*128,'Terrain plus props')
  restore(original);save();preview=true;status='SELFTEST PASS: paint, undo, object save/reload, mesh';print(status)
 end
end
function love.draw()
 local g=love.graphics;g.clear(.10,.12,.13);g.setColor(1,1,1)
 g.print('WORLD AUTHORING'..(dirty and ' * unsaved' or ''),15,15)
 local o=selected and w.objects[selected]
 local lines={
  'Tab: map / pixel preview','O: select / drag objects','H: height brush (absolute)','U / J: raise / lower','K: smooth','T: biome brush','V: terrain / grayscale',
  '[ / ]: brush radius '..radius,', / .: height '..level,'1..7: biome '..brush,'Wheel: zoom | middle: pan','',
  'N: add '..kinds[kind],'Q: next object type','Arrows: move selected','+ / -: scale','PgUp / PgDn: object height','E: rotate 15 degrees','D / F: cluster density',
  'Delete: remove object','Ctrl Z / Y: undo / redo','S: save (with .bak)','R: reload (confirm if dirty)','',
  'MODE: '..mode,
 }
 if o then lines[#lines+1]=o.name or o.type;lines[#lines+1]=string.format('x %.1f y %.1f z %.1f',o.x,o.y,o.z or 0);lines[#lines+1]=string.format('scale %.2f angle %.0f',o.scale or 1,o.rotation or 0) end
 g.print(table.concat(lines,'\n'),15,45)
 if preview then
  g.push('all');g.setCanvas(canvas);g.origin();renderer:draw({cameraX=w.maxX/2,cameraY=w.maxY/2,altitude=180},true);g.pop()
  g.setColor(1,1,1);local sc=math.min((g.getWidth()-310)/160,(g.getHeight()-130)/144);sc=math.max(1,math.floor(sc));g.draw(canvas,300,70,0,sc,sc)
 else
  g.setScissor(280,50,g.getWidth()-280,g.getHeight()-105);g.setColor(1,1,1);g.draw(layer=='height' and heightImage or terrainImage,ox,oy,0,zoom,zoom)
  for i,v in ipairs(w.objects) do
   g.setColor(i==selected and 1 or .95,i==selected and .3 or .95,.3);g.circle('line',ox+v.x*zoom,oy+v.y*zoom,5)
   if v.name then g.print(v.name,ox+v.x*zoom+6,oy+v.y*zoom) end
  end
  g.setScissor()
 end
 for i,c in ipairs(M.codes) do g.setColor(c[1]/255,c[2]/255,c[3]/255);g.rectangle('fill',300+(i-1)*105,20,16,16);g.setColor(1,1,1);g.print(i..' '..({'water','grass','forest','mountain','sand','city','road'})[i],320+(i-1)*105,20) end
 g.setColor(1,1,1);g.printf(status,15,g.getHeight()-45,g.getWidth()-30)
 if status:find('SELFTEST PASS',1,true) then
  love.graphics.captureScreenshot(function(im) write('world/editor-proof.png',im:encode('png'):getString());love.event.quit() end)
 end
end
function love.mousepressed(mx,my,b)
 if preview or mx<280 or my<50 then return end;local x,y=pos(mx,my);if not inside(x,y) then return end
 if b==1 then
  if mode=='objects' then
   selected=nil;local best=7/zoom
   for i,o in ipairs(w.objects) do local d=math.sqrt((x-o.x)^2+(y-o.y)^2);if d<best then best=d;selected=i end end
   if selected then checkpoint();drag=true end
  else checkpoint();painting=true;paint(x,y) end
 end
end
function love.mousemoved(mx,my,dx,dy)
 if love.mouse.isDown(3) then ox=ox+dx;oy=oy+dy end
 local x,y=pos(mx,my)
 if painting and inside(x,y) then paint(x,y) end
 if drag and selected and inside(x,y) then w.objects[selected].x=x;w.objects[selected].y=y;dirty=true end
end
function love.mousereleased(_,_,b) if b==1 and (painting or drag) then painting=false;drag=false;safely(refresh) end end
function love.wheelmoved(_,y) zoom=math.max(1,math.min(15,zoom+y)) end
function love.keypressed(key)
 local ctrl=love.keyboard.isDown('lctrl','rctrl');local o=selected and w.objects[selected]
 if key=='s' then safely(save)
 elseif key=='r' then if dirty then status='Discard unsaved changes? Y confirms.' else safely(reload) end
 elseif key=='y' and status=='Discard unsaved changes? Y confirms.' then safely(reload)
 elseif key=='y' and status=='Quit without saving? Y confirms.' then dirty=false;love.event.quit()
 elseif ctrl and key=='z' and #history>0 then redo[#redo+1]=snapshot();restore(table.remove(history))
 elseif ctrl and key=='y' and #redo>0 then history[#history+1]=snapshot();restore(table.remove(redo))
 elseif key=='tab' then preview=not preview;safely(refresh)
 elseif key=='v' then layer=layer=='height' and 'terrain' or 'height'
 elseif key=='o' then mode='objects'
 elseif key=='h' then mode='height';layer='height'
 elseif key=='u' then mode='raise';layer='height'
 elseif key=='j' then mode='lower';layer='height'
 elseif key=='k' then mode='smooth';layer='height'
 elseif key=='t' then mode='terrain';layer='terrain'
 elseif tonumber(key) and tonumber(key)>=1 and tonumber(key)<=7 then brush=tonumber(key)
 elseif key=='[' or key=='leftbracket' then radius=math.max(1,radius-1)
 elseif key==']' or key=='rightbracket' then radius=math.min(32,radius+1)
 elseif key==',' or key=='comma' then level=math.max(0,level-5)
 elseif key=='.' or key=='period' then level=math.min(255,level+5)
 elseif key=='q' then kind=kind%#kinds+1
 elseif key=='n' then
  checkpoint();local x,y=pos(love.mouse.getPosition());if not inside(x,y) then x,y=w.width/2,w.depth/2 end
  w.objects[#w.objects+1]={type=kinds[kind],x=x,y=y,scale=1,z=0};selected=#w.objects;dirty=true;safely(refresh)
 elseif o then
  local valid={left=true,right=true,up=true,down=true,['=']=true,['+']=true,['-']=true,kpadd=true,kpsubtract=true,pageup=true,pagedown=true,delete=true,e=true,d=true,f=true}
  if valid[key] then
   checkpoint()
   if key=='delete' then table.remove(w.objects,selected);selected=nil
   elseif key=='left' then o.x=math.max(0,o.x-1)
   elseif key=='right' then o.x=math.min(w.width-1,o.x+1)
   elseif key=='up' then o.y=math.max(0,o.y-1)
   elseif key=='down' then o.y=math.min(w.depth-1,o.y+1)
   elseif key=='pageup' then o.z=(o.z or 0)+1
   elseif key=='pagedown' then o.z=(o.z or 0)-1
   elseif key=='e' then o.rotation=((o.rotation or 0)+15)%360
   elseif key=='d' then o.density=math.min(1,(o.density or w.config.tree_density)+.1)
   elseif key=='f' then o.density=math.max(0,(o.density or w.config.tree_density)-.1)
   else o.scale=math.max(.1,(o.scale or 1)+((key=='-' or key=='kpsubtract') and -.1 or .1)) end
   dirty=true;safely(refresh)
  end
 end
end
function love.quit() if dirty then status='Quit without saving? Y confirms.';return true end end
