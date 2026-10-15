local folder = Instance.new("Folder")
folder.Name = "BatMotionChecks20261004"
folder.Parent = game.ServerStorage
local checks = {}
local function closeFrame(a,b)
	return (a.Position-b.Position).Magnitude < 0.00001 and a.LookVector:Dot(b.LookVector) > 0.999999 and a.UpVector:Dot(b.UpVector) > 0.999999
end
local function check(value, message)
	assert(value, message)
	table.insert(checks, message)
end
local ok, result = xpcall(function()
	local live = game.StarterPlayer.StarterPlayerScripts.PlaygroundEmotes
	local module = Instance.new("ModuleScript")
	module.Name = "ExactCapabilityMotion"
	module.Capabilities = live.Capabilities
	module.Sandboxed = live.Sandboxed
	module.Source = assert(_G.BatMotionCandidate):match("^(.-)local beforeAnimation =")
		.. "\nreturn {sample=sampleBatPose,apply=applyBatPose,animate=animateBat,restore=restore,collect=collectJoints,pose=pose}"
	module.Parent = folder
	local animation = require(module)
	check(not tostring(module.Capabilities):find("Input"), "No Input capability added")
	check(module.Capabilities == live.Capabilities and module.Sandboxed == live.Sandboxed, "Exact live approved sandbox and capabilities")
	local fixtures = assert(game.ServerStorage:FindFirstChild("WeaponRigFixtures"))
	for _, rigName in ipairs({"R6", "R15"}) do
		local rig = fixtures[rigName]:Clone()
		rig.Name = rigName
		rig.Parent = folder
		local human = rig:FindFirstChildOfClass("Humanoid")
		local joints = animation.collect(rig)
		local originals, cframes = {}, {}
		for name, joint in pairs(joints) do
			originals[joint] = CFrame.Angles(0.015, -0.025, 0.01)
			joint.Transform = originals[joint]
			originals[joint] = joint.Transform
			cframes[joint] = {joint.C0, joint.C1}
		end
		local tool = Instance.new("Tool")
		tool.Name = "ProtectedEquippedBat"
		tool.Grip = CFrame.new(0.1,0.2,0.3) * CFrame.Angles(0.1,0.2,0.3)
		tool:SetAttribute("BatSwingAt", -1000)
		tool.Parent = rig
		local accessory = Instance.new("Accessory")
		accessory.Name = "ProtectedAccessory"
		accessory.Parent = rig
		local grip = tool.Grip
		rig:SetAttribute("PCBatHeld", true)
		rig:SetAttribute("PCBatGame", "BritishBulldog")
		local attrs = {BBParticipating=true, PCBatSwingAt=100, PCBatSwingSerial=1}
		local player = {}
		function player:GetAttribute(name) return attrs[name] end
		local record = {joints={}, bodyJoints=joints, weapon="BritishBulldog",weaponAt=99}
		check(animation.animate(record,player,rig,human,100.22),rigName .. " player timestamp drives held bat without Tool access")
		local right = joints[rigName=="R6" and "Right Shoulder" or "RightShoulder"]
		local left = joints[rigName=="R6" and "Left Shoulder" or "LeftShoulder"]
		local root = joints.RootJoint or joints.Root
		local hip = joints[rigName=="R6" and "Left Hip" or "LeftHip"]
		check(right.Transform ~= originals[right] and left.Transform ~= originals[left],rigName .. " striking and guide arms move")
		check(root.Transform ~= originals[root] and hip.Transform ~= originals[hip],rigName .. " torso coil and planted hip counter rotation")
		if rigName=="R15" then
			check(joints.Waist:IsA("AnimationConstraint") and joints.Waist.Transform ~= originals[joints.Waist], "Native R15 animation joints and waist supported")
		end
		local first = right.Transform
		animation.animate(record,player,rig,human,100.22)
		check((right.Transform.Position-first.Position).Magnitude<0.00001 and right.Transform.LookVector:Dot(first.LookVector)>0.999999,rigName .. " repeated pose does not accumulate")
		animation.restore(record)
		local restored = true
		local intact = true
		for joint, original in pairs(originals) do
			restored = restored and closeFrame(joint.Transform,original)
			intact = intact and joint.C0 == cframes[joint][1] and joint.C1 == cframes[joint][2]
		end
		check(restored,rigName .. " original Animator transforms restored within native float precision")
		check(intact and tool.Grip==grip,rigName .. " native joint frames and authored weapon grip untouched")
		animation.animate(record,player,rig,human,100.22)
		local external = CFrame.Angles(0.4,0.3,0.2)
		right.Transform = external
		animation.restore(record)
		check(closeFrame(right.Transform,external),rigName .. " external animation change preserved on cleanup")
		for _, blocked in ipairs({"BBRagdolled","TGRagdolled","MDParticipating"}) do
			attrs[blocked]=true
			check(not animation.animate(record,player,rig,human,100.22),rigName .. " blocks " .. blocked)
			attrs[blocked]=nil
		end
		rig:SetAttribute("PCBatHeld",false)
		check(not animation.animate(record,player,rig,human,100.22),rigName .. " stops immediately when bat is unequipped")
		rig:SetAttribute("PCBatHeld",true)
		rig:SetAttribute("PCBatGame","OtherGame")
		check(not animation.animate(record,player,rig,human,100.22),rigName .. " rejects inactive game")
		rig:SetAttribute("PCBatGame","TagYoureIt")
		attrs.BBParticipating=nil
		attrs.TGParticipating=true
		attrs.TGRole="Runner"
		record.weapon="TagYoureIt"
		record.weaponAt=99
		check(animation.animate(record,player,rig,human,100.30),rigName .. " departing Tagger finishes authorized held-bat follow-through")
		animation.restore(record)
		local leftParent = left.Parent
		left.Parent = folder
		local late = {joints={}, weapon="TagYoureIt", weaponAt=99}
		check(animation.animate(late,player,rig,human,100.22),rigName .. " incomplete character safely animates available joints")
		check(late.bodyJoints[left.Name]==nil,rigName .. " absent joint is not fabricated")
		animation.restore(late)
		left.Parent = leftParent
		attrs.PCBatSwingAt=100.6
		check(animation.animate(late,player,rig,human,100.82) and late.bodyJoints[left.Name]==left and late.joints[left]~=nil,
			rigName .. " late replicated joint joins animation without re-equipping")
		animation.restore(late)
		human.Health=0
		check(not animation.animate(record,player,rig,human,100.22),rigName .. " dead humanoid cannot pose")
	end
	for _, classic in ipairs({true,false}) do
		local idle = animation.sample(0,classic)
		local settled = animation.sample(0.48,classic)
		check(idle.shoulder==settled.shoulder and settled.guideWeight==0 and settled.bodyWeight==0, "Full recovery at 0.48 seconds")
		for _, time in ipairs({0.105,0.15,0.22,0.30,0.365,0.48}) do
			local left = animation.sample(time-0.00001,classic)
			local right = animation.sample(time+0.00001,classic)
			check((left.shoulder-right.shoulder).Magnitude<0.08, "Continuous shoulder through " .. tostring(time))
		end
		local coil, contact, follow = animation.sample(0.105,classic),animation.sample(0.22,classic),animation.sample(0.30,classic)
		check(coil.root.Y < -10 and coil.shoulder.X > (classic and 100 or 80) and contact.shoulder.Y > 0 and follow.shoulder.Y > 70, "Coil crosses target into clear follow-through")
		check(contact.guideWeight>0.8 and contact.bodyWeight>0.99, "Contact uses whole body and guide hand inside confirmed hit window")
		for time=0,0.5,0.001 do
			local p=animation.sample(time,classic)
			assert(p.shoulder.Magnitude==p.shoulder.Magnitude and p.shoulder.Magnitude<200,"Nonfinite or unstable pose")
			assert(p.guideWeight>=0 and p.guideWeight<=1 and p.bodyWeight>=0 and p.bodyWeight<=1,"Invalid blended weight")
		end
	end
	check(not assert(_G.BatMotionCandidate):find('IsA("Tool")',1,true), "Source has no Tool introspection")
	return {passed=#checks,checks=checks,capabilities=tostring(module.Capabilities),playStarted=false}
end,debug.traceback)
folder:Destroy()
_G.BatMotionCandidate=nil
if not ok then error(result) end
return game.HttpService:JSONEncode(result)


