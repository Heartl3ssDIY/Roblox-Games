local shell = game:GetService("StarterGui"):WaitForChild("PlaygroundShell")
local storage = game:GetService("ServerStorage")
local root = storage:FindFirstChild("InventoryLevelUIBackups20261004")
if not root then root = Instance.new("Folder") root.Name = "InventoryLevelUIBackups20261004" root.Parent = storage end
local backup = root:FindFirstChild("LevelUIInitial")
if not backup then
 backup = Instance.new("Folder")
 backup.Name = "LevelUIInitial"
 for _, name in ipairs({ "LevelPanel", "CompactLevelPanel", "LevelUpNotice", "PlayerLevelController" }) do
  local source = shell:FindFirstChild(name)
  if source then source:Clone().Parent = backup end
 end
 backup:SetAttribute("SavedAt", DateTime.now():ToIsoDate())
 backup.Parent = root
end
local panel = shell:WaitForChild("LevelPanel")
local compact = shell:WaitForChild("CompactLevelPanel")
local function outline(label, thickness)
 label.TextStrokeTransparency = 1
 label.TextXAlignment = Enum.TextXAlignment.Center
 label.TextYAlignment = Enum.TextYAlignment.Center
 local stroke = label:FindFirstChild("TextOutline")
 if not stroke then stroke = Instance.new("UIStroke") stroke.Name = "TextOutline" stroke.Parent = label end
 stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
 stroke.BorderStrokePosition = Enum.BorderStrokePosition.Outer
 stroke.StrokeSizingMode = Enum.StrokeSizingMode.FixedSize
 stroke.Thickness = thickness
 stroke.Color = Color3.fromRGB(24, 30, 51)
 stroke.Transparency = 0
 stroke.LineJoinMode = Enum.LineJoinMode.Round
end
local function label(parent, name, template, position, size, text, maximum, minimum, thickness)
 local object = parent:FindFirstChild(name)
 if not object then object = template:Clone() object.Name = name object.Parent = parent end
 object.Position, object.Size = position, size
 object.AnchorPoint = Vector2.zero
 object.Text = text
 object.Visible = true
 object.TextScaled = true
 object.BackgroundTransparency = 1
 object.TextColor3 = Color3.fromRGB(255, 249, 224)
 object.TextTransparency = 0
 object.ZIndex = parent.ZIndex + 1
 local limit = object:FindFirstChildOfClass("UITextSizeConstraint")
 if not limit then limit = Instance.new("UITextSizeConstraint") limit.Name = "TextLimit" limit.Parent = object end
 limit.MinTextSize, limit.MaxTextSize = minimum, maximum
 outline(object, thickness)
 return object
end
panel.Size = UDim2.fromOffset(288, 98)
panel.FacePreview.Position = UDim2.fromOffset(18, 19)
panel.LevelIcon.Position = UDim2.fromOffset(94, 11)
panel.LevelIcon.Size = UDim2.fromOffset(22, 22)
panel.IconFallback.Position = panel.LevelIcon.Position
panel.IconFallback.Size = panel.LevelIcon.Size
panel.Level.Position = UDim2.fromOffset(119, 8)
panel.Level.Size = UDim2.fromOffset(152, 27)
outline(panel.Level, 2)
label(panel, "NextLevel", panel.XP, UDim2.fromOffset(90, 35), UDim2.fromOffset(181, 16), "NEXT: LEVEL 2", 13, 10, 1.3)
label(panel, "XP", panel.XP, UDim2.fromOffset(90, 55), UDim2.fromOffset(181, 17), "0 / 200 XP", 14, 10, 1.3)
panel.XPTrack.Position = UDim2.fromOffset(94, 79)
panel.XPTrack.Size = UDim2.fromOffset(173, 10)
compact.Size = UDim2.fromOffset(151, 66)
compact.FacePreview.Position = UDim2.fromOffset(7, 12)
compact.Level.Position = UDim2.fromOffset(54, 5)
compact.Level.Size = UDim2.fromOffset(89, 19)
outline(compact.Level, 1.5)
label(compact, "NextLevel", compact.XP, UDim2.fromOffset(52, 25), UDim2.fromOffset(93, 12), "NEXT: LV 2", 10, 8, 1)
label(compact, "XP", compact.XP, UDim2.fromOffset(52, 39), UDim2.fromOffset(93, 12), "0 / 200 XP", 10, 8, 1)
compact.XPTrack.Position = UDim2.fromOffset(55, 55)
compact.XPTrack.Size = UDim2.fromOffset(86, 6)
local notice = shell:FindFirstChild("LevelUpNotice")
if notice and not notice:IsA("CanvasGroup") then notice:Destroy() notice = nil end
if not notice then notice = Instance.new("CanvasGroup") notice.Name = "LevelUpNotice" notice.Parent = shell end
notice.AnchorPoint = Vector2.new(0.5, 0)
notice.Position = UDim2.new(0.5, 0, 0, 145)
notice.Size = UDim2.new(0.72, 0, 0, 92)
notice.BackgroundTransparency = 1
notice.GroupTransparency = 1
notice.Visible = false
notice.Active = false
notice.ZIndex = 24
notice.ClipsDescendants = false
notice:SetAttribute("HoldSeconds", 3)
local bounds = notice:FindFirstChildOfClass("UISizeConstraint")
if not bounds then bounds = Instance.new("UISizeConstraint") bounds.Parent = notice end
bounds.MinSize, bounds.MaxSize = Vector2.new(216, 92), Vector2.new(340, 92)
local scale = notice:FindFirstChildOfClass("UIScale")
if not scale then scale = Instance.new("UIScale") scale.Name = "NoticeScale" scale.Parent = notice end
scale.Scale = 1
local skin = notice:FindFirstChild("ReusableSkin")
if not skin then skin = shell.RewardToast.ReusableSkin:Clone() skin.Parent = notice end
skin.ZIndex = notice.ZIndex
skin.Position, skin.Size = UDim2.fromScale(0, 0), UDim2.fromScale(1, 1)
skin.Image = "rbxassetid://84589903135132"
skin.ImageTransparency = 0
skin.ImageColor3 = Color3.new(1, 1, 1)
skin:SetAttribute("DefaultImage", skin.Image)
notice:SetAttribute("UISkinManaged", true)
notice:SetAttribute("UISkinDynamic", false)
local title = label(notice, "Title", panel.Level, UDim2.new(0, 44, 0, 9), UDim2.new(1, -88, 0, 30), "LEVEL UP!", 26, 17, 2)
local detail = label(notice, "Level", panel.Level, UDim2.new(0, 16, 0, 42), UDim2.new(1, -32, 0, 29), "LEVEL 2", 24, 17, 2)
for _, side in ipairs({ "Left", "Right" }) do
 local icon = notice:FindFirstChild(side .. "Star")
 if not icon then icon = panel.LevelIcon:Clone() icon.Name = side .. "Star" icon.Parent = notice end
 icon.AnchorPoint = Vector2.new(side == "Right" and 1 or 0, 0)
 icon.Position = UDim2.new(side == "Right" and 1 or 0, side == "Right" and -17 or 17, 0, 13)
 icon.Size = UDim2.fromOffset(26, 26)
 icon.Visible = true
 icon.ZIndex = notice.ZIndex + 1
end
shell:SetAttribute("LevelLayoutVersion", 2)
return { backup = backup:GetFullName(), changed = { panel:GetFullName(), compact:GetFullName(), notice:GetFullName() }, sourceChanged = false }

