return function()
	assert(not game:GetService("RunService"):IsRunning(), "Edit mode required")
	local staging = game.ServerStorage._ToyRoundRepairChecks20261008
	local Equipment = require(staging.PlaygroundEquipmentService)
	local Toys = require(staging.PlaygroundToyService)
	local fixture = Instance.new("Folder")
	fixture.Name, fixture.Parent = "NativeToyFixtures", staging
	local checks, services = {}, {}
	local function check(name, value)
		assert(value, name)
		table.insert(checks, name)
	end
	local toys = Toys.new()
	toys.running = true
	toys.folder = Instance.new("Folder")
	toys.folder.Parent = fixture
	toys.bounds = Instance.new("Part")
	toys.bounds.Size, toys.bounds.CFrame, toys.bounds.Parent = Vector3.new(100, 50, 100), CFrame.new(100000, 10, 100000), fixture
	local equipment = Equipment.new(nil, toys)
	equipment.running = true
	local function fakePlayer(label)
		local character = Instance.new("Model")
		character.Name = label
		for _, name in {"HumanoidRootPart", "Torso", "Right Arm"} do
			local part = Instance.new("Part")
			part.Name, part.Anchored, part.Position, part.Parent = name, true, Vector3.new(100000, 10, 100000), character
		end
		local humanoid = Instance.new("Humanoid")
		humanoid.RequiresNeck = false
		humanoid.Parent = character
		character.Parent = fixture
		local root = character.HumanoidRootPart
		local backpack, starterGear = Instance.new("Backpack"), Instance.new("Folder")
		backpack.Parent, starterGear.Parent = fixture, fixture
		local attributes = { PCDataReady = true, PCGear = "M01" }
		local player = { Parent = game.Players, Character = character, UserId = 999999, attributes = attributes }
		function player:GetAttribute(key) return self.attributes[key] end
		function player:SetAttribute(key, value) self.attributes[key] = value end
		function player:FindFirstChildOfClass(class) return class == "Backpack" and backpack or nil end
		function player:FindFirstChild(name) return name == "StarterGear" and starterGear or nil end
		local record = { player = player, character = character, gearConnections = {}, batConnections = {}, characterConnections = {}, backpackConnections = {}, connections = {}, closed = false }
		equipment.records[player] = record
		table.insert(services, record)
		return player, record, backpack, starterGear, root
	end
	local function tool(parent, id, marked)
		local item = Instance.new("Tool")
		item:SetAttribute("CatalogId", id)
		if marked then item:SetAttribute("PCToy", true) else item:SetAttribute("PCCosmeticEquipment", true) end
		item.Parent = parent
		return item
	end
	local function toyCount(record)
		local total = 0
		for _, container in { record.character, record.player:FindFirstChildOfClass("Backpack"), record.player:FindFirstChild("StarterGear") } do
			for _, child in container:GetChildren() do if child:IsA("Tool") and child:GetAttribute("PCToy") == true then total += 1 end end
		end
		return total
	end
	local ok, problem = xpcall(function()
		local player, record, backpack, starterGear, root = fakePlayer("Owner")
		check("lobby character can hold toys", toys:CanHold(player) and equipment:_toyAllowed(record))
		local keeper = tool(record.character, "M01", true)
		record.gear, record.gearId = keeper, "M01"
		local duplicate = tool(record.character, "M01", true)
		local backpackCopy = tool(backpack, "M01", true)
		local respawnCopy = tool(starterGear, "M01", true)
		local legacy = tool(backpack, "M02", false)
		local bat = tool(backpack, "B01", false)
		local gun = Instance.new("Tool")
		gun.Name, gun.Parent = "MudGun", backpack
		equipment:_reconcileToys(record, keeper)
		check("one tracked toy survives reconciliation", toyCount(record) == 1 and keeper.Parent == record.character)
		check("duplicate toy containers are cleaned", duplicate.Parent == nil and backpackCopy.Parent == nil and respawnCopy.Parent == nil and legacy.Parent == nil)
		check("bats and Mud guns are preserved", bat.Parent == backpack and gun.Parent == backpack)
		equipment:_clearGear(record)
		check("clear removes all carried and respawn toy copies", toyCount(record) == 0 and not record.gear and record.character:GetAttribute("PCToyHeld") == nil)
		local catalog = require(game.ReplicatedStorage.PlaygroundCatalog)
		local source = game.ReplicatedStorage.PlaygroundCosmeticAssets.M01
		for index = 1, 6 do
			equipment:_refresh(record)
			task.wait()
			check("repeated lobby refresh has one toy " .. index, toyCount(record) == 1 and record.gear and record.gear:GetAttribute("CatalogId") == "M01")
		end
		player:SetAttribute("PCGear", "M02")
		for index = 1, 3 do equipment:_refresh(record) end
		check("switching toy replaces the old tool", toyCount(record) == 1 and record.gearId == "M02")
		player:SetAttribute("PCGear", "M01")
		equipment:_refresh(record)
		local nativeRecord = assert(toys:_record(player))
		local humanoid, time = nativeRecord.humanoid, workspace:GetServerTimeNow()
		local speed, power, height = humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight
		nativeRecord.speedUntil, nativeRecord.jumpUntil = time + 25, time + 10
		toys:_movement(nativeRecord, time)
		local projectile = Instance.new("Part") projectile.Parent = toys.folder
		toys:_object(player, projectile, 10)
		local pad = Instance.new("Model") pad.Parent = toys.folder
		toys:_object(player, pad, 15, {kind = "Pad"})
		toys:_burst(root.Position, Color3.new(1, 1, 1), "stars", 10, player)
		toys:_beam(root.Position, root.Position + Vector3.zAxis, Color3.new(1, 1, 1), player)
		local target, targetRecord = fakePlayer("Target")
		toys:_burn(player, target)
		toys:_freeze(target, player)
		local victimRecord = toys.records[target]
		check("test fixtures have active projectiles and boost effects", #toys.objects >= 4 and humanoid.WalkSpeed == speed * 3 and victimRecord.fire and victimRecord.frost)
		equipment:PrepareRound({player})
		equipment:_refresh(record)
		check("round preparation blocks queued toy recreation", record.roundPreparing and toyCount(record) == 0 and player:GetAttribute("PCToyRoundPreparing") == true)
		check("round preparation blocks activation", equipment:UseToy(player).ok == false and not toys:CanHold(player))
		check("round preparation removes projectiles pads and particle rays", #toys.objects == 0 and #toys.folder:GetChildren() == 0)
		check("round preparation restores speed and jumping", humanoid.WalkSpeed == speed and humanoid.JumpPower == power and humanoid.JumpHeight == height)
		check("round preparation removes fire freeze from affected players", victimRecord.fire == nil and victimRecord.frost == nil and victimRecord.freezeUntil == 0 and victimRecord.burnUntil == 0)
		local late = assert(toys:_record(target))
		late.speedUntil, late.jumpUntil = time + 25, time + 10
		toys:_movement(late, time)
		late.humanoid.WalkSpeed, late.humanoid.JumpHeight = 23, 9.5
		target:SetAttribute("MDParticipating", true)
		toys:ClearPlayer(target)
		check("cleanup preserves later game speed and jump writes", late.humanoid.WalkSpeed == 23 and late.humanoid.JumpHeight == 9.5)
		target:SetAttribute("MDParticipating", false)
		local nested = assert(toys:_record(target))
		nested.freezeImmuneUntil = 0
		toys:_freeze(target, player)
		nested.humanoid.WalkSpeed, nested.humanoid.JumpHeight = 24, 8.5
		target:SetAttribute("BBParticipating", true)
		toys:ClearPlayer(player)
		check("freeze owner cleanup preserves round movement", nested.humanoid.WalkSpeed == 24 and nested.humanoid.JumpHeight == 8.5 and toys.records[target] == nil)
		target:SetAttribute("BBParticipating", false)
		for _, flag in {"BBParticipating", "TGParticipating", "MDParticipating"} do
			player:SetAttribute(flag, true)
			equipment:_refresh(record)
			local stray = tool(backpack, "M01", true)
			equipment:_refresh(record)
			check(flag .. " removes stray carried toy", toyCount(record) == 0 and stray.Parent == nil)
			check(flag .. " rejects held and remote toy use", not toys:CanHold(player) and equipment:UseToy(player).ok == false)
			player:SetAttribute(flag, false)
			equipment:_refresh(record)
			check(flag .. " lobby restores one selected toy", toyCount(record) == 1 and record.gearId == "M01")
		end
		root.Position += Vector3.new(1000, 0, 0)
		equipment:_refresh(record)
		check("leaving lobby bounds removes the held toy", toyCount(record) == 0 and not toys:CanHold(player))
		root.Position -= Vector3.new(1000, 0, 0)
		equipment:_refresh(record)
		check("reentering lobby restores exactly one toy", toyCount(record) == 1)
		equipment:_bindBackpack(record, backpack)
		player:SetAttribute("BBParticipating", true)
		local injected = tool(backpack, "M01", true)
		task.wait()
		check("backpack insertion during a round is immediately cleaned", injected.Parent == nil and toyCount(record) == 0)
		player:SetAttribute("BBParticipating", false)
		record.roundPreparing = false
		player:SetAttribute("PCToyRoundPreparing", false)
		equipment:PrepareRound({player})
		task.wait(3.1)
		check("rejected round preparation recovers lobby equipment", not record.roundPreparing and player:GetAttribute("PCToyRoundPreparing") == false and toyCount(record) == 1)
		check("fixture never started Play", not game:GetService("RunService"):IsRunning())
	end, debug.traceback)
	equipment.running = false
	for _, record in services do
		record.closed = true
		for _, list in {record.gearConnections, record.backpackConnections, record.characterConnections} do for _, connection in list do connection:Disconnect() end end
		equipment:_clearGear(record)
	end
	toys:Stop()
	fixture:Destroy()
	return { passed = ok, error = not ok and problem or nil, checks = checks, checkCount = #checks, fixtureDestroyed = fixture.Parent == nil, playStarted = false, dataStoreCalls = 0 }
end
