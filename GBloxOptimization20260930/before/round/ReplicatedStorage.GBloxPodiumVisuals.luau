-- Client-only podium lighting and free R6/R15 celebration poses. Avatar emote tracks replicate from the server.
local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local Tween=game:GetService("TweenService")
local M={}
function M.Begin(packet)
 local self={lights={},poses={},tweens={}}
 local folder=Instance.new("Folder") folder.Name="LocalPodiumReveal" folder.Parent=workspace self.folder=folder
 local tone=Instance.new("ColorCorrectionEffect") tone.Name="PodiumRevealTone" tone.Brightness=-.12 tone.Contrast=.08 tone.Parent=game:GetService("Lighting") self.tone=tone
 for _,entry in packet.roster do
  local source=Instance.new("Part") source.Name="Spotlight"..entry.place source.Size=Vector3.one source.Transparency=1
  source.Anchored=true source.CanCollide=false source.CanTouch=false source.CanQuery=false
  source.CFrame=CFrame.lookAt(entry.cframe.Position+Vector3.new(0,22,-5),entry.cframe.Position) source.Parent=folder
  local light=Instance.new("SpotLight") light.Face=Enum.NormalId.Front light.Range=48 light.Angle=38 light.Brightness=0
  light.Color=entry.place==1 and Color3.fromRGB(255,225,165) or Color3.fromRGB(190,240,255)
  light.Shadows=false light.Parent=source
  local a=Instance.new("Attachment",source)
  local target=Instance.new("Part") target.Name="LightTarget" target.Size=Vector3.one target.Transparency=1 target.Anchored=true target.CanCollide=false target.CanTouch=false target.CanQuery=false target.CFrame=entry.cframe*CFrame.new(0,-2.8,0) target.Parent=folder
  local b=Instance.new("Attachment",target)
  local beam=Instance.new("Beam") beam.Attachment0=a beam.Attachment1=b beam.Width0=.1 beam.Width1=9
  beam.FaceCamera=true beam.Color=ColorSequence.new(light.Color) beam.Transparency=NumberSequence.new(.92) beam.LightEmission=1 beam.Enabled=false beam.Parent=source
  self.lights[entry.place]={light=light,beam=beam}
 end
 function self:Reveal(place)
  for rank,rig in self.lights do
   if self.tweens[rank] then self.tweens[rank]:Cancel() end
   local on=not place or rank==place
   rig.beam.Enabled=on
   self.tweens[rank]=Tween:Create(rig.light,TweenInfo.new(.45),{Brightness=on and 7 or 0})
   self.tweens[rank]:Play()
  end
  tone.Brightness=place and -.12 or -.025
 end
 local function clearPose(pose)
  for _,m in pose.motors do if m.joint.Parent then m.joint.C0=m.c0 end end
 end
 local started=os.clock()
 self.tick=Run.RenderStepped:Connect(function()
  local t=os.clock()-started
  for _,entry in packet.roster do
   local player=Players:GetPlayerByUserId(entry.userId)
   local character=player and player.Character
   local pose=self.poses[entry.userId]
   if character and (not pose or pose.character~=character) then
    if pose then clearPose(pose) end
    pose={character=character,motors={},r15=character:FindFirstChildOfClass("Humanoid") and character:FindFirstChildOfClass("Humanoid").RigType==Enum.HumanoidRigType.R15} self.poses[entry.userId]=pose
    for _,v in character:GetDescendants() do if v:IsA("Motor6D") then pose.motors[v.Name]={joint=v,c0=v.C0} end end
   end
   if pose and character and player:GetAttribute("GBloxPodiumActive") then
    clearPose(pose)
    local function set(name,cf)
     local mapped=pose.r15 and ({["Right Shoulder"]="RightShoulder",["Left Shoulder"]="LeftShoulder",["RootJoint"]="Waist",["Right Hip"]="RightHip",["Left Hip"]="LeftHip"})[name] or name
     local m=pose.motors[mapped]
     if m and m.joint.Parent then m.joint.C0=m.c0*cf end
    end
    local key=player:GetAttribute("RankingEmote")
    if key=="wave" then
     set("Right Shoulder",CFrame.Angles(0,0,math.rad(145)+math.sin(t*7)*.28))
    elseif key=="cheer" then
     set("Right Shoulder",CFrame.Angles(0,0,math.rad(150)+math.sin(t*5)*.12))
     set("Left Shoulder",CFrame.Angles(0,0,-math.rad(150)-math.sin(t*5)*.12))
     set("RootJoint",CFrame.new(0,0,math.abs(math.sin(t*4))*.15))
    elseif key=="dance" then
     set("RootJoint",CFrame.Angles(0,0,math.sin(t*4)*.13))
     set("Right Shoulder",CFrame.Angles(math.sin(t*4)*.55,0,1))
     set("Left Shoulder",CFrame.Angles(-math.sin(t*4)*.55,0,-1))
     set("Right Hip",CFrame.Angles(math.sin(t*4)*.2,0,0))
     set("Left Hip",CFrame.Angles(-math.sin(t*4)*.2,0,0))
    end
   end
  end
 end)
 function self:Destroy()
  if self.tick then self.tick:Disconnect() end
  for _,tween in self.tweens do tween:Cancel() end
  for _,pose in self.poses do clearPose(pose) end
  folder:Destroy() tone:Destroy()
 end
 return self
end
return M

