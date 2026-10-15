local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
assert(not RunService:IsRunning(), "Stop the playtest before restoring map materials")

local backup = ServerStorage:FindFirstChild("PlaygroundRetroStudsBackup20261003")
assert(backup, "The retro studs backup is missing")
local entries = backup:FindFirstChild("Entries")
assert(entries and entries:IsA("Folder"), "The retro studs backup entries are missing")

local jobs = {}
local missing = {}
local excluded = 0
for _, entry in ipairs(entries:GetChildren()) do
	assert(entry:IsA("ObjectValue"), "Unexpected object in the material backup: " .. entry.Name)
	local changed = entry:GetAttribute("Changed")
	assert(typeof(changed) == "boolean", "Missing Changed flag on backup entry " .. entry.Name)
	if changed then
		local path = entry:GetAttribute("Path") or entry.Name
		local materialName = entry:GetAttribute("Material")
		local variant = entry:GetAttribute("MaterialVariant")
		assert(typeof(materialName) == "string" and typeof(variant) == "string", "Invalid material backup for " .. path)
		local material = Enum.Material[materialName]
		assert(material, "Unknown original material for " .. path)
		local object = entry.Value
		if object and object:IsA("BasePart") and object.Parent then
			table.insert(jobs, {object = object, material = material, variant = variant})
		else
			table.insert(missing, path)
		end
	else
		excluded += 1
	end
end

for _, job in ipairs(jobs) do
	job.object.Material = job.material
	job.object.MaterialVariant = job.variant
end
backup:SetAttribute("Restored", #missing == 0)
backup:SetAttribute("LastRestoreTime", os.time())

return {
	restoredParts = #jobs,
	excludedPartsPreserved = excluded,
	missingParts = missing,
	backupKept = true,
	materialVariantKept = true,
	restoreComplete = #missing == 0,
	geometryPropertiesNotWritten = true,
}
