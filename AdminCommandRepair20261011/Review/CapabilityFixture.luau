local container = Instance.new("Folder")
container.Name = "AdminCapabilityAuditTemporary"
container.Parent = game.ServerStorage
local warnings = {}
local listener = game:GetService("LogService").MessageOut:Connect(function(message, kind)
 if message:find("Playground admin command failed:", 1, true) then table.insert(warnings, message) end
end)
local ok, output = xpcall(function()
 local adminClone = game.ServerScriptService.PlaygroundAdminService:Clone()
 adminClone.Name, adminClone.Parent = "AdminClone", container
 local coordinatorClone = game.ServerScriptService.PlaygroundCoordinator:Clone()
 coordinatorClone.Name, coordinatorClone.Parent = "CoordinatorClone", container
 local probe = Instance.new("ModuleScript")
 probe.Name, probe.Sandboxed, probe.Capabilities = "GameProbe", true, game.ServerScriptService.HideAndSeekService.Capabilities
 probe.Source = [=[
 local Service = {}
 function Service:StartRound(selected)
  if self.probe == "AnimationCreate" then
   local object = Instance.new("Animation")
   object.AnimationId = "rbxassetid://0"
   object:Destroy()
  elseif self.probe == "MotorTransform" then
   local object = Instance.new("Motor6D")
   object.Transform = CFrame.identity
   object:Destroy()
  elseif self.probe == "AnimatorTracks" then
   local object = Instance.new("Animator")
   object:GetPlayingAnimationTracks()
   object:Destroy()
  elseif self.probe == "InputRead" then
   local value = game:GetService("UserInputService").TouchEnabled
  elseif self.probe == "PromptConnect" then
   local object = Instance.new("ProximityPrompt")
   local c = object.Triggered:Connect(function() end)
   c:Disconnect()
   object:Destroy()
  end
  return true
 end
 return Service
 ]=]
 probe.Parent = container
 local Admin, Coordinator, Game = require(adminClone), require(coordinatorClone), require(probe)
 local config = Instance.new("Folder")
 config.Name, config.Parent = "Config", container
 config:SetAttribute("AdminUserId", 123)
 local state = Instance.new("Folder")
 state.Name, state.Parent = "State", container
 local actor = { UserId = 123, Name = "AuditOwner", DisplayName = "AuditOwner", GetAttribute = function()return nil end }
 local playerSource = { GetPlayers = function()return {} end, GetPlayerByUserId = function()return nil end }
 local result = {}
 for _, mode in ipairs({"NoOperation", "AnimationCreate", "MotorTransform", "AnimatorTracks", "InputRead", "PromptConnect"}) do
  local service = setmetatable({probe=mode}, {__index=Game})
  local coordinator = setmetatable({services={BritishBulldog=service},state=state,votes={},autoEnabled=false}, Coordinator)
  local admin = Admin.new(coordinator, config, true, playerSource)
  local before = #warnings
  local succeeded, reply = pcall(admin.Handle, admin, actor, "BBStart", {})
  task.wait()
  result[mode] = { succeeded=succeeded,reply=reply,warnings={} }
  for i=before+1,#warnings do table.insert(result[mode].warnings,warnings[i]) end
 end
 return result
end, debug.traceback)
listener:Disconnect()
container:Destroy()
return {ok=ok,result=output}

