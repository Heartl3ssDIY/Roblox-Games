local config = require(game.ReplicatedFirst.GBloxLoading.MenuConfig)

local function create(className, name, parent, properties)
	local object = Instance.new(className)
	object.Name = name
	for property, value in properties or {} do
		object[property] = value
	end
	object.Parent = parent
	return object
end

local gui = create("ScreenGui", "GBloxMenu", game.ReplicatedFirst.GBloxLoading, {
	IgnoreGuiInset = true,
	ResetOnSpawn = false,
	DisplayOrder = 100,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
gui:SetAttribute("State", "Loading")
gui:SetAttribute("Progress", 0)

local root = create("CanvasGroup", "Root", gui, {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(36, 122, 151),
	BorderSizePixel = 0,
})

local function image(name, parent, asset, position, size, zIndex, className)
	return create(className or "ImageLabel", name, parent, {
		Image = asset,
		BackgroundTransparency = 1,
		Position = position,
		Size = size,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = zIndex or 2,
	})
end

local background = image("Background", root, config.Images.Background,
	UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 1)
background.ScaleType = Enum.ScaleType.Crop

local title = image("Title", root, config.Images.Title,
	UDim2.fromScale(0.028, 0.045), UDim2.fromScale(0.33, 0.263), 5)

local loading = create("Frame", "LoadingScreen", root, {
	BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3,
})
local heading = create("TextLabel", "LoadingText", loading, {
	BackgroundTransparency = 1,
	Position = UDim2.fromScale(0.08, 0.66),
	Size = UDim2.fromScale(0.84, 0.20),
	Font = Enum.Font.Arcade,
	Text = "Loading...",
	TextColor3 = Color3.new(0, 0, 0),
	TextScaled = true,
	ZIndex = 3,
})
local track = image("ProgressBar", loading, config.Images.LoadingTrack,
	UDim2.fromScale(0.023, 0.865), UDim2.fromScale(0.954, 0.089), 3)
track.ScaleType = Enum.ScaleType.Stretch
local inner = create("Frame", "Inner", track, {
	BackgroundTransparency = 1,
	Position = UDim2.new(0, 6, 0, 6),
	Size = UDim2.new(1, -12, 1, -12),
	ClipsDescendants = true,
	ZIndex = 4,
})
local fill = image("Fill", inner, config.Images.LoadingFill,
	UDim2.fromScale(0, 0), UDim2.fromScale(0, 1), 4)
fill.ScaleType = Enum.ScaleType.Stretch
create("TextLabel", "Percentage", inner, {
	BackgroundTransparency = 1,
	Position = UDim2.fromScale(0.018, 0.05),
	Size = UDim2.fromScale(0.14, 0.9),
	Font = Enum.Font.Arcade,
	Text = "0%",
	TextColor3 = Color3.new(0, 0, 0),
	TextStrokeColor3 = Color3.fromRGB(138, 255, 255),
	TextStrokeTransparency = 0.7,
	TextScaled = true,
	ZIndex = 5,
})
create("TextButton", "Retry", loading, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromScale(0.5, 0.65),
	Size = UDim2.fromOffset(280, 46),
	BackgroundColor3 = Color3.fromRGB(138, 255, 255),
	Font = Enum.Font.Arcade,
	Text = "Retry loading",
	TextSize = 22,
	TextColor3 = Color3.new(0, 0, 0),
	Visible = false,
	ZIndex = 5,
})

local main = create("Frame", "MainScreen", root, {
	BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
	Visible = false, ZIndex = 3,
})
local platform = image("Platform", main, config.Images.Platform,
	UDim2.fromScale(0, 1), UDim2.fromScale(0.594, 0.591), 2)
platform.AnchorPoint = Vector2.new(0, 1)
local logo = image("GroupLogo", main, config.Images.GroupLogo,
	UDim2.fromScale(0.028, 0.78), UDim2.fromScale(0.178, 0.192), 3)

local buttons = {}
for _, entry in {
	{ "Play", 439, 128, 0.50 },
	{ "Shop", 498, 136, 0.65 },
	{ "Settings", 581, 128, 0.80 },
} do
	local name, width, height, y = table.unpack(entry)
	local button = image(name.."Button", main, config.Images[name],
		UDim2.fromScale(0.974, y), UDim2.fromScale(width / 1800, height / 1000), 5, "ImageButton")
	button.AnchorPoint = Vector2.new(1, 0)
	button.AutoButtonColor = false
	button:SetAttribute("Label", name)
	create("UIScale", "HoverScale", button, { Scale = 1 })
	buttons[name] = button
end
buttons.Play.NextSelectionDown = buttons.Shop
buttons.Shop.NextSelectionUp = buttons.Play
buttons.Shop.NextSelectionDown = buttons.Settings
buttons.Settings.NextSelectionUp = buttons.Shop

create("TextLabel", "Notice", main, {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.fromScale(0.97, 0.99),
	Size = UDim2.fromScale(0.50, 0.055),
	BackgroundTransparency = 1,
	Font = Enum.Font.Arcade,
	Text = "",
	TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1),
	TextStrokeTransparency = 0.2,
	ZIndex = 6,
})

local soundButton = image("SoundButton", root, config.Images.SoundOn,
	UDim2.fromScale(0.97, 0.055), UDim2.fromOffset(52, 52), 8, "ImageButton")
soundButton.AnchorPoint = Vector2.new(1, 0)
soundButton.AutoButtonColor = false
create("UIScale", "HoverScale", soundButton, { Scale = 1 })
gui:SetAttribute("SoundMuted", false)

-- The shine uses the same image, so it follows the transparent angled edges.
for _, target in { title, buttons.Play, buttons.Shop, buttons.Settings } do
	target.ImageColor3 = Color3.fromRGB(212, 220, 230)
	local shine = image("Gloss", target, target.Image,
		UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), target.ZIndex + 1)
	create("UIGradient", "Sweep", shine, {
		Rotation = 20,
		Offset = Vector2.new(-1.3, 0),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.36, 1),
			NumberSequenceKeypoint.new(0.48, 0),
			NumberSequenceKeypoint.new(0.54, 0),
			NumberSequenceKeypoint.new(0.68, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
	})
end

local sounds = create("Folder", "Sounds", gui)
for name, id in config.Sounds do
	create("Sound", name, sounds, { SoundId = id, Volume = name == "Hover" and 0.22 or 0.35 })
end
create("BindableEvent", "OpenShop", gui)
create("BindableEvent", "OpenSettings", gui)
return gui:GetFullName()

