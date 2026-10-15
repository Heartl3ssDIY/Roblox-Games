assert(not game:GetService("RunService"):IsRunning(), "Keep Play stopped")
local target=game.ServerScriptService.PlaygroundBootstrap
local before=tostring(target.Capabilities)
local backup=game.ServerStorage:FindFirstChild("WeaponRigUpdateBackup20261004")
assert(backup,"Backup folder missing")
if not backup:FindFirstChild("PlaygroundBootstrap.AnimationApproval") then
 local saved=Instance.new("ObjectValue") saved.Name="PlaygroundBootstrap.AnimationApproval" saved.Value=target
 saved:SetAttribute("CapabilitiesBefore",before)
 saved:SetAttribute("UserApproved", "Approve launcher Animation")
 saved.Parent=backup
end
if not before:find("Animation",1,true) then
 local values={}
 for name in before:gmatch("[^|]+") do table.insert(values,Enum.SecurityCapability[name:match("^%s*(.-)%s*$")]) end
 table.insert(values,Enum.SecurityCapability.Animation)
 target.Capabilities=SecurityCapabilities.new(table.unpack(values))
end
return {target=target:GetFullName(),before=before,after=tostring(target.Capabilities),playStarted=false}
