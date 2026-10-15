local dryRun = false
assert(not game:GetService("RunService"):IsRunning(), "Edit mode required")
local ServerStorage = game:GetService("ServerStorage")
local tag = assert(workspace:FindFirstChild("Tag You're It"), "Tag map missing")
local mud = assert(workspace:FindFirstChild("Stuck in the Mud"), "Mud map missing")
local backupName = "MapSurfaceSeparation20261004"
local backups = ServerStorage:FindFirstChild("AssetIntegrationBackups")
local previous = backups and backups:FindFirstChild(backupName)
if previous and previous:GetAttribute("Completed") then
	return { alreadyApplied = true, backup = previous:GetFullName() }
end
assert(not previous, "An unfinished map repair exists; inspect its backup before resuming")

local plan = {}
local reasons = {}
local function change(part, frame, size, reason)
	assert(part and part:IsA("BasePart"), "Expected map part")
	assert(size.X > 0 and size.Y > 0 and size.Z > 0, "Invalid part dimensions")
	local entry = plan[part]
	if not entry then
		entry = { part = part, originalFrame = part.CFrame, originalSize = part.Size }
		plan[part] = entry
	end
	entry.frame, entry.size, entry.reason = frame, size, reason
	reasons[reason] = (reasons[reason] or 0) + 1
end

local function worldSize(part)
	local cf, size = part.CFrame, part.Size
	return Vector3.new(
		math.abs(cf.RightVector.X) * size.X + math.abs(cf.UpVector.X) * size.Y + math.abs(cf.LookVector.X) * size.Z,
		math.abs(cf.RightVector.Y) * size.X + math.abs(cf.UpVector.Y) * size.Y + math.abs(cf.LookVector.Y) * size.Z,
		math.abs(cf.RightVector.Z) * size.X + math.abs(cf.UpVector.Z) * size.Y + math.abs(cf.LookVector.Z) * size.Z
	)
end

local function footprintOverlaps(a, b)
	for _, part in { a.part, b.part } do
		for _, axis in { part.CFrame.RightVector, part.CFrame.UpVector, part.CFrame.LookVector } do
			if math.abs(axis.Y) < 0.001 then
				local distance = math.abs((a.part.Position - b.part.Position):Dot(axis))
				local function radius(item)
					local cf, size = item.part.CFrame, item.part.Size
					return (math.abs(cf.RightVector:Dot(axis)) * size.X
						+ math.abs(cf.UpVector:Dot(axis)) * size.Y
						+ math.abs(cf.LookVector:Dot(axis)) * size.Z) * 0.5
				end
				if distance >= radius(a) + radius(b) - 0.015 then return false end
			end
		end
	end
	return true
end

local function differentColour(a, b)
	return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B) > 0.025
end

