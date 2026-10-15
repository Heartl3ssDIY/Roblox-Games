local storage=game:GetService("ServerStorage")
local fixture=Instance.new("Folder") fixture.Name="EmoteClientChecks20261005" fixture.Parent=workspace
local result={passed=false,checks=0}
local function check(value,message) assert(value,message) result.checks+=1 end
local ok,err=xpcall(function()
 local function module(name,source,live)
  local item=Instance.new("ModuleScript") item.Name=name item.Source=source item.Capabilities=live.Capabilities item.Sandboxed=live.Sandboxed item.Parent=fixture return require(item)
 end
 local api=module("Playback",[====[local Players={}
local clock=0
local os={clock=function()return clock end}
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

return {SetPlayer=function(player)Players.LocalPlayer=player end,SetClock=function(value)clock=value end,
 Update=updateCatalogEmote,Stop=stopCatalogEmote,Retire=cleanRetiredEmotes,Request=function()return catalogEmote end,Asset=emoteAnimationId}
]====],game.StarterPlayer.StarterPlayerScripts.PlaygroundEmotes)
 local model=storage.WeaponRigFixtures.R15:Clone() model.Name="PlaybackRig" model.Parent=fixture model:PivotTo(CFrame.new(5000,1000,5000))
 local root=model.HumanoidRootPart root.Anchored=true root.AssemblyLinearVelocity=Vector3.zero
 local nativeHumanoid=model:FindFirstChildOfClass("Humanoid")
 local animator=nativeHumanoid:FindFirstChildOfClass("Animator") if not animator then animator=Instance.new("Animator") animator.Parent=nativeHumanoid end
 local state=Enum.HumanoidStateType.Running
 local delayedAnimator=false
 local humanoid={Health=100,PlatformStand=false,RigType=Enum.HumanoidRigType.R15,MoveDirection=Vector3.zero,Jump=false,
  GetState=function()return state end,FindFirstChildOfClass=function()if delayedAnimator then return nil end return animator end}
 local character={Parent=fixture,attrs={},GetAttribute=function(self,key)return self.attrs[key]end,
  FindFirstChild=function()return root end,FindFirstChildOfClass=function()return humanoid end}
 local player={Character=character,attrs={PCDataReady=true},GetAttribute=function(self,key)return self.attrs[key]end,SetAttribute=function(self,key,value)self.attrs[key]=value if key=="PCEmotePlaybackStatus"then self.statusMessage=self.attrs.PCEmotePlaybackMessage end end}
 api.SetPlayer(player)
 local serial=0
 local function start()
  serial+=1 player.attrs.PCEmoteSerial=serial player.attrs.PCEmoteAction="E01" player.attrs.PCEmoteAnimationId="rbxassetid://93650537970037"
  player.attrs.PCEmoteStartedAt=100 player.attrs.PCEmoteUntil=130 player.attrs.PCEmoteRigType="R15"
  api.SetClock(0) api.Update(100) task.wait(.15) api.Update(100.15)
 end
 check(api.Asset("rbxassetid://123")=="rbxassetid://123" and api.Asset("https://bad")==nil,"Strict animation URI")
 start()
 local request=api.Request()
 check(request and request.track,"Real Animator track created under exact capabilities")
 check(request.track.IsPlaying and request.track.Length>0,"Verified real animation loads and plays")
 check(request.track.Looped and request.track.Priority==Enum.AnimationPriority.Action,"Loop and priority configured")
 check(player.attrs.PCEmotePlaybackStatus=="playing","Ready status reflects loaded track")
 check(player.statusMessage=="Move or jump to stop dancing","Status publishes after its associated message")
 local track=request.track api.Update(100.2) check(api.Request().track==track,"Same serial creates no duplicate track")
 humanoid.MoveDirection=Vector3.xAxis api.Update(100.3) check(api.Request()==nil and not track.IsPlaying,"Movement stops real track")
 humanoid.MoveDirection=Vector3.zero api.Update(100.4) check(api.Request()==nil,"Stopping input cannot replay consumed serial")
 api.Retire(true)
 for _,reason in ipairs({"jump","death","round","ragdoll","toy","bat","toolAction","expiry","respawn"})do
  start() check(api.Request()~=nil,reason.." fresh serial starts")
  if reason=="jump"then humanoid.Jump=true
  elseif reason=="death"then humanoid.Health=0
  elseif reason=="round"then player.attrs.MDParticipating=true
  elseif reason=="ragdoll"then player.attrs.TGRagdolled=true
  elseif reason=="toy"then character.attrs.PCToyHeld="M01"
  elseif reason=="bat"then character.attrs.PCBatHeld=true
  elseif reason=="toolAction"then player.attrs.PCToyActionAt=101
  elseif reason=="expiry"then player.attrs.PCEmoteUntil=100
  elseif reason=="respawn"then player.Character=nil end
  api.Update(101) check(api.Request()==nil,reason.." cancels playback")
  humanoid.Jump=false humanoid.Health=100 player.attrs.MDParticipating=nil player.attrs.TGRagdolled=nil
  character.attrs.PCToyHeld=nil character.attrs.PCBatHeld=nil player.attrs.PCToyActionAt=nil player.Character=character
  api.Retire(true)
 end
 humanoid.RigType=Enum.HumanoidRigType.R6 start() check(api.Request()==nil,"R6 rejects R15-only animation")humanoid.RigType=Enum.HumanoidRigType.R15
 delayedAnimator=true start() check(api.Request()~=nil and not api.Request().track,"Late server Animator waits without local creation")
 delayedAnimator=false api.Update(100.3)task.wait(.15)api.Update(100.4)check(api.Request().track~=nil,"Late server Animator recovered")api.Stop("Stopped")api.Retire(true)
 delayedAnimator=true start()api.SetClock(9)api.Update(101)check(api.Request()==nil and player.attrs.PCEmotePlaybackStatus=="failed","Bounded Animator timeout with honest status")delayedAnimator=false
 api.Update(102)check(api.Request()==nil,"Timeout does not retry same serial")
 start()check(api.Request()~=nil,"New use request recovers after timeout")api.Stop("Stopped")api.Retire(true)
 local pod=module("Podium",[====[local Players = game:GetService("Players")
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


local winner
local nativePlayers=Players
Players={GetPlayerByUserId=function()return winner end}
local gui={attrs={},GetAttribute=function(self,key)return self.attrs[key]end}
local alive=true
local packetState="ready"
local function stopTrack(avatar)
	local token = avatar.animationToken
	if token then
		token.expired = true
		if token.worker and coroutine.status(token.worker) ~= "dead" and token.worker ~= coroutine.running() then pcall(task.cancel, token.worker) end
		avatar.animationToken = nil
	end
	if avatar.track then avatar.track:Stop(0) avatar.track:Destroy() avatar.track = nil end
	if avatar.animation then avatar.animation:Destroy() avatar.animation = nil end
	avatar.animationAsset = nil
	restorePose(avatar)
end

local function requestedAnimation(slot)
	local winner = slot.userId and Players:GetPlayerByUserId(slot.userId)
	local equipped, asset, rig
	if winner and winner:GetAttribute("PCDataReady") == true then
		equipped = winner:GetAttribute("PCEmote")
		asset = winner:GetAttribute("PCEquippedEmoteAnimationId")
		rig = winner:GetAttribute("PCEquippedEmoteRigType")
	else
		local entry = slot.entry
		equipped = entry and entry.emoteId
		asset = entry and entry.emoteAnimationId
		rig = entry and entry.emoteRigType
	end
	if typeof(equipped) == "string" and equipped ~= "" then
		return rig == "R15" and animationId(asset) or nil
	end
	return animationId(gui:GetAttribute("PodiumAnimationId"))
end

local function failedAnimation(slot, avatar)
	stopTrack(avatar)
	avatar.animationRetryAt = os.clock() + 15
	slot.display.StatusLabel.Text = avatar.animationAttempts >= 3 and "Dance unavailable" or "Dance is loading slowly"
end

local function updateAnimation(slot)
	local avatar = slot.avatar
	local requested = requestedAnimation(slot)
	if avatar.requestedAnimation ~= requested then
		stopTrack(avatar)
		avatar.requestedAnimation = requested
		avatar.animationAttempts, avatar.animationRetryAt = 0, 0
	end
	if not requested then return end
	local now = os.clock()
	if avatar.track then
		if avatar.track.Length > 0 and avatar.track.IsPlaying then
			avatar.animationAttempts, avatar.animationRetryAt = 0, 0
			return
		end
		if now - avatar.animationLoadedAt > 8 then failedAnimation(slot, avatar) end
		return
	end
	if avatar.animationToken then
		if now - avatar.animationToken.startedAt > 8 then failedAnimation(slot, avatar) end
		return
	end
	if (avatar.animationAttempts or 0) >= 3 or now < (avatar.animationRetryAt or 0) then return end
	avatar.animationAttempts = (avatar.animationAttempts or 0) + 1
	local token = {startedAt=now}
	avatar.animationToken = token
	local animation = Instance.new("Animation")
	animation.Name = "EquippedPodiumEmote"
	animation.AnimationId = requested
	avatar.animation, avatar.animationAsset = animation, requested
	token.worker = task.spawn(function()
		local ok, track = pcall(function() return avatar.animator:LoadAnimation(animation) end)
		if not alive or token.expired or avatar.animationToken ~= token or slot.avatar ~= avatar or not avatar.model.Parent then
			if ok then track:Destroy() end
			return
		end
		avatar.animationToken = nil
		if not ok then failedAnimation(slot, avatar) return end
		avatar.track, avatar.animationLoadedAt = track, os.clock()
		local played = pcall(function()
			track.Priority = Enum.AnimationPriority.Action
			track.Looped = true
			track:Play(0.25)
		end)
		if not played then failedAnimation(slot, avatar)
		else slot.display.StatusLabel.Text = packetState == "stale" and "Saved ranking" or "" end
	end)
end

return {Prepare=prepareModel,Stop=stopTrack,Request=requestedAnimation,Update=updateAnimation,
 SetWinner=function(value)winner=value end,SetManual=function(value)gui.attrs.PodiumAnimationId=value end}
]====],game.StarterGui.PlaygroundPodium.Controller)
 local avatarModel=storage.WeaponRigFixtures.R15:Clone()avatarModel.Name="PodiumRig"avatarModel.Parent=fixture
 local avatar=pod.Prepare(avatarModel)
 avatar.model:PivotTo(CFrame.new(5020,1000,5000))
 local slot={userId=1,avatar=avatar,entry={emoteId="E01",emoteAnimationId="rbxassetid://93650537970037",emoteRigType="R15"},display={StatusLabel={Text=""}}}
 check(pod.Request(slot)=="rbxassetid://93650537970037","Offline equipped dance resolves from snapshot")
 pod.SetManual("rbxassetid://999")check(pod.Request(slot)=="rbxassetid://93650537970037","Equipped dance beats manual fallback")
 slot.entry.emoteAnimationId=""check(pod.Request(slot)==nil,"Unavailable equipped dance does not substitute manual animation")
 slot.entry=nil check(pod.Request(slot)=="rbxassetid://999","Manual fallback retained when no equipped emote")
 local winner={attrs={PCDataReady=true,PCEmote="E01",PCEquippedEmoteAnimationId="rbxassetid://93650537970037",PCEquippedEmoteRigType="R15"},GetAttribute=function(self,key)return self.attrs[key]end}
 pod.SetWinner(winner)check(pod.Request(slot)=="rbxassetid://93650537970037","Online winner immediately overrides stale snapshot")
 pod.Update(slot)task.wait(.15)pod.Update(slot)
 check(avatar.track and avatar.track.IsPlaying and avatar.track.Length>0,"Real equipped podium dance plays under exact capabilities")
 local old=avatar.track pod.Update(slot)check(avatar.track==old,"Podium avoids duplicate track loads")
 for cycle=1,5 do
  pod.Stop(avatar)pod.Update(slot)task.wait(.1)pod.Update(slot)
  check(avatar.track and avatar.track.IsPlaying,"Podium resumes after repeated intentional pause "..cycle)
 end
 old=avatar.track
 winner.attrs.PCEmote=nil winner.attrs.PCEquippedEmoteAnimationId=nil pod.SetManual(nil)pod.Update(slot)
 check(avatar.track==nil and not old.IsPlaying,"Unequip stops dance and restores podium pose")
 pod.Stop(avatar)
 result.passed=true result.playbackCapabilities=tostring(game.StarterPlayer.StarterPlayerScripts.PlaygroundEmotes.Capabilities)
 result.podiumCapabilities=tostring(game.StarterGui.PlaygroundPodium.Controller.Capabilities)
end,debug.traceback)
fixture:Destroy()
result.cleaned=workspace:FindFirstChild("EmoteClientChecks20261005")==nil
if not ok then result.error=err end
return result
