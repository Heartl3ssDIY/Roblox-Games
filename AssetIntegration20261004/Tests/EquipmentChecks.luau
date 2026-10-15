local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local source = assert(game:GetService("ServerScriptService"):FindFirstChild("PlaygroundEquipmentService"), "Equipment module missing")
local fixture = Instance.new("Folder")
fixture.Name = "_EquipmentChecks_" .. game:GetService("HttpService"):GenerateGUID(false)
fixture.Parent = ServerStorage
local report = { generatedAt = DateTime.now():ToIsoDate(), mode = "Edit", playStarted = false, checks = {} }
local service, record

local function check(name, callback)
	callback()
	table.insert(report.checks, { name = name, passed = true })
end

local success, problem = xpcall(function()
	local module = source:Clone()
	module.Name = "EquipmentUnderTest"
	module.Parent = fixture
	local Equipment = require(module)
	local Catalog = require(ReplicatedStorage:FindFirstChild("PlaygroundCatalog"))
	local assets = assert(ReplicatedStorage:FindFirstChild("PlaygroundCosmeticAssets"))
	service = Equipment.new()
	local character = Instance.new("Model")
	character.Name = "FixtureCharacter"
	character.Parent = fixture
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = character
	local hand = Instance.new("Part")
	hand.Name = "RightHand"
	hand.Size = Vector3.new(1, 1, 1)
	hand.CFrame = CFrame.new(40, 10, 30)
	hand.Anchored = true
	hand.Parent = character
	local grip = Instance.new("Attachment")
	grip.Name = "RightGripAttachment"
	grip.Position = Vector3.new(0, -0.3, 0)
	grip.Parent = hand
	local backpack = Instance.new("Backpack")
	backpack.Parent = fixture
	local attributes = { PCDataReady = false, PCBat = "B01", PCGear = "M05" }
	local player = { Character = character }
	function player:GetAttribute(name) return attributes[name] end
	function player:FindFirstChildOfClass(className) return className == "Backpack" and backpack or nil end
	record = { player = player, character = character, connections = {}, characterConnections = {}, gearConnections = {}, closed = false }
	local function refresh() service:_refresh(record) end
	local function assertSafeParts(container)
		local count = 0
		for _, part in container:GetDescendants() do
			if part:IsA("BasePart") then
				count += 1
				assert(not part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery, "Unsafe cosmetic part " .. part.Name)
				assert(part.Massless, "Cosmetic part is not massless")
			end
		end
		assert(count > 1, "Expected a handle plus visible geometry")
	end

	check("No equipment before player data is ready", function()
		refresh()
		assert(not record.bat and not record.gear)
	end)
	check("Lobby creates a harmless collectible tool", function()
		attributes.PCDataReady = true
		refresh()
		assert(not record.bat and record.gear and record.gear.Parent == backpack)
		assert(record.gear:IsA("Tool") and not record.gear.Enabled and not record.gear.CanBeDropped)
		assert(record.gear:GetAttribute("CosmeticOnly") == true and record.gear:GetAttribute("CatalogId") == "M05")
		assertSafeParts(record.gear)
	end)
	check("Every imported miscellaneous asset equips and replaces its previous tool", function()
		local count = 0
		for index = 1, 15 do
			local id = string.format("M%02d", index)
			assert(Catalog.ById[id] and assets:FindFirstChild(id), "Missing misc asset " .. id)
			local old = record.gear
			local oldId = record.gearId
			attributes.PCGear = id
			refresh()
			assert(record.gearId == id and record.gear and record.gear.Parent == backpack)
			if old and oldId ~= id then assert(old.Parent == nil, "Old tool leaked") end
			assertSafeParts(record.gear)
			count += 1
		end
		report.miscAssetsChecked = count
	end)
	check("Mud rounds remove cosmetic toys", function()
		attributes.MDParticipating = true
		refresh()
		assert(not record.gear and not record.bat and #backpack:GetChildren() == 0)
	end)
	check("Only the Bulldog receives its selected bat", function()
		attributes.MDParticipating = false
		attributes.BBParticipating = true
		attributes.BBRole = "Bulldog"
		refresh()
		assert(record.bat and record.bat.Parent == character and record.batId == "B01")
		assert(not record.gear)
		local anchor = assert(record.bat:FindFirstChild("GripAnchor"))
		local weld = assert(anchor:FindFirstChild("RightHandGrip"))
		assert(weld.Part0 == hand and weld.Part1 == anchor)
		assertSafeParts(record.bat)
	end)
	check("Every imported bat equips without retaining the previous bat", function()
		local count = 0
		for index = 1, 15 do
			local id = string.format("B%02d", index)
			assert(Catalog.ById[id] and assets:FindFirstChild(id), "Missing bat asset " .. id)
			local old = record.bat
			local oldId = record.batId
			attributes.PCBat = id
			refresh()
			assert(record.batId == id and record.bat and record.bat.Parent == character)
			if old and oldId ~= id then assert(old.Parent == nil, "Old bat leaked") end
			assertSafeParts(record.bat)
			count += 1
		end
		report.batAssetsChecked = count
	end)
	check("Runner role removes bat without granting a lobby toy", function()
		attributes.BBRole = "Runner"
		refresh()
		assert(not record.bat and not record.gear)
	end)
	check("Tag participation keeps miscellaneous toys out of rounds", function()
		attributes.BBParticipating = false
		attributes.TGParticipating = true
		refresh()
		assert(not record.bat and not record.gear)
	end)
	check("Returning to lobby restores the selected toy", function()
		attributes.TGParticipating = false
		refresh()
		assert(record.gear and record.gearId == "M15" and not record.bat)
	end)
	check("Wrong-slot and missing IDs do not create equipment", function()
		attributes.PCGear = "P01"
		attributes.BBParticipating = true
		attributes.BBRole = "Bulldog"
		attributes.PCBat = "P01"
		refresh()
		assert(not record.bat and not record.gear)
		attributes.PCBat = "missing"
		refresh()
		assert(not record.bat)
	end)
	check("Missing hand removes bat safely", function()
		attributes.PCBat = "B01"
		hand.Parent = fixture
		refresh()
		assert(not record.bat)
		hand.Parent = character
		refresh()
		assert(record.bat)
	end)
	check("Dead characters have no equipped cosmetics", function()
		humanoid.Health = 0
		refresh()
		assert(not record.bat and not record.gear)
	end)
	check("Character replacement clears the previous character equipment", function()
		humanoid.Health = 100
		attributes.BBParticipating = false
		attributes.PCGear = "M05"
		refresh()
		assert(record.gear)
		local replacement = Instance.new("Model")
		replacement.Parent = fixture
		player.Character = replacement
		refresh()
		assert(not record.bat and not record.gear)
		player.Character = character
	end)
	check("Data readiness loss clears gear and its listeners", function()
		refresh()
		assert(record.gear)
		local listeners = table.clone(record.gearConnections)
		attributes.PCDataReady = false
		refresh()
		assert(not record.gear and not record.bat and #record.gearConnections == 0)
		for _, listener in listeners do assert(not listener.Connected) end
	end)
	check("Equipment service remains stopped throughout fixtures", function()
		assert(not service.running and #service.connections == 0)
	end)
end, debug.traceback)

if service and record then
	service:_clearBat(record)
	service:_clearGear(record)
end
fixture:Destroy()
report.fixtureDestroyed = fixture.Parent == nil
report.passed = success
if not success then report.error = problem end
return report
