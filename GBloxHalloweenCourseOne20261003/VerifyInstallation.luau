assert(game.PlaceId==106769122906103)
local root=workspace[" Course -  round 1"].HalloweenGameplay
local backup=game.ServerStorage.BeforeHalloweenCourseOne_20261003_080454
local rows={}
local added=0
for _,p in ipairs(workspace:GetDescendants()) do
 if p:IsA("BasePart") then
  if p:IsDescendantOf(root) then
   added+=1
   assert(p.Anchored and not p.CanCollide and not p.CanTouch and not p.CanQuery,"New art has gameplay collision: "..p:GetFullName())
  else
   table.insert(rows,game.HttpService:JSONEncode({p:GetFullName(),{p.CFrame:GetComponents()},{p.Size.X,p.Size.Y,p.Size.Z},{p.Color.R,p.Color.G,p.Color.B},p.Material.Name,p.Transparency,p.CanCollide,p.CanTouch,p.CanQuery,p.Anchored,p.CollisionGroup}))
  end
 end
end
table.sort(rows)
local text=table.concat(rows,"\n")
local hash=5381
for i=1,#text do hash=(hash*33+string.byte(text,i))%4294967296 end
assert(#rows==backup:GetAttribute("OriginalPartCount"),"Original part count changed")
assert(tostring(hash)==backup:GetAttribute("OriginalWorldFingerprint"),"Original world geometry or physics changed")
local es=game:GetService("ScriptEditorService")
local scripts={game.ServerScriptService.RunnerServer,game.ServerScriptService.GBloxAbilityEffects,game.ServerScriptService.GBloxGravitySwitch,game.ServerScriptService.GBloxHalloweenService,game.ServerScriptService.GBloxHalloweenAppearance,game.StarterGui.GBloxHalloweenControls.Controller}
for _,s in ipairs(scripts) do local chunk,err=loadstring(es:GetEditorSource(s),s:GetFullName()) assert(chunk,err) end
local perCourse={}
for _,c in ipairs(workspace:GetChildren()) do
 if c.Name:lower():match("^%s*course%s*%-%s*round") then table.insert(perCourse,{name=c.Name,newGameplay=c:FindFirstChild("HalloweenGameplay")~=nil}) end
end
local traps={}
for _,m in ipairs(root.Traps:GetChildren()) do
 local sensor=m:FindFirstChild("Sensor")
 local support=m:FindFirstChild("Support")
 assert(sensor and support and support.Value and support.Value:IsDescendantOf(workspace[" Course -  round 1"]))
 if m:GetAttribute("TrapType")=="Grave" then
  local hand=assert(m:FindFirstChild("ZombieHand"))
  for _,p in ipairs(hand:GetDescendants()) do if p:IsA("BasePart") then assert(p.Transparency==1,"Rest hand must stay hidden") end end
 end
 table.insert(traps,{name=m.Name,type=m:GetAttribute("TrapType"),position=tostring(sensor.Position),support=support.Value:GetFullName()})
end
local templates=game.ReplicatedStorage.GBloxHalloweenAssets
local templateNames={}
for _,m in ipairs(templates:GetChildren()) do table.insert(templateNames,m.Name) end
return game.HttpService:JSONEncode({originalPartCount=#rows,originalWorldFingerprint=tostring(hash),originalWorldUnchanged=true,addedNonCollidableParts=added,compiledScripts=#scripts,decorations=#root.Decorations:GetChildren(),traps=traps,templateNames=templateNames,courses=perCourse,published=false,playtestStarted=false})

