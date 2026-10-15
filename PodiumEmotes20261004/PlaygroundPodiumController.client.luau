local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local function finite(value)
	return typeof(value) == "number" and value == value and math.abs(value) < math.huge
end

local function animationId(value)
	if typeof(value) == "number" then
		if not finite(value) or value <= 0 or value % 1 ~= 0 then return nil end
		value = string.format("%.0f", value)
	end
	if typeof(value) ~= "string" then return nil end
	local digits = value:match("^rbxassetid://(%d+)$") or value:match("^(%d+)$")
	if not digits or #digits > 18 or tonumber(digits) <= 0 then return nil end
	return "rbxassetid://" .. digits
end

local function readableIsA(object, className)
	local ok, result = pcall(function() return object:IsA(className) end)
	return ok and result
end

local function bodyBounds(model)
	local low, high = math.huge, -math.huge
	for _, part in ipairs(model:GetChildren()) do
		if readableIsA(part, "BasePart") and part.Name ~= "HumanoidRootPart" then
			local half, frame = part.Size * 0.5, part.CFrame
			local extent = math.abs(frame.RightVector.Y) * half.X + math.abs(frame.UpVector.Y) * half.Y + math.abs(frame.LookVector.Y) * half.Z
			low = math.min(low, part.Position.Y - extent)
			high = math.max(high, part.Position.Y + extent)
		end
	end
	return low, high
end

