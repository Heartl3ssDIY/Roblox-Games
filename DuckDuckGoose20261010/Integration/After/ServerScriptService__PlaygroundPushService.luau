local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Push = {}
Push.__index = Push

local function alive(record)
	return record and record.character and record.character.Parent and record.root and record.root.Parent
		and record.humanoid and record.humanoid.Health > 0
end

function Push.new(bulldog, tag)
	return setmetatable({ bulldog = bulldog, tag = tag, connections = {}, requests = {}, cooldowns = {}, pending = {}, running = false }, Push)
end

function Push:_setting(name, fallback, minimum, maximum)
	local value = script:GetAttribute(name)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return fallback end
	return math.clamp(value, minimum, maximum)
end

function Push:_eligible(service, record, now)
	if not service or not service.running or not service.active or not record or not record.participating
		or not alive(record) or record.frozen or record.ragdoll or record.pendingBulldog then return false end
	if not record.isBot and (record.player.Parent ~= Players or record.player.Character ~= record.character) then return false end
	if record.player:GetAttribute("MDParticipating") == true or record.player:GetAttribute("HSParticipating") == true or record.player:GetAttribute("DGParticipating") == true or record.player:GetAttribute("DGEliminated") == true then return false end
	if service == self.bulldog then
		if record.player:GetAttribute("TGParticipating") == true then return false end
		return service.phase == "Crossing" and now < service.endsAt
			and (record.role == "Runner" or record.role == "Bulldog") and not record.arrived
			and service:_inField(record.root.Position)
			and not service:_inside(service.safeZones.North, record.root.Position)
			and not service:_inside(service.safeZones.South, record.root.Position)
			and (record.role ~= "Runner" or record.departed)
	end
	if record.player:GetAttribute("BBParticipating") == true then return false end
	return service.phase == "Playing" and now < service.endsAt
		and (record.role == "Runner" or record.role == "Tagger") and now >= (record.protectedEndsAt or 0)
		and service:_batInField(record)
end

function Push:_service(player, now)
	for _, service in ipairs({ self.bulldog, self.tag }) do
		local record = service and service.records[player]
		if self:_eligible(service, record, now) then return service, record end
	end
end

function Push:_rayParameters(service)
	local ignored = { service.bounds }
	if service.safeZones then
		table.insert(ignored, service.safeZones.North)
		table.insert(ignored, service.safeZones.South)
	end
	for _, player in Players:GetPlayers() do
		if player.Character then table.insert(ignored, player.Character) end
	end
	for _, record in pairs(service.records) do
		if record.character then table.insert(ignored, record.character) end
	end
	local parameters = RaycastParams.new()
	parameters.FilterType = Enum.RaycastFilterType.Exclude
	parameters.FilterDescendantsInstances = ignored
	parameters.RespectCanCollide = true
	return parameters
end

function Push:_resolve(player, request)
	if not self.running or self.pending[player] ~= request then return false end
	self.pending[player] = nil
	local now = workspace:GetServerTimeNow()
	local service, attacker = request.service, request.attacker
	if service.currentRound ~= request.round or service.crossingNumber ~= request.crossing
		or service.records[player] ~= attacker or attacker.character ~= request.character
		or not self:_eligible(service, attacker, now) then return false end
	local reach = self:_setting("Reach", 6, 2, 8)
	local forward = attacker.root.CFrame.LookVector
	forward = Vector3.new(forward.X, 0, forward.Z)
	if forward.Magnitude < 0.01 then return false end
	local parameters = self:_rayParameters(service)
	local nearest, nearestDistance
	for _, target in pairs(service.records) do
		if target ~= attacker and self:_eligible(service, target, now) then
			local offset = target.root.Position - attacker.root.Position
			local horizontal = Vector3.new(offset.X, 0, offset.Z)
			local distance = offset.Magnitude
			if distance <= reach and (not nearestDistance or distance < nearestDistance)
				and (horizontal.Magnitude < 0.01 or forward.Unit:Dot(horizontal.Unit) >= 0.35)
				and not workspace:Raycast(attacker.root.Position, offset, parameters) then
				nearest, nearestDistance = target, distance
			end
		end
	end
	if not nearest then return false end
	return service:_ragdoll(nearest, attacker, now, self:_setting("RagdollSeconds", 3, 1, 5), "Push")
end

function Push:Request(player, ...)
	if not self.running or select("#", ...) ~= 0 or typeof(player) ~= "Instance" or player.Parent ~= Players then return false end
	local now = workspace:GetServerTimeNow()
	if now - (self.requests[player] or -math.huge) < 0.15 then return false end
	self.requests[player] = now
	if now < (self.cooldowns[player] or 0) then return false end
	local service, attacker = self:_service(player, now)
	if not service or attacker.batSwing then return false end
	local readyAt = now + self:_setting("CooldownSeconds", 6, 3, 30)
	local request = { service = service, attacker = attacker, character = attacker.character,
		round = service.currentRound, crossing = service.crossingNumber }
	self.cooldowns[player] = readyAt
	self.pending[player] = request
	attacker.batSwingReadyAt = math.max(attacker.batSwingReadyAt or 0, now + 0.6)
	player:SetAttribute("PCPushReadyAt", readyAt)
	attacker.character:SetAttribute("PCPushAt", now)
	task.delay(0.18, function() self:_resolve(player, request) end)
	return true
end

function Push:Start()
	if self.running then return self end
	self.running = true
	local remote = ReplicatedStorage:WaitForChild("PlaygroundPushRequest")
	assert(remote:IsA("RemoteEvent"), "PlaygroundPushRequest must be a RemoteEvent")
	table.insert(self.connections, remote.OnServerEvent:Connect(function(player, ...) self:Request(player, ...) end))
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player)
		self.requests[player], self.cooldowns[player], self.pending[player] = nil, nil, nil
	end))
	return self
end

function Push:Stop()
	self.running = false
	for _, connection in ipairs(self.connections) do connection:Disconnect() end
	table.clear(self.connections)
	table.clear(self.requests)
	table.clear(self.cooldowns)
	table.clear(self.pending)
end

return Push


