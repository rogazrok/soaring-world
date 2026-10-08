-- World-space cloud banks: a few sorted transparent billboards, not ray marching.
-- Positions and density never depend on player/camera position or heading.
local M={};local C={};C.__index=C
local format={{'VertexPosition','float',3},{'VertexTexCoord','float',2},{'VertexColor','float',4},{'VertexCloudShape','float',2}}
local source=[[
varying vec2 CloudShape;
#ifdef VERTEX
attribute vec2 VertexCloudShape;
uniform vec3 Camera;uniform vec2 Direction;uniform vec2 Pitch;
uniform float Focal;uniform float Quality;uniform float Far;uniform vec2 FrameCenter;
vec4 position(mat4 tp,vec4 v) {
  CloudShape=VertexCloudShape;
  vec3 d=v.xyz-Camera;
  float side=dot(d.xy,vec2(-Direction.y,Direction.x));
  float forward=dot(d.xy,Direction);
  float depth=forward*Pitch.x-d.z*Pitch.y;
  float up=forward*Pitch.y+d.z*Pitch.x;
  vec4 p=tp*vec4(FrameCenter.x*depth+side*Focal*Quality,FrameCenter.y*depth-up*Focal*Quality,0.0,depth);
  p.z=(Far+4.0)/(Far-4.0)*depth-8.0*Far/(Far-4.0);return p;
}
#endif
#ifdef PIXEL
float lobe(vec2 p,vec2 centre,vec2 radius) {
  vec2 d=(p-centre)/radius;
  return 1.0-smoothstep(0.25,1.0,dot(d,d));
}
vec4 effect(vec4 color,Image tex,vec2 uv,vec2 screen) {
  vec2 q=uv*2.0-1.0;
  // Overlapping asymmetric lobes form a cloud silhouette, rather than a disk.
  // Two stable shape values per card vary the crown, shoulders and underside.
  float a=CloudShape.x,b=CloudShape.y;
  float edge=lobe(q,vec2((a-.5)*.20,(b-.5)*.16),vec2(.62,.60));
  edge=max(edge,lobe(q,vec2(-.49,.03+a*.20),vec2(.43,.35+b*.11)));
  edge=max(edge,lobe(q,vec2(.46,-.10+b*.25),vec2(.42,.36+a*.10)));
  edge=max(edge,lobe(q,vec2(-.18+a*.38,-.39),vec2(.30+b*.15,.39)));
  edge=max(edge,lobe(q,vec2(.10-b*.28,.36),vec2(.40,.29+a*.10)));
  // Broad soft masses; no noise texture, realistic lighting or colour grading.
  float softness=0.82+0.18*(1.0-uv.y);
  return vec4(color.rgb*softness,color.a*edge);
}
#endif
]]
local function hash(i,s) return ((i*173+s*257)%997)/997 end
-- A private generator: cloud layout must not consume the game's encounter RNG.
local generation=0
local function randomSequence(seed)
  local state=math.floor(math.abs(seed))%2147483646+1
  return function() state=(state*48271)%2147483647;return state/2147483647 end
end
local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
local function smooth(a,b,v) local t=clamp((v-a)/(b-a),0,1);return t*t*(3-2*t) end
function M.new(world,seed)
  local ok,shader=pcall(love.graphics.newShader,source)
  local self=setmetatable({world=world,supported=ok,error=not ok and tostring(shader) or nil,banks={},meshes={}},C)
  if not ok then print('[Soaring] World clouds unavailable; screen clouds retained: '..self.error);return self end
  self.shader=shader
  generation=generation+1
  self.seed=seed or (os.time()+math.floor(os.clock()*1000000)+generation*104729)
  local random=randomSequence(self.seed)
  -- Best-candidate scattering keeps even LOW's first ten banks spread out.
  -- A fresh field is created on takeoff, never on camera movement/quality change.
  for i=1,24 do
    local x,y,best=nil,nil,-1
    for candidate=1,32 do
      local cx=(.05+.90*random())*world.maxX;local cy=(.05+.90*random())*world.maxY
      local nearest=math.huge
      for _,b in ipairs(self.banks) do
        local dx,dy=(cx-b.x)/world.maxX,(cy-b.y)/world.maxY
        nearest=math.min(nearest,dx*dx+dy*dy)
      end
      if nearest>best then x,y,best=cx,cy,nearest end
    end
    local mist=i%5==0;local ground=world:getGroundHeight(x,y)
    local bank={id=i,x=x,y=y,z=ground+(mist and 58 or 104+hash(i,11)*62),
      rx=mist and 210 or 100+hash(i,13)*65,ry=mist and 130 or 80+hash(i,17)*50,
      rz=mist and 35 or 78+hash(i,19)*27,mist=mist,puffs={}}
    for j=1,5 do
      bank.puffs[j]={(random()-.5)*bank.rx*.95,(random()-.5)*bank.ry*.95,(random()-.5)*bank.rz*.65,
        random(),random(),.85+random()*.40,.80+random()*.40}
    end
    self.banks[i]=bank
  end
  -- Fixed upper bound, reused each frame; at most 24 banks x 5 cards.
  for i=1,2 do self.meshes[i]=love.graphics.newMesh(format,24*5*6,'triangles','stream') end
  return self
