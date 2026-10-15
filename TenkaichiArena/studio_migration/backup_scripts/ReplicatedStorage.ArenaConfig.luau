--!strict
-- ArenaConfig: field geometry + line placement for unit deployment.
-- Player side = red (negative Z), Opponent side = blue (positive Z), midline at Z=0.

local ArenaConfig = {}

ArenaConfig.arenaName = "Arena_WestCity"
ArenaConfig.center = Vector3.new(1000, 51, 0)   -- field centre, top surface Y
ArenaConfig.fieldHalfWidth = 28                 -- usable X spread each way from centre (field is 60 wide)
ArenaConfig.surfaceY = 51

-- Distance from the midline (Z=0) for each line. Player uses -Z, opponent +Z.
-- Tank sits furthest back (behind ranged back line).
ArenaConfig.lineZ = {
	front = 8,    -- closest to the midline
	mid   = 17,
	back  = 27,   -- ranged backline
	tank  = 36,   -- tank line, furthest back but still within ~30% of the short edge
}

-- Resolve which Z-line a unit uses. Tanks on the "back" line go to the tank row.
function ArenaConfig.lineForUnit(unit): string
	if unit.type == "Tank" then return "tank" end
	return unit.lines[1]   -- "front" | "mid" | "back"
end

-- World position for a unit deploying on `side` ("player"|"opponent"),
-- given which line and the index-th unit already on that line (0-based) and total expected.
-- Units spread sideways along X as more land on the same line.
function ArenaConfig.slotPosition(side: string, lineKey: string, index: number, countOnLine: number): Vector3
	local c = ArenaConfig.center
	local z = ArenaConfig.lineZ[lineKey] or ArenaConfig.lineZ.front
	local signZ = (side == "player") and -1 or 1
	local worldZ = c.Z + signZ * z

	-- spread along X: centre the row, space units evenly
	local spacing = 6
	local n = math.max(countOnLine, 1)
	local totalWidth = (n - 1) * spacing
	local startX = c.X - totalWidth / 2
	local worldX = startX + index * spacing
	-- clamp within field width
	local minX, maxX = c.X - ArenaConfig.fieldHalfWidth, c.X + ArenaConfig.fieldHalfWidth
	worldX = math.clamp(worldX, minX, maxX)

	return Vector3.new(worldX, ArenaConfig.surfaceY, worldZ)
end

-- Facing: player units face +Z (toward opponent), opponent units face -Z.
function ArenaConfig.facing(side: string): Vector3
	return (side == "player") and Vector3.new(0, 0, 1) or Vector3.new(0, 0, -1)
end

return ArenaConfig

