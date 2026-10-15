return function(sourceText)
	local ServerStorage = game:GetService("ServerStorage")
	local fixture = Instance.new("Folder")
	fixture.Name = "_BulldogRagdollChecks_" .. game:GetService("HttpService"):GenerateGUID(false)
	fixture.Parent = ServerStorage
	local report = { mode = "Edit", playStarted = false, generatedAt = DateTime.now():ToIsoDate(), checks = {} }
	local services = {}
	local function check(name, callback)
		callback()
		table.insert(report.checks, { name = name, passed = true })
	end
	local ok, failure = xpcall(function()
		local original = game:GetService("ServerScriptService").BritishBulldogService
		local module = original:Clone()
		if sourceText then module.Source = sourceText end
		module.Parent = fixture
		local rulesModule = game:GetService("ServerScriptService").BritishBulldogRules:Clone()
		rulesModule.Parent = fixture
		local Service = require(module)
		local Rules = require(rulesModule)
		local function makeService()
			local service = Service.new(workspace["British Bulldog game"])
			service.state = Instance.new("Folder")
			service.state.Name = "FixtureState"
			service.state.Parent = fixture
			service.active = true
			service.phase = "Crossing"
			service.currentRound = {}
			service.endsAt = workspace:GetServerTimeNow() + 300
			service.lobbySpawn = nil
			table.insert(services, service)
			return service
		end
		local function makeRig(service, rigType)
			local character = Instance.new("Model")
			character.Name = "Fixture" .. rigType
			local position = service.bounds.Position
			local parts, motors, originals = {}, {}, {}
			local function part(name, offset)
				local p = Instance.new("Part")
				p.Name = name
				p.Size = Vector3.new(1, 1, 1)
				p.CFrame = CFrame.new(position + offset)
				p.CanCollide = name == "Torso" or name == "UpperTorso"
				p.Parent = character
				parts[name] = p
				originals[p] = { CanCollide = p.CanCollide }
				return p
			end
			local function motor(name, first, second)
				local m = Instance.new("Motor6D")
				m.Name = name
				m.Part0, m.Part1 = parts[first], parts[second]
				m.C0 = m.Part0.CFrame:ToObjectSpace(m.Part1.CFrame)
				m.Parent = m.Part0
				motors[name] = m
				originals[m] = { Enabled = m.Enabled, C0 = m.C0, C1 = m.C1 }
			end
			local root = part("HumanoidRootPart", Vector3.zero)
			root.Transparency = 1
			if rigType == "R6" then
				part("Torso", Vector3.zero)
				part("Head", Vector3.new(0, 1.5, 0))
				motor("RootJoint", "HumanoidRootPart", "Torso")
				motor("Neck", "Torso", "Head")
				for index, side in ipairs({ "Left", "Right" }) do
					local sign = index == 1 and -1 or 1
					part(side .. " Arm", Vector3.new(sign * 1.5, 0, 0))
					part(side .. " Leg", Vector3.new(sign * 0.5, -2, 0))
					motor(side .. " Shoulder", "Torso", side .. " Arm")
					motor(side .. " Hip", "Torso", side .. " Leg")
				end
			else
				part("LowerTorso", Vector3.zero)
				part("UpperTorso", Vector3.new(0, 0.8, 0))
				part("Head", Vector3.new(0, 2, 0))
				motor("Root", "HumanoidRootPart", "LowerTorso")
				motor("Waist", "LowerTorso", "UpperTorso")
				motor("Neck", "UpperTorso", "Head")
				for index, side in ipairs({ "Left", "Right" }) do
					local sign = index == 1 and -1 or 1
					part(side .. "UpperArm", Vector3.new(sign * 1.2, 0.8, 0))
					part(side .. "LowerArm", Vector3.new(sign * 1.2, 0, 0))
					part(side .. "Hand", Vector3.new(sign * 1.2, -0.8, 0))
					part(side .. "UpperLeg", Vector3.new(sign * 0.5, -1, 0))
					part(side .. "LowerLeg", Vector3.new(sign * 0.5, -1.8, 0))
					part(side .. "Foot", Vector3.new(sign * 0.5, -2.6, 0))
					motor(side .. "Shoulder", "UpperTorso", side .. "UpperArm")
					motor(side .. "Elbow", side .. "UpperArm", side .. "LowerArm")
					motor(side .. "Wrist", side .. "LowerArm", side .. "Hand")
					motor(side .. "Hip", "LowerTorso", side .. "UpperLeg")
					motor(side .. "Knee", side .. "UpperLeg", side .. "LowerLeg")
					motor(side .. "Ankle", side .. "LowerLeg", side .. "Foot")
				end
			end
			local humanoid = Instance.new("Humanoid")
			humanoid.RigType = rigType == "R6" and Enum.HumanoidRigType.R6 or Enum.HumanoidRigType.R15
			humanoid.BreakJointsOnDeath = false
			humanoid.Parent = character
			character.PrimaryPart = root
			character.Parent = fixture
			local attributes = {}
			local player = { Character = character, DisplayName = character.Name }
			function player:GetAttribute(name) return attributes[name] end
			function player:SetAttribute(name, value) attributes[name] = value end
			local record = { player = player, character = character, humanoid = humanoid, root = root,
				role = "Runner", participating = true, departed = true, arrived = false, frozen = false,
				originalGroups = {}, connections = {}, characterConnections = {}, spawnIndex = 1 }
			service.records[player] = record
			return record, motors, originals
		end
		local function assertRestored(record, originals)
			assert(not record.ragdoll and record.player:GetAttribute("BBRagdolled") == false)
			assert(record.character:GetAttribute("BBRagdolled") == false)
			assert(not record.character:FindFirstChild("BBRagdollConstraints"))
			for object, original in pairs(originals) do
				if object:IsA("Motor6D") then
					assert(object.Enabled == original.Enabled, "Motor enabled state not restored")
					assert(object.C0 == original.C0 and object.C1 == original.C1, "Authored motor offsets changed")
				else assert(object.CanCollide == original.CanCollide, "Collision flag not restored") end
			end
			for _, object in ipairs(record.character:GetDescendants()) do
				assert(object.Name ~= "BBRagdollA0" and object.Name ~= "BBRagdollA1", "Attachment leaked")
			end
		end
		local service = makeService()
		local attacker = makeRig(service, "R6")
		attacker.role = "Bulldog"
		attacker.root.CFrame += Vector3.new(0, 0, 2)
		local now = workspace:GetServerTimeNow()
		local r6, r6Motors, r6Original = makeRig(service, "R6")
		check("R6 contact tag creates five limited sockets and keeps its root motor connected", function()
			assert(service:_caught(r6, "Tagged", now, attacker))
			assert(r6.role == "Tagged" and r6.frozen and r6.ragdoll)
			assert(r6.player:GetAttribute("BBRagdolled") == true and r6.character:GetAttribute("BBRagdolled") == true)
			local sockets = 0
			for _, object in ipairs(r6.character.BBRagdollConstraints:GetChildren()) do
				if object:IsA("BallSocketConstraint") then
					sockets += 1
					assert(object.LimitsEnabled and object.TwistLimitsEnabled and object.Attachment0 and object.Attachment1)
				end
			end
			assert(sockets == 5 and r6Motors.RootJoint.Enabled and not r6Motors.Neck.Enabled)
			assert(not r6.humanoid.RequiresNeck and r6.humanoid.PlatformStand and r6.humanoid.Health == 100)
			assert(attacker.player:GetAttribute("BBBatHitSerial") == 1)
		end)
		check("Timer preserves the full ragdoll duration then restores a tagged freeze", function()
			service:_updateRagdoll(r6, now + 1.34)
			assert(r6.ragdoll)
			service:_updateRagdoll(r6, now + 1.351)
			assertRestored(r6, r6Original)
			assert(r6.frozen and r6.lockedCFrame and r6.role == "Tagged")
			assert(r6.humanoid.RequiresNeck and not r6.humanoid.PlatformStand and r6.humanoid.JumpPower == 0)
		end)
		check("Repeated tags do not restart ragdoll or increment hit VFX", function()
			assert(service:_caught(r6, "Tagged", now + 2, attacker) == false)
			assert(attacker.player:GetAttribute("BBBatHitSerial") == 1)
		end)
		local r15, r15Motors, r15Original = makeRig(service, "R15")
		r15Motors.LeftWrist.Enabled = false
		r15Original[r15Motors.LeftWrist].Enabled = false
		check("R15 uses its real joints and preserves previously disabled motors", function()
			assert(service:_caught(r15, "Tagged", now, attacker))
			local sockets = 0
			for _, object in ipairs(r15.character.BBRagdollConstraints:GetChildren()) do if object:IsA("BallSocketConstraint") then sockets += 1 end end
			assert(sockets == 13 and r15Motors.Root.Enabled and not r15Motors.Waist.Enabled)
			service:_updateRagdoll(r15, now + 2)
			assertRestored(r15, r15Original)
		end)
		check("Every imported bat has identical ragdoll duration and no damage", function()
			for index = 1, 15 do
				local victim, _, originalStates = makeRig(service, index % 2 == 0 and "R15" or "R6")
				attacker.player:SetAttribute("PCBat", string.format("B%02d", index))
				assert(service:_caught(victim, "Tagged", now, attacker))
				assert(math.abs(victim.ragdoll.endsAt - now - 1.35) < 0.0001)
				assert(victim.humanoid.Health == 100)
				service:_updateRagdoll(victim, now + 2)
				assertRestored(victim, originalStates)
				service:_removePlayer(victim.player)
				victim.character:Destroy()
			end
			report.batsChecked = 15
		end)
		check("Crossing conversion preserves ragdoll then releases the new Bulldog", function()
			local victim, _, originalStates = makeRig(service, "R6")
			service:_caught(victim, "Tagged", now, attacker)
			service:_finishCrossing()
			assert(victim.role == "Bulldog" and victim.ragdoll and victim.ragdoll.freezeAfter == false)
			service:_updateRagdoll(victim, now + 2)
			assertRestored(victim, originalStates)
			assert(not victim.frozen and victim.role == "Bulldog")
		end)
		check("Results freeze allows a final hit to finish visibly", function()
			local victim, _, originalStates = makeRig(service, "R15")
			service:_caught(victim, "Tagged", now, attacker)
			service.phase = "Results"
			service:_freeze(victim)
			service:_updateRagdoll(victim, now + 0.2)
			assert(victim.ragdoll)
			service:_updateRagdoll(victim, now + 2)
			assertRestored(victim, originalStates)
			assert(victim.frozen)
			service.phase = "Crossing"
		end)
		check("Reset or elimination without bat contact does not trigger ragdoll", function()
			local victim = makeRig(service, "R6")
			local serial = attacker.player:GetAttribute("BBBatHitSerial")
			assert(service:_caught(victim, "Reset or eliminated", now))
			assert(victim.frozen and not victim.ragdoll and attacker.player:GetAttribute("BBBatHitSerial") == serial)
		end)
		check("Death and character removal clean transient constraints", function()
			for _, mode in ipairs({ "Death", "Removal" }) do
				local victim, _, originalStates = makeRig(service, "R15")
				service:_caught(victim, "Tagged", now, attacker)
				if mode == "Death" then victim.humanoid.Health = 0 else victim.character.Parent = nil end
				service:_updateRagdoll(victim, now + 0.1)
				assertRestored(victim, originalStates)
				victim.character.Parent = fixture
			end
		end)
		check("Respawn restores the old rig and never applies stale recovery to the new one", function()
			local victim, _, originalStates = makeRig(service, "R15")
			local oldCharacter = victim.character
			service:_caught(victim, "Tagged", now, attacker)
			local replacement = makeRig(service, "R6")
			service.records[replacement.player] = nil
			victim.player.Character = replacement.character
			service:_setupCharacter(victim, replacement.character)
			assert(victim.character == replacement.character and not victim.ragdoll)
			assertRestored({ character = oldCharacter, player = victim.player }, originalStates)
			local newRootFrame = victim.root.CFrame
			service:_updateRagdoll(victim, now + 2)
			assert(victim.root.CFrame == newRootFrame and victim.character:GetAttribute("BBRagdolled") ~= true)
		end)
		check("Teleport removes the old ragdoll before moving the character", function()
			local victim, _, originalStates = makeRig(service, "R6")
			service:_caught(victim, "Tagged", now, attacker)
			local destination = CFrame.new(service.bounds.Position + Vector3.new(8, 0, 0))
			service:_teleport(victim, destination)
			assertRestored(victim, originalStates)
			assert((victim.root.Position - destination.Position).Magnitude < 0.01)
		end)
		check("Expired and inactive rounds reject tags without a VFX event", function()
			local victim = makeRig(service, "R6")
			local serial = attacker.player:GetAttribute("BBBatHitSerial")
			service.endsAt = now - 1
			assert(service:_caught(victim, "Tagged", now, attacker) == false)
			service.endsAt = now + 300
			service.active = false
			assert(service:_caught(victim, "Tagged", now, attacker) == false)
			service.active = true
			assert(not victim.ragdoll and attacker.player:GetAttribute("BBBatHitSerial") == serial)
		end)
		check("Safe zones, arrival, departure and frozen attacker tag rules remain enforced", function()
			assert(Rules.CanTag("Crossing", "Runner", true, false, true, false))
			assert(not Rules.CanTag("Crossing", "Runner", true, false, false, false))
			assert(not Rules.CanTag("Crossing", "Runner", true, true, true, false))
			assert(not Rules.CanTag("Crossing", "Runner", false, false, true, false))
			assert(not Rules.CanTag("Crossing", "Runner", true, false, true, true))
			assert(not Rules.CanTag("Countdown", "Runner", true, false, true, false))
		end)
		check("Round stop restores joints, jump settings and all transient state", function()
			local victim, _, originalStates = makeRig(service, "R15")
			local originalJumpPower = victim.humanoid.JumpPower
			service:_caught(victim, "Tagged", now, attacker)
			assert(service:StopRound())
			assertRestored(victim, originalStates)
			assert(not victim.participating and victim.role == "Spectator" and not victim.frozen)
			assert(victim.humanoid.JumpPower == originalJumpPower and victim.humanoid.RequiresNeck and not victim.humanoid.PlatformStand)
		end)
		check("Service was never started and Play remains stopped", function()
			assert(not service.running and #service.connections == 0 and not game:GetService("RunService"):IsRunning())
		end)
	end, debug.traceback)
	for _, service in ipairs(services) do
		for _, record in pairs(service.records) do
			service:_restoreRagdoll(record, false)
		end
	end
	fixture:Destroy()
	report.fixtureDestroyed = fixture.Parent == nil
	report.passed = ok
	if not ok then report.error = failure end
	return report
end
