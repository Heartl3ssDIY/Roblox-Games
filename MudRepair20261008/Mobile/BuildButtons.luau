local RunService=game:GetService("RunService")
local StarterGui=game:GetService("StarterGui")
assert(not RunService:IsRunning(),"Stop Play before installing mobile sprint buttons.")
assert(game.PlaceId==95034648955135,"This installer is for Playground Classics.")
local template=StarterGui.TagHUD.SprintPanel.Sprint
local parents={
 StarterGui.BritishBulldogHUD,
 StarterGui.TagHUD,
 StarterGui.MudHUD.Main,
}
for _,parent in ipairs(parents) do
 assert(not parent:FindFirstChild("MobileSprint"),parent:GetFullName().." already has MobileSprint.")
end
local out={}
for _,parent in ipairs(parents) do
 local button=template:Clone()
 button.Name="MobileSprint"
 button.AnchorPoint=Vector2.new(0,1)
 button.Position=UDim2.new(0,18,1,-202)
 button.Size=UDim2.fromOffset(120,54)
 button.Visible=false
 button.Active=true
 button.Selectable=false
 button.AutoButtonColor=false
 button.ZIndex=20
 button.Text="SPRINT\nHOLD"
 button.TextTransparency=1
 button.TextStrokeTransparency=1
 button:SetAttribute("UserArtworkManaged",nil)
 button:SetAttribute("ArtworkAsset",nil)
 button:SetAttribute("ArtworkText",nil)
 button:SetAttribute("MobileSprintPlacement","LeftAboveJoystick")
 button:SetAttribute("TouchHold",true)
 local skin=button:FindFirstChild("ReusableSkin")
 if skin then skin.ZIndex=20 end
 local label=button:FindFirstChild("LiveCaption")
 if label then
  label.Position=UDim2.fromScale(0.075,0.08)
  label.Size=UDim2.fromScale(0.85,0.78)
  label.Text="SPRINT\nHOLD"
  label.TextScaled=true
  label.TextWrapped=false
  label.ZIndex=21
  local limit=label:FindFirstChildOfClass("UITextSizeConstraint")
  if not limit then limit=Instance.new("UITextSizeConstraint") limit.Parent=label end
  limit.MinTextSize=10
  limit.MaxTextSize=18
 end
 button.Parent=parent
 table.insert(out,button:GetFullName())
end
local controls=StarterGui.MudHUD.Main.Controls
controls.AnchorPoint=Vector2.zero
controls.Position=UDim2.fromScale(0,0)
controls.Size=UDim2.fromScale(1,1)
controls.Active=false
local scale=controls:FindFirstChild("ResponsiveHudScale")
if scale then
 scale.Scale=1
 scale:SetAttribute("PhoneScale",1)
 scale:SetAttribute("TabletScale",1)
 scale:SetAttribute("DesktopScale",1)
end
controls.Meter.AnchorPoint=Vector2.new(0.5,1)
controls.Meter.Position=UDim2.new(0.5,0,1,-18)
controls.Meter.Size=UDim2.fromOffset(200,36)
controls.Mud.AnchorPoint=Vector2.new(1,1)
controls.Mud.Position=UDim2.new(1,-88,1,-238)
controls.Mud.Size=UDim2.fromOffset(62,44)
controls.Heat.AnchorPoint=Vector2.new(1,1)
controls.Heat.Position=UDim2.new(1,-18,1,-238)
controls.Heat.Size=UDim2.fromOffset(62,44)
controls.Fire.AnchorPoint=Vector2.new(1,1)
controls.Fire.Position=UDim2.new(1,-18,1,-180)
controls.Fire.Size=UDim2.fromOffset(132,54)
controls.Sprint.Visible=false
for _,button in ipairs({controls.Mud,controls.Heat,controls.Fire}) do
 button.ZIndex=20
 for _,child in ipairs(button:GetChildren()) do
  if child:IsA("GuiObject") then child.ZIndex=child:IsA("TextLabel") and 21 or 20 end
 end
end
return out
