local gui=game.StarterGui.MudHUD
assert(not game:GetService("RunService"):IsRunning(),"Stop Play before editing.")
local changed={}
for _,object in gui:GetDescendants() do
 if object:IsA("TextLabel") or object:IsA("TextButton") then
  object.TextStrokeTransparency=1
  local preferred=object:FindFirstChild("TextOutline") or object:FindFirstChildWhichIsA("UIStroke")
  for _,stroke in object:GetChildren() do
   if stroke:IsA("UIStroke") and stroke.ApplyStrokeMode==Enum.ApplyStrokeMode.Contextual then
    table.insert(changed,{path=stroke:GetFullName(),mode=tostring(stroke.StrokeSizingMode),thickness=stroke.Thickness,enabled=stroke.Enabled})
    stroke.Enabled=stroke==preferred
    stroke.StrokeSizingMode=Enum.StrokeSizingMode.FixedSize
    stroke.Thickness=1.4
   end
  end
 end
end
for _,header in {gui.Main.Top,gui.Main.CompactTop,gui.Main.PortraitTop} do
 header.ReusableSkin.ScaleType=Enum.ScaleType.Slice
 header.ReusableSkin.SliceCenter=Rect.new(64,64,1984,217)
 header.ReusableSkin.SliceScale=0.2
 header.Outline.Enabled=false
 header.Team.ReusableSkin.ScaleType=Enum.ScaleType.Slice
 header.Team.ReusableSkin.SliceCenter=Rect.new(88,88,424,232)
 header.Team.ReusableSkin.SliceScale=0.12
end
local shoot=gui.Main.Controls.Fire
shoot.ReusableSkin.ScaleType=Enum.ScaleType.Slice
shoot.ReusableSkin.SliceCenter=Rect.new(88,88,264,148)
shoot.ReusableSkin.SliceScale=0.18
shoot.Outline.Enabled=false
local sprint=gui.Main.MobileSprint
sprint.ReusableSkin.ScaleType=Enum.ScaleType.Slice
sprint.ReusableSkin.SliceCenter=Rect.new(88,88,424,232)
sprint.ReusableSkin.SliceScale=0.18
sprint.Outline.Enabled=false
return {textStrokes=changed}

