local gui = script.Parent
local records = {}
local connections = {}
local alive = true
local white = Color3.new(1, 1, 1)
local palettes = {
	Blue = Color3.fromRGB(42, 160, 235),
	Gold = Color3.fromRGB(255, 205, 57),
	Cream = Color3.fromRGB(255, 249, 224),
	Green = Color3.fromRGB(94, 203, 162),
	Red = Color3.fromRGB(255, 105, 120),
	Pink = Color3.fromRGB(255, 153, 166),
	Silver = Color3.fromRGB(176, 188, 206),
	Black = Color3.fromRGB(61, 69, 86),
	Orange = Color3.fromRGB(255, 153, 66),
	Mud = Color3.fromRGB(168, 108, 59),
	Purple = Color3.fromRGB(175, 124, 229),
}
local imagePalettes = {
	["90528629970043"] = "Blue", ["84589903135132"] = "Gold",
	["80217215544210"] = "Cream", ["117403446558356"] = "Cream",
	["78972575698291"] = "Green", ["96220174131051"] = "Red",
	["91168456076260"] = "Silver", ["137398265947826"] = "Black",
	["70427716988197"] = "Orange", ["98268172973975"] = "Mud",
	["109174047078490"] = "Purple",
}

local function connect(bucket, signal, callback)
	table.insert(bucket, signal:Connect(callback))
end

local function release(skin)
	local record = records[skin]
	if not record then return end
	records[skin] = nil
	if record.fallback.Parent then record.fallback.Visible = false end
	for _, connection in ipairs(record.connections) do connection:Disconnect() end
end

local function tint(color, imageColor)
	return Color3.new(color.R * imageColor.R, color.G * imageColor.G, color.B * imageColor.B)
end

local function faceColor(skin, fallback)
	local image = skin.Image
	local id = string.match(image, "^rbxassetid://(%d+)") or string.match(image, "[?&]id=(%d+)")
	local palette = id and imagePalettes[id]
	if palette then return palettes[palette] end
	for name, color in pairs(palettes) do
		if image ~= "" and skin:GetAttribute(name .. "Image") == image then return color end
	end
	return fallback:GetAttribute("FallbackFaceColor") or palettes.Cream
end

local function bind(skin)
	if not alive or records[skin] or not (skin:IsA("ImageLabel") or skin:IsA("ImageButton")) then return end
	local parent = skin.Parent
	local fallback = parent and parent:FindFirstChild(skin.Name .. "Fallback")
	if not fallback or not fallback:IsA("Frame") or fallback:GetAttribute("BackgroundFallbackFor") ~= skin.Name then return end
	local edge = fallback:FindFirstChild("Edge")
	local face = edge and edge:FindFirstChild("Face")
	if not edge or not face then return end
	local record = { connections = {}, fallback = fallback }
	records[skin] = record
	local function refresh()
		if not alive or records[skin] ~= record or skin.Parent ~= fallback.Parent then return end
		local transparency = math.clamp(skin.ImageTransparency, 0, 1)
		fallback.Visible = skin.Visible and skin.Image ~= "" and not skin.IsLoaded and transparency < 1
		fallback.BackgroundTransparency = transparency
		edge.BackgroundTransparency = transparency
		face.BackgroundTransparency = transparency
		fallback.BackgroundColor3 = tint(fallback:GetAttribute("FallbackInkColor") or Color3.fromRGB(31, 38, 60), skin.ImageColor3)
		local color = faceColor(skin, fallback)
		edge.BackgroundColor3 = tint(color:Lerp(white, 0.72), skin.ImageColor3)
		face.BackgroundColor3 = tint(color, skin.ImageColor3)
	end
	record.refresh = refresh
	for _, property in ipairs({ "IsLoaded", "Image", "ImageTransparency", "ImageColor3", "Visible" }) do
		connect(record.connections, skin:GetPropertyChangedSignal(property), refresh)
	end
	connect(record.connections, skin.AttributeChanged, refresh)
	connect(record.connections, fallback.AttributeChanged, refresh)
	connect(record.connections, skin.AncestryChanged, function()
		if not skin:IsDescendantOf(gui) or skin.Parent ~= fallback.Parent then release(skin) end
	end)
	connect(record.connections, fallback.AncestryChanged, function()
		if not fallback:IsDescendantOf(gui) or fallback.Parent ~= skin.Parent then release(skin) end
	end)
	refresh()
end

connect(connections, gui.DescendantAdded, function(descendant)
	task.defer(function()
		if not alive or not descendant:IsDescendantOf(gui) then return end
		bind(descendant)
		if descendant:IsA("Frame") then
			local name = descendant:GetAttribute("BackgroundFallbackFor")
			local parent = descendant.Parent
			local skin = typeof(name) == "string" and parent and parent:FindFirstChild(name)
			if skin then bind(skin) end
		end
	end)
end)
connect(connections, script.Destroying, function()
	alive = false
	for skin in pairs(records) do release(skin) end
	for _, connection in ipairs(connections) do connection:Disconnect() end
end)
for _, descendant in ipairs(gui:GetDescendants()) do bind(descendant) end

