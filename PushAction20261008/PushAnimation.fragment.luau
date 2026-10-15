local pushClips = {}
local function pushClip(classic)
	local name = classic and "R6" or "R15"
	if pushClips[name] then return pushClips[name] end
	local folder = game.ReplicatedStorage:FindFirstChild("PlaygroundPushAnimations")
	local sequence = folder and folder:FindFirstChild(name)
	if not sequence then return nil end
	local clip = {frames={}, duration=0}
	for _,key in sequence:GetKeyframes() do
		local frame = {time=key.Time,poses={}}
		for _,p in key:GetDescendants() do
			if p:IsA("Pose") then
				local joint = p:GetAttribute("JointName")
				if joint then frame.poses[joint] = {transform=p.CFrame,weight=p.Weight,basis=p:GetAttribute("SourceBasis") or CFrame.identity,additive=p:GetAttribute("Additive")==true} end
			end
		end
		table.insert(clip.frames,frame)
		clip.duration=math.max(clip.duration,key.Time)
	end
	if #clip.frames<2 then return nil end
	table.sort(clip.frames,function(a,b) return a.time<b.time end)
	pushClips[name]=clip
	return clip
end
local function animatePush(record, player, character, humanoid, now)
	if humanoid.Health<=0 or player:GetAttribute("BBRagdolled")==true or player:GetAttribute("TGRagdolled")==true
		or not (player:GetAttribute("BBParticipating")==true or player:GetAttribute("TGParticipating")==true) then return false end
	local started=character:GetAttribute("PCPushAt")
	if typeof(started)~="number" or started~=started then return false end
	local elapsed=now-started
	local clip=pushClip(humanoid.RigType==Enum.HumanoidRigType.R6)
	if not clip or elapsed<0 or elapsed>=clip.duration then return false end
	local index=2
	while index<#clip.frames and elapsed>clip.frames[index].time do index+=1 end
	local first,last=clip.frames[index-1],clip.frames[index]
	local alpha=math.clamp((elapsed-first.time)/math.max(last.time-first.time,0.001),0,1)
	alpha=alpha*alpha*(3-2*alpha)
	local joints=bodyJoints(record,character,now)
	for name,a in first.poses do
		local b,joint=last.poses[name],joints[name]
		if b and joint and joint.Parent and joint.Enabled then
			local weight=a.weight+(b.weight-a.weight)*alpha
			if weight>0 then
				local original=joint.Transform
				local previous=record.joints[joint]
				if previous and original==previous.applied then original=previous.original end
				local motion=a.transform:Lerp(b.transform,alpha)
				local rotation=a.basis*motion*a.basis:Inverse()
				local basis=joint.C0.Rotation
				local target=basis:Inverse()*rotation*basis
				if a.additive then target=original*target end
				joint.Transform=original:Lerp(target,weight)
				record.joints[joint]={original=original,applied=joint.Transform}
			end
		end
	end
	return true
end
