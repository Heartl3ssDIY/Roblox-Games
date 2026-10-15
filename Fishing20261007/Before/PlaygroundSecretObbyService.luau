local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Obby = {}
Obby.__index = Obby

local function participating(player)
	return player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true or player:GetAttribute("MDParticipating") == true
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

function Obby.new(scene, entry, economy)
	local self = setmetatable({}, Obby)
	self.scene, self.entry, self.economy = scene, entry, economy
	self.runs, self.connections, self.promptTimes = {}, {}, {}
	self.tiles, self.path = {}, {}
	self.random = Random.new()
	self.floorQuery = RaycastParams.new()
	self.floorQuery.FilterType = Enum.RaycastFilterType.Include
	self.floorQuery.FilterDescendantsInstances = {scene.Tiles}
	self.running = false
	self.lastOccupied = os.clock()
	for _, model in scene.Tiles:GetChildren() do
		local row, column = model:GetAttribute("Row"), model:GetAttribute("Column")
		local tile = { model = model, top = model.Top, row = row, column = column, pieces = {} }
		for _, p in model:GetDescendants() do if p:IsA("BasePart") then table.insert(tile.pieces, {part=p, transparency=p.Transparency, collide=p.CanCollide, query=p.CanQuery, color=p.Color}) end end
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
	if not near(player, opening, 12) or player:GetAttribute("PCDataReady") ~= true then return end
	local now = os.clock()
	if now - (self.promptTimes[player] or -math.huge) < 1 then return end
	self.promptTimes[player] = now
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
	if ok then self:_tell(player, "+1,000 coins! Secret Steps complete.") else self:_tell(player, message) end
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
			if p.Y < 14 or p.Y > 85 or p.X < -372 or p.X > -240 or p.Z < 28 or p.Z > 80 then
				self:_reset(player, "Wrong turn! Try the next tile.")
			elseif run.lastPosition and (p - run.lastPosition).Magnitude > math.max(18, humanoid.WalkSpeed * dt * 4 + 8) then
				self:_reset(player, "Follow each row of the secret path.")
			else
				local row = math.floor((-p.X - 267) / 8 + 0.5)
				local column = math.floor((p.Z - 54) / 8 + 2.5)
				local tile = self.tiles[row] and self.tiles[row][column]
				if tile and math.abs(p.X - tile.top.Position.X) <= 3.8 and math.abs(p.Z - tile.top.Position.Z) <= 3.8 and p.Y >= 20.8 and p.Y <= 26.2 then
					local floor = workspace:Raycast(p, Vector3.new(0, -math.clamp(humanoid.HipHeight + 2.1, 2.4, 4.6), 0), self.floorQuery)
					if floor and floor.Instance:IsDescendantOf(tile.model) then self:_visit(player, run, tile, now) end
				end
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

return Obby


