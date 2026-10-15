assert(not game:GetService("RunService"):IsRunning(),"Stop Play before restoring the arena colours")
local arena=assert(workspace:FindFirstChild("Stuck in the Mud"))
local backup=assert(game.ServerStorage:FindFirstChild("LaserTagVisualBackup20261013"))
local restored=0
for _,ref in backup.ColourTargets:GetChildren() do
 if ref:IsA("ObjectValue") and ref.Value and ref.Value:IsA("BasePart") then
  ref.Value.Color=ref:GetAttribute("OriginalColor")
  restored+=1
 end
end
arena.Geometry:SetAttribute("LaserTagPaletteVersion",nil)
arena.Scenery:SetAttribute("LaserTagPaletteVersion",nil)
for _,name in {"HeatGun","MudGun"} do
 local gun=game.ReplicatedStorage.MudAssets:FindFirstChild(name)
 if gun then gun:SetAttribute("LaserTagPaletteVersion",nil) end
 local labels=backup:FindFirstChild("VisualMetadata")
 local original=labels and labels:FindFirstChild(name)
 if gun and original then gun.ToolTip=original:GetAttribute("OriginalToolTip") end
end
if backup:GetAttribute("OriginalDisplayNameWasNil") then arena:SetAttribute("GameDisplayName",nil)
else arena:SetAttribute("GameDisplayName",backup.OriginalDisplayName.Value) end
backup:SetAttribute("Installed",false)
return {partsRestored=restored}
