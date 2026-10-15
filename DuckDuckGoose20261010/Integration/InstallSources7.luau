assert(not game:GetService("RunService"):IsRunning(), "Stop Play before integrating Duck Duck Goose.")
assert(game.PlaceId == 95034648955135, "Wrong experience.")
local entries = { {path="ServerScriptService.PlaygroundLobbySwingService",expected=786263874,after=1430572022,caps="RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Physics | UI | Input | Players | AvatarBehavior",sandboxed=true,source=[==[local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Swing = {}
local active
local roundAttributes = { "BBParticipating", "TGParticipating", "MDParticipating", "HSParticipating", "DGParticipating", "DGEliminated" }

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

]==]},
 {path="ServerScriptService.PlaygroundSecretObbyService",expected=1063533538,after=1723726874,caps="RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Physics | UI | Input | Players | AvatarBehavior",sandboxed=true,source=[==[local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Obby = {}
Obby.__index = Obby

local function participating(player)
	return player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true or ( player:GetAttribute("MDParticipating") == true or player:GetAttribute("HSParticipating") == true or player:GetAttribute("DGParticipating") == true or player:GetAttribute("DGEliminated") == true )
end

local function characterOf(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if player.Parent ~= Players or not humanoid or humanoid.Health <= 0 or not root or participating(player) then return nil end
	return character, root, humanoid
end

local function near(player, part, distance)
	local character, root = characterOf(player)
	return character and (root.Position - part.Position).Magnitude <= distance
end

local function footRayLength(character, root)
	local lowest
	for _, name in {"LeftFoot", "RightFoot", "Left Leg", "Right Leg"} do
		local foot = character:FindFirstChild(name)
		if foot and foot:IsA("BasePart") then
			local frame, size = foot.CFrame, foot.Size
			local extent = (math.abs(frame.RightVector.Y) * size.X + math.abs(frame.UpVector.Y) * size.Y + math.abs(frame.LookVector.Y) * size.Z) * 0.5
			lowest = math.min(lowest or math.huge, foot.Position.Y - extent)
		end
	end
	return math.max(0.5, root.Position.Y - (lowest or (root.Position.Y - root.Size.Y * 1.5))) + 0.6
end

function Obby.new(scene, entry, economy)
	local self = setmetatable({}, Obby)
	self.scene, self.entry, self.economy = scene, entry, economy
	self.runs, self.connections, self.promptTimes = {}, {}, {}
	self.tiles, self.path = {}, {}
	self.tileParts = {}
	self.boundsFrame, self.boundsSize = scene:GetBoundingBox()
	self.floorY = math.huge
	self.random = Random.new()
	self.floorQuery = RaycastParams.new()
	self.floorQuery.FilterType = Enum.RaycastFilterType.Include
	self.floorQuery.FilterDescendantsInstances = {scene.Tiles}
	self.running = false
	self.lastOccupied = os.clock()
	for _, model in scene.Tiles:GetChildren() do
		local row, column = model:GetAttribute("Row"), model:GetAttribute("Column")
		local tile = { model = model, top = model.Top, row = row, column = column, pieces = {} }
		self.floorY = math.min(self.floorY, tile.top.Position.Y + tile.top.Size.Y * 0.5)
		for _, p in model:GetDescendants() do if p:IsA("BasePart") then
			self.tileParts[p] = tile
			table.insert(tile.pieces, {part=p, transparency=p.Transparency, collide=p.CanCollide, query=p.CanQuery, color=p.Color})
		end end
		self.tiles[row] = self.tiles[row] or {}
		self.tiles[row][column] = tile
	end
	self:_newPath()
	return self
end

function Obby:_restoreTile(tile)
	tile.failedAt = nil
	for _, record in tile.pieces do
		record.part.Transparency, record.part.CanCollide, record.part.CanQuery = record.transparency, record.collide, record.query
		record.part.Color = record.color
	end
end

function Obby:_newPath()
	local column = self.random:NextInteger(1, 3)
	for row = 1, 8 do
		column = math.clamp(column + self.random:NextInteger(-1, 1), 1, 3)
		self.path[row] = column
		for _, tile in self.tiles[row] do self:_restoreTile(tile) end
	end
	self.lastOccupied = os.clock()
end

function Obby:_tell(player, text)
	player:SetAttribute("PCRewardText", text)
	player:SetAttribute("PCRewardAt", workspace:GetServerTimeNow())
end

function Obby:_move(player, frame)
	local character, root, humanoid = characterOf(player)
	if not character then return false end
	local seat = humanoid.SeatPart
	local weld = seat and seat:FindFirstChild("SeatWeld")
	humanoid.Sit = false
	if weld and ((weld.Part0 and weld.Part0:IsDescendantOf(character)) or (weld.Part1 and weld.Part1:IsDescendantOf(character))) then weld:Destroy() end
	root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
	character:PivotTo(frame)
	return true
end

function Obby:_reset(player, message)
	local run = self.runs[player]
	if not run then return end
	if self:_move(player, self.scene.StartPoint.CFrame) then
		run.row, run.started, run.lastStep, run.lastPosition = 0, os.clock(), -math.huge, self.scene.StartPoint.Position
		player:SetAttribute("PCSecretObbyRow", 0)
		if message and os.clock() - (run.lastNotice or -math.huge) >= 4 then self:_tell(player, message); run.lastNotice = os.clock() end
	else self.runs[player] = nil end
end

function Obby:_enter(player)
	local opening = self.entry.Opening
	if not near(player, opening, 12) then return end
	local now = os.clock()
	if now - (self.promptTimes[player] or -math.huge) < 1 then return end
	self.promptTimes[player] = now
	if player:GetAttribute("PCDataReady") ~= true then
		self:_tell(player, "Your data is still loading. Try the cave again in a moment.")
		return
	end
	if self:_move(player, self.scene.StartPoint.CFrame) then
		self.runs[player] = { character=player.Character, row=0, started=now, lastStep=-math.huge, lastPosition=self.scene.StartPoint.Position }
		player:SetAttribute("PCSecretObbyRow", 0)
		self:_tell(player, "Secret Steps: find all 8 safe tiles. Daily prize: 1,000 coins!")
	end
end

function Obby:_exit(player)
	if not near(player, self.scene.ReturnPortal.Opening, 12) and not near(player, self.scene.FinishReturnPortal.Opening, 12) then return end
	self.runs[player] = nil
	player:SetAttribute("PCSecretObbyRow", 0)
	self:_move(player, CFrame.lookAt(Vector3.new(-132, 7.6, 54), Vector3.new(-120, 7.6, 54)))
end

function Obby:_claim(player)
	local run = self.runs[player]
	if not run or run.claiming or run.character ~= player.Character or run.row ~= 8
		or os.clock() - run.started < 1.2 or not near(player, self.scene.TreasureChest.Latch, 12) then return end
	run.claiming = true
	local ok, message = self.economy:ClaimSecretObbyReward(player)
	run.claiming = false
	self:_tell(player, message)
end

function Obby:_visit(player, run, tile, now)
	if tile.failedAt then return end
	if self.path[tile.row] ~= tile.column then
		tile.failedAt = now
		tile.top.Color = Color3.fromRGB(255, 110, 117)
		return
	end
	if tile.row <= run.row then return end
	if tile.row ~= run.row + 1 or now - run.lastStep < 0.09 then
		self:_reset(player, "Follow each row of the secret path.")
		return
	end
	run.row, run.lastStep = tile.row, now
	tile.top.Color = Color3.fromRGB(96, 219, 152)
	player:SetAttribute("PCSecretObbyRow", run.row)
end

function Obby:_tick(dt)
	local now = os.clock()
	for _, row in self.tiles do for _, tile in row do
		if tile.failedAt then
			local age = now - tile.failedAt
			if age >= 3.5 then self:_restoreTile(tile)
			elseif age >= 0.18 then for _, record in tile.pieces do record.part.Transparency=1;record.part.CanCollide=false;record.part.CanQuery=false end end
		end
	end end
	local occupied = false
	for player, run in self.runs do
		local character, root, humanoid = characterOf(player)
		if not character or character ~= run.character then
			self.runs[player] = nil
			if player.Parent == Players then player:SetAttribute("PCSecretObbyRow", 0) end
		else
			occupied = true
			local p = root.Position
			local localPosition = self.boundsFrame:PointToObjectSpace(p)
			if p.Y < self.floorY - 6 or p.Y > self.floorY + 65
				or math.abs(localPosition.X) > self.boundsSize.X * 0.5 + 2
				or math.abs(localPosition.Z) > self.boundsSize.Z * 0.5 + 2 then
				self:_reset(player, "Wrong turn! Try the next tile.")
			elseif run.lastPosition and (p - run.lastPosition).Magnitude > math.max(18, humanoid.WalkSpeed * dt * 4 + 8) then
				self:_reset(player, "Follow each row of the secret path.")
			else
				local floor = workspace:Raycast(p, Vector3.new(0, -footRayLength(character, root), 0), self.floorQuery)
				local tile = floor and self.tileParts[floor.Instance]
				if tile and floor.Normal.Y > 0.5 then self:_visit(player, run, tile, now) end
			end
			run.lastPosition = root.Position
		end
	end
	if occupied then self.lastOccupied = now elseif now - self.lastOccupied > 120 then self:_newPath() end
end

function Obby:Start()
	if self.running then return self end
	self.running = true
	table.insert(self.connections, self.entry.Opening.Travel.Triggered:Connect(function(player) self:_enter(player) end))
	table.insert(self.connections, self.scene.ReturnPortal.Opening.Travel.Triggered:Connect(function(player) self:_exit(player) end))
	table.insert(self.connections, self.scene.FinishReturnPortal.Opening.Travel.Triggered:Connect(function(player) self:_exit(player) end))
	table.insert(self.connections, self.scene.TreasureChest.Latch.ClaimReward.Triggered:Connect(function(player) self:_claim(player) end))
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player) self.runs[player]=nil;self.promptTimes[player]=nil end))
	local elapsed = 0
	table.insert(self.connections, RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 0.08 then local delta=elapsed;elapsed=0;self:_tick(delta) end
	end))
	return self
end

function Obby:Stop()
	self.running = false
	for _, connection in self.connections do connection:Disconnect() end
	table.clear(self.connections)
	for player in self.runs do if player.Parent == Players then self:_move(player, CFrame.new(-132, 7.6, 54));player:SetAttribute("PCSecretObbyRow", 0) end end
	table.clear(self.runs)
	for _, row in self.tiles do for _, tile in row do self:_restoreTile(tile) end end
end

return Obby]==]},
 {path="ServerScriptService.PlaygroundLobbyBenchService",expected=2000129994,after=2053443118,caps="RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Physics | UI | Input | Players | AvatarBehavior",sandboxed=true,source=[==[local Players = game:GetService("Players")

local Benches = {}
local active
local roundAttributes = { "BBParticipating", "TGParticipating", "MDParticipating", "HSParticipating", "DGParticipating", "DGEliminated" }

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

]==]},
 {path="ServerScriptService.PlaygroundFishingService",expected=420005555,after=1009253996,caps="RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Physics | UI | Input | Players | AvatarBehavior",sandboxed=true,source=[==[local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Fishing = {}
Fishing.__index = Fishing

local function characterOf(player)
	if player.Parent ~= Players or player:GetAttribute("PCDataReady") ~= true
		or player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true
		or ( player:GetAttribute("MDParticipating") == true or player:GetAttribute("HSParticipating") == true or player:GetAttribute("DGParticipating") == true or player:GetAttribute("DGEliminated") == true ) then return nil end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root then return nil end
	return character, root
end

function Fishing.new(scene, economy)
	local self = setmetatable({ scene = scene, economy = economy, stations = {}, runs = {}, requests = {}, connections = {}, running = false }, Fishing)
	for index = 1, 4 do
		local model = assert(scene:FindFirstChild("Rod" .. index), "Fishing rod is missing")
		local interaction = assert(model:FindFirstChild("Interaction"), "Fishing interaction is missing")
		local prompt = assert(interaction:FindFirstChild("Fish"), "Fishing prompt is missing")
		local bobber = assert(model:FindFirstChild("Bobber"), "Fishing bobber is missing")
		table.insert(self.stations, { model = model, interaction = interaction, prompt = prompt, bobber = bobber, rest = bobber.CFrame })
	end
	return self
end

function Fishing:_tell(player, message)
	if player.Parent ~= Players then return end
	player:SetAttribute("PCRewardText", message)
	player:SetAttribute("PCRewardAt", workspace:GetServerTimeNow())
end

function Fishing:_valid(player, station, character)
	local current, root = characterOf(player)
	return current ~= nil and (character == nil or current == character)
		and station.model:IsDescendantOf(self.scene) and station.interaction.Parent ~= nil
		and (root.Position - station.interaction.Position).Magnitude <= 10
end

function Fishing:_finish(player, run, message)
	if self.runs[player] ~= run then return end
	self.runs[player] = nil
	local station = run.station
	if station.run == run then
		station.run = nil
		if station.bobber.Parent then station.bobber.CFrame = station.rest end
		if station.prompt.Parent then station.prompt.Enabled = self.running end
		if station.model.Parent then station.model:SetAttribute("FishingUserId", nil) end
	end
	if player.Parent == Players then
		player:SetAttribute("PCFishingCasting", false)
		player:SetAttribute("PCFishingCastEnds", 0)
		if message then self:_tell(player, message) end
	end
end

function Fishing:_begin(player, station)
	if not self.running or station.run or self.runs[player] or not self:_valid(player, station) then return end
	local now = os.clock()
	if now - (self.requests[player] or -math.huge) < 0.75 then return end
	self.requests[player] = now
	local ok, reason = self.economy:CanFish(player)
	if not ok then self:_tell(player, reason or "Fishing isn't available right now.") return end
	if station.run or self.runs[player] or not self.running or not self:_valid(player, station) then return end
	local run = { station = station, character = player.Character, started = os.clock(), claiming = false }
	self.runs[player], station.run = run, run
	station.prompt.Enabled = false
	station.model:SetAttribute("FishingUserId", player.UserId)
	player:SetAttribute("PCFishingCasting", true)
	player:SetAttribute("PCFishingCastEnds", workspace:GetServerTimeNow() + 6)
	self:_tell(player, "Fishing... stay by the rod until you get a bite!")
end

function Fishing:_claim(player, run)
	if run.claiming or self.runs[player] ~= run or not self.running then return end
	if not self:_valid(player, run.station, run.character) then self:_finish(player, run, "Fishing cancelled. Your catch wasn't used.") return end
	run.claiming = true
	local called, ok, message = pcall(function() return self.economy:ClaimFishingReward(player) end)
	if not called then
		warn("Fishing reward could not finish: " .. tostring(ok))
		message = "Your catch couldn't be confirmed. Please try the rod again."
	elseif typeof(message) ~= "string" then
		message = ok and "Caught a five-minute boost!" or "Your catch couldn't be confirmed. Try again."
	end
	self:_finish(player, run, message)
end

function Fishing:_step(now)
	for player, run in self.runs do
		if run.claiming then continue end
		if not self:_valid(player, run.station, run.character) then
			self:_finish(player, run, "Fishing cancelled. Your catch wasn't used.")
		else
			local elapsed = now - run.started
			local dip = elapsed > 4.8 and -0.22 or 0
			run.station.bobber.CFrame = run.station.rest * CFrame.new(0, math.sin(elapsed * 5) * 0.055 + dip, 0)
			if elapsed >= 6 then
				run.claiming = true
				task.spawn(function()
					run.claiming = false
					self:_claim(player, run)
				end)
			end
		end
	end
end

function Fishing:Start()
	if self.running then return self end
	self.running = true
	for _, station in self.stations do
		station.prompt.Enabled = true
		station.model:SetAttribute("FishingUserId", nil)
		table.insert(self.connections, station.prompt.Triggered:Connect(function(player) self:_begin(player, station) end))
	end
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player)
		local run = self.runs[player]
		if run then self:_finish(player, run) end
		self.requests[player] = nil
	end))
	local elapsed = 0
	table.insert(self.connections, RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 0.08 then elapsed = 0 self:_step(os.clock()) end
	end))
	return self
