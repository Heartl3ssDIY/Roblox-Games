local hudScales = {}
local hudScaleConnection
local function trackHudScale(object)
	if object:IsA("UIScale") and object.Name == "ResponsiveHudScale" then hudScales[object] = true end
end
for _, object in ipairs(gui.Parent:GetDescendants()) do trackHudScale(object) end
hudScaleConnection = gui.Parent.DescendantAdded:Connect(trackHudScale)

local function hudProfile(viewport)
	local short = math.min(viewport.X, viewport.Y)
	if viewport.X <= 900 or short <= 600 then return "PhoneScale" end
	if short <= 1024 and math.max(viewport.X, viewport.Y) <= 1400 then return "TabletScale" end
	return "DesktopScale"
end

local function refreshHudScale()
	local camera = workspace.CurrentCamera
	if not camera or camera.ViewportSize.X <= 0 or camera.ViewportSize.Y <= 0 then return end
	local profile = hudProfile(camera.ViewportSize)
	for scale in pairs(hudScales) do
		if not scale:IsDescendantOf(gui.Parent) then
			hudScales[scale] = nil
		else
			local value = scale:GetAttribute(profile)
			if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then value = 1 end
			value = math.clamp(value, 0.75, 1)
			if scale.Scale ~= value then scale.Scale = value end
		end
	end
end
refreshHudScale()
