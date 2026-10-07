-- Shared departure cinema. PNG is the user's unmodified 9x48x48 v2 sheet.
local M={}
local phases={{'fade',.35},{'whistle',.50},{'arrival',.56},{'wait',.18},
  {'jump',16/60},{'board',.16},{'takeoff',.56},{'cover',.16}}
function M.pose(time)
  local elapsed=0
  for _,phase in ipairs(phases) do
    if time<elapsed+phase[2] then
      local t=time-elapsed;local name=phase[1]
      local frame=name=='arrival' and ({1,2,3,2})[math.min(4,math.floor(t/.14)+1)]
        or (name=='wait' or name=='jump') and 4
        or name=='board' and 5
        or name=='takeoff' and math.min(9,6+math.floor(t/.14))
        or name=='cover' and 9 or nil
      return {phase=name,frame=frame,progress=t/phase[2],
        rider=frame and frame>=5 or false,alpha=name=='cover' and t/phase[2] or 0}
    end
    elapsed=elapsed+phase[2]
  end
  return {phase='done',frame=9,rider=true,alpha=1}
end
function M.landingPose(time)
  local phases={{'descent',.56},{'board',.18},{'dismount',16/60},{'wait',.12},{'departure',.56}}
  local elapsed=0
  for _,phase in ipairs(phases) do
    if time<elapsed+phase[2] then
      local t=time-elapsed;local name=phase[1]
      local frame=name=='descent' and math.max(6,9-math.floor(t/.14))
        or name=='board' and 5 or (name=='dismount' or name=='wait') and 4
        or ({1,2,3,2})[math.min(4,math.floor(t/.14)+1)]
      return {phase=name,frame=frame,progress=t/phase[2],rider=frame>=5,alpha=0}
    end
    elapsed=elapsed+phase[2]
  end
  return {phase='done',rider=false,alpha=0}
end
function M.new(game,mod,ow,onDone,onAbort,landing,nightAmount)
  -- Validate the asset before closing menus or mutating player state.
  local image=mod.assets:image('assets/dragonite_sequence_v2.png')
  assert(image:getWidth()==432 and image:getHeight()==48,'Dragonite v2 sheet must be 432x48')
  image:setFilter('nearest','nearest')
  local quads={};for n=1,9 do quads[n]=love.graphics.newQuad((n-1)*48,0,48,48,432,48) end
  local player=ow.player
  local saved={px=player.px,py=player.py,facing=player.facing,hidden=ow.playerHidden,
    locked=player.inputLocked,hopFrames=player.hopFrames,hopTotal=player.hopTotal,
    ledgeHop=player.ledgeHop,onBike=player.onBike}
  local pose=landing and M.landingPose or M.pose
  nightAmount=math.max(0,math.min(1,tonumber(nightAmount) or 0))
  local screen={game=game,isOpaque=false,dragonTakeoff=not landing,dragonLanding=landing,
    time=0,pose=pose(0),ow=ow,nightAmount=nightAmount}
  local Music=require('src.core.Music')
  function screen:enter()
    player.inputLocked=true;player.onBike=false;player.facing=landing and 'left' or 'right'
    ow.playerHidden=landing or false
    if not landing then Music.fadeOut(3) end
  end
  function screen:update(dt)
    self.time=self.time+math.max(0,math.min(dt or 0,.1))
    self.pose=pose(self.time)
    if self.pose.phase=='whistle' and not self.whistled then
      self.whistled=true;require('src.core.Sound').play(game.data,'SWR_DRAGON_WHISTLE')
    end
    if self.pose.phase=='board' and not self.cried then
      self.cried=true;require('src.core.Sound').playCry(game.data,'DRAGONITE')
    end
    if self.pose.phase=='jump' then
      -- Native Player:pose() renders the original 32-frame ledge arc/shadow.
      -- Only its rising half plays; the apex switches to the supplied rider.
      player.hopTotal=32;player.ledgeHop=true
      player.hopFrames=32-math.min(16,math.floor(self.pose.progress*16))
      player.px=saved.px+math.floor(20*self.pose.progress+.5)
    end
    if self.pose.phase=='dismount' then
      -- Falling half of the same native ledge jump; no second rider sprite.
      player.hopTotal=32;player.ledgeHop=true
      player.hopFrames=16-math.min(16,math.floor(self.pose.progress*16))
      player.px=saved.px-math.floor(20*(1-self.pose.progress)+.5)
    elseif landing and not self.pose.rider then
      player.px=saved.px;player.hopFrames=0
    end
    ow.playerHidden=self.pose.rider
    self.musicAccum=(self.musicAccum or 0)+(dt or 0)
    while self.musicAccum>=1/60 do Music.update(game.data);self.musicAccum=self.musicAccum-1/60 end
    if self.pose.phase=='done' and not self.finished then
      self.finished=true
      if game.stack:top()==self then game.stack:pop() end
      onDone()
    end
  end
  function screen:draw()
    local g=love.graphics
    -- The frozen native overworld underneath draws once, with its palette.
    local FX=require('src.render.PaletteFX')
    g.setCanvas(game.renderer.worldCanvas);FX.setPass('world')
    if self.pose.frame then
      g.push('all');g.setShader();g.setColor(1,1,1,1)
      local cam=ow.camera
      -- Mirrored frame5's rider is centered here; match the first native
      -- dismount frame (px-20 + the native sprite's 8px center).
      local x=saved.px+(landing and -12 or 30)-cam.x
      local y=saved.py+24-cam.y
      if self.pose.phase=='arrival' then y=y-(1-self.pose.progress)*(y+48) end
      if self.pose.phase=='descent' then y=y-(1-self.pose.progress)*(y+48) end
      if self.pose.phase=='departure' then y=y-self.pose.progress*(y+48) end
      -- Frames 7/8/9 already contain 1/4/7px lift: keep this anchor fixed.
      local dx,dy=math.floor(x+.5)-24,math.floor(y+.5)-42
      local sx=landing and -1 or 1
      if landing then dx=dx+48 end
      -- Tint only the custom Dragonite/Red frames to match the frozen native
      -- overworld lighting. The underlying map keeps its normal engine render.
      g.setColor(1-self.nightAmount*.50,1-self.nightAmount*.37,1-self.nightAmount*.16,1)
      g.draw(image,quads[self.pose.frame],dx,dy,0,sx,1)
      FX.markSpriteRedraw(image,quads[self.pose.frame],dx,dy,sx)
      g.pop()
    end
    game.renderer:endWorldPass()
    if self.pose.alpha>0 then
      game.renderer.screenVeil={0,self.pose.alpha}
    end
  end
  function screen:exit()
    player.px,player.py,player.facing=saved.px,saved.py,saved.facing
    player.inputLocked=saved.locked;ow.playerHidden=saved.hidden
    player.hopFrames,player.hopTotal,player.ledgeHop=saved.hopFrames,saved.hopTotal,saved.ledgeHop
    player.onBike=saved.onBike
    for _,quad in ipairs(quads) do quad:release() end
    if not self.finished and onAbort then onAbort() end
  end
  function screen:onKeyPressed(key) game.input:keypressed(key) end
  function screen:onGamepadPressed(button) game.input:gamepadpressed(nil,button) end
  return screen
end
return M
