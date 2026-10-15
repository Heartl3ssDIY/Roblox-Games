from pathlib import Path

root = Path(__file__).resolve().parent
source = (root / 'Before/PlaygroundEquipmentService.luau').read_text(encoding='utf-8')
source = source.replace('function Equipment.new(batServices)', 'function Equipment.new(batServices, toys)')
source = source.replace('batServices = batServices or {} }, Equipment)', 'batServices = batServices or {}, toys = toys }, Equipment)')
source = source.replace('function Equipment:_clearGear(record)\n', '''function Equipment:_clearGear(record)
	if self.toys then self.toys:CancelAction(record.player) end
	if record.character then record.character:SetAttribute("PCToyHeld", nil) end
''')
source = source.replace('tool.ToolTip = item.name .. " · collectible toy"', 'tool.ToolTip = item.name .. " · lobby toy"')
source = source.replace('tool.Enabled = false\n\ttool.Grip', 'tool.Enabled = true\n\ttool.ManualActivationOnly = true\n\ttool.Grip')
source = source.replace('tool:SetAttribute("CosmeticOnly", true)', 'tool:SetAttribute("PCToy", true)')
needle = '''	table.insert(record.gearConnections, tool.Equipped:Connect(function()
		if participating(record.player) then self:_clearGear(record) self:_queue(record) end
	end))'''
replacement = '''	local function mirrorHeld(held)
		if record.gear ~= tool or not record.character then return end
		record.character:SetAttribute("PCToyHeld", held and item.id or nil)
		if self.toys then
			if held then self.toys:Hold(record.player) else self.toys:CancelAction(record.player) end
		end
	end
	table.insert(record.gearConnections, tool.Equipped:Connect(function()
		if participating(record.player) then self:_clearGear(record) self:_queue(record) else mirrorHeld(true) end
	end))
	table.insert(record.gearConnections, tool.Unequipped:Connect(function() mirrorHeld(false) end))
	if item.id == "M14" then
		local flame = anchorPart("TorchFlame")
		flame.CFrame = CFrame.new(0, size.Y - math.min(size.Y * 0.25, 0.45), -size.Z * 0.2)
		flame.Parent = tool
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1, weld.Parent = handle, flame, flame
		local fire = Instance.new("Fire")
		fire.Name, fire.Size, fire.Heat, fire.Parent = "CampFlame", 2.4, 3, flame
		local light = Instance.new("PointLight")
		light.Color, light.Brightness, light.Range, light.Parent = Color3.fromRGB(255, 170, 70), 0.6, 9, flame
	end'''
assert needle in source
source = source.replace(needle, replacement)
source = source.replace('tool.Parent = backpack\nend', '''tool.Parent = backpack
	local humanoid = record.character:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid:EquipTool(tool) end
	mirrorHeld(tool.Parent == record.character)
end''')
source = source.replace('''	if character ~= record.character or not ready or not humanoid or humanoid.Health <= 0 then
''', '''	if character ~= record.character or not ready or not humanoid or humanoid.Health <= 0 then
		if self.toys then self.toys:ClearPlayer(player) end
''')
source = source.replace('''	local gearId = player:GetAttribute("PCGear")''', '''	if participating(player) and self.toys then self.toys:ClearPlayer(player) end
	local gearId = player:GetAttribute("PCGear")''')
source = source.replace('''		self:_makeGear(record, gear, backpack, gearAsset)
	end
end''', '''		self:_makeGear(record, gear, backpack, gearAsset)
	elseif record.gear.Parent ~= character then
		humanoid:EquipTool(record.gear)
		character:SetAttribute("PCToyHeld", gear.id)
		if self.toys then self.toys:Hold(player) end
	end
end''')
source = source.replace('''	disconnect(record.characterConnections)
	self:_clearBat(record)
	self:_clearGear(record)
	record.character = character''', '''	disconnect(record.characterConnections)
	if self.toys then self.toys:ClearPlayer(record.player) end
	self:_clearBat(record)
	self:_clearGear(record)
	record.character = character''')
