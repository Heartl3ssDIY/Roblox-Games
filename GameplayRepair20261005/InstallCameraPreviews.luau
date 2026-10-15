assert(not game:GetService("RunService"):IsRunning(),"Edit mode required")
local function normalize(s) return (string.gsub(s,"\r",""):gsub("%s+$","")) end
local entries={}
table.insert(entries,{target=game["StarterPlayer"]["StarterPlayerScripts"]["BritishBulldogCamera"],before=[====[local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local player=Players.LocalPlayer
local baseline
local currentDistance
local connections={}
local elapsed=0
local roll=0
local shift=0
local lastCamera
local lastBase
local lastOutput
local beforeName="BritishBulldogCameraRestore"
local afterName="BritishBulldogCameraMotion"

local function removeCameraOffset()
 if lastCamera and lastCamera.Parent and lastBase and lastOutput and lastCamera.CFrame==lastOutput then
  lastCamera.CFrame=lastBase
 end
 lastCamera=nil
 lastBase=nil
 lastOutput=nil
end

local function restore()
 removeCameraOffset()
 roll=0
 shift=0
 if not baseline then return end
 player.CameraMinZoomDistance=math.min(baseline.minimum,player.CameraMaxZoomDistance)
 player.CameraMaxZoomDistance=baseline.maximum
 player.CameraMinZoomDistance=baseline.minimum
 player.CameraMode=baseline.mode
 baseline=nil
 currentDistance=nil
end

local function update()
 local arena=workspace:FindFirstChild("British Bulldog game")
 local gameplay=arena and arena:FindFirstChild("Gameplay")
 local bounds=gameplay and gameplay:FindFirstChild("ArenaBounds")
 local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 local inside=false
 if root and bounds and bounds:IsA("BasePart") then
  local point=bounds.CFrame:PointToObjectSpace(root.Position)
  local half=bounds.Size/2
  inside=math.abs(point.X)<=half.X and math.abs(point.Y)<=half.Y and math.abs(point.Z)<=half.Z
 end
 if not inside and player:GetAttribute("BBParticipating")~=true then restore() return end
 local distance=arena and arena:GetAttribute("CameraZoomDistance")
 if typeof(distance)~="number" or distance~=distance then distance=30 end
 distance=math.clamp(distance,8,80)
 if not baseline then
  baseline={minimum=player.CameraMinZoomDistance,maximum=player.CameraMaxZoomDistance,mode=player.CameraMode}
 end
 if currentDistance~=distance then
  player.CameraMode=Enum.CameraMode.Classic
  player.CameraMinZoomDistance=math.min(distance,player.CameraMaxZoomDistance)
  player.CameraMaxZoomDistance=distance
  player.CameraMinZoomDistance=distance
  currentDistance=distance
 end
end

local function numberAttribute(name,fallback)
 local value=player:GetAttribute(name)
 return typeof(value)=="number" and value==value and math.abs(value)<math.huge and value or fallback
end

RunService:BindToRenderStep(beforeName,Enum.RenderPriority.Camera.Value-1,removeCameraOffset)
RunService:BindToRenderStep(afterName,Enum.RenderPriority.Camera.Value+1,function(dt)
 local camera=workspace.CurrentCamera
 local character=player.Character
 local humanoid=character and character:FindFirstChildOfClass("Humanoid")
 local root=character and character:FindFirstChild("HumanoidRootPart")
 local state=ReplicatedStorage:FindFirstChild("BritishBulldogState")
 local active=player:GetAttribute("BBParticipating")==true and state and state:GetAttribute("Phase")=="Crossing"
  and player:GetAttribute("BBRole")~="Tagged" and player:GetAttribute("BBStatus")~="Safe"
  and humanoid and humanoid.Health>0 and root and humanoid.WalkSpeed>0
 if not camera or camera.CameraType~=Enum.CameraType.Custom then roll=0 shift=0 return end
 local targetRoll=0
 local targetShift=0
 if active and player:GetAttribute("PCReducedMotion")~=true then
  local screenRight=camera.CFrame.RightVector
  local lateral=root.AssemblyLinearVelocity:Dot(screenRight)
  targetRoll=-math.rad(1.2)*math.clamp(lateral/math.max(humanoid.WalkSpeed,1),-1,1)
  local started=numberAttribute("BBDodgeStartedAt",0)
  local duration=math.clamp(numberAttribute("BBDodgeDuration",0.32),0.2,0.5)+0.14
  local time=workspace:GetServerTimeNow()-started
  local direction=player:GetAttribute("BBDodgeDirection")
  if started>0 and time>=0 and time<duration and typeof(direction)=="Vector3" then
   local alpha=time/duration
   local pulse=alpha<0.22 and math.sin(alpha/0.22*math.pi/2) or math.cos((alpha-0.22)/0.78*math.pi/2)^2
   local side=math.clamp(direction:Dot(screenRight),-1,1)
   targetRoll-=math.rad(3.2)*side*pulse
   targetShift=0.24*side*pulse
  end
 end
 local blend=1-math.exp(-18*math.clamp(dt,0,0.1))
 roll+=(targetRoll-roll)*blend
 shift+=(targetShift-shift)*blend
 if not active and math.abs(roll)<0.0001 and math.abs(shift)<0.0001 then roll=0 shift=0 return end
 if roll==0 and shift==0 then return end
 lastCamera=camera
 lastBase=camera.CFrame
 lastOutput=lastBase*CFrame.new(shift,0,0)*CFrame.Angles(0,0,roll)
 camera.CFrame=lastOutput
end)

table.insert(connections,player:GetAttributeChangedSignal("BBParticipating"):Connect(update))
table.insert(connections,RunService.Heartbeat:Connect(function(dt)
 elapsed+=dt
 if elapsed>=0.2 then elapsed=0 update() end
end))
script.Destroying:Connect(function()
 RunService:UnbindFromRenderStep(beforeName)
 RunService:UnbindFromRenderStep(afterName)
 for _,connection in ipairs(connections) do connection:Disconnect() end
 restore()
end)
update()
]====],after=[====[local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local player=Players.LocalPlayer
local baseline
local connections={}
local elapsed=0
local roll=0
local shift=0
local lastCamera
local lastBase
local lastOutput
local beforeName="BritishBulldogCameraRestore"
local afterName="BritishBulldogCameraMotion"

local function removeCameraOffset()
 if lastCamera and lastCamera.Parent and lastBase and lastOutput and lastCamera.CFrame==lastOutput then
  lastCamera.CFrame=lastBase
 end
 lastCamera=nil
 lastBase=nil
 lastOutput=nil
end

local function restore()
 removeCameraOffset()
 roll=0
 shift=0
 if not baseline then return end
 player.CameraMinZoomDistance=math.min(baseline.minimum,player.CameraMaxZoomDistance)
 player.CameraMaxZoomDistance=baseline.maximum
 player.CameraMinZoomDistance=baseline.minimum
 player.CameraMode=baseline.mode
 baseline=nil
end

local function update()
 local active=player:GetAttribute("BBParticipating")==true
  or player:GetAttribute("TGParticipating")==true
  or player:GetAttribute("MDParticipating")==true
 if not active then restore() return end
 if not baseline then
  baseline={minimum=player.CameraMinZoomDistance,maximum=player.CameraMaxZoomDistance,mode=player.CameraMode}
 end
 player.CameraMode=Enum.CameraMode.Classic
 if player.CameraMinZoomDistance~=0.5 then player.CameraMinZoomDistance=0.5 end
 if player.CameraMaxZoomDistance~=5 then player.CameraMaxZoomDistance=5 end
end

local function numberAttribute(name,fallback)
 local value=player:GetAttribute(name)
 return typeof(value)=="number" and value==value and math.abs(value)<math.huge and value or fallback
end

RunService:BindToRenderStep(beforeName,Enum.RenderPriority.Camera.Value-1,removeCameraOffset)
RunService:BindToRenderStep(afterName,Enum.RenderPriority.Camera.Value+1,function(dt)
 local camera=workspace.CurrentCamera
 local character=player.Character
 local humanoid=character and character:FindFirstChildOfClass("Humanoid")
 local root=character and character:FindFirstChild("HumanoidRootPart")
 local state=ReplicatedStorage:FindFirstChild("BritishBulldogState")
 local active=player:GetAttribute("BBParticipating")==true and state and state:GetAttribute("Phase")=="Crossing"
  and player:GetAttribute("BBRole")~="Tagged" and player:GetAttribute("BBStatus")~="Safe"
  and humanoid and humanoid.Health>0 and root and humanoid.WalkSpeed>0
 if not camera or camera.CameraType~=Enum.CameraType.Custom then roll=0 shift=0 return end
 local targetRoll=0
 local targetShift=0
 if active and player:GetAttribute("PCReducedMotion")~=true then
  local screenRight=camera.CFrame.RightVector
  local lateral=root.AssemblyLinearVelocity:Dot(screenRight)
  targetRoll=-math.rad(1.2)*math.clamp(lateral/math.max(humanoid.WalkSpeed,1),-1,1)
  local started=numberAttribute("BBDodgeStartedAt",0)
  local duration=math.clamp(numberAttribute("BBDodgeDuration",0.32),0.2,0.5)+0.14
  local time=workspace:GetServerTimeNow()-started
  local direction=player:GetAttribute("BBDodgeDirection")
  if started>0 and time>=0 and time<duration and typeof(direction)=="Vector3" then
   local alpha=time/duration
   local pulse=alpha<0.22 and math.sin(alpha/0.22*math.pi/2) or math.cos((alpha-0.22)/0.78*math.pi/2)^2
   local side=math.clamp(direction:Dot(screenRight),-1,1)
   targetRoll-=math.rad(3.2)*side*pulse
   targetShift=0.24*side*pulse
  end
 end
 local blend=1-math.exp(-18*math.clamp(dt,0,0.1))
 roll+=(targetRoll-roll)*blend
 shift+=(targetShift-shift)*blend
 if not active and math.abs(roll)<0.0001 and math.abs(shift)<0.0001 then roll=0 shift=0 return end
 if roll==0 and shift==0 then return end
 lastCamera=camera
 lastBase=camera.CFrame
 lastOutput=lastBase*CFrame.new(shift,0,0)*CFrame.Angles(0,0,roll)
 camera.CFrame=lastOutput
end)

for _,attribute in ipairs({"BBParticipating","TGParticipating","MDParticipating"}) do
 table.insert(connections,player:GetAttributeChangedSignal(attribute):Connect(update))
end
table.insert(connections,RunService.Heartbeat:Connect(function(dt)
 elapsed+=dt
 if elapsed>=0.2 then elapsed=0 update() end
end))
script.Destroying:Connect(function()
 RunService:UnbindFromRenderStep(beforeName)
 RunService:UnbindFromRenderStep(afterName)
 for _,connection in ipairs(connections) do connection:Disconnect() end
 restore()
end)
update()
]====]})
table.insert(entries,{target=game["StarterPlayer"]["StarterPlayerScripts"]["PlaygroundPets"],before=[====[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local assets = ReplicatedStorage:WaitForChild("PlaygroundCosmeticAssets")
local visuals = Instance.new("Folder")
visuals.Name = "PlaygroundPetVisuals"
visuals.Parent = workspace

local states = {}
local connections = {}
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true
raycastParams.RespectCanCollide = true

local MAX_DISTANCE = 150
local MAX_VISIBLE = 24
local MAX_SIZE = 3
local effectColours = {
	P04 = Color3.fromRGB(251, 165, 222),
	P09 = Color3.fromRGB(151, 212, 255),
	P12 = Color3.fromRGB(139, 255, 214),
	P15 = Color3.fromRGB(255, 206, 232),
	P18 = Color3.fromRGB(255, 164, 69),
	P19 = Color3.fromRGB(182, 190, 255),
	P20 = Color3.fromRGB(255, 224, 115),
}
local hoveringPets = { P10 = true, P12 = true, P14 = true, P19 = true }

local function horizontal(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

local function smoothAlpha(speed, delta)
	return 1 - math.exp(-speed * delta)
end

local function visibleBounds(model)
	local lower = Vector3.new(math.huge, math.huge, math.huge)
	local upper = -lower
	local count = 0
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 1 then
			count += 1
			for x = -1, 1, 2 do
				for y = -1, 1, 2 do
					for z = -1, 1, 2 do
						local corner = part.CFrame:PointToWorldSpace(part.Size * Vector3.new(x, y, z) * 0.5)
						lower = lower:Min(corner)
						upper = upper:Max(corner)
					end
				end
			end
		end
	end
	if count == 0 then return nil end
	return lower, upper
end

local function release(player)
	local state = states[player]
	if not state then return end
	states[player] = nil
	for _, track in state.tracks do
		track:Stop(0)
		track:Destroy()
	end
	state.model:Destroy()
end

local function prepareParts(model)
	local parts = {}
	for _, object in model:GetDescendants() do
		if object:IsA("BaseScript") then
			object.Enabled = false
		elseif object:IsA("BasePart") then
			object.CanCollide = false
			object.CanTouch = false
			object.CanQuery = false
			object.Massless = true
			object.Anchored = false
			table.insert(parts, object)
		elseif object:IsA("Humanoid") then
			object.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			object.AutoRotate = false
		end
	end
	local root = model:FindFirstChild("RootPart", true) or model.PrimaryPart or parts[1]
	if not root or not root:IsA("BasePart") then return nil end
	local anchoredComponents = {}
	local function anchorComponent(part)
		if anchoredComponents[part] then return end
		anchoredComponents[part] = true
		for _, connected in part:GetConnectedParts(true) do
			anchoredComponents[connected] = true
		end
		part.Anchored = true
	end
	anchorComponent(root)
	for _, part in parts do anchorComponent(part) end
	return root
end

local function loadAnimations(state)
	local model = state.model
	local controller = model:FindFirstChildWhichIsA("AnimationController", true)
		or model:FindFirstChildWhichIsA("Humanoid", true)
	if not controller then return end
	local animator = controller:FindFirstChildOfClass("Animator")
	for _, animation in model:GetDescendants() do
		local name = animation.Name:lower()
		if animation:IsA("Animation") and animation.AnimationId ~= "" and (name == "idle" or name == "walk") then
			if not animator then
				animator = Instance.new("Animator")
				animator.Parent = controller
			end
			local success, track = pcall(function() return animator:LoadAnimation(animation) end)
			if success then
				if states[state.player] ~= state then track:Destroy() return end
				track.Looped = true
				track.Priority = name == "walk" and Enum.AnimationPriority.Movement or Enum.AnimationPriority.Idle
				if state.tracks[name] then state.tracks[name]:Destroy() end
				state.tracks[name] = track
				track:Play(0.2, name == "idle" and 1 or 0)
			end
		end
	end
	if states[state.player] ~= state then return end
	if state.tracks.idle then state.tracks.idle:AdjustWeight(state.walkMode and state.tracks.walk and 0 or 1, 0.2) end
	if state.tracks.walk then state.tracks.walk:AdjustWeight(state.walkMode and 1 or 0, 0.2) end
end

local function addSparkles(state, root, lower, upper)
	local colour = effectColours[state.id]
	if not colour then return end
	local attachment = Instance.new("Attachment")
	attachment.Name = "PetSparkleOrigin"
	attachment.Position = root.CFrame:PointToObjectSpace(Vector3.new(
		(lower.X + upper.X) * 0.5, lower.Y + (upper.Y - lower.Y) * 0.7, (lower.Z + upper.Z) * 0.5
	))
	attachment.Parent = root
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "PetSparkles"
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(colour)
	emitter.Rate = 1.5
	emitter.Lifetime = NumberRange.new(0.45, 0.8)
	emitter.Speed = NumberRange.new(0.15, 0.45)
	emitter.SpreadAngle = Vector2.new(160, 160)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.2, 0.18),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Rotation = NumberRange.new(-180, 180)
	emitter.RotSpeed = NumberRange.new(-35, 35)
	emitter.LightEmission = 0.35
	emitter.LightInfluence = 0.5
	emitter.Enabled = false
	emitter.Parent = attachment
	state.emitter = emitter
end

local function createState(player, id, character)
	local template = assets:FindFirstChild(id)
	if not template or not template:IsA("Model") then return end
	local model = template:Clone()
	model.Name = tostring(player.UserId) .. "_" .. id
	model:SetAttribute("PetOwnerUserId", player.UserId)
	local restRotation = model:GetPivot().Rotation
	model:PivotTo(restRotation)
	local lower, upper = visibleBounds(model)
	if not lower then model:Destroy() return end
	local size = upper - lower
	local largest = math.max(size.X, size.Y, size.Z)
	if largest > MAX_SIZE then
		model:ScaleTo(model:GetScale() * MAX_SIZE / largest)
		lower, upper = visibleBounds(model)
	end
	model.Parent = visuals
	local root = prepareParts(model)
	if not root then model:Destroy() return end
	local state = {
		player = player, id = id, character = character, model = model, tracks = {},
		phase = (player.UserId % 97) * math.pi * 2 / 97,
		position = nil, ground = nil, groundClock = 1, movement = 0,
		facing = CFrame.identity, walkMode = false,
		restRotation = restRotation,
		centreOffset = CFrame.new(-(lower.X + upper.X) * 0.5, -lower.Y, -(lower.Z + upper.Z) * 0.5),
		facingOffset = CFrame.Angles(0, math.rad(tonumber(template:GetAttribute("PetFacingYaw")) or 0), 0),
	}
	states[player] = state
	addSparkles(state, root, lower, upper)
	task.spawn(loadAnimations, state)
	return state
end

local function characterRoot(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
		return root, humanoid, character
	end
	return nil
end

local function reconcile()
	local camera = workspace.CurrentCamera
	local origin = camera and camera.CFrame.Position
	local localRoot = characterRoot(localPlayer)
	if localRoot then origin = localRoot.Position end
	if not origin then return end
	local candidates = {}
	local exclusions = { visuals }
	for _, player in Players:GetPlayers() do
		if player.Character then table.insert(exclusions, player.Character) end
		local id = player:GetAttribute("PCPet")
		local root, _, character = characterRoot(player)
		if type(id) == "string" and id:match("^P%d%d$") and root then
			local distance = (root.Position - origin).Magnitude
			if distance < MAX_DISTANCE or player == localPlayer then
				table.insert(candidates, { player = player, id = id, character = character,
					distance = player == localPlayer and -1 or distance })
			end
		end
	end
	raycastParams.FilterDescendantsInstances = exclusions
	table.sort(candidates, function(a, b) return a.distance < b.distance end)
	local wanted = {}
	for index = 1, math.min(MAX_VISIBLE, #candidates) do
		local entry = candidates[index]
		wanted[entry.player] = true
		local state = states[entry.player]
		if state and (state.id ~= entry.id or state.character ~= entry.character or not state.model.Parent) then
			release(entry.player)
			state = nil
		end
		if not state then createState(entry.player, entry.id, entry.character) end
	end
	for player in states do
		if not wanted[player] then release(player) end
	end
end

local function updateState(state, delta, observer, reducedMotion, effectsEnabled)
	local root, humanoid, character = characterRoot(state.player)
	if not root or character ~= state.character then release(state.player) return end
	local side = state.player.UserId % 2 == 0 and 2.4 or -2.4
	local target = root.CFrame:PointToWorldSpace(Vector3.new(side, 0, 3.4))
	local from = root.Position
	local obstruction = workspace:Raycast(from, horizontal(target - from), raycastParams)
	if obstruction then
		target = obstruction.Position + obstruction.Normal * 0.9
	end
	target = horizontal(target)
	local teleported = not state.position or (target - state.position).Magnitude > 35
	if teleported then
		state.position = target
		state.ground = nil
		state.groundClock = 1
	end
	local previous = state.position
	state.position = previous:Lerp(target, smoothAlpha(7.5, delta))
	local speed = (state.position - previous).Magnitude / math.max(delta, 0.001)
	state.movement += (math.clamp(speed / 9, 0, 1) - state.movement) * smoothAlpha(7, delta)
	local direction = horizontal(target - previous)
	if direction.Magnitude < 0.35 then direction = horizontal(root.CFrame.LookVector) end
	if direction.Magnitude > 0.01 then
		local desiredFacing = CFrame.lookAt(Vector3.zero, direction.Unit)
		state.facing = teleported and desiredFacing or state.facing:Lerp(desiredFacing, smoothAlpha(9, delta))
	end
	state.groundClock += delta
	if state.groundClock >= 0.08 then
		state.groundClock = 0
		local rayOrigin = Vector3.new(state.position.X, root.Position.Y + 6, state.position.Z)
		local result = workspace:Raycast(rayOrigin, Vector3.new(0, -64, 0), raycastParams)
		state.groundTarget = result and result.Position.Y or root.Position.Y - humanoid.HipHeight - root.Size.Y * 0.5
	end
	local groundTarget = state.groundTarget or root.Position.Y - 3
	state.ground = state.ground and state.ground + (groundTarget - state.ground) * smoothAlpha(18, delta) or groundTarget
	state.phase += delta * math.pi * 2 * (0.85 + state.movement * 1.75)
	local hover = hoveringPets[state.id]
	local hop = (1 - math.cos(state.phase)) * 0.5
	local bounce = hover and 0.35 + hop * 0.16 or hop * (0.06 + state.movement * 0.45)
	local roll = math.sin(state.phase * 0.5) * math.rad(1 + state.movement * 3)
	local pitch = math.sin(state.phase) * math.rad(state.movement * 3)
	if reducedMotion then bounce *= 0.2 roll = 0 pitch = 0 end
	local position = Vector3.new(state.position.X, state.ground + 0.12 + bounce, state.position.Z)
	state.model:PivotTo(CFrame.new(position) * state.facing * CFrame.Angles(pitch, 0, roll)
		* state.centreOffset * state.facingOffset * state.restRotation)
	local walking = state.movement > (state.walkMode and 0.12 or 0.25)
	if walking ~= state.walkMode then
		state.walkMode = walking
		if state.tracks.idle then state.tracks.idle:AdjustWeight(walking and state.tracks.walk and 0 or 1, 0.2) end
		if state.tracks.walk then state.tracks.walk:AdjustWeight(walking and 1 or 0, 0.2) end
	end
	if state.tracks.walk then state.tracks.walk:AdjustSpeed(math.clamp(speed / 8, 0.6, 1.6)) end
	if state.emitter then
		state.emitter.Enabled = effectsEnabled and not reducedMotion and (position - observer).Magnitude < 70
	end
end

local reconcileClock = 1
table.insert(connections, Players.PlayerRemoving:Connect(release))
table.insert(connections, RunService.Heartbeat:Connect(function(delta)
	reconcileClock += delta
	if reconcileClock >= 0.3 then
		reconcileClock = 0
		reconcile()
	end
end))
table.insert(connections, RunService.RenderStepped:Connect(function(delta)
	local camera = workspace.CurrentCamera
	if not camera then return end
	local reducedMotion = localPlayer:GetAttribute("PCReducedMotion") == true
	local effectsEnabled = localPlayer:GetAttribute("PCPetEffectsEnabled") ~= false
	for _, state in states do
		updateState(state, math.min(delta, 0.1), camera.CFrame.Position, reducedMotion, effectsEnabled)
	end
end))

script.Destroying:Connect(function()
	for _, connection in connections do connection:Disconnect() end
	for player in states do release(player) end
	visuals:Destroy()
end)

]====],after=[====[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local assets = ReplicatedStorage:WaitForChild("PlaygroundCosmeticAssets")
local visuals = Instance.new("Folder")
visuals.Name = "PlaygroundPetVisuals"
visuals.Parent = workspace

local states = {}
local connections = {}
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true
raycastParams.RespectCanCollide = true

local MAX_DISTANCE = 150
local MAX_VISIBLE = 24
local MAX_SIZE = 3
local effectColours = {
	P04 = Color3.fromRGB(251, 165, 222),
	P09 = Color3.fromRGB(151, 212, 255),
	P12 = Color3.fromRGB(139, 255, 214),
	P15 = Color3.fromRGB(255, 206, 232),
	P18 = Color3.fromRGB(255, 164, 69),
	P19 = Color3.fromRGB(182, 190, 255),
	P20 = Color3.fromRGB(255, 224, 115),
}
local hoveringPets = { P10 = true, P12 = true, P14 = true, P19 = true }

local function horizontal(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

local function smoothAlpha(speed, delta)
	return 1 - math.exp(-speed * delta)
end

local function visibleBounds(model)
	local lower = Vector3.new(math.huge, math.huge, math.huge)
	local upper = -lower
	local count = 0
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 1 then
			count += 1
			for x = -1, 1, 2 do
				for y = -1, 1, 2 do
					for z = -1, 1, 2 do
						local corner = part.CFrame:PointToWorldSpace(part.Size * Vector3.new(x, y, z) * 0.5)
						lower = lower:Min(corner)
						upper = upper:Max(corner)
					end
				end
			end
		end
	end
	if count == 0 then return nil end
	return lower, upper
end

local function release(player)
	local state = states[player]
	if not state then return end
	states[player] = nil
	for _, track in state.tracks do
		track:Stop(0)
		track:Destroy()
	end
	state.model:Destroy()
end

local function prepareParts(model)
	local parts = {}
	for _, object in model:GetDescendants() do
		if object:IsA("BaseScript") then
			object.Enabled = false
		elseif object:IsA("BasePart") then
			object.CanCollide = false
			object.CanTouch = false
			object.CanQuery = false
			object.Massless = true
			object.Anchored = false
			table.insert(parts, object)
		elseif object:IsA("Humanoid") then
			object.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			object.AutoRotate = false
		end
	end
	local root = model:FindFirstChild("RootPart", true) or model.PrimaryPart or parts[1]
	if not root or not root:IsA("BasePart") then return nil end
	local anchoredComponents = {}
	local function anchorComponent(part)
		if anchoredComponents[part] then return end
		anchoredComponents[part] = true
		for _, connected in part:GetConnectedParts(true) do
			anchoredComponents[connected] = true
		end
		part.Anchored = true
	end
	anchorComponent(root)
	for _, part in parts do anchorComponent(part) end
	return root
end

local function loadAnimations(state)
	local model = state.model
	local controller = model:FindFirstChildWhichIsA("AnimationController", true)
		or model:FindFirstChildWhichIsA("Humanoid", true)
	if not controller then return end
	local animator = controller:FindFirstChildOfClass("Animator")
	for _, animation in model:GetDescendants() do
		local name = animation.Name:lower()
		if animation:IsA("Animation") and animation.AnimationId ~= "" and (name == "idle" or name == "walk") then
			if not animator then
				animator = Instance.new("Animator")
				animator.Parent = controller
			end
			local success, track = pcall(function() return animator:LoadAnimation(animation) end)
			if success then
				if states[state.player] ~= state then track:Destroy() return end
				track.Looped = true
				track.Priority = name == "walk" and Enum.AnimationPriority.Movement or Enum.AnimationPriority.Idle
				if state.tracks[name] then state.tracks[name]:Destroy() end
				state.tracks[name] = track
				track:Play(0.2, name == "idle" and 1 or 0)
			end
		end
	end
	if states[state.player] ~= state then return end
	if state.tracks.idle then state.tracks.idle:AdjustWeight(state.walkMode and state.tracks.walk and 0 or 1, 0.2) end
	if state.tracks.walk then state.tracks.walk:AdjustWeight(state.walkMode and 1 or 0, 0.2) end
end

local function addSparkles(state, root, lower, upper)
	local colour = effectColours[state.id]
	if not colour then return end
	local attachment = Instance.new("Attachment")
	attachment.Name = "PetSparkleOrigin"
	attachment.Position = root.CFrame:PointToObjectSpace(Vector3.new(
		(lower.X + upper.X) * 0.5, lower.Y + (upper.Y - lower.Y) * 0.7, (lower.Z + upper.Z) * 0.5
	))
	attachment.Parent = root
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "PetSparkles"
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(colour)
	emitter.Rate = 1.5
	emitter.Lifetime = NumberRange.new(0.45, 0.8)
	emitter.Speed = NumberRange.new(0.15, 0.45)
	emitter.SpreadAngle = Vector2.new(160, 160)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.2, 0.18),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Rotation = NumberRange.new(-180, 180)
	emitter.RotSpeed = NumberRange.new(-35, 35)
	emitter.LightEmission = 0.35
	emitter.LightInfluence = 0.5
	emitter.Enabled = false
	emitter.Parent = attachment
	state.emitter = emitter
end

local function createState(player, id, character)
	local template = assets:FindFirstChild(id)
	if not template or not template:IsA("Model") then return end
	local model = template:Clone()
	model.Name = tostring(player.UserId) .. "_" .. id
	model:SetAttribute("PetOwnerUserId", player.UserId)
	local restRotation = model:GetPivot().Rotation
	model:PivotTo(restRotation)
	local lower, upper = visibleBounds(model)
	if not lower then model:Destroy() return end
	local size = upper - lower
	local largest = math.max(size.X, size.Y, size.Z)
	if largest > MAX_SIZE then
		model:ScaleTo(model:GetScale() * MAX_SIZE / largest)
		lower, upper = visibleBounds(model)
	end
	model.Parent = visuals
	local root = prepareParts(model)
	if not root then model:Destroy() return end
	local state = {
		player = player, id = id, character = character, model = model, tracks = {},
		phase = (player.UserId % 97) * math.pi * 2 / 97,
		position = nil, ground = nil, groundClock = 1, movement = 0,
		facing = CFrame.identity, walkMode = false,
		restRotation = restRotation,
		centreOffset = CFrame.new(-(lower.X + upper.X) * 0.5, -lower.Y, -(lower.Z + upper.Z) * 0.5),
		facingOffset = CFrame.Angles(0, math.rad(tonumber(template:GetAttribute("PetFacingYaw")) or 0), 0),
	}
	states[player] = state
	addSparkles(state, root, lower, upper)
	task.spawn(loadAnimations, state)
	return state
end

local function characterRoot(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
		return root, humanoid, character
	end
	return nil
end

local function reconcile()
	local camera = workspace.CurrentCamera
	local origin = camera and camera.CFrame.Position
	local localRoot = characterRoot(localPlayer)
	if localRoot then origin = localRoot.Position end
	if not origin then return end
	local candidates = {}
	local exclusions = { visuals }
	for _, player in Players:GetPlayers() do
		if player.Character then table.insert(exclusions, player.Character) end
		local id = player:GetAttribute("PCPet")
		local root, _, character = characterRoot(player)
		if type(id) == "string" and id:match("^P%d%d$") and root then
			local distance = (root.Position - origin).Magnitude
			if distance < MAX_DISTANCE or player == localPlayer then
				table.insert(candidates, { player = player, id = id, character = character,
					distance = player == localPlayer and -1 or distance })
			end
		end
	end
	raycastParams.FilterDescendantsInstances = exclusions
	table.sort(candidates, function(a, b) return a.distance < b.distance end)
	local wanted = {}
	for index = 1, math.min(MAX_VISIBLE, #candidates) do
		local entry = candidates[index]
		wanted[entry.player] = true
		local state = states[entry.player]
		if state and (state.id ~= entry.id or state.character ~= entry.character or not state.model.Parent) then
			release(entry.player)
			state = nil
		end
		if not state then createState(entry.player, entry.id, entry.character) end
	end
	for player in states do
		if not wanted[player] then release(player) end
	end
end

local function updateState(state, delta, observer, reducedMotion, effectsEnabled)
	local root, humanoid, character = characterRoot(state.player)
	if not root or character ~= state.character then release(state.player) return end
	local side = state.player.UserId % 2 == 0 and 2.4 or -2.4
	local target = root.CFrame:PointToWorldSpace(Vector3.new(side, 0, 3.4))
	local from = root.Position
	local obstruction = workspace:Raycast(from, horizontal(target - from), raycastParams)
	if obstruction then
		target = obstruction.Position + obstruction.Normal * 0.9
	end
	target = horizontal(target)
	local teleported = not state.position or (target - state.position).Magnitude > 35
	if teleported then
		state.position = target
		state.ground = nil
		state.groundClock = 1
	end
	local previous = state.position
	state.position = previous:Lerp(target, smoothAlpha(7.5, delta))
	local speed = (state.position - previous).Magnitude / math.max(delta, 0.001)
	state.movement += (math.clamp(speed / 9, 0, 1) - state.movement) * smoothAlpha(7, delta)
	local direction = horizontal(target - previous)
	if direction.Magnitude < 0.35 then direction = horizontal(root.CFrame.LookVector) end
	if direction.Magnitude > 0.01 then
		local desiredFacing = CFrame.lookAt(Vector3.zero, direction.Unit)
		state.facing = teleported and desiredFacing or state.facing:Lerp(desiredFacing, smoothAlpha(9, delta))
	end
	state.groundClock += delta
	if state.groundClock >= 0.08 then
		state.groundClock = 0
		local rayOrigin = Vector3.new(state.position.X, root.Position.Y + 6, state.position.Z)
		local result = workspace:Raycast(rayOrigin, Vector3.new(0, -64, 0), raycastParams)
		local foot = character:FindFirstChild("LeftFoot") or character:FindFirstChild("Left Leg")
		local floor = foot and foot:IsA("BasePart") and foot.Position.Y - foot.Size.Y * 0.5 or root.Position.Y - 3
		state.groundTarget = result and result.Position.Y or floor
	end
	local groundTarget = state.groundTarget or root.Position.Y - 3
	state.ground = state.ground and state.ground + (groundTarget - state.ground) * smoothAlpha(18, delta) or groundTarget
	state.phase += delta * math.pi * 2 * (0.85 + state.movement * 1.75)
	local hover = hoveringPets[state.id]
	local hop = (1 - math.cos(state.phase)) * 0.5
	local bounce = hover and 0.35 + hop * 0.16 or hop * (0.06 + state.movement * 0.45)
	local roll = math.sin(state.phase * 0.5) * math.rad(1 + state.movement * 3)
	local pitch = math.sin(state.phase) * math.rad(state.movement * 3)
	if reducedMotion then bounce *= 0.2 roll = 0 pitch = 0 end
	local position = Vector3.new(state.position.X, state.ground + 0.12 + bounce, state.position.Z)
	state.model:PivotTo(CFrame.new(position) * state.facing * CFrame.Angles(pitch, 0, roll)
		* state.centreOffset * state.facingOffset * state.restRotation)
	local walking = state.movement > (state.walkMode and 0.12 or 0.25)
	if walking ~= state.walkMode then
		state.walkMode = walking
		if state.tracks.idle then state.tracks.idle:AdjustWeight(walking and state.tracks.walk and 0 or 1, 0.2) end
		if state.tracks.walk then state.tracks.walk:AdjustWeight(walking and 1 or 0, 0.2) end
	end
	if state.tracks.walk then state.tracks.walk:AdjustSpeed(math.clamp(speed / 8, 0.6, 1.6)) end
	if state.emitter then
		state.emitter.Enabled = effectsEnabled and not reducedMotion and (position - observer).Magnitude < 70
	end
end

local reconcileClock = 1
table.insert(connections, Players.PlayerRemoving:Connect(release))
table.insert(connections, RunService.Heartbeat:Connect(function(delta)
	reconcileClock += delta
	if reconcileClock >= 0.3 then
		reconcileClock = 0
		reconcile()
	end
end))
table.insert(connections, RunService.RenderStepped:Connect(function(delta)
	local camera = workspace.CurrentCamera
	if not camera then return end
	local reducedMotion = localPlayer:GetAttribute("PCReducedMotion") == true
	local effectsEnabled = localPlayer:GetAttribute("PCPetEffectsEnabled") ~= false
	for _, state in states do
		updateState(state, math.min(delta, 0.1), camera.CFrame.Position, reducedMotion, effectsEnabled)
	end
end))

script.Destroying:Connect(function()
	for _, connection in connections do connection:Disconnect() end
	for player in states do release(player) end
	visuals:Destroy()
end)

]====]})
table.insert(entries,{target=game["StarterGui"]["PlaygroundToyHotbar"]["Controller"],before=[====[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContentProvider = game:GetService("ContentProvider")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer
local gui = script.Parent
local bar = gui:WaitForChild("Bar")
local catalogObject = ReplicatedStorage:WaitForChild("PlaygroundCatalog", 10)
if not catalogObject then bar.Visible = false return end
local catalog = require(catalogObject)
local connections = {}
local slots = {}
local alive = true
local pending = false
local requestToken = 0
local notice = ""
local noticeUntil = 0
local activeIndex = 0
local activeId = ""
local refresh
local backpackSuppressed = false
local savedBackpackState = nil

local function showNativeBackpack(show)
	if not show and not backpackSuppressed then
		local ok, previous = pcall(function() return StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack) end)
		if not ok then return end
		local applied = pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end)
		if applied then savedBackpackState = previous backpackSuppressed = true end
	elseif show and backpackSuppressed then
		local applied = pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, savedBackpackState) end)
		if applied then backpackSuppressed = false savedBackpackState = nil end
	end
end

local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end

local function inRound()
	return player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true or player:GetAttribute("MDParticipating") == true
end

local function modalOpen()
	local shell = player.PlayerGui:FindFirstChild("PlaygroundShell")
	if shell then
		for _, name in ipairs({ "ShopPanel", "VotePanel", "CompactVotePanel" }) do
			local panel = shell:FindFirstChild(name)
			if panel and panel.Visible then return true end
		end
	end
	local admin = player.PlayerGui:FindFirstChild("PlaygroundAdminPanel")
	local adminHub = admin and admin:FindFirstChild("AdminHub")
	if admin and admin.Enabled and adminHub and adminHub.Visible then return true end
	return GuiService.MenuIsOpen
end

local function usable()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return player:GetAttribute("PCDataReady") == true and not inRound() and humanoid and humanoid.Health > 0
end

local function tell(message, seconds)
	notice = tostring(message or "")
	noticeUntil = workspace:GetServerTimeNow() + (seconds or 3)
end

local function cooldownEndsAt(id)
	local now = workspace:GetServerTimeNow()
	local ember = tonumber(player:GetAttribute("PCToyEmberUntil")) or 0
	local attribute = id == "M07" and ember > now and "PCToyEmberShotUntil" or "PCToyCooldown_" .. id
	return tonumber(player:GetAttribute(attribute)) or 0
end

local function bounds(model)
	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency < 1 then
			for x = -1, 1, 2 do for y = -1, 1, 2 do for z = -1, 1, 2 do
				local point = part.CFrame:PointToWorldSpace(part.Size * Vector3.new(x, y, z) * 0.5)
				low = low:Min(point)
				high = high:Max(point)
			end end end
		end
	end
	if low.X == math.huge then return Vector3.zero, Vector3.one end
	return (low + high) * 0.5, high - low
end

local function framePreview(record)
	if not record.model or not record.model.Parent then return end
	local viewport = record.button.Preview
	local camera = viewport.PreviewCamera
	local aspect = math.max(0.2, viewport.AbsoluteSize.X / math.max(1, viewport.AbsoluteSize.Y))
	local angle = math.rad(camera.FieldOfView * 0.5)
	local distance = record.radius / math.sin(math.min(angle, math.atan(math.tan(angle) * aspect))) * 1.1
	camera.CFrame = CFrame.lookAt(Vector3.new(0.5, 0.2, -1).Unit * distance, Vector3.zero)
	viewport.CurrentCamera = camera
end

local function preview(record, id)
	if record.id == id and (id == "" or record.model) then return end
	record.id = id
	record.generation += 1
	local generation = record.generation
	local world = record.button.Preview.World
	for _, child in ipairs(world:GetChildren()) do child:Destroy() end
	record.model = nil
	record.button.Preview.Visible = id ~= ""
	record.button.PreviewNote.Visible = false
	if id == "" then return end
	local assets = ReplicatedStorage:FindFirstChild("PlaygroundCosmeticAssets")
	local original = assets and assets:FindFirstChild(id)
	if not original or not original:IsA("Model") then
		record.button.PreviewNote.Text = "NO PREVIEW"
		record.button.PreviewNote.Visible = true
		return
	end
	local model = original:Clone()
	model.Name = "ToyPreview"
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("LuaSourceContainer") then child:Destroy()
		elseif child:IsA("BasePart") then
			child.Anchored = true
			child.CanCollide = false
			child.CanTouch = false
			child.CanQuery = false
		elseif child:IsA("ParticleEmitter") or child:IsA("Trail") then child.Enabled = false end
	end
	local center, size = bounds(model)
	model:PivotTo(CFrame.new(-center) * model:GetPivot())
	model.Parent = world
	record.model = model
	record.radius = math.max(0.05, size.Magnitude * 0.5)
	framePreview(record)
	local complete = false
	task.delay(8, function()
		if alive and generation == record.generation and not complete then
			record.button.PreviewNote.Text = "PREVIEW DELAYED"
			record.button.PreviewNote.Visible = true
		end
	end)
	task.spawn(function()
		local loaded = true
		local ok = pcall(function()
			ContentProvider:PreloadAsync({ model }, function(contentId, status)
				if contentId ~= "" and status ~= Enum.AssetFetchStatus.Success then loaded = false end
			end)
		end)
		complete = true
		if not alive or generation ~= record.generation or not world.Parent then return end
		record.button.PreviewNote.Visible = not ok or not loaded
		record.button.PreviewNote.Text = "PREVIEW DELAYED"
		model.Parent = nil
		model.Parent = world
		framePreview(record)
	end)
end

local function syncLoadout()
	if not alive then return end
	for index, record in ipairs(slots) do
		local id = player:GetAttribute("PCToySlot" .. tostring(index))
		if typeof(id) ~= "string" or not catalog.ById[id] then id = "" end
		preview(record, id)
		record.button.ItemName.Text = id ~= "" and catalog.ById[id].name or "EMPTY"
	end
	activeIndex = math.clamp(math.floor(tonumber(player:GetAttribute("PCToyIndex")) or 0), 0, 4)
	activeId = slots[activeIndex] and slots[activeIndex].id or ""
	refresh()
end

local function invoke(remoteName, action, payload, itemId)
	if pending or not alive then return end
	local remote = ReplicatedStorage:FindFirstChild(remoteName)
	if not remote or not remote:IsA("RemoteFunction") then tell("Toys are getting ready.") refresh() return end
	pending = true
	requestToken += 1
	local token = requestToken
	refresh()
	task.delay(8, function()
		if not alive or requestToken ~= token or not pending then return end
		requestToken += 1
		pending = false
		tell("That took too long. Try again.")
		refresh()
	end)
	task.spawn(function()
		local ok, reply = pcall(function() return remote:InvokeServer(action, payload) end)
		if not alive or requestToken ~= token then return end
		pending = false
		if ok and typeof(reply) == "table" then
			if reply.message then tell(reply.message) elseif not reply.ok then tell("That did not go through.") end
		else
			tell("That did not go through. Try again.")
		end
		refresh()
	end)
end

local function aimAt(screenPosition)
	local camera = workspace.CurrentCamera
	if not camera then return nil end
	local position = screenPosition or camera.ViewportSize * 0.5
	local ray = screenPosition and camera:ScreenPointToRay(position.X, position.Y) or camera:ViewportPointToRay(position.X, position.Y)
	local parameters = RaycastParams.new()
	parameters.FilterType = Enum.RaycastFilterType.Exclude
	parameters.FilterDescendantsInstances = player.Character and { player.Character } or {}
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, parameters)
	return hit and hit.Position or ray.Origin + ray.Direction * 150
end

local function useToy(position)
	if not gui.Enabled or not bar.Visible or not usable() or modalOpen() or activeId == "" or pending then return end
	local item = catalog.ById[activeId]
	if item and item.toyActionPending then tell("This toy's action is coming soon.") refresh() return end
	if cooldownEndsAt(activeId) > workspace:GetServerTimeNow() then return end
	invoke("PlaygroundToyRequest", "Use", aimAt(position), activeId)
end

local function selectToy(index)
	local record = slots[index]
	if not gui.Enabled or not record or record.id == "" or not bar.Visible or not usable() or modalOpen() or pending then return end
	invoke("PlaygroundShopRequest", "SelectToy", index)
end

refresh = function()
	if not alive then return end
	local hasToy = false
	for _, record in ipairs(slots) do if record.id ~= "" then hasToy = true break end end
	local available = usable()
	bar.Visible = hasToy and player:GetAttribute("PCDataReady") == true and not inRound() and not modalOpen()
	showNativeBackpack(not (hasToy and player:GetAttribute("PCDataReady") == true and not inRound() and gui.Enabled))
	local now = workspace:GetServerTimeNow()
	local remaining = math.max(0, cooldownEndsAt(activeId) - now)
	local item = catalog.ById[activeId]
	local actionPending = item and item.toyActionPending == true
	local character = player.Character
	local heldTool = character and character:FindFirstChildOfClass("Tool")
	local heldId = heldTool and heldTool:GetAttribute("CatalogId")
	for index, record in ipairs(slots) do
		local selected = index == activeIndex and record.id ~= ""
		local selectionTag = record.button:FindFirstChild("Selected")
		selectionTag.Visible = selected
		selectionTag.Text = selected and heldId == record.id and "HELD" or "READY"
		record.button.Key.TextColor3 = selected and Color3.fromRGB(255, 215, 74) or Color3.fromRGB(255, 249, 224)
		record.button.Active = available and not pending and record.id ~= ""
		record.button.Selectable = record.button.Active
		record.button.ReusableSkin.ImageColor3 = record.id == "" and Color3.fromRGB(155, 155, 155) or Color3.new(1, 1, 1)
	end
	bar.Use.Active = available and not pending and activeId ~= "" and remaining <= 0 and not actionPending
	bar.Use.Selectable = bar.Use.Active
	local label = pending and "WAIT..." or actionPending and "SOON" or remaining > 0 and string.format("%.1fs", remaining) or "USE"
	bar.Use.Text = label
	bar.Use.LiveCaption.Text = label
	bar.Use.ReusableSkin.ImageColor3 = bar.Use.Active and Color3.new(1, 1, 1) or Color3.fromRGB(165, 165, 165)
	bar.Status.Text = now < noticeUntil and notice or not available and "Respawning..." or activeId == "" and "Select a toy" or actionPending and "Action coming soon" or UserInputService.TouchEnabled and "Tap a slot, then USE" or "1–4 select • click to use"
	local ember = tonumber(player:GetAttribute("PCToyEmberUntil")) or 0
	gui.Crosshair.Visible = bar.Visible and available and (activeId == "M10" or activeId == "M07" and ember > now)
end

for index = 1, 4 do
	local button = bar.Slots:WaitForChild("Slot" .. tostring(index))
	local record = { button = button, id = nil, generation = 0 }
	table.insert(slots, record)
	connect(button.Activated, function() selectToy(index) end)
	connect(button.Preview:GetPropertyChangedSignal("AbsoluteSize"), function() framePreview(record) end)
end
connect(bar.Use.Activated, function() useToy(nil) end)
local numberKeys = { [Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3, [Enum.KeyCode.Four] = 4 }
connect(UserInputService.InputBegan, function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	local index = numberKeys[input.KeyCode]
	if index then selectToy(index)
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then useToy(UserInputService:GetMouseLocation())
	elseif input.KeyCode == Enum.KeyCode.ButtonR2 then useToy(nil) end
end)
connect(UserInputService.TouchTapInWorld, function(position, processed)
	if not processed and not UserInputService:GetFocusedTextBox() then useToy(position) end
end)
connect(player:GetAttributeChangedSignal("PCToyLoadoutVersion"), syncLoadout)
for _, key in ipairs({ "PCDataReady", "BBParticipating", "TGParticipating", "MDParticipating", "PCToyEmberUntil", "PCToyEmberShotUntil" }) do
	connect(player:GetAttributeChangedSignal(key), refresh)
end
for index = 1, 15 do connect(player:GetAttributeChangedSignal(string.format("PCToyCooldown_M%02d", index)), refresh) end
local elapsed = 0
connect(RunService.Heartbeat, function(delta)
	elapsed += delta
	if elapsed >= 0.1 then elapsed = 0 refresh() end
end)
connect(script.Destroying, function()
	alive = false
	showNativeBackpack(true)
	bar.Visible = false
	gui.Crosshair.Visible = false
	requestToken += 1
	for _, connection in ipairs(connections) do connection:Disconnect() end
	for _, record in ipairs(slots) do
		record.generation += 1
		if record.model then record.model:Destroy() end
	end
end)
syncLoadout()

]====],after=[====[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContentProvider = game:GetService("ContentProvider")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer
local gui = script.Parent
local bar = gui:WaitForChild("Bar")
local catalogObject = ReplicatedStorage:WaitForChild("PlaygroundCatalog", 10)
if not catalogObject then bar.Visible = false return end
local catalog = require(catalogObject)
local connections = {}
local slots = {}
local alive = true
local pending = false
local requestToken = 0
local notice = ""
local noticeUntil = 0
local activeIndex = 0
local activeId = ""
local refresh
local backpackSuppressed = false
local savedBackpackState = nil

local function showNativeBackpack(show)
	if not show and not backpackSuppressed then
		local ok, previous = pcall(function() return StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack) end)
		if not ok then return end
		local applied = pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end)
		if applied then savedBackpackState = previous backpackSuppressed = true end
	elseif show and backpackSuppressed then
		local applied = pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, savedBackpackState) end)
		if applied then backpackSuppressed = false savedBackpackState = nil end
	end
