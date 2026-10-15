local passed = 0
local function check(value, message)
	assert(value,message)
	passed += 1
end
local vectorMeta = {}
vectorMeta.__index = function(v,key)
	if key=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end
end
local Vector3 = {}
function Vector3.new(x,y,z) return setmetatable({X=x,Y=y,Z=z},vectorMeta) end
vectorMeta.__add=function(a,b)return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
vectorMeta.__sub=function(a,b)return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
vectorMeta.__mul=function(a,b)
	if type(a)=="number" then a,b=b,a end
	return Vector3.new(a.X*b,a.Y*b,a.Z*b)
end
Vector3.zero=Vector3.new(0,0,0)
local function vector(x,y,z)return Vector3.new(x,y,z)end
local Enum={HumanoidRigType={R6="R6",R15="R15"}}
local function bodyJoints(record) return record.bodyJoints end
local function weaponJoint(record,joint,angles,weight,additive)
	if not joint or not joint.Parent or not joint.Enabled or weight<=0 then return end
	record.calls[joint.Name]={angles=angles,weight=weight,additive=additive==true}
end
local toyActions = {
	M01 = { action = "Kick", duration = 1.10, placeAt = 0.24, contactAt = 0.60 },
	M02 = { action = "Lob", duration = 0.85, contactAt = 0.34 },
	M03 = { action = "Bonk", duration = 0.58, contactAt = 0.23 },
	M04 = { action = "BarrelThrow", duration = 1.10, contactAt = 0.52 },
	M05 = { action = "Drink", duration = 1.30, contactAt = 0.82 },
	M06 = { action = "Drink", duration = 1.30, contactAt = 0.82 },
	M07 = { action = "Drink", duration = 1.30, contactAt = 0.82, alternateAction = "Aim", alternateDuration = 0.80 },
	M08 = { action = "Shake", duration = 1.05, contactAt = 0.65 },
	M10 = { action = "Aim", duration = 0.80, contactAt = 0.35 },
	M11 = { action = "Throw", duration = 0.78, contactAt = 0.30 },
	M12 = { action = "Throw", duration = 0.78, contactAt = 0.30 },
	M13 = { action = "Throw", duration = 0.78, contactAt = 0.30 },
	M14 = { action = "Carry", duration = 0 },
	M15 = { action = "Place", duration = 1.00, contactAt = 0.46 },
}
local function toyPose(values)
	local result = {
		right = vector(64, 0, -8), elbow = 20, wrist = Vector3.zero,
		left = vector(55, -32, 10), leftElbow = 20, leftWeight = 0,
		root = Vector3.zero, waist = Vector3.zero,
		rightHip = Vector3.zero, leftHip = Vector3.zero,
		rightKnee = 0, leftKnee = 0,
		barrelLift = 0, drinkTip = 0,
	}
	for key, value in pairs(values or {}) do result[key] = value end
	return result
