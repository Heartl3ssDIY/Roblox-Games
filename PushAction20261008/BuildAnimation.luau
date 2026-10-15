assert(not game:GetService("RunService"):IsRunning(), "Edit only")
local storage = game:GetService("ServerStorage")
local authoring = storage.PushAnimationAuthoring20261008
assert(not authoring:FindFirstChild("Clips"), "Push clips already authored")
local folder = Instance.new("Folder")
folder.Name = "Clips"
folder.Parent = authoring
local poses = {
	{time=0, weight=0, arm=12, elbow=8, spread=7, lean=0, chest=0, neck=0, knee=0},
	{time=0.10, weight=1, arm=35, elbow=75, spread=12, lean=6, chest=4, neck=-4, knee=-8},
	{time=0.18, weight=1, arm=92, elbow=8, spread=7, lean=-10, chest=-7, neck=7, knee=-5},
	{time=0.25, weight=1, arm=94, elbow=5, spread=6, lean=-12, chest=-5, neck=7, knee=-3},
	{time=0.37, weight=1, arm=65, elbow=32, spread=9, lean=-5, chest=-2, neck=3, knee=-4},
	{time=0.48, weight=0.6, arm=28, elbow=28, spread=9, lean=2, chest=1, neck=-1, knee=-2},
	{time=0.60, weight=0, arm=12, elbow=8, spread=7, lean=0, chest=0, neck=0, knee=0},
}
local function rotation(x,y,z)
	return CFrame.fromEulerAnglesYXZ(math.rad(x),math.rad(y),math.rad(z))
end
for _,kind in {"R6","R15"} do
	local rig = authoring["PushPreview"..kind]
	local joints = {}
	for _,joint in rig:GetDescendants() do
		if joint:IsA("Motor6D") or joint:IsA("AnimationConstraint") then joints[joint.Name] = joint end
	end
	local sequence = Instance.new("KeyframeSequence")
	sequence.Name, sequence.Loop, sequence.Priority = kind, false, Enum.AnimationPriority.Action
	sequence:SetAttribute("ImpactTime",0.18)
	sequence:SetAttribute("Duration",0.6)
	sequence.Parent = folder
	for index,data in poses do
		local key = Instance.new("Keyframe")
		key.Name, key.Time = index==3 and "Impact" or "Push"..index, data.time
		key.Parent = sequence
		local transforms, additive = {}, {}
		local classic = kind=="R6"
		transforms[classic and "Right Shoulder" or "RightShoulder"] = rotation(data.arm,0,-data.spread)
		transforms[classic and "Left Shoulder" or "LeftShoulder"] = rotation(data.arm,0,data.spread)
		transforms.RightElbow,transforms.LeftElbow = rotation(data.elbow,0,0),rotation(data.elbow,0,0)
		transforms.RightWrist,transforms.LeftWrist = rotation(-8,0,-4),rotation(-8,0,4)
		transforms[classic and "RootJoint" or "Root"] = rotation(data.lean,0,0)
		transforms.Waist,transforms.Neck = rotation(data.chest,0,0),rotation(data.neck,0,0)
		transforms[classic and "Right Hip" or "RightHip"] = rotation(-data.lean-3*data.weight,0,0)
		transforms[classic and "Left Hip" or "LeftHip"] = rotation(-data.lean+3*data.weight,0,0)
		transforms.RightKnee,transforms.LeftKnee = rotation(data.knee,0,0),rotation(data.knee-2*data.weight,0,0)
		for _,name in {"Root","RootJoint","Waist","Neck","RightHip","LeftHip","Right Hip","Left Hip","RightKnee","LeftKnee"} do additive[name]=true end
		local rootPose = Instance.new("Pose")
		rootPose.Name,rootPose.Weight,rootPose.Parent = "HumanoidRootPart",0,key
		local partPoses = {HumanoidRootPart=rootPose}
		local function addPart(part)
			if partPoses[part.Name] then return partPoses[part.Name] end
			local joint
			for _,candidate in joints do if candidate.Part1==part then joint=candidate break end end
			if not joint or not joint.Part0 then return rootPose end
			local p = Instance.new("Pose")
			p.Name = part.Name
			p.Parent = addPart(joint.Part0)
			local motion = transforms[joint.Name]
			p.Weight = motion and data.weight or 0
			p.EasingStyle,p.EasingDirection = Enum.PoseEasingStyle.Cubic,Enum.PoseEasingDirection.InOut
			local basis = joint.C0.Rotation
			p.CFrame = motion and basis:Inverse()*motion*basis or CFrame.identity
			p:SetAttribute("JointName",joint.Name)
			p:SetAttribute("SourceBasis",basis)
			p:SetAttribute("Additive",additive[joint.Name]==true)
			partPoses[part.Name] = p
			return p
		end
		for _,joint in joints do if joint.Part1 then addPart(joint.Part1) end end
		if index==3 then
			local marker=Instance.new("KeyframeMarker")
			marker.Name,marker.Value,marker.Parent="PushImpact","",key
		end
	end
	local saved = Instance.new("Folder")
	saved.Name,saved.Parent="AnimSaves",rig
	local clip = sequence:Clone()
	clip.Name,clip.Parent="Push",saved
end
return {r6=#folder.R6:GetKeyframes(),r15=#folder.R15:GetKeyframes()}