end

local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end

local function inRound()
	return player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true or player:GetAttribute("MDParticipating") == true
end

local function modalOpen()
	local shell = player.PlayerGui:FindFirstChild("PlaygroundShell")
	if shell then
		for _, name in ipairs({ "ShopPanel", "VotePanel", "CompactVotePanel" }) do
			local panel = shell:FindFirstChild(name)
			if panel and panel.Visible then return true end
		end
	end
	local admin = player.PlayerGui:FindFirstChild("PlaygroundAdminPanel")
	local adminHub = admin and admin:FindFirstChild("AdminHub")
	if admin and admin.Enabled and adminHub and adminHub.Visible then return true end
	return GuiService.MenuIsOpen
end

local function usable()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return player:GetAttribute("PCDataReady") == true and not inRound() and humanoid and humanoid.Health > 0
end

local function tell(message, seconds)
	notice = tostring(message or "")
	noticeUntil = workspace:GetServerTimeNow() + (seconds or 3)
end

local function cooldownEndsAt(id)
	local now = workspace:GetServerTimeNow()
	local ember = tonumber(player:GetAttribute("PCToyEmberUntil")) or 0
	local attribute = id == "M07" and ember > now and "PCToyEmberShotUntil" or "PCToyCooldown_" .. id
	return tonumber(player:GetAttribute(attribute)) or 0
