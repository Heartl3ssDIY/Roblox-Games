local config = require(game.ReplicatedFirst.GBloxCourseLoading.LoadingConfig)

local function create(className, name, parent, properties)
	local object = Instance.new(className)
	object.Name = name
	for property, value in properties or {} do
		object[property] = value
	end
	object.Parent = parent
	return object
end

local gui = create("ScreenGui", "GBloxCourseLoadingScreen", game.ReplicatedFirst.GBloxCourseLoading, {
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

local soundButton = image("SoundButton", root, config.Images.SoundOn,
	UDim2.fromScale(0.97, 0.055), UDim2.fromOffset(52, 52), 8, "ImageButton")
soundButton.AnchorPoint = Vector2.new(1, 0)
soundButton.AutoButtonColor = false
create("UIScale", "HoverScale", soundButton, { Scale = 1 })
gui:SetAttribute("SoundMuted", false)

-- The shine uses the same image, so it follows the transparent angled edges.
for _, target in { title } do
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
return gui:GetFullName()

