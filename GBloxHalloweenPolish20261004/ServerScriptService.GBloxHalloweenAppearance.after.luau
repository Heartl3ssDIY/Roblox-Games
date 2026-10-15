local ReplicatedStorage=game:GetService("ReplicatedStorage")
local settings=ReplicatedStorage:WaitForChild("GBloxHalloweenSettings")
local theme=ReplicatedStorage:WaitForChild("GBloxCourseTheme")
local parts={}
local lights={}
local roots={}
local courses={}
local connections={}
local queued=false
local stopped=false

local function appearance()
 local visible=settings:GetAttribute("Enabled")==true and theme:GetAttribute("ActiveTheme")=="Halloween"
 for part,transparency in parts do
  if part.Parent then
   part.Transparency=(visible and not part:GetAttribute("HalloweenRestHidden")) and transparency or 1
  else
   parts[part]=nil
  end
 end
 for light,enabled in lights do
  if light.Parent then light.Enabled=visible and enabled else lights[light]=nil end
 end
end
local function queueAppearance()
 if queued or stopped then return end
 queued=true
 task.defer(function()
  queued=false
  if not stopped then appearance() end
 end)
end
local function register(instance)
 if instance:IsA("BasePart") then
  local visible=instance:GetAttribute("HalloweenVisibleTransparency")
  if typeof(visible)~="number" then visible=instance.Transparency end
  parts[instance]=visible
 elseif instance:IsA("Light") then
  local visible=instance:GetAttribute("HalloweenVisibleEnabled")
  lights[instance]=visible~=false
 end
end
local function bindRoot(root)
 if roots[root] then return end
 roots[root]=true
 for _,instance in root:GetDescendants() do register(instance) end
 table.insert(connections,root.DescendantAdded:Connect(function(instance)
  register(instance)
  queueAppearance()
 end))
 table.insert(connections,root.DescendantRemoving:Connect(function(instance)
  parts[instance]=nil
  lights[instance]=nil
 end))
 queueAppearance()
end
local function bindCourse(course)
 if courses[course] then return end
 courses[course]=true
 local root=course:FindFirstChild("HalloweenGameplay")
 if root then bindRoot(root) end
 table.insert(connections,course.ChildAdded:Connect(function(child)
  if child.Name=="HalloweenGameplay" then bindRoot(child) end
 end))
end
local function isCourse(instance)
 for index=1,5 do
  if instance.Name==" Course -  round "..index then return true end
 end
 return false
end
for _,course in workspace:GetChildren() do
 if isCourse(course) then bindCourse(course) end
end
table.insert(connections,workspace.ChildAdded:Connect(function(child)
 if isCourse(child) then bindCourse(child) end
end))
table.insert(connections,settings:GetAttributeChangedSignal("Enabled"):Connect(appearance))
table.insert(connections,theme:GetAttributeChangedSignal("ActiveTheme"):Connect(appearance))
appearance()
local keys={
 "Enabled",
 "PollInterval",
 "WebHoldSeconds",
 "WebCooldown",
 "WebLifetime",
 "WebRadius",
 "WebMaxActive",
 "CornerWebHoldSeconds",
 "CornerWebFallSpeed",
 "CornerWebImmunity",
 "GraveStuckSeconds",
 "GraveHoldSeconds",
 "GraveStillRadius",
 "GraveStillSpeed",
 "GhostInitialDelay",
 "GhostBaseSpeed",
 "GhostMaxSpeed",
 "GhostSpeedIncrease",
 "GhostSpeedInterval",
 "GhostSpawnBehind",
 "GhostCatchRadius",
 "PumpkinCooldown",
 "PumpkinHoldSeconds",
 "PumpkinRange",
 "PumpkinSpeed",
 "PumpkinLifetime",
 "PumpkinHitRadius",
 "PumpkinSplatSeconds",
}
local snapshot
local pending=false
local connection
local function applySnapshot()
 if not snapshot or settings:GetAttribute("UsePublishedConfig")~=true then return end
 if workspace:GetAttribute("RunnerRoundPhase")=="Running" then pending=true return end
 pending=false
 for _,name in keys do
  local ok,value=pcall(function() return snapshot:GetValue("GBloxHalloween."..name) end)
  if ok and value~=nil then
   local current=settings:GetAttribute(name)
   if typeof(value)==typeof(current) and (typeof(value)~="number" or (value==value and math.abs(value)<math.huge)) then
    settings:SetAttribute(name,value)
   end
  end
 end
end
local function loadPublished()
 if settings:GetAttribute("UsePublishedConfig")~=true or snapshot then return end
 task.spawn(function()
  local ok,result=pcall(function() return game:GetService("ConfigService"):GetConfigAsync() end)
  if stopped then return end
  if not ok then
   warn("[GBloxHalloween] Published config unavailable; using Studio attributes.")
   return
  end
  snapshot=result
  connection=snapshot.UpdateAvailable:Connect(function()
   local refreshed=pcall(function() snapshot:Refresh() end)
   if refreshed then applySnapshot() end
  end)
  applySnapshot()
 end)
end
table.insert(connections,settings:GetAttributeChangedSignal("UsePublishedConfig"):Connect(loadPublished))
table.insert(connections,workspace:GetAttributeChangedSignal("RunnerRoundPhase"):Connect(function()
 if pending then applySnapshot() end
end))
script.Destroying:Connect(function()
 stopped=true
 if connection then connection:Disconnect() end
 for _,signal in connections do signal:Disconnect() end
 table.clear(parts)
 table.clear(lights)
 table.clear(roots)
 table.clear(courses)
end)
loadPublished()

