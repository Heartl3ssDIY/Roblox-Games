local testScope=Instance.new("Folder")
testScope.Name="CameraChecks"
testScope.Parent=workspace
local signal=Instance.new("BindableEvent")
signal.Capabilities=SecurityCapabilities.new(Enum.SecurityCapability.Basic)
signal.Sandboxed=true
signal.Parent=testScope
local participating=false
local availableArena
local testPlayer={CameraMinZoomDistance=2,CameraMaxZoomDistance=48,CameraMode=Enum.CameraMode.LockFirstPerson}
function testPlayer:GetAttribute(name)
 return name=="BBParticipating" and participating or nil
end
function testPlayer:GetAttributeChangedSignal(name)
 return signal.Event
end
local testArena=workspace["British Bulldog game"]:Clone()
testArena.Parent=game:GetService("ServerStorage")
testArena:SetAttribute("CameraZoomDistance",40)
local gameplay=testArena:FindFirstChild("Gameplay")
local bounds=gameplay:FindFirstChild("ArenaBounds")
local character=Instance.new("Model")
character.Parent=testScope
local root=Instance.new("Part")
root.Name="HumanoidRootPart"
root.Anchored=true
root.Position=Vector3.new(0,5,0)
root.Parent=character
testPlayer.Character=character
local workspace={}
function workspace:FindFirstChild(name)
 return name=="British Bulldog game" and availableArena or nil
end
local Players={LocalPlayer=testPlayer}
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local baseline
local currentDistance
local connections={}
local elapsed=0

local function restore()
 if not baseline then return end
 player.CameraMinZoomDistance=math.min(baseline.minimum,player.CameraMaxZoomDistance)
 player.CameraMaxZoomDistance=baseline.maximum
 player.CameraMinZoomDistance=baseline.minimum
 player.CameraMode=baseline.mode
 baseline=nil
 currentDistance=nil
end

local function update()
 local arena=workspace:FindFirstChild("British Bulldog game")
 local gameplay=arena and arena:FindFirstChild("Gameplay")
 local bounds=gameplay and gameplay:FindFirstChild("ArenaBounds")
 local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 local inside=false
 if root and bounds and bounds:IsA("BasePart") then
  local point=bounds.CFrame:PointToObjectSpace(root.Position)
  local half=bounds.Size/2
  inside=math.abs(point.X)<=half.X and math.abs(point.Y)<=half.Y and math.abs(point.Z)<=half.Z
 end
 if not inside and player:GetAttribute("BBParticipating")~=true then restore() return end
 local distance=arena and arena:GetAttribute("CameraZoomDistance")
 if typeof(distance)~="number" or distance~=distance then distance=30 end
 distance=math.clamp(distance,8,80)
 if not baseline then
  baseline={minimum=player.CameraMinZoomDistance,maximum=player.CameraMaxZoomDistance,mode=player.CameraMode}
 end
 if currentDistance~=distance then
  player.CameraMode=Enum.CameraMode.Classic
  player.CameraMinZoomDistance=math.min(distance,player.CameraMaxZoomDistance)
  player.CameraMaxZoomDistance=distance
  player.CameraMinZoomDistance=distance
  currentDistance=distance
 end
end

table.insert(connections,player:GetAttributeChangedSignal("BBParticipating"):Connect(update))
table.insert(connections,RunService.Heartbeat:Connect(function(dt)
 elapsed+=dt
 if elapsed>=0.2 then elapsed=0 update() end
end))
testScope.Destroying:Connect(function()
 for _,connection in ipairs(connections) do connection:Disconnect() end
 restore()
end)
update()


local checks={}
local ok,failure=xpcall(function()
 checks.waitingWithoutStream=testPlayer.CameraMinZoomDistance==2 and testPlayer.CameraMaxZoomDistance==48
 participating=true
 signal:Fire()
 task.wait(0.05)
 checks.lockedBeforeArenaStreams=testPlayer.CameraMinZoomDistance==30 and testPlayer.CameraMaxZoomDistance==30 and testPlayer.CameraMode==Enum.CameraMode.Classic
 availableArena=testArena
 gameplay.Parent=game:GetService("ServerStorage")
 task.wait(0.25)
 checks.configuredBeforeBoundsStream=testPlayer.CameraMinZoomDistance==40 and testPlayer.CameraMaxZoomDistance==40
 participating=false
 signal:Fire()
 task.wait(0.05)
 checks.restoredWithMissingBounds=testPlayer.CameraMinZoomDistance==2 and testPlayer.CameraMaxZoomDistance==48 and testPlayer.CameraMode==Enum.CameraMode.LockFirstPerson
 gameplay.Parent=testArena
 root.CFrame=bounds.CFrame
 task.wait(0.25)
 checks.locksInsideStreamedArena=testPlayer.CameraMinZoomDistance==40 and testPlayer.CameraMaxZoomDistance==40 and testPlayer.CameraMode==Enum.CameraMode.Classic
 testArena:SetAttribute("CameraZoomDistance",25)
 task.wait(0.25)
 checks.configurable=testPlayer.CameraMinZoomDistance==25 and testPlayer.CameraMaxZoomDistance==25
 availableArena=nil
 task.wait(0.25)
 checks.restoredWhenArenaStreamsOut=testPlayer.CameraMinZoomDistance==2 and testPlayer.CameraMaxZoomDistance==48 and testPlayer.CameraMode==Enum.CameraMode.LockFirstPerson
 participating=true
 signal:Fire()
 task.wait(0.05)
 checks.relocksAfterStreamOut=testPlayer.CameraMinZoomDistance==30 and testPlayer.CameraMaxZoomDistance==30
end,debug.traceback)
testScope:Destroy()
task.wait(0.05)
if gameplay.Parent~=testArena then gameplay:Destroy() end
testArena:Destroy()
checks.restoredOnDestroy=testPlayer.CameraMinZoomDistance==2 and testPlayer.CameraMaxZoomDistance==48 and testPlayer.CameraMode==Enum.CameraMode.LockFirstPerson
assert(ok,failure)
for name,passed in pairs(checks) do
 assert(passed,"Camera check failed: "..name)
end
return checks

