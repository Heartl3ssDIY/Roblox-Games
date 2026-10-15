assert(not game:GetService("RunService"):IsRunning(), "Exit Play first")
assert(game.PlaceId == 111313211501470, "Wrong place")
local Http=game:GetService("HttpService")
local storage=game:GetService("ServerStorage")
local imports={}
local originals={}
for _, m in ipairs(workspace:GetChildren()) do
 if m:IsA("Model") and (m.Name:match("^%d%d_") or m.Name=="ACU_Citadel_Collision") then
  assert(not imports[m.Name], "Duplicate import: "..m.Name)
  imports[m.Name]=m
 end
end
local count=0
for _ in pairs(imports) do count+=1 end
assert(count==43, "Expected42visualbatches andcollision; found "..count)
assert(imports["16_Outer_Gardens_Forests_01"] and imports["14_60_ArenaPortals_Torii_01_01"],"Missing retry imports")
local old=workspace:FindFirstChild("Lobby_MainModeZone")
assert(old and not old:GetAttribute("CitadelIntegrationVersion"),"Lobby already integrated or original missing")
assert(not workspace:FindFirstChild("ACU_Citadel_Staging"),"Staging root already exists")
local backup=Instance.new("Folder")
backup.Name="BeforeLobbyIntegration_"..os.date("!%Y%m%d_%H%M%S")
backup.Parent=storage
local root=Instance.new("Model")
root.Name="ACU_Citadel_Staging"
root.WorldPivot=CFrame.identity
root:SetAttribute("CitadelIntegrationVersion",1)
root:SetAttribute("SourceMarkerYawDegrees",180)
root:SetAttribute("BaseWidthStuds",632)
root:SetAttribute("SetupState","Grouping")
local visuals=Instance.new("Folder")
visuals.Name="Visuals";visuals.Parent=root
local names={"Landscape","Plaza_Paths_Arrival","Civic_Branding","Story_Gate","Summon_Hall","Ranked_Hall","Champions_Court","Shop_NPC_Stations","Market_Street","Academy","Celestial_Pagoda","City_Buildings","Fortress_Backdrop","Arena_Promenade","Waterfall_Ravine","Outer_Gardens_Forests","Inner_Gardens_Training"}
local groups={}
for i,name in ipairs(names) do
 local f=Instance.new("Model"); f.Name=string.format("%02d_%s",i,name);f.WorldPivot=CFrame.identity;f.Parent=visuals;groups[i]=f
end
local changed={}
local visualCount,collisionCount,textured=0,0,0
local ok,err=pcall(function()
 for name,m in pairs(imports) do
  local col=name=="ACU_Citadel_Collision"
  for _,p in ipairs(m:GetDescendants()) do
   if p:IsA("BasePart") then
    local record={part=p,Anchored=p.Anchored,CanCollide=p.CanCollide,CanTouch=p.CanTouch,CanQuery=p.CanQuery,Transparency=p.Transparency}
    table.insert(changed,record)
    table.insert(originals,{batch=name,path=p:GetFullName():sub(#m:GetFullName()+2),anchored=p.Anchored,canCollide=p.CanCollide,canTouch=p.CanTouch,canQuery=p.CanQuery,transparency=p.Transparency})
    p.Anchored=true;p.CanTouch=false
    if col then
     p.Transparency=1;p.CanCollide=true;p.CanQuery=true;collisionCount+=1
    else
     p.CanCollide=false;p.CanQuery=false;visualCount+=1
     if p:IsA("MeshPart") and (p.TextureID~="" or p:FindFirstChildOfClass("SurfaceAppearance")) then textured+=1 end
    end
   end
  end
  if col then m.Name="Collision";m.Parent=root
  else m.Parent=groups[tonumber(name:sub(1,2))] end
 end
 local encoded=Http:JSONEncode(originals)
 for offset=1,#encoded,100000 do
  local saved=Instance.new("StringValue")
  saved.Name=string.format("ImportedPartPropertiesJSON_%02d",math.floor((offset-1)/100000)+1)
  saved.Value=encoded:sub(offset,offset+99999);saved.Parent=backup
 end
 root.Parent=workspace
 root:SetAttribute("SetupState","Grouped")
 root:SetAttribute("BackupFolder",backup.Name)
end)
if not ok then
 for _,r in ipairs(changed) do
  r.part.Anchored=r.Anchored;r.part.CanCollide=r.CanCollide;r.part.CanTouch=r.CanTouch;r.part.CanQuery=r.CanQuery;r.part.Transparency=r.Transparency
 end
 for name,m in pairs(imports) do m.Name=name;m.Parent=workspace end
 root:Destroy();backup:Destroy()
 error(err)
end
game:GetService("ChangeHistoryService"):SetWaypoint("ACU Citadel grouped with collision")
return Http:JSONEncode({backup=backup.Name,visualBatches=42,districts=17,visualParts=visualCount,collisionParts=collisionCount,texturedParts=textured,oldLobbyUnchanged=true,scale=root:GetScale()})