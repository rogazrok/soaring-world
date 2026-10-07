-- Cooperative CPU/GPU preparation. Checkpoints are work boundaries, NOT frames.
-- Several resumes per update keep total loading time independent of their count.
local M={}
function M.new(build,clock)
  clock=clock or love.timer.getTime
  local self={ready=false,resumes=0,updates=0,workSeconds=0,started=clock()}
  self.thread=coroutine.create(function() return build(function() coroutine.yield() end) end)
  function self:step(dt)
    if self.ready then return end
    local start=clock()
    -- Leave room for audio/input/drawing, including devices running below 60 FPS.
    local budget=math.max(.008,math.min(.040,math.max(0,dt or 0)*.8))
    self.updates=self.updates+1
    repeat
      self.resumes=self.resumes+1
      local ok,result=coroutine.resume(self.thread)
      if not ok then self.error=tostring(result);self.ready=true
      elseif coroutine.status(self.thread)=='dead' then self.result=result;self.ready=true end
    until self.ready or clock()-start>=budget
    self.workSeconds=self.workSeconds+clock()-start
    if self.ready then self.wallSeconds=clock()-self.started;self.thread=nil end
  end
  return self
end
return M
