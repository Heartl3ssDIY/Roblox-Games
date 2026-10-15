return function(equipmentSource, animationSource)
	assert(not game:GetService("RunService"):IsRunning(), "Edit mode required")
	local replicated = game:GetService("ReplicatedStorage")
	local storage = game:GetService("ServerStorage")
	local fixture = Instance.new("Folder")
	fixture.Name = "_BatRigChecks"
	fixture.Parent = workspace
	local report = { playStarted = false, checks = {}, grips = {}, testedBats = 0 }
	local function check(name, callback) callback() table.insert(report.checks, name) end
	local ok, problem = xpcall(function()
		local equipmentModule = game.ServerScriptService.PlaygroundEquipmentService:Clone()
		equipmentModule.Source = equipmentSource or equipmentModule.Source
		equipmentModule.Parent = fixture
		local Equipment = require(equipmentModule)
		local poses = Instance.new("ModuleScript")
		poses.Name = "PoseFunctions"
		local animationSandbox = game.StarterPlayer.StarterPlayerScripts.PlaygroundEmotes:Clone()
		animationSandbox.Enabled = false
		animationSandbox.Parent = fixture
		local text = animationSource or game.StarterPlayer.StarterPlayerScripts.PlaygroundEmotes.Source
		poses.Source = assert(text:match("^(.-)local beforeAnimation =")) .. "\nreturn { sample = sampleBatPose, apply = weaponJoint, animate = animateBat, restore = restore }"
		poses.Parent = animationSandbox
		local Pose = require(poses)
		local Catalog = require(replicated.PlaygroundCatalog)
		local savedRigs = assert(storage:FindFirstChild("WeaponRigFixtures"), "Native rigs required")
		for _, rigName in ipairs({ "R6", "R15" }) do
			local character = savedRigs[rigName]:Clone()
			character.Name = "BatCheck" .. rigName
			for _, child in ipairs(character:GetDescendants()) do if child:IsA("Tool") or child:IsA("LuaSourceContainer") then child:Destroy() end end
			character.Parent = fixture
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local hand = character:FindFirstChild(rigName == "R6" and "Right Arm" or "RightHand")
			local attributes = { PCDataReady = true, BBParticipating = true, BBRole = "Bulldog" }
			local player = { Character = character }
			function player:GetAttribute(name) return attributes[name] end
			function player:FindFirstChildOfClass() return nil end
			local record = { player = player, character = character, connections = {}, characterConnections = {}, gearConnections = {}, batConnections = {} }
			local service = Equipment.new()
			local canceled, accepted, requests = 0, true, 0
			function service:_batService() return { CancelBatSwing = function() canceled += 1 end, TryBatSwing = function() requests += 1 return accepted end } end
			function service:_weaponGame(p)
				if p:GetAttribute("MDParticipating") then return nil end
				if attributes.BBParticipating and attributes.BBRole == "Bulldog" then return "BritishBulldog" end
				if attributes.TGParticipating and attributes.TGRole == "Tagger" then return "TagYoureIt" end
			end
			for index = 1, 15 do
				local id = string.format("B%02d", index)
				attributes.PCBat = id
				service:_refresh(record)
				local tool = assert(record.bat, "Missing " .. id)
				assert(tool:IsA("Tool") and tool.RequiresHandle and not tool.ManualActivationOnly and not tool.CanBeDropped)
				assert(tool:GetAttribute("PCBatWeapon") == true and tool.Parent == character)
				assert(tool.Handle.RightGripAttachment.CFrame == tool.Grip and tool.Grip == CFrame.identity)
				assert(tool:FindFirstChild("HeldVFX") and tool.Visual:FindFirstChildWhichIsA("Highlight", true))
				local joint
				local deadline = os.clock() + 1
				repeat
					task.wait(0.025)
					for _, gripJoint in ipairs(hand:GetChildren()) do
						if gripJoint.Name == "RightGrip" and gripJoint:IsA("JointInstance") and gripJoint.Part1 == tool.Handle then joint = gripJoint break end
					end
				until joint or os.clock() > deadline
				assert(joint and joint.Part0 == hand and joint.Part1 == tool.Handle, "Native palm joint missing " .. rigName .. id)
				local shoulder = character:FindFirstChild(rigName == "R6" and "Right Shoulder" or "RightShoulder", true)
				local expectedPalm = hand:FindFirstChild("RightGripAttachment")
				local expectedC0 = expectedPalm and expectedPalm.CFrame or CFrame.new(0, -1, 0) * CFrame.Angles(-math.pi / 2, 0, 0)
				assert((joint.C0.Position - expectedC0.Position).Magnitude < 0.001)
				assert(joint.C1 == tool.Grip)
				local low = math.huge
				for _, part in ipairs(tool.Visual:GetDescendants()) do if part:IsA("BasePart") and part:GetAttribute("PCStudLayer") ~= true then low = math.min(low, part.Size.Y) end end
				assert(low < math.huge)
				report.testedBats += 1
			end
			check(rigName .. " all15 bats have native hand grips, matching attachments and retained VFX", function() assert(record.bat) end)
			check(rigName .. " click delegates once and rejected swings do not animate", function()
				local before = record.bat:GetAttribute("BatSwingAt")
				accepted = false
				assert(not service:_activateBat(record) and record.bat:GetAttribute("BatSwingAt") == before)
				accepted = true
				assert(service:_activateBat(record) and record.bat:GetAttribute("BatSwingAt") > 0)
				assert(requests == 2)
			end)
			check(rigName .. " pose changes upper body and restores exact original joint transforms", function()
				local poseRecord = { joints = {}, weapon = record.bat, weaponAt = 0 }
				local shoulder = character:FindFirstChild(rigName == "R6" and "Right Shoulder" or "RightShoulder", true)
				local original = shoulder.Transform
				local angle = Pose.sample(0.16, rigName == "R6")
				Pose.apply(poseRecord, shoulder, angle, 1)
				assert(shoulder.Transform ~= original)
				Pose.restore(poseRecord)
				assert(shoulder.Transform == original)
				for _, time in ipairs({ 0, 0.11, 0.16, 0.20, 0.30, 0.48, 0.8 }) do
					local angles, elbow, wrist = Pose.sample(time, rigName == "R6")
					assert(angles.X == angles.X and elbow == elbow and wrist == wrist)
				end
			end)
			check(rigName .. " lobby admin preview cannot equip a bat", function()
				attributes.BBParticipating = false attributes.PCAdminBatPreview = true
				service:_refresh(record)
				assert(record.bat == nil)
			end)
			check(rigName .. " Tagger gets bat, Runner and Mud never do", function()
				attributes.TGParticipating = true attributes.TGRole = "Tagger"
				service:_refresh(record)
				assert(record.bat and record.batGame == "TagYoureIt")
				attributes.TGRole = "Runner" service:_refresh(record) assert(not record.bat)
				attributes.TGRole = "Tagger" attributes.MDParticipating = true service:_refresh(record) assert(not record.bat)
				attributes.MDParticipating = nil attributes.TGRagdolled = true service:_refresh(record) assert(not record.bat)
				attributes.TGRagdolled = false service:_refresh(record) assert(record.bat)
			end)
			check(rigName .. " death and cleanup cancel pending hits and destroy tools", function()
				humanoid.Health = 0 service:_refresh(record)
				assert(not record.bat and canceled > 0)
				record.closed = true
				service:_clearBat(record)
			end)
		end
	end, debug.traceback)
	fixture:Destroy()
	report.passed = ok
	report.error = not ok and problem or nil
	report.fixtureDestroyed = fixture.Parent == nil
	return report
end