end

local function bounds(model)
	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency < 1 then
			for x = -1, 1, 2 do for y = -1, 1, 2 do for z = -1, 1, 2 do
				local point = part.CFrame:PointToWorldSpace(part.Size * Vector3.new(x, y, z) * 0.5)
				low = low:Min(point)
				high = high:Max(point)
			end end end
		end
	end
	if low.X == math.huge then return Vector3.zero, Vector3.one end
	return (low + high) * 0.5, high - low
end

local function framePreview(record)
	if not record.model or not record.model.Parent then return end
	local viewport = record.button.Preview
	local camera = viewport:FindFirstChild("PreviewCamera")
	if not camera or not camera:IsA("Camera") then
		camera = Instance.new("Camera")
		camera.Name = "PreviewCamera"
		camera.FieldOfView = viewport:GetAttribute("PreviewFieldOfView") or 35
		camera.Parent = viewport
	end
	local aspect = math.max(0.2, viewport.AbsoluteSize.X / math.max(1, viewport.AbsoluteSize.Y))
	local angle = math.rad(camera.FieldOfView * 0.5)
	local distance = record.radius / math.sin(math.min(angle, math.atan(math.tan(angle) * aspect))) * 1.1
	camera.CFrame = CFrame.lookAt(Vector3.new(0.5, 0.2, -1).Unit * distance, Vector3.zero)
	viewport.CurrentCamera = camera
