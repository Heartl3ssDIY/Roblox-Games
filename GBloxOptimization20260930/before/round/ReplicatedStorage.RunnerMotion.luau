local config=require(script.Parent.RunnerConfig)
local M={}
function M.Speed(startedAt,multiplier,now)
 local elapsed=startedAt and math.max(0,(now or workspace:GetServerTimeNow())-startedAt) or 0
 return math.min(config.MaxRunSpeed,config.RunSpeed+config.RunAcceleration*elapsed)*(multiplier or 1)
end
function M.Forward(startedAt,multiplier,bonus,now)
 return M.Speed(startedAt,multiplier,now)+(bonus or 0)*(multiplier or 1)
end
return M
