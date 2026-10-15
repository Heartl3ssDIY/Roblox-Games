local ArenaCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("ArenaCatalog"))
local ArenaConfig = {}

ArenaConfig.arenaName = "Arena_Tenkaichi"
ArenaConfig.displayName = "Tenkaichi Tournament"
ArenaConfig.progressionKey = "Tenkaichi"
ArenaConfig.lineZ = { front = 12, mid = 20, back = 32, tank = 38 }

function ArenaConfig.getArena(arenaName)
    local entry = ArenaCatalog.find(arenaName or ArenaConfig.arenaName)
    return entry and workspace:FindFirstChild(entry.modelName)
end

function ArenaConfig.getOrigin()
	local arena = ArenaConfig.getArena()
	return arena and arena:FindFirstChild("BattleOrigin")
end

function ArenaConfig.lineForUnit(unit)
	return unit.type == "Tank" and "tank" or unit.lines[1]
end

function ArenaConfig.slotPosition(side, line, index, count)
	local origin = assert(ArenaConfig.getOrigin(), "BattleOrigin is missing")
	local width = origin:GetAttribute("HalfWidth") or 29
	local columns = math.min(count, 12)
	local row = math.floor(index / 12)
	local rowCount = math.min(12, count - row * 12)
	local spacing = math.min(7, width * 2 / math.max(columns - 1, 1))
	local x = (index % 12 - (rowCount - 1) / 2) * spacing
	local depth = origin:GetAttribute("HalfDepth") or 43.5
	local z = math.min(depth - 3, (ArenaConfig.lineZ[line] or 12) + row * 3.5)
	return origin.CFrame:PointToWorldSpace(Vector3.new(x, 0, side == "player" and -z or z))
end

function ArenaConfig.facing(side)
	local origin = assert(ArenaConfig.getOrigin(), "BattleOrigin is missing")
	return origin.CFrame:VectorToWorldSpace(Vector3.new(0, 0, side == "player" and 1 or -1))
end

function ArenaConfig.clampPosition(position)
	local origin = assert(ArenaConfig.getOrigin(), "BattleOrigin is missing")
	local point = origin.CFrame:PointToObjectSpace(position)
	local width = origin:GetAttribute("HalfWidth") or 29
	local depth = origin:GetAttribute("HalfDepth") or 29
	return origin.CFrame:PointToWorldSpace(Vector3.new(
		math.clamp(point.X, -width, width), point.Y, math.clamp(point.Z, -depth, depth)
	))
end

return ArenaConfig


