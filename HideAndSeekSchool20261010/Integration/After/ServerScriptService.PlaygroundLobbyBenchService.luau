local Players = game:GetService("Players")

local Benches = {}
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

function Benches.Start()
	if active then return active end
	local lobby = workspace:FindFirstChild("Playground Lobby")
	if not lobby then return nil end
	local self = { connections = {}, entries = {}, running = true }
	active = self
	for _, seat in ipairs(lobby:GetDescendants()) do
		if not seat:IsA("Seat") or seat:GetAttribute("PCBenchSeat") ~= true then continue end
		local prompt = seat:FindFirstChild("SitPrompt", true)
		if not prompt then continue end
		local entry = { seat = seat, prompt = prompt, occupantConnections = {}, lastRequest = {} }
		table.insert(self.entries, entry)
		local function occupantChanged()
			disconnect(entry.occupantConnections)
			local humanoid = seat.Occupant
			local player = humanoid and Players:GetPlayerFromCharacter(humanoid.Parent)
			entry.player = player
			prompt.Enabled = humanoid == nil and self.running
			if humanoid and (not player or inRound(player) or humanoid.Health <= 0) then release(entry) return end
			if not humanoid then return end
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
			if (root.Position - seat.Position).Magnitude > prompt.MaxActivationDistance + 1 then return end
			local now = os.clock()
			if now - (entry.lastRequest[player] or -math.huge) < 0.75 then return end
			entry.lastRequest[player] = now
			humanoid:UnequipTools()
			seat:Sit(humanoid)
		end))
		occupantChanged()
	end
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player)
		for _, entry in ipairs(self.entries) do
			entry.lastRequest[player] = nil
			if entry.player == player then release(entry) end
		end
	end))
	function self:Stop() Benches.Stop() end
	return self
end

function Benches.Stop()
	local self = active
	if not self then return end
	active, self.running = nil, false
	disconnect(self.connections)
	for _, entry in ipairs(self.entries) do
		disconnect(entry.occupantConnections)
		entry.prompt.Enabled = false
		release(entry)
	end
end

return Benches