end

local function preview(record, id)
	if record.id == id and (id == "" or record.model) then return end
	record.id = id
	record.generation += 1
	local generation = record.generation
	local world = record.button.Preview.World
	for _, child in ipairs(world:GetChildren()) do child:Destroy() end
	record.model = nil
	record.button.Preview.Visible = id ~= ""
	record.button.PreviewNote.Visible = false
	if id == "" then return end
	local assets = ReplicatedStorage:FindFirstChild("PlaygroundCosmeticAssets")
	local original = assets and assets:FindFirstChild(id)
	if not original or not original:IsA("Model") then
		record.button.PreviewNote.Text = "NO PREVIEW"
		record.button.PreviewNote.Visible = true
		return
	end
	local model = original:Clone()
	model.Name = "ToyPreview"
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("LuaSourceContainer") then child:Destroy()
		elseif child:IsA("BasePart") then
			child.Anchored = true
			child.CanCollide = false
			child.CanTouch = false
			child.CanQuery = false
		elseif child:IsA("ParticleEmitter") or child:IsA("Trail") then child.Enabled = false end
	end
	local center, size = bounds(model)
	model:PivotTo(CFrame.new(-center) * model:GetPivot())
	model.Parent = world
	record.model = model
	record.radius = math.max(0.05, size.Magnitude * 0.5)
	framePreview(record)
	local complete = false
	task.delay(8, function()
		if alive and generation == record.generation and not complete then
			record.button.PreviewNote.Text = "PREVIEW DELAYED"
			record.button.PreviewNote.Visible = true
		end
	end)
	task.spawn(function()
		local loaded = true
		local ok = pcall(function()
			ContentProvider:PreloadAsync({ model }, function(contentId, status)
				if contentId ~= "" and status ~= Enum.AssetFetchStatus.Success then loaded = false end
			end)
		end)
		complete = true
		if not alive or generation ~= record.generation or not world.Parent then return end
		record.button.PreviewNote.Visible = not ok or not loaded
		record.button.PreviewNote.Text = "PREVIEW DELAYED"
		model.Parent = nil
		model.Parent = world
		framePreview(record)
	end)
end

local function syncLoadout()
	if not alive then return end
	for index, record in ipairs(slots) do
		local id = player:GetAttribute("PCToySlot" .. tostring(index))
		if typeof(id) ~= "string" or not catalog.ById[id] then id = "" end
		preview(record, id)
		record.button.ItemName.Text = id ~= "" and catalog.ById[id].name or "EMPTY"
	end
	activeIndex = math.clamp(math.floor(tonumber(player:GetAttribute("PCToyIndex")) or 0), 0, 4)
	activeId = slots[activeIndex] and slots[activeIndex].id or ""
	refresh()
