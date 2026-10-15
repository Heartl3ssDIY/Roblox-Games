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
	Badge_01_Silver_Rim = Color3.fromRGB(132, 72, 162),
	Badge_02_Dark_Inset = Color3.fromRGB(53, 36, 77),
	Badge_03_Cyan_Face = Color3.fromRGB(151, 249, 44),
	Badge_04_Number_2 = Color3.fromRGB(235, 226, 191),
	Runner_01_Head = Color3.fromRGB(235, 226, 191),
	Runner_02_Torso = Color3.fromRGB(235, 226, 191),
	Runner_03_Left_Arm = Color3.fromRGB(235, 226, 191),
	Runner_04_Right_Arm = Color3.fromRGB(235, 226, 191),
	Runner_05_Left_Leg = Color3.fromRGB(235, 226, 191),
	Runner_06_Right_Leg = Color3.fromRGB(235, 226, 191),
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

local lightingProperties = {
 "Ambient", "OutdoorAmbient", "ColorShift_Top", "ColorShift_Bottom",
 "Brightness", "ClockTime", "ExposureCompensation", "EnvironmentDiffuseScale",
 "EnvironmentSpecularScale", "FogColor", "FogStart", "FogEnd", "GlobalShadows",
 "ShadowSoftness", "GeographicLatitude",
}

function Theme.ApplyEnvironment(theme)
 local profiles = game:GetService("ServerStorage"):FindFirstChild("GBloxCourseEnvironments")
 local profile = profiles and profiles:FindFirstChild(theme)
 if not profile then return end
 local lighting = game:GetService("Lighting")
 local renderers = {}
 for _,className in {"Sky", "Atmosphere"} do
  local reference = profile:FindFirstChild(className .. "Reference")
  assert(reference and reference:IsA("ObjectValue") and reference.Value and reference.Value:IsA(className), "Missing environment " .. className)
  renderers[className] = reference.Value
 end
 for _,name in lightingProperties do
  local value = profile:GetAttribute(name)
  if value ~= nil then lighting[name] = value end
 end
 for className,target in renderers do
  for _,current in lighting:GetChildren() do
   if current:IsA(className) and current ~= target then
    local destination = profiles
    for _,saved in profiles:GetChildren() do
     local reference = saved:FindFirstChild(className .. "Reference")
     if reference and reference:IsA("ObjectValue") and reference.Value == current then destination = saved break end
    end
    current.Parent = destination
   end
  end
  target.Parent = lighting
 end
end

function Theme.Apply(theme, root)
	assert(theme == "Normal" or theme == "Halloween", "Theme must be Normal or Halloween")
	local count = 0
	for _, course in ipairs((root or workspace):GetChildren()) do
		if Theme.IsCourse(course) then count += Theme.ApplyCourse(course, theme) end
	end
	Theme.ApplyEnvironment(theme)
	return count
end

return Theme


