local function build(parent)
	assert(parent and parent:IsA("StarterGui"), "A StarterGui parent is required")
	assert(not parent:FindFirstChild("GBloxHalloweenControls"), "GBloxHalloweenControls already exists")
	local gui = Instance.new("ScreenGui")
	gui.Name = "GBloxHalloweenControls"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = 45
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui:SetAttribute("FallbackSplatEnabled", true)
	gui:SetAttribute("Purpose", "Free seasonal Course 1 controls; upload your orange splat to PumpkinSplat.Artwork.Image")

	local function make(class, name, owner, properties)
		local object = Instance.new(class)
		object.Name = name
		for key, value in pairs(properties or {}) do object[key] = value end
		object.Parent = owner
		return object
	end
	local function corner(owner, radius)
		make("UICorner", "Corner", owner, {CornerRadius = UDim.new(0, radius)})
	end
	local function label(name, owner, text, position, size, colour)
		return make("TextLabel", name, owner, {
			BackgroundTransparency = 1, BorderSizePixel = 0, Active = false,
			Position = position, Size = size, Text = text, Font = Enum.Font.Arcade,
			TextSize = 12, TextColor3 = colour or Color3.fromRGB(223, 251, 255),
			TextStrokeColor3 = Color3.fromRGB(5, 21, 29), TextStrokeTransparency = 0.5,
			TextWrapped = true, ZIndex = 3,
		})
	end

	local controls = make("Frame", "Controls", gui, {
		Position = UDim2.new(0, 16, 0.28, 0), Size = UDim2.fromOffset(116, 160),
		BackgroundColor3 = Color3.fromRGB(10, 31, 42), BackgroundTransparency = 0.18,
		BorderSizePixel = 0, Visible = false, Active = false,
	})
	corner(controls, 10)
	make("UIStroke", "Outline", controls, {Color = Color3.fromRGB(20, 166, 181), Thickness = 1.5, Transparency = 0.15})
	label("Heading", controls, "HALLOWEEN", UDim2.fromOffset(8, 4), UDim2.new(1, -16, 0, 18), Color3.fromRGB(255, 183, 76))

	local function ability(name, y, title, key, info)
		local button = make("TextButton", name, controls, {
			Position = UDim2.fromOffset(8, y), Size = UDim2.fromOffset(100, 40),
			BackgroundColor3 = Color3.fromRGB(17, 87, 105), BorderSizePixel = 0,
			Text = "", AutoButtonColor = true, Selectable = true,
			Active = true, ZIndex = 2,
		})
		corner(button, 8)
		make("UIStroke", "Outline", button, {Color = Color3.fromRGB(33, 212, 220), Thickness = 1})
		label("Caption", button, title, UDim2.fromOffset(4, 3), UDim2.new(1, -8, 0, 14))
		local keyLabel = label("Key", button, key, UDim2.fromOffset(4, 17), UDim2.new(1, -8, 0, 10), Color3.fromRGB(255, 197, 123))
		keyLabel.TextSize = 10
		local cooldown = label("Cooldown", button, "READY", UDim2.fromOffset(4, 27), UDim2.new(1, -8, 0, 11))
		cooldown.TextSize = 10
		local help = label(name .. "Help", controls, info, UDim2.fromOffset(8, y + 41), UDim2.fromOffset(100, 17))
		help.TextSize = 10
		return button
	end
	local web = ability("Web", 24, "PLACE WEB", "V / L1", "TRAP 5s · CD 30s")
	local pumpkin = ability("Pumpkin", 82, "PUMPKIN", "B / R1", "THROW · SPLAT 3s")
	web.NextSelectionDown = pumpkin
	pumpkin.NextSelectionUp = web
	local status = label("Status", controls, "", UDim2.fromOffset(8, 140), UDim2.new(1, -16, 0, 18), Color3.fromRGB(255, 197, 123))
	status.TextSize = 10

	local splat = make("Frame", "PumpkinSplat", gui, {
		Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1, BorderSizePixel = 0, Active = false,
		Visible = false, ZIndex = 70,
	})
	local fallback = make("Frame", "Fallback", splat, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.58, 0.65), BackgroundTransparency = 1,
		BorderSizePixel = 0, Active = false, ZIndex = 70,
	})
	make("UIAspectRatioConstraint", "Aspect", fallback, {AspectRatio = 1.25})
	local blobs = {
		{0.50, 0.50, 0.70, 0.65, -8}, {0.26, 0.27, 0.38, 0.38, 14},
		{0.75, 0.34, 0.40, 0.35, -18}, {0.67, 0.76, 0.38, 0.40, 12},
		{0.24, 0.70, 0.35, 0.35, -24}, {0.10, 0.44, 0.12, 0.16, 5},
		{0.87, 0.68, 0.15, 0.12, -8}, {0.48, 0.10, 0.13, 0.14, 0},
	}
	for i, blob in ipairs(blobs) do
		local part = make("Frame", "Splat" .. i, fallback, {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(blob[1], blob[2]),
			Size = UDim2.fromScale(blob[3], blob[4]), Rotation = blob[5],
			BackgroundColor3 = Color3.fromRGB(239, 108, 24), BackgroundTransparency = 0.12,
			BorderSizePixel = 0, Active = false, ZIndex = 70,
		})
		make("UICorner", "Corner", part, {CornerRadius = UDim.new(0.5, 0)})
	end
	make("ImageLabel", "Artwork", splat, {
		Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1, Image = "", ScaleType = Enum.ScaleType.Fit,
		Active = false, ZIndex = 71,
	})
	local splatNotice = label("Notice", splat, "PUMPKIN SPLAT", UDim2.new(0.5, -130, 0.77, 0), UDim2.fromOffset(260, 28), Color3.fromRGB(255, 235, 208))
	splatNotice.TextSize = 17
	splatNotice.ZIndex = 72
	gui.Parent = parent
	return gui
end

return build
