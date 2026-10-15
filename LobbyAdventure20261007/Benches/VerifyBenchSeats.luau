assert(not game:GetService("RunService"):IsRunning(), "Edit verification only.")
local lobby = workspace["Playground Lobby"]
local result = { benches = 0, seats = 0, minimumSpacing = math.huge, obstructedPositions = {} }
local surfaces = {}
for _, seat in ipairs(lobby:GetDescendants()) do
	if seat:IsA("Seat") and seat:GetAttribute("PCBenchSeat") then
		result.seats += 1
		local surface = seat.BenchSurface.Value
		surfaces[surface] = true
		assert(seat.Anchored and seat.Transparency == 1 and not seat.CanCollide and not seat.CanTouch)
		assert(not seat.Disabled and seat.Parent.Parent == surface)
		local prompt = seat:FindFirstChild("SitPrompt", true)
		assert(prompt and prompt.Parent:IsA("Attachment") and prompt.Parent.WorldPosition.Y > surface.Position.Y + surface.Size.Y / 2)
		assert(prompt.GamepadKeyCode == Enum.KeyCode.ButtonX and prompt.KeyboardKeyCode == Enum.KeyCode.E)
		assert(math.abs(seat.Position.Y + seat.Size.Y / 2 - surface.Position.Y - surface.Size.Y / 2) < 0.001)
		local back = surface.Parent:FindFirstChild("Back")
		if back then assert(seat.CFrame.LookVector:Dot(surface.Position - back.Position) > 1) end
		if surface.Name == "BenchSeat" then assert(seat.CFrame.LookVector:Dot(surface.Parent.TableTop.Position - surface.Position) > 3) end
		if surface.Name == "CaveBench" then assert(seat.CFrame.LookVector.X > 0.99) end
		for _, other in ipairs(seat.Parent:GetChildren()) do
			if other:IsA("Seat") and other ~= seat then
				local distance = (other.Position - seat.Position).Magnitude
				assert(distance >= 2.99)
				result.minimumSpacing = math.min(result.minimumSpacing, distance)
			end
		end
		local params = OverlapParams.new()
		params.FilterType, params.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude, { seat.Parent }
		for _, part in ipairs(workspace:GetPartBoundsInBox(seat.CFrame * CFrame.new(0, 2.1, -0.1), Vector3.new(2.4, 3.6, 1.2), params)) do
			if part.CanCollide and part.Transparency < 1 then table.insert(result.obstructedPositions, seat:GetFullName() .. " : " .. part:GetFullName()) end
		end
	end
end
for surface in pairs(surfaces) do
	result.benches += 1
	assert(#surface.SeatingPositions:GetChildren() == 3)
	local unchanged = false
	for _, snapshot in ipairs(game:GetService("ServerStorage").LobbyBenchBackup20261007:GetChildren()) do
		if snapshot:GetAttribute("OriginalPath") == surface:GetFullName() and snapshot.CFrame == surface.CFrame and snapshot.Size == surface.Size and snapshot.Color == surface.Color and snapshot.MaterialVariant == surface.MaterialVariant then unchanged = true break end
	end
	assert(unchanged, "Original bench geometry changed: " .. surface:GetFullName())
end
assert(result.benches == 12 and result.seats == 36)
assert(#result.obstructedPositions == 0, game:GetService("HttpService"):JSONEncode(result.obstructedPositions))
local source = game:GetService("ServerScriptService").PlaygroundLobbyBenchService
local donor = game:GetService("ServerScriptService").PlaygroundToyService
assert(source.Capabilities == donor.Capabilities and source.Sandboxed == donor.Sandboxed)
local module = source:Clone()
module.Name, module.Parent = "BenchCapabilityVerification", game:GetService("ServerStorage")
local service = require(module)
local ok, reason = pcall(function()
	local state = service.Start()
	assert(state and #state.entries == 36 and #state.connections == 73)
	assert(service.Start() == state)
	state:Stop()
	assert(not state.running and #state.connections == 0)
	for _, entry in ipairs(state.entries) do assert(#entry.occupantConnections == 0) end
end)
service.Stop()
module:Destroy()
for _, seat in ipairs(lobby:GetDescendants()) do
	if seat:IsA("Seat") and seat:GetAttribute("PCBenchSeat") then seat:FindFirstChild("SitPrompt", true).Enabled = true end
end
assert(ok, reason)
result.lifecycle = "Start, idempotency, Stop and connection cleanup passed"
result.appearance = "All 12 original bench surfaces unchanged"
result.simulation = "No Play or live avatar test performed"
return game:GetService("HttpService"):JSONEncode(result)