source = source.replace('''			table.insert(record.characterConnections, humanoid.Died:Connect(function()
''', '''			table.insert(record.characterConnections, humanoid.Died:Connect(function()
				if self.toys then self.toys:ClearPlayer(record.player) end
''')
source = source.replace('''		if character == record.character then
''', '''		if character == record.character then
			if self.toys then self.toys:ClearPlayer(record.player) end
''')
source = source.replace('''	record.closed = true
''', '''	record.closed = true
	if self.toys then self.toys:ClearPlayer(player) end
''')
source = source.replace('function Equipment:Start()', '''function Equipment:UseToy(player, aim)
	local record = self.records[player]
	if not self.running or not record or record.closed or not self.toys then return { ok = false, message = "Toys are loading." } end
	return self.toys:Use(player, record.gear, aim)
end

function Equipment:PrepareRound(selected)
	local players = typeof(selected) == "Instance" and { selected } or selected or Players:GetPlayers()
	for _, player in ipairs(players) do
		if player.Parent == Players then
			if self.toys then self.toys:ClearPlayer(player) end
			local record = self.records[player]
			if record then self:_clearGear(record) end
		end
	end
end

function Equipment:Start()''')
(root / 'After/PlaygroundEquipmentService.luau').write_text(source, encoding='utf-8')

bootstrap = (root / 'Before/PlaygroundBootstrap.luau').read_text(encoding='utf-8')
needle = '''local equipment = Equipment.new({ BritishBulldog = britishBulldog, TagYoureIt = tag }):Start()
script.Destroying:Connect(function() equipment:Stop() end)'''
replacement = '''local Toys = require(ServerScriptService:WaitForChild("PlaygroundToyService"))
local toys = Toys.new({ playBonk = function(position)
	local template = ReplicatedStorage:FindFirstChild("ToyBonk")
	if not template or not template:IsA("Sound") then return end
	local anchor = Instance.new("Part")
	anchor.Name, anchor.Size, anchor.Position = "ToyBonkSound", Vector3.new(0.1, 0.1, 0.1), position
	anchor.Anchored, anchor.CanCollide, anchor.CanTouch, anchor.CanQuery, anchor.Transparency = true, false, false, false, 1
	anchor.Parent = workspace
	local sound = template:Clone()
	sound.Volume, sound.RollOffMaxDistance, sound.Parent = 0.4, 50, anchor
	sound:Play()
	game:GetService("Debris"):AddItem(anchor, 4)
end }):Start()
local equipment = Equipment.new({ BritishBulldog = britishBulldog, TagYoureIt = tag }, toys):Start()
for service, methodName in pairs({ [britishBulldog] = "_beginRound", [tag] = "_begin", [mud] = "_begin" }) do
	local original = service[methodName]
	service[methodName] = function(instance, selected, ...)
		equipment:PrepareRound(selected)
		return original(instance, selected, ...)
	end
end
local toyRequest = ReplicatedStorage:WaitForChild("PlaygroundToyRequest")
local toyRequests = {}
toyRequest.OnServerInvoke = function(player, action, aim)
	if player.Parent ~= Players or action ~= "Use" then return { ok = false, message = "Invalid toy request." } end
	local current = os.clock()
	if current - (toyRequests[player] or -math.huge) < 0.1 then return { ok = false, message = "Please wait." } end
	toyRequests[player] = current
	return equipment:UseToy(player, aim)
end
local toyLeaving = Players.PlayerRemoving:Connect(function(player) toyRequests[player] = nil end)
script.Destroying:Connect(function()
	toyRequest.OnServerInvoke = nil
	toyLeaving:Disconnect()
	equipment:Stop()
	toys:Stop()
end)'''
assert needle in bootstrap
bootstrap = bootstrap.replace(needle, replacement)
(root / 'After/PlaygroundBootstrap.luau').write_text(bootstrap, encoding='utf-8')
