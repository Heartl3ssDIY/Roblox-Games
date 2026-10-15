local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local player=Players.LocalPlayer
local baseline
local currentDistance
local connections={}
local elapsed=0
local roll=0
local shift=0
local lastCamera
local lastBase
local lastOutput
local beforeName="BritishBulldogCameraRestore"
local afterName="BritishBulldogCameraMotion"

local function removeCameraOffset()
 if lastCamera and lastCamera.Parent and lastBase and lastOutput and lastCamera.CFrame==lastOutput then
  lastCamera.CFrame=lastBase
 end
 lastCamera=nil
 lastBase=nil
 lastOutput=nil
end

local function restore()
 removeCameraOffset()
 roll=0
 shift=0
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

local function numberAttribute(name,fallback)
 local value=player:GetAttribute(name)
 return typeof(value)=="number" and value==value and math.abs(value)<math.huge and value or fallback
end

RunService:BindToRenderStep(beforeName,Enum.RenderPriority.Camera.Value-1,removeCameraOffset)
RunService:BindToRenderStep(afterName,Enum.RenderPriority.Camera.Value+1,function(dt)
 local camera=workspace.CurrentCamera
 local character=player.Character
 local humanoid=character and character:FindFirstChildOfClass("Humanoid")
 local root=character and character:FindFirstChild("HumanoidRootPart")
 local state=ReplicatedStorage:FindFirstChild("BritishBulldogState")
 local active=player:GetAttribute("BBParticipating")==true and state and state:GetAttribute("Phase")=="Crossing"
  and player:GetAttribute("BBRole")~="Tagged" and player:GetAttribute("BBStatus")~="Safe"
  and humanoid and humanoid.Health>0 and root and humanoid.WalkSpeed>0
 if not camera or camera.CameraType~=Enum.CameraType.Custom then roll=0 shift=0 return end
 local targetRoll=0
 local targetShift=0
 if active and player:GetAttribute("PCReducedMotion")~=true then
  local screenRight=camera.CFrame.RightVector
  local lateral=root.AssemblyLinearVelocity:Dot(screenRight)
  targetRoll=-math.rad(1.2)*math.clamp(lateral/math.max(humanoid.WalkSpeed,1),-1,1)
  local started=numberAttribute("BBDodgeStartedAt",0)
  local duration=math.clamp(numberAttribute("BBDodgeDuration",0.32),0.2,0.5)+0.14
  local time=workspace:GetServerTimeNow()-started
  local direction=player:GetAttribute("BBDodgeDirection")
  if started>0 and time>=0 and time<duration and typeof(direction)=="Vector3" then
   local alpha=time/duration
   local pulse=alpha<0.22 and math.sin(alpha/0.22*math.pi/2) or math.cos((alpha-0.22)/0.78*math.pi/2)^2
   local side=math.clamp(direction:Dot(screenRight),-1,1)
   targetRoll-=math.rad(3.2)*side*pulse
   targetShift=0.24*side*pulse
  end
 end
 local blend=1-math.exp(-18*math.clamp(dt,0,0.1))
 roll+=(targetRoll-roll)*blend
 shift+=(targetShift-shift)*blend
 if not active and math.abs(roll)<0.0001 and math.abs(shift)<0.0001 then roll=0 shift=0 return end
 if roll==0 and shift==0 then return end
 lastCamera=camera
 lastBase=camera.CFrame
 lastOutput=lastBase*CFrame.new(shift,0,0)*CFrame.Angles(0,0,roll)
 camera.CFrame=lastOutput
end)

table.insert(connections,player:GetAttributeChangedSignal("BBParticipating"):Connect(update))
table.insert(connections,RunService.Heartbeat:Connect(function(dt)
 elapsed+=dt
 if elapsed>=0.2 then elapsed=0 update() end
end))
script.Destroying:Connect(function()
 RunService:UnbindFromRenderStep(beforeName)
 RunService:UnbindFromRenderStep(afterName)
 for _,connection in ipairs(connections) do connection:Disconnect() end
 restore()
end)
update()
