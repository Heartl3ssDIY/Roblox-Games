assert(not game:GetService("RunService"):IsRunning(), "Stop the playtest before restoring")
local storage=game:GetService("ServerStorage")
local backup=storage:FindFirstChild("BritishBulldogOriginal20261003")
assert(backup,"Original arena backup is missing")
local current=workspace:FindFirstChild("British Bulldog game")
if current then current:Destroy() end
local restored=backup:Clone()
restored.Name="British Bulldog game"
restored.Parent=workspace
for serviceName,names in pairs({ServerScriptService={"BritishBulldogBootstrap","BritishBulldogService","BritishBulldogRules","BritishBulldogStartRound"},StarterGui={"BritishBulldogHUD"},ReplicatedStorage={"BritishBulldogAssets","BritishBulldogState"},SoundService={"BritishBulldogMusic"}}) do
 local service=game:GetService(serviceName)
 for _,name in ipairs(names) do local instance=service:FindFirstChild(name) if instance then instance:Destroy() end end
end
local camera=game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("BritishBulldogCamera")
if camera then camera:Destroy() end
local lightingBackup=storage:FindFirstChild("BritishBulldogLightingBefore20261003")
if lightingBackup then
 local lighting=game:GetService("Lighting")
 for name,value in pairs(lightingBackup:GetAttributes()) do lighting[name]=value end
 for _,old in ipairs(lightingBackup:GetChildren()) do
  local instance=lighting:FindFirstChild(old.Name)
  if instance then instance:Destroy() end
  old:Clone().Parent=lighting
 end
end
return "Original four-part arena and lighting restored"