end

function Fishing:Stop()
	self.running = false
	for _, connection in self.connections do connection:Disconnect() end
	table.clear(self.connections)
	for player, run in self.runs do self:_finish(player, run) end
	table.clear(self.requests)
	for _, station in self.stations do
		if station.prompt.Parent then station.prompt.Enabled = false end
		if station.bobber.Parent then station.bobber.CFrame = station.rest end
	end
end

return Fishing

]==]},
 {path="ServerScriptService.PlaygroundPushService",expected=317986207,after=496784774,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | Physics | UI | Animation | AvatarAppearance | Environment | RemoteEvent | LegacySound | Players | AvatarBehavior",sandboxed=true,source=[==[local Players = game:GetService("Players")
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


]==]},
 {path="StarterGui.PlaygroundPushControls.Controller",expected=2130263385,after=1882537479,caps="RunClientScript | AccessOutsideWrite | Basic | Physics | UI | Input | RemoteEvent | Players | AvatarBehavior",sandboxed=true,source=[==[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local gui = script.Parent
local playerGui = gui.Parent
local tagGui = playerGui:WaitForChild("TagHUD")
local bulldogGui = playerGui:WaitForChild("BritishBulldogHUD")
local buttons = {
	Tag = { gui = tagGui, button = tagGui:WaitForChild("SprintPanel"):WaitForChild("Push") },
	Bulldog = { gui = bulldogGui, button = bulldogGui:WaitForChild("MovementControls"):WaitForChild("Push") },
	Mobile = { gui = gui, button = gui:WaitForChild("MobilePush") },
}
local connections = {}
local actionName = "PlaygroundPush"
local alive, focused, bound = true, true, false
local nextTapAt, elapsed = 0, 0

local function activeGame()
	if player:GetAttribute("PCDataReady") ~= true or player:GetAttribute("MDParticipating") == true
		or player:GetAttribute("BBRagdolled") == true or player:GetAttribute("TGRagdolled") == true
		or player:GetAttribute("PCPushed") == true or player:GetAttribute("HSParticipating") == true
		or player:GetAttribute("DGParticipating") == true or player:GetAttribute("DGEliminated") == true then return nil end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or humanoid.Sit then return nil end
	local now = workspace:GetServerTimeNow()
	if player:GetAttribute("BBParticipating") == true then
		local state = ReplicatedStorage:FindFirstChild("BritishBulldogState")
		local role = player:GetAttribute("BBRole")
		local status = player:GetAttribute("BBStatus")
		if state and state:GetAttribute("Phase") == "Crossing"
			and (role == "Runner" and status == "Crossing" or role == "Bulldog" and status == "Bulldog") then return "Bulldog" end
	elseif player:GetAttribute("TGParticipating") == true then
		local state = ReplicatedStorage:FindFirstChild("TagState")
		local role = player:GetAttribute("TGRole")
		local protected = player:GetAttribute("TGProtectedEndsAt")
		if state and state:GetAttribute("Phase") == "Playing" and (role == "Runner" or role == "Tagger")
			and (typeof(protected) ~= "number" or protected <= now) then return "Tag" end
	end
	return nil
end

local function remainingCooldown()
	local readyAt = player:GetAttribute("PCPushReadyAt")
	local serverRemaining = typeof(readyAt) == "number" and readyAt == readyAt
		and readyAt < math.huge and readyAt - workspace:GetServerTimeNow() or 0
	return math.max(0, serverRemaining, nextTapAt - os.clock())
end

local function inputHint()
	local last = UserInputService:GetLastInputType()
	if string.find(last.Name, "Gamepad", 1, true) then
		local label = UserInputService:GetStringForKeyCode(Enum.KeyCode.ButtonX)
		return (label == "ButtonSquare" or label == "Square") and "[\u{25A1}]" or "[X]"
	end
	if last == Enum.UserInputType.Touch or UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then return "TAP" end
	return "[Q]"
end

local function inputReady()
	return alive and gui.Enabled and focused and not GuiService.MenuIsOpen and not UserInputService:GetFocusedTextBox()
end

local refresh
local function push()
	local gameId = activeGame()
	local entry = gameId and (UserInputService.TouchEnabled and buttons.Mobile or buttons[gameId])
	if not entry or not entry.gui.Enabled or not entry.button.Visible or not inputReady() or remainingCooldown() > 0 then return end
	local remote = ReplicatedStorage:FindFirstChild("PlaygroundPushRequest")
	if not remote or not remote:IsA("RemoteEvent") then return end
	nextTapAt = os.clock() + 0.35
	local ok = pcall(function() remote:FireServer() end)
	if not ok then nextTapAt = 0 end
	refresh()
end

local function action(_, inputState)
	if not activeGame() or not inputReady() then return Enum.ContextActionResult.Pass end
	if inputState == Enum.UserInputState.Begin then push() end
	return Enum.ContextActionResult.Sink
end

refresh = function()
	local gameId = activeGame()
	local displayId = gameId and (UserInputService.TouchEnabled and "Mobile" or gameId)
	local remaining = remainingCooldown()
	local ready = gameId ~= nil and inputReady() and remaining <= 0
	for id, entry in pairs(buttons) do
		local button = entry.button
		button.Visible = gui.Enabled and id == displayId
		button.Active = id == displayId and ready
		button.Interactable = button.Active
		button.Selectable = button.Active
		button.Hint.Text = remaining > 0 and string.format("%.1fs", remaining) or inputHint()
		button.ReusableSkin.ImageColor3 = ready and Color3.new(1, 1, 1) or Color3.fromRGB(164, 170, 184)
		button.Fallback.Visible = not button.ReusableSkin.IsLoaded
	end
	if gameId and gui.Enabled and not bound then
		ContextActionService:BindActionAtPriority(actionName, action, false, 3000, Enum.KeyCode.Q, Enum.KeyCode.ButtonX)
		bound = true
	elseif (not gameId or not gui.Enabled) and bound then
		ContextActionService:UnbindAction(actionName)
		bound = false
	end
end

local function connect(signal, callback)
	table.insert(connections, signal:Connect(callback))
end
for _, entry in pairs(buttons) do connect(entry.button.Activated, push) end
connect(UserInputService.WindowFocusReleased, function() focused = false refresh() end)
connect(UserInputService.WindowFocused, function() focused = true refresh() end)
connect(UserInputService.LastInputTypeChanged, refresh)
connect(player.CharacterRemoving, function() nextTapAt = 0 for _, entry in pairs(buttons) do entry.button.Visible = false end end)
connect(player.CharacterAdded, function() nextTapAt = 0 refresh() end)
connect(player.AttributeChanged, refresh)
connect(gui:GetPropertyChangedSignal("Enabled"), refresh)
connect(RunService.Heartbeat, function(delta)
	elapsed += delta
	if elapsed >= 0.05 then elapsed = 0 refresh() end
end)
connect(script.Destroying, function()
	alive = false
	if bound then ContextActionService:UnbindAction(actionName) end
	for _, connection in connections do connection:Disconnect() end
	for _, entry in pairs(buttons) do entry.button.Visible = false end
end)
refresh()
]==]}}
local function fingerprint(source)
 source = string.gsub(source,"\r\n","\n")
 local value=0
 for index=1,#source do value=(value*31+string.byte(source,index))%2147483647 end
 return value
