return function()
 assert(not game:GetService("RunService"):IsRunning(), "Apply HUD repair in Edit mode only")
 local starter=game:GetService("StarterGui")
 local storage=game:GetService("ServerStorage")
 local backup=storage:FindFirstChild("GameplayHUDRepairBackup20261005")
 if not backup then
  backup=Instance.new("Folder")
  backup.Name="GameplayHUDRepairBackup20261005"
  backup.Parent=storage
  for _,name in ipairs({"BritishBulldogHUD","TagHUD","MudHUD"})do
   starter[name]:Clone().Parent=backup
  end
 end
 local bulldog=starter.BritishBulldogHUD
 local tag=starter.TagHUD
 local mud=starter.MudHUD
 local changed={}
 local function set(object,property,value)
  if object[property]~=value then object[property]=value table.insert(changed,object:GetFullName().."."..property)end
 end
 set(bulldog,"Enabled",false)
 set(tag,"Enabled",false)
 set(mud.Main,"Visible",false)
 set(mud.ColourPicker,"Visible",false)
 set(bulldog.MovementControls,"Visible",false)
 set(bulldog.Departure,"Visible",false)
 set(bulldog.CompactDeparture,"Visible",false)
 set(tag.Controls,"Visible",false)
 set(tag.SprintPanel,"Visible",false)
 set(mud.Main.Controls,"Visible",false)
 set(mud.Main.DesktopControls,"Visible",false)
 for _,name in ipairs({"BulldogChip","RunnerChip"})do
  local chip=bulldog.TopCard.Panel[name]
  set(chip.Count,"Position",UDim2.fromScale(0.04,0.12))
  set(chip.Count,"Size",UDim2.fromScale(0.24,0.69))
  set(chip.Caption,"Position",UDim2.fromScale(0.33,0.15))
  set(chip.Caption,"Size",UDim2.fromScale(0.63,0.63))
 end
 local topPanel=bulldog.TopCard.Panel
 set(topPanel.Timer,"Position",UDim2.fromScale(0.35,0.30))
 set(topPanel.Timer,"Size",UDim2.fromScale(0.30,0.28))
 set(topPanel.PhaseLabel,"Position",UDim2.fromScale(0.34,0.65))
 set(topPanel.PhaseLabel,"Size",UDim2.fromScale(0.32,0.15))
 local taggerChip=tag.Top.TaggerChip
 set(taggerChip.ReusableSkin,"Position",UDim2.fromScale(0,0))
 set(taggerChip.ReusableSkin,"AnchorPoint",Vector2.zero)
 set(taggerChip.ReusableSkin,"Size",UDim2.fromScale(1,1))
 local taggerName=taggerChip:FindFirstChild("Name")
 set(taggerName,"Position",UDim2.fromScale(0.04,0.12))
 set(taggerName,"Size",UDim2.fromScale(0.92,0.68))
 set(tag.SprintPanel,"Size",UDim2.fromOffset(280,116))
 set(tag.SprintPanel.Meter,"Size",UDim2.new(1,0,0,60))
 set(tag.SprintPanel.Meter.Role,"Position",UDim2.fromOffset(10,5))
 set(tag.SprintPanel.Meter.Role,"Size",UDim2.fromOffset(144,19))
 set(tag.SprintPanel.Meter.Time,"Position",UDim2.fromOffset(10,28))
 set(tag.SprintPanel.Meter.Time,"Size",UDim2.new(1,-20,0,17))
 set(tag.SprintPanel.Meter.Charge,"Position",UDim2.new(1,-116,0,5))
 set(tag.SprintPanel.Meter.Charge,"Size",UDim2.fromOffset(106,19))
 set(tag.SprintPanel.Meter.Track,"Position",UDim2.fromOffset(10,50))
 set(tag.SprintPanel.Sprint,"Position",UDim2.fromOffset(0,68))
 set(tag.SprintPanel.Sprint,"Size",UDim2.fromOffset(172,48))
 set(tag.Controls.Dodge,"Position",UDim2.fromOffset(186,0))
 set(tag.Controls.Dodge,"Size",UDim2.fromOffset(94,48))
 for _,spec in ipairs({{tag.SprintPanel.Meter.Role,18},{tag.SprintPanel.Meter.Time,15},{tag.SprintPanel.Meter.Charge,15}})do
  local limit=spec[1]:FindFirstChildOfClass("UITextSizeConstraint")
  if limit then set(limit,"MaxTextSize",spec[2])end
 end
 set(taggerChip,"Position",UDim2.fromScale(0.07,0.34))
 set(taggerChip,"Size",UDim2.fromScale(0.60,0.29))
 for _,spec in ipairs({{tag.Controls.Dodge,"DODGE\n[E]"},{tag.SprintPanel.Sprint,"SPRINT\nHOLD SHIFT"}})do
  local button,text=spec[1],spec[2]
  set(button,"Text",text)
  local label=button.LiveCaption
  set(label,"Text",text)
  set(label,"Position",UDim2.fromScale(0.075,0.08))
  set(label,"Size",UDim2.fromScale(0.85,0.72))
  set(label,"TextXAlignment",Enum.TextXAlignment.Center)
  set(label,"TextYAlignment",Enum.TextYAlignment.Center)
 end
 local vault=tag.Controls:FindFirstChild("Vault")
 if vault then table.insert(changed,vault:GetFullName().." removed")vault:Destroy()end
 local light=Color3.fromRGB(255,249,224)
 for _,gui in ipairs({bulldog,tag,mud})do
  for _,object in ipairs(gui:GetDescendants())do
   if object:IsA("TextLabel") or object:IsA("TextButton")then
    local outline=object:FindFirstChild("TextOutline")
    if outline and outline:IsA("UIStroke")then
     set(object,"TextColor3",light)
     set(object,"TextStrokeTransparency",1)
     set(outline,"ApplyStrokeMode",Enum.ApplyStrokeMode.Contextual)
     set(outline,"BorderStrokePosition",Enum.BorderStrokePosition.Outer)
    end
   end
  end
 end
 return {changed=changed,backup=backup:GetFullName(),outerPanelPositionsPreserved=true,panelArtworkPreserved=true}
end

