assert(not game:GetService("RunService"):IsRunning(), "Stop Play before editing authored menus")
assert(game.PlaceId == 95034648955135, "Unexpected place")
local StarterGui = game:GetService("StarterGui")
local ServerStorage = game:GetService("ServerStorage")
local session = StarterGui.PlaygroundSessionControls
local emotes = StarterGui.PlaygroundEmoteWheel
assert(session.Dock.Size == UDim2.new(0, 292, 0.9, 0), "Settings layout changed")
assert(session.SpectatePanel.Size == UDim2.fromOffset(304, 146), "Spectate layout changed")
assert(emotes.Panel:IsA("Frame") and emotes.Panel.SizeLimit.MinSize == Vector2.new(280, 300), "Emote layout changed")
local backupName = "PhoneHudModalBackup20261009"
assert(not ServerStorage:FindFirstChild(backupName), "Modal repair already installed")
local backup = Instance.new("Folder")
backup.Name = backupName
backup.Parent = ServerStorage
session:Clone().Parent = backup
emotes:Clone().Parent = backup

local dock = session.Dock
dock.Size = UDim2.new(1, -16, 0.9, 0)
dock.SettingsSize.MinSize = Vector2.new(260, 170)
dock.SettingsSize.MaxSize = Vector2.new(292, 398)
dock.Title.Size = UDim2.new(1, -80, 0, 32)
local body = dock.Body
for _, name in {"AFK", "Notice", "Visibility"} do body[name].Size = UDim2.new(1, -28, 0, body[name].Size.Y.Offset) end
body.VisibilityHelp.Size = UDim2.new(1, -20, 0, 26)
body.Hint.Size = UDim2.new(1, -8, 0, 12)
body.ScrollingDirection = Enum.ScrollingDirection.Y
body.CanvasSize = UDim2.fromOffset(0, 316)
body.ScrollBarThickness = 4
body.ClipsDescendants = true

local spectate = session.SpectatePanel
spectate.Size = UDim2.new(1, -16, 0, 146)
local spectateLimit = Instance.new("UISizeConstraint")
spectateLimit.Name = "SpectateSize"
spectateLimit.MinSize = Vector2.new(260, 146)
spectateLimit.MaxSize = Vector2.new(304, 146)
spectateLimit.Parent = spectate
spectate.Title.Size = UDim2.new(1, -116, 0, 16)
spectate.PlayerName.Size = UDim2.new(1, -112, 0, 23)
spectate.Username.Size = UDim2.new(1, -112, 0, 16)
spectate.Next.Position = UDim2.new(1, -52, 0, 24)
spectate.Exit.AnchorPoint = Vector2.new(0.5, 0)
spectate.Exit.Position = UDim2.new(0.5, 0, 0, 72)
spectate.Controls.Size = UDim2.new(1, -20, 0, 12)
spectate.JoinStatus.Size = UDim2.new(1, -20, 0, 12)

local old = emotes.Panel
local panel = Instance.new("ScrollingFrame")
panel.Name = "Panel"
panel.AnchorPoint = old.AnchorPoint
panel.Position = old.Position
panel.Size = UDim2.new(1, -16, 1, -16)
panel.Visible = old.Visible
panel.BackgroundColor3 = old.BackgroundColor3
panel.BackgroundTransparency = old.BackgroundTransparency
panel.BorderColor3 = old.BorderColor3
panel.BorderSizePixel = old.BorderSizePixel
panel.ZIndex = old.ZIndex
panel.LayoutOrder = old.LayoutOrder
panel.Active = true
panel.Selectable = false
panel.ClipsDescendants = true
panel.CanvasSize = UDim2.fromOffset(0, 480)
panel.AutomaticCanvasSize = Enum.AutomaticSize.None
panel.ScrollingDirection = Enum.ScrollingDirection.Y
panel.ScrollBarThickness = 4
panel.ScrollBarImageColor3 = Color3.fromRGB(24, 36, 74)
panel.VerticalScrollBarInset = Enum.ScrollBarInset.None
for name, value in pairs(old:GetAttributes()) do panel:SetAttribute(name, value) end
for _, child in old:GetChildren() do child.Parent = panel end
panel.SizeLimit.MinSize = Vector2.new(260, 220)
panel.SizeLimit.MaxSize = Vector2.new(650, 680)
local aspect = panel:FindFirstChild("PanelAspect")
if aspect then aspect:Destroy() end
panel.StopButton.AnchorPoint = Vector2.new(1, 0)
panel.StopButton.Position = UDim2.new(1, -14, 1, -110)
panel.Status.Size = UDim2.new(1, -114, 0, 22)
panel.PageLabel.AnchorPoint = Vector2.new(0.5, 0)
panel.PageLabel.Position = UDim2.new(0.5, 0, 0, 42)
panel.PageLabel.Size = UDim2.fromOffset(66, 14)
panel:SetAttribute("PlacementNote", "Scrollable authored wheel keeps touch targets reachable on short mobile screens")
old:Destroy()
panel.Parent = emotes
return {ok=true,backup=backup:GetFullName(),settingsCanvas=316,emoteMinimumCanvas=480,controllersChanged=false}

