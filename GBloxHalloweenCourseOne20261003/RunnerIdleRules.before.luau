-- Server-observed forward progress, not key presses or animation/vertical jitter.
local M={Timeout=15,MinimumProgress=1}
local function valid(n)
 return typeof(n)=="number" and n==n and math.abs(n)<math.huge
end
function M.New(now,progress,round)
 return {lastProgressAt=now,progress=valid(progress) and progress or nil,round=round,paused=false}
end
function M.Step(state,now,progress,round,active,paused)
 if not active then return nil,false,0 end
 if not state or state.round~=round then return M.New(now,progress,round),false,0 end
 if paused then
  state.lastProgressAt=now state.progress=valid(progress) and progress or nil state.paused=true
  return state,false,0
 end
 if state.paused then return M.New(now,progress,round),false,0 end
 if valid(progress) then
  if state.progress==nil or progress-state.progress>=M.MinimumProgress then
   state.progress=progress state.lastProgressAt=now
  end
 end
 local elapsed=math.max(0,now-state.lastProgressAt)
 return state,elapsed>=M.Timeout,elapsed
end
return M