local floorReports = {}
for _, entry in { { tag, "GrassCourt" }, { mud, "PlaygroundFloor" } } do
	local map, floorName = entry[1], entry[2]
	local geometry = assert(map:FindFirstChild("Geometry"))
	local floor = assert(geometry:FindFirstChild(floorName))
	local ink = assert(geometry:FindFirstChild("IslandInk"))
	local floorTop = floor.Position.Y + floor.Size.Y * 0.5
	assert(math.abs(ink.Position.Y + ink.Size.Y * 0.5 - floorTop) < 0.02, "Unexpected island floor heights")
	change(ink, ink.CFrame - Vector3.new(0, 0.08, 0), ink.Size - Vector3.new(0, 0.16, 0), "Separate island foundation from coloured floor")
	local layers = {}
	for _, part in map:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 1 and not part.CanCollide then
			local size = worldSize(part)
			if size.Y <= 0.3 and part.Position.Y > floorTop and part.Position.Y < floorTop + 0.6 then
				table.insert(layers, { part = part, top = part.Position.Y + size.Y * 0.5, size = size })
			end
		end
	end
	table.sort(layers, function(a, b)
		if math.abs(a.top - b.top) > 0.001 then return a.top < b.top end
		return a.part:GetFullName() < b.part:GetFullName()
	end)
	local maximumLift = 0
	for i, layer in layers do
		local targetTop = math.max(layer.top, floorTop + 0.1)
		for j = 1, i - 1 do
			local below = layers[j]
			if differentColour(layer.part.Color, below.part.Color) and footprintOverlaps(layer, below) then
				targetTop = math.max(targetTop, below.newTop + 0.08)
			end
		end
		layer.newTop = targetTop
		local lift = targetTop - layer.top
		if lift > 0.001 then
			maximumLift = math.max(maximumLift, lift)
			change(layer.part, layer.part.CFrame + Vector3.new(0, lift, 0), layer.part.Size, "Separate overlapping floor paint layers")
		end
	end
	assert(maximumLift < 0.65, "Unexpected floor layer stack; inspect before applying")
	table.insert(floorReports, { map = map.Name, paintLayers = #layers, maximumLift = maximumLift, floorTopUnchanged = floorTop })
end

for _, part in tag:GetDescendants() do
	if part:IsA("BasePart") then
		if part.Name == "FenceColumnCream" or part.Name == "ColumnCap" then
			change(part, part.CFrame + Vector3.new(0, 0.06, 0), part.Size + Vector3.new(0, 0.12, 0), "Separate cream caps from ink tops")
		elseif part.Name == "GrassLipZ" and part.Parent == tag.Geometry then
			change(part, part.CFrame, part.Size + Vector3.new(0.24, 0, 0), "Separate grass lip from island side face")
		elseif part.Parent.Name == "LinkBridges" and part.Name:match("Surface$") then
			local trim = part.Size.X > part.Size.Z and Vector3.new(3.2, 0, 0) or Vector3.new(0, 0, 3.2)
			change(part, part.CFrame, part.Size - trim, "Remove coloured bridge overlap at loop joins")
		end
	end
end

for _, part in mud:GetDescendants() do
	if part:IsA("BasePart") then
		if part.Name == "BookSpine" then
			assert(part.Size.X > 1.49, "Unexpected book width")
			change(part, part.CFrame, Vector3.new(1.5, part.Size.Y, part.Size.Z), "Leave a gap between neighbouring book colours")
		elseif part.Name == "MonkeyHeader" then
			change(part, part.CFrame + Vector3.new(0, 0.06, 0), part.Size + Vector3.new(0, 0.12, 0), "Separate monkey-bar header from post tops")
		elseif part.Name == "StorageDoorTrim" then
			change(part, part.CFrame, part.Size - Vector3.new(0, 0.16, 0), "Inset door trim beneath storage colour top")
		end
	end
end

local rows = {}
for _, entry in plan do table.insert(rows, entry) end
table.sort(rows, function(a, b) return a.part:GetFullName() < b.part:GetFullName() end)
local report = { dryRun = dryRun, parts = #rows, reasons = reasons, floors = floorReports }
if dryRun then return report end

if not backups then
	backups = Instance.new("Folder")
	backups.Name = "AssetIntegrationBackups"
	backups.Parent = ServerStorage
end
local backup = Instance.new("Folder")
backup.Name = backupName
backup:SetAttribute("CreatedAt", DateTime.now():ToIsoDate())
backup.Parent = backups
for index, entry in rows do
	local record = Instance.new("ObjectValue")
	record.Name = string.format("Part%04d", index)
	record.Value = entry.part
	record:SetAttribute("OriginalPath", entry.part:GetFullName())
	record:SetAttribute("OriginalCFrame", entry.originalFrame)
	record:SetAttribute("OriginalSize", entry.originalSize)
	record:SetAttribute("OriginalCanCollide", entry.part.CanCollide)
	record:SetAttribute("Reason", entry.reason)
	record.Parent = backup
end
for _, entry in rows do
	entry.part.Size = entry.size
	entry.part.CFrame = entry.frame
end
backup:SetAttribute("Completed", true)
report.backup = backup:GetFullName()
return report