end

local function invoke(remoteName, action, payload, itemId)
	if pending or not alive then return end
	local remote = ReplicatedStorage:FindFirstChild(remoteName)
	if not remote or not remote:IsA("RemoteFunction") then tell("Toys are getting ready.") refresh() return end
	pending = true
	requestToken += 1
	local token = requestToken
	refresh()
	task.delay(8, function()
		if not alive or requestToken ~= token or not pending then return end
		requestToken += 1
		pending = false
		tell("That took too long. Try again.")
		refresh()
	end)
	task.spawn(function()
		local ok, reply = pcall(function() return remote:InvokeServer(action, payload) end)
		if not alive or requestToken ~= token then return end
		pending = false
		if ok and typeof(reply) == "table" then
			if reply.message then tell(reply.message) elseif not reply.ok then tell("That did not go through.") end
		else
			tell("That did not go through. Try again.")
		end
		refresh()
	end)
end

local function aimAt(screenPosition)
	local camera = workspace.CurrentCamera
	if not camera then return nil end
	local position = screenPosition or camera.ViewportSize * 0.5
	local ray = screenPosition and camera:ScreenPointToRay(position.X, position.Y) or camera:ViewportPointToRay(position.X, position.Y)
	local parameters = RaycastParams.new()
	parameters.FilterType = Enum.RaycastFilterType.Exclude
	parameters.FilterDescendantsInstances = player.Character and { player.Character } or {}
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, parameters)
	return hit and hit.Position or ray.Origin + ray.Direction * 150
end

local function useToy(position)
	if not gui.Enabled or not bar.Visible or not usable() or modalOpen() or activeId == "" or pending then return end
	local item = catalog.ById[activeId]
	if item and item.toyActionPending then tell("This toy's action is coming soon.") refresh() return end
	if cooldownEndsAt(activeId) > workspace:GetServerTimeNow() then return end
	invoke("PlaygroundToyRequest", "Use", aimAt(position), activeId)
end

local function selectToy(index)
	local record = slots[index]
	if not gui.Enabled or not record or record.id == "" or not bar.Visible or not usable() or modalOpen() or pending then return end
	invoke("PlaygroundShopRequest", "SelectToy", index)
end

refresh = function()
	if not alive then return end
	local hasToy = false
	for _, record in ipairs(slots) do if record.id ~= "" then hasToy = true break end end
	local available = usable()
	bar.Visible = hasToy and player:GetAttribute("PCDataReady") == true and not inRound() and not modalOpen()
	showNativeBackpack(not (hasToy and player:GetAttribute("PCDataReady") == true and not inRound() and gui.Enabled))
	local now = workspace:GetServerTimeNow()
	local remaining = math.max(0, cooldownEndsAt(activeId) - now)
	local item = catalog.ById[activeId]
	local actionPending = item and item.toyActionPending == true
	local character = player.Character
	local heldTool = character and character:FindFirstChildOfClass("Tool")
	local heldId = heldTool and heldTool:GetAttribute("CatalogId")
	for index, record in ipairs(slots) do
		local selected = index == activeIndex and record.id ~= ""
		local selectionTag = record.button:FindFirstChild("Selected")
		selectionTag.Visible = selected
		selectionTag.Text = selected and heldId == record.id and "HELD" or "READY"
		record.button.Key.TextColor3 = selected and Color3.fromRGB(255, 215, 74) or Color3.fromRGB(255, 249, 224)
		record.button.Active = available and not pending and record.id ~= ""
		record.button.Selectable = record.button.Active
		record.button.ReusableSkin.ImageColor3 = record.id == "" and Color3.fromRGB(155, 155, 155) or Color3.new(1, 1, 1)
	end
	bar.Use.Active = available and not pending and activeId ~= "" and remaining <= 0 and not actionPending
	bar.Use.Selectable = bar.Use.Active
	local label = pending and "WAIT..." or actionPending and "SOON" or remaining > 0 and string.format("%.1fs", remaining) or "USE"
	bar.Use.Text = label
	bar.Use.LiveCaption.Text = label
	bar.Use.ReusableSkin.ImageColor3 = bar.Use.Active and Color3.new(1, 1, 1) or Color3.fromRGB(165, 165, 165)
	bar.Status.Text = now < noticeUntil and notice or not available and "Respawning..." or activeId == "" and "Select a toy" or actionPending and "Action coming soon" or UserInputService.TouchEnabled and "Tap a slot, then USE" or "1–4 select • click to use"
	local ember = tonumber(player:GetAttribute("PCToyEmberUntil")) or 0
	gui.Crosshair.Visible = bar.Visible and available and (activeId == "M10" or activeId == "M07" and ember > now)
end

for index = 1, 4 do
	local button = bar.Slots:WaitForChild("Slot" .. tostring(index))
	local record = { button = button, id = nil, generation = 0 }
	table.insert(slots, record)
	connect(button.Activated, function() selectToy(index) end)
	connect(button.Preview:GetPropertyChangedSignal("AbsoluteSize"), function() framePreview(record) end)
