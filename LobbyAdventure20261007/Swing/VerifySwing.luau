assert(not game:GetService("RunService"):IsRunning(), "Edit verification only.")
local swing = workspace["Playground Lobby"].PlaygroundLobbySwing
local result = { seats = 0, movingParts = 0, welds = 0, highlights = 0, obstacles = {} }
for _, part in ipairs(swing:GetDescendants()) do
	if part:IsA("Highlight") then result.highlights += 1 end
end
assert(result.highlights == 0)
for _, assembly in ipairs(swing.Seats:GetChildren()) do
	local seat, hinge = assembly.Seat, assembly.SwingHinge
	assert(seat:IsA("Seat") and seat.SitPrompt.GamepadKeyCode == Enum.KeyCode.ButtonX)
	assert(hinge.ActuatorType == Enum.ActuatorType.Servo and hinge.LimitsEnabled)
	assert(hinge.LowerAngle == -32 and hinge.UpperAngle == 32)
	assert((hinge.Attachment0.WorldPosition - hinge.Attachment1.WorldPosition).Magnitude < 0.0001)
	assert(hinge.Attachment0.WorldAxis:Dot(hinge.Attachment1.WorldAxis) > 0.999)
	assert(hinge.Attachment0.Parent.Anchored and not seat.Anchored)
	for _, part in ipairs(assembly:GetDescendants()) do
		if part:IsA("BasePart") then
			assert(not part.Anchored and not part.CanCollide)
			result.movingParts += 1
			if part ~= seat then
				assert(part.Massless and part.SeatAssemblyWeld.Part0 == seat and part.SeatAssemblyWeld.Part1 == part)
				result.welds += 1
			end
		end
	end
	result.seats += 1
end
assert(result.seats == 2 and result.movingParts == 100 and result.welds == 98)
local params = OverlapParams.new()
params.FilterType, params.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude, { swing }
for _, part in ipairs(workspace:GetPartBoundsInBox(CFrame.new(51, 14.6, 35), Vector3.new(32, 20, 22), params)) do
	if part.CanCollide and part.Transparency < 1 then table.insert(result.obstacles, part:GetFullName()) end
end
assert(#result.obstacles == 0)
local source = game:GetService("ServerScriptService").PlaygroundLobbySwingService
local donor = game:GetService("ServerScriptService").PlaygroundToyService
assert(source.Capabilities == donor.Capabilities and source.Sandboxed == donor.Sandboxed)
local module = source:Clone()
module.Name, module.Parent = "SwingCapabilityVerification", game:GetService("ServerStorage")
local service = require(module)
local ok, reason = pcall(function()
	local state = service.Start()
	assert(state and #state.entries == 2 and #state.connections == 6)
	assert(service.Start() == state)
	state:Stop()
	assert(not state.running and #state.connections == 0)
	for _, entry in ipairs(state.entries) do assert(#entry.occupantConnections == 0 and entry.hinge.TargetAngle == 0) end
end)
service.Stop()
module:Destroy()
for _, assembly in ipairs(swing.Seats:GetChildren()) do assembly.Seat.SitPrompt.Enabled = true end
assert(ok, reason)
result.lifecycle = "start, idempotency, stop, connection cleanup passed"
result.simulation = "Not run: Play remains stopped"
return game:GetService("HttpService"):JSONEncode(result)
