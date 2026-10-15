local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage:WaitForChild("PlaygroundCatalog"))
local Equipment = {}
Equipment.__index = Equipment

local function disconnect(connections)
	for _, connection in ipairs(connections) do connection:Disconnect() end
	table.clear(connections)
end

local function participating(player)
	return player:GetAttribute("BBParticipating") == true
		or player:GetAttribute("TGParticipating") == true
		or player:GetAttribute("MDParticipating") == true
end

local function visibleBounds(model)
	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency < 1 and part:GetAttribute("PCStudLayer") ~= true then
			for x = -1, 1, 2 do for y = -1, 1, 2 do for z = -1, 1, 2 do
				local point = part.CFrame:PointToWorldSpace(part.Size * Vector3.new(x, y, z) * 0.5)
				low = low:Min(point)
				high = high:Max(point)
			end end end
		end
	end
	if low.X == math.huge then return nil end
	return low, high
end

local function anchorPart(name)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.new(0.15, 0.15, 0.15)
	part.Transparency = 1
	part.Massless = true
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	return part
end

local function weldModel(model, anchor)
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("LuaSourceContainer") then child:Destroy()
		elseif child:IsA("BasePart") then
			child.Anchored = false
			child.Massless = true
			child.CanCollide = false
			child.CanTouch = false
			child.CanQuery = false
			local coatingWeld = child:GetAttribute("PCStudLayer") == true and child:FindFirstChild("StudFinishWeld")
			if not coatingWeld or not coatingWeld:IsA("WeldConstraint") or not coatingWeld.Part0 or not coatingWeld.Part1 then
				local weld = Instance.new("WeldConstraint")
				weld.Name = "CosmeticGripWeld"
				weld.Part0 = anchor
				weld.Part1 = child
				weld.Parent = child
			end
		elseif child:IsA("Highlight") then child.Adornee = model end
	end
end

function Equipment.new()
	return setmetatable({ running = false, records = {}, connections = {} }, Equipment)
end

function Equipment:_clearBat(record)
	local model = record.bat
	record.bat = nil
	record.batId = nil
	if model then model:Destroy() end
end

function Equipment:_clearGear(record)
	disconnect(record.gearConnections)
	local tool = record.gear
	record.gear = nil
	record.gearId = nil
	if tool then tool:Destroy() end
end

function Equipment:_queue(record)
	if not self.running or record.closed or record.queued then return end
	record.queued = true
	task.defer(function()
		record.queued = false
		if self.running and not record.closed then self:_refresh(record) end
	end)
end

function Equipment:_makeBat(record, item, hand, original)
	local visual = original:Clone()
	local low, high = visibleBounds(visual)
	if not low then visual:Destroy() return end
	local size = high - low
	local grip = Vector3.new((low.X + high.X) * 0.5, low.Y + math.min(size.Y * 0.14, 0.42), (low.Z + high.Z) * 0.5)
	local gripAttachment = hand:FindFirstChild("RightGripAttachment")
	local handOffset = gripAttachment and gripAttachment:IsA("Attachment") and gripAttachment.Position or Vector3.new(0, -hand.Size.Y * 0.45, 0)
	local target = hand.CFrame * CFrame.new(handOffset) * CFrame.Angles(math.rad(-65), 0, math.rad(-8))
	local carrier = Instance.new("Model")
	carrier.Name = "PCCosmeticBat"
	carrier:SetAttribute("PCCosmeticEquipment", true)
	carrier:SetAttribute("CatalogId", item.id)
	local anchor = anchorPart("GripAnchor")
	anchor.CFrame = target
	anchor.Parent = carrier
	carrier.PrimaryPart = anchor
	visual.Name = "Visual"
	visual:PivotTo(target * CFrame.new(-grip) * visual:GetPivot())
	visual.Parent = carrier
	weldModel(visual, anchor)
	local handWeld = Instance.new("WeldConstraint")
	handWeld.Name = "RightHandGrip"
	handWeld.Part0 = hand
	handWeld.Part1 = anchor
	handWeld.Parent = anchor
	record.bat = carrier
	record.batId = item.id
	carrier.Parent = record.character
end

function Equipment:_makeGear(record, item, backpack, original)
	local visual = original:Clone()
	local low, high = visibleBounds(visual)
	if not low then visual:Destroy() return end
	local center = (low + high) * 0.5
	local size = high - low
	local grip = Vector3.new(center.X, low.Y + math.min(size.Y * 0.25, 0.45), center.Z + size.Z * 0.2)
	visual:PivotTo(CFrame.new(-grip) * visual:GetPivot())
	local tool = Instance.new("Tool")
	tool.Name = item.name
	tool.ToolTip = item.name .. " · collectible toy"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.Enabled = false
	tool.Grip = CFrame.new(0, -0.15, 0)
	tool:SetAttribute("PCCosmeticEquipment", true)
	tool:SetAttribute("CatalogId", item.id)
	tool:SetAttribute("CosmeticOnly", true)
	local handle = anchorPart("Handle")
	handle.Parent = tool
	visual.Name = "Visual"
	visual.Parent = tool
	weldModel(visual, handle)
	record.gear = tool
	record.gearId = item.id
	table.insert(record.gearConnections, tool.Equipped:Connect(function()
		if participating(record.player) then self:_clearGear(record) self:_queue(record) end
	end))
	table.insert(record.gearConnections, tool.AncestryChanged:Connect(function() self:_queue(record) end))
	tool.Parent = backpack
