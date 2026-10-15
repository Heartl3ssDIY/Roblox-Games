assert(not game:GetService("RunService"):IsRunning(),"Stop Play before updating the blaster labels")
local arena=assert(workspace:FindFirstChild("Stuck in the Mud"))
local backup=assert(game.ServerStorage:FindFirstChild("LaserTagVisualBackup20261013"))
local assets=game.ReplicatedStorage.MudAssets
if backup:FindFirstChild("VisualMetadata") then return {alreadyInstalled=true} end
local stored=Instance.new("Folder");stored.Name="VisualMetadata";stored.Parent=backup
local report={guns={},spawnCircleUpdates={}}
for name,label in {HeatGun="Red Laser Blaster",MudGun="Blue Laser Blaster"} do
 local gun=assert(assets:FindFirstChild(name))
 local ref=Instance.new("ObjectValue");ref.Name=name;ref.Value=gun
 ref:SetAttribute("OriginalToolTip",gun.ToolTip);ref:SetAttribute("InstalledToolTip",label);ref.Parent=stored
 table.insert(report.guns,{name=name,originalToolTip=gun.ToolTip,toolTip=label})
 gun.ToolTip=label
end
local chunkParts=backup.Manifest:GetChildren();table.sort(chunkParts,function(a,b) return a.Name<b.Name end)
local encoded={};for _,p in chunkParts do table.insert(encoded,p.Value) end
local http=game:GetService("HttpService")
local manifest=http:JSONDecode(table.concat(encoded))
local byPart={}
for i in manifest.parts do byPart[backup.ColourTargets[string.format("Part%04d",i)].Value]=i end
for _,p in arena.Geometry.FloorArtwork:GetChildren() do
 if p:IsA("BasePart") and p.Name=="SpawnCircleColor" then
  local closest,dist
  for _,group in arena.Gameplay.TeamSpawns:GetChildren() do
   local marker=group:FindFirstChild("01")
   if marker then
    local d=(Vector3.new(marker.Position.X,0,marker.Position.Z)-Vector3.new(p.Position.X,0,p.Position.Z)).Magnitude
    if not dist or d<dist then closest=tonumber(string.match(group.Name,"%d+"));dist=d end
   end
  end
  local color
  if closest==1 then color=Color3.fromRGB(164,69,70)
  elseif closest==7 then color=Color3.fromRGB(61,110,149)
  else color=p.Position.X<8800 and Color3.fromRGB(164,69,70) or Color3.fromRGB(61,110,149) end
  if p.Color~=color then
   local index=assert(byPart[p]);local before=p.Color;p.Color=color
   backup.ColourTargets[string.format("Part%04d",index)]:SetAttribute("InstalledColor",color)
   manifest.parts[index].after={color.R,color.G,color.B}
   table.insert(report.spawnCircleUpdates,{manifestIndex=index,spawnGroup=closest,before={before.R,before.G,before.B},after={color.R,color.G,color.B}})
  end
 end
end
local data=http:JSONEncode(manifest)
for start=1,#data,60000 do
 local name=string.format("Chunk%03d",math.floor((start-1)/60000)+1)
 local value=backup.Manifest:FindFirstChild(name)
 if not value then value=Instance.new("StringValue");value.Name=name;value.Parent=backup.Manifest end
 value.Value=string.sub(data,start,start+59999)
end
for _,p in backup.Manifest:GetChildren() do if tonumber(string.match(p.Name,"%d+"))>math.ceil(#data/60000) then p:Destroy() end end
local result=Instance.new("StringValue");result.Name="Report";result.Value=http:JSONEncode(report);result.Parent=stored
return report
