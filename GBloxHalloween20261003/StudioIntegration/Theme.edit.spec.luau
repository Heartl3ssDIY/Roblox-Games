local Theme = require(game.ServerScriptService.GBloxCourseTheme.Theme)
local settings = game.ReplicatedStorage.GBloxCourseTheme
local snapshots = {}
local scriptSources = {}
local courseCount = 0
for _, course in ipairs(workspace:GetChildren()) do
 if Theme.IsCourse(course) then
  courseCount += 1
  for _, p in ipairs(course:GetDescendants()) do
   if p:IsA("BasePart") then
    snapshots[p] = {cf=p.CFrame,size=p.Size,color=p.Color,material=p.Material,variant=p.MaterialVariant,
     transparency=p.Transparency,collide=p.CanCollide,touch=p.CanTouch,query=p.CanQuery,anchored=p.Anchored,
     mesh=p:IsA("MeshPart") and p.MeshId or nil,texture=p:IsA("MeshPart") and p.TextureID or nil,
     parent=p.Parent,name=p.Name,physical=p.CustomPhysicalProperties}
   end
  end
 end
end
for _, s in ipairs(game.ServerScriptService:GetDescendants()) do if s:IsA("LuaSourceContainer") then scriptSources[s]=s.Source end end
local checks = {}
local function check(condition, name)
 assert(condition, name)
 table.insert(checks, name)
end
local function verifyGeometry()
 for p,s in pairs(snapshots) do
  assert(p.Parent==s.parent and p.Name==s.name,"Hierarchy changed")
  assert(p.CFrame==s.cf and p.Size==s.size,"Geometry moved or resized")
  assert(p.Material==s.material and p.MaterialVariant==s.variant,"Surface properties changed")
  assert(p.Transparency==s.transparency and p.CanCollide==s.collide and p.CanTouch==s.touch and p.CanQuery==s.query and p.Anchored==s.anchored,"Gameplay properties changed")
  assert(p.CustomPhysicalProperties==s.physical,"Physics changed")
  if p:IsA("MeshPart") then assert(p.MeshId==s.mesh and p.TextureID==s.texture,"Mesh changed") end
 end
 for s,source in pairs(scriptSources) do assert(s.Source==source,"Existing source changed") end
end
local changed = 0
local ok, err = xpcall(function()
 local platform,wheel
 for _, v in ipairs(workspace[" Course -  round 1"]:GetDescendants()) do
  if v:IsA("Model") and v:FindFirstChild("Flat_Platform_RunSurface") then platform=platform or v end
  if v:IsA("Model") and v.Name=="Red_Spiked_Wheel" then wheel=wheel or v end
 end
 assert(platform and wheel)
 local sample = {}
 for _,model in ipairs({platform,wheel}) do for _,p in ipairs(model:GetDescendants()) do if Theme.ApplyPart(p,"Halloween") then sample[p]=true end end end
 check(platform.Flat_Platform_Cyan.Color~=snapshots[platform.Flat_Platform_Cyan].color,"Sample platform becomes Halloween")
 check(wheel.RedWheel_Teeth.Color~=snapshots[wheel.RedWheel_Teeth].color,"Sample wheel receives bone-colored teeth")
 verifyGeometry()
 check(true,"Sample placement, wheel pivots, collision and scripts unchanged")
 for p in pairs(sample) do Theme.ApplyPart(p,"Normal") end
 for p,s in pairs(snapshots) do assert(p.Color==s.color,"Sample failed to restore") end
 check(true,"Sample restores original colors exactly")
 changed=Theme.Apply("Halloween")
 verifyGeometry()
 for p,s in pairs(snapshots) do if not Theme.IsSupported(p) then assert(p.Color==s.color,"Unrelated part recolored") end end
 check(true,"All course themes preserve gameplay geometry and unrelated objects")
 check(Theme.Apply("Halloween")==changed,"Applying Halloween twice is safe")
 check(Theme.Apply("Normal")==changed,"Every themed mesh can restore Normal")
 for p,s in pairs(snapshots) do assert(p.Color==s.color,"Normal failed to restore original color") end
 check(true,"All original per-instance colors restore exactly")
 local invalid=pcall(function() Theme.Apply("InvalidTheme") end)
 check(not invalid,"Unknown themes rejected without changes")
 for p,s in pairs(snapshots) do assert(p.Color==s.color,"Invalid theme changed color") end
 Theme.Apply("Halloween")
 settings:SetAttribute("ActiveTheme","Halloween")
 settings:SetAttribute("AppliedParts",changed)
 verifyGeometry()
end,debug.traceback)
if not ok then Theme.Apply("Normal") settings:SetAttribute("ActiveTheme","Normal") end
return game:GetService("HttpService"):JSONEncode({passed=ok,error=err,checks=checks,courseCount=courseCount,themedParts=changed})

