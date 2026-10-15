return function(arena)
	assert(not game:GetService("RunService"):IsRunning(), "Stop Play before moving school lockers")
	arena = arena or assert(workspace:FindFirstChild("Hide and Seek"), "School island missing")
	local origin = assert(arena:GetAttribute("SchoolOriginCFrame"), "School origin missing")
	local transform = origin * CFrame.new(0, 0, 8) * origin:Inverse()
	local moved = 0
	for _, name in ipairs({"Locker01", "Locker11"}) do
		local locker = assert(arena.Gameplay.LockerSpots:FindFirstChild(name), name .. " missing")
		local position = origin:PointToObjectSpace(locker.HidePoint.Position)
		assert(math.abs(position.Z + 47) < 0.03 or math.abs(position.Z + 39) < 0.03, name .. " moved since audit")
		if math.abs(position.Z + 47) < 0.03 then
			for _, item in ipairs(locker:GetDescendants()) do if item:IsA("BasePart") then item.CFrame = transform * item.CFrame end end
			moved += 1
		end
		locker:SetAttribute("VestibuleClearanceVersion", "20261010")
	end
	arena:SetAttribute("VestibuleClearanceVersion", "20261010")
	return {moved = moved, targetZ = -39, alreadyApplied = moved == 0}
end
