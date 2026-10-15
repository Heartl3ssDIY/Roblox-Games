return function()
local report = {}
task.spawn(function()
local fixture
report.ok, report.result = xpcall(function()
local checks = 0
local function check(ok, message) assert(ok, message); checks += 1 end
local Players = {LocalPlayer={GetAttribute=function() return false end}}
local petClipCache = {}
local function loadPetClips(name)
	if petClipCache[name] then return petClipCache[name] end
	local root = game.ReplicatedStorage:FindFirstChild("PlaygroundPetAnimations")
	local source = root and root:FindFirstChild(name)
	if not source then return nil end
	local clips = {referenceScale = tonumber(source:GetAttribute("ReferenceScale")) or 1}
	for _, sequence in source:GetChildren() do
		if sequence:IsA("KeyframeSequence") and sequence:GetAttribute("NormalizedBoneTransforms") == true then
			local frames = {}
			for _, keyframe in sequence:GetKeyframes() do
				local poses = {}
				for _, pose in keyframe:GetChildren() do
					if pose:IsA("Pose") then poses[pose.Name] = pose.CFrame end
				end
				table.insert(frames, {time = keyframe.Time, poses = poses})
			end
			table.sort(frames, function(a, b) return a.time < b.time end)
			if #frames >= 2 and frames[#frames].time > 0 then
				clips[sequence.Name] = {frames = frames, duration = frames[#frames].time}
			end
		end
	end
	if not clips.Idle then return nil end
	petClipCache[name] = clips
	return clips
end

local function petClipPose(clip, phase, boneName)
	local frames = clip.frames
	local time = phase * clip.duration
	local low, high = 1, #frames
	while low + 1 < high do
		local middle = math.floor((low + high) * 0.5)
		if frames[middle].time <= time then low = middle else high = middle end
	end
	local a, b = frames[low], frames[high]
	local from = a.poses[boneName] or CFrame.identity
	local to = b.poses[boneName] or from
	return from:Lerp(to, math.clamp((time - a.time) / math.max(b.time - a.time, 0.0001), 0, 1))
end

local function prepareAuthoredMotion(state)
	local name = state.model:GetAttribute("PCPetClipSet")
	if type(name) ~= "string" then return end
	local clips = loadPetClips(name)
	if not clips then return end
	state.authored = {clips = clips, bones = {}, phase = 0, scale = state.model:GetScale() / clips.referenceScale}
	for _, bone in state.model:GetDescendants() do
		if bone:IsA("Bone") then
			table.insert(state.authored.bones, {bone = bone, name = bone.Name, rest = bone.Transform})
		end
	end
end

local function updateAuthoredMotion(state, reducedMotion)
	local authored = state.authored
	local idle, fly = authored.clips.Idle, authored.clips.Fly or authored.clips.Idle
	local blend = state.model:GetAttribute("PCDisplayPet") == true and 0 or state.movement
	local phase = reducedMotion and 0.25 or authored.phase
	for _, entry in authored.bones do
		local transform = petClipPose(idle, phase, entry.name):Lerp(petClipPose(fly, phase, entry.name), blend)
		entry.bone.Transform = entry.rest * (transform.Rotation + transform.Position * authored.scale)
	end
end


local hoveringPets = { P23 = true, P25 = true, P28 = true, P35 = true }
local function prepareRigMotion(state)
	prepareAuthoredMotion(state)
	state.bones, state.skinBones = {}, {}
	local pivot = state.model:GetPivot()
	for _, bone in ipairs(state.model:GetDescendants()) do
		if bone:IsA("Bone") then
			local source = bone:FindFirstChild("PCSourceBone")
			if source and source:IsA("ObjectValue") and source.Value then
				table.insert(state.skinBones, { bone = bone, source = source.Value })
			elseif state.model:GetAttribute("PCProceduralPetRig") == true then
				local frame = bone.WorldCFrame
				table.insert(state.bones, {
					bone = bone, name = bone.Name, rest = bone.Transform,
					pitch = frame:VectorToObjectSpace(pivot.RightVector),
					yaw = frame:VectorToObjectSpace(pivot.UpVector),
					roll = frame:VectorToObjectSpace(pivot.LookVector),
				})
			end
		end
	end
end

local function updateRigMotion(state, reducedMotion)
	if state.authored then updateAuthoredMotion(state, reducedMotion) return end
	if not state.tracks.idle and not state.tracks.walk then
		local phase, movement = state.phase, state.movement
		local intensity = reducedMotion and 0 or 1
		for _, entry in ipairs(state.bones) do
			local name, pitch, yaw, roll = entry.name, 0, 0, 0
			local right = name:find("R") ~= nil
			if name == "Head" then
				pitch = math.sin(phase * 0.5) * 3
				yaw = math.sin(phase * 0.29) * 5
			elseif name == "Tail" then
				yaw = math.sin(phase * 0.8) * (7 + movement * 9)
				pitch = math.sin(phase * 0.4) * 3
			elseif name:find("Wing") then
				roll = math.sin(phase) * (hoveringPets[state.id] and 22 or 10) * (right and -1 or 1)
			elseif name:find("Leg") or name:find("Arm") then
				local offset = right and math.pi or 0
				if name:find("Back") then offset += math.pi end
				local number = tonumber(name:match("(%d+)$"))
				if number then offset += (number - 1) * math.pi end
				pitch = math.sin(phase + offset) * (2 + movement * 18)
			elseif name == "Body" then
				pitch = math.sin(phase * 0.5) * 1.5
			end
			entry.bone.Transform = entry.rest
				* CFrame.fromAxisAngle(entry.pitch, math.rad(pitch * intensity))
				* CFrame.fromAxisAngle(entry.yaw, math.rad(yaw * intensity))
				* CFrame.fromAxisAngle(entry.roll, math.rad(roll * intensity))
		end
	end
	for _, entry in ipairs(state.skinBones) do
		entry.bone.Transform = entry.source.Transform
	end
end

local petRigStates = {}
local petRigClock = 1
local function updatePetRigs(delta)
	petRigClock += delta
	if petRigClock >= 0.3 then
		petRigClock = 0
		local display = workspace:FindFirstChild("VIP-Dragon-Rigged-display")
		if display and display:IsA("Model") and display:GetAttribute("PCDisplayPet") == true and not petRigStates[display] then
			local state = {model = display, id = "P36", tracks = {}, movement = 0, phase = 0}
			prepareRigMotion(state)
			petRigStates[display] = state
		end
		local folder = workspace:FindFirstChild("PlaygroundPetVisuals")
		if folder then
			for _, model in ipairs(folder:GetChildren()) do
				if model:IsA("Model") and (model:GetAttribute("PCProceduralPetRig") == true or type(model:GetAttribute("PCPetClipSet")) == "string") and not petRigStates[model] then
					local userId = tonumber(model:GetAttribute("PetOwnerUserId")) or 0
					local state = {model = model, id = model:GetAttribute("CatalogId"), tracks = {}, movement = 0, phase = (userId % 97) * math.pi * 2 / 97}
					prepareRigMotion(state)
					petRigStates[model] = state
				end
			end
		end
	end
	local reducedMotion = Players.LocalPlayer:GetAttribute("PCReducedMotion") == true
	for model, state in pairs(petRigStates) do
		if not model.Parent then
			petRigStates[model] = nil
		else
			state.movement = math.clamp(tonumber(model:GetAttribute("PCPetMovement")) or 0, 0, 1)
			state.phase += delta * math.pi * 2 * (0.85 + state.movement * 1.75)
			if state.authored and not reducedMotion then
				local clips = state.authored.clips
				local blend = model:GetAttribute("PCDisplayPet") == true and 0 or state.movement
				local duration = clips.Idle.duration + ((clips.Fly or clips.Idle).duration - clips.Idle.duration) * blend
				state.authored.phase = (state.authored.phase + delta / duration) % 1
			end
			updateRigMotion(state, reducedMotion)
		end
	end
end


local template=game.ReplicatedStorage.PlaygroundCosmeticAssets.P36
local display=workspace["VIP-Dragon-Rigged-display"]
local backup=game.ServerStorage.VIPDragonBackup20261007["VIP-Dragon-Rigged-display"]
check(display:GetPivot()==backup:GetPivot() and display:GetScale()==backup:GetScale(),"Large display moved or resized")
local clips=loadPetClips("VIPDragon")
check(clips.Idle and clips.Fly and #clips.Idle.frames==41 and #clips.Fly.frames==27,"Authored animation frames missing")
check(clips.Idle.duration>clips.Fly.duration,"Flight clip cadence incorrect")
for _,clip in {clips.Idle,clips.Fly} do
 for name,first in clip.frames[1].poses do
  local last=clip.frames[#clip.frames].poses[name]
  local delta=first:ToObjectSpace(last)
  local _,angle=delta:ToAxisAngle()
  check(delta.Position.Magnitude<0.002 and angle<0.002,"Clip loop seam on "..name)
 end
end
fixture=template:Clone()
fixture.Name="VIPAnimationCheck"
fixture:PivotTo(CFrame.new(0,4000,0))
fixture.Parent=workspace
local state={model=fixture,id="P36",tracks={},movement=0,phase=0}
prepareRigMotion(state)
check(state.authored and #state.authored.bones==14,"Rig did not bind all 14 bones")
local wing=fixture.RootPart:FindFirstChild("Wing.L",true)
state.authored.phase=0 updateRigMotion(state,false) local down=wing.Transform
state.authored.phase=0.5 updateRigMotion(state,false) local up=wing.Transform
local _,wingRange=down:ToObjectSpace(up):ToAxisAngle()
check(math.deg(wingRange)>50,"Authored wing flap missing")
state.authored.phase=0.3 state.movement=0 updateRigMotion(state,false) local hover=wing.Transform
state.movement=1 updateRigMotion(state,false) local flying=wing.Transform
check(not hover:FuzzyEq(flying,0.0001),"Moving pet does not switch to flight")
updateRigMotion(state,true) local reduced=wing.Transform
state.authored.phase=0.9 updateRigMotion(state,true)
check(reduced:FuzzyEq(wing.Transform),"Reduced motion does not hold steady")
local body=fixture.RootPart:FindFirstChild("Body",true)
state.movement=0 state.authored.phase=0.25 updateRigMotion(state,false)
local smallOffset=body.Transform.Position
state.authored.scale=25 updateRigMotion(state,false)
check((body.Transform.Position-smallOffset*25).Magnitude<0.0001,"Large rig translations are not scaled")
local originals,coats=0,0
for _,part in template:GetDescendants() do
 if part:IsA("BasePart") then
  check(not part.CanCollide and not part.CanTouch and not part.CanQuery,"Cosmetic collision enabled")
  if part:IsA("MeshPart") then
   if part:GetAttribute("PCStudLayer") then
    coats+=1 check(part.HasSkinnedMesh and part.MaterialVariant=="PlaygroundItemStuds","Stud coat lost skinned binding")
   else originals+=1 end
  end
 end
end
check(originals==8 and coats==8,"Incorrect VIP mesh layers")
check(template:GetAttribute("PCOutlineStored")==true and template:GetAttribute("PCOutlineColor")==Color3.new(0,0,0),"Black outline metadata missing")
check(template:FindFirstChildOfClass("Highlight")==nil,"Stored template wastes an outline slot")
check(display.CartoonOutline.Adornee==display and display.CartoonOutline.OutlineTransparency==0,"Display outline missing")
check(template:GetAttribute("PCPetHoverHeight")==1.15,"VIP flight height missing")
return {checks=checks,passed=true,wingRange=math.deg(wingRange)}
end,debug.traceback)
if fixture then fixture:Destroy() end
report.done=true
end)
while not report.done do task.wait() end
return report
end
