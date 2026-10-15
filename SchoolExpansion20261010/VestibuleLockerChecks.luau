return function(arena)
	arena = arena or assert(workspace:FindFirstChild("Hide and Seek"), "School island missing")
	local origin = assert(arena:GetAttribute("SchoolOriginCFrame"), "School origin missing")
	local result = {checks = 0, failures = {}}
	local query = OverlapParams.new()
	query.FilterType = Enum.RaycastFilterType.Include
	query.FilterDescendantsInstances = {arena}
	query.RespectCanCollide = true
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Include
	ray.FilterDescendantsInstances = {arena}
	ray.RespectCanCollide = true
	local function check(condition, message)
		result.checks += 1
		if not condition then table.insert(result.failures, message) end
	end
	local function avatar(foot, name)
		local hits = workspace:GetPartBoundsInBox(CFrame.new(foot + Vector3.new(0, 3.06, 0)), Vector3.new(2.6, 5.88, 2.6), query)
		local names = {}
		for _, hit in ipairs(hits) do table.insert(names, hit:GetFullName()) end
		check(#hits == 0, name .. " blocked: " .. table.concat(names, "; "))
		check(workspace:Raycast(foot + Vector3.new(0, 0.2, 0), Vector3.new(0, -1.25, 0), ray) ~= nil, name .. " lacks floor support")
	end
	for _, name in ipairs({"Locker01", "Locker11"}) do
		local locker = arena.Gameplay.LockerSpots[name]
		local position = origin:PointToObjectSpace(locker.HidePoint.Position)
		check(math.abs(position.Z + 39) < 0.03, name .. " was not moved clear of vestibule")
		avatar(locker.ExitPoint.Position - Vector3.new(0, 3, 0), name .. " exit")
	end
	for base = 0, 18, 18 do for _, side in ipairs({-1, 1}) do for _, x in ipairs({6, 11, 18}) do
		avatar(origin:PointToWorldSpace(Vector3.new(side * x, base, -47)), "Vestibule route")
	end end end
	result.passed = #result.failures == 0
	return result
end
