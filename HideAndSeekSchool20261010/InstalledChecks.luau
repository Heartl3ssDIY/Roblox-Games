assert(not game:GetService("RunService"):IsRunning(), "Edit only")
local module = game.ServerScriptService.HideAndSeekService
local Service = require(module)
local arena = workspace["Hide and Seek"]
local service = Service.new(arena, game.ReplicatedStorage.HideAndSeekState)
local ok, result = xpcall(function()
 service.lobbySpawn = workspace["Playground Lobby"].Gameplay.LobbySpawn
 service:_bindLockers()
 local count = 0
 for model, locker in service.lockers do
  count += 1
  assert(service:_exitClear({}, locker), "Blocked installed locker exit: " .. model.Name)
 end
 assert(count == 20, "Missing locker bindings")
 assert(arena:GetAttribute("MaxPlayers") == 16 and arena:GetAttribute("RoundDuration") == 180, "Wrong installed rules")
 service:Stop()
 assert(Service.GetRunningService() == nil, "Stopped service leaked")
 return {installedLockers=count, allExitsClear=true, rulesCorrect=true, stoppedCleanly=true}
end, debug.traceback)
if not ok then pcall(function() service:Stop() end) error(result) end
return result