end
local toyIdle = {
	M01 = toyPose({right=vector(52,0,-12)}),
	M02 = toyPose({right=vector(65,8,-20),elbow=25,left=vector(65,-34,14),leftElbow=24,leftWeight=0.65}),
	M03 = toyPose({right=vector(82,0,-10),elbow=25}),
	M04 = toyPose({right=vector(63,14,-25),elbow=18,left=vector(65,-34,18),leftElbow=18,leftWeight=1}),
	M05 = toyPose(), M06 = toyPose(), M07 = toyPose(),
	M08 = toyPose({right=vector(65,12,-24),elbow=24,left=vector(65,-34,18),leftElbow=24,leftWeight=0.85}),
	M10 = toyPose({right=vector(75,4,-12),elbow=20,left=vector(63,-35,15),leftElbow=25,leftWeight=0.45}),
	M11 = toyPose(), M12 = toyPose(), M13 = toyPose(),
	M14 = toyPose({right=vector(90,-6,-17),elbow=23}),
	M15 = toyPose({right=vector(52,12,-20),elbow=16,left=vector(53,-36,17),leftElbow=16,leftWeight=1}),
}
local function toyKey(time, values) return { time=time, pose=toyPose(values) } end
local toyTracks = {
	Kick = {
		toyKey(0),
		toyKey(0.24,{right=vector(48,8,-18),elbow=6,root=vector(-28,0,0),waist=vector(-14,0,0),
			left=vector(20,-5,18),leftWeight=.7,rightHip=vector(22,0,0),leftHip=vector(22,0,0),rightKnee=-24,leftKnee=-24}),
		toyKey(0.43,{right=vector(20,-4,-22),elbow=6,root=vector(-2,-5,-3),
			left=vector(18,0,25),leftWeight=.7,rightHip=vector(-26,0,-3),rightKnee=-32}),
		toyKey(0.60,{right=vector(27,-5,-28),elbow=8,root=vector(8,8,3),waist=vector(5,5,0),
			left=vector(25,0,28),leftWeight=.85,rightHip=vector(72,0,-3),leftHip=vector(-5,0,0),rightKnee=-4}),
		toyKey(0.76,{right=vector(30,0,-19),elbow=12,root=vector(4,6,2),
			left=vector(24,0,18),leftWeight=.5,rightHip=vector(38,0,0),rightKnee=-12}),
		toyKey(1.10),
	},
	Lob = {
		toyKey(0),
		toyKey(0.19,{right=vector(122,8,-22),elbow=48,left=vector(125,-27,19),leftElbow=44,leftWeight=1,
			root=vector(5,0,0),waist=vector(4,0,0),rightKnee=-9,leftKnee=-9}),
		toyKey(0.34,{right=vector(153,7,-15),elbow=8,left=vector(151,-18,14),leftElbow=8,leftWeight=1,
			root=vector(-3,0,0),waist=vector(-3,0,0)}),
		toyKey(0.48,{right=vector(132,9,-17),elbow=12,wrist=vector(14,0,0),
			left=vector(126,-20,15),leftElbow=14,leftWeight=.8,root=vector(-4,0,0)}),
		toyKey(0.85),
	},
	Bonk = {
		toyKey(0),
		toyKey(0.12,{right=vector(118,-24,-32),elbow=36,root=vector(3,-15,-3),waist=vector(0,-12,0),
			left=vector(75,-47,16),leftElbow=30,leftWeight=.65}),
		toyKey(0.23,{right=vector(47,28,-17),elbow=9,wrist=vector(-9,5,0),
			root=vector(-5,10,4),waist=vector(-3,13,0),left=vector(43,-28,18),leftElbow=12,leftWeight=.4}),
		toyKey(0.34,{right=vector(71,76,-23),elbow=28,root=vector(-2,17,4),waist=vector(0,19,0)}),
		toyKey(0.58),
	},
	BarrelThrow = {
		toyKey(0),
		toyKey(0.23,{right=vector(102,8,-20),elbow=35,left=vector(104,-29,19),leftElbow=35,leftWeight=1,
			root=vector(-8,0,0),waist=vector(-5,0,0),rightKnee=-13,leftKnee=-13}),
		toyKey(0.40,{right=vector(164,8,-18),elbow=22,left=vector(163,-20,17),leftElbow=22,leftWeight=1,barrelLift=1,
			root=vector(7,0,0),waist=vector(6,0,0)}),
		toyKey(0.52,{right=vector(104,5,-15),elbow=5,left=vector(103,-20,16),leftElbow=5,leftWeight=1,
			root=vector(-13,0,0),waist=vector(-8,0,0)}),
		toyKey(0.69,{right=vector(69,9,-18),elbow=9,left=vector(68,-25,18),leftElbow=9,leftWeight=.8,
			root=vector(-10,0,0),waist=vector(-5,0,0)}),
		toyKey(1.10),
	},
	Drink = {
		toyKey(0),
		toyKey(0.32,{right=vector(128,8,-37),elbow=58,wrist=vector(-14,0,-8),root=vector(2,0,0)}),
		toyKey(0.60,{right=vector(136,7,-39),elbow=65,wrist=vector(-31,0,-8),root=vector(4,0,0),waist=vector(2,0,0),drinkTip=1}),
		toyKey(0.82,{right=vector(135,7,-39),elbow=64,wrist=vector(-35,0,-8),root=vector(4,0,0),waist=vector(2,0,0),drinkTip=1}),
		toyKey(1.02,{right=vector(113,8,-27),elbow=44,wrist=vector(-10,0,-3),root=vector(1,0,0)}),
		toyKey(1.30),
	},
	Shake = {
		toyKey(0),
		toyKey(0.20,{right=vector(94,13,-28),elbow=34,left=vector(93,-35,20),leftElbow=33,leftWeight=1}),
		toyKey(0.35,{right=vector(103,6,-31),elbow=39,left=vector(103,-41,23),leftElbow=38,leftWeight=1,root=vector(0,-3,-2)}),
		toyKey(0.48,{right=vector(82,20,-23),elbow=26,left=vector(82,-28,17),leftElbow=25,leftWeight=1,root=vector(0,3,2)}),
		toyKey(0.65,{right=vector(105,7,-32),elbow=40,left=vector(104,-40,23),leftElbow=39,leftWeight=1,root=vector(0,-3,-2)}),
		toyKey(0.78,{right=vector(83,18,-24),elbow=28,left=vector(84,-30,18),leftElbow=27,leftWeight=.9,root=vector(0,2,1)}),
		toyKey(1.05),
	},
	Aim = {
		toyKey(0),
		toyKey(0.22,{right=vector(89,5,-11),elbow=14,left=vector(81,-37,19),leftElbow=32,leftWeight=.9,
			root=vector(-3,-5,0),waist=vector(0,-5,0)}),
		toyKey(0.35,{right=vector(89,5,-11),elbow=14,left=vector(81,-37,19),leftElbow=32,leftWeight=.9,
			root=vector(-3,-5,0),waist=vector(0,-5,0)}),
		toyKey(0.41,{right=vector(97,3,-14),elbow=24,left=vector(85,-38,20),leftElbow=38,leftWeight=.9,
			root=vector(1,-5,0),waist=vector(2,-5,0)}),
		toyKey(0.80),
	},
	Throw = {
		toyKey(0),
		toyKey(0.17,{right=vector(136,-31,-32),elbow=44,root=vector(4,-14,-3),waist=vector(2,-14,0),
			left=vector(62,6,16),leftWeight=.6}),
		toyKey(0.30,{right=vector(90,11,-16),elbow=5,wrist=vector(12,0,0),
			root=vector(-7,10,3),waist=vector(-4,12,0),left=vector(32,-7,19),leftWeight=.4}),
		toyKey(0.45,{right=vector(57,49,-25),elbow=16,root=vector(-5,15,3),waist=vector(-3,12,0)}),
		toyKey(0.78),
	},
	Place = {
		toyKey(0),
		toyKey(0.24,{right=vector(47,12,-21),elbow=12,left=vector(49,-36,18),leftElbow=12,leftWeight=1,
			root=vector(-18,0,0),waist=vector(-12,0,0),rightHip=vector(15,0,0),leftHip=vector(15,0,0),rightKnee=-20,leftKnee=-20}),
		toyKey(0.46,{right=vector(41,12,-20),elbow=3,left=vector(42,-35,17),leftElbow=3,leftWeight=1,
			root=vector(-29,0,0),waist=vector(-16,0,0),rightHip=vector(26,0,0),leftHip=vector(26,0,0),rightKnee=-30,leftKnee=-30}),
		toyKey(0.64,{right=vector(31,6,-20),elbow=8,left=vector(32,-21,18),leftElbow=8,leftWeight=.7,
			root=vector(-16,0,0),waist=vector(-8,0,0),rightHip=vector(13,0,0),leftHip=vector(13,0,0),rightKnee=-16,leftKnee=-16}),
		toyKey(1.00),
	},
}
local function sampleToyPose(id, action, elapsed)
	local idle = toyIdle[id]
	local definition = toyActions[id]
	if not idle or not definition then return nil end
	local track = toyTracks[action]
	local duration = action == definition.action and definition.duration or action == definition.alternateAction and definition.alternateDuration
	if not duration or not track or elapsed ~= elapsed or elapsed < 0 or elapsed >= duration then return idle end
	local index = 2
	while index < #track and elapsed > track[index].time do index += 1 end
	local before, after = track[index - 1], track[index]
	local alpha = math.clamp((elapsed - before.time) / (after.time - before.time), 0, 1)
	alpha = alpha * alpha * (3 - 2 * alpha)
	local first = index == 2 and idle or before.pose
	local last = index == #track and idle or after.pose
	local sampled = {}
	for key, value in pairs(first) do sampled[key] = value + (last[key] - value) * alpha end
	return sampled
