local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local MaterialService = game:GetService("MaterialService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
assert(not RunService:IsRunning(), "Stop the playtest before changing map materials")

local mapNames = {"British Bulldog game", "Tag You're It", "Playground Lobby", "Stuck in the Mud"}
local variantName = "PlaygroundRetroStuds"
local backupName = "PlaygroundRetroStudsBackup20261003"
local colorMap = "rbxassetid://10509831729"
local normalMap = "rbxassetid://10509831753"
local maps = {}
for _, name in ipairs(mapNames) do
	local map = workspace:FindFirstChild(name)
	assert(map, "Missing map: " .. name)
	table.insert(maps, map)
end

local function isInk(part)
	for _, token in ipairs({"Ink", "Outline", "Rim"}) do
		if string.find(part.Name, token, 1, true) then return true end
	end
	local r = math.floor(part.Color.R * 255 + 0.5)
	local g = math.floor(part.Color.G * 255 + 0.5)
	local b = math.floor(part.Color.B * 255 + 0.5)
	return (r == 27 and g == 45 and b == 61)
		or (r == 28 and g == 43 and b == 62)
		or (r == 29 and g == 46 and b == 72)
end

local function exclusion(part)
	if not part.Anchored then return "Unanchored" end
	if part.Transparency > 0 then return "Transparent" end
	if part.Material == Enum.Material.Glass or part.Material == Enum.Material.Water then return "WaterOrGlass" end
	if string.find(part.Name, "Water", 1, true) then return "WaterOrGlass" end
	if isInk(part) then return "Outline" end
	return nil
end

local targets = {}
for _, map in ipairs(maps) do
	for _, part in ipairs(map:GetDescendants()) do
		if part:IsA("BasePart") and not exclusion(part) then
			assert(part.Material == Enum.Material.SmoothPlastic, "Unexpected base material: " .. part:GetFullName())
			table.insert(targets, part)
		end
	end
end
assert(#targets > 0, "No map surfaces were found")

local backup = ServerStorage:FindFirstChild(backupName)
local variant = MaterialService:FindFirstChild(variantName)
if backup then
	assert(backup:IsA("Folder") and backup:GetAttribute("CreatedBy") == "PlaygroundRetroStuds20261003", "Backup name belongs to another object")
end
if variant then
	assert(variant:IsA("MaterialVariant") and variant:GetAttribute("CreatedBy") == "PlaygroundRetroStuds20261003", "Material name belongs to another object")
end

local recording
pcall(function() recording = ChangeHistoryService:TryBeginRecording("Playground retro stud finish") end)

if not backup then
	backup = Instance.new("Folder")
	backup.Name = backupName
	backup:SetAttribute("CreatedBy", "PlaygroundRetroStuds20261003")
	backup:SetAttribute("CreatedAtUTC", DateTime.now():ToIsoDate())
	backup:SetAttribute("MaterialVariant", variantName)
	local entries = Instance.new("Folder")
	entries.Name = "Entries"
	entries.Parent = backup
	local highlights = Instance.new("Folder")
	highlights.Name = "Highlights"
	highlights.Parent = backup
	local properties = {"CFrame", "Size", "Color", "Transparency", "CanCollide", "CanTouch", "CanQuery", "Anchored", "CastShadow", "Reflectance", "CollisionGroup"}
	local surfaces = {"TopSurface", "BottomSurface", "LeftSurface", "RightSurface", "FrontSurface", "BackSurface"}
	local partCount = 0
	local highlightCount = 0
	for _, map in ipairs(maps) do
		for _, object in ipairs(map:GetDescendants()) do
			if object:IsA("BasePart") then
				partCount += 1
				local entry = Instance.new("ObjectValue")
				entry.Name = tostring(partCount)
				entry.Value = object
				entry:SetAttribute("Path", object:GetFullName())
				entry:SetAttribute("Map", map.Name)
				local reason = exclusion(object)
				entry:SetAttribute("Changed", reason == nil)
				entry:SetAttribute("Exclusion", reason or "")
				entry:SetAttribute("Material", object.Material.Name)
				entry:SetAttribute("MaterialVariant", object.MaterialVariant)
				for _, property in ipairs(properties) do entry:SetAttribute(property, object[property]) end
				for _, property in ipairs(surfaces) do entry:SetAttribute(property, object[property].Name) end
				local physical = object.CustomPhysicalProperties
				local currentPhysical = object.CurrentPhysicalProperties
				for _, property in ipairs({"Density", "Friction", "Elasticity", "FrictionWeight", "ElasticityWeight"}) do
					entry:SetAttribute("Current" .. property, currentPhysical[property])
				end
				entry:SetAttribute("HasCustomPhysicalProperties", physical ~= nil)
				if physical then
					entry:SetAttribute("PhysicalDensity", physical.Density)
					entry:SetAttribute("PhysicalFriction", physical.Friction)
					entry:SetAttribute("PhysicalElasticity", physical.Elasticity)
					entry:SetAttribute("PhysicalFrictionWeight", physical.FrictionWeight)
					entry:SetAttribute("PhysicalElasticityWeight", physical.ElasticityWeight)
				end
				entry.Parent = entries
			elseif object:IsA("Highlight") then
				highlightCount += 1
				local entry = Instance.new("ObjectValue")
				entry.Name = tostring(highlightCount)
				entry.Value = object
				entry:SetAttribute("Path", object:GetFullName())
				for _, property in ipairs({"Enabled", "FillColor", "OutlineColor", "FillTransparency", "OutlineTransparency"}) do entry:SetAttribute(property, object[property]) end
				entry:SetAttribute("DepthMode", object.DepthMode.Name)
				local adornee = Instance.new("ObjectValue")
				adornee.Name = "Adornee"
				adornee.Value = object.Adornee
				adornee.Parent = entry
				entry.Parent = highlights
			end
		end
	end
	backup.Parent = ServerStorage
end

if not variant then
	variant = Instance.new("MaterialVariant")
	variant.Name = variantName
	variant:SetAttribute("CreatedBy", "PlaygroundRetroStuds20261003")
	variant.Parent = MaterialService
end
variant.BaseMaterial = Enum.Material.SmoothPlastic
variant.ColorMap = colorMap
variant.NormalMap = normalMap
variant.MaterialPattern = Enum.MaterialPattern.Regular
variant.StudsPerTile = 1
variant.CustomPhysicalProperties = nil

local counts = {}
for _, part in ipairs(targets) do
	part.MaterialVariant = variantName
	local current = part.Parent
	while current and not table.find(maps, current) do current = current.Parent end
	local name = current and current.Name or "Unknown"
	counts[name] = (counts[name] or 0) + 1
end

if recording then pcall(function() ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit) end) end
return {changed = #targets, maps = counts, backup = backup:GetFullName(), material = variant:GetFullName(), studSize = variant.StudsPerTile}
