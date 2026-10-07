-- Full-screen Dragonite departure image sequence shown while Soaring prepares.
local M={}
local FRAME_W,FRAME_H,COLS,COUNT=256,144,6,26
local FRAME_TIME,DURATION=.20,5.20
local WAIT_FRAMES={25,26,23,26} -- up, neutral, down, neutral
function M.new(mod,Wings,DayNight,nightAmount)
  local image=mod.assets:image('assets/soaring_loading_sheet.png')
  nightAmount=math.max(0,math.min(1,tonumber(nightAmount) or 0))
  local nightShader,nightShaderError
  if nightAmount>.001 and DayNight and DayNight.newShader then
    nightShader,nightShaderError=DayNight.newShader(love.graphics)
    if not nightShader then print('[Soaring] Loading night shader unavailable; using a simple tint fallback: '..tostring(nightShaderError)) end
  end
  assert(image:getWidth()==1536 and image:getHeight()==720,
    'Soaring loading sheet must be 1536x720')
  image:setFilter('nearest','nearest')
  local quads={}
  for i=1,COUNT do
    local x=((i-1)%COLS)*FRAME_W
    local y=math.floor((i-1)/COLS)*FRAME_H
    quads[i]=love.graphics.newQuad(x,y,FRAME_W,FRAME_H,1536,720)
  end
  local waitingImages={}
  local pixels=love.image.newImageData(love.filesystem.newFileData(
    assert(mod:read('assets/soaring_loading_sheet.png')),'soaring_loading_sheet.png'))
  local frames=Wings.compose(function(frame,x,y)
    local cell=frame-1
    local r,g,b=pixels:getPixel((cell%COLS)*FRAME_W+x,math.floor(cell/COLS)*FRAME_H+y)
    return math.floor(r*255+.5)*65536+math.floor(g*255+.5)*256+math.floor(b*255+.5)
  end)
  pixels:release()
  for frame,colors in pairs(frames) do
    local data=love.image.newImageData(FRAME_W,FRAME_H)
    for y=0,FRAME_H-1 do for x=0,FRAME_W-1 do
      local c=colors[y*FRAME_W+x+1]
      data:setPixel(x,y,math.floor(c/65536)/255,(math.floor(c/256)%256)/255,(c%256)/255,1)
    end end
    waitingImages[frame]=love.graphics.newImage(data,{mipmaps=false})
    waitingImages[frame]:setFilter('nearest','nearest');data:release()
  end
  local self={image=image,quads=quads,waitingImages=waitingImages,nightShader=nightShader,nightAmount=nightAmount,elapsed=0,frame=1,duration=DURATION}
  function self:update(dt)
    self.elapsed=self.elapsed+math.max(0,dt or 0)
    if self:finished() then
      local step=math.floor((math.max(0,self.elapsed-DURATION)+1e-9)/FRAME_TIME)
      self.frame=WAIT_FRAMES[step%#WAIT_FRAMES+1]
    else self.frame=math.min(COUNT,math.floor((self.elapsed+1e-9)/FRAME_TIME)+1) end
  end
  function self:finished() return self.elapsed+1e-9>=DURATION end
  function self:draw()
    local g=love.graphics
    local width,height=g.getDimensions()
    local scale=math.max(width/FRAME_W,height/FRAME_H)
    local drawW,drawH=FRAME_W*scale,FRAME_H*scale
    local x,y=(width-drawW)*.5,(height-drawH)*.5
    g.push('all');g.origin();g.setShader();g.setColor(1,1,1,1)
    g.setBlendMode('alpha')
    if self.nightShader then
      self.nightShader:send('NightAmount',self.nightAmount)
      g.setShader(self.nightShader)
    end
    local waitImage=self:finished() and self.waitingImages[self.frame]
    if waitImage then g.draw(waitImage,x,y,0,scale,scale)
    else g.draw(image,quads[self.frame],x,y,0,scale,scale) end
    if not self.nightShader and self.nightAmount>.001 then
      g.setShader()
      g.setColor(.08,.12,.25,math.min(.34,self.nightAmount*.34))
      g.rectangle('fill',0,0,width,height)
    end
    g.pop()
  end
  function self:release()
    for _,q in ipairs(quads) do q:release() end
    for _,img in pairs(self.waitingImages) do img:release() end
    if self.nightShader then self.nightShader:release() end
  end
  return self
end
return M