end
connect(bar.Use.Activated, function() useToy(nil) end)
local numberKeys = { [Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3, [Enum.KeyCode.Four] = 4 }
connect(UserInputService.InputBegan, function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	local index = numberKeys[input.KeyCode]
	if index then selectToy(index)
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then useToy(UserInputService:GetMouseLocation())
	elseif input.KeyCode == Enum.KeyCode.ButtonR2 then useToy(nil) end
end)
connect(UserInputService.TouchTapInWorld, function(position, processed)
	if not processed and not UserInputService:GetFocusedTextBox() then useToy(position) end
end)
connect(player:GetAttributeChangedSignal("PCToyLoadoutVersion"), syncLoadout)
for _, key in ipairs({ "PCDataReady", "BBParticipating", "TGParticipating", "MDParticipating", "PCToyEmberUntil", "PCToyEmberShotUntil" }) do
	connect(player:GetAttributeChangedSignal(key), refresh)
end
for index = 1, 15 do connect(player:GetAttributeChangedSignal(string.format("PCToyCooldown_M%02d", index)), refresh) end
local elapsed = 0
connect(RunService.Heartbeat, function(delta)
	elapsed += delta
	if elapsed >= 0.1 then elapsed = 0 refresh() end
end)
connect(script.Destroying, function()
	alive = false
	showNativeBackpack(true)
	bar.Visible = false
	gui.Crosshair.Visible = false
	requestToken += 1
	for _, connection in ipairs(connections) do connection:Disconnect() end
	for _, record in ipairs(slots) do
		record.generation += 1
		if record.model then record.model:Destroy() end
	end
end)
syncLoadout()

]====]})
table.insert(entries,{target=game["StarterGui"]["PlaygroundShell"]["Controller"],before=[====[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local gui = script.Parent
local shop = gui:WaitForChild("ShopPanel")
local vote = gui:WaitForChild("VotePanel")
local compactVote = gui:WaitForChild("CompactVotePanel")
local votePanels = { vote, compactVote }
local wallet = gui:WaitForChild("Wallet")
local dock = gui:WaitForChild("Dock")
local toast = gui:WaitForChild("RewardToast")
local catalogObject = ReplicatedStorage:WaitForChild("PlaygroundCatalog", 10)
if not catalogObject then warn("Playground catalog is unavailable") return end
local catalog = require(catalogObject)
local ink = Color3.fromRGB(27, 45, 61)
local white = Color3.fromRGB(255, 255, 248)
local gold = Color3.fromRGB(255, 211, 78)
local blue = Color3.fromRGB(89, 193, 244)
local pink = Color3.fromRGB(255, 153, 166)
local mint = Color3.fromRGB(130, 225, 180)
local muted = Color3.fromRGB(194, 201, 206)
local data = { coins = player:GetAttribute("PCCoins") or 0, ready = player:GetAttribute("PCDataReady") == true, owned = {}, equipped = {}, unlocks = {} }
local category = "All"
local page = 1
local pageCount = 1
local busy = false
local pendingStatus = false
local voteBusy = false
local toastToken = 0
local lastUnlockSerial = nil
local slots = {}
local previews = {}
local lastReward = player:GetAttribute("PCRewardAt")
local lastCoinPickup = player:GetAttribute("PCCoinPickupSerial") or 0
local coinPopups = {}
local wasInsideShop = false
local state = nil
local stateConnection = nil
local pager = shop:WaitForChild("Pager")
local emoteEmptyState = shop:WaitForChild("EmoteEmptyState")
local gameLabels = { BritishBulldog = "Bulldog", TagYoureIt = "Tag", StuckInTheMud = "Mud", All = "total" }

local function showToast(message, duration)
	toastToken += 1
	local token = toastToken
	toast.Message.Text = tostring(message)
	toast.Visible = true
	task.delay(duration or 3.2, function()
		if token == toastToken and toast.Parent then toast.Visible = false end
	end)
end

local function clearCoinPopup(popup)
	local record = coinPopups[popup]
	if not record then return end
	coinPopups[popup] = nil
	if record.completed then record.completed:Disconnect() end
	for _, tween in ipairs(record.tweens) do tween:Cancel() end
	popup:Destroy()
end

local function showCoinPickup(amount, position)
	if typeof(amount) ~= "number" or amount ~= amount or amount <= 0 or amount % 1 ~= 0 or typeof(position) ~= "Vector3" then return end
	local templates = gui:FindFirstChild("Templates")
	local template = templates and templates:FindFirstChild("CoinPickupPopup")
	local lobby = workspace:FindFirstChild("Playground Lobby")
	local gameplay = lobby and lobby:FindFirstChild("Gameplay")
	local markers = gameplay and gameplay:FindFirstChild("CoinSpawns")
	if not template or not template:IsA("BillboardGui") or not markers then return end
	local anchor, distance = nil, 8
	for _, marker in ipairs(markers:GetChildren()) do
		if marker:IsA("BasePart") then
			local gap = (marker.Position - position).Magnitude
			if gap < distance then anchor, distance = marker, gap end
		end
	end
	if not anchor then return end
	local popup = template:Clone()
	popup.Name = "CoinPickup"
	local label = popup:FindFirstChild("Amount")
	if not label or not label:IsA("TextLabel") then popup:Destroy() return end
	label.Text = "+" .. tostring(amount)
	popup.Adornee = anchor
	popup.StudsOffsetWorldSpace += position - anchor.Position
	popup.Enabled = true
	popup.Parent = gui
	local lift = TweenService:Create(popup, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffsetWorldSpace = popup.StudsOffsetWorldSpace + Vector3.new(0, 1.8, 0) })
	local fade = TweenService:Create(label, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.35), { TextTransparency = 1 })
	local record = { tweens = { lift, fade } }
	coinPopups[popup] = record
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then table.insert(record.tweens, TweenService:Create(stroke, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.35), { Transparency = 1 })) end
	record.completed = fade.Completed:Connect(function() clearCoinPopup(popup) end)
	for _, tween in ipairs(record.tweens) do tween:Play() end
	return popup
end

local function setText(label, value)
	label.Text = value
	local caption = label:FindFirstChild("LiveCaption")
	if caption and caption:IsA("TextLabel") then caption.Text = value end
end

local function refreshWallet()
	local coins = data.ready and tostring(data.coins or 0) or "..."
	wallet.Coins.Text = coins
	wallet.Wins.Text = data.ready and tostring(player:GetAttribute("PCWins") or 0) or "..."
	wallet.Level.Text = data.ready and tostring(player:GetAttribute("PCLevel") or 1) or "..."
	shop.Coins.Text = coins .. " coins"
end

local function visibleBounds(model)
	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency < 1 then
			for x = -1, 1, 2 do
				for y = -1, 1, 2 do
					for z = -1, 1, 2 do
						local point = part.CFrame:PointToWorldSpace(part.Size * Vector3.new(x, y, z) * 0.5)
						low = low:Min(point)
						high = high:Max(point)
					end
				end
			end
		end
	end
	if low.X == math.huge then return Vector3.zero, Vector3.one end
	return (low + high) * 0.5, high - low
end

local function framePreview(record)
	if not record.model or not record.model.Parent then return end
	local viewport = record.card.Preview
	local camera = viewport:FindFirstChild("PreviewCamera")
	if not camera then return end
	local aspect = math.max(0.2, viewport.AbsoluteSize.X / math.max(1, viewport.AbsoluteSize.Y))
	local angle = math.rad(camera.FieldOfView * 0.5)
	local radius = record.radius
	local distance = radius / math.sin(math.min(angle, math.atan(math.tan(angle) * aspect))) * 1.12
	local direction = Vector3.new(0.5, 0.2, -1).Unit
	camera.CFrame = CFrame.lookAt(direction * distance, Vector3.zero)
	viewport.CurrentCamera = camera
end

local function renderPreview(record, item)
	local id = item and item.id or nil
	if record.previewId == id and (not id or record.model) then return end
	record.previewId = nil
	if record.model then record.model:Destroy() end
	record.model = nil
	previews[record] = nil
	local world = record.card.Preview:FindFirstChild("World")
	if not world then return end
	for _, child in ipairs(world:GetChildren()) do child:Destroy() end
	if not item then return end
	local assets = ReplicatedStorage:FindFirstChild("PlaygroundCosmeticAssets")
	local original = assets and assets:FindFirstChild(id)
	if not original or not original:IsA("Model") then return end
	local model = original:Clone()
	model.Name = "ItemModel"
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("LuaSourceContainer") then child:Destroy()
		elseif child:IsA("BasePart") then
			child.Anchored = true
			child.CanCollide = false
			child.CanTouch = false
			child.CanQuery = false
		elseif child:IsA("ParticleEmitter") or child:IsA("Trail") then child.Enabled = false end
	end
	local center, size = visibleBounds(model)
	model:PivotTo(CFrame.new(-center) * model:GetPivot())
	model.Parent = world
	record.model = model
	record.previewId = id
	record.pivot = model:GetPivot()
	record.radius = math.max(0.01, size.Magnitude * 0.5)
	previews[record] = record
	framePreview(record)
	task.spawn(function()
		pcall(function() ContentProvider:PreloadAsync({ model }) end)
		if record.model == model and world.Parent then
			model.Parent = nil
			model.Parent = world
			framePreview(record)
		end
	end)
end

local function requirement(item, unlock)
	local rule = item.unlock or { kind = "Coins", amount = item.price or 0 }
	if rule.kind == "Starter" then return "Starter reward", "FREE" end
	if rule.kind == "Coins" then return tostring(item.price or rule.amount or 0) .. " coins", item.category end
	local progress = unlock and unlock.progress or 0
	local target = rule.amount or 0
	if rule.kind == "Level" then return "Level " .. tostring(target), tostring(math.min(progress, target)) .. " / " .. tostring(target) end
	return tostring(target) .. " " .. (gameLabels[rule.gameId] or "total") .. " wins", tostring(math.min(progress, target)) .. " / " .. tostring(target)
end

local function isEquipped(item)
	if item.slot == "Gear" and typeof(data.equipped.Toys) == "table" then
		return table.find(data.equipped.Toys, item.id) ~= nil
	end
	return data.equipped[item.slot] == item.id
end

local function refreshCards()
	refreshWallet()
	local filtered = {}
	for _, item in ipairs(catalog.Items) do
		if category == "All" or item.category == category then table.insert(filtered, item) end
	end
	emoteEmptyState.Visible = category == "Emotes" and #filtered == 0
	pager.Visible = #filtered > 0
	pageCount = math.max(1, math.ceil(#filtered / math.max(1, #slots)))
	page = math.clamp(page, 1, pageCount)
	setText(pager.PageLabel, tostring(page) .. " / " .. tostring(pageCount))
	for _, spec in ipairs({ { pager.Previous, page > 1 }, { pager.Next, page < pageCount } }) do
		spec[1].Active = spec[2] and not busy
		spec[1].Selectable = spec[1].Active
		spec[1].BackgroundColor3 = spec[1].Active and blue or muted
	end
	for index, record in ipairs(slots) do
		local item = filtered[(page - 1) * #slots + index]
		local card = record.card
		record.item = item
		card.Visible = item ~= nil
		renderPreview(record, item)
		if item then
			card:SetAttribute("CatalogId", item.id)
			setText(card:FindFirstChild("Name"), item.name)
			local owned = data.owned[item.id] == true
			local equipped = isEquipped(item)
			local unlock = data.unlocks[item.id]
			local price, detail = requirement(item, unlock)
			setText(card.Price, owned and (equipped and "Equipped" or "Owned") or price)
			setText(card.Category, owned and item.category or detail)
			local isCoins = item.unlock and item.unlock.kind == "Coins"
			local canBuy = isCoins and (unlock and unlock.purchasable == true or not unlock and data.coins >= (item.price or 0))
			local available = item.available ~= false
			local action = not available and "UNAVAILABLE" or not data.ready and "LOADING" or equipped and "UNEQUIP" or owned and "EQUIP" or isCoins and "BUY" or "LOCKED"
			if busy then action = "PLEASE WAIT" end
			setText(card.Action, action)
			card.Action.Visible = true
			card.Action.Active = not busy and data.ready and available and (owned or canBuy)
			card.Action.Selectable = card.Action.Active
			card.Action.BackgroundColor3 = not card.Action.Active and muted or equipped and mint or owned and blue or gold
			setText(card.Try, "INFO")
			card.Try.Visible = true
			card.Try.Active = true
			card.Try.Selectable = true
			local outline = card:FindFirstChild("Outline")
			if outline then outline.Color = equipped and gold or ink end
		else
			card:SetAttribute("CatalogId", nil)
		end
	end
	for _, button in ipairs(shop.Categories:GetChildren()) do
		if button:IsA("TextButton") and button.Visible then button.BackgroundColor3 = button.Name == category and gold or white end
	end
end

local function applyReply(reply)
	if typeof(reply) ~= "table" then return end
	if typeof(reply.coins) == "number" then data.coins = reply.coins end
	if typeof(reply.ready) == "boolean" then data.ready = reply.ready end
	if typeof(reply.owned) == "table" then data.owned = reply.owned end
	if typeof(reply.equipped) == "table" then data.equipped = reply.equipped end
	if typeof(reply.unlocks) == "table" then data.unlocks = reply.unlocks end
	if typeof(reply.unlockSerial) == "number" and reply.unlockSerial ~= lastUnlockSerial then
		lastUnlockSerial = reply.unlockSerial
		if typeof(reply.newlyUnlocked) == "table" and #reply.newlyUnlocked > 0 then
			local names = {}
			for index, id in ipairs(reply.newlyUnlocked) do
				if index > 2 then break end
				local item = catalog.ById[id]
				if item then table.insert(names, item.name) end
			end
			if #names > 0 then
				local more = #reply.newlyUnlocked > 2 and " and " .. tostring(#reply.newlyUnlocked - 2) .. " more" or ""
				showToast("Unlocked: " .. table.concat(names, ", ") .. more .. "!", 5)
			end
		end
	end
	refreshCards()
end

local request
request = function(action, id, quiet)
	if busy then
		if action == "GetStatus" then pendingStatus = true end
		return
	end
	local remote = ReplicatedStorage:FindFirstChild("PlaygroundShopRequest")
	if not remote or not remote:IsA("RemoteFunction") then
		if not quiet then shop.Status.Text = "The shop is getting ready. Try again in a moment." end
		return
	end
	busy = true
	refreshCards()
	task.spawn(function()
		local ok, reply = pcall(function() return remote:InvokeServer(action, id) end)
		busy = false
		if ok and typeof(reply) == "table" then
			applyReply(reply)
			if not quiet or not reply.ok then shop.Status.Text = tostring(reply.message or (reply.ok and "All set!" or "Try again in a moment.")) end
			if not reply.ok and not shop.Visible and not quiet then showToast(reply.message or "Try again in a moment.") end
		else
			refreshCards()
			if not quiet then shop.Status.Text = "That did not go through. Try again in a moment." end
		end
		if pendingStatus then
			pendingStatus = false
			task.defer(function() request("GetStatus", nil, true) end)
		end
	end)
end

local function setShop(visible)
	shop.Visible = visible
	gui.Backdrop.Visible = visible
	if visible then
		shop.Status.Text = data.ready and "Earn rewards, or spend your coins." or "Your coins are loading..."
		request("GetStatus", nil, true)
	end
end

local function setCategory(value)
	category = value
	page = 1
	shop.Cards.CanvasPosition = Vector2.zero
	refreshCards()
end

for _, card in ipairs(shop.Cards:GetChildren()) do
	if card:IsA("Frame") and card:FindFirstChild("Preview") and card:FindFirstChild("Action") then
		table.insert(slots, { card = card })
	end
end
table.sort(slots, function(a, b) return a.card.Name < b.card.Name end)
for _, record in ipairs(slots) do
	record.card.Action.Activated:Connect(function()
		local item = record.item
		if busy or not data.ready or not item or not record.card.Action.Active then return end
		if isEquipped(item) then request("Unequip", item.slot == "Gear" and item.id or item.slot)
		elseif data.owned[item.id] then request("Equip", item.id)
		else request("Buy", item.id) end
	end)
	record.card.Try.Activated:Connect(function()
		local item = record.item
		if not item then return end
		local unlock = data.unlocks[item.id]
		local description = item.description or item.name
		if unlock and not data.owned[item.id] then description ..= " " .. unlock.label .. "." end
		showToast(description, 5)
	end)
	record.card.Preview:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() framePreview(record) end)
end
for _, button in ipairs(shop.Categories:GetChildren()) do
	if button:IsA("TextButton") and button.Visible then button.Activated:Connect(function() setCategory(button.Name) end) end
end
pager.Previous.Activated:Connect(function()
	if busy or page <= 1 then return end
	page -= 1
	shop.Cards.CanvasPosition = Vector2.zero
	refreshCards()
end)
pager.Next.Activated:Connect(function()
	if busy or page >= pageCount then return end
	page += 1
	shop.Cards.CanvasPosition = Vector2.zero
	refreshCards()
end)
dock.Shop.Activated:Connect(function() setShop(not shop.Visible) end)
shop.Close.Activated:Connect(function() setShop(false) end)
gui.Backdrop.Activated:Connect(function() setShop(false) end)
dock.Pets.Activated:Connect(function() setCategory("Pets") setShop(true) end)
dock.Toys.Activated:Connect(function() setCategory("Toys") setShop(true) end)
for _, attribute in ipairs({ "PCCoins", "PCWins", "PCLevel", "PCDataReady" }) do
	player:GetAttributeChangedSignal(attribute):Connect(function()
		local wasReady = data.ready
		data.coins = player:GetAttribute("PCCoins") or data.coins
		data.ready = player:GetAttribute("PCDataReady") == true
		refreshCards()
		if data.ready and not wasReady then request("GetStatus", nil, true) end
	end)
end
player:GetAttributeChangedSignal("PCInventoryVersion"):Connect(function() request("GetStatus", nil, true) end)
player:GetAttributeChangedSignal("PCRewardAt"):Connect(function()
	local now = player:GetAttribute("PCRewardAt")
	if now and now ~= lastReward then
		lastReward = now
		local message = player:GetAttribute("PCRewardText")
		if typeof(message) == "string" and message ~= "" then showToast(message, 4) end
	end
end)
local coinPickupConnection = player:GetAttributeChangedSignal("PCCoinPickupSerial"):Connect(function()
	local serial = player:GetAttribute("PCCoinPickupSerial")
	if typeof(serial) ~= "number" or serial <= lastCoinPickup then return end
	lastCoinPickup = serial
	showCoinPickup(player:GetAttribute("PCCoinPickupAmount"), player:GetAttribute("PCCoinPickupPosition"))
end)
script.Destroying:Connect(function()
	coinPickupConnection:Disconnect()
	while next(coinPopups) do clearCoinPopup(next(coinPopups)) end
end)
ReplicatedStorage.ChildAdded:Connect(function(child)
	if child.Name == "PlaygroundShopRequest" then request("GetStatus", nil, true)
	elseif child.Name == "PlaygroundCosmeticAssets" then refreshCards() end
end)

local function insideZone(zone,root)
 if not zone or not zone:IsA("BasePart") or not root then return false end
 local point=zone.CFrame:PointToObjectSpace(root.Position)
 return math.abs(point.X)<=zone.Size.X/2 and math.abs(point.Y)<=zone.Size.Y/2 and math.abs(point.Z)<=zone.Size.Z/2
end
local function votesText(count)
 return tostring(count)..(count==1 and " vote" or " votes")
end
local function refreshVotes()
 local phase=state and state:GetAttribute("Phase") or "Waiting"
 local voting=phase=="Voting"
 local chosen=player:GetAttribute("PCVote")
 for _,vote in ipairs(votePanels) do
 vote.Title.Text=voting and "PICK THE NEXT ROUND" or "NEXT ROUND"
 local ending=state and state:GetAttribute("VotingEndsAt") or 0
 vote.Timer.Text=voting and tostring(math.max(0,math.ceil(ending-workspace:GetServerTimeNow()))).."s" or phase=="Playing" and "PLAYING" or phase=="Paused" and "PAUSED" or "WAITING"
 vote.VotesBritishBulldog.Text=votesText(state and state:GetAttribute("VotesBritishBulldog") or 0)
 vote.VotesTagYoureIt.Text=votesText(state and state:GetAttribute("VotesTagYoureIt") or 0)
 vote.VotesStuckInTheMud.Text=votesText(state and state:GetAttribute("VotesStuckInTheMud") or 0)
 vote.BritishBulldog.BackgroundColor3=chosen=="BritishBulldog" and gold or blue
 vote.TagYoureIt.BackgroundColor3=chosen=="TagYoureIt" and gold or pink
 vote.StuckInTheMud.BackgroundColor3=chosen=="StuckInTheMud" and gold or mint
 vote.BritishBulldog.Active=voting and not voteBusy
 vote.TagYoureIt.Active=voting and not voteBusy
 local mudAvailable=state and state:GetAttribute("AvailableStuckInTheMud")~=false
 vote.StuckInTheMud.Active=voting and not voteBusy and mudAvailable
 if not mudAvailable then
  vote.StuckInTheMud.BackgroundColor3=Color3.fromRGB(162,169,184)
  local minimum=state:GetAttribute("MinimumStuckInTheMud") or 4
  vote.VotesStuckInTheMud.Text=(state:GetAttribute("ReadyPlayerCount") or 0)<minimum and "Needs "..tostring(minimum).." players" or "Unavailable"
 end
 vote.StuckInTheMud.Selectable=vote.StuckInTheMud.Active
 vote.BritishBulldog.Selectable=vote.BritishBulldog.Active
 vote.TagYoureIt.Selectable=vote.TagYoureIt.Active
 if not voteBusy then
  vote.Message.Text=voting and (chosen and chosen~="" and "Your vote is saved. You can change it." or "Step onto a card to vote, or tap it here.") or phase=="Playing" and "Another round is underway." or phase=="Paused" and "The next round is paused." or "Voting opens when the next round is ready."
 end
 end
end
local function bindState(object)
 if not object or object==state then return end
 if stateConnection then stateConnection:Disconnect() end
 state=object
 stateConnection=state.AttributeChanged:Connect(refreshVotes)
 refreshVotes()
end
bindState(ReplicatedStorage:FindFirstChild("PlaygroundState"))
ReplicatedStorage.ChildAdded:Connect(function(child) if child.Name=="PlaygroundState" then bindState(child) end end)
player:GetAttributeChangedSignal("PCVote"):Connect(refreshVotes)
local function castVote(id)
 if voteBusy or not state or state:GetAttribute("Phase")~="Voting" then return end
 local remote=ReplicatedStorage:FindFirstChild("PlaygroundVoteRequest")
 if not remote or not remote:IsA("RemoteFunction") then return end
 voteBusy=true
 refreshVotes()
 task.spawn(function()
  local ok,reply=pcall(function() return remote:InvokeServer(id) end)
  voteBusy=false
  refreshVotes()
  if not ok then
   for _,panel in ipairs(votePanels) do panel.Message.Text="That vote did not go through. Try again." end
  elseif typeof(reply)=="table" and reply.ok==false then
   for _,panel in ipairs(votePanels) do panel.Message.Text=tostring(reply.message or "Step into the voting area first.") end
  end
 end)
end
for _,panel in ipairs(votePanels) do
 for _,id in ipairs({"BritishBulldog","TagYoureIt","StuckInTheMud"}) do panel[id].Activated:Connect(function() castVote(id) end) end
end
player.CharacterAdded:Connect(function() wasInsideShop=false end)
local elapsed=0
local previewTime=0
RunService.Heartbeat:Connect(function(delta)
 elapsed+=delta
 previewTime+=delta
 if elapsed<0.15 then return end
 elapsed=0
 local character=player.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 local lobby=workspace:FindFirstChild("Playground Lobby")
 local gameplay=lobby and lobby:FindFirstChild("Gameplay")
 local participating=player:GetAttribute("BBParticipating")==true or (player:GetAttribute("TGParticipating")==true or player:GetAttribute("MDParticipating")==true)
 wallet.Visible=not participating
 dock.Visible=not participating
 if participating and shop.Visible then setShop(false) end
 local shopZone=gameplay and gameplay:FindFirstChild("ShopZone")
 local voteZone=gameplay and gameplay:FindFirstChild("VoteZone")
 local inShop=insideZone(shopZone,root)
 if inShop and not wasInsideShop and not participating then setShop(true) end
 wasInsideShop=inShop
 local showVote=not participating and insideZone(voteZone,root) and not shop.Visible
 local camera=workspace.CurrentCamera
 local useCompactVote=camera and (camera.ViewportSize.X<980 or camera.ViewportSize.Y<450) or false
 vote.Visible=showVote and not useCompactVote
 compactVote.Visible=showVote and useCompactVote
 if showVote then refreshVotes() end
 if shop.Visible then
  local rotation=math.sin(previewTime*0.45)*0.30
  for _,preview in pairs(previews) do
   if preview.model.Parent then preview.model:PivotTo(CFrame.Angles(0,rotation,0)*preview.pivot) end
  end
 end
end)
refreshCards()
refreshVotes()
request("GetStatus",nil,true)


]====],after=[====[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local gui = script.Parent
local shop = gui:WaitForChild("ShopPanel")
local vote = gui:WaitForChild("VotePanel")
local compactVote = gui:WaitForChild("CompactVotePanel")
local votePanels = { vote, compactVote }
local wallet = gui:WaitForChild("Wallet")
local dock = gui:WaitForChild("Dock")
local toast = gui:WaitForChild("RewardToast")
local catalogObject = ReplicatedStorage:WaitForChild("PlaygroundCatalog", 10)
if not catalogObject then warn("Playground catalog is unavailable") return end
local catalog = require(catalogObject)
local ink = Color3.fromRGB(27, 45, 61)
local white = Color3.fromRGB(255, 255, 248)
local gold = Color3.fromRGB(255, 211, 78)
local blue = Color3.fromRGB(89, 193, 244)
local pink = Color3.fromRGB(255, 153, 166)
local mint = Color3.fromRGB(130, 225, 180)
local muted = Color3.fromRGB(194, 201, 206)
local data = { coins = player:GetAttribute("PCCoins") or 0, ready = player:GetAttribute("PCDataReady") == true, owned = {}, equipped = {}, unlocks = {} }
local category = "All"
local page = 1
local pageCount = 1
local busy = false
local pendingStatus = false
local voteBusy = false
local toastToken = 0
local lastUnlockSerial = nil
local slots = {}
local previews = {}
local lastReward = player:GetAttribute("PCRewardAt")
local lastCoinPickup = player:GetAttribute("PCCoinPickupSerial") or 0
local coinPopups = {}
local wasInsideShop = false
local state = nil
local stateConnection = nil
local pager = shop:WaitForChild("Pager")
local emoteEmptyState = shop:WaitForChild("EmoteEmptyState")
local gameLabels = { BritishBulldog = "Bulldog", TagYoureIt = "Tag", StuckInTheMud = "Mud", All = "total" }

local function showToast(message, duration)
	toastToken += 1
	local token = toastToken
	toast.Message.Text = tostring(message)
	toast.Visible = true
	task.delay(duration or 3.2, function()
		if token == toastToken and toast.Parent then toast.Visible = false end
	end)
end

local function clearCoinPopup(popup)
	local record = coinPopups[popup]
	if not record then return end
	coinPopups[popup] = nil
	if record.completed then record.completed:Disconnect() end
	for _, tween in ipairs(record.tweens) do tween:Cancel() end
	popup:Destroy()
end

local function showCoinPickup(amount, position)
	if typeof(amount) ~= "number" or amount ~= amount or amount <= 0 or amount % 1 ~= 0 or typeof(position) ~= "Vector3" then return end
	local templates = gui:FindFirstChild("Templates")
	local template = templates and templates:FindFirstChild("CoinPickupPopup")
	local lobby = workspace:FindFirstChild("Playground Lobby")
	local gameplay = lobby and lobby:FindFirstChild("Gameplay")
	local markers = gameplay and gameplay:FindFirstChild("CoinSpawns")
	if not template or not template:IsA("BillboardGui") or not markers then return end
	local anchor, distance = nil, 8
	for _, marker in ipairs(markers:GetChildren()) do
		if marker:IsA("BasePart") then
			local gap = (marker.Position - position).Magnitude
			if gap < distance then anchor, distance = marker, gap end
		end
	end
	if not anchor then return end
	local popup = template:Clone()
	popup.Name = "CoinPickup"
	local label = popup:FindFirstChild("Amount")
	if not label or not label:IsA("TextLabel") then popup:Destroy() return end
	label.Text = "+" .. tostring(amount)
	popup.Adornee = anchor
	popup.StudsOffsetWorldSpace += position - anchor.Position
	popup.Enabled = true
	popup.Parent = gui
	local lift = TweenService:Create(popup, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffsetWorldSpace = popup.StudsOffsetWorldSpace + Vector3.new(0, 1.8, 0) })
	local fade = TweenService:Create(label, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.35), { TextTransparency = 1 })
	local record = { tweens = { lift, fade } }
	coinPopups[popup] = record
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then table.insert(record.tweens, TweenService:Create(stroke, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.35), { Transparency = 1 })) end
	record.completed = fade.Completed:Connect(function() clearCoinPopup(popup) end)
	for _, tween in ipairs(record.tweens) do tween:Play() end
	return popup
