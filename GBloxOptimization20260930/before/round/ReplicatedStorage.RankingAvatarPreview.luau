-- Local-only WorldModel previews. Never animate or move the live race character.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Preview={}
Preview.__index=Preview
function Preview.new(frame)
 local self=setmetatable({frame=frame,generation=0,connections={},motors={}},Preview)
 frame.BackgroundTransparency=1
 frame.Ambient=Color3.fromRGB(175,185,205)
 frame.LightColor=Color3.new(1,1,1)
 frame.LightDirection=Vector3.new(-1,-1,-1)
 local label=Instance.new("TextLabel")
 label.Name="AvatarLoading" label.Size=UDim2.fromScale(1,1) label.BackgroundTransparency=1
 label.Text="..." label.TextScaled=true label.Font=Enum.Font.Arcade label.TextColor3=Color3.new(1,1,1)
 label.ZIndex=frame.ZIndex+1 label.Parent=frame self.label=label
 return self
end
function Preview:Clear()
 self.generation+=1
 if self.tick then self.tick:Disconnect() self.tick=nil end
 if self.model then self.model:Destroy() self.model=nil end
 if self.world then self.world:Destroy() self.world=nil end
 if self.camera then self.camera:Destroy() self.camera=nil end
 self.motors={}
 self.frame.CurrentCamera=nil
 self.frame:SetAttribute("AvatarLoadedUserId",nil)
 self.frame:SetAttribute("EmoteUnavailable",nil)
 self.frame:SetAttribute("DisplayedEmote",nil)
 self.label.Visible=false
end
function Preview:Show(userId,key,animationId)
 self.animationId=animationId
 key=key or "idle"
 local native=(string.sub(key,1,7)=="avatar:" or string.sub(key,1,5)=="shop:")
 local rig=native and Enum.HumanoidRigType.R15 or Enum.HumanoidRigType.R6
 if self.userId==userId and self.rig==rig and self.model then
  self.key=key self:Animate() return
 end
 self:Clear()
 self.userId=userId self.rig=rig self.key=key
 local version=self.generation
 self.label.Text="..." self.label.Visible=true
 task.spawn(function()
  local ok,model=pcall(function()
   local person=Players:GetPlayerByUserId(userId)
   local humanoid=person and person.Character and person.Character:FindFirstChildOfClass("Humanoid")
   local description
   if humanoid then
    local success,value=pcall(function() return humanoid:GetAppliedDescription() end)
    if success then description=value end
   end
   description=description or Players:GetHumanoidDescriptionFromUserIdAsync(userId)
   -- Avatar emotes are on the profile description, not always copied onto the R6 runner.
   if native then
    description:Destroy()
    description=Players:GetHumanoidDescriptionFromUserIdAsync(userId)
   end
   local result=Players:CreateHumanoidModelFromDescriptionAsync(description,rig)
   description:Destroy()
   return result
  end)
  if self.generation~=version or not self.frame.Parent then if ok then model:Destroy() end return end
  if not ok then self.label.Text="AVATAR\nUNAVAILABLE" return end
  local world=Instance.new("WorldModel") world.Name="AvatarWorld" world.Parent=self.frame self.world=world
  self.model=model model.Name="Avatar_"..userId
  local root=model:FindFirstChild("HumanoidRootPart")
  for _,d in model:GetDescendants() do
   if d:IsA("LuaSourceContainer") then d:Destroy()
   elseif d:IsA("BasePart") then d.CanCollide=false d.CanTouch=false d.CanQuery=false d.Anchored=d==root
   elseif d:IsA("Motor6D") then self.motors[d.Name]={joint=d,c0=d.C0} end
  end
  local hum=model:FindFirstChildOfClass("Humanoid")
  hum.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None hum.AutoRotate=false
  if not hum:FindFirstChildOfClass("Animator") then Instance.new("Animator",hum) end
  model:PivotTo(CFrame.new())
  model.Parent=world
  local cf,size=model:GetBoundingBox()
  local camera=Instance.new("Camera") camera.Name="AvatarCamera" camera.FieldOfView=35 camera.Parent=self.frame
  self.camera=camera self.frame.CurrentCamera=camera
  local aspect=math.max(self.frame.AbsoluteSize.X,1)/math.max(self.frame.AbsoluteSize.Y,1)
  local distance=math.max(size.Y,size.X/aspect)*.65/math.tan(math.rad(camera.FieldOfView/2))+size.Z*.5
  camera.CFrame=CFrame.lookAt(cf.Position+Vector3.new(0,size.Y*.03,-distance),cf.Position)
  self.label.Visible=false
  self.frame:SetAttribute("AvatarLoadedUserId",userId)
  self:Animate()
 end)
