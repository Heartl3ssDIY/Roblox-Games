
local values={}
local attributes={}
local signals={}
local fixture=setmetatable({},{
 __index=function(_,key) return values[key] end,
 __newindex=function(_,key,value)
  if key=="CameraMinZoomDistance" and values.CameraMaxZoomDistance then assert(value<=values.CameraMaxZoomDistance,"invalid minimum write") end
  if key=="CameraMaxZoomDistance" and values.CameraMinZoomDistance then assert(value>=values.CameraMinZoomDistance,"invalid maximum write") end
  values[key]=value
 end,
})
function fixture:GetAttribute(name) return attributes[name] end
function fixture:GetAttributeChangedSignal(name)
 if not signals[name] then signals[name]=Instance.new("BindableEvent") end
 return signals[name].Event
end
function fixture:SetAttribute(name,value)
 attributes[name]=value
 if signals[name] then signals[name]:Fire() end
end
function fixture:Destroy()
 for _,event in pairs(signals) do event:Destroy() end
end
fixture.CameraMinZoomDistance=0.75
fixture.CameraMaxZoomDistance=100
fixture.CameraMode=Enum.CameraMode.Classic
local heartbeat=Instance.new("BindableEvent")
local destroying=Instance.new("BindableEvent")
local bound={}
local fakeRun={Heartbeat=heartbeat.Event}
function fakeRun:BindToRenderStep(name,priority,callback) bound[name]=callback end
function fakeRun:UnbindFromRenderStep(name) bound[name]=nil end
local script={Destroying=destroying.Event}
local Players=game:GetService("Players")
local RunService=fakeRun
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local player=fixture
local baseline
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
end

local function update()
 local active=player:GetAttribute("BBParticipating")==true
  or player:GetAttribute("TGParticipating")==true
  or player:GetAttribute("MDParticipating")==true
 if not active then restore() return end
 if not baseline then
  baseline={minimum=player.CameraMinZoomDistance,maximum=player.CameraMaxZoomDistance,mode=player.CameraMode}
 end
 player.CameraMode=Enum.CameraMode.Classic
 if player.CameraMinZoomDistance~=0.5 then player.CameraMinZoomDistance=0.5 end
 if player.CameraMaxZoomDistance~=5 then player.CameraMaxZoomDistance=5 end
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

for _,attribute in ipairs({"BBParticipating","TGParticipating","MDParticipating"}) do
 table.insert(connections,player:GetAttributeChangedSignal(attribute):Connect(update))
end
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

local count=0
local function check(condition,message) assert(condition,message) count+=1 end
local function tick() heartbeat:Fire(0.25) task.wait() end
check(fixture.CameraMinZoomDistance==0.75 and fixture.CameraMaxZoomDistance==100,"lobby is preserved")
for _,attribute in ipairs({"BBParticipating","TGParticipating","MDParticipating"}) do
 fixture:SetAttribute(attribute,true)
 tick()
 check(fixture.CameraMinZoomDistance==0.5,"inward zoom is allowed "..attribute)
 check(fixture.CameraMaxZoomDistance==5,"outward zoom capped "..attribute)
 check(fixture.CameraMinZoomDistance<fixture.CameraMaxZoomDistance,"zoom not fixed "..attribute)
 fixture:SetAttribute(attribute,false)
 tick()
 check(fixture.CameraMinZoomDistance==0.75 and fixture.CameraMaxZoomDistance==100,"lobby zoom restored "..attribute)
end
fixture:SetAttribute("TGParticipating",true) tick()
fixture:SetAttribute("BBParticipating",true)
fixture:SetAttribute("TGParticipating",false) tick()
check(fixture.CameraMaxZoomDistance==5,"overlapping round transition remains capped")
fixture:SetAttribute("BBParticipating",false) tick()
check(fixture.CameraMaxZoomDistance==100,"transition restores original baseline")
fixture.CameraMinZoomDistance=12 fixture.CameraMaxZoomDistance=28
fixture:SetAttribute("MDParticipating",true) tick()
check(fixture.CameraMinZoomDistance==0.5 and fixture.CameraMaxZoomDistance==5,"high min safely lowered")
destroying:Fire() task.wait()
check(fixture.CameraMinZoomDistance==12 and fixture.CameraMaxZoomDistance==28,"destroy restores previous bounds")
check(next(bound)==nil,"render bindings released")
fixture:Destroy() heartbeat:Destroy() destroying:Destroy()
return {passed=count}

