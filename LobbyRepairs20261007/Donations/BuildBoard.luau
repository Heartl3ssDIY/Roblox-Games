assert(not game:GetService("RunService"):IsRunning(), "Stop Play before installing")
local lobby = workspace["Playground Lobby"]
assert(not lobby:FindFirstChild("DonationBoard"), "Board already exists")
assert(not game.StarterGui:FindFirstChild("PlaygroundDonations"), "Donation GUI already exists")
local ink = Color3.fromRGB(24, 35, 62)
local cream = Color3.fromRGB(255, 248, 216)
local gold = Color3.fromRGB(255, 205, 75)
local board = Instance.new("Model")
board.Name = "DonationBoard"
board:SetAttribute("ProductSetupRequired", true)
local origin = CFrame.new(-44, 4, 106)
local function part(name, size, at, color, studs)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color = name, size, origin * CFrame.new(at), color
	p.Anchored, p.Locked, p.Material = true, true, Enum.Material.SmoothPlastic
	p.TopSurface = studs and Enum.SurfaceType.Studs or Enum.SurfaceType.Smooth
	p.Parent = board
	return p
end
part("BaseInk", Vector3.new(20, 0.3, 8), Vector3.new(0, 0.15, 0), ink)
part("Base", Vector3.new(19.6, 0.3, 7.6), Vector3.new(0, 0.35, 0), Color3.fromRGB(141, 219, 228), true)
for _, x in {-7.8, 7.8} do
	part("Post", Vector3.new(1, 13, 1), Vector3.new(x, 6.8, 0), ink)
	part("PostInset", Vector3.new(0.6, 12.4, 0.15), Vector3.new(x, 6.8, -0.56), gold, true)
end
part("BoardInk", Vector3.new(18, 12.4, 0.8), Vector3.new(0, 9.3, 0), ink)
local face = part("Face", Vector3.new(17.6, 12, 0.12), Vector3.new(0, 9.3, -0.46), cream)
part("TopTrim", Vector3.new(18.4, 0.65, 1), Vector3.new(0, 15.7, 0), gold, true)
local surface = Instance.new("SurfaceGui")
surface.Name, surface.Face, surface.CanvasSize = "Sign", Enum.NormalId.Front, Vector2.new(720, 490)
surface.LightInfluence, surface.AlwaysOnTop = 0, false
surface.Parent = face
local function label(parent, name, text, pos, size, textSize, color)
	local v = Instance.new("TextLabel")
	v.Name, v.Text, v.Position, v.Size = name, text, pos, size
	v.BackgroundTransparency, v.BorderSizePixel = 1, 0
	v.Font, v.TextSize, v.TextColor3 = Enum.Font.FredokaOne, textSize, color or cream
	v.TextWrapped = true
	v.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Color, stroke.Thickness, stroke.ApplyStrokeMode = ink, 2, Enum.ApplyStrokeMode.Contextual
	stroke.Parent = v
	return v
end
label(surface, "Title", "SUPPORT THE\nPLAYGROUND", UDim2.fromOffset(20, 24), UDim2.new(1, -40, 0, 136), 58, gold)
label(surface, "Subtitle", "Enjoying the games?\nLeave a little thank-you!", UDim2.fromOffset(30, 180), UDim2.new(1, -60, 0, 94), 34)
label(surface, "Amounts", "50  •  100  •  250  •  1,000 ROBUX", UDim2.fromOffset(22, 300), UDim2.new(1, -44, 0, 60), 33, gold)
label(surface, "CallToAction", "INTERACT TO DONATE", UDim2.fromOffset(30, 388), UDim2.new(1, -60, 0, 55), 35)
local promptPart = part("Interaction", Vector3.new(1, 1, 1), Vector3.new(0, 3.5, -2.5), cream)
promptPart.Transparency, promptPart.CanCollide, promptPart.CanTouch = 1, false, false
local prompt = Instance.new("ProximityPrompt")
prompt.Name, prompt.ActionText, prompt.ObjectText = "OpenDonations", "Donate", "Support the playground"
prompt.KeyboardKeyCode, prompt.GamepadKeyCode = Enum.KeyCode.E, Enum.KeyCode.ButtonX
prompt.RequiresLineOfSight, prompt.MaxActivationDistance, prompt.HoldDuration = false, 12, 0
prompt:SetAttribute("PlaygroundDonationBoard", true)
prompt.Parent = promptPart
board.Parent = lobby

