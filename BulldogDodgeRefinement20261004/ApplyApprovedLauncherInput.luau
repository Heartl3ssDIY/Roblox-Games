-- Launcher Input approved by the user on 2026-10-04.
assert(game.PlaceId==95034648955135,"Wrong place")
assert(not game:GetService("RunService"):IsRunning(),"Keep Play stopped")
local bootstrap=game:GetService("ServerScriptService"):FindFirstChild("PlaygroundBootstrap")
assert(bootstrap and bootstrap:IsA("Script") and bootstrap.Sandboxed,"Expected sandboxed launcher")
local before=tostring(bootstrap.Capabilities)
local capabilities={}
for _,capability in ipairs(Enum.SecurityCapability:GetEnumItems()) do
 if bootstrap.Capabilities:Contains(SecurityCapabilities.new(capability)) or capability==Enum.SecurityCapability.Input then
  table.insert(capabilities,capability)
 end
end
bootstrap.Capabilities=SecurityCapabilities.new(table.unpack(capabilities))
assert(bootstrap.Capabilities:Contains(SecurityCapabilities.new(Enum.SecurityCapability.Input)))
return game:GetService("HttpService"):JSONEncode({script=bootstrap:GetFullName(),added="Input",before=before,after=tostring(bootstrap.Capabilities),sandboxed=bootstrap.Sandboxed,playStarted=false})
