-- Course folders may contain spaces; their round number determines order.
local Registry = {}

function Registry.Number(name)
	return tonumber(string.lower(name):match("^%s*course%s*%-%s*round%s*(%d+)%s*$"))
end

function Registry.Resolve(root, number, capacity)
	local candidates = {}
	for _, child in root:GetChildren() do
		if (Registry.Number(child.Name) or child:GetAttribute("RoundNumber")) == number then table.insert(candidates, child) end
	end
	if #candidates ~= 1 then
		return nil, #candidates == 0 and ("Course " .. number .. " has not been built yet.")
			or ("Multiple folders are named Course " .. number .. ".")
	end
	local course = candidates[1]
	local function binding(name)
		local ref = course:FindFirstChild(name)
		if ref and ref:IsA("ObjectValue") and ref.Value and ref.Value:IsDescendantOf(course) then return ref.Value end
	end
	local start = course:FindFirstChild("Start")
	local folder = binding("SpawnFolder") or (start and start:FindFirstChild("Spawn locs")) or course:FindFirstChild("Spawn locs")
	local finish = binding("FinishZone") or course:FindFirstChild("Green_EndZone_round"..number) or course:FindFirstChild("Green_EndZone")
	local bounds = binding("BoundsFolder") or course:FindFirstChild("out of bounds")
	if not folder or not finish or not bounds then
		return nil, ("Course %d needs valid SpawnFolder, FinishZone and BoundsFolder references."):format(number)
	end
	local spawns = {}
	for _, part in folder:GetChildren() do
		if part:IsA("SpawnLocation") then table.insert(spawns, part) end
	end
	table.sort(spawns, function(a, b)
		-- SpawnLocation_2.1 means course 2, spawn 1.
		local an = tonumber(a:GetAttribute("SpawnIndex")) or tonumber(a.Name:match("(%d+)%s*$")) or math.huge
		local bn = tonumber(b:GetAttribute("SpawnIndex")) or tonumber(b.Name:match("(%d+)%s*$")) or math.huge
		if an ~= bn then return an < bn end
		return a.Name < b.Name
	end)
	if #spawns < capacity then
		return nil, ("Course %d needs %d spawn points; found %d."):format(number, capacity, #spawns)
	end
	local center = Vector3.zero
	for _, spawn in spawns do center += spawn.Position end
	center /= #spawns
	return {
		number = number, course = course, spawnFolder = folder, spawns = spawns,
		bounds = bounds, finish = finish, boosts = course:FindFirstChild("Speed boosts"),
		tokens = course:FindFirstChild("Second life tokens"), center = center,
	}
end

function Registry.ActivateSpawns(root, descriptor)
	for _, child in root:GetChildren() do
		if child:GetAttribute("RoundNumber") or Registry.Number(child.Name) then
			for _, part in child:GetDescendants() do
				if part:IsA("SpawnLocation") then
					part.Enabled = part:IsDescendantOf(descriptor.spawnFolder)
				end
			end
		end
	end
end

return Registry

