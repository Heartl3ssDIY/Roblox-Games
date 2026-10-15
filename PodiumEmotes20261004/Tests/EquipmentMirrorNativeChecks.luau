return function(candidateSource, originalSource)
	assert(not game:GetService("RunService"):IsRunning(), "Edit mode required")
	local storage = game:GetService("ServerStorage")
	local replicated = game:GetService("ReplicatedStorage")
	local originalModule = game:GetService("ServerScriptService").PlaygroundEquipmentService
	local fixture = Instance.new("Folder")
	fixture.Name = "_EquipmentMirrorNativeChecks"
	fixture.Parent = workspace
	local report = { checks = {}, playStarted = false, realPlayersMutated = 0 }
	local services = {}
	local function check(name, value)
		assert(value, name)
		table.insert(report.checks, name)
	end
	local function module(name, source)
		local clone = originalModule:Clone()
		clone.Name = name
		clone.Source = source
		clone.Parent = fixture
		check(name .. " preserves exact sandbox and capabilities", clone.Sandboxed == originalModule.Sandboxed and clone.Capabilities == originalModule.Capabilities)
		return require(clone)
	end
	local function recordFor(character)
		local player = { Character = character }
		function player:GetAttribute() return nil end
		function player:FindFirstChildOfClass() return nil end
		return { player = player, character = character, characterConnections = {}, gearConnections = {}, batConnections = {} }
	end
	local ok, problem = xpcall(function()
		report.capabilities = tostring(originalModule.Capabilities)
		local Equipment = module("Candidate", candidateSource)
		local OldEquipment = module("Original", originalSource)
		local catalog = require(replicated.PlaygroundCatalog)
		for _, rigName in ipairs({ "R6", "R15" }) do
			local character = storage.WeaponRigFixtures[rigName]:Clone()
			character.Name = "Mirror" .. rigName
			for _, child in ipairs(character:GetDescendants()) do
				if child:IsA("Tool") or child:IsA("LuaSourceContainer") then child:Destroy() end
			end
			character:PivotTo(CFrame.new(0, 700, 0))
			character.Parent = fixture
			local accessory = Instance.new("Accessory")
			accessory.Name = "PermissionBoundaryAccessory"
			accessory.Parent = character
			local oldService = OldEquipment.new()
			function oldService:_queue() end
			local oldRecord = recordFor(character)
			local oldOk, oldError = pcall(function() oldService:_bindCharacter(oldRecord, character) end)
			report[rigName .. "OriginalBinder"] = { passed = oldOk, error = not oldOk and tostring(oldError) or nil }
			for _, connection in ipairs(oldRecord.characterConnections) do connection:Disconnect() end
			local service = Equipment.new()
			local queued, cancelled = 0, 0
			function service:_queue() queued += 1 end
			function service:_cancelBatHit() cancelled += 1 end
			local record = recordFor(character)
			table.insert(services, { service = service, record = record })
			service:_bindCharacter(record, character)
			check(rigName .. " binds with real Accessory under unchanged sandbox", record.humanoid ~= nil)
			check(rigName .. " starts unheld with no game", character:GetAttribute("PCBatHeld") == false and character:GetAttribute("PCBatGame") == nil)
			local queuedBefore = queued
			local extraAccessory = Instance.new("Accessory")
			extraAccessory.Name = "AddedAccessory"
			extraAccessory.Parent = character
			task.wait()
			check(rigName .. " Accessory ChildAdded safely queues", queued > queuedBefore)
			queuedBefore = queued
			extraAccessory:Destroy()
			task.wait()
			check(rigName .. " Accessory ChildRemoved safely queues", queued > queuedBefore)
			local hand = character:FindFirstChild(rigName == "R6" and "Right Arm" or "RightHand")
			service:_makeBat(record, catalog.ById.B01, hand, replicated.PlaygroundCosmeticAssets.B01, "BritishBulldog")
			task.wait()
			local tool = assert(record.bat, "Native bat missing")
			check(rigName .. " authored Tool is parented to rig", tool.Parent == character)
			check(rigName .. " initial Tool parenting mirrors held state and game", character:GetAttribute("PCBatHeld") == true and character:GetAttribute("PCBatGame") == "BritishBulldog")
			local backpack = Instance.new("Backpack")
			backpack.Name = "IsolatedBackpack"
			backpack.Parent = fixture
			tool.Parent = backpack
			task.wait()
			report[rigName .. "EditUnequippedEventObserved"] = character:GetAttribute("PCBatHeld") == false
			tool.Parent = character
			service:_clearBat(record)
			check(rigName .. " explicit clear removes tool and both mirrors", record.bat == nil and tool.Parent == nil and character:GetAttribute("PCBatHeld") == false and character:GetAttribute("PCBatGame") == nil)
			service:_makeBat(record, catalog.ById.B01, hand, replicated.PlaygroundCosmeticAssets.B01, "TagYoureIt")
			task.wait()
			tool = assert(record.bat)
			tool:Destroy()
			task.wait()
			check(rigName .. " external Tool destruction clears mirrors", character:GetAttribute("PCBatHeld") == false and character:GetAttribute("PCBatGame") == nil)
			service:_clearBat(record)
			check(rigName .. " swing cancellation remains wired", cancelled >= 3)
		end
	end, debug.traceback)
	for _, item in ipairs(services) do
		for _, list in ipairs({ item.record.characterConnections, item.record.batConnections, item.record.gearConnections }) do
			for _, connection in ipairs(list) do connection:Disconnect() end
		end
	end
	fixture:Destroy()
	report.passed = ok
	report.error = not ok and tostring(problem) or nil
	report.fixtureDestroyed = fixture.Parent == nil
	return report
end