end
function Preview:Animate()
 if self.tick then self.tick:Disconnect() self.tick=nil end
 local hum=self.model and self.model:FindFirstChildOfClass("Humanoid")
 if not hum then return end
 for _,m in self.motors do m.joint.C0=m.c0 m.joint.Transform=CFrame.identity end
 local animator=hum:FindFirstChildOfClass("Animator")
 for _,track in animator:GetPlayingAnimationTracks() do track:Stop(0) end
 local key=self.key
 self.frame:SetAttribute("DisplayedEmote",key)
 if (string.sub(key,1,7)=="avatar:" or string.sub(key,1,5)=="shop:") then
  local version=self.generation
  task.spawn(function()
   local success,track=pcall(function()
    assert(self.animationId,"No authorized animation supplied")
    local animation=Instance.new("Animation")
    animation.AnimationId=self.animationId
    local result=animator:LoadAnimation(animation)
    animation:Destroy()
    result.Looped=true
    result:Play(.15)
    return result
   end)
   if version~=self.generation or self.key~=key then if success and track then track:Stop(0) end return end
   if success and track then
    self.label.Visible=false
    self.frame:SetAttribute("EmoteUnavailable",nil)
   else
    self.frame:SetAttribute("EmoteUnavailable",key)
    self.label.Text="EMOTE\nUNAVAILABLE" self.label.Visible=true
   end
  end)
  return
 end
 self.label.Visible=false self.frame:SetAttribute("EmoteUnavailable",nil)
 local function pose(name,cf)
  local m=self.motors[name] if m and m.joint.Parent then m.joint.C0=m.c0*cf end
 end
 local started=os.clock()
 self.tick=RunService.RenderStepped:Connect(function()
  if not self.model or not self.frame.Visible then return end
  local t=os.clock()-started
  if key=="wave" then
   pose("Right Shoulder",CFrame.Angles(0,0,math.rad(145)+math.sin(t*7)*.28))
   pose("Neck",CFrame.Angles(0,0,math.sin(t*2)*.06))
  elseif key=="cheer" then
   pose("Right Shoulder",CFrame.Angles(0,0,math.rad(150)+math.sin(t*5)*.12))
   pose("Left Shoulder",CFrame.Angles(0,0,-math.rad(150)-math.sin(t*5)*.12))
   pose("RootJoint",CFrame.new(0,0,math.abs(math.sin(t*4))*.15))
  elseif key=="dance" then
   pose("RootJoint",CFrame.Angles(0,0,math.sin(t*4)*.13))
   pose("Right Shoulder",CFrame.Angles(math.sin(t*4)*.55,0,1.0))
   pose("Left Shoulder",CFrame.Angles(-math.sin(t*4)*.55,0,-1.0))
   pose("Right Hip",CFrame.Angles(math.sin(t*4)*.2,0,0))
   pose("Left Hip",CFrame.Angles(-math.sin(t*4)*.2,0,0))
  else
   pose("Neck",CFrame.Angles(0,math.sin(t)*.035,0))
  end
 end)
end
return Preview

