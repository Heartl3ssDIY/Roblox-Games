local Equipment=assert(loadstring(assert(_G.BatPoseEquipmentSource)))()
local equipment=Equipment.new()
equipment._cancelBatHit=function()end
equipment._queue=function()end
local Catalog=require(game.ReplicatedStorage.PlaygroundCatalog)
local fixtures=assert(game.ServerStorage:FindFirstChild("WeaponRigFixtures"),"Native rigs required")
local previous=workspace:FindFirstChild("BatPosePreview20261004")if previous then previous:Destroy()end
local folder=Instance.new("Folder")folder.Name="BatPosePreview20261004"folder.Parent=workspace
local batPoses = {
	{ time = 0, r6 = Vector3.new(90, 0, -8), r15 = Vector3.new(65, 0, -8), elbow = 25, wrist = 0 },
	{ time = 0.11, r6 = Vector3.new(115, -55, -15), r15 = Vector3.new(85, -55, -15), elbow = 35, wrist = -10 },
	{ time = 0.20, r6 = Vector3.new(75, 25, -10), r15 = Vector3.new(55, 25, -10), elbow = 20, wrist = 8 },
	{ time = 0.30, r6 = Vector3.new(60, 65, -12), r15 = Vector3.new(40, 65, -12), elbow = 25, wrist = 12 },
	{ time = 0.48, r6 = Vector3.new(90, 0, -8), r15 = Vector3.new(65, 0, -8), elbow = 25, wrist = 0 },
}
local function sampleBatPose(elapsed, classic)
	local key = classic and "r6" or "r15"
	if elapsed < 0 or elapsed >= 0.48 then return batPoses[1][key], batPoses[1].elbow, 0 end
	for index = 2, #batPoses do
		local first, last = batPoses[index - 1], batPoses[index]
		if elapsed <= last.time then
			local alpha = (elapsed - first.time) / (last.time - first.time)
			alpha = alpha * alpha * (3 - 2 * alpha)
			return first[key]:Lerp(last[key], alpha), first.elbow + (last.elbow - first.elbow) * alpha, first.wrist + (last.wrist - first.wrist) * alpha
		end
	end
end

local results={}
for i,rigName in ipairs({"R6","R15"})do
	for j,itemId in ipairs({"B01","B06"})do
		for k,stage in ipairs({{name="Idle",time=0},{name="Impact",time=.20},{name="Followthrough",time=.30}})do
			local rig=fixtures[rigName]:Clone()
			rig.Name=rigName.."_"..itemId.."_"..stage.name
			for _,t in ipairs(rig:GetChildren())do if t:IsA("Tool")then t:Destroy()end end
			local oldGrip=rig:FindFirstChild("RightGrip",true)if oldGrip then oldGrip:Destroy()end
			rig.Parent=folder
			rig:PivotTo(CFrame.new((i-1)*18+(j-1)*8,900,(k-1)*-10))
			local shoulderAngles,elbowAngle,wristAngle=sampleBatPose(stage.time,rigName=="R6")
			local angles={[rigName=="R6"and"Right Shoulder"or"RightShoulder"]=shoulderAngles,RightElbow=Vector3.new(elbowAngle,0,0),RightWrist=Vector3.new(0,wristAngle,0)}
			local joints={}
			for _,part in ipairs(rig:GetDescendants())do
				if part:IsA("BasePart")then
					part.Anchored=true
					if part.Name=="Head"or part.Name:find("Hand")or part.Name=="Right Arm"or part.Name=="Left Arm"then part.Color=Color3.fromRGB(224,181,133)else part.Color=Color3.fromRGB(67,133,168)end
				elseif part:IsA("Motor6D")or part:IsA("AnimationConstraint")then
					local a,b=part:IsA("Motor6D")and part.Part0 or part.Attachment0.Parent,part:IsA("Motor6D")and part.Part1 or part.Attachment1.Parent
					local rotation=part.C0.Rotation
					local v=angles[part.Name]
					local transform=v and rotation:Inverse()*CFrame.Angles(math.rad(v.X),math.rad(v.Y),math.rad(v.Z))*rotation or CFrame.identity
					table.insert(joints,{a=a,b=b,c0=part.C0,c1=part.C1,transform=transform})
					part.Enabled=false
				elseif part:IsA("Constraint")then part.Enabled=false end
			end
			local known={[rig.HumanoidRootPart]=true}
			for pass=1,20 do for _,joint in ipairs(joints)do if known[joint.a]and not known[joint.b]then
				joint.b.CFrame=joint.a.CFrame*joint.c0*joint.transform*joint.c1:Inverse()
				known[joint.b]=true
			end end end
			local holder=Instance.new("Folder")holder.Name="WeaponPreview"holder.Parent=rig
			local backpack=Instance.new("Backpack")backpack.Parent=holder
			local player={}
			function player:FindFirstChildOfClass(class)return class=="Backpack"and backpack or nil end
			local record={player=player,character=rig,batConnections={}}
			local hand=rig:FindFirstChild("RightHand")or rig:FindFirstChild("Right Arm")
			equipment:_makeBat(record,Catalog.ById[itemId],hand,game.ReplicatedStorage.PlaygroundCosmeticAssets[itemId],"BritishBulldog")
			for _,connection in ipairs(record.batConnections)do connection:Disconnect()end
			local tool=record.bat;tool.Parent=holder;backpack:Destroy()
			local frames={}
			for _,part in ipairs(tool:GetDescendants())do
				if part:IsA("WeldConstraint")then part.Enabled=false
				elseif part:IsA("BasePart")then part.Anchored=true;frames[part]=part.CFrame
				elseif part:IsA("ParticleEmitter")or part:IsA("Trail")then part.Enabled=false end
			end
			local nativeC0=rigName=="R6"and CFrame.new(0,-1,0)*CFrame.Angles(-math.pi/2,0,0)or hand.RightGripAttachment.CFrame
			local target=hand.CFrame*nativeC0*tool.Grip:Inverse()
			local delta=target*tool.Handle.CFrame:Inverse()
			for part,cf in pairs(frames)do part.CFrame=delta*cf end
			local actual=tool.Handle.CFrame*tool.Handle.RightGripAttachment.CFrame
			local expected=hand.CFrame*nativeC0
			local tip=tool.Handle:FindFirstChild("BatEffectTip")
			local torso=rig:FindFirstChild("Torso")or rig.UpperTorso
			local tipInTorso=tip and torso.CFrame:PointToObjectSpace(tip.WorldPosition)
			table.insert(results,{name=rig.Name,gripError=(actual.Position-expected.Position).Magnitude,shaftUp=tool.Handle.CFrame.UpVector:Dot(Vector3.yAxis),tipInTorso=tipInTorso and {tipInTorso.X,tipInTorso.Y,tipInTorso.Z},hand={hand.Position.X,hand.Position.Y,hand.Position.Z}})
		end
	end
end
game.ContentProvider:PreloadAsync({folder})
_G.BatPoseResults=results
return game.HttpService:JSONEncode(results)