end
local function applyToyPose(record, joints, sampled, classic, fade)
	local right = sampled.right - vector(classic and 0 or sampled.elbow,0,0)
	local left = sampled.left - vector(classic and 0 or sampled.leftElbow,0,0)
	if classic then
		right += vector(-24,32,-12) * sampled.barrelLift
		left += vector(-23,-20,13) * sampled.barrelLift
	end
	local wrist = sampled.wrist + (classic and Vector3.zero or vector(45,80,38) * sampled.drinkTip)
	weaponJoint(record,joints[classic and "Right Shoulder" or "RightShoulder"],right,fade)
	weaponJoint(record,joints.RightElbow,vector(sampled.elbow,0,0),fade)
	weaponJoint(record,joints.RightWrist,wrist,fade)
	weaponJoint(record,joints[classic and "Left Shoulder" or "LeftShoulder"],left,fade*sampled.leftWeight)
	weaponJoint(record,joints.LeftElbow,vector(sampled.leftElbow,0,0),fade*sampled.leftWeight)
	local root = sampled.root * (classic and 1 or 0.55)
	weaponJoint(record,joints.RootJoint or joints.Root,root,fade,true)
	weaponJoint(record,joints.Waist,sampled.waist,fade,true)
	local chest = root + (classic and Vector3.zero or sampled.waist)
	weaponJoint(record,joints.Neck,vector(-chest.X*.35,-chest.Y*.5,-chest.Z*.4),fade,true)
	weaponJoint(record,joints[classic and "Right Hip" or "RightHip"],sampled.rightHip,fade,true)
	weaponJoint(record,joints[classic and "Left Hip" or "LeftHip"],sampled.leftHip,fade,true)
	weaponJoint(record,joints.RightKnee,vector(sampled.rightKnee,0,0),fade,true)
	weaponJoint(record,joints.LeftKnee,vector(sampled.leftKnee,0,0),fade,true)
