local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local MaterialService = game:GetService("MaterialService")
assert(not RunService:IsRunning(), "Stop the playtest before verifying map materials")

local backup = ServerStorage:FindFirstChild("PlaygroundRetroStudsBackup20261003")
assert(backup, "The retro studs backup is missing")
local entries = backup:FindFirstChild("Entries")
local highlights = backup:FindFirstChild("Highlights")
assert(entries and entries:IsA("Folder"), "The retro studs backup entries are missing")
assert(highlights and highlights:IsA("Folder"), "The cartoon outline backup is missing")

local failures = {}
local failureCount = 0
local checks = 0
local partsChecked = 0
local changedParts = 0
local excludedParts = 0
local highlightsChecked = 0
local physicalPropertiesChecked = 0
local effectivePhysicalPropertiesChecked = 0
local function check(condition, message)
	checks += 1
	if condition then return end
	failureCount += 1
	if #failures < 25 then table.insert(failures, message) end
end

local properties = {
	"CFrame", "Size", "Color", "Transparency", "CanCollide", "CanTouch",
	"CanQuery", "Anchored", "CastShadow", "Reflectance", "CollisionGroup",
}
local surfaces = {"TopSurface", "BottomSurface", "LeftSurface", "RightSurface", "FrontSurface", "BackSurface"}
local function sameNumber(a, b)
	return typeof(a) == "number" and typeof(b) == "number" and math.abs(a - b) < 0.000001
end

local variant = MaterialService:GetMaterialVariant(Enum.Material.SmoothPlastic, "PlaygroundRetroStuds")
check(variant ~= nil and variant:IsA("MaterialVariant"), "The PlaygroundRetroStuds material variant is missing")
if variant then
	check(variant.BaseMaterial == Enum.Material.SmoothPlastic, "The retro studs variant must use SmoothPlastic")
	check(string.match(variant.ColorMap, "(%d+)$") == "10509831729", "The retro studs color map changed")
	check(string.match(variant.NormalMap, "(%d+)$") == "10509831753", "The retro studs normal map changed")
	check(variant.MaterialPattern == Enum.MaterialPattern.Regular, "The retro studs pattern must remain Regular")
	check(sameNumber(variant.StudsPerTile, 1), "The retro studs tile scale changed")
end

