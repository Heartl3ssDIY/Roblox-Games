local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local assets = ReplicatedStorage:WaitForChild("PlaygroundCosmeticAssets")
local visuals = Instance.new("Folder")
visuals.Name = "PlaygroundPetVisuals"
visuals.Parent = workspace

local outlineCandidates = {}
local knownHighlights = {}
local outlineConnections = {}
local outlineClock = 1

local function outlineCandidate(object)
	if object:IsA("Model") and object:GetAttribute("PCOutlineStored") == true and object:IsDescendantOf(workspace) then
		outlineCandidates[object] = true
		local outline = object:FindFirstChild("CartoonOutline")
		if outline and outline:IsA("Highlight") then outline:SetAttribute("PCCosmeticManaged", true) end
	end
end

local function observeOutlineObject(object)
	if object:IsA("Highlight") then knownHighlights[object] = true end
	outlineCandidate(object)
end

for _, object in ipairs(game:GetDescendants()) do observeOutlineObject(object) end
table.insert(outlineConnections, game.DescendantAdded:Connect(observeOutlineObject))
table.insert(outlineConnections, game.DescendantRemoving:Connect(function(object)
	knownHighlights[object] = nil
end))

local function clearCosmeticOutline(model)
	local outline = model:FindFirstChild("CartoonOutline")
	if outline and outline:IsA("Highlight") and outline:GetAttribute("PCCosmeticManaged") == true then outline:Destroy() end
end

local function updateCartoonOutlines()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local external = 0
	for highlight in pairs(knownHighlights) do
		if not highlight.Parent then knownHighlights[highlight] = nil
		elseif highlight:GetAttribute("PCCosmeticManaged") ~= true then external += 1 end
	end
	local budget = math.clamp(239 - external, 0, 128)
	local candidates = {}
	for model in pairs(outlineCandidates) do
		if not model.Parent or not model:IsDescendantOf(workspace) then
			clearCosmeticOutline(model)
			outlineCandidates[model] = nil
		elseif model:GetAttribute("PCOutlineEnabled") ~= false then
			local position = model:GetPivot().Position
			local distance = (position - camera.CFrame.Position).Magnitude
			local _, onScreen = camera:WorldToViewportPoint(position)
			local owner = model:GetAttribute("PetOwnerUserId")
			local tool = model:FindFirstAncestorOfClass("Tool")
			local localItem = owner == localPlayer.UserId or (tool and localPlayer.Character and tool:IsDescendantOf(localPlayer.Character))
			local score = localItem and -10000 or distance + (onScreen and 0 or 2000)
			if owner or tool then score -= 100 end
			table.insert(candidates, {model = model, score = score})
		end
	end
	table.sort(candidates, function(a, b) return a.score < b.score end)
	local wanted = {}
	for index = 1, math.min(budget, #candidates) do wanted[candidates[index].model] = true end
	for model in pairs(outlineCandidates) do
		if not wanted[model] then clearCosmeticOutline(model) end
	end
	for model in pairs(wanted) do
		local outline = model:FindFirstChild("CartoonOutline")
		if not outline then
			outline = Instance.new("Highlight")
			outline.Name = "CartoonOutline"
			outline:SetAttribute("PCCosmeticManaged", true)
			outline.Adornee = model
			outline.Parent = model
		end
		if outline:IsA("Highlight") then
			outline.Enabled = true
			outline.Adornee = model
			outline.FillTransparency = model:GetAttribute("PCOutlineFillTransparency") or 1
			outline.FillColor = model:GetAttribute("PCOutlineFillColor") or Color3.new(1, 1, 1)
			outline.OutlineTransparency = model:GetAttribute("PCOutlineTransparency") or 0
			outline.OutlineColor = model:GetAttribute("PCOutlineColor") or Color3.new(0, 0, 0)
			outline.DepthMode = model:GetAttribute("PCOutlineDepthMode") == "AlwaysOnTop" and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
		end
	end
end

table.insert(outlineConnections, RunService.Heartbeat:Connect(function(delta)
	outlineClock += delta
	if outlineClock >= 0.25 then outlineClock = 0 updateCartoonOutlines() end
end))

local function releaseCartoonOutlines()
	for _, connection in ipairs(outlineConnections) do connection:Disconnect() end
	for model in pairs(outlineCandidates) do if model.Parent then clearCosmeticOutline(model) end end
	table.clear(outlineCandidates)
	table.clear(knownHighlights)
end


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
	P21 = Color3.fromRGB(143, 217, 255),
	P22 = Color3.fromRGB(255, 177, 82),
	P25 = Color3.fromRGB(255, 231, 160),
	P35 = Color3.fromRGB(255, 194, 87),
}
local hoveringPets = { P10 = true, P12 = true, P14 = true, P19 = true, P23 = true, P25 = true, P28 = true, P35 = true }

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
	if state.model:GetAttribute("PCProceduralPetRig") == true then
		state.model:SetAttribute("PCPetMovement", state.movement)
	end
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
	releaseCartoonOutlines()
	for _, connection in connections do connection:Disconnect() end
	for player in states do release(player) end
	visuals:Destroy()
end)