end
local function animateToy(record, player, character, humanoid, now)
	local id = character:GetAttribute("PCToyHeld")
	if typeof(id) ~= "string" or not toyActions[id] or humanoid.Health <= 0
		or player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true
		or player:GetAttribute("MDParticipating") == true or player:GetAttribute("BBRagdolled") == true
		or player:GetAttribute("TGRagdolled") == true then
		record.toy = nil
		return false
	end
	if record.toy ~= id then
		record.toy = id
		record.toyAt = now
		record.jointsAt = nil
	end
	local started = player:GetAttribute("PCToyActionAt")
	local action = player:GetAttribute("PCToyAction")
	local matches = player:GetAttribute("PCToyActionItem") == id
	local elapsed = matches and typeof(started) == "number" and started == started and now - started or math.huge
	local sampled = sampleToyPose(id, action, elapsed)
	local fade = math.clamp((now-record.toyAt)/0.12,0,1)
	applyToyPose(record,bodyJoints(record,character,now),sampled,humanoid.RigType==Enum.HumanoidRigType.R6,fade)
	return true
end
local function close(a,b)
	if type(a)=="number" then return math.abs(a-b)<0.00001 end
	return (a-b).Magnitude<0.00001
end
local function samePose(a,b)
	for key,value in pairs(a) do if not close(value,b[key]) then return false end end
	return true
