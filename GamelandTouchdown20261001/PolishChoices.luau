local a=workspace["Oni's Work"].FootballMayhem
local history=game:GetService("ChangeHistoryService")
local recording=history:TryBeginRecording("FootballMayhemVisualPolish","Neon choices and dark-green borders")
local borders=a:FindFirstChild("ChoiceBorders") or Instance.new("Folder")
borders.Name="ChoiceBorders" borders.Parent=a
local changed,removed=0,0
for _,row in a.Rows:GetChildren() do
 for _,tile in row:GetChildren() do
  if tile:IsA("BasePart") then
   tile.Material=Enum.Material.Neon
   local label=tile:FindFirstChild("Label")
   if label then label:Destroy() removed+=1 end
   local name=row.Name.."_"..tile.Name
   local border=borders:FindFirstChild(name) or Instance.new("Folder")
   border.Name=name border.Parent=borders
   local thickness=.22
   for index,spec in ipairs({
    {Vector3.new(tile.Size.X+.12,.035,thickness),CFrame.new(0,tile.Size.Y/2+.025,-tile.Size.Z/2+.08)},
    {Vector3.new(tile.Size.X+.12,.035,thickness),CFrame.new(0,tile.Size.Y/2+.025,tile.Size.Z/2-.08)},
    {Vector3.new(thickness,.035,tile.Size.Z+.12),CFrame.new(-tile.Size.X/2+.08,tile.Size.Y/2+.025,0)},
    {Vector3.new(thickness,.035,tile.Size.Z+.12),CFrame.new(tile.Size.X/2-.08,tile.Size.Y/2+.025,0)}
   }) do
    local edge=border:FindFirstChild("Edge"..index) or Instance.new("Part")
    edge.Name="Edge"..index edge.Size=spec[1] edge.CFrame=tile.CFrame*spec[2]
    edge.Color=Color3.fromRGB(26,91,36) edge.Material=Enum.Material.SmoothPlastic
    edge.Anchored=true edge.CanCollide=false edge.CanTouch=false edge.CanQuery=false edge.CastShadow=false
    edge.Parent=border
   end
   changed+=1
  end
 end
end
for _,v in a.Details:GetChildren() do if string.match(v.Name,"^Row marker ") then v:Destroy() removed+=1 end end
for _,pad in a.StartPads:GetChildren() do pad.Transparency=1 pad.CanCollide=false pad.CanTouch=false pad.CanQuery=false end
if recording then history:FinishRecording(recording,Enum.FinishRecordingOperation.Commit) end
return game:GetService("HttpService"):JSONEncode({neonTiles=changed,numberLabelsRemoved=removed,borders=#borders:GetChildren()})
