local Players=game:GetService("Players")
local Tween=game:GetService("TweenService")
local SoundService=game:GetService("SoundService")
local Artwork=require(game:GetService("ReplicatedStorage"):WaitForChild("GBloxUIArtwork"))
local gui=Players.LocalPlayer:WaitForChild("PlayerGui")
local function sound(name,id,volume)
 local s=Instance.new("Sound") s.Name=name s.SoundId="rbxassetid://"..id s.Volume=volume s.Parent=SoundService return s
end
local hover=sound("UIHover","98390881944061",.18)
local click=sound("UIClick","85549623140205",.25)
local open=sound("UIOpen","108355097117461",.22)
local lastHover=0
local function add(b)
 if not b:IsA("GuiButton") or b:GetAttribute("Polished") then return end
 b:SetAttribute("Polished",true)
 local rotation=b.Rotation
 local shine=Instance.new("Frame") shine.Name="HoverGloss" shine.BackgroundColor3=Color3.new(1,1,1) shine.BackgroundTransparency=1 shine.BorderSizePixel=0 shine.Size=UDim2.fromScale(1,1) shine.ZIndex=b.ZIndex+1 shine.Parent=b
 local corner=Instance.new("UICorner") corner.CornerRadius=UDim.new(.18,0) corner.Parent=shine
 local gradient=Instance.new("UIGradient") gradient.Rotation=25 gradient.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.4,1),NumberSequenceKeypoint.new(.5,.4),NumberSequenceKeypoint.new(.6,1),NumberSequenceKeypoint.new(1,1)}) gradient.Parent=shine
 local scale=Instance.new("UIScale") scale.Name="FeedbackScale" scale.Parent=b
 local function animate(angle,size) Tween:Create(b,TweenInfo.new(.12),{Rotation=angle}):Play() Tween:Create(scale,TweenInfo.new(.12),{Scale=size}):Play() end
 b.MouseEnter:Connect(function()
  animate(rotation+3,1.035)
  shine.BackgroundTransparency=.65 gradient.Offset=Vector2.new(-1,0)
  Tween:Create(gradient,TweenInfo.new(.4),{Offset=Vector2.new(1,0)}):Play()
  if os.clock()-lastHover>.06 then lastHover=os.clock() SoundService:PlayLocalSound(hover) end
 end)
 b.MouseLeave:Connect(function() animate(rotation,1) shine.BackgroundTransparency=1 end)
 b.MouseButton1Down:Connect(function() animate(rotation,.96) end)
 b.MouseButton1Up:Connect(function() animate(rotation,1) end)
 b.Activated:Connect(function()
  SoundService:PlayLocalSound((b.Name=="Shop" or b.Name=="Abilities") and open or click)
  animate(rotation,1)
 end)
 b:GetPropertyChangedSignal("Visible"):Connect(function() if not b.Visible then b.Rotation=rotation scale.Scale=1 end end)
 if b.Name=="TemporaryReadyButton" then
  b.BackgroundTransparency=1 b.TextScaled=true
  local ratio=Instance.new("UIAspectRatioConstraint") ratio.AspectRatio=173/63 ratio.Parent=b
  b.Size=UDim2.new(.32,0,.09,0)
  local limits=Instance.new("UISizeConstraint") limits.MinSize=Vector2.new(170,50) limits.MaxSize=Vector2.new(260,95) limits.Parent=b
  Artwork.Button(b)

 end
end
for _,d in gui:GetDescendants() do add(d) end
gui.DescendantAdded:Connect(add)