end
local expected={
	M01={"Kick",1.10,.60,.24},M02={"Lob",.85,.34},M03={"Bonk",.58,.23},
	M04={"BarrelThrow",1.10,.52},M05={"Drink",1.30,.82},M06={"Drink",1.30,.82},
	M07={"Drink",1.30,.82},M08={"Shake",1.05,.65},M10={"Aim",.80,.35},
	M11={"Throw",.78,.30},M12={"Throw",.78,.30},M13={"Throw",.78,.30},M14={"Carry",0},M15={"Place",1,.46},
}
for id, values in pairs(expected) do
	local def=toyActions[id]
	check(def.action==values[1]and def.duration==values[2]and def.contactAt==values[3]and def.placeAt==values[4],id.." matches authoritative timing")
	check(samePose(sampleToyPose(id,"WrongAction",.2),toyIdle[id]),id.." rejects mismatched action")
	check(samePose(sampleToyPose(id,def.action,math.huge),toyIdle[id]),id.." ignores expired action")
	check(samePose(sampleToyPose(id,def.action,-.1),toyIdle[id]),id.." ignores future timestamp")
	check(samePose(sampleToyPose(id,def.action,0/0),toyIdle[id]),id.." ignores nonfinite action")
	check(samePose(sampleToyPose(id,def.action,def.duration),toyIdle[id]),id.." recovers to authored carry")
	if def.duration>0 then
		local track=toyTracks[def.action]
		for _,key in ipairs(track) do
			local a,b=sampleToyPose(id,def.action,key.time-.00001),sampleToyPose(id,def.action,key.time+.00001)
			check((a.right-b.right).Magnitude<.04 and (a.left-b.left).Magnitude<.04,id.." continuous at "..key.time)
		end
		for time=0,def.duration,.005 do
			local p=sampleToyPose(id,def.action,time)
			for _,v in pairs(p) do
				local magnitude=type(v)=="number"and math.abs(v)or v.Magnitude
				assert(magnitude==magnitude and magnitude<250,"Invalid sampled pose")
			end
			assert(p.leftWeight>=0 and p.leftWeight<=1,"Invalid guide-hand blend")
		end
		check(not samePose(sampleToyPose(id,def.action,def.contactAt),toyIdle[id]),id.." has actual gesture at gameplay contact")
	end