end

local function setText(label, value)
	label.Text = value
	local caption = label:FindFirstChild("LiveCaption")
	if caption and caption:IsA("TextLabel") then caption.Text = value end
end

local function refreshWallet()
	local coins = data.ready and tostring(data.coins or 0) or "..."
	wallet.Coins.Text = coins
	wallet.Wins.Text = data.ready and tostring(player:GetAttribute("PCWins") or 0) or "..."
	wallet.Level.Text = data.ready and tostring(player:GetAttribute("PCLevel") or 1) or "..."
	shop.Coins.Text = coins .. " coins"
end

local function visibleBounds(model)
	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency < 1 then
			for x = -1, 1, 2 do
				for y = -1, 1, 2 do
					for z = -1, 1, 2 do
						local point = part.CFrame:PointToWorldSpace(part.Size * Vector3.new(x, y, z) * 0.5)
						low = low:Min(point)
						high = high:Max(point)
					end
				end
			end
		end
	end
	if low.X == math.huge then return Vector3.zero, Vector3.one end
	return (low + high) * 0.5, high - low
end

local function framePreview(record)
	if not record.model or not record.model.Parent then return end
	local viewport = record.card.Preview
	local camera = viewport:FindFirstChild("PreviewCamera")
	if not camera or not camera:IsA("Camera") then
		camera = Instance.new("Camera")
		camera.Name = "PreviewCamera"
		camera.FieldOfView = viewport:GetAttribute("PreviewFieldOfView") or 35
		camera.Parent = viewport
	end
	local aspect = math.max(0.2, viewport.AbsoluteSize.X / math.max(1, viewport.AbsoluteSize.Y))
	local angle = math.rad(camera.FieldOfView * 0.5)
	local radius = record.radius
	local distance = radius / math.sin(math.min(angle, math.atan(math.tan(angle) * aspect))) * 1.12
	local direction = Vector3.new(0.5, 0.2, -1).Unit
	camera.CFrame = CFrame.lookAt(direction * distance, Vector3.zero)
	viewport.CurrentCamera = camera
end

local function renderPreview(record, item)
	local id = item and item.id or nil
	if record.previewId == id and (not id or record.model) then return end
	record.previewId = nil
	if record.model then record.model:Destroy() end
	record.model = nil
	previews[record] = nil
	local world = record.card.Preview:FindFirstChild("World")
	if not world then return end
	for _, child in ipairs(world:GetChildren()) do child:Destroy() end
	if not item then return end
	local assets = ReplicatedStorage:FindFirstChild("PlaygroundCosmeticAssets")
	local original = assets and assets:FindFirstChild(id)
	if not original or not original:IsA("Model") then return end
	local model = original:Clone()
	model.Name = "ItemModel"
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("LuaSourceContainer") then child:Destroy()
		elseif child:IsA("BasePart") then
			child.Anchored = true
			child.CanCollide = false
			child.CanTouch = false
			child.CanQuery = false
		elseif child:IsA("ParticleEmitter") or child:IsA("Trail") then child.Enabled = false end
	end
	local center, size = visibleBounds(model)
	model:PivotTo(CFrame.new(-center) * model:GetPivot())
	model.Parent = world
	record.model = model
	record.previewId = id
	record.pivot = model:GetPivot()
	record.radius = math.max(0.01, size.Magnitude * 0.5)
	previews[record] = record
	framePreview(record)
	task.spawn(function()
		pcall(function() ContentProvider:PreloadAsync({ model }) end)
		if record.model == model and world.Parent then
			model.Parent = nil
			model.Parent = world
			framePreview(record)
		end
	end)
end

local function requirement(item, unlock)
	local rule = item.unlock or { kind = "Coins", amount = item.price or 0 }
	if rule.kind == "Starter" then return "Starter reward", "FREE" end
	if rule.kind == "Coins" then return tostring(item.price or rule.amount or 0) .. " coins", item.category end
	local progress = unlock and unlock.progress or 0
	local target = rule.amount or 0
	if rule.kind == "Level" then return "Level " .. tostring(target), tostring(math.min(progress, target)) .. " / " .. tostring(target) end
	return tostring(target) .. " " .. (gameLabels[rule.gameId] or "total") .. " wins", tostring(math.min(progress, target)) .. " / " .. tostring(target)
end

local function isEquipped(item)
	if item.slot == "Gear" and typeof(data.equipped.Toys) == "table" then
		return table.find(data.equipped.Toys, item.id) ~= nil
	end
	return data.equipped[item.slot] == item.id
end