end
function C:position(bank,time,cfg)
  local margin=400;local sx,sy=self.world.maxX+margin*2,self.world.maxY+margin*2
  local velocity=cfg.cloud_velocity
  local x=(bank.x+time*velocity[1]+margin)%sx-margin
  local y=(bank.y+time*velocity[2]+margin)%sy-margin
  local fade=smooth(-margin,-margin+100,x)*(1-smooth(self.world.maxX+margin-100,self.world.maxX+margin,x))
    *smooth(-margin,-margin+100,y)*(1-smooth(self.world.maxY+margin-100,self.world.maxY+margin,y))
  return x,y,bank.z,fade
end
function C:density(point,time,cfg)
  if not self.supported or not cfg.enabled or cfg.cloud_mode~='WORLD' or not cfg.local_mist then return 0 end
  local density=0
  for i=1,cfg.cloudBanks do
    local b=self.banks[i];local x,y,z,fade=self:position(b,time,cfg)
    local d=((point[1]-x)/b.rx)^2+((point[2]-y)/b.ry)^2+((point[3]-z)/b.rz)^2
    density=density+(1-smooth(.08,1,d))*fade*(b.mist and .09 or cfg.cloud_density)
  end
  return math.min(.72,density)
end
function C:prepare(ctx,time,cfg)
  self.back={};self.front={};self.stats={cards=0,back=0,front=0}
  if not self.supported or not cfg.enabled or cfg.cloud_mode~='WORLD' then return end
  local cards={};local cam=ctx.camera;local fx,fy=ctx.direction[1],ctx.direction[2]
  local cp,sp=ctx.pitch[1],ctx.pitch[2]
  local right={-fy,fx,0};local up={fx*sp,fy*sp,cp}
  for i=1,cfg.cloudBanks do
    local b=self.banks[i];local x,y,z,fade=self:position(b,time,cfg)
    for j=1,cfg.cloudPuffs do
      local seed=i*7+j
      local puff=b.puffs[j]
      local px,py,pz=x+puff[1],y+puff[2],z+puff[3]
      local dx,dy,dz=px-cam[1],py-cam[2],pz-cam[3]
      local depth=(dx*fx+dy*fy)*cp-dz*sp
      local width=b.rx*(.66+hash(seed,37)*.22)*puff[6];local height=b.rz*(.80+hash(seed,41)*.20)*puff[7]
      local distance=math.sqrt(dx*dx+dy*dy+dz*dz)
      -- Fade the nearest card away before the near-plane can slice its edge.
      local opacity=b.mist and math.min(cfg.cloud_opacity,.11) or cfg.cloud_opacity
      local alpha=opacity*fade*smooth(5,35,depth)*smooth(12,55,distance)*(1-smooth(ctx.far*.75,ctx.far,depth))
      if b.mist then alpha=alpha*.48 end
      if depth>5 and depth<ctx.far and alpha>.001 then
        cards[#cards+1]={x=px,y=py,z=pz,width=width,height=height,depth=depth,alpha=alpha,id=seed,shape=puff}
      end
    end
  end
  table.sort(cards,function(a,b) if a.depth==b.depth then return a.id<b.id end;return a.depth>b.depth end)
  for _,c in ipairs(cards) do
    local target=c.depth>=ctx.riderDepth and self.back or self.front
    for _,uv in ipairs({{0,0},{1,0},{1,1},{0,0},{1,1},{0,1}}) do
      local sx,sy=(uv[1]*2-1)*c.width,(1-uv[2]*2)*c.height
      target[#target+1]={c.x+right[1]*sx+up[1]*sy,c.y+right[2]*sx+up[2]*sy,c.z+up[3]*sy,
        uv[1],uv[2],.94,.96,.94,c.alpha,c.shape[4],c.shape[5]}
    end
  end
  self.stats.back=#self.back/6;self.stats.front=#self.front/6;self.stats.cards=#cards
end
function C:draw(ctx,front)
  local vertices=front and self.front or self.back;if not vertices or #vertices==0 then return end
  local g=love.graphics;local shader=self.shader;local mesh=self.meshes[front and 2 or 1]
  mesh:setVertices(vertices);mesh:setDrawRange(1,#vertices)
  shader:send('Camera',ctx.camera);shader:send('Direction',ctx.direction);shader:send('Pitch',ctx.pitch)
  shader:send('Focal',ctx.focal);shader:send('Quality',ctx.quality);shader:send('Far',ctx.far);shader:send('FrameCenter',ctx.frameCenter)
  g.push('all');g.setShader(shader);g.setDepthMode('less',false);g.setMeshCullMode('none');g.setBlendMode('alpha');g.setColor(1,1,1,1)
  g.draw(mesh);g.pop()
end
function C:drawInside(amount,width,height)
  if amount<=.001 then return end
  local g=love.graphics;g.push('all');g.setShader();g.setDepthMode();g.setColor(.89,.93,.91,amount)
  g.rectangle('fill',0,0,width,height);g.pop()
end
function C:release()
  for _,m in ipairs(self.meshes) do m:release() end
  if self.shader then self.shader:release() end
end
return M
