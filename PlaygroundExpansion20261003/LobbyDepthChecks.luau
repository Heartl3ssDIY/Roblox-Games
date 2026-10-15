local lobby = workspace:FindFirstChild("Playground Lobby")
local root = lobby and lobby:FindFirstChild("Improvements20261003")
assert(root and root:GetAttribute("PlaygroundManaged") and root:GetAttribute("Applied"), "Depth pass must be installed first")
local results = {}
local function check(name, condition, details)
	assert(condition, name .. " failed: " .. tostring(details))
	table.insert(results, {name = name, ok = true, details = details})
end
local query = RaycastParams.new()
query.FilterType = Enum.RaycastFilterType.Include
query.FilterDescendantsInstances = {lobby}
query.RespectCanCollide = true
local function cast(a, direction) return workspace:Raycast(a, direction, query) end
local function floorNear(point)
	local hit = cast(point + Vector3.new(0, 0.3, 0), Vector3.new(0, -1.1, 0))
	return hit and hit.Position.Y
end
local function headroom(point)
	return not cast(point + Vector3.new(0, 0.3, 0), Vector3.new(0, 5.7, 0))
end
local gameplay = lobby.Gameplay
check("Spawn marker unchanged", gameplay.LobbySpawn.Position == Vector3.new(0, 4.6, 0))
check("Vote zone unchanged", gameplay.VoteZone.Position == Vector3.new(88, 10, -82) and gameplay.VoteZone.Size == Vector3.new(74, 12, 60))
check("Shop zone unchanged", gameplay.ShopZone.Position == Vector3.new(-107, 10, -31) and gameplay.ShopZone.Size == Vector3.new(34, 12, 38))
check("Lobby bounds unchanged", gameplay.LobbyBounds.Size == Vector3.new(320, 80, 304) and gameplay.LobbyBounds.Position == Vector3.new(0, 40, 0))
for _, x in ipairs({-24, -12, 0, 12, 24}) do
	for _, z in ipairs({-24, -12, 0, 12, 24}) do
		local point = Vector3.new(x, 4, z)
		check("Spawn floor " .. x .. "," .. z, math.abs((floorNear(point) or -100) - 4) < 0.02)
		check("Spawn headroom " .. x .. "," .. z, headroom(point))
	end
end
for _, specification in ipairs({
	{name = "NorthGardenStairs", steps = 30, rise = 23 / 30, run = 2.8, start = Vector3.new(-65, 4, -36), direction = Vector3.new(0, 0, -1)},
	{name = "WestGardenStairs", steps = 14, rise = 10 / 14, run = 2.5, start = Vector3.new(-119, 4, 65), direction = Vector3.new(0, 0, 1)},
}) do
	local stair = root.GreenLedges:FindFirstChild(specification.name)
	check(specification.name .. " authored", stair and stair:IsA("Model"))
	for index = 1, specification.steps do
		local part = stair:FindFirstChild("Step" .. index)
		local point = specification.start + specification.direction * ((index - 0.5) * specification.run) + Vector3.new(0, index * specification.rise, 0)
		check(specification.name .. " tread " .. index, part and part.CanCollide and part.Size.X >= 12 and math.abs(part.Position.Y + part.Size.Y / 2 - point.Y) < 0.01)
		check(specification.name .. " solid floor " .. index, math.abs((floorNear(point) or -100) - point.Y) < 0.02)
		check(specification.name .. " headroom " .. index, headroom(point))
	end
end
check("North garden landing joins ledge", math.abs((floorNear(Vector3.new(-65, 27.16, -127)) or -100) - 27.16) < 0.03)
check("West garden landing joins terrace", math.abs((floorNear(Vector3.new(-119, 14.16, 104)) or -100) - 14.16) < 0.03)
check("Social building door clear at torso height", not cast(Vector3.new(-94, 8, -31), Vector3.new(-20, 0, 0)))
check("Social building door has headroom", headroom(Vector3.new(-108, 4.88, -31)))
check("Cave entrance clear at torso height", not cast(Vector3.new(-108, 8, 54), Vector3.new(-30, 0, 0)))
check("Cave has headroom", headroom(Vector3.new(-132, 4.30, 54)))
for index = 1, 72 do
	local part = root.LookoutTower:FindFirstChild("LookoutStep" .. index)
	local theta = math.pi + index * math.pi * 2 / 24
	local point = Vector3.new(80 + math.cos(theta) * 15, 4 + index * 0.75, -14 + math.sin(theta) * 15)
	check("Lookout tread " .. index, part and part.CanCollide and part.Size.X >= 8 and math.abs(part.Position.Y + part.Size.Y / 2 - point.Y) < 0.01)
	check("Lookout solid floor " .. index, math.abs((floorNear(point) or -100) - point.Y) < 0.02)
	check("Lookout headroom " .. index, headroom(point))
end
check("Final lookout step can exit radially", not cast(Vector3.new(65, 60.2, -14), Vector3.new(-6, 0, 0)))
check("Observation floor reachable with one step", math.abs((floorNear(Vector3.new(59, 58.7, -14)) or -100) - 58.7) < 0.02)
check("Observation walking headroom", headroom(Vector3.new(59, 58.7, -14)))
local coinSites = {
	{Vector3.new(0, 6.4, 43), 4}, {Vector3.new(-39, 6.4, -9), 4}, {Vector3.new(-84, 6.4, -27), 4},
	{Vector3.new(-88, 6.4, -94), 4}, {Vector3.new(7, 6.4, -118), 4}, {Vector3.new(66, 6.4, -114), 4},
	{Vector3.new(-62, 8.7, 82), 6.4}, {Vector3.new(-101, 7.8, 33), 5.85},
	{Vector3.new(90, 18.4, 100), 16}, {Vector3.new(34, 6.4, 126), 4},
}
check("Ten coin markers preserved", #gameplay.CoinSpawns:GetChildren() == 10)
for index, data in ipairs(coinSites) do
	local marker = gameplay.CoinSpawns:FindFirstChild(string.format("Coin%02d", index))
	check("Coin marker unchanged " .. index, marker and (marker.Position - data[1]).Magnitude < 0.01)
	local point = Vector3.new(data[1].X, data[2], data[1].Z)
	check("Coin has accessible solid floor " .. index, floorNear(point) ~= nil)
	check("Coin has avatar headroom " .. index, headroom(point))
end
check("Waterfall decorative", not root.WaterfallAndStream.FallingWater.CanCollide and not root.WaterfallAndStream.Stream.CanCollide)
local actualParts = 0
for _, part in ipairs(root:GetDescendants()) do
	if part:IsA("BasePart") then
		actualParts += 1
		check("Anchored " .. part.Name, part.Anchored)
	elseif part:IsA("LuaSourceContainer") then error("Depth pass must contain authored geometry only") end
end
check("Substantial depth geometry", actualParts >= 1000, actualParts)
return {passed = #results, results = results, parts = actualParts, checkedAllTreads = 116, visualCliffsExtendBeyondGameplayBounds = true}