local function refreshCards()
	refreshWallet()
	local filtered = {}
	for _, item in ipairs(catalog.Items) do
		if category == "All" or item.category == category then table.insert(filtered, item) end
	end
	emoteEmptyState.Visible = category == "Emotes" and #filtered == 0
	pager.Visible = #filtered > 0
	pageCount = math.max(1, math.ceil(#filtered / math.max(1, #slots)))
	page = math.clamp(page, 1, pageCount)
	setText(pager.PageLabel, tostring(page) .. " / " .. tostring(pageCount))
	for _, spec in ipairs({ { pager.Previous, page > 1 }, { pager.Next, page < pageCount } }) do
		spec[1].Active = spec[2] and not busy
		spec[1].Selectable = spec[1].Active
		spec[1].BackgroundColor3 = spec[1].Active and blue or muted
	end
	for index, record in ipairs(slots) do
		local item = filtered[(page - 1) * #slots + index]
		local card = record.card
		record.item = item
		card.Visible = item ~= nil
		renderPreview(record, item)
		if item then
			card:SetAttribute("CatalogId", item.id)
			setText(card:FindFirstChild("Name"), item.name)
			local owned = data.owned[item.id] == true
			local equipped = isEquipped(item)
			local unlock = data.unlocks[item.id]
			local price, detail = requirement(item, unlock)
			setText(card.Price, owned and (equipped and "Equipped" or "Owned") or price)
			setText(card.Category, owned and item.category or detail)
			local isCoins = item.unlock and item.unlock.kind == "Coins"
			local canBuy = isCoins and (unlock and unlock.purchasable == true or not unlock and data.coins >= (item.price or 0))
			local available = item.available ~= false
			local action = not available and "UNAVAILABLE" or not data.ready and "LOADING" or equipped and "UNEQUIP" or owned and "EQUIP" or isCoins and "BUY" or "LOCKED"
			if busy then action = "PLEASE WAIT" end
			setText(card.Action, action)
			card.Action.Visible = true
			card.Action.Active = not busy and data.ready and available and (owned or canBuy)
			card.Action.Selectable = card.Action.Active
			card.Action.BackgroundColor3 = not card.Action.Active and muted or equipped and mint or owned and blue or gold
			setText(card.Try, "INFO")
			card.Try.Visible = true
			card.Try.Active = true
			card.Try.Selectable = true
			local outline = card:FindFirstChild("Outline")
			if outline then outline.Color = equipped and gold or ink end
		else
			card:SetAttribute("CatalogId", nil)
		end
	end
	for _, button in ipairs(shop.Categories:GetChildren()) do
		if button:IsA("TextButton") and button.Visible then button.BackgroundColor3 = button.Name == category and gold or white end
	end
end

local function applyReply(reply)
	if typeof(reply) ~= "table" then return end
	if typeof(reply.coins) == "number" then data.coins = reply.coins end
	if typeof(reply.ready) == "boolean" then data.ready = reply.ready end
	if typeof(reply.owned) == "table" then data.owned = reply.owned end
	if typeof(reply.equipped) == "table" then data.equipped = reply.equipped end
	if typeof(reply.unlocks) == "table" then data.unlocks = reply.unlocks end
	if typeof(reply.unlockSerial) == "number" and reply.unlockSerial ~= lastUnlockSerial then
		lastUnlockSerial = reply.unlockSerial
		if typeof(reply.newlyUnlocked) == "table" and #reply.newlyUnlocked > 0 then
			local names = {}
			for index, id in ipairs(reply.newlyUnlocked) do
				if index > 2 then break end
				local item = catalog.ById[id]
				if item then table.insert(names, item.name) end
			end
			if #names > 0 then
				local more = #reply.newlyUnlocked > 2 and " and " .. tostring(#reply.newlyUnlocked - 2) .. " more" or ""
				showToast("Unlocked: " .. table.concat(names, ", ") .. more .. "!", 5)
			end
		end
	end
	refreshCards()
end

local request
request = function(action, id, quiet)
	if busy then
		if action == "GetStatus" then pendingStatus = true end
		return
	end
	local remote = ReplicatedStorage:FindFirstChild("PlaygroundShopRequest")
	if not remote or not remote:IsA("RemoteFunction") then
		if not quiet then shop.Status.Text = "The shop is getting ready. Try again in a moment." end
		return
	end
	busy = true
	refreshCards()
	task.spawn(function()
		local ok, reply = pcall(function() return remote:InvokeServer(action, id) end)
		busy = false
		if ok and typeof(reply) == "table" then
			applyReply(reply)
			if not quiet or not reply.ok then shop.Status.Text = tostring(reply.message or (reply.ok and "All set!" or "Try again in a moment.")) end
			if not reply.ok and not shop.Visible and not quiet then showToast(reply.message or "Try again in a moment.") end
		else
			refreshCards()
			if not quiet then shop.Status.Text = "That did not go through. Try again in a moment." end
		end
		if pendingStatus then
			pendingStatus = false
			task.defer(function() request("GetStatus", nil, true) end)
		end
	end)
end

local function setShop(visible)
	shop.Visible = visible
	gui.Backdrop.Visible = visible
	if visible then
		shop.Status.Text = data.ready and "Earn rewards, or spend your coins." or "Your coins are loading..."
		request("GetStatus", nil, true)
	end
end

local function setCategory(value)
	category = value
	page = 1
	shop.Cards.CanvasPosition = Vector2.zero
	refreshCards()
end

for _, card in ipairs(shop.Cards:GetChildren()) do
	if card:IsA("Frame") and card:FindFirstChild("Preview") and card:FindFirstChild("Action") then
		table.insert(slots, { card = card })
	end
end
table.sort(slots, function(a, b) return a.card.Name < b.card.Name end)
for _, record in ipairs(slots) do
	record.card.Action.Activated:Connect(function()
		local item = record.item
		if busy or not data.ready or not item or not record.card.Action.Active then return end
		if isEquipped(item) then request("Unequip", item.slot == "Gear" and item.id or item.slot)
		elseif data.owned[item.id] then request("Equip", item.id)
		else request("Buy", item.id) end
	end)
	record.card.Try.Activated:Connect(function()
		local item = record.item
		if not item then return end
		local unlock = data.unlocks[item.id]
		local description = item.description or item.name
		if unlock and not data.owned[item.id] then description ..= " " .. unlock.label .. "." end
		showToast(description, 5)
	end)
	record.card.Preview:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() framePreview(record) end)
end
for _, button in ipairs(shop.Categories:GetChildren()) do
	if button:IsA("TextButton") and button.Visible then button.Activated:Connect(function() setCategory(button.Name) end) end
end
pager.Previous.Activated:Connect(function()
	if busy or page <= 1 then return end
	page -= 1
	shop.Cards.CanvasPosition = Vector2.zero
	refreshCards()
end)
pager.Next.Activated:Connect(function()
	if busy or page >= pageCount then return end
	page += 1
	shop.Cards.CanvasPosition = Vector2.zero
	refreshCards()
end)
dock.Shop.Activated:Connect(function() setShop(not shop.Visible) end)
shop.Close.Activated:Connect(function() setShop(false) end)
gui.Backdrop.Activated:Connect(function() setShop(false) end)
dock.Pets.Activated:Connect(function() setCategory("Pets") setShop(true) end)
dock.Toys.Activated:Connect(function() setCategory("Toys") setShop(true) end)
for _, attribute in ipairs({ "PCCoins", "PCWins", "PCLevel", "PCDataReady" }) do
	player:GetAttributeChangedSignal(attribute):Connect(function()
		local wasReady = data.ready
		data.coins = player:GetAttribute("PCCoins") or data.coins
		data.ready = player:GetAttribute("PCDataReady") == true
		refreshCards()
		if data.ready and not wasReady then request("GetStatus", nil, true) end
	end)
end
player:GetAttributeChangedSignal("PCInventoryVersion"):Connect(function() request("GetStatus", nil, true) end)
player:GetAttributeChangedSignal("PCRewardAt"):Connect(function()
	local now = player:GetAttribute("PCRewardAt")
	if now and now ~= lastReward then
		lastReward = now
		local message = player:GetAttribute("PCRewardText")
		if typeof(message) == "string" and message ~= "" then showToast(message, 4) end
	end
end)
local coinPickupConnection = player:GetAttributeChangedSignal("PCCoinPickupSerial"):Connect(function()
	local serial = player:GetAttribute("PCCoinPickupSerial")
	if typeof(serial) ~= "number" or serial <= lastCoinPickup then return end
	lastCoinPickup = serial
	showCoinPickup(player:GetAttribute("PCCoinPickupAmount"), player:GetAttribute("PCCoinPickupPosition"))
end)
script.Destroying:Connect(function()
	coinPickupConnection:Disconnect()
	while next(coinPopups) do clearCoinPopup(next(coinPopups)) end
end)
ReplicatedStorage.ChildAdded:Connect(function(child)
	if child.Name == "PlaygroundShopRequest" then request("GetStatus", nil, true)
	elseif child.Name == "PlaygroundCosmeticAssets" then refreshCards() end
end)

local function insideZone(zone,root)
 if not zone or not zone:IsA("BasePart") or not root then return false end
 local point=zone.CFrame:PointToObjectSpace(root.Position)
 return math.abs(point.X)<=zone.Size.X/2 and math.abs(point.Y)<=zone.Size.Y/2 and math.abs(point.Z)<=zone.Size.Z/2
end
local function votesText(count)
 return tostring(count)..(count==1 and " vote" or " votes")
end
local function refreshVotes()
 local phase=state and state:GetAttribute("Phase") or "Waiting"
 local voting=phase=="Voting"
 local chosen=player:GetAttribute("PCVote")
 for _,vote in ipairs(votePanels) do
 vote.Title.Text=voting and "PICK THE NEXT ROUND" or "NEXT ROUND"
 local ending=state and state:GetAttribute("VotingEndsAt") or 0
 vote.Timer.Text=voting and tostring(math.max(0,math.ceil(ending-workspace:GetServerTimeNow()))).."s" or phase=="Playing" and "PLAYING" or phase=="Paused" and "PAUSED" or "WAITING"
 vote.VotesBritishBulldog.Text=votesText(state and state:GetAttribute("VotesBritishBulldog") or 0)
 vote.VotesTagYoureIt.Text=votesText(state and state:GetAttribute("VotesTagYoureIt") or 0)
 vote.VotesStuckInTheMud.Text=votesText(state and state:GetAttribute("VotesStuckInTheMud") or 0)
 vote.BritishBulldog.BackgroundColor3=chosen=="BritishBulldog" and gold or blue
 vote.TagYoureIt.BackgroundColor3=chosen=="TagYoureIt" and gold or pink
 vote.StuckInTheMud.BackgroundColor3=chosen=="StuckInTheMud" and gold or mint
 vote.BritishBulldog.Active=voting and not voteBusy
 vote.TagYoureIt.Active=voting and not voteBusy
 local mudAvailable=state and state:GetAttribute("AvailableStuckInTheMud")~=false
 vote.StuckInTheMud.Active=voting and not voteBusy and mudAvailable
 if not mudAvailable then
  vote.StuckInTheMud.BackgroundColor3=Color3.fromRGB(162,169,184)
  local minimum=state:GetAttribute("MinimumStuckInTheMud") or 4
  vote.VotesStuckInTheMud.Text=(state:GetAttribute("ReadyPlayerCount") or 0)<minimum and "Needs "..tostring(minimum).." players" or "Unavailable"
 end
 vote.StuckInTheMud.Selectable=vote.StuckInTheMud.Active
 vote.BritishBulldog.Selectable=vote.BritishBulldog.Active
 vote.TagYoureIt.Selectable=vote.TagYoureIt.Active
 if not voteBusy then
  vote.Message.Text=voting and (chosen and chosen~="" and "Your vote is saved. You can change it." or "Step onto a card to vote, or tap it here.") or phase=="Playing" and "Another round is underway." or phase=="Paused" and "The next round is paused." or "Voting opens when the next round is ready."
 end
 end
end
local function bindState(object)
 if not object or object==state then return end
 if stateConnection then stateConnection:Disconnect() end
 state=object
 stateConnection=state.AttributeChanged:Connect(refreshVotes)
 refreshVotes()
end
bindState(ReplicatedStorage:FindFirstChild("PlaygroundState"))
ReplicatedStorage.ChildAdded:Connect(function(child) if child.Name=="PlaygroundState" then bindState(child) end end)
player:GetAttributeChangedSignal("PCVote"):Connect(refreshVotes)
local function castVote(id)
 if voteBusy or not state or state:GetAttribute("Phase")~="Voting" then return end
 local remote=ReplicatedStorage:FindFirstChild("PlaygroundVoteRequest")
 if not remote or not remote:IsA("RemoteFunction") then return end
 voteBusy=true
 refreshVotes()
 task.spawn(function()
  local ok,reply=pcall(function() return remote:InvokeServer(id) end)
  voteBusy=false
  refreshVotes()
  if not ok then
   for _,panel in ipairs(votePanels) do panel.Message.Text="That vote did not go through. Try again." end
  elseif typeof(reply)=="table" and reply.ok==false then
   for _,panel in ipairs(votePanels) do panel.Message.Text=tostring(reply.message or "Step into the voting area first.") end
  end
 end)
end
for _,panel in ipairs(votePanels) do
 for _,id in ipairs({"BritishBulldog","TagYoureIt","StuckInTheMud"}) do panel[id].Activated:Connect(function() castVote(id) end) end
end
player.CharacterAdded:Connect(function() wasInsideShop=false end)
local elapsed=0
local previewTime=0
RunService.Heartbeat:Connect(function(delta)
 elapsed+=delta
 previewTime+=delta
 if elapsed<0.15 then return end
 elapsed=0
 local character=player.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 local lobby=workspace:FindFirstChild("Playground Lobby")
 local gameplay=lobby and lobby:FindFirstChild("Gameplay")
 local participating=player:GetAttribute("BBParticipating")==true or (player:GetAttribute("TGParticipating")==true or player:GetAttribute("MDParticipating")==true)
 wallet.Visible=not participating
 dock.Visible=not participating
 if participating and shop.Visible then setShop(false) end
 local shopZone=gameplay and gameplay:FindFirstChild("ShopZone")
 local voteZone=gameplay and gameplay:FindFirstChild("VoteZone")
 local inShop=insideZone(shopZone,root)
 if inShop and not wasInsideShop and not participating then setShop(true) end
 wasInsideShop=inShop
 local showVote=not participating and insideZone(voteZone,root) and not shop.Visible
 local camera=workspace.CurrentCamera
 local useCompactVote=camera and (camera.ViewportSize.X<980 or camera.ViewportSize.Y<450) or false
 vote.Visible=showVote and not useCompactVote
 compactVote.Visible=showVote and useCompactVote
 if showVote then refreshVotes() end
 if shop.Visible then
  local rotation=math.sin(previewTime*0.45)*0.30
  for _,preview in pairs(previews) do
   if preview.model.Parent then preview.model:PivotTo(CFrame.Angles(0,rotation,0)*preview.pivot) end
  end
 end
end)
refreshCards()
refreshVotes()
request("GetStatus",nil,true)


]====]})
for _,entry in ipairs(entries) do assert(normalize(entry.target.Source)==normalize(entry.before),"source changed: "..entry.target:GetFullName()) end
local backup=Instance.new("Folder")
backup.Name="GameplayRepairCameraPreviewBackup20261005"
backup.Parent=game.ServerStorage
local result={}
for _,entry in ipairs(entries) do
 local original=entry.target:Clone()
 original.Name=entry.target:GetFullName()
 original.Parent=backup
 entry.target.Source=entry.after
 table.insert(result,{path=entry.target:GetFullName(),matched=entry.target.Source==entry.after})
end
for _,gui in ipairs({game.StarterGui.PlaygroundShell,game.StarterGui.PlaygroundToyHotbar}) do
 for _,object in ipairs(gui:GetDescendants()) do
  if object:IsA("ViewportFrame") then
   local camera=object:FindFirstChild("PreviewCamera")
   if camera and camera:IsA("Camera") then object:SetAttribute("PreviewFieldOfView",camera.FieldOfView) end
  end
 end
end
return result
