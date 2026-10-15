local result = {checks = 0, failures = {}, counts = {}}
local target = Instance.new("Folder")
target.Name = "DuckDuckGooseUnparentedFixture"
local function check(condition, message)
	result.checks += 1
	if not condition then table.insert(result.failures, message) end
end
local ok, message = pcall(function()
	local arena = BuildIsland(target)
	local origin = arena:GetAttribute("DGOriginCFrame")
	local center = arena.Gameplay.CircleCenter.Position
	local parts, solids, seats, guiCount, invalidParts, invalidText = 0, 0, 0, 0, {}, {}
	local physical = {}
	for _, item in ipairs(arena:GetDescendants()) do
		if item:IsA("BasePart") then
			parts += 1
			if not item.Anchored then table.insert(invalidParts, item.Name .. " unanchored") end
			if item.CanCollide then solids += 1 table.insert(physical, item) end
			if item.CanCollide ~= item.CanQuery then table.insert(invalidParts, item.Name .. " collision/query mismatch") end
			if item:GetAttribute("DGDecorative") and (item.CanCollide or item.CanQuery or item.CanTouch) then table.insert(invalidParts, item.Name .. " decorative collision") end
			if item:IsA("Seat") then seats += 1 end
		elseif item:IsA("SurfaceGui") then
			guiCount += 1
			local caption = item:FindFirstChildWhichIsA("TextLabel")
			if not caption or not caption.TextScaled or not caption.TextWrapped then table.insert(invalidText, item:GetFullName()) end
		end
	end
	result.counts = {parts = parts, solidParts = solids, allNativeSeats = seats, authoredSurfaceLabels = guiCount, gameSeats = #arena.Gameplay.Seats:GetChildren(), entrySpawns = #arena.Gameplay.EntrySpawns:GetChildren(), spectatorSpawns = #arena.Gameplay.SpectatorSpawns:GetChildren()}
	check(#invalidParts == 0, table.concat(invalidParts, "; "))
	check(#invalidText == 0, "TextScaled/TextWrapped lost: " .. table.concat(invalidText, "; "))
	check(guiCount == 18, "Expected sixteen seat numbers plus two sign faces")
	check(parts < 550, "Modest island part budget exceeded")
	check(result.counts.gameSeats == 16 and seats == 26, "Expected sixteen game seats and ten spectator seats")
	check(result.counts.entrySpawns == 16 and result.counts.spectatorSpawns == 16, "Spawn counts wrong")
	check(arena:GetAttribute("SelectionSeconds") == 15, "Selection deadline does not match service")
	check(arena:GetAttribute("LapInnerRadius") == 25 and arena:GetAttribute("LapOuterRadius") == 36, "Lap bounds wrong")
	check(arena.Grounds.CircularRunningTrack.StuddedTanTrack.Shape == Enum.PartType.Cylinder, "Running track is not a continuous native cylinder")
	local function blocked(foot)
		local avatarCenter = foot + Vector3.new(0, 3.06, 0)
		local half = Vector3.new(1.3, 2.94, 1.3)
		local hits = {}
		for _, item in ipairs(physical) do
			if item.Shape == Enum.PartType.Block then
				local localCenter = item.CFrame:PointToObjectSpace(avatarCenter)
				local right, up, back = item.CFrame.RightVector, item.CFrame.UpVector, -item.CFrame.LookVector
				local function extent(axis) return math.abs(axis.X) * half.X + math.abs(axis.Y) * half.Y + math.abs(axis.Z) * half.Z end
				local e = Vector3.new(extent(right), extent(up), extent(back)) + item.Size / 2
				local itemHalf = item.Size / 2
				local worldExtent = Vector3.new(
					math.abs(right.X) * itemHalf.X + math.abs(up.X) * itemHalf.Y + math.abs(back.X) * itemHalf.Z,
					math.abs(right.Y) * itemHalf.X + math.abs(up.Y) * itemHalf.Y + math.abs(back.Y) * itemHalf.Z,
					math.abs(right.Z) * itemHalf.X + math.abs(up.Z) * itemHalf.Y + math.abs(back.Z) * itemHalf.Z) + half
				local delta = item.Position - avatarCenter
				if math.abs(localCenter.X) < e.X - 0.005 and math.abs(localCenter.Y) < e.Y - 0.005 and math.abs(localCenter.Z) < e.Z - 0.005 and math.abs(delta.X) < worldExtent.X - 0.005 and math.abs(delta.Y) < worldExtent.Y - 0.005 and math.abs(delta.Z) < worldExtent.Z - 0.005 then table.insert(hits, item:GetFullName()) end
			end
		end
		return hits
	end
	local indices = {}
	for _, slot in ipairs(arena.Gameplay.Seats:GetChildren()) do
		local index = slot:GetAttribute("DGSeatIndex")
		check(index and not indices[index], "Seat index missing/duplicate") indices[index] = true
		check(slot.Seat:IsA("Seat") and slot:FindFirstChild("Spot") and slot:FindFirstChild("StandPoint"), "Seat contract missing")
		local horizontal = slot.Seat.Position - center
		horizontal = Vector3.new(horizontal.X, 0, horizontal.Z)
		check(math.abs(horizontal.Magnitude - 22) < 0.02, "Seat circle radius wrong")
		check(slot.Seat.CFrame.LookVector:Dot(-horizontal.Unit) > 0.99, "Seat does not face inwards")
		local standFoot = slot.StandPoint.Position - Vector3.new(0, 3, 0)
		local hits = blocked(standFoot)
		check(#hits == 0, "StandPoint obstructed: " .. table.concat(hits, "; "))
		check((slot.StandPoint.Position - slot.Spot.Position).Magnitude < 5, "Selected seat cannot be claimed from clear StandPoint")
	end
	for index = 1, 64 do
		local angle = (index - 1) * math.pi * 2 / 64
		for _, radius in ipairs({25, 25.2, 30.5, 35}) do
			local point = origin:PointToWorldSpace(Vector3.new(math.sin(angle) * radius, 0.1, -math.cos(angle) * radius))
			local hits = blocked(point)
			check(#hits == 0, "Running ring blocked at radius" .. radius .. ": " .. table.concat(hits, "; "))
			check(radius < 36 and arena.Grounds.CircularRunningTrack.StuddedTanTrack.CanCollide, "Running ring has no continuous support")
		end
	end
	for _, group in ipairs({arena.Gameplay.EntrySpawns, arena.Gameplay.SpectatorSpawns}) do for _, point in ipairs(group:GetChildren()) do
		local foot = point.Position - Vector3.new(0, 3, 0)
		local hits = blocked(foot)
		check(#hits == 0, point.Name .. " spawn obstructed: " .. table.concat(hits, "; "))
	end end
	local bounds = arena.Gameplay.ArenaBounds
	local p = bounds.CFrame:PointToObjectSpace(arena.Gameplay.CircleCenter.Position)
	check(math.abs(p.X) < bounds.Size.X / 2 and math.abs(p.Z) < bounds.Size.Z / 2, "Circle outside arena")
	check(target.Parent == nil, "Fixture accidentally entered live world")
end)
target:Destroy()
if not ok then table.insert(result.failures, "Fixture runtime failure: " .. tostring(message)) end
result.passed = #result.failures == 0
return result
