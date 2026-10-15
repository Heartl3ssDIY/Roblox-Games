local root = workspace:FindFirstChild("Playground Lobby")
assert(root and root:GetAttribute("PlaygroundManaged") == true, "Managed lobby missing")
local results = {}
local function check(name, condition, details)
	assert(condition, name .. " failed: " .. tostring(details))
	table.insert(results, {name = name, ok = true, details = details})
end
local gameplay = root:FindFirstChild("Gameplay")
check("Gameplay folder", gameplay ~= nil)
local spawn = gameplay:FindFirstChild("LobbySpawn")
check("Central spawn", spawn and spawn:IsA("SpawnLocation") and spawn.Enabled and spawn.Neutral and spawn.Duration == 0)
check("Spawn placement", (spawn.Position - Vector3.new(0, 4.6, 0)).Magnitude < 0.01)
check("Clear central plaza", root:GetAttribute("SpawnPlazaDiameter") >= 48, root:GetAttribute("SpawnPlazaDiameter"))
local zone = gameplay:FindFirstChild("VoteZone")
check("Voting bounds", zone and zone.Size == Vector3.new(74, 12, 60) and zone.Position == Vector3.new(88, 10, -82))
check("Voting marker is invisible", zone.Transparency == 1 and not zone.CanCollide and not zone.CanTouch and not zone.CanQuery)
local choices = gameplay:FindFirstChild("VoteChoices")
check("Two authored vote pads", choices and #choices:GetChildren() == 2)
for _, name in ipairs({"BritishBulldog", "TagYoureIt"}) do
	local choice = choices:FindFirstChild(name)
	check(name .. " vote choice", choice and choice:GetAttribute("GameId") == name and choice:GetAttribute("Available") == true)
	check(name .. " vote marker is nonblocking", choice.Transparency == 1 and not choice.CanCollide and not choice.CanTouch)
end
local coins = gameplay:FindFirstChild("CoinSpawns")
check("Ten coin markers", coins and #coins:GetChildren() == 10)
local pickupIds = {}
for _, coin in ipairs(coins:GetChildren()) do
	local id = coin:GetAttribute("PickupId")
	check(coin.Name .. " identifier", typeof(id) == "string" and not pickupIds[id])
	pickupIds[id] = true
	check(coin.Name .. " template marker", not coin.CanCollide and not coin.CanTouch and coin.Transparency == 1 and coin:GetAttribute("Value") == 1)
end
check("Wide main paths", root:GetAttribute("MainPathWidth") >= 8, root:GetAttribute("MainPathWidth"))
local query = RaycastParams.new()
query.FilterType = Enum.RaycastFilterType.Include
query.FilterDescendantsInstances = {root}
query.RespectCanCollide = true
local function floorAt(x, z)
	local hit = workspace:Raycast(Vector3.new(x, 60, z), Vector3.new(0, -80, 0), query)
	return hit and hit.Position.Y
end
check("Spawn solid floor", math.abs((floorAt(0, 0) or -100) - 4) < 0.01)
check("Shallow pond has solid bottom", math.abs((floorAt(-84, 82) or -100) - 4) < 0.01)
local lastY = 4
for index = 1, 16 do
	local z = 48.5 + index * 3
	local y = floorAt(90, z)
	check("Terrace stair " .. index, y and math.abs(y - (4 + index * 0.75)) < 0.015, y)
	check("Terrace riser " .. index, y and y - lastY <= 0.76, y and y - lastY)
	lastY = y
end
check("Terrace stair meets peak", math.abs((floorAt(90, 99) or -100) - 16) < 0.02)
for index = 1, 4 do
	local expected = 4 + index * 0.6
	local northY = floorAt(-62, 48.5 + index * 3)
	local southY = floorAt(-62, 115.5 - index * 3)
	check("Bridge north stair " .. index, northY and math.abs(northY - expected) < 0.015, northY)
	check("Bridge south stair " .. index, southY and math.abs(southY - expected) < 0.015, southY)
end
for index = 1, 10 do
	local y = floorAt(-62, 62 + (index - 0.5) * 4)
	check("Bridge deck continuity " .. index, y and math.abs(y - 6.4) < 0.02, y)
end
local loose = {}
for _, value in ipairs(root:GetDescendants()) do
	if value:IsA("BasePart") and not value.Anchored then table.insert(loose, value:GetFullName()) end
	if value:IsA("LuaSourceContainer") then error("Lobby builder should contain geometry and templates only") end
end
check("All geometry anchored", #loose == 0, #loose)
check("No water gameplay hazard", root:GetAttribute("WaterIsDecorative") == true)
return {passed = #results, results = results, root = root:GetFullName(), partCount = root:GetAttribute("PartCount")}
