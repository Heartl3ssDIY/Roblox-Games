assert(not game:GetService("RunService"):IsRunning(), "Stop Play before aligning mirror frames.")
local arena = workspace:FindFirstChild("Hide and Seek")
assert(arena, "School is missing.")
local mirrors, moved = 0, 0
for _, mirror in arena:GetDescendants() do
	if mirror:IsA("BasePart") and mirror.Name == "Mirror" then
		local halfWidth, halfHeight = mirror.Size.X/2, mirror.Size.Y/2
		local positions = {
			TopOutline = Vector3.new(0,halfHeight-.07,-.105),
			BottomOutline = Vector3.new(0,-halfHeight+.07,-.105),
			LeftOutline = Vector3.new(-halfWidth+.07,0,-.105),
			RightOutline = Vector3.new(halfWidth-.07,0,-.105),
		}
		for name, offset in pairs(positions) do
			local trim = mirror.Parent:FindFirstChild(name)
			assert(trim and trim:IsA("BasePart"), "Missing mirror outline: " .. name)
			if not trim:GetAttribute("PCMirrorFrameBefore20261010") then trim:SetAttribute("PCMirrorFrameBefore20261010",trim.CFrame) end
			local desired = mirror.CFrame*CFrame.new(offset)
			if (trim.Position-desired.Position).Magnitude > .001 then trim.CFrame = desired moved += 1 end
		end
		mirrors += 1
	end
end
assert(mirrors == 2, "Mirror inventory changed.")
return { mirrors = mirrors, trimPartsAligned = moved, repeatSafe = true }