for _, entry in ipairs(entries:GetChildren()) do
	local path = entry:GetAttribute("Path") or entry.Name
	check(entry:IsA("ObjectValue"), path .. ": backup entry type changed")
	if not entry:IsA("ObjectValue") then continue end
	local object = entry.Value
	check(object ~= nil and object:IsA("BasePart") and object.Parent ~= nil, path .. ": original part is missing")
	if not object or not object:IsA("BasePart") or not object.Parent then continue end
	partsChecked += 1
	check(object:GetFullName() == path, path .. ": original hierarchy changed")
	local changed = entry:GetAttribute("Changed")
	check(typeof(changed) == "boolean", path .. ": missing Changed flag")
	if changed == true then
		changedParts += 1
		check(object.Material.Name == entry:GetAttribute("Material"), path .. ": original material changed")
		check(object.MaterialVariant == "PlaygroundRetroStuds", path .. ": expected PlaygroundRetroStuds variant")
	elseif changed == false then
		excludedParts += 1
		check(object.Material.Name == entry:GetAttribute("Material"), path .. ": excluded material changed")
		check(object.MaterialVariant == entry:GetAttribute("MaterialVariant"), path .. ": excluded variant changed")
	end
	for _, property in ipairs(properties) do
		check(object[property] == entry:GetAttribute(property), path .. ": " .. property .. " changed")
	end
	for _, property in ipairs(surfaces) do
		check(object[property].Name == entry:GetAttribute(property), path .. ": " .. property .. " changed")
	end
	local hadPhysicalProperties = entry:GetAttribute("HasCustomPhysicalProperties")
	if hadPhysicalProperties ~= nil then
		physicalPropertiesChecked += 1
		local physical = object.CustomPhysicalProperties
		check(typeof(hadPhysicalProperties) == "boolean", path .. ": invalid physical properties flag")
		check((physical ~= nil) == hadPhysicalProperties, path .. ": custom physical properties presence changed")
		if hadPhysicalProperties and physical then
			check(sameNumber(physical.Density, entry:GetAttribute("PhysicalDensity")), path .. ": density changed")
			check(sameNumber(physical.Friction, entry:GetAttribute("PhysicalFriction")), path .. ": friction changed")
			check(sameNumber(physical.Elasticity, entry:GetAttribute("PhysicalElasticity")), path .. ": elasticity changed")
			check(sameNumber(physical.FrictionWeight, entry:GetAttribute("PhysicalFrictionWeight")), path .. ": friction weight changed")
			check(sameNumber(physical.ElasticityWeight, entry:GetAttribute("PhysicalElasticityWeight")), path .. ": elasticity weight changed")
		end
	end
	if entry:GetAttribute("CurrentDensity") ~= nil then
		effectivePhysicalPropertiesChecked += 1
		local physical = object.CurrentPhysicalProperties
		check(sameNumber(physical.Density, entry:GetAttribute("CurrentDensity")), path .. ": effective density changed")
		check(sameNumber(physical.Friction, entry:GetAttribute("CurrentFriction")), path .. ": effective friction changed")
		check(sameNumber(physical.Elasticity, entry:GetAttribute("CurrentElasticity")), path .. ": effective elasticity changed")
		check(sameNumber(physical.FrictionWeight, entry:GetAttribute("CurrentFrictionWeight")), path .. ": effective friction weight changed")
		check(sameNumber(physical.ElasticityWeight, entry:GetAttribute("CurrentElasticityWeight")), path .. ": effective elasticity weight changed")
	end
end

local outlineProperties = {"Enabled", "FillColor", "OutlineColor", "FillTransparency", "OutlineTransparency"}
for _, entry in ipairs(highlights:GetChildren()) do
	local path = entry:GetAttribute("Path") or entry.Name
	check(entry:IsA("ObjectValue"), path .. ": outline backup entry type changed")
	if not entry:IsA("ObjectValue") then continue end
	local object = entry.Value
	check(object ~= nil and object:IsA("Highlight") and object.Parent ~= nil, path .. ": original cartoon outline is missing")
	if not object or not object:IsA("Highlight") or not object.Parent then continue end
	highlightsChecked += 1
	check(object:GetFullName() == path, path .. ": outline hierarchy changed")
	for _, property in ipairs(outlineProperties) do
		check(object[property] == entry:GetAttribute(property), path .. ": outline " .. property .. " changed")
	end
	check(object.DepthMode.Name == entry:GetAttribute("DepthMode"), path .. ": outline DepthMode changed")
	local adornee = entry:FindFirstChild("Adornee")
	check(adornee ~= nil and adornee:IsA("ObjectValue"), path .. ": original outline adornee backup is missing")
	if adornee and adornee:IsA("ObjectValue") then
		check(object.Adornee == adornee.Value, path .. ": outline Adornee changed")
	end
end

check(partsChecked > 0, "The map material backup contains no surviving parts")
check(changedParts > 0, "The map material backup contains no changed surfaces")
assert(failureCount == 0, tostring(failureCount) .. " verification failures:\n" .. table.concat(failures, "\n"))

return {
	verified = true,
	checks = checks,
	partsChecked = partsChecked,
	changedParts = changedParts,
	excludedParts = excludedParts,
	highlightsChecked = highlightsChecked,
	physicalPropertiesChecked = physicalPropertiesChecked,
	effectivePhysicalPropertiesChecked = effectivePhysicalPropertiesChecked,
	materialVariantVerified = true,
	geometryAndSurfacesPreserved = true,
	outlinePropertiesPreserved = true,
}
