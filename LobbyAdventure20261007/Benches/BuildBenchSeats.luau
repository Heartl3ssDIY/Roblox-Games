assert(not game:GetService("RunService"):IsRunning(), "Install bench seats in Edit mode.")
local lobby = workspace["Playground Lobby"]
local surfaces = {}
for _, part in ipairs(lobby:GetDescendants()) do
	if part:IsA("Part") and not part:IsA("Seat") and (part.Name == "BenchSeat" or part.Name == "CaveBench" or (part.Name == "Seat" and string.find(part.Parent.Name, "Bench"))) then
		assert(not part:FindFirstChild("SeatingPositions"), "Bench seating already installed: " .. part:GetFullName())
		table.insert(surfaces, part)
	end
end
assert(#surfaces == 12, "Inspect changed bench geometry before installing.")
local backup = Instance.new("Folder")
backup.Name, backup.Parent = "LobbyBenchBackup20261007", game:GetService("ServerStorage")
local result = { benches = {}, positions = 0 }
for index, surface in ipairs(surfaces) do
	local snapshot = surface:Clone()
	snapshot.Name, snapshot.Parent = string.format("%02d_%s_%s", index, surface.Parent.Name, surface.Name), backup
	snapshot:SetAttribute("OriginalPath", surface:GetFullName())
	local group = Instance.new("Folder")
	group.Name, group.Parent = "SeatingPositions", surface
	local back = surface.Parent:FindFirstChild("Back")
	local tableTop = surface.Name == "BenchSeat" and surface.Parent:FindFirstChild("TableTop")
	local longZ = surface.Size.Z > surface.Size.X
	local length = longZ and surface.Size.Z or surface.Size.X
	local tangent = longZ and surface.CFrame.ZVector or surface.CFrame.XVector
	local direction
	if back then direction = surface.Position - back.Position
	elseif tableTop then direction = tableTop.Position - surface.Position
	else direction = Vector3.xAxis end
	direction = Vector3.new(direction.X, 0, direction.Z).Unit
	local spacing = math.min(3.2, length / 3)
	local row = { path = surface:GetFullName(), originalCFrame = { surface.CFrame:GetComponents() }, originalSize = { surface.Size.X, surface.Size.Y, surface.Size.Z }, slots = {} }
	for slot, offset in ipairs({ -spacing, 0, spacing }) do
		local position = surface.Position + tangent * offset + Vector3.new(0, surface.Size.Y / 2 - 0.075, 0) + direction * (back and 0.15 or 0)
		local seat = Instance.new("Seat")
		seat.Name = "Sit" .. slot
		seat.Size = Vector3.new(2.1, 0.15, math.min(1.65, longZ and surface.Size.X or surface.Size.Z))
		seat.CFrame = CFrame.lookAt(position, position + direction)
		seat.Transparency, seat.Anchored = 1, true
		seat.CanCollide, seat.CanTouch, seat.CanQuery, seat.CastShadow = false, false, false, false
		seat.Disabled, seat.Locked = false, true
		seat:SetAttribute("PCBenchSeat", true)
		seat:SetAttribute("BenchName", surface.Parent.Name)
		seat:SetAttribute("SeatNumber", slot)
		seat.Parent = group
		local marker = Instance.new("Attachment")
		marker.Name, marker.Position, marker.Parent = "PromptPosition", Vector3.new(0, 1.25, 0), seat
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name, prompt.ActionText, prompt.ObjectText = "SitPrompt", "Sit", surface.Name == "BenchSeat" and "Picnic bench" or "Bench"
		prompt.KeyboardKeyCode, prompt.GamepadKeyCode = Enum.KeyCode.E, Enum.KeyCode.ButtonX
		prompt.MaxActivationDistance, prompt.HoldDuration, prompt.RequiresLineOfSight = 5.5, 0, true
		prompt.Exclusivity, prompt.Parent = Enum.ProximityPromptExclusivity.OnePerButton, marker
		local ref = Instance.new("ObjectValue")
		ref.Name, ref.Value, ref.Parent = "BenchSurface", surface, seat
		table.insert(row.slots, { position = { position.X, position.Y, position.Z }, facing = { direction.X, direction.Y, direction.Z } })
		result.positions += 1
	end
	table.insert(result.benches, row)
end
return game:GetService("HttpService"):JSONEncode(result)
