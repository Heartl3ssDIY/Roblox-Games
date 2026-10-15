local ReplicatedStorage=game:GetService("ReplicatedStorage")
local settings=ReplicatedStorage:WaitForChild("GBloxHalloweenSettings")
local theme=ReplicatedStorage:WaitForChild("GBloxCourseTheme")
local root=workspace:WaitForChild(" Course -  round 1"):WaitForChild("HalloweenGameplay")
local parts={}
local lights={}
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
for _,instance in root:GetDescendants() do register(instance) end
local function appearance()
 local visible=settings:GetAttribute("Enabled")==true and theme:GetAttribute("ActiveTheme")=="Halloween"
 for part,transparency in parts do
  if part.Parent then part.Transparency=(visible and not part:GetAttribute("HalloweenRestHidden")) and transparency or 1 else parts[part]=nil end
 end
 for light,enabled in lights do
  if light.Parent then light.Enabled=visible and enabled else lights[light]=nil end
 end
end
root.DescendantAdded:Connect(function(instance) register(instance) appearance() end)
settings:GetAttributeChangedSignal("Enabled"):Connect(appearance)
theme:GetAttributeChangedSignal("ActiveTheme"):Connect(appearance)
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
settings:GetAttributeChangedSignal("UsePublishedConfig"):Connect(loadPublished)
workspace:GetAttributeChangedSignal("RunnerRoundPhase"):Connect(function()
 if pending then applySnapshot() end
end)
script.Destroying:Connect(function() if connection then connection:Disconnect() end end)
loadPublished()

