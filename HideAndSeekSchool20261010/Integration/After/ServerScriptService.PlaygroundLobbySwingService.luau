local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Swing = {}
local active
local roundAttributes = { "BBParticipating", "TGParticipating", "MDParticipating", "HSParticipating" }

local function inRound(player)
	for _, attribute in ipairs(roundAttributes) do
		if player:GetAttribute(attribute) == true then return true end
	end
	return false
end

local function disconnect(connections)
	for _, connection in ipairs(connections) do connection:Disconnect() end
	table.clear(connections)
end

local function release(entry)
	local humanoid = entry.seat.Occupant
	local weld = entry.seat:FindFirstChild("SeatWeld")
	if weld then weld:Destroy() end
	if humanoid and humanoid.Parent then humanoid.Sit = false end
end

function Swing.Start()
	if active then return active end
	local lobby = workspace:FindFirstChild("Playground Lobby")
	local model = lobby and lobby:FindFirstChild("PlaygroundLobbySwing")
	if not model then return nil end
	local self = { connections = {}, entries = {}, running = true, model = model }
	active = self
	for _, assembly in ipairs(model.Seats:GetChildren()) do
		local seat = assembly:FindFirstChild("Seat")
		local hinge = assembly:FindFirstChild("SwingHinge")
		local prompt = seat and seat:FindFirstChild("SitPrompt")
		if not seat or not hinge or not prompt then continue end
		for _, part in ipairs(assembly:GetDescendants()) do
			if part:IsA("BasePart") then part.Anchored = false end
		end
		local entry = { seat = seat, hinge = hinge, prompt = prompt, ramp = 0, phase = 0, occupantConnections = {}, lastRequest = {} }
		table.insert(self.entries, entry)
		local function occupantChanged()
			disconnect(entry.occupantConnections)
			local previousPlayer = entry.player
			local previousRoot = entry.root
			local humanoid = seat.Occupant
			local player = humanoid and Players:GetPlayerFromCharacter(humanoid.Parent)
			prompt.Enabled = humanoid == nil and self.running
			entry.player = player
			entry.root = humanoid and humanoid.Parent:FindFirstChild("HumanoidRootPart")
			if previousPlayer ~= player and previousRoot and previousRoot.Parent then
				pcall(previousRoot.SetNetworkOwnershipAuto, previousRoot)
			end
			if humanoid and (not player or inRound(player) or humanoid.Health <= 0) then release(entry) return end
			if not humanoid then return end
			entry.phase = 0
			entry.ramp = 0
			pcall(seat.SetNetworkOwner, seat, nil)
			for _, attribute in ipairs(roundAttributes) do
				table.insert(entry.occupantConnections, player:GetAttributeChangedSignal(attribute):Connect(function()
					if inRound(player) then release(entry) end
				end))
			end
			table.insert(entry.occupantConnections, humanoid.Died:Connect(function() release(entry) end))
		end
		table.insert(self.connections, seat:GetPropertyChangedSignal("Occupant"):Connect(occupantChanged))
		table.insert(self.connections, prompt.Triggered:Connect(function(player)
			if not self.running or player.Parent ~= Players or seat.Occupant or inRound(player) then return end
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not humanoid or not root or humanoid.Health <= 0 or humanoid.SeatPart or root.Anchored then return end
			if (root.Position - seat.Position).Magnitude > prompt.MaxActivationDistance + 2 then return end
			local now = os.clock()
			if now - (entry.lastRequest[player] or -math.huge) < 1 then return end
			entry.lastRequest[player] = now
			humanoid:UnequipTools()
			seat:Sit(humanoid)
		end))
		pcall(seat.SetNetworkOwner, seat, nil)
		occupantChanged()
	end
	local accumulator = 0
	table.insert(self.connections, RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 1 / 30 then return end
		local elapsed = math.min(accumulator, 0.1)
		accumulator = 0
		if not model.Parent then Swing.Stop() return end
		for _, entry in ipairs(self.entries) do
			local occupied = entry.seat.Occupant ~= nil and entry.player and not inRound(entry.player)
			local amplitude = math.clamp(model:GetAttribute("SwingAngle") or 26, 8, 30)
			local period = math.clamp(model:GetAttribute("SwingPeriod") or 4.5, 3.5, 8)
			entry.ramp += ((occupied and 1 or 0) - entry.ramp) * math.min(elapsed * 1.6, 1)
			entry.phase += elapsed * math.pi * 2 / period
			entry.hinge.TargetAngle = math.sin(entry.phase) * amplitude * entry.ramp
			if not occupied and entry.ramp < 0.003 then entry.hinge.TargetAngle = 0 end
		end
	end))
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player)
		for _, entry in ipairs(self.entries) do
			entry.lastRequest[player] = nil
			if entry.player == player then release(entry) end
		end
	end))
	function self:Stop() Swing.Stop() end
	return self
end

function Swing.Stop()
	local self = active
	if not self then return end
	self.running = false
	active = nil
	disconnect(self.connections)
	for _, entry in ipairs(self.entries) do
		disconnect(entry.occupantConnections)
		entry.prompt.Enabled = false
		entry.hinge.TargetAngle = 0
		release(entry)
		if entry.root and entry.root.Parent then pcall(entry.root.SetNetworkOwnershipAuto, entry.root) end
	end
end

return Swing


