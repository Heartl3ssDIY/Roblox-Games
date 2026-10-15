local gui=game.StarterGui.MudHUD
local m=gui.Main
local sprintSkin=m.MobileSprint.ReusableSkin
local blue=sprintSkin:GetAttribute("BlueImage")
if typeof(blue)=="string" then sprintSkin.Image=blue sprintSkin:SetAttribute("DefaultImage",blue) end
for _,header in {m.CompactTop,m.PortraitTop} do header.Lives.Position=UDim2.new(0.5,0,0,45) end
local definitions={
 {m.Top,Color3.fromRGB(255,249,224)},
 {m.CompactTop,Color3.fromRGB(255,249,224)},
 {m.PortraitTop,Color3.fromRGB(255,249,224)},
 {m.Controls.Fire,Color3.fromRGB(255,207,51)},
 {m.MobileSprint,Color3.fromRGB(42,160,255)},
}
for _,definition in definitions do
 local parent,color=definition[1],definition[2]
 local skin=parent.ReusableSkin
 local frame=parent:FindFirstChild("ArtFallback") or Instance.new("Frame")
 frame.Name="ArtFallback" frame.Size=UDim2.fromScale(1,1) frame.Position=UDim2.fromScale(0,0)
 frame.BackgroundColor3=color frame.BorderSizePixel=0 frame.Active=false frame.Selectable=false
 frame.ZIndex=skin.ZIndex-1
 local corner=Instance.new("UICorner") corner.CornerRadius=UDim.new(0,12) corner.Parent=frame
 local stroke=Instance.new("UIStroke") stroke.Color=Color3.fromRGB(24,35,62) stroke.Thickness=2 stroke.StrokeSizingMode=Enum.StrokeSizingMode.FixedSize stroke.Parent=frame
 local gradient=Instance.new("UIGradient") gradient.Color=ColorSequence.new(Color3.new(1,1,1),Color3.fromRGB(210,216,224)) gradient.Rotation=90 gradient.Parent=frame
 frame.Visible=not skin.IsLoaded frame.Parent=parent
end
return {fallbacks=#definitions}

