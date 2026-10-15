local MODE = "apply"

local placeId = 111313211501470
local lobbyName = "Lobby_MainModeZone"
local backupName = "BeforeRoadJunction_20260926"
local targetNames = {
	"SUP_COL_0001",
	"SUP_COL_0002",
	"SUP_COL_0003",
	"SUP_COL_0019",
	"SUP_COL_0020",
}

assert(game.PlaceId == placeId, "Wrong place")
local lobby = workspace:FindFirstChild(lobbyName)
assert(lobby and lobby:IsA("Model"), "Active lobby not found")
assert(math.abs(lobby:GetScale() - 1.5) < 0.001, "Lobby scale changed; re-audit junction")
local supplemental = lobby:FindFirstChild("Collision") and lobby.Collision:FindFirstChild("Supplemental")
assert(supplemental, "Supplemental collision folder missing")
local serverStorage = game:GetService("ServerStorage")
local backup = serverStorage:FindFirstChild(backupName)

local function getPart(name, parent)
	local part = parent:FindFirstChild(name)
	assert(part and part:IsA("Part"), "Missing part: " .. name)
	return part
end

if MODE == "rollback" then
	assert(backup and backup:IsA("Folder"), "Road junction backup not found")
	for _, name in ipairs(targetNames) do
		getPart(name, backup)
	end
	for _, name in ipairs(targetNames) do
		local current = supplemental:FindFirstChild(name)
		if current then
			current:Destroy()
		end
		getPart(name, backup):Clone().Parent = supplemental
	end
	backup:Destroy()
	return {restored = true, count = #targetNames}
end

assert(MODE == "apply", "MODE must be apply or rollback")
assert(not backup, "Backup already exists; inspect or roll back before reapplying")

local main = getPart("SUP_COL_0001", supplemental)
local borderA = getPart("SUP_COL_0002", supplemental)
local borderB = getPart("SUP_COL_0003", supplemental)
local foundation = getPart("SUP_COL_0019", supplemental)
local arrival = getPart("SUP_COL_0020", supplemental)

assert(main:GetAttribute("SourceObject") == "Main route paving 0", "Main route source changed")
assert(arrival:GetAttribute("SourceObject") == "Arrival boulevard segment 1 paving", "Arrival source changed")
assert(foundation:GetAttribute("SourceObject") == "Arrival boulevard segment 1 dark foundation", "Foundation source changed")
assert((borderA:GetAttribute("SourceObject") or ""):find("Indigo paving border"), "Border source changed")
assert((borderB:GetAttribute("SourceObject") or ""):find("Indigo paving border"), "Border source changed")
assert(math.abs(main.Position.X) < 0.01 and math.abs(arrival.Position.X) < 0.01, "Roads moved")
assert(math.abs(main.Position.Z + 115.5) < 0.01 and math.abs(arrival.Position.Z + 292.5) < 0.01, "Roads moved")
assert(math.abs(math.abs(main.Orientation.Y) - 180) < 0.1, "Main route rotated")
assert(math.abs(math.abs(arrival.Orientation.Y) - 180) < 0.1, "Arrival road rotated")
assert(main.CanCollide and arrival.CanCollide, "Walk surfaces must remain collidable")

local mainLowerZ = main.Position.Z - main.Size.Z / 2
local arrivalUpperZ = arrival.Position.Z + arrival.Size.Z / 2
local overlap = arrivalUpperZ - mainLowerZ
assert(overlap > 19.4 and overlap < 19.6, "Unexpected road overlap")
assert(main.Size.Z - overlap > 20, "Trim would erase main route")

backup = Instance.new("Folder")
backup.Name = backupName
for _, name in ipairs(targetNames) do
	getPart(name, supplemental):Clone().Parent = backup
end
backup.Parent = serverStorage

main.Size = Vector3.new(main.Size.X, main.Size.Y, main.Size.Z - overlap)
main.CFrame = main.CFrame + Vector3.new(0, 0, overlap / 2)
borderA.CanCollide = false
borderA:SetAttribute("LobbyNoCollision", true)
borderB.CanCollide = false
borderB:SetAttribute("LobbyNoCollision", true)
foundation.CanCollide = false
foundation:SetAttribute("LobbyNoCollision", true)

local newMainLowerZ = main.Position.Z - main.Size.Z / 2
assert(math.abs(newMainLowerZ - arrivalUpperZ) < 0.01, "Road collision join did not align")
return {
	applied = true,
	backup = backup:GetFullName(),
	mainRoadStartZ = newMainLowerZ,
	arrivalRoadEndZ = arrivalUpperZ,
	visualMeshesChanged = false,
}

