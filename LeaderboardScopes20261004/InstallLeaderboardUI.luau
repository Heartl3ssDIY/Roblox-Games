local StarterGui = game:GetService("StarterGui")
local ServerStorage = game:GetService("ServerStorage")
local lobby = workspace:FindFirstChild("Playground Lobby")
local boards = assert(lobby and lobby:FindFirstChild("Leaderboards"), "Lobby leaderboards are missing")
local backup = ServerStorage:FindFirstChild("LeaderboardScopesBackup20261004")
if not backup then backup = Instance.new("Folder") backup.Name = "LeaderboardScopesBackup20261004" backup.Parent = ServerStorage end
local existing = StarterGui:FindFirstChild("PlaygroundLeaderboards")
if existing and not backup:FindFirstChild("PreviousPlayerGui") then
 local saved = existing:Clone()
 saved.Name = "PreviousPlayerGui"
 saved.Parent = backup
end
local shell = StarterGui:WaitForChild("PlaygroundShell")
local skinTemplate = shell.Dock.Emote.ReusableSkin
local function textOutline(label, thickness)
 label.TextStrokeTransparency = 1
 local stroke = label:FindFirstChild("TextOutline")
 if not stroke then stroke = Instance.new("UIStroke") stroke.Name = "TextOutline" stroke.Parent = label end
 stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
 stroke.BorderStrokePosition = Enum.BorderStrokePosition.Outer
 stroke.StrokeSizingMode = Enum.StrokeSizingMode.FixedSize
 stroke.LineJoinMode = Enum.LineJoinMode.Round
 stroke.Color = Color3.fromRGB(24, 30, 51)
 stroke.Thickness = thickness
 stroke.Transparency = 0
end
local function scaleText(label, minimum, maximum)
 label.TextWrapped = false
 label.TextScaled = true
 local limit = label:FindFirstChildOfClass("UITextSizeConstraint")
 if not limit then limit = Instance.new("UITextSizeConstraint") limit.Name = "TextLimit" limit.Parent = label end
 limit.MinTextSize, limit.MaxTextSize = minimum, maximum
