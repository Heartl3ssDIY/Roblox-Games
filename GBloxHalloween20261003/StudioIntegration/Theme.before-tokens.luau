local Theme = {}

local colors = {
	Flat_Platform_Cyan = Color3.fromRGB(151, 249, 44),
	Flat_Platform_DarkMetal = Color3.fromRGB(53, 36, 77),
	Flat_Platform_Edge = Color3.fromRGB(132, 72, 162),
	Flat_Platform_RunSurface = Color3.fromRGB(91, 77, 111),
	RedWheel_Glow = Color3.fromRGB(151, 249, 44),
	RedWheel_Gunmetal = Color3.fromRGB(53, 36, 77),
	RedWheel_Hub = Color3.fromRGB(53, 36, 77),
	RedWheel_Teeth = Color3.fromRGB(235, 226, 191),
	RedSpike_Base_Cyan = Color3.fromRGB(151, 249, 44),
	RedSpike_Base_DarkMetal = Color3.fromRGB(53, 36, 77),
	RedSpike_Base_Edge = Color3.fromRGB(132, 72, 162),
	RedSpike_Base_RunSurface = Color3.fromRGB(91, 77, 111),
	Grey_Ridged_Block_Obstacle = Color3.fromRGB(91, 77, 111),
	SpeedBoost_Arrows = Color3.fromRGB(235, 226, 191),
	SpeedBoost_CyanCore = Color3.fromRGB(151, 249, 44),
	SpeedBoost_DarkEdge = Color3.fromRGB(53, 36, 77),
	SpeedBoost_SilverRim = Color3.fromRGB(132, 72, 162),
	Green_EndZone_Frame = Color3.fromRGB(132, 72, 162),
	Green_EndZone_Glass = Color3.fromRGB(151, 249, 44),
	Green_EndZone_NeonBorder = Color3.fromRGB(151, 249, 44),
}

local colorAttribute = "GBloxNormalColor"
local schemaAttribute = "GBloxThemeSnapshotVersion"

function Theme.IsCourse(instance)
	return (instance:IsA("Folder") or instance:IsA("Model"))
		and instance.Name:lower():match("^%s*course%s*%-%s*round%s*%d+%s*$") ~= nil
end

function Theme.IsSupported(part)
	return part:IsA("MeshPart") and colors[part.Name] ~= nil
end

function Theme.ApplyPart(part, theme)
	assert(theme == "Normal" or theme == "Halloween", "Theme must be Normal or Halloween")
	if not Theme.IsSupported(part) then return false end
	if part:GetAttribute(schemaAttribute) ~= 1 then
		if theme == "Normal" then return false end
		part:SetAttribute(colorAttribute, part.Color)
		part:SetAttribute(schemaAttribute, 1)
	end
	local normalColor = part:GetAttribute(colorAttribute)
	assert(typeof(normalColor) == "Color3", "Missing original color for " .. part:GetFullName())
	part.Color = theme == "Halloween" and colors[part.Name] or normalColor
	return true
end

function Theme.ApplyCourse(course, theme)
	assert(theme == "Normal" or theme == "Halloween", "Theme must be Normal or Halloween")
	assert(Theme.IsCourse(course), "Expected a course folder")
	local count = 0
	for _, part in ipairs(course:GetDescendants()) do
		if Theme.ApplyPart(part, theme) then count += 1 end
	end
	return count
end

function Theme.Apply(theme, root)
	assert(theme == "Normal" or theme == "Halloween", "Theme must be Normal or Halloween")
	local count = 0
	for _, course in ipairs((root or workspace):GetChildren()) do
		if Theme.IsCourse(course) then count += Theme.ApplyCourse(course, theme) end
	end
	return count
end

return Theme
