assert(game.PlaceId==106769122906103,"Wrong place")
local ServerStorage=game:GetService("ServerStorage")
local Lighting=game:GetService("Lighting")
local settings=assert(game.ReplicatedStorage:FindFirstChild("GBloxCourseTheme"))
local scriptObject=game.ServerScriptService.GBloxCourseTheme.Theme
local editor=game:GetService("ScriptEditorService")
local before="local Theme = {}\n\nlocal colors = {\n\tFlat_Platform_Cyan = Color3.fromRGB(151, 249, 44),\n\tFlat_Platform_DarkMetal = Color3.fromRGB(53, 36, 77),\n\tFlat_Platform_Edge = Color3.fromRGB(132, 72, 162),\n\tFlat_Platform_RunSurface = Color3.fromRGB(91, 77, 111),\n\tRedWheel_Glow = Color3.fromRGB(151, 249, 44),\n\tRedWheel_Gunmetal = Color3.fromRGB(53, 36, 77),\n\tRedWheel_Hub = Color3.fromRGB(53, 36, 77),\n\tRedWheel_Teeth = Color3.fromRGB(235, 226, 191),\n\tRedSpike_Base_Cyan = Color3.fromRGB(151, 249, 44),\n\tRedSpike_Base_DarkMetal = Color3.fromRGB(53, 36, 77),\n\tRedSpike_Base_Edge = Color3.fromRGB(132, 72, 162),\n\tRedSpike_Base_RunSurface = Color3.fromRGB(91, 77, 111),\n\tGrey_Ridged_Block_Obstacle = Color3.fromRGB(91, 77, 111),\n\tSpeedBoost_Arrows = Color3.fromRGB(235, 226, 191),\n\tSpeedBoost_CyanCore = Color3.fromRGB(151, 249, 44),\n\tSpeedBoost_DarkEdge = Color3.fromRGB(53, 36, 77),\n\tSpeedBoost_SilverRim = Color3.fromRGB(132, 72, 162),\n\tGreen_EndZone_Frame = Color3.fromRGB(132, 72, 162),\n\tGreen_EndZone_Glass = Color3.fromRGB(151, 249, 44),\n\tGreen_EndZone_NeonBorder = Color3.fromRGB(151, 249, 44),\n\tBadge_01_Silver_Rim = Color3.fromRGB(132, 72, 162),\n\tBadge_02_Dark_Inset = Color3.fromRGB(53, 36, 77),\n\tBadge_03_Cyan_Face = Color3.fromRGB(151, 249, 44),\n\tBadge_04_Number_2 = Color3.fromRGB(235, 226, 191),\n\tRunner_01_Head = Color3.fromRGB(235, 226, 191),\n\tRunner_02_Torso = Color3.fromRGB(235, 226, 191),\n\tRunner_03_Left_Arm = Color3.fromRGB(235, 226, 191),\n\tRunner_04_Right_Arm = Color3.fromRGB(235, 226, 191),\n\tRunner_05_Left_Leg = Color3.fromRGB(235, 226, 191),\n\tRunner_06_Right_Leg = Color3.fromRGB(235, 226, 191),\n}\n\nlocal colorAttribute = \"GBloxNormalColor\"\nlocal schemaAttribute = \"GBloxThemeSnapshotVersion\"\n\nfunction Theme.IsCourse(instance)\n\treturn (instance:IsA(\"Folder\") or instance:IsA(\"Model\"))\n\t\tand instance.Name:lower():match(\"^%s*course%s*%-%s*round%s*%d+%s*$\") ~= nil\nend\n\nfunction Theme.IsSupported(part)\n\treturn part:IsA(\"MeshPart\") and colors[part.Name] ~= nil\nend\n\nfunction Theme.ApplyPart(part, theme)\n\tassert(theme == \"Normal\" or theme == \"Halloween\", \"Theme must be Normal or Halloween\")\n\tif not Theme.IsSupported(part) then return false end\n\tif part:GetAttribute(schemaAttribute) ~= 1 then\n\t\tif theme == \"Normal\" then return false end\n\t\tpart:SetAttribute(colorAttribute, part.Color)\n\t\tpart:SetAttribute(schemaAttribute, 1)\n\tend\n\tlocal normalColor = part:GetAttribute(colorAttribute)\n\tassert(typeof(normalColor) == \"Color3\", \"Missing original color for \" .. part:GetFullName())\n\tpart.Color = theme == \"Halloween\" and colors[part.Name] or normalColor\n\treturn true\nend\n\nfunction Theme.ApplyCourse(course, theme)\n\tassert(theme == \"Normal\" or theme == \"Halloween\", \"Theme must be Normal or Halloween\")\n\tassert(Theme.IsCourse(course), \"Expected a course folder\")\n\tlocal count = 0\n\tfor _, part in ipairs(course:GetDescendants()) do\n\t\tif Theme.ApplyPart(part, theme) then count += 1 end\n\tend\n\treturn count\nend\n\nfunction Theme.Apply(theme, root)\n\tassert(theme == \"Normal\" or theme == \"Halloween\", \"Theme must be Normal or Halloween\")\n\tlocal count = 0\n\tfor _, course in ipairs((root or workspace):GetChildren()) do\n\t\tif Theme.IsCourse(course) then count += Theme.ApplyCourse(course, theme) end\n\tend\n\treturn count\nend\n\nreturn Theme\n\r\n"
local source=[=[local Theme = {}

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

]=]
assert(editor:GetEditorSource(scriptObject)==before,"Theme script changed during inspection")
assert(not ServerStorage:FindFirstChild("BeforeNormalTheme20261004"),"Theme switch backup already exists")
assert(not ServerStorage:FindFirstChild("GBloxCourseEnvironments"),"Environment profiles already exist; review first")
local compiled,err=loadstring(source) assert(compiled,err)
local Theme=compiled()
local supported=0 local geometry={}
for _,course in workspace:GetChildren() do if Theme.IsCourse(course) then
for _,part in course:GetDescendants() do if part:IsA("BasePart") then
geometry[part]={cframe=part.CFrame,size=part.Size,anchored=part.Anchored,collide=part.CanCollide,touch=part.CanTouch,query=part.CanQuery}
if Theme.IsSupported(part) then supported+=1 assert(typeof(part:GetAttribute("GBloxNormalColor"))=="Color3" and part:GetAttribute("GBloxThemeSnapshotVersion")==1,"Original color missing") end
end end end end
local sky=assert(Lighting:FindFirstChildWhichIsA("Sky"))
local atmosphere=assert(Lighting:FindFirstChildWhichIsA("Atmosphere"))
local backup=Instance.new("Folder") backup.Name="BeforeNormalTheme20261004" backup:SetAttribute("ActiveTheme",settings:GetAttribute("ActiveTheme")) backup:SetAttribute("AppliedParts",settings:GetAttribute("AppliedParts"))
local savedSource=Instance.new("StringValue") savedSource.Name="ThemeSource" savedSource.Value=before savedSource.Parent=backup
local savedLighting=Instance.new("Folder") savedLighting.Name="LightingBefore" savedLighting.Parent=backup
for _,item in Lighting:GetChildren() do item:Clone().Parent=savedLighting end
local profiles=Instance.new("Folder") profiles.Name="GBloxCourseEnvironments"
local normal=Instance.new("Folder") normal.Name="Normal" normal.Parent=profiles
local halloween=Instance.new("Folder") halloween.Name="Halloween" halloween.Parent=profiles
local properties={"Ambient","OutdoorAmbient","ColorShift_Top","ColorShift_Bottom","Brightness","ClockTime","ExposureCompensation","EnvironmentDiffuseScale","EnvironmentSpecularScale","FogColor","FogStart","FogEnd","GlobalShadows","ShadowSoftness","GeographicLatitude"}
for _,name in properties do local value=Lighting[name] savedLighting:SetAttribute(name,value) halloween:SetAttribute(name,value) normal:SetAttribute(name,value) end
local lobby=game.HttpService:JSONDecode([=[{"lighting":{"ExposureCompensation":0,"ColorShift_Bottom":{"values":[0,0,0],"type":"Color3"},"FogColor":{"values":[0.7529412508010864,0.7529412508010864,0.7529412508010864],"type":"Color3"},"FogEnd":100000,"GeographicLatitude":0,"EnvironmentDiffuseScale":1,"EnvironmentSpecularScale":1,"ShadowSoftness":0.20000000298023224,"FogStart":0,"Ambient":{"values":[0.27450981736183167,0.27450981736183167,0.27450981736183167],"type":"Color3"},"OutdoorAmbient":{"values":[0.27450981736183167,0.27450981736183167,0.27450981736183167],"type":"Color3"},"GlobalShadows":true,"Brightness":3,"ColorShift_Top":{"values":[0,0,0],"type":"Color3"},"ClockTime":14.5},"sky":{"StarCount":3000,"SkyboxUp":"rbxassetid://6412503613","MoonTextureId":"rbxassetid://6444320592","SkyboxDn":"rbxassetid://6444884785","SkyboxOrientation":{"values":[0,0,0],"type":"Vector3"},"CelestialBodiesShown":true,"SkyboxBk":"rbxassetid://6444884337","SkyboxFt":"rbxassetid://6444884337","SunTextureId":"rbxassetid://6196665106","SunAngularSize":11,"SkyboxLf":"rbxassetid://6444884337","SkyboxRt":"rbxassetid://6444884337","MoonAngularSize":11},"atmosphere":{"Density":0.30000001192092896,"Haze":0,"Color":{"values":[0.7803921699523926,0.7803921699523926,0.7803921699523926],"type":"Color3"},"Decay":{"values":[0.4156862795352936,0.43921568989753723,0.4901960790157318],"type":"Color3"},"Glare":0,"Offset":0.25}}]=])
local function decode(v)
if type(v)=="table" then if v.type=="Color3" then return Color3.new(table.unpack(v.values)) elseif v.type=="Vector3" then return Vector3.new(table.unpack(v.values)) end end return v end
for _,name in {"Ambient","OutdoorAmbient","ColorShift_Top","ColorShift_Bottom"} do normal:SetAttribute(name,decode(lobby.lighting[name])) end
normal:SetAttribute("EnvironmentSource","G-Blox lobby sky, atmosphere and neutral color cast")
local normalSky=Instance.new("Sky") normalSky.Name="Sky_Normal"
for name,value in lobby.sky do normalSky[name]=decode(value) end normalSky.Parent=normal
local normalAtmosphere=Instance.new("Atmosphere") normalAtmosphere.Name="Atmosphere_Normal"
for name,value in lobby.atmosphere do normalAtmosphere[name]=decode(value) end normalAtmosphere.Parent=normal
for _,row in {{normal,"Sky",normalSky},{normal,"Atmosphere",normalAtmosphere},{halloween,"Sky",sky},{halloween,"Atmosphere",atmosphere}} do local ref=Instance.new("ObjectValue") ref.Name=row[2].."Reference" ref.Value=row[3] ref.Parent=row[1] end
local courseOne=assert(workspace:FindFirstChild(" Course -  round 1"))
local seasonal=assert(courseOne:FindFirstChild("HalloweenGameplay"))
local pumpkin=courseOne:FindFirstChild("Jack_O_Lantern")
if pumpkin then
local originalParent=Instance.new("ObjectValue") originalParent.Name="PumpkinOriginalParent" originalParent.Value=pumpkin.Parent originalParent.Parent=backup
local savedPumpkin=Instance.new("ObjectValue") savedPumpkin.Name="PumpkinModel" savedPumpkin.Value=pumpkin savedPumpkin.Parent=backup
backup:SetAttribute("PumpkinPivot",pumpkin:GetPivot())
for _,item in pumpkin:GetDescendants() do if item:IsA("BasePart") then if typeof(item:GetAttribute("HalloweenVisibleTransparency"))~="number" then item:SetAttribute("HalloweenVisibleTransparency",item.Transparency) end elseif item:IsA("Light") then if item:GetAttribute("HalloweenVisibleEnabled")==nil then item:SetAttribute("HalloweenVisibleEnabled",item.Enabled) end end end
pumpkin.Parent=assert(seasonal:FindFirstChild("Decorations"))
end
backup.Parent=ServerStorage profiles.Parent=ServerStorage
editor:UpdateSourceAsync(scriptObject,function(current) assert(current==before,"Concurrent theme edit") return source end)
settings:SetAttribute("ActiveTheme","Normal")
local changed=Theme.Apply("Normal") settings:SetAttribute("AppliedParts",changed)
local hidden=0 local disabledLights=0
for _,course in workspace:GetChildren() do if Theme.IsCourse(course) then local root=course:FindFirstChild("HalloweenGameplay") if root then for _,item in root:GetDescendants() do if item:IsA("BasePart") then if typeof(item:GetAttribute("HalloweenVisibleTransparency"))~="number" then item:SetAttribute("HalloweenVisibleTransparency",item.Transparency) end item.Transparency=1 hidden+=1 elseif item:IsA("Light") then if item:GetAttribute("HalloweenVisibleEnabled")==nil then item:SetAttribute("HalloweenVisibleEnabled",item.Enabled) end item.Enabled=false disabledLights+=1 end end end end end
for part,state in geometry do assert(part.CFrame==state.cframe and part.Size==state.size and part.Anchored==state.anchored and part.CanCollide==state.collide and part.CanTouch==state.touch and part.CanQuery==state.query,"Geometry or collision changed") end
assert(changed==supported,"Palette coverage differs")
backup:SetAttribute("Status","NormalApplied")
return game.HttpService:JSONEncode({ActiveTheme=settings:GetAttribute("ActiveTheme"),RestoredPaletteParts=changed,HiddenSeasonalParts=hidden,DisabledSeasonalLights=disabledLights,Sky=Lighting:FindFirstChildWhichIsA("Sky").Name,HalloweenEnvironmentStored=sky.Parent:GetFullName(),Backup=backup:GetFullName(),GeometryAndCollisionsUnchanged=true})
