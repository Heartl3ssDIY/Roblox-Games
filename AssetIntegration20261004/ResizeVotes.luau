local dryRun = false
assert(not game:GetService("RunService"):IsRunning(), "Edit mode required")
local ServerStorage = game:GetService("ServerStorage")
local lobby = assert(workspace:FindFirstChild("Playground Lobby"), "Lobby missing")
local alcove = assert(lobby:FindFirstChild("VotingAlcove"), "Voting alcove missing")
local gameplay = assert(lobby:FindFirstChild("Gameplay"), "Lobby gameplay missing")
local choices = assert(gameplay:FindFirstChild("VoteChoices"), "Vote choices missing")
local inner = assert(alcove:FindFirstChild("VotingInner"), "Voting inner paving missing")
local backupName = "CompactVotingStands20261004"
local backups = ServerStorage:FindFirstChild("AssetIntegrationBackups")
local previous = backups and backups:FindFirstChild(backupName)
if previous and previous:GetAttribute("Completed") then
	return { alreadyApplied = true, backup = previous:GetFullName() }
end
assert(not previous, "An unfinished voting resize exists; inspect its backup before resuming")

local plan = {}
local report = { dryRun = dryRun, stands = {} }
local scale = 0.75
local function change(part, frame, size)
	table.insert(plan, { part = part, frame = frame, size = size,
		originalFrame = part.CFrame, originalSize = part.Size })
end
for _, spec in { { "BritishBulldog", 68 }, { "TagYoureIt", 88 }, { "StuckInTheMud", 108 } } do
	local gameId, targetX = spec[1], spec[2]
	local stand = assert(alcove:FindFirstChild(gameId .. "Stand"), "Voting stand missing: " .. gameId)
	local pad = assert(stand:FindFirstChild("ChoicePad"))
	local rim = assert(stand:FindFirstChild("ChoicePadRim"))
	local baseY = rim.Position.Y - rim.Size.Y * 0.5
	local origin = Vector3.new(pad.Position.X, baseY, pad.Position.Z)
	local target = Vector3.new(targetX, baseY, pad.Position.Z)
	local desiredPadSize = pad.Size * scale
	local desiredRimSize = rim.Size * scale
	assert(targetX - desiredRimSize.X * 0.5 > inner.Position.X - inner.Size.X * 0.5 + 1)
	assert(targetX + desiredRimSize.X * 0.5 < inner.Position.X + inner.Size.X * 0.5 - 1)
	assert(target.Z - desiredRimSize.Z * 0.5 > inner.Position.Z - inner.Size.Z * 0.5 + 1)
	assert(target.Z + desiredRimSize.Z * 0.5 < inner.Position.Z + inner.Size.Z * 0.5 - 1)
	for _, part in stand:GetDescendants() do
		if part:IsA("BasePart") then
			local position = target + (part.Position - origin) * scale
			change(part, CFrame.new(position) * part.CFrame.Rotation, part.Size * scale)
		end
	end
	local trigger = assert(choices:FindFirstChild(gameId), "Vote trigger missing: " .. gameId)
	assert(trigger:GetAttribute("GameId") == gameId, "Vote trigger ID mismatch")
	local triggerBottom = baseY + 0.05
	change(trigger, CFrame.new(targetX, triggerBottom + 4, target.Z) * trigger.CFrame.Rotation,
		Vector3.new(desiredPadSize.X, 8, desiredPadSize.Z))
	table.insert(report.stands, { id = gameId, x = targetX, z = target.Z, baseY = baseY,
		padWidth = desiredPadSize.X, padDepth = desiredPadSize.Z, triggerHeight = 8 })
end
local zone = assert(gameplay:FindFirstChild("VoteZone"), "Vote zone missing")
change(zone, CFrame.new(inner.Position.X, zone.Position.Y, inner.Position.Z) * zone.CFrame.Rotation,
	Vector3.new(inner.Size.X, zone.Size.Y, inner.Size.Z))
report.parts = #plan
report.zoneSize = { inner.Size.X, zone.Size.Y, inner.Size.Z }
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
for index, entry in plan do
	local record = Instance.new("ObjectValue")
	record.Name = string.format("Part%04d", index)
	record.Value = entry.part
	record:SetAttribute("OriginalPath", entry.part:GetFullName())
	record:SetAttribute("OriginalCFrame", entry.originalFrame)
	record:SetAttribute("OriginalSize", entry.originalSize)
	record:SetAttribute("OriginalCanCollide", entry.part.CanCollide)
	record.Parent = backup
end
for _, entry in plan do
	entry.part.Size = entry.size
	entry.part.CFrame = entry.frame
end
backup:SetAttribute("Completed", true)
report.backup = backup:GetFullName()
return report
