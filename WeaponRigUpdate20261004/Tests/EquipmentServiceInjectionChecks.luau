return function(sources)
	assert(not game:GetService("RunService"):IsRunning(), "Edit mode required")
	local storage = game:GetService("ServerStorage")
	local scripts = game:GetService("ServerScriptService")
	local fixture = Instance.new("Folder")
	fixture.Name = "_EquipmentServiceInjectionChecks"
	fixture.Parent = storage
	local report = { checks = {}, capabilities = {}, playStarted = false, realPlayersMutated = 0 }
	local function check(name, value) assert(value, name) table.insert(report.checks, name) end
	local function module(name)
		local original = scripts[name]
		local copy = original:Clone()
		copy.Source = sources and sources[name] or copy.Source
		copy.Parent = fixture
		check(name .. " retains exact live sandbox settings", copy.Capabilities == original.Capabilities and copy.Sandboxed == original.Sandboxed)
		report.capabilities[name] = tostring(copy.Capabilities)
		return require(copy)
	end
	local ok, problem = xpcall(function()
		scripts.BritishBulldogRules:Clone().Parent = fixture
		local Bulldog = module("BritishBulldogService")
		local Tag = module("TagService")
		local Equipment = module("PlaygroundEquipmentService")
		local bounds = Instance.new("Part")
		bounds.Size = Vector3.new(200, 200, 200)
		bounds.Anchored = true
		bounds.Parent = fixture
		for gameId, Service in pairs({ BritishBulldog = Bulldog, TagYoureIt = Tag }) do
			local character = storage.WeaponRigFixtures.R15:Clone()
			character.Parent = fixture
			character:PivotTo(CFrame.new(0, 5, 0))
			local attributes = { PCDataReady = true }
			local player = { Character = character, UserId = 12999 }
			function player:GetAttribute(key) return attributes[key] end
			function player:SetAttribute(key, value) attributes[key] = value end
			local record = {
				player = player, character = character, root = character.HumanoidRootPart,
				humanoid = character:FindFirstChildOfClass("Humanoid"), ready = true, isBot = true,
				participating = true, role = gameId == "BritishBulldog" and "Bulldog" or "Tagger",
			}
			local service = setmetatable({
				records = { [player] = record }, running = true, active = true,
				phase = gameId == "BritishBulldog" and "Crossing" or "Playing",
				endsAt = workspace:GetServerTimeNow() + 30, currentRound = {}, crossingNumber = 1,
				bounds = bounds, northZ = -90, southZ = 90, spawnPads = { bounds }, tagger = record,
			}, Service)
			local equipment = Equipment.new({ [gameId] = service })
			function equipment:_weaponGame() return gameId end
			local tool = Instance.new("Tool")
			tool.RequiresHandle = false
			tool:SetAttribute("BatSwingAt", 0)
			tool.Parent = character
			local equipmentRecord = { player = player, character = character, bat = tool, batGame = gameId, batConnections = {} }
			check(gameId .. " resolves exact injected service", equipment:_batService(gameId) == service)
			check(gameId .. " genuine swing accepted through Equipment capability boundary", equipment:_activateBat(equipmentRecord))
			local swing, cooldown = record.batSwing, record.batSwingReadyAt
			check(gameId .. " genuine service creates contact window and timestamp", swing and swing.hitAt < swing.endsAt and attributes.PCBatSwingSerial == 1 and attributes.PCBatSwingAt > 0)
			check(gameId .. " accepted swing starts tool animation", tool:GetAttribute("BatSwingAt") > 0)
			local timestamp = tool:GetAttribute("BatSwingAt")
			check(gameId .. " cooldown is enforced across injected call", not equipment:_activateBat(equipmentRecord) and record.batSwing == swing and tool:GetAttribute("BatSwingAt") == timestamp)
			equipment:_cancelBatHit(equipmentRecord)
			check(gameId .. " genuine cancellation clears windup and preserves cooldown", record.batSwing == nil and record.batSwingReadyAt == cooldown)
			check(gameId .. " cancellation cannot bypass cooldown", not equipment:_activateBat(equipmentRecord))
			record.batSwingReadyAt = 0
			record.frozen = true
			check(gameId .. " genuine frozen-state rejection propagates", not equipment:_activateBat(equipmentRecord) and record.batSwing == nil)
			record.frozen = false
			check(gameId .. " restored state permits a new swing", equipment:_activateBat(equipmentRecord))
			equipmentRecord.closed = true
			equipment:_clearBat(equipmentRecord)
			check(gameId .. " cleanup cancels genuine service window and destroys tool", record.batSwing == nil and equipmentRecord.bat == nil and tool.Parent == nil)
			character:Destroy()
		end
	end, debug.traceback)
	fixture:Destroy()
	report.passed = ok
	report.error = not ok and problem or nil
	report.fixtureDestroyed = fixture.Parent == nil
	return report
end
