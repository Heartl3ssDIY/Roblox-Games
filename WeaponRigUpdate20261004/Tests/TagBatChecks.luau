return function(sourceText, sprintSource)
 local ServerStorage = game:GetService("ServerStorage")
 local fixture = Instance.new("Folder")
 fixture.Name = "_TagBatChecks_" .. game:GetService("HttpService"):GenerateGUID(false)
 fixture.Parent = ServerStorage
 local report = { mode = "Edit", playStarted = false, generatedAt = DateTime.now():ToIsoDate(), checks = {} }
 local services, extra = {}, {}
 local function check(name, callback)
  report.currentCheck = name
  callback()
  table.insert(report.checks, { name = name, passed = true })
 end
 local ok, failure = xpcall(function()
  local module = game:GetService("ServerScriptService").TagService:Clone()
  if sourceText then module.Source = sourceText end
  module.Parent = fixture
  local Service = require(module)
  local function makeService()
   local service = Service.new(workspace["Tag You're It"])
   service.state = Instance.new("Folder")
   service.state.Parent = fixture
   service.bounds = Instance.new("Part")
   service.bounds.Size = Vector3.new(200, 200, 200)
   service.bounds.CFrame = CFrame.new(30000, 600, 30000)
   service.bounds.Parent = fixture
   local pad = Instance.new("Part")
   pad.CFrame = service.bounds.CFrame
   pad.Parent = fixture
   service.spawnPads = { pad }
   service.taggerSpawn = pad
   service.active, service.phase, service.currentRound = true, "Playing", {}
   service.endsAt = workspace:GetServerTimeNow() + 300
   service.lastAccountAt = workspace:GetServerTimeNow()
   service.initialGraceEndsAt, service.tagCount = 0, 0
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
				role = "Runner", participating = true, ready = true, isBot = true, frozen = false,
				taggerSeconds = 0, protectedEndsAt = 0, tagCooldownEndsAt = 0, moveCooldowns = {}, nextBotMoveAt = math.huge,
				originalGroups = {}, connections = {}, characterConnections = {}, spawnIndex = 1 }
			service.records[player] = record
			return record, motors, originals
		end

  local function assertRestored(record, originals)
   assert(not record.ragdoll and record.player:GetAttribute("TGRagdolled") == false)
   assert(record.character:GetAttribute("TGRagdolled") == false)
   assert(not record.character:FindFirstChild("TGRagdollConstraints"))
   for object, original in pairs(originals) do
    if object:IsA("Motor6D") or object:IsA("AnimationConstraint") then
     assert(object.Enabled == original.Enabled, "Joint enabled state changed")
     assert(object.C0 == original.C0 and object.C1 == original.C1, "Joint offsets changed")
    elseif object:IsA("BallSocketConstraint") then
     for property, value in pairs(original) do assert(object[property] == value, "Native socket property changed: " .. property) end
    else assert(object.CanCollide == original.CanCollide, "Collision flag changed") end
   end
   for _, object in ipairs(record.character:GetDescendants()) do
    assert(object.Name ~= "TGRagdollA0" and object.Name ~= "TGRagdollA1", "Attachment leaked")
   end
  end
  local function pair(rigType)
   local service = makeService()
   local attacker = makeRig(service, "R6")
   local target, joints, originals = makeRig(service, rigType or "R6")
   service.tagger = attacker
   service:_teleport(attacker, service.bounds.CFrame)
   service:_teleport(target, service.bounds.CFrame * CFrame.new(0, 0, -2))
   service:_role(attacker, "Tagger")
   service:_role(target, "Runner")
   return service, attacker, target, joints, originals
  end
  local function hit(service, attacker, target)
   assert(service:TryBatSwing(attacker.player))
   local now = attacker.batSwing.hitAt + 0.01
   assert(service:_transfer(target, now))
   return now
  end
  check("Contact without click never transfers Tag", function()
   local service, attacker, target = pair()
   service:_tick()
   assert(service.tagger == attacker and not target.ragdoll and service.tagCount == 0)
   assert(not service:_transfer(target, workspace:GetServerTimeNow()))
  end)
  check("Click records server timestamp before serial and enforces windup, impact window and cooldown", function()
   local service, attacker, target = pair()
   assert(service:TryBatSwing(attacker.player))
   local swing = attacker.batSwing
   local timestamp = attacker.player:GetAttribute("PCBatSwingAt")
   assert(attacker.player:GetAttribute("PCBatSwingSerial") == 1)
   assert(math.abs(swing.hitAt - timestamp - 0.16) < 0.0001)
   assert(math.abs(swing.endsAt - timestamp - 0.30) < 0.0001)
   assert(math.abs(attacker.batSwingReadyAt - timestamp - 0.75) < 0.0001)
   assert(not service:TryBatSwing(attacker.player))
   assert(not service:_swingCanHit(attacker, target, timestamp + 0.159))
   assert(service:_swingCanHit(attacker, target, timestamp + 0.17))
   assert(not service:_swingCanHit(attacker, target, timestamp + 0.301))
  end)
  check("Frontal cone rejects a target behind or to the side", function()
   local service, attacker, target = pair()
   assert(service:TryBatSwing(attacker.player))
   local now = attacker.batSwing.hitAt + 0.01
   service:_teleport(target, service.bounds.CFrame * CFrame.new(0, 0, 2))
   assert(not service:_swingCanHit(attacker, target, now))
   service:_teleport(target, service.bounds.CFrame * CFrame.new(2, 0, 0))
   assert(not service:_swingCanHit(attacker, target, now))
   service:_teleport(target, service.bounds.CFrame * CFrame.new(0, 0, -2))
   assert(service:_swingCanHit(attacker, target, now))
  end)
  check("Unequip cancellation keeps cooldown and prevents a queued hit", function()
   local service, attacker, target = pair()
   assert(service:TryBatSwing(attacker.player))
   local readyAt, impactAt = attacker.batSwingReadyAt, attacker.batSwing.hitAt
   assert(service:CancelBatSwing(attacker.player))
   assert(not attacker.batSwing and attacker.batSwingReadyAt == readyAt)
   assert(not service:_transfer(target, impactAt + 0.01))
   assert(not service:TryBatSwing(attacker.player))
   assert(not service:CancelBatSwing({}))
  end)
  check("Tag transfer preserves roles, timer accounting, score and tag-back protection", function()
   local service, attacker, target, _, original = pair()
   local started = service.lastAccountAt
   local now = hit(service, attacker, target)
   assert(service.tagger == target and target.role == "Tagger" and attacker.role == "Runner")
   assert(attacker.tagsMade == 1 and service.tagCount == 1)
   assert(math.abs(attacker.taggerSeconds - (now - started)) < 0.001)
   assert(math.abs(attacker.protectedEndsAt - now - service:_setting("TagBackProtectionSeconds", 2, 0.5)) < 0.001)
   assert(math.abs(target.tagCooldownEndsAt - now - service:_setting("TagCooldownSeconds", 1.2, 0.5)) < 0.001)
   assert(attacker.player:GetAttribute("PCBatHitSerial") == 1 and not target.player:GetAttribute("PCBatHitSerial"))
   assert(target.ragdoll and target.humanoid.WalkSpeed == 0)
   assert(not service:_transfer(attacker, now + 0.02))
   assert(Service.SelectLosers(service.records, "LastTagger", target)[target])
   assert(Service.SelectLosers(service.records, "MostTaggerTime", target)[attacker])
   service:_updateRagdoll(target, now + 1.34)
   assert(target.ragdoll)
   service:_updateRagdoll(target, now + 1.351)
   assertRestored(target, original)
   assert(target.humanoid.WalkSpeed == service:_setting("TaggerWalkSpeed", 18, 0))
   assert(target.humanoid.JumpPower > 0 and not target.frozen and target.humanoid.RequiresNeck and not target.humanoid.PlatformStand)
  end)
  check("One impact selects only the nearest eligible target", function()
   local service, attacker, target = pair()
   local other = makeRig(service, "R6")
   service:_teleport(other, service.bounds.CFrame * CFrame.new(0, 0, -3))
   service:_role(other, "Runner")
   assert(service:TryBatSwing(attacker.player))
   attacker.batSwing.hitAt = 0
   service:_tick()
   assert(service.tagger == target and target.ragdoll and not other.ragdoll and service.tagCount == 1)
   service:_tick()
   assert(service.tagCount == 1)
  end)
  check("R6 and legacy R15 joints create correct limited sockets and preserve disabled joints", function()
   for _, kind in ipairs({ "R6", "R15" }) do
    local service, attacker, target, joints, originals = pair(kind)
    if kind == "R15" then joints.LeftWrist.Enabled = false originals[joints.LeftWrist].Enabled = false end
    local now = hit(service, attacker, target)
    local sockets = 0
    for _, object in ipairs(target.character.TGRagdollConstraints:GetChildren()) do
     if object:IsA("BallSocketConstraint") then sockets += 1 assert(object.LimitsEnabled and object.TwistLimitsEnabled) end
    end
    assert(sockets == (kind == "R6" and 5 or 13))
    assert((joints.RootJoint or joints.Root).Enabled and not joints.Neck.Enabled)
    assert(not target.humanoid.RequiresNeck and target.humanoid.PlatformStand and target.humanoid.Health == 100)
    service:_updateRagdoll(target, now + 2)
    assertRestored(target, originals)
   end
  end)
  check("Current native R15 AnimationConstraints use authored sockets without duplicate constraints", function()
   local service, attacker, target = pair()
   target.character:Destroy()
   local nativeFixtures = ServerStorage:FindFirstChild("WeaponRigFixtures")
   if nativeFixtures and nativeFixtures:FindFirstChild("R15") then
    target.character = nativeFixtures.R15:Clone()
   else
    local description = Instance.new("HumanoidDescription")
    description.Parent = fixture
    target.character = game:GetService("Players"):CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R15)
    description:Destroy()
   end
   target.character.Parent = fixture
   target.player.Character = target.character
   target.humanoid = target.character:FindFirstChildOfClass("Humanoid")
   target.root = target.character.HumanoidRootPart
   target.humanoid.BreakJointsOnDeath = false
   local originals, joints, originalSocketCount = {}, {}, 0
   for _, object in ipairs(target.character:GetDescendants()) do
    if object:IsA("BasePart") then originals[object] = { CanCollide = object.CanCollide }
    elseif object:IsA("AnimationConstraint") then
     joints[object.Name] = object
     originals[object] = { Enabled = object.Enabled, C0 = object.C0, C1 = object.C1 }
    elseif object:IsA("BallSocketConstraint") then
     originals[object] = {}
     for _, property in ipairs({ "Enabled", "LimitsEnabled", "TwistLimitsEnabled", "UpperAngle", "TwistLowerAngle", "TwistUpperAngle", "MaxFrictionTorque", "Restitution" }) do originals[object][property] = object[property] end
     originalSocketCount += 1
    end
   end
   assert(joints.Root and originalSocketCount == 14)
   joints.LeftWrist.Enabled = false
   originals[joints.LeftWrist].Enabled = false
   local kneeSocket = target.character.LeftLowerLeg.LeftKneeBallSocket
   kneeSocket.Enabled = false
   originals[kneeSocket].Enabled = false
   service:_teleport(target, service.bounds.CFrame * CFrame.new(0, 0, -2))
   local now = hit(service, attacker, target)
   local totalSockets = 0
   for _, object in ipairs(target.character:GetDescendants()) do if object:IsA("BallSocketConstraint") then totalSockets += 1 end end
   assert(totalSockets == originalSocketCount, "socket count " .. tostring(totalSockets))
   assert(joints.Root.Enabled, "root disabled")
   assert(not joints.Neck.Enabled, "neck not disabled")
   assert(kneeSocket.Enabled, "native knee socket not enabled")
   service:_updateRagdoll(target, now + 2)
   assertRestored(target, originals)
   report.currentR15AnimationJoints = 15
   report.currentR15AuthoredSockets = originalSocketCount
  end)
  check("All 15 bats have identical 1.35 second ragdoll with no damage", function()
   for index = 1, 15 do
    local service, attacker, target, _, originals = pair(index % 2 == 0 and "R15" or "R6")
    attacker.player:SetAttribute("PCBat", string.format("B%02d", index))
    local now = hit(service, attacker, target)
    assert(math.abs(target.ragdoll.endsAt - now - 1.35) < 0.0001 and target.humanoid.Health == 100)
    service:_updateRagdoll(target, now + 2)
    assertRestored(target, originals)
   end
   report.batsChecked = 15
  end)
  check("Range, protection, frozen state, death and field boundaries reject impact", function()
   local service, attacker, target = pair()
   local now = workspace:GetServerTimeNow()
   target.protectedEndsAt = now + 2
   assert(not service:_canTag(attacker, target, now))
   target.protectedEndsAt = 0
   target.frozen = true
   assert(not service:_canTag(attacker, target, now))
   target.frozen = false
   target.ragdoll = {}
   assert(not service:_canTag(attacker, target, now))
   target.ragdoll = nil
   service:_teleport(target, service.bounds.CFrame * CFrame.new(0, 0, -10))
   assert(not service:_canTag(attacker, target, now))
   service:_teleport(attacker, service.bounds.CFrame * CFrame.new(99, 0, 0))
   service:_teleport(target, service.bounds.CFrame * CFrame.new(99, 0, -2))
   assert(not service:_canTag(attacker, target, now))
   service:_teleport(attacker, service.bounds.CFrame)
   service:_teleport(target, service.bounds.CFrame * CFrame.new(0, 0, -2))
   target.humanoid.Health = 0
   assert(not service:_canTag(attacker, target, now))
  end)
  check("Solid obstacles block the impact ray", function()
   local service, attacker, target = pair()
   local blocker = Instance.new("Part")
   blocker.Size = Vector3.new(10, 10, 0.25)
   blocker.CFrame = service.bounds.CFrame * CFrame.new(0, 0, -1)
   blocker.Anchored = true
   blocker.Parent = workspace
   table.insert(extra, blocker)
   assert(not service:_canTag(attacker, target, workspace:GetServerTimeNow()))
   blocker:Destroy()
   assert(service:_canTag(attacker, target, workspace:GetServerTimeNow()))
  end)
  check("Inactive rounds, non-taggers, fake humans, frozen state and wrong games cannot swing", function()
   local service, attacker, target = pair()
   assert(not service:TryBatSwing(target.player))
   attacker.isBot = false
   assert(not service:TryBatSwing(attacker.player))
   attacker.isBot = true
   for _, state in ipairs({ "active", "phase", "expired", "frozen", "MDParticipating", "BBParticipating" }) do
    if state == "active" then service.active = false
    elseif state == "phase" then service.phase = "Results"
    elseif state == "expired" then service.endsAt = 0
    elseif state == "frozen" then attacker.frozen = true
    else attacker.player:SetAttribute(state, true) end
    assert(not service:TryBatSwing(attacker.player), state .. " accepted")
    service.active, service.phase, service.endsAt, attacker.frozen = true, "Playing", workspace:GetServerTimeNow() + 300, false
    attacker.player:SetAttribute("MDParticipating", false)
    attacker.player:SetAttribute("BBParticipating", false)
   end
   assert(not attacker.player:GetAttribute("PCBatSwingSerial"))
  end)
  check("Stale character and round swing windows cannot land", function()
   local service, attacker, target = pair()
   assert(service:TryBatSwing(attacker.player))
   local swing = attacker.batSwing
   swing.character = target.character
   assert(not service:_swingCanHit(attacker, target, swing.hitAt))
   swing.character = attacker.character
   swing.token = {}
   assert(not service:_swingCanHit(attacker, target, swing.hitAt))
  end)
  check("Bots request the same timed swing instead of contact tagging", function()
   local service, attacker, target = pair()
   attacker.nextBotMoveAt = 0
   service:_driveBots(workspace:GetServerTimeNow())
   assert(attacker.batSwing and attacker.player:GetAttribute("PCBatSwingSerial") == 1)
   assert(not target.ragdoll and service.tagger == attacker)
  end)
  check("Ragdoll prevents dodge, vault, new swing and sprint eligibility", function()
   local service, attacker, target = pair()
   hit(service, attacker, target)
   assert(not service:TryBatSwing(target.player))
   target.isBot = false
   assert(not service:Move(target.player, "Dodge"))
   assert(not service:Move(target.player, "Vault"))
   target.isBot = true
   local sprintModule = game:GetService("ServerScriptService").TagSprintService:Clone()
   if sprintSource then sprintModule.Source = sprintSource end
   sprintModule.Parent = fixture
   local sprint = require(sprintModule).new(service)
   assert(not sprint:_active(target.player, target))
   service:_restoreRagdoll(target, true)
   assert(sprint:_active(target.player, target))
   target.player:SetAttribute("TGRagdolled", true)
   assert(not sprint:_active(target.player, target))
   target.player:SetAttribute("TGRagdolled", false)
  end)
  check("Results freeze lets the last ragdoll finish and then restores a frozen rig", function()
   local service, attacker, target, _, originals = pair("R15")
   local now = hit(service, attacker, target)
   service.phase, target.frozen = "Results", true
   service:_movement(target)
   service:_updateRagdoll(target, now + 0.2)
   assert(target.ragdoll)
   service:_updateRagdoll(target, now + 2)
   assertRestored(target, originals)
   assert(target.frozen and target.lockedCFrame and target.humanoid.WalkSpeed == 0)
  end)
  check("Death and character removal clean ragdoll constraints", function()
   for _, mode in ipairs({ "Death", "Removal" }) do
    local service, attacker, target, _, originals = pair("R15")
    local now = hit(service, attacker, target)
    if mode == "Death" then target.humanoid.Health = 0 else target.character.Parent = nil end
    service:_updateRagdoll(target, now + 0.1)
    assertRestored(target, originals)
    target.character.Parent = fixture
   end
  end)
  check("Respawn restores old rig and rejects stale recovery on the new character", function()
   local service, attacker, target, _, originals = pair("R15")
   local oldCharacter = target.character
   local now = hit(service, attacker, target)
   local replacement = makeRig(service, "R6")
   service.records[replacement.player] = nil
   target.player.Character = replacement.character
   service:_setupCharacter(target, replacement.character)
   assert(target.character == replacement.character and not target.ragdoll)
   assertRestored({ character = oldCharacter, player = target.player }, originals)
   local cframe = target.root.CFrame
   service:_updateRagdoll(target, now + 2)
   assert(target.root.CFrame == cframe and target.character:GetAttribute("TGRagdolled") ~= true)
  end)
  check("Teleport, departure, invalid round and stop restore all transient state", function()
   for _, mode in ipairs({ "Teleport", "Departure", "Token", "Stop" }) do
    local service, attacker, target, _, originals = pair("R15")
    local originalJump = target.humanoid.JumpPower
    local now = hit(service, attacker, target)
    if mode == "Teleport" then service:_teleport(target, service.bounds.CFrame * CFrame.new(8, 0, 0))
    elseif mode == "Departure" then service:_removePlayer(target.player)
    elseif mode == "Token" then service.currentRound = {} service:_updateRagdoll(target, now + 0.1)
    else assert(service:StopRound()) end
    assertRestored(target, originals)
    assert(target.humanoid.JumpPower == originalJump and target.humanoid.RequiresNeck and not target.humanoid.PlatformStand)
   end
  end)
  check("No gameplay service was started and Play remains stopped", function()
   for _, service in ipairs(services) do assert(not service.running and #service.connections == 0) end
   assert(not game:GetService("RunService"):IsRunning())
  end)
 end, debug.traceback)
 for _, service in ipairs(services) do
  for _, record in pairs(service.records) do
   service:_restoreRagdoll(record, false)
   for _, connection in ipairs(record.characterConnections) do connection:Disconnect() end
  end
 end
 for _, object in ipairs(extra) do object:Destroy() end
 fixture:Destroy()
 report.fixtureDestroyed = fixture.Parent == nil
 report.passed = ok
 if not ok then report.error = failure else report.currentCheck = nil end
 return report
end

