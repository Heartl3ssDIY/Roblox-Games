local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Obby = {}
Obby.__index = Obby

local function participating(player)
	return player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true or ( player:GetAttribute("MDParticipating") == true or player:GetAttribute("HSParticipating") == true or player:GetAttribute("DGParticipating") == true or player:GetAttribute("DGEliminated") == true or player:GetAttribute("SKParticipating") == true or player:GetAttribute("SKEliminated") == true )
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
		for _, record in tile.pieces do
			record.part.Transparency = 1
			record.part.CanCollide = false
			record.part.CanQuery = false
		end
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
			if age >= 3.5 then self:_restoreTile(tile) end
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
	table.insert(self.connections, RunService.Heartbeat:Connect(function(dt) self:_tick(dt) end))
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