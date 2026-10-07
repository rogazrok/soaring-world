-- Gen 1-sized developer menu. Registered only when config.debugEnabled=true.
local M={}
local COMMANDS={
  'AREA','ANCHOR','PROFILE','REWARD','FORCE RANDOM','FORCE SELECTED',
  'ADD 1 STEP','ADD 100 STEPS','SET THRESH -1','TRIGGER NOW',
  'COMPLETE ACTIVE','RESET ACTIVE','RESET ALL','TEST ALL START','NEXT TEST CASE',
  'DISCOVER CURRENT','DISCOVER ALL REGULAR','RESET DISCOVERY','FORCE MEW AREA','MEW STATUS','RESET MEW STATE','GIVE DRAGON CALL','LANCE REPLAY',
}
local function clipped(s,n) s=tostring(s or '-');return #s>n and s:sub(1,n) or s end
local function step(list,index,dir)
  return (index-1+dir+#list)%#list+1
end
function M.new(game,mod,reg,H)
  local screen={game=game,isOpaque=true,selected=1,scroll=1,areaIndex=1,
    anchorIndex=1,profileIndex=1,rewardIndex=1,armed=false,confirmReset=false,message=''}
  local function close()
    if game.stack:top()==screen then game.stack:pop() end
  end
  local function area() return reg.areas[screen.areaIndex] end
  local function anchors()
    local out={{id='AUTO'}}
    local selected=area()
    if selected.fixedAnchor then return {selected.fixedAnchor} end
    for _,a in ipairs(reg.anchors) do
      for _,tag in ipairs(selected.tags) do
        for _,aTag in ipairs(a.tags) do
          if tag==aTag then out[#out+1]=a;break end
        end
        if out[#out]==a then break end
      end
    end
    return out
  end
  local function profiles()
    local out={{id='AUTO'}}
    for _,p in ipairs(area().encounterProfiles) do out[#out+1]=p end
    return out
  end
  local function rewardProfiles()
    local out={{id='AUTO'}}
    for _,id in ipairs(H.rewardProfileIds(area())) do out[#out+1]={id=id} end
    return out
  end
  local function choose(dir)
    local command=COMMANDS[screen.selected]
    if command=='AREA' then
      screen.areaIndex=step(reg.areas,screen.areaIndex,dir)
      screen.anchorIndex=1;screen.profileIndex=1;screen.rewardIndex=1
    elseif command=='ANCHOR' then
      local rows=anchors();screen.anchorIndex=step(rows,screen.anchorIndex,dir)
    elseif command=='PROFILE' then
      local rows=profiles();screen.profileIndex=step(rows,screen.profileIndex,dir)
    elseif command=='REWARD' then
      local rows=rewardProfiles();screen.rewardIndex=step(rows,screen.rewardIndex,dir)
    end
  end
  local function execute(command)
    local ok,reason
    if command=='LANCE REPLAY' then
      ok,reason=mod.exports.hiddenDebugAction('replayLance',{game=game})
      if ok then
        -- Restore overworld control before the queued scene starts.
        while game.stack:top() and game.stack:top()~=game.overworld do game.stack:pop() end
        return
      end
    elseif command=='GIVE DRAGON CALL' then
      ok,reason=mod.exports.hiddenDebugAction('giveDragonCall',{game=game})
    elseif command=='FORCE RANDOM' then
      ok,reason=H.forceSpawn(mod,reg,{replace=true})
    elseif command=='FORCE SELECTED' then
      local anchor=anchors()[screen.anchorIndex]
      local profile=profiles()[screen.profileIndex]
      local reward=rewardProfiles()[screen.rewardIndex]
      ok,reason=H.forceSpawn(mod,reg,{areaId=area().id,
        anchorId=anchor.id~='AUTO' and anchor.id or nil,
        profileId=profile.id~='AUTO' and profile.id or nil,
        rewardProfileId=reward.id~='AUTO' and reward.id or nil,replace=true,debugBypass=true})
    elseif command=='ADD 1 STEP' then ok,reason=H.debugSteps(mod,reg,'add1')
    elseif command=='ADD 100 STEPS' then ok,reason=H.debugSteps(mod,reg,'add100')
    elseif command=='SET THRESH -1' then ok,reason=H.debugSteps(mod,reg,'before')
    elseif command=='TRIGGER NOW' then ok,reason=H.debugSteps(mod,reg,'trigger')
    elseif command=='COMPLETE ACTIVE' then ok,reason=H.completeActive(mod,reg,nil,game)
    elseif command=='RESET ACTIVE' then ok=H.resetActive(mod,reg)
    elseif command=='RESET ALL' then
      if not screen.confirmReset then
        screen.confirmReset=true;screen.message='A AGAIN: RESET ALL';return
      end
      ok,reason=H.resetAll(mod,reg,game);screen.confirmReset=false
    elseif command=='TEST ALL START' then ok,reason=H.startTestAll(mod,reg)
    elseif command=='NEXT TEST CASE' then ok,reason=H.nextTestCase(mod,reg)
    elseif command=='DISCOVER CURRENT' then ok,reason=H.debugDiscovery(mod,reg,'current')
    elseif command=='DISCOVER ALL REGULAR' then ok,reason=H.debugDiscovery(mod,reg,'all')
    elseif command=='RESET DISCOVERY' then ok,reason=H.debugDiscovery(mod,reg,'reset')
    elseif command=='FORCE MEW AREA' then
      ok,reason=H.forceSpawn(mod,reg,{areaId='FORGOTTEN_PIER_01',debugBypass=true,replace=true})
    elseif command=='MEW STATUS' then
      local m=H.mewStatus(mod,reg)
      screen.message=('U:%s USED:%s GOT:%s'):format(m.unlocked and 'Y' or 'N',m.consumed and 'Y' or 'N',m.captured and 'Y' or 'N');return
    elseif command=='RESET MEW STATE' then
      if not screen.confirmReset then screen.confirmReset=true;screen.message='A AGAIN: RESET MEW';return end
      ok,reason=H.resetMew(mod,reg,game);screen.confirmReset=false
    else return end
    screen.message=ok and 'DONE' or clipped(reason,19)
  end
  function screen:update()
    local input=game.input
    if not self.armed then
      self.armed=not (input:isDown('a') or input:isDown('b')
        or input:isDown('up') or input:isDown('down'))
      return
    end
    if input:wasPressed('b') then
      if self.confirmReset then self.confirmReset=false;self.message='RESET CANCELLED'
      else close() end
      return
    end
    if input:wasPressed('up') then self.selected=step(COMMANDS,self.selected,-1)
    elseif input:wasPressed('down') then self.selected=step(COMMANDS,self.selected,1) end
    if self.selected<self.scroll then self.scroll=self.selected end
    if self.selected>=self.scroll+6 then self.scroll=self.selected-5 end
    if input:wasPressed('left') then choose(-1)
    elseif input:wasPressed('right') then choose(1) end
    if input:wasPressed('a') then execute(COMMANDS[self.selected]) end
  end
  function screen:onKeyPressed(key) game.input:keypressed(key) end
  function screen:onGamepadPressed(button) game.input:gamepadpressed(nil,button) end
  function screen:draw()
    local g=love.graphics;local font=mod.ui.Font
    g.push('all');g.setColor(1,1,1,1);g.rectangle('fill',0,0,160,144)
    local status=H.status(mod,reg);local active=status.active
    font.draw('HIDDEN DEBUG '..H.discoveryCount(mod,reg)..'/5',0,0)
    font.draw(('STEPS %d/%d'):format(status.steps,status.threshold),0,8)
    font.draw('ACTIVE '..clipped(active and active.areaId or 'NONE',13),0,16)
    font.draw('ANCHOR '..clipped(active and active.anchorId or '-',13),0,24)
    font.draw('PROFILE '..clipped(active and active.profileId or '-',12),0,32)
    local currentArea=active and reg.byId[active.areaId]
    local itemTaken=currentArea and H.rewardClaimed(mod,currentArea)
    font.draw(('D:%s V:%s C:%s R:%s T%s'):format(currentArea and H.isDiscovered(mod,currentArea) and 'Y' or 'N',
      active and active.visited and 'Y' or 'N',active and active.completed and 'Y' or 'N',
      itemTaken and 'Y' or 'N',status.testAll and '1' or '0'),0,40)
    local rewardProfile,rewardItem=H.rewardStatus(mod,reg,currentArea)
    font.draw('LOOT '..(rewardProfile or '-'),0,48)
    font.draw('ITEM '..(rewardItem or '-'),0,56)
    for row=0,5 do
      local i=self.scroll+row;local command=COMMANDS[i]
      if command then
        local label=command
        if command=='AREA' then label='AREA '..area().name
        elseif command=='ANCHOR' then label='ANCHOR '..anchors()[self.anchorIndex].id
        elseif command=='PROFILE' then label='PROFILE '..profiles()[self.profileIndex].id
        elseif command=='REWARD' then label='REWARD '..rewardProfiles()[self.rewardIndex].id end
        if i==self.selected then font.drawCode(0xED,0,64+row*8) end
        font.draw(clipped(label,19),8,64+row*8)
      end
    end
    font.draw(clipped(self.message,20),0,112)
    font.draw('A SELECT B BACK',0,128)
    g.pop()
  end
  return screen
end
return M
