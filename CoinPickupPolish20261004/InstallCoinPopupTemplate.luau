assert(not game:GetService("RunService"):IsRunning(), "Keep Play stopped")
local gui = game.StarterGui.PlaygroundShell
local templates = gui:FindFirstChild("Templates")
assert(templates, "Existing editable templates folder required")
assert(not templates:FindFirstChild("CoinPickupPopup"), "Popup template already exists")
local popup = Instance.new("BillboardGui")
popup.Name = "CoinPickupPopup"
popup.Enabled = false
popup.Size = UDim2.fromOffset(84, 42)
popup.StudsOffsetWorldSpace = Vector3.new(0, 0.35, 0)
popup.AlwaysOnTop = false
popup.LightInfluence = 0
popup.MaxDistance = 65
popup.ClipsDescendants = false
local amount = Instance.new("TextLabel")
amount.Name = "Amount"
amount.Size = UDim2.fromScale(1, 1)
amount.BackgroundTransparency = 1
amount.Text = "+5"
amount.TextColor3 = Color3.fromRGB(255, 222, 98)
amount.Font = Enum.Font.FredokaOne
amount.TextSize = 28
amount.TextXAlignment = Enum.TextXAlignment.Center
amount.TextYAlignment = Enum.TextYAlignment.Center
amount.TextStrokeTransparency = 1
amount.Parent = popup
local stroke = Instance.new("UIStroke")
stroke.Name = "TextOutline"
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
stroke.Color = Color3.fromRGB(27, 45, 61)
stroke.Thickness = 2
stroke.LineJoinMode = Enum.LineJoinMode.Round
stroke.Parent = amount
popup.Parent = templates
return {template = popup:GetFullName(), enabled = popup.Enabled, label = amount.Text}