end
local objects={}
for _,entry in entries do
 local object=game
 for name in string.gmatch(entry.path,"[^.]+") do object=object:FindFirstChild(name) assert(object,"Missing "..entry.path) end
 local hash=fingerprint(object.Source)
 assert(hash==entry.expected or hash==entry.after,"Source changed: "..entry.path)
 assert(tostring(object.Capabilities)==entry.caps and object.Sandboxed==entry.sandboxed,"Permissions changed: "..entry.path)
 objects[entry.path]=object
end
local storage=game:GetService("ServerStorage")
local backup=storage:FindFirstChild("DuckDuckGooseIntegrationBackup20261010")
if not backup then backup=Instance.new("Folder") backup.Name,backup.Parent="DuckDuckGooseIntegrationBackup20261010",storage end
local changed=0
for _,entry in entries do
 local object=objects[entry.path]
 if fingerprint(object.Source)~=entry.after then
  local snapshot=object:Clone()
  snapshot.Name=entry.path
  if snapshot:IsA("BaseScript") then snapshot.Enabled=false end
  snapshot.Parent=backup
  object.Source=entry.source
  object:SetAttribute("DuckDuckGooseIntegrated20261010",true)
  changed+=1
 end
end
return {patched=changed,capabilitiesPreserved=true,backup=backup:GetFullName()}
