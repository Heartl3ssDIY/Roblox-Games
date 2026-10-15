local catalogEmote
local lastEmoteSerial = 0
local retiredEmotes = {}

local function emoteAnimationId(value)
	if typeof(value) ~= "string" then return nil end
	local digits = value:match("^rbxassetid://(%d+)$")
	if not digits or #digits > 18 or tonumber(digits) <= 0 then return nil end
	return value
end

local function emoteNumber(value)
	return typeof(value) == "number" and value == value and math.abs(value) < math.huge
end

local function emoteStatus(status, message)
	local player = Players.LocalPlayer
	if player then
		player:SetAttribute("PCEmotePlaybackMessage", message or "")
		player:SetAttribute("PCEmotePlaybackStatus", status)
	end
end

local function disposeEmote(track, animation)
	if track then pcall(function() track:Destroy() end) end
	if animation then animation:Destroy() end
end

local function cleanRetiredEmotes(force)
	for index = #retiredEmotes, 1, -1 do
		local entry = retiredEmotes[index]
		if force or os.clock() >= entry.destroyAt then
			disposeEmote(entry.track, entry.animation)
			table.remove(retiredEmotes, index)
		end
	end
end

local function stopCatalogEmote(message, failed)
	local request = catalogEmote
	if not request then return end
	catalogEmote = nil
	request.expired = true
	if request.worker and coroutine.status(request.worker) ~= "dead" and request.worker ~= coroutine.running() then pcall(task.cancel, request.worker) end
	if request.track then
		pcall(function() request.track:Stop(0.12) end)
		table.insert(retiredEmotes, {track=request.track,animation=request.animation,destroyAt=os.clock()+0.2})
	else disposeEmote(nil, request.animation) end
	emoteStatus(failed and "failed" or "stopped", message)
end

local function emoteCanContinue(player, character, humanoid)
	if not character or not character.Parent or not humanoid or humanoid.Health <= 0 or humanoid.PlatformStand
		or humanoid.RigType ~= Enum.HumanoidRigType.R15 or player:GetAttribute("PCDataReady") ~= true then return false end
	if player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true
		or player:GetAttribute("MDParticipating") == true or player:GetAttribute("BBRagdolled") == true
		or player:GetAttribute("TGRagdolled") == true or character:GetAttribute("PCBatHeld") == true then return false end
	local toy = character:GetAttribute("PCToyHeld")
	if typeof(toy) == "string" and toy ~= "" then return false end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or humanoid.MoveDirection.Magnitude > 0.08 or humanoid.Jump then return false end
	local velocity = root.AssemblyLinearVelocity
	if Vector3.new(velocity.X, 0, velocity.Z).Magnitude > 1.5 then return false end
	local state = humanoid:GetState()
	return state ~= Enum.HumanoidStateType.Jumping and state ~= Enum.HumanoidStateType.Freefall
		and state ~= Enum.HumanoidStateType.Climbing and state ~= Enum.HumanoidStateType.Swimming
		and state ~= Enum.HumanoidStateType.Seated and state ~= Enum.HumanoidStateType.Dead
end

local function updateCatalogEmote(now)
	cleanRetiredEmotes(false)
	local player = Players.LocalPlayer
	if not player then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local serial = player:GetAttribute("PCEmoteSerial")
	local expires = player:GetAttribute("PCEmoteUntil")
	if catalogEmote and (catalogEmote.character ~= character or serial ~= catalogEmote.serial
		or not emoteNumber(expires) or now >= expires or not emoteCanContinue(player, character, humanoid)
		or (tonumber(player:GetAttribute("PCToyActionAt")) or 0) > catalogEmote.startedAt) then
		stopCatalogEmote("Dance stopped")
	end
	if emoteNumber(serial) and serial > 0 and serial % 1 == 0 and serial ~= lastEmoteSerial then
		lastEmoteSerial = serial
		local asset = emoteAnimationId(player:GetAttribute("PCEmoteAnimationId"))
		local started = player:GetAttribute("PCEmoteStartedAt")
		if not asset or player:GetAttribute("PCEmoteRigType") ~= "R15" or not emoteNumber(started)
			or not emoteNumber(expires) or started > now + 0.5 or expires <= now or expires - started > 35
			or not emoteCanContinue(player, character, humanoid) then return end
		catalogEmote = {serial=serial,character=character,humanoid=humanoid,asset=asset,startedAt=started,loadAt=os.clock()}
		emoteStatus("loading", "Loading dance...")
	end
	local request = catalogEmote
	if not request then return end
	if os.clock() - request.loadAt > 8 and (not request.track or request.track.Length <= 0) then
		stopCatalogEmote("This dance couldn't load. Try playing it again.", true)
		return
	end
	if request.track then
		if request.track.Length > 0 then
			if not request.track.IsPlaying then stopCatalogEmote("Dance stopped")
			elseif not request.ready then request.ready = true emoteStatus("playing", "Move or jump to stop dancing") end
		end
		return
	end
	if request.loading then return end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then return end
	request.loading = true
	local animation = Instance.new("Animation")
	animation.Name = "PlaygroundCatalogEmote"
	animation.AnimationId = request.asset
	request.animation = animation
	request.worker = task.spawn(function()
		local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
		if catalogEmote ~= request or request.expired then
			if ok then disposeEmote(track, nil) end
			return
		end
		if not ok then stopCatalogEmote("This dance couldn't load. Try playing it again.", true) return end
		request.track = track
		local played = pcall(function()
			track.Priority = Enum.AnimationPriority.Action
			track.Looped = true
			track:Play(0.2)
		end)
		if not played then stopCatalogEmote("This dance couldn't play. Try again.", true) end
	end)
end
