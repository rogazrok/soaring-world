-- World-locked 360 degree horizon panorama. Camera translation never changes
-- the sampling; only heading and pitch select which part of the cylinder is seen.
local M={}
local WIDTH,HEIGHT=4096,1024
local PI=math.pi
local shaderSource=[[ 
extern Image Panorama;
extern vec4 Frame; // quality, logical width, horizon y, unused
extern vec3 View; // heading, cosine pitch, focal length
vec4 effect(vec4 color,Image image,vec2 uv,vec2 screen) {
  float x=screen.x/Frame.x;
  float y=screen.y/Frame.x;
  // A wider sampled angle makes distant features read smaller.
  float angle=View.x+atan((x-Frame.y*0.5)*View.y/View.z)*1.08;
  float u=fract((angle+1.57079632679)/6.28318530718);
  float elevation=atan((Frame.z-y)/View.z);
  // Fit into 68 degrees vertically (was 90) and lift the panorama by 2 degrees.
  float v=clamp(0.5-(elevation-0.03490658504)/1.18682389136,0.0,1.0);
  return Texel(Panorama,vec2(u,v))*color;
}
]]
function M.new(read)
  local path='generated/horizons/soaring_panorama_360.png'
  local data=love.image.newImageData(love.filesystem.newFileData(assert(read(path)),path))
  assert(data:getWidth()==WIDTH and data:getHeight()==HEIGHT,'360 panorama must be 4096x1024')
  local image=love.graphics.newImage(data)
  image:setFilter('nearest','nearest');image:setWrap('repeat','clamp')
  data:release()
  local self={image=image,shader=love.graphics.newShader(shaderSource)}
  function self:bind(shader,imageName,frameName,viewName,quality,logicalWidth,horizon,view)
    shader:send(imageName,self.image)
    shader:send(frameName,{quality,logicalWidth,horizon,0})
    shader:send(viewName,{view.heading,math.cos(view.pitch),view.focal})
  end
  function self:draw(width,height,quality,horizon,view)
    self:bind(self.shader,'Panorama','Frame','View',quality,view.logicalWidth,horizon,view)
    local g=love.graphics
    g.push('all');g.setShader(self.shader);g.setColor(1,1,1,1)
    g.rectangle('fill',0,0,width,height)
    g.pop()
  end
  function self:release() self.image:release();self.shader:release() end
  return self
end
return M
