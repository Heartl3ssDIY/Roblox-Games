assert(not game:GetService("RunService"):IsRunning(),"Edit only")
local container=Instance.new("Folder")
container.Name="CaveInstantTileNativeFixture20261011"
container.Parent=game.ServerStorage
local now=100
local function signal()
 local entries={}
 return {Connect=function(_,callback) local entry={active=true,callback=callback} table.insert(entries,entry) return {Disconnect=function() entry.active=false end} end,
 Fire=function(_,...) for _,entry in ipairs(entries) do if entry.active then entry.callback(...) end end end}
end
local heartbeat=signal()
local players={PlayerRemoving=signal()}
local services={Players=players,RunService={Heartbeat=heartbeat}}
local env={game={GetService=function(_,name) return services[name] end},workspace={GetServerTimeNow=function() return now end},os={clock=function() return now end}}
local module=game.ServerScriptService.PlaygroundSecretObbyService:Clone()
module.Name="CaveInstantTileModuleFixture"
module.Source="return function(env)\nlocal game,workspace,os=env.game,env.workspace,env.os\n"..[======[local Players = game:GetService("Players")
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

return Obby]======].."\nend"
module.Parent=container
local report={checks={}}
local function check(name,condition) table.insert(report.checks,{name=name,passed=condition==true}) assert(condition,name) end
local service
local ok,failure=xpcall(function()
 local Obby=require(module)(env)
 local scene=Instance.new("Model") scene.Name,scene.Parent="Scene",container
 local tiles=Instance.new("Folder") tiles.Name,tiles.Parent="Tiles",scene
 for row=1,8 do for column=1,3 do
  local model=Instance.new("Model") model.Name,model.Parent="Tile"..row.."_"..column,tiles
  model:SetAttribute("Row",row) model:SetAttribute("Column",column)
  local top=Instance.new("Part") top.Name,top.Size,top.CFrame="Top",Vector3.new(3,1,3),CFrame.new(column*4,0,row*4) top.Anchored=true top.Parent=model
  local rim=Instance.new("Part") rim.Name,rim.Size,rim.CFrame="Rim",Vector3.new(3.4,.2,3.4),CFrame.new(column*4,-.6,row*4) rim.Anchored=true rim.Transparency=.2 rim.Parent=model
 end end
 for _,name in ipairs({"ReturnPortal","FinishReturnPortal","TreasureChest"}) do
  local folder=Instance.new("Folder") folder.Name,folder.Parent=name,scene
  local part=Instance.new("Part") part.Name,part.Parent=name=="TreasureChest" and "Latch" or "Opening",folder
  local prompt=Instance.new("ProximityPrompt") prompt.Name,prompt.Parent=name=="TreasureChest" and "ClaimReward" or "Travel",part
 end
 local entry=Instance.new("Folder") entry.Name,entry.Parent="Entry",container
 local opening=Instance.new("Part") opening.Name,opening.Parent="Opening",entry
 local prompt=Instance.new("ProximityPrompt") prompt.Name,prompt.Parent="Travel",opening
 local rewards=0
 service=Obby.new(scene,entry,{ClaimSecretObbyReward=function() rewards+=1 return true,"ok" end})
 for row=1,8 do service.path[row]=2 end
 local player=Instance.new("Folder") player.Name,player.Parent="FakePlayer",container
 local run={row=0,lastStep=-math.huge}
 local wrong=service.tiles[1][1]
 service:_visit(player,run,wrong,now)
 check("Wrong tile hides during visit without yielding",wrong.top.Transparency==1 and wrong.model.Rim.Transparency==1)
 check("Wrong tile loses collision immediately",not wrong.top.CanCollide and not wrong.model.Rim.CanCollide)
 check("Wrong tile is immediately excluded from floor queries",not wrong.top.CanQuery and not wrong.model.Rim.CanQuery)
 check("Wrong tile starts unchanged restore clock",wrong.failedAt==100)
 check("Wrong tile does not advance path",run.row==0)
 now=103.49 service:_tick(.01)
 check("Wrong tile stays missing before3.5seconds",wrong.top.Transparency==1 and not wrong.top.CanCollide)
 now=103.5 service:_tick(.01)
 check("Tile restores at3.5seconds",wrong.failedAt==nil and wrong.top.Transparency==0 and wrong.top.CanCollide and wrong.top.CanQuery)
 check("Decorative transparency restores exactly",math.abs(wrong.model.Rim.Transparency-.2)<.00001 and wrong.model.Rim.CanCollide)
 local safe=service.tiles[1][2]
 service:_visit(player,run,safe,now)
 check("Correct path advances normally",run.row==1 and player:GetAttribute("PCSecretObbyRow")==1)
 check("Correct tile remains visible and collidable",safe.top.Transparency==0 and safe.top.CanCollide and safe.failedAt==nil)
 local before=service._tick local ticks=0
 service._tick=function() ticks+=1 end
 service:Start()
 heartbeat:Fire(1/240)
 check("Footing checks run on the next heartbeat without throttle",ticks==1)
 heartbeat:Fire(1/240)
 check("Second heartbeat checks immediately too",ticks==2)
 service._tick=before
 service:_visit(player,run,wrong,now)
 service:Stop()
 check("Stopping restores collapsed tiles",wrong.top.Transparency==0 and wrong.top.CanCollide and wrong.failedAt==nil)
 check("No reward granted from wrong tiles or resets",rewards==0)
 check("Safe path stays unchanged",service.path[1]==2 and service.path[8]==2)
end,debug.traceback)
pcall(function() if service then service:Stop() end end)
container:Destroy()
report.passed,report.error,report.checkCount=ok,ok and nil or failure,#report.checks
return game:GetService("HttpService"):JSONEncode(report)
