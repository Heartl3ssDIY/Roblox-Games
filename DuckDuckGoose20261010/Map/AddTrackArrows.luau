return function(arena)
	assert(not game:GetService("RunService"):IsRunning(), "Edit only")
	arena = arena or assert(workspace:FindFirstChild("Duck Duck Goose"), "Duck Duck Goose island missing")
	local origin = arena.Gameplay.CircleCenter.CFrame
	local track = arena.Grounds.CircularRunningTrack
	local surface = track.StuddedTanTrack
	assert(math.abs(surface.CFrame.RightVector:Dot(origin.UpVector)) > 0.999, "Track must be horizontal")
	local top = origin:PointToObjectSpace(surface.Position).Y + surface.Size.X / 2
	local existing = track:FindFirstChild("TrackDirections")
	if existing then
		assert(existing:GetAttribute("DGPaintedDirections") == true, "Unexpected TrackDirections object")
		existing:Destroy()
	end
	local directions = Instance.new("Model")
	directions.Name = "TrackDirections"
	directions:SetAttribute("DGPaintedDirections", true)
	for index = 1, 8 do
		local angle = (index - 1) * math.pi * 2 / 8
		local radial = Vector3.new(math.sin(angle), 0, -math.cos(angle))
		local forward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local arrow = Instance.new("Model")
		arrow.Name = string.format("Chevron%02d", index)
		arrow:SetAttribute("ClockwiseAngle", angle)
		for _, side in ipairs({-1, 1}) do
			local tip = radial * 30.5 + forward * 1.15 + radial * (side * 0.30) + Vector3.new(0, top + 0.05, 0)
			local tail = radial * 30.5 - forward * 1.15 + radial * (side * 1.70) + Vector3.new(0, top + 0.05, 0)
			local arm = tip - tail
			local paint = Instance.new("Part")
			paint.Name = side == -1 and "InnerArm" or "OuterArm"
			paint.Size = Vector3.new(arm.Magnitude, 0.04, 0.45)
			paint.CFrame = CFrame.fromMatrix(origin:PointToWorldSpace((tip + tail) / 2), origin:VectorToWorldSpace(arm.Unit), origin.UpVector)
			paint.Color = Color3.fromRGB(237, 227, 206)
			paint.Material = Enum.Material.SmoothPlastic
			paint.Anchored, paint.CanCollide, paint.CanQuery, paint.CanTouch = true, false, false, false
			paint.CastShadow = false
			paint:SetAttribute("DGDuckMap", true)
			paint:SetAttribute("DGDecorative", true)
			paint.Parent = arrow
		end
		arrow.Parent = directions
	end
	directions.Parent = track
	return directions
end