local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "PlaygroundDonations", false, 80
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
local panel = Instance.new("Frame")
panel.Name, panel.Size, panel.Position, panel.AnchorPoint = "Panel", UDim2.fromOffset(460, 460), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5)
panel.BackgroundTransparency, panel.Visible = 1, false
panel.Parent = gui
local scale = Instance.new("UIScale") scale.Name = "Fit" scale.Parent = panel
local function skin(parent, asset)
	local v = Instance.new("ImageLabel")
	v.Name, v.BackgroundTransparency, v.Image = "ReusableSkin", 1, "rbxassetid://" .. asset
	if asset == "117403446558356" or asset == "90528629970043" then v.Image = "https://www.roblox.com/asset/?id=" .. asset .. "&version=1" end
	v.Size, v.ScaleType, v.SliceCenter = UDim2.fromScale(1, 1), Enum.ScaleType.Slice, Rect.new(88, 88, 424, 232)
	v.ZIndex, v.Parent = 1, parent
end
skin(panel, "117403446558356")
local function button(parent, name, text, pos, size, asset)
	local v = Instance.new("TextButton")
	v.Name, v.Text, v.BackgroundTransparency = name, "", 1
	v.Position, v.Size, v.Selectable = pos, size, true
	v.Parent = parent
	skin(v, asset or "84589903135132")
	local t = label(v, "Label", text, UDim2.fromOffset(6, -2), UDim2.new(1, -12, 1, 0), 23)
	t.ZIndex = 2
	return v
end
local heading = label(panel, "Heading", "SUPPORT THE PLAYGROUND", UDim2.fromOffset(22, 22), UDim2.fromOffset(350, 54), 27)
heading.ZIndex = 2
button(panel, "Close", "X", UDim2.fromOffset(390, 20), UDim2.fromOffset(48, 48), "96220174131051")
local sub = label(panel, "Subtitle", "Choose a donation • no gameplay advantage", UDim2.fromOffset(24, 79), UDim2.fromOffset(412, 34), 18)
sub.ZIndex = 2
local amounts = Instance.new("Frame")
amounts.Name, amounts.BackgroundTransparency, amounts.Position, amounts.Size = "Amounts", 1, UDim2.fromOffset(28, 128), UDim2.fromOffset(404, 140)
amounts.ZIndex, amounts.Parent = 2, panel
for i, amount in {50, 100, 250, 1000} do
	button(amounts, "Donation"..amount, amount .. " ROBUX", UDim2.fromOffset(((i-1)%2)*210, math.floor((i-1)/2)*72), UDim2.fromOffset(194, 60))
end
local otherTitle = label(panel, "OtherTitle", "OTHER AMOUNT", UDim2.fromOffset(28, 283), UDim2.fromOffset(404, 28), 20)
otherTitle.ZIndex = 2
local input = Instance.new("TextBox")
input.Name, input.Position, input.Size = "OtherAmount", UDim2.fromOffset(30, 320), UDim2.fromOffset(194, 50)
input.BackgroundColor3, input.BorderSizePixel, input.TextColor3 = cream, 0, ink
input.PlaceholderText, input.Text, input.ClearTextOnFocus = "Robux amount", "", false
input.Font, input.TextSize, input.ZIndex = Enum.Font.FredokaOne, 22, 2
input.Parent = panel
local corner = Instance.new("UICorner") corner.CornerRadius = UDim.new(0, 10) corner.Parent = input
local edge = Instance.new("UIStroke") edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border edge.Color = ink edge.Thickness = 2 edge.Parent = input
button(panel, "OtherDonate", "DONATE", UDim2.fromOffset(240, 315), UDim2.fromOffset(194, 60), "90528629970043")
local status = label(panel, "Status", "Donations are coming soon.", UDim2.fromOffset(28, 388), UDim2.fromOffset(404, 46), 19)
status.ZIndex = 2
gui.Parent = game.StarterGui
local config = Instance.new("Folder") config.Name = "PlaygroundDonationProducts"
for _, amount in {50, 100, 250, 1000} do
	local entry = Instance.new("IntValue") entry.Name = "Donation" .. amount entry.Value = 0 entry:SetAttribute("BaseRobux", amount) entry.Parent = config
end
config.Parent = game.ReplicatedStorage
local result = Instance.new("RemoteEvent") result.Name = "PlaygroundDonationResult" result.Parent = game.ReplicatedStorage
return "Donation board and editable UI created; product IDs still needed."