end
check(sampleToyPose("M09","Throw",.2)==nil,"Deferred plunger gains no fabricated action")
check(sampleToyPose("Unknown","Throw",.2)==nil,"Unknown item rejected")
local kickBack=sampleToyPose("M01","Kick",.43)
local kickContact=sampleToyPose("M01","Kick",.60)
check(kickBack.rightHip.X<0 and kickContact.rightHip.X>60,"Football winds leg back then kicks forward")
check(sampleToyPose("M01","Kick",.24).root.X<-20,"Football reaches down to place ball before kick")
check(sampleToyPose("M02","Lob",.34).right.X>140,"Basketball releases upwards")
check(sampleToyPose("M04","BarrelThrow",.40).right.X>150 and sampleToyPose("M04","BarrelThrow",.40).leftWeight==1,"Barrel lifts overhead with both arms")
check(sampleToyPose("M05","Drink",.60).elbow>55 and sampleToyPose("M05","Drink",.82).wrist.X<-25,"Drinking brings bottle up and tips it")
check(sampleToyPose("M08","Shake",.35).right.X>sampleToyPose("M08","Shake",.48).right.X+15,"Present visibly oscillates")
check(sampleToyPose("M10","Aim",.41).elbow>sampleToyPose("M10","Aim",.35).elbow,"Frost aiming includes recoil")
check(not samePose(sampleToyPose("M07","Aim",.35),toyIdle.M07),"Active Ember breath has an aiming gesture")
check(samePose(sampleToyPose("M07","Aim",.80),toyIdle.M07),"Ember aiming recovers at .8 seconds")
check(samePose(sampleToyPose("M05","Aim",.35),toyIdle.M05),"Other potions cannot play the Ember alternate")
check(samePose(sampleToyPose("M07","Aim",-.1),toyIdle.M07),"Future Ember shot timestamps remain idle")
check(sampleToyPose("M15","Place",.46).rightKnee<-20 and sampleToyPose("M15","Place",.46).root.X<-20,"Pad placement bends down")
for _,rig in ipairs({"R6","R15"})do
	local joints={}
	for _,name in ipairs({"Right Shoulder","Left Shoulder","Right Hip","Left Hip","RootJoint","RightShoulder","LeftShoulder","RightElbow","LeftElbow","RightWrist","Root","Waist","Neck","RightHip","LeftHip","RightKnee","LeftKnee"})do
		joints[name]={Name=name,Parent=true,Enabled=true}
	end
	local attrs={PCToyAction="Kick",PCToyActionAt=100,PCToyActionItem="M01"}
	local charAttrs={PCToyHeld="M01"}
	local player={GetAttribute=function(_,key)return attrs[key]end}
	local character={GetAttribute=function(_,key)return charAttrs[key]end}
	local human={RigType=rig,Health=100}
	local record={bodyJoints=joints,calls={},toy="M01",toyAt=99}
	check(animateToy(record,player,character,human,100.60),rig.." accepts authoritative action")
	check(record.calls[rig=="R6"and"Right Hip"or"RightHip"].angles.X>60,rig.." applies kick to native hip name")
	check(record.calls.RootJoint.additive and record.calls.Neck.additive,rig.." body gesture layers over locomotion")
	attrs.PCToyActionItem="M02"
	record.calls={}
	animateToy(record,player,character,human,100.60)
	check(record.calls[rig=="R6"and"Right Hip"or"RightHip"].angles.Magnitude==0,rig.." stale swapped-item action cannot replay")
	attrs.PCToyActionItem="M01"
	for _,block in ipairs({"BBParticipating","TGParticipating","MDParticipating","BBRagdolled","TGRagdolled"})do
		attrs[block]=true record.calls={}
		check(not animateToy(record,player,character,human,100.60) and record.toy==nil and next(record.calls)==nil,rig.." stops cleanly on "..block)
		attrs[block]=nil
	end
	charAttrs.PCToyHeld=nil record.calls={}
	check(not animateToy(record,player,character,human,100.60)and next(record.calls)==nil,rig.." clears on unequip")
	charAttrs.PCToyHeld="M01" human.Health=0
	check(not animateToy(record,player,character,human,100.60)and record.toy==nil,rig.." clears on death")
	human.Health=100
	charAttrs.PCToyHeld="M14"
	record.toy="M14" record.toyAt=99 record.calls={}
	check(animateToy(record,player,character,human,101),rig.." torch has carry motion without activation")
	local shoulder=record.calls[rig=="R6"and"Right Shoulder"or"RightShoulder"]
	check(shoulder.angles.X==(rig=="R6" and 90 or 67),rig.." torch uses rig-appropriate shoulder and elbow split")
	joints[rig=="R6"and"Right Shoulder"or"RightShoulder"].Enabled=false record.calls={}
	animateToy(record,player,character,human,101)
	check(record.calls[rig=="R6"and"Right Shoulder"or"RightShoulder"]==nil,rig.." disabled ragdoll joint stays untouched")
end
check(sampleToyPose("M04","BarrelThrow",.40).barrelLift==1,"R6 barrel correction peaks at overhead lift")
check(sampleToyPose("M04","BarrelThrow",.52).barrelLift==0,"Barrel correction clears at release")
check(sampleToyPose("M05","Drink",.82).drinkTip==1,"R15 bottle tip held during drinking contact")
check(sampleToyPose("M05","Drink",1.3).drinkTip==0,"Bottle tipping clears on recovery")
print("Toy motion checks passed: "..passed)

