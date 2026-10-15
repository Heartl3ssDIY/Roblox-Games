assert(not game:GetService("RunService"):IsRunning(), "Edit only")
local result = {checks = 0, failures = {}}
local target = Instance.new("Folder")
local function check(condition, message)
	result.checks += 1
	if not condition then table.insert(result.failures, message) end
end
local function test(arena)
	local origin = arena.Gameplay.CircleCenter.CFrame
	local track = arena.Grounds.CircularRunningTrack
	local directions = track.TrackDirections
	check(#directions:GetChildren() == 8, "Expected eight chevrons")
	local top = origin:PointToObjectSpace(track.StuddedTanTrack.Position).Y + track.StuddedTanTrack.Size.X / 2
	for index = 1, 8 do
		local arrow = directions:FindFirstChild(string.format("Chevron%02d", index))
		check(arrow ~= nil and #arrow:GetChildren() == 2, "Each chevron needs two arms")
		local inner, outer = arrow.InnerArm, arrow.OuterArm
		local angle = (index - 1) * math.pi * 2 / 8
		local forward = origin:VectorToWorldSpace(Vector3.new(math.cos(angle), 0, math.sin(angle)))
		check((inner.CFrame.RightVector + outer.CFrame.RightVector).Unit:Dot(forward) > 0.999, "Chevron points against clockwise tangent")
		for _, paint in ipairs({inner, outer}) do
			check(paint.Anchored and not paint.CanCollide and not paint.CanQuery and not paint.CanTouch, "Paint affects player movement")
			check(math.abs(origin:PointToObjectSpace(paint.Position).Y - paint.Size.Y / 2 - top - 0.03) < 0.001, "Paint overlaps track surface")
			check(math.abs(paint.Size.Y - 0.04) < 0.001 and paint.MaterialVariant == "", "Paint is not flat and readable")
		end
		local separated = false
		for _, axis in ipairs({inner.CFrame.RightVector, inner.CFrame.LookVector, outer.CFrame.RightVector, outer.CFrame.LookVector}) do
			local function extent(item)
				return math.abs(axis:Dot(item.CFrame.RightVector)) * item.Size.X / 2 + math.abs(axis:Dot(item.CFrame.LookVector)) * item.Size.Z / 2
			end
			if math.abs(axis:Dot(outer.Position - inner.Position)) > extent(inner) + extent(outer) + 0.001 then separated = true end
		end
		check(separated, "Chevron arms overlap and may z-fight")
		if index == 1 then check(forward:Dot(origin.RightVector) > 0.999, "Angle-zero arrow must point +X") end
	end
end
local ok, message = pcall(function()
	local arena = BuildIsland(target)
	test(arena)
	local authored = {}
	for _, arrow in ipairs(arena.Grounds.CircularRunningTrack.TrackDirections:GetChildren()) do
		for _, arm in ipairs(arrow:GetChildren()) do authored[arrow.Name .. arm.Name] = arm.CFrame end
	end
	AddTrackArrows(arena)
	test(arena)
	for _, arrow in ipairs(arena.Grounds.CircularRunningTrack.TrackDirections:GetChildren()) do
		for _, arm in ipairs(arrow:GetChildren()) do
			local original = authored[arrow.Name .. arm.Name]
			check((arm.Position - original.Position).Magnitude < 0.001 and arm.CFrame.RightVector:Dot(original.RightVector) > 0.999, "Installed patch differs from authored builder")
		end
	end
	AddTrackArrows(arena)
	check(#arena.Grounds.CircularRunningTrack:GetChildren() == 29, "Patch duplicates arrow container")
	check(#arena.Grounds.CircularRunningTrack.TrackDirections:GetDescendants() == 24, "Patch duplicates arrows")
end)
target:Destroy()
if not ok then table.insert(result.failures, tostring(message)) end
result.passed = #result.failures == 0
return result
