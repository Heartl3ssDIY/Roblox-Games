assert(not game:GetService("RunService"):IsRunning())
local folder=Instance.new("Folder") folder.Name="ExpansionGearVerification" folder.Parent=game.ServerStorage
local function test()
 local module=Instance.new("ModuleScript") module.Source=[====[local function vector(x,y,z) return Vector3.new(x or 0,y or 0,z or 0) end
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
	M16 = { action = "Drink", duration = 1.3, contactAt = 0.82 },
	M17 = { action = "Aim", duration = 0.8, contactAt = 0.35 },
	M18 = { action = "Aim", duration = 0.8, contactAt = 0.35 },
	M19 = { action = "Place", duration = 1, contactAt = 0.46 },
	M20 = { action = "Bonk", duration = 0.58, contactAt = 0.23 },
	M21 = { action = "Throw", duration = 0.78, contactAt = 0.3 },
	M22 = { action = "Shake", duration = 1.05, contactAt = 0.65 },
	M23 = { action = "Aim", duration = 0.8, contactAt = 0.35 },
	M24 = { action = "Throw", duration = 0.78, contactAt = 0.3 },
	M25 = { action = "Shake", duration = 1.05, contactAt = 0.65 },
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
	M16 = toyPose(),
	M17 = toyPose({right=vector(75,4,-12),elbow=20,left=vector(63,-35,15),leftElbow=25,leftWeight=0.6}),
	M18 = toyPose({right=vector(75,4,-12),elbow=20}),
	M19 = toyPose({right=vector(52,0,-12)}),
	M20 = toyPose({right=vector(80,0,-10),elbow=25}),
	M21 = toyPose(),
	M22 = toyPose({right=vector(65,12,-24),elbow=24,left=vector(65,-34,18),leftElbow=24,leftWeight=0.7}),
	M23 = toyPose({right=vector(75,4,-12),elbow=20}),
	M24 = toyPose(),
	M25 = toyPose({right=vector(65,12,-24),elbow=24,left=vector(65,-34,18),leftElbow=24,leftWeight=0.85}),
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

return {actions=toyActions,sample=sampleToyPose,idle=toyIdle}]====] module.Parent=folder
 module.Capabilities=game.StarterPlayer.StarterPlayerScripts.PlaygroundEmotes.Capabilities module.Sandboxed=true
 local poses=require(module)
 local count=0
 for n=16,25 do
  local id=string.format("M%02d",n) local config=assert(poses.actions[id]) local idle=assert(poses.idle[id])
  local atContact=assert(poses.sample(id,config.action,config.contactAt)) assert(atContact.right~=idle.right,"No active pose "..id)
  assert(poses.sample(id,config.action,config.duration)==idle)
  for _,value in pairs(atContact) do
   if typeof(value)=="Vector3" then assert(value.X==value.X and value.Y==value.Y and value.Z==value.Z) else assert(type(value)=="number" and value==value) end
  end
  count+=1
 end
 local equipmentModule=game.ServerScriptService.PlaygroundEquipmentService:Clone() equipmentModule.Parent=folder
 local Equipment=require(equipmentModule)
 local equipment=Equipment.new({})
 local effects={}
 for n=16,25 do
  local id=string.format("B%02d",n)
  local tool=Instance.new("Tool") tool.Parent=folder
  local handle=Instance.new("Part") handle.Name="Handle" handle.Parent=tool
  equipment:_attachBatEffects(tool,handle,{id=id},Vector3.new(.85,3.6,.85),.42)
  local effect=assert(tool:GetAttribute("HeldEffect"))
  assert(not effects[effect],"Duplicate named bat effect") effects[effect]=true
  assert(tool:FindFirstChild("HeldVFX"))
  assert(tool:FindFirstChildWhichIsA("Trail",true) and tool:FindFirstChildWhichIsA("ParticleEmitter",true))
  equipment:_batHitEffect({bat=tool})
 end
 return {toyPoses=count,batEffects=10,sandboxed=true}
end
local ok,result=xpcall(test,debug.traceback)
folder:Destroy()
if not ok then error(result) end
return game.HttpService:JSONEncode(result)