end

function Equipment:_refresh(record)
	local player = record.player
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local ready = player:GetAttribute("PCDataReady") == true
	if character ~= record.character or not ready or not humanoid or humanoid.Health <= 0 then
		self:_clearBat(record)
		self:_clearGear(record)
		return
	end
	local assets = ReplicatedStorage:FindFirstChild("PlaygroundCosmeticAssets")
	local batId = player:GetAttribute("PCBat")
	local bat = typeof(batId) == "string" and Catalog.ById[batId]
	local bulldog = player:GetAttribute("BBParticipating") == true and player:GetAttribute("BBRole") == "Bulldog"
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local batAsset = bat and assets and assets:FindFirstChild(bat.id)
	if not bulldog or not bat or bat.slot ~= "Bat" or bat.available == false or not hand or not hand:IsA("BasePart") or not batAsset or not batAsset:IsA("Model") then
		self:_clearBat(record)
	elseif record.batId ~= bat.id or not record.bat or record.bat.Parent ~= character then
		self:_clearBat(record)
		self:_makeBat(record, bat, hand, batAsset)
	end
	local gearId = player:GetAttribute("PCGear")
	local gear = typeof(gearId) == "string" and Catalog.ById[gearId]
	local backpack = player:FindFirstChildOfClass("Backpack")
	local gearAsset = gear and assets and assets:FindFirstChild(gear.id)
	if participating(player) or not gear or gear.slot ~= "Gear" or gear.available == false or not backpack or not gearAsset or not gearAsset:IsA("Model") then
		self:_clearGear(record)
	elseif record.gearId ~= gear.id or not record.gear or (record.gear.Parent ~= backpack and record.gear.Parent ~= character) then
		self:_clearGear(record)
		self:_makeGear(record, gear, backpack, gearAsset)
	end
end

function Equipment:_bindCharacter(record, character)
	disconnect(record.characterConnections)
	self:_clearBat(record)
	self:_clearGear(record)
	record.character = character
	record.humanoid = nil
	local function bindHumanoid(child)
		if child:IsA("Humanoid") and record.humanoid ~= child then
			record.humanoid = child
			table.insert(record.characterConnections, child.Died:Connect(function()
				self:_clearBat(record)
				self:_clearGear(record)
			end))
		end
	end
	for _, child in ipairs(character:GetChildren()) do
		if child:GetAttribute("PCCosmeticEquipment") == true then child:Destroy() else bindHumanoid(child) end
	end
	table.insert(record.characterConnections, character.ChildAdded:Connect(function(child)
		bindHumanoid(child)
		if child:IsA("BasePart") or child:IsA("Humanoid") then self:_queue(record) end
	end))
	table.insert(record.characterConnections, character.ChildRemoved:Connect(function(child)
		if child == record.bat or child:IsA("BasePart") then self:_queue(record) end
	end))
	self:_queue(record)
end

function Equipment:_addPlayer(player)
	if self.records[player] then return end
	local record = { player = player, connections = {}, characterConnections = {}, gearConnections = {}, closed = false }
	self.records[player] = record
	for _, attribute in ipairs({ "PCBat", "PCGear", "PCDataReady", "BBRole", "BBParticipating", "TGParticipating", "MDParticipating" }) do
		table.insert(record.connections, player:GetAttributeChangedSignal(attribute):Connect(function() self:_queue(record) end))
	end
	table.insert(record.connections, player.CharacterAdded:Connect(function(character) self:_bindCharacter(record, character) end))
	table.insert(record.connections, player.CharacterRemoving:Connect(function(character)
		if character == record.character then
			disconnect(record.characterConnections)
			self:_clearBat(record)
			self:_clearGear(record)
			record.character = nil
		end
	end))
	table.insert(record.connections, player.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then self:_queue(record) end
	end))
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then for _, child in ipairs(backpack:GetChildren()) do if child:GetAttribute("PCCosmeticEquipment") == true then child:Destroy() end end end
	if player.Character then self:_bindCharacter(record, player.Character) end
end

function Equipment:_removePlayer(player)
	local record = self.records[player]
	if not record then return end
	record.closed = true
	disconnect(record.connections)
	disconnect(record.characterConnections)
	self:_clearBat(record)
	self:_clearGear(record)
	self.records[player] = nil
end

function Equipment:Start()
	if self.running then return self end
	self.running = true
	table.insert(self.connections, Players.PlayerAdded:Connect(function(player) self:_addPlayer(player) end))
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player) self:_removePlayer(player) end))
	local assets = ReplicatedStorage:FindFirstChild("PlaygroundCosmeticAssets")
	if assets then
		table.insert(self.connections, assets.ChildAdded:Connect(function()
			for _, record in pairs(self.records) do self:_queue(record) end
		end))
	end
	for _, player in ipairs(Players:GetPlayers()) do self:_addPlayer(player) end
	return self
end

function Equipment:Stop()
	self.running = false
	disconnect(self.connections)
	local players = {}
	for player in pairs(self.records) do table.insert(players, player) end
	for _, player in ipairs(players) do self:_removePlayer(player) end
end

return Equipment
