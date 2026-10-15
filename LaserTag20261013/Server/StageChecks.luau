assert(not game:GetService("RunService"):IsRunning(), "Edit only")
assert(not game.ServerStorage:FindFirstChild("LaserTagNativeCandidate20261013"), "Previous candidate still exists")
local candidate=game.ServerScriptService.StuckInTheMudService:Clone()
candidate.Name="LaserTagNativeCandidate20261013"
candidate.Source="return function(env)\nlocal game,workspace=env.game,env.workspace\nlocal typeof=env.typeof\nlocal task=env.task\n"..candidate.Source.."\nend"
candidate.Parent=game.ServerStorage
return "Fresh live candidate staged for NativeChecks.luau"
