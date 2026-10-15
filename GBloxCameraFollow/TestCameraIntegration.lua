local callback
local CameraFollow=assert(loadstring(game.ReplicatedStorage.RunnerCameraFollow.Source))()
local config=assert(loadstring(game.ReplicatedStorage.RunnerConfig.Source))()
local function mockPlayer()
 local p={attrs={GBloxCourseReady=true,RunnerCourseVersion=1,RunnerCourseCenter=Vector3.zero}}
 function p:GetAttribute(k) return self.attrs[k] end
 local root={Position=Vector3.new(10,20,0)}
 p.Character={FindFirstChild=function(_,name) return name=="HumanoidRootPart" and root or nil end}
 return p,root
end
local player,root=mockPlayer()
local cameraTarget=player
local camera={CFrame=CFrame.new(),FieldOfView=58}
local workspace={CurrentCamera=camera,GetAttribute=function() return nil end,GetServerTimeNow=function() return 0 end}
local RunService={BindToRenderStep=function(_,name,priority,fn) callback=fn end}
local cameraCourseVersion,cameraFocus,cameraRoot,cameraRecoveryRevision
local startX,courseCenterY,courseCenterZ=0,0,0
local phase="Waiting"
local finishDeadline
local countdown={}
RunService:BindToRenderStep("RunnerCamera", Enum.RenderPriority.Camera.Value + 1,
 function(deltaTime)
  if player:GetAttribute("GBloxPodiumActive") or player:GetAttribute("GBloxPodiumCameraActive")
   or not player:GetAttribute("GBloxCourseReady") then
   cameraFocus=nil
   return -- The podium/loading sequence owns the camera.
  end
  local activeCamera=workspace.CurrentCamera
  if not activeCamera then return end
  if camera~=activeCamera then camera=activeCamera cameraFocus=nil end
  local character=cameraTarget and cameraTarget.Character
  local root=character and character:FindFirstChild("HumanoidRootPart")
  if not root then cameraFocus=nil return end
  local center=(cameraTarget and cameraTarget:GetAttribute("RunnerCourseCenter"))
   or player:GetAttribute("RunnerCourseCenter") or Vector3.new(startX,courseCenterY,courseCenterZ)
  local cameraOffset=workspace:GetAttribute("RunnerCameraOffset") or config.CameraOffset
   or Vector3.new(-4.4,2.53,-94.86)
  local version=player:GetAttribute("RunnerCourseVersion")
  local recoveryRevision=cameraTarget:GetAttribute("RunnerRecoveryRevision")
  local reset=not cameraFocus or cameraCourseVersion~=version or cameraRoot~=root
   or cameraRecoveryRevision~=recoveryRevision
  if reset then
   -- Snap after a round transfer, respawn, recovery or spectator switch.
   cameraFocus=Vector3.new(root.Position.X,root.Position.Y,center.Z)
   cameraCourseVersion=version cameraRoot=root cameraRecoveryRevision=recoveryRevision
   camera.FieldOfView=config.CameraFieldOfView
  else
   local alpha=1-math.exp(-config.CameraFollowSpeed*deltaTime)
   local deadZone,maxLag=CameraFollow.Limits(cameraOffset,camera.FieldOfView,
    config.CameraVerticalDeadZone or 6,config.CameraVerticalMaxLag or 18)
   local y=CameraFollow.StepY(cameraFocus.Y,root.Position.Y,deltaTime,deadZone,
    config.CameraVerticalFollowSpeed or 7,maxLag)
   cameraFocus=Vector3.new(
    cameraFocus.X+(root.Position.X-cameraFocus.X)*alpha,
    y,cameraFocus.Z+(center.Z-cameraFocus.Z)*alpha)
  end
  camera.CameraType=Enum.CameraType.Scriptable
  camera.CFrame=CFrame.lookAt(cameraFocus+cameraOffset,cameraFocus)
  if phase=="Running" and finishDeadline then
   countdown.Text=tostring(math.max(0,math.ceil(finishDeadline-workspace:GetServerTimeNow())))
  end
 end)


local passed=0
local function check(ok,label) assert(ok,label) passed+=1 end
callback(1/60)
check((cameraFocus-root.Position).Magnitude<.001,"initial target center")
root.Position+=Vector3.new(-1,3,0) callback(1/60)
check(cameraFocus.Y==20,"normal movement does not bob")
root.Position+=Vector3.new(-1,90,0) callback(1/60)
check(math.abs(cameraFocus.Y-root.Position.Y)<=18,"fast vertical movement stays framed")
player.attrs.RunnerCourseVersion=2 root.Position=Vector3.new(197000,34800,-15000) player.attrs.RunnerCourseCenter=Vector3.new(197000,34800,-15000)
callback(1/60) check((cameraFocus-root.Position).Magnitude<.001,"round change snaps not cross-map sweep")
player.attrs.RunnerRecoveryRevision=1 root.Position+=Vector3.new(100,-40,0)
callback(1/60) check((cameraFocus-root.Position).Magnitude<.001,"revive resets follow")
local spectator,sroot=mockPlayer() sroot.Position=Vector3.new(2,300,0) cameraTarget=spectator
callback(1/60) check(cameraRoot==sroot and cameraFocus.Y==300,"spectator switch follows watched player")
player.attrs.GBloxPodiumActive=true local before=camera.CFrame
sroot.Position+=Vector3.new(0,500,0) callback(1/60)
check(camera.CFrame==before and cameraFocus==nil,"podium camera untouched")
player.attrs.GBloxPodiumActive=false player.attrs.GBloxPodiumCameraActive=true callback(1/60)
check(camera.CFrame==before,"podium reveal camera untouched")
player.attrs.GBloxPodiumCameraActive=false callback(1/60)
check(cameraFocus.Y==800,"resume snaps to current player")
player.attrs.GBloxCourseReady=false before=camera.CFrame callback(1/60)
check(camera.CFrame==before and cameraFocus==nil,"loading camera untouched")
return tostring(passed).." installed camera-callback integration checks passed."

