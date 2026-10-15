local StarterGui = game:GetService("StarterGui")
assert(not game:GetService("RunService"):IsRunning(), "Install in Edit mode")
assert(not StarterGui:FindFirstChild("PlaygroundFishingHUD"), "Fishing HUD already exists")
local gui = Instance.new("ScreenGui")
gui.Name = "PlaygroundFishingHUD"
gui.ResetOnSpawn = false
gui.DisplayOrder = 26
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui:SetAttribute("Purpose", "Active fishing boost timers; editable desktop and compact layouts")
local icons = { Coins = "rbxassetid://140694007262146", XP = "rbxassetid://116411095284602" }
for _, compact in { false, true } do
	local dock = Instance.new("Frame")
	dock.Name = compact and "CompactDock" or "DesktopDock"
	dock.AnchorPoint = Vector2.new(1, 1)
	dock.Position = compact and UDim2.new(1, -72, 1, -122) or UDim2.new(1, -18, 1, -18)
	dock.Size = compact and UDim2.fromOffset(112, 66) or UDim2.fromOffset(148, 88)
	dock.BackgroundTransparency = 1
	dock.Visible = not compact
	dock.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Name = "LayoutScale"
	scale.Parent = dock
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, compact and 8 or 12)
	layout.Parent = dock
	for order, name in { "Coins", "XP" } do
		local item = Instance.new("Frame")
		item.Name = name
		item.LayoutOrder = order
		item.BackgroundTransparency = 1
		item.Size = compact and UDim2.fromOffset(52, 66) or UDim2.fromOffset(68, 88)
		item.Visible = false
		item.Parent = dock
		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.BackgroundTransparency = 1
		icon.Size = UDim2.new(1, 0, 0, compact and 48 or 66)
		icon.Image = icons[name]
		icon.ScaleType = Enum.ScaleType.Fit
		icon.Parent = item
		local timer = Instance.new("TextLabel")
		timer.Name = "Timer"
		timer.BackgroundTransparency = 1
		timer.AnchorPoint = Vector2.new(0.5, 1)
		timer.Position = UDim2.fromScale(0.5, 1)
		timer.Size = UDim2.new(1, 0, 0, compact and 21 or 24)
		timer.Font = Enum.Font.FredokaOne
		timer.TextSize = compact and 16 or 20
		timer.TextColor3 = Color3.fromRGB(255, 251, 225)
		timer.Text = "5:00"
		timer.Parent = item
		local stroke = Instance.new("UIStroke")
		stroke.Name = "TextOutline"
		stroke.Color = Color3.fromRGB(9, 18, 47)
		stroke.Thickness = 1.6
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		stroke.Parent = timer
	end
end
gui.Parent = StarterGui
return "Authored fishing HUD created"
