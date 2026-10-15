local gui = script.Parent
local records = {}
local connections = {}
local alive = true
local captionFill = Color3.fromRGB(255, 249, 224)

local palette = {
	{ name = "Blue", color = Color3.fromRGB(42, 160, 255) },
	{ name = "Blue", color = Color3.fromRGB(89, 193, 244) },
	{ name = "Red", color = Color3.fromRGB(255, 81, 92) },
	{ name = "Green", color = Color3.fromRGB(94, 203, 162) },
	{ name = "Green", color = Color3.fromRGB(130, 225, 180) },
	{ name = "Gold", color = Color3.fromRGB(255, 211, 78) },
	{ name = "Cream", color = Color3.fromRGB(255, 255, 248) },
	{ name = "Black", color = Color3.fromRGB(48, 56, 75) },
	{ name = "Orange", color = Color3.fromRGB(255, 158, 69) },
	{ name = "Pink", color = Color3.fromRGB(255, 153, 166) },
	{ name = "Silver", color = Color3.fromRGB(194, 201, 206) },
	{ name = "Silver", color = Color3.fromRGB(162, 169, 184) },
	{ name = "Mud", color = Color3.fromRGB(151, 94, 44) },
}

local function closestColour(color)
	local nearest = "Cream"
	local distance = math.huge
	for _, entry in ipairs(palette) do
		local reference = entry.color
		local difference = (color.R - reference.R) ^ 2 + (color.G - reference.G) ^ 2 + (color.B - reference.B) ^ 2
		if difference < distance then
			distance = difference
			nearest = entry.name
		end
	end
	return nearest
end

local function connect(bucket, signal, callback)
	local connection = signal:Connect(callback)
	table.insert(bucket, connection)
	return connection
end

local function release(target)
	local record = records[target]
	if not record then return end
	records[target] = nil
	for _, connection in ipairs(record.connections) do connection:Disconnect() end
end

local bind
bind = function(target)
	if not alive or records[target] or not target:IsA("GuiObject") or target:GetAttribute("UISkinManaged") ~= true then return end
	local skin = target:FindFirstChild("ReusableSkin")
	if not skin or not skin:IsA("ImageLabel") then return end
	local record = { connections = {}, hovering = false, pressed = false }
	records[target] = record
	local function refresh()
		if not alive or records[target] ~= record or not target.Parent then return end
		if target.BackgroundTransparency ~= 1 then target.BackgroundTransparency = 1 end
		local caption = target:FindFirstChild("LiveCaption")
		if caption and caption:IsA("TextLabel") and (target:IsA("TextButton") or target:IsA("TextLabel")) then
			caption.Text = target.Text
			caption.TextColor3 = captionFill
			if target.TextTransparency ~= 1 then target.TextTransparency = 1 end
			if target.TextStrokeTransparency ~= 1 then target.TextStrokeTransparency = 1 end
		end
		local colourName = closestColour(target.BackgroundColor3)
		local asset = skin:GetAttribute("DefaultImage")
		if target:GetAttribute("UISkinDynamic") == true then asset = skin:GetAttribute(colourName .. "Image") or asset end
		if typeof(asset) == "string" and asset ~= "" and skin.Image ~= asset then skin.Image = asset end
		local tinted = target:IsA("GuiButton") and target.Active and (record.hovering or record.pressed)
		skin.ImageColor3 = tinted and Color3.new(0.94, 0.94, 0.94) or Color3.new(1, 1, 1)
		local selection = target:FindFirstChild("SelectionMark")
		if selection and selection:IsA("GuiObject") then
			if target:GetAttribute("UISkinSelectionFromOutline") == true then
				local outline = target:FindFirstChild("Outline")
				selection.Visible = outline ~= nil and outline:IsA("UIStroke") and outline.Enabled
			elseif target:GetAttribute("UISkinSelectionFromColour") == true then
				selection.Visible = colourName == "Gold"
			end
		end
		local sourceGradient = target:FindFirstChild("Progress")
		local skinGradient = skin:FindFirstChild("Progress")
		if sourceGradient and sourceGradient:IsA("UIGradient") and skinGradient and skinGradient:IsA("UIGradient") then
			for _, property in ipairs({ "Color", "Transparency", "Offset", "Rotation", "Enabled" }) do
				skinGradient[property] = sourceGradient[property]
			end
		end
	end
	record.refresh = refresh
	for _, property in ipairs({ "BackgroundColor3", "BackgroundTransparency" }) do
		connect(record.connections, target:GetPropertyChangedSignal(property), refresh)
	end
	if target:IsA("TextButton") or target:IsA("TextLabel") then
		for _, property in ipairs({ "Text", "TextColor3", "TextTransparency", "TextStrokeTransparency" }) do
			connect(record.connections, target:GetPropertyChangedSignal(property), refresh)
		end
	end
	connect(record.connections, target.AttributeChanged, refresh)
	connect(record.connections, skin.AttributeChanged, refresh)
	local gradient = target:FindFirstChild("Progress")
	if gradient and gradient:IsA("UIGradient") then
		for _, property in ipairs({ "Color", "Transparency", "Offset", "Rotation", "Enabled" }) do
			connect(record.connections, gradient:GetPropertyChangedSignal(property), refresh)
		end
	end
	local outline = target:FindFirstChild("Outline")
	if outline and outline:IsA("UIStroke") then connect(record.connections, outline:GetPropertyChangedSignal("Enabled"), refresh) end
	if target:IsA("GuiButton") then
		connect(record.connections, target.MouseEnter, function() record.hovering = true refresh() end)
		connect(record.connections, target.MouseLeave, function() record.hovering = false record.pressed = false refresh() end)
		connect(record.connections, target.MouseButton1Down, function() record.pressed = target.Active refresh() end)
		connect(record.connections, target.MouseButton1Up, function() record.pressed = false refresh() end)
		connect(record.connections, target.Activated, function() record.pressed = false refresh() end)
		connect(record.connections, target:GetPropertyChangedSignal("Active"), function()
			if not target.Active then record.pressed = false record.hovering = false end
			refresh()
		end)
		connect(record.connections, target:GetPropertyChangedSignal("Visible"), function()
			if not target.Visible then record.pressed = false record.hovering = false end
			refresh()
		end)
	end
	local function rebind(child)
		if child.Name ~= "ReusableSkin" and child.Name ~= "Progress" and child.Name ~= "Outline" and child.Name ~= "LiveCaption" and child.Name ~= "SelectionMark" then return end
		release(target)
		task.defer(function() if target:IsDescendantOf(gui) then bind(target) end end)
	end
	connect(record.connections, target.ChildAdded, rebind)
	connect(record.connections, target.ChildRemoved, rebind)
	connect(record.connections, target.AncestryChanged, function()
		if not target:IsDescendantOf(gui) then release(target) end
	end)
	refresh()
end

connect(connections, gui.DescendantAdded, function(descendant)
	task.defer(function()
		if not alive or not descendant:IsDescendantOf(gui) then return end
		bind(descendant)
		local parent = descendant.Parent
		if parent and parent:IsA("GuiObject") then bind(parent) end
	end)
end)

connect(connections, script.Destroying, function()
	alive = false
	for target in pairs(records) do release(target) end
	for _, connection in ipairs(connections) do connection:Disconnect() end
end)

for _, descendant in ipairs(gui:GetDescendants()) do bind(descendant) end