local function prepareModel(model)
	assert(model and model:IsA("Model"), "Avatar model unavailable")
	local humanoid = assert(model:FindFirstChildOfClass("Humanoid"), "Avatar humanoid unavailable")
	local root = assert(model:FindFirstChild("HumanoidRootPart"), "Avatar root unavailable")
	for _, object in ipairs(model:GetDescendants()) do
		if readableIsA(object, "LuaSourceContainer") then
			object:Destroy()
		elseif readableIsA(object, "BasePart") then
			object.Anchored = object == root
			object.CanCollide, object.CanTouch, object.CanQuery = false, false, false
			object.Massless = true
		elseif readableIsA(object, "AnimationConstraint") then
			object.IsKinematic = true
			object.Enabled = true
		end
	end
	humanoid.AutoRotate = false
	humanoid.EvaluateStateMachine = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.WalkSpeed, humanoid.JumpPower = 0, 0
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then animator = Instance.new("Animator") animator.Parent = humanoid end
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do track:Stop(0) end
	local low, high = bodyBounds(model)
	local height = high - low
	assert(finite(height) and height > 0.05 and height < 1000, "Avatar body dimensions unavailable")
	model:ScaleTo(model:GetScale() * 5.5 / height)
	model.PrimaryPart = root
	model:PivotTo(CFrame.lookAt(Vector3.zero, Vector3.new(0, 0, 1)))
	low = bodyBounds(model)
	local result = { model = model, root = root, humanoid = humanoid, animator = animator, floorOffset = -low, joints = {} }
	for _, name in ipairs({ "Right Shoulder", "Left Shoulder", "RightShoulder", "LeftShoulder", "RightElbow", "LeftElbow", "RightWrist", "LeftWrist", "Waist", "Neck" }) do
		local joint = model:FindFirstChild(name, true)
		if joint and (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then
			result.joints[name] = { joint = joint, original = joint.Transform, rotation = joint.C0.Rotation }
		end
	end
	return result
end

local function poseJoint(avatar, name, x, y, z, fade)
	local entry = avatar.joints[name]
	if not entry or not entry.joint.Parent then return end
	local offset = entry.rotation:Inverse() * CFrame.Angles(math.rad(x), math.rad(y), math.rad(z)) * entry.rotation
	entry.joint.Transform = entry.original:Lerp(entry.original * offset, fade)
end

local function restorePose(avatar)
	for _, entry in pairs(avatar.joints) do if entry.joint.Parent then entry.joint.Transform = entry.original end end
end

local function animateModel(avatar, standingPoint, rank, elapsed, authored)
	local fade = math.clamp(elapsed / 0.35, 0, 1)
	local t = elapsed + rank * 0.7
	local bounce = authored and 0 or (1 - math.cos(elapsed * 3.6)) * 0.065 * fade
	local position = standingPoint.WorldPosition + Vector3.new(0, avatar.floorOffset + bounce, 0)
	avatar.model:PivotTo(CFrame.lookAt(position, position + Vector3.new(0, 0, 1)) * CFrame.Angles(0, math.sin(t * 1.3) * 0.045 * fade, 0))
	if authored then return end
	local wave = math.sin(t * 4.8)
	local right = avatar.joints["Right Shoulder"] and "Right Shoulder" or "RightShoulder"
	local left = avatar.joints["Left Shoulder"] and "Left Shoulder" or "LeftShoulder"
	if rank == 1 then
		poseJoint(avatar, right, 12, 0, 132 + wave * 10, fade)
		poseJoint(avatar, left, 12, 0, -132 + wave * 10, fade)
		poseJoint(avatar, "RightElbow", 35 + wave * 12, 0, 0, fade)
		poseJoint(avatar, "LeftElbow", 35 - wave * 12, 0, 0, fade)
	elseif rank == 2 then
		poseJoint(avatar, right, 10, 0, 140 + wave * 12, fade)
		poseJoint(avatar, left, 0, 0, -12 + math.sin(t * 2) * 5, fade)
		poseJoint(avatar, "RightElbow", 50, wave * 15, 0, fade)
	else
		poseJoint(avatar, right, 18 + wave * 8, 0, 48, fade)
		poseJoint(avatar, left, 18 - wave * 8, 0, -48, fade)
		poseJoint(avatar, "RightElbow", 55 + wave * 15, 0, 0, fade)
		poseJoint(avatar, "LeftElbow", 55 - wave * 15, 0, 0, fade)
	end
	poseJoint(avatar, "Waist", 0, 0, math.sin(t * 2.4) * 4, fade)
	poseJoint(avatar, "Neck", math.sin(t * 2.1) * 3, math.sin(t * 1.4) * 7, 0, fade)
	poseJoint(avatar, "RightWrist", 0, wave * 12, 0, fade)
	poseJoint(avatar, "LeftWrist", 0, -wave * 12, 0, fade)
end

local gui = script.Parent
local playerGui = gui.Parent
local header = gui:WaitForChild("Header")
local slots, connections, selectionConnections = {}, {}, {}
local folder = Instance.new("Folder")
folder.Name = "PlaygroundPodiumAvatars"
folder.Parent = workspace
local alive, activeLoads = true, 0
local selectionGui
local selectedScope, selectedBoard = "global", "MostWins"
local scopes = { global = true, server = true, region = true }
local boardNames = { MostWins = "MOST WINS", HighestLevel = "HIGHEST LEVEL" }
local packetState, packetStatus, packetRegion = "loading", "Loading winners...", nil

local function disconnect(list)
	for _, connection in ipairs(list) do connection:Disconnect() end
	table.clear(list)
end

local function stopTrack(avatar)
	if avatar.track then avatar.track:Stop(0) avatar.track:Destroy() avatar.track = nil end
	if avatar.animation then avatar.animation:Destroy() avatar.animation = nil end
	avatar.animationAsset = nil
	restorePose(avatar)
end

local function clearAvatar(slot)
	if slot.loadToken then slot.loadToken.expired = true slot.loadToken = nil end
	if slot.avatar then stopTrack(slot.avatar) slot.avatar.model:Destroy() slot.avatar = nil end
end

local function setEntry(slot, entry)
	local id = entry and entry.userId
	if slot.userId ~= id then
		clearAvatar(slot)
		slot.userId, slot.attempts, slot.retryAt = id, 0, 0
	end
	slot.entry = entry
	slot.display.NameLabel.Text = entry and entry.name or (packetState == "loading" and "Loading..." or "No winner yet")
	slot.display.ScoreLabel.Text = entry and (selectedBoard == "MostWins" and entry.value .. " WINS" or entry.value) or "—"
	if entry then
		slot.display.StatusLabel.Text = slot.avatar and (packetState == "stale" and "Saved ranking" or "") or (slot.attempts >= 3 and "Avatar unavailable" or "Loading avatar...")
	else
		slot.display.StatusLabel.Text = packetState == "loading" and "Waiting for rankings" or packetState == "unavailable" and "Rankings unavailable" or "Your next win could put you here"
	end
end

local function refreshHeading()
	header.Title.Text = boardNames[selectedBoard] .. " · TOP 3"
	local label = selectedScope == "region" and (packetRegion or "REGION") or selectedScope == "server" and "THIS SERVER" or "GLOBAL"
	header.Subtitle.Text = string.upper(label) .. (packetState == "loading" and " · LOADING" or packetState == "unavailable" and " · UNAVAILABLE" or packetState == "stale" and " · SAVED RANKINGS" or " · WINNERS")
end

local function readPacket()
	local encoded = selectionGui and selectionGui:GetAttribute("PodiumSnapshot")
	if typeof(encoded) ~= "string" or #encoded > 32768 then return end
	local ok, packet = pcall(function() return HttpService:JSONDecode(encoded) end)
	if not ok or typeof(packet) ~= "table" or packet.scope ~= selectedScope or packet.board ~= selectedBoard or typeof(packet.entries) ~= "table" then return end
	packetState = packet.state == "loading" and "loading" or packet.state == "unavailable" and "unavailable" or packet.state == "stale" and "stale" or "ready"
	packetStatus = typeof(packet.status) == "string" and packet.status or ""
	packetRegion = typeof(packet.region) == "string" and packet.region or nil
	local seen = {}
	for index, slot in ipairs(slots) do
		local entry = packet.entries[index]
		if typeof(entry) ~= "table" or not finite(entry.userId) or entry.userId <= 0 or entry.userId % 1 ~= 0 or seen[entry.userId]
			or typeof(entry.name) ~= "string" or typeof(entry.value) ~= "string" then entry = nil end
		if entry then seen[entry.userId] = true end
		setEntry(slot, entry)
	end
	refreshHeading()
end

local function readSelection()
	local scope = selectionGui and selectionGui:GetAttribute("PodiumScope")
	local board = selectionGui and selectionGui:GetAttribute("PodiumBoard")
	scope = scopes[scope] and scope or "global"
	board = boardNames[board] and board or "MostWins"
	if scope ~= selectedScope or board ~= selectedBoard then
		selectedScope, selectedBoard = scope, board
		packetState, packetStatus, packetRegion = "loading", "Loading winners...", nil
		for _, slot in ipairs(slots) do setEntry(slot, nil) end
		refreshHeading()
	end
	readPacket()
end

local function bindSelection()
	local source = playerGui:FindFirstChild("PlaygroundLeaderboards")
	if source == selectionGui then return end
	disconnect(selectionConnections)
	selectionGui = source
	packetState, packetStatus, packetRegion = "loading", "Loading winners...", nil
	for _, slot in ipairs(slots) do setEntry(slot, nil) end
	refreshHeading()
	if source then
		for _, attribute in ipairs({ "PodiumScope", "PodiumBoard", "PodiumSnapshot" }) do
			table.insert(selectionConnections, source:GetAttributeChangedSignal(attribute):Connect(attribute == "PodiumSnapshot" and readPacket or readSelection))
		end
	end
	readSelection()
end

local function bindPedestals()
	local lobby = workspace:FindFirstChild("Playground Lobby")
	local podium = lobby and lobby:FindFirstChild("WinnerPodium")
	local headerFace = podium and podium:FindFirstChild("HeaderFace")
	if headerFace and headerFace:IsA("BasePart") then header.Adornee = headerFace end
	header.Enabled = gui.Enabled and headerFace ~= nil
	for index, slot in ipairs(slots) do
		local pedestal = podium and podium:FindFirstChild("Rank" .. index)
		local point = pedestal and pedestal:FindFirstChild("StandingPoint", true)
		local face = pedestal and pedestal:FindFirstChild("Face")
		slot.point = point and point:IsA("Attachment") and point or nil
		if face and face:IsA("BasePart") then slot.display.Adornee = face end
		slot.display.Enabled = gui.Enabled and slot.point ~= nil and face ~= nil
		if not slot.point and slot.avatar then clearAvatar(slot) end
	end
end

local function beginAvatar(slot)
	local token = { userId = slot.userId, startedAt = os.clock() }
	slot.loadToken = token
	slot.attempts += 1
	activeLoads += 1
	task.spawn(function()
		local ok, model = pcall(function() return Players:CreateHumanoidModelFromUserIdAsync(token.userId) end)
		activeLoads -= 1
		local current = alive and not token.expired and slot.loadToken == token and slot.userId == token.userId and slot.point and slot.point:IsDescendantOf(workspace)
		if slot.loadToken == token then slot.loadToken = nil end
		if not current then if ok and typeof(model) == "Instance" then model:Destroy() end return end
		local prepared, avatar = false, nil
		if ok and typeof(model) == "Instance" then prepared, avatar = pcall(prepareModel, model) end
		if not prepared then
			if ok and typeof(model) == "Instance" then model:Destroy() end
			slot.retryAt = os.clock() + math.min(60, slot.attempts * 15)
			slot.display.StatusLabel.Text = "Avatar unavailable"
			return
		end
		avatar.startedAt = os.clock()
		model.Name = "Rank" .. slot.rank .. "_" .. token.userId
		model:SetAttribute("PodiumUserId", token.userId)
		model.Parent = folder
		slot.avatar = avatar
		animateModel(avatar, slot.point, slot.rank, 0, false)
		slot.display.StatusLabel.Text = packetState == "stale" and "Saved ranking" or ""
	end)
end

local function updateAnimation(avatar)
	local requested = animationId(gui:GetAttribute("PodiumAnimationId"))
	if avatar.animationAsset == requested then return end
	stopTrack(avatar)
	avatar.animationAsset = requested
	if not requested then return end
	local animation = Instance.new("Animation")
	animation.AnimationId = requested
	avatar.animation = animation
	local ok, track = pcall(function() return avatar.animator:LoadAnimation(animation) end)
	if ok then
		avatar.track = track
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = true
		track:Play(0.25)
	end
end

for index = 1, 3 do
	slots[index] = { rank = index, display = gui:WaitForChild("Rank" .. index), attempts = 0, retryAt = 0 }
	setEntry(slots[index], nil)
end
refreshHeading()
bindSelection()
readPacket()
bindPedestals()

local function cleanup()
	if not alive then return end
	alive = false
	disconnect(connections)
	disconnect(selectionConnections)
	for _, slot in ipairs(slots) do clearAvatar(slot) slot.display.Enabled = false end
	folder:Destroy()
end

table.insert(connections, gui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if gui.Enabled then folder.Parent = workspace else folder.Parent = nil end
	bindPedestals()
end))
table.insert(connections, gui.Destroying:Connect(cleanup))
table.insert(connections, script.Destroying:Connect(cleanup))
local elapsed = 0
table.insert(connections, RunService.Heartbeat:Connect(function(dt)
	if not alive then return end
	elapsed += dt
	if elapsed < 0.25 then return end
	elapsed = 0
	bindSelection()
	bindPedestals()
	if not gui.Enabled then return end
	local now = os.clock()
	for _, slot in ipairs(slots) do
		if slot.loadToken and now - slot.loadToken.startedAt > 20 then slot.display.StatusLabel.Text = "Avatar is taking longer to load" end
		if slot.userId and slot.point and not slot.avatar and not slot.loadToken and slot.attempts < 3 and now >= slot.retryAt and activeLoads < 2 then beginAvatar(slot) end
	end
end))
table.insert(connections, RunService.PreAnimation:Connect(function()
	if not alive then return end
	for _, slot in ipairs(slots) do if slot.avatar then restorePose(slot.avatar) end end
end))
table.insert(connections, RunService.PreSimulation:Connect(function()
	if not alive or not gui.Enabled then return end
	local now = os.clock()
	for _, slot in ipairs(slots) do
		local avatar = slot.avatar
		if avatar and slot.point and slot.point:IsDescendantOf(workspace) then
			updateAnimation(avatar)
			local authored = avatar.track and avatar.track.IsPlaying and avatar.track.Length > 0
			animateModel(avatar, slot.point, slot.rank, now - avatar.startedAt, authored)
		end
	end
end))