end
local function prepareDisplay(display, interactive)
 display.Active = interactive
 display.ResetOnSpawn = false
 display:SetAttribute("LeaderboardScopesVersion", 1)
 display.Header.Subtitle.Text = "GLOBAL · TOP 10"
 scaleText(display.Header.Subtitle, 18, 23)
 display.Body.Position = UDim2.fromOffset(24, 226)
 display.Body.Size = UDim2.fromOffset(672, 686)
 local function rowLayout(row, index)
  row.Size = UDim2.fromOffset(672, 64)
  row.Position = UDim2.fromOffset(0, (index - 1) * 68)
  row.RankBadge.Position = UDim2.fromOffset(8, 8)
  row.Rank.Position = UDim2.fromOffset(8, 8)
  row.Avatar.Position = UDim2.fromOffset(69, 5)
  row.PlayerName.Position = UDim2.fromOffset(137, 4)
  row.Value.Position = UDim2.fromOffset(476, 4)
  row.PlayerName.RichText = false
  row.PlayerName.TextTruncate = Enum.TextTruncate.AtEnd
  scaleText(row.PlayerName, 16, 30)
  scaleText(row.Value, 18, 32)
 end
 for index = 1, 10 do
  local row = display.Body:FindFirstChild(string.format("Row%02d", index))
  assert(row, "Leaderboard row is missing")
  rowLayout(row, index)
 end
 rowLayout(display.Templates.RowTemplate, 1)
 display.Empty.Position = UDim2.fromOffset(60, 451)
 display.Empty.Size = UDim2.fromOffset(600, 150)
 display.Empty.TextWrapped = true
 display.Empty.TextScaled = true
 local emptyLimit = display.Empty:FindFirstChildOfClass("UITextSizeConstraint")
 if not emptyLimit then emptyLimit = Instance.new("UITextSizeConstraint") emptyLimit.Parent = display.Empty end
 emptyLimit.MinTextSize, emptyLimit.MaxTextSize = 23, 36
 scaleText(display.Status, 14, 23)
 local tabs = display:FindFirstChild("ScopeTabs")
 if not tabs then tabs = Instance.new("Frame") tabs.Name = "ScopeTabs" tabs.Parent = display end
 tabs.BackgroundTransparency = 1
 tabs.Position = UDim2.fromOffset(24, 158)
 tabs.Size = UDim2.fromOffset(672, 52)
 tabs.ZIndex = 18
 local buttons = {}
 for index, scope in ipairs({ "global", "server", "region" }) do
  local button = tabs:FindFirstChild(scope)
  if not button then button = Instance.new("TextButton") button.Name = scope button.Parent = tabs end
  button:SetAttribute("Scope", scope)
  button.Position = UDim2.fromOffset((index - 1) * 228, 0)
  button.Size = UDim2.fromOffset(216, 52)
  button.BackgroundTransparency = 1
  button.Text = ""
  button.Active = interactive
  button.Selectable = interactive
  button.AutoButtonColor = false
  button.ZIndex = 18
  local skin = button:FindFirstChild("ReusableSkin")
  if not skin then skin = skinTemplate:Clone() skin.Parent = button end
  skin.Position = UDim2.fromScale(0, 0)
  skin.Size = UDim2.fromScale(1, 1)
  skin.ZIndex = 18
  skin.Image = scope == "global" and "rbxassetid://84589903135132" or "rbxassetid://90528629970043"
  skin.ImageTransparency = 0
  skin.ImageColor3 = Color3.new(1, 1, 1)
  skin:SetAttribute("DefaultImage", skin.Image)
  local caption = button:FindFirstChild("Caption")
  if not caption then caption = display.Header.Subtitle:Clone() caption.Name = "Caption" caption.Parent = button end
  caption.Position = UDim2.fromOffset(12, 6)
  caption.Size = UDim2.new(1, -24, 1, -14)
  caption.AnchorPoint = Vector2.zero
  caption.BackgroundTransparency = 1
  caption.Text = string.upper(scope)
  caption.TextXAlignment = Enum.TextXAlignment.Center
  caption.TextYAlignment = Enum.TextYAlignment.Center
  caption.TextColor3 = Color3.fromRGB(255, 249, 224)
  caption.TextTransparency = 0
  caption.ZIndex = 19
  scaleText(caption, 20, 28)
  textOutline(caption, 2.5)
  buttons[index] = button
 end
 for index, button in ipairs(buttons) do
  button.NextSelectionLeft = buttons[(index + 1) % 3 + 1]
  button.NextSelectionRight = buttons[index % 3 + 1]
 end
end
if not existing then
 existing = Instance.new("ScreenGui")
 existing.Name = "PlaygroundLeaderboards"
 existing.Parent = StarterGui
end
assert(existing:IsA("ScreenGui"), "PlaygroundLeaderboards must be an editable ScreenGui")
existing.ResetOnSpawn = false
existing.IgnoreGuiInset = true
existing.Enabled = true
existing:SetAttribute("LeaderboardScopesVersion", 1)
local changed = {}
for _, name in ipairs({ "MostWins", "HighestLevel" }) do
 local model = assert(boards:FindFirstChild(name), name .. " is missing")
 local face = assert(model:FindFirstChild("Face"), name .. " Face is missing")
 local display = assert(face:FindFirstChild("Display"), name .. " Display is missing")
 if not backup:FindFirstChild(name) then
  local saved = display:Clone()
  saved.Name = name
  saved.Parent = backup
 end
 prepareDisplay(display, false)
 local localDisplay = existing:FindFirstChild(name)
 if localDisplay then localDisplay:Destroy() end
 localDisplay = display:Clone()
 localDisplay.Name = name
 localDisplay.Adornee = face
 localDisplay.Enabled = false
 prepareDisplay(localDisplay, true)
 localDisplay:SetAttribute("BoardId", name)
 localDisplay.Parent = existing
 table.insert(changed, localDisplay:GetFullName())
end
local controller = existing:FindFirstChild("Controller")
if not controller then
 controller = shell.Controller:Clone()
 controller.Name = "Controller"
 controller.Source = ""
 controller.Disabled = true
 controller.Parent = existing
end
backup:SetAttribute("SavedAt", backup:GetAttribute("SavedAt") or DateTime.now():ToIsoDate())
return { backup = backup:GetFullName(), ui = existing:GetFullName(), boards = changed, controller = controller:GetFullName(), controllerReady = false }

