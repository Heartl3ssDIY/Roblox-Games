local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local MatchSettings = require(ReplicatedStorage:WaitForChild("MatchSettings"))
local MatchClock = require(ReplicatedStorage:WaitForChild("MatchClock"))

local CombatSFX = {}
local random = Random.new()
local folder
local lastPlayed = {}

local sounds = {
	whoosh = {id = "rbxassetid://9120715880", volume = .24, duration = 1.1, gap = .12},
	impact = {id = "rbxassetid://132504023010884", volume = .27, duration = .62, gap = .09},
	charge = {id = "rbxassetid://9125973433", volume = .19, duration = 1.76, gap = .18},
	beam = {id = "rbxassetid://120679226277488", volume = .25, duration = 1.43, gap = .12},
	ko = {id = "rbxassetid://9113480917", volume = .28, duration = .375, gap = .14},
}

local function getFolder()
	if folder and folder.Parent then return folder end
	folder = Instance.new("Folder")
	folder.Name = "LocalCombatSounds"
	folder.Archivable = false
	folder.Parent = workspace
	return folder
end

local function play(key, point, pitch)
	if not MatchSettings.soundsEnabled() or MatchClock.isPaused() or typeof(point) ~= "Vector3" then return end
	local config = sounds[key]
	if not config then return end
	local now = os.clock()
	if now - (lastPlayed[key] or -math.huge) < config.gap then return end
	lastPlayed[key] = now
	local emitter = Instance.new("Part")
	emitter.Name = "CombatSound_" .. key
	emitter.Size = Vector3.one * .1
	emitter.CFrame = CFrame.new(point)
	emitter.Anchored = true
	emitter.CanCollide = false
	emitter.CanTouch = false
	emitter.CanQuery = false
	emitter.CastShadow = false
	emitter.Transparency = 1
	emitter.Parent = getFolder()
	local sound = Instance.new("Sound")
	sound.SoundId = config.id
	sound.Volume = config.volume
	sound.PlaybackSpeed = (pitch or 1) * random:NextNumber(.96, 1.04)
	sound.RollOffMode = Enum.RollOffMode.Inverse
	sound.RollOffMinDistance = 8
	sound.RollOffMaxDistance = 75
	sound.Parent = emitter
	sound.Ended:Connect(function()
		if emitter.Parent then emitter:Destroy() end
	end)
	local expireAt = MatchClock.now() + math.max(6, config.duration / sound.PlaybackSpeed + 3)
	local function expire()
		if not emitter.Parent then return end
		local remaining = expireAt - MatchClock.now()
		if remaining <= 0 then emitter:Destroy()
		else task.delay(math.clamp(remaining, 1, 30), expire) end
	end
	task.delay(6, expire)
	sound:Play()
end

function CombatSFX.charge(point, kind)
	if kind == "Roshi" or kind == "Beeras" then
		play("charge", point, kind == "Roshi" and 1.2 or 1)
	end
end

function CombatSFX.release(point, kind)
	play(kind == "Melee" and "whoosh" or "beam", point, kind == "Beeras" and .86 or 1)
end

function CombatSFX.hit(point)
	play("impact", point)
end

function CombatSFX.knockout(point)
	play("ko", point)
end

function CombatSFX.stopAll()
	if folder and folder.Parent then folder:Destroy() end
	folder = nil
end

MatchSettings.SoundsChanged.Event:Connect(function(enabled)
	if not enabled then CombatSFX.stopAll() end
end)

Players.LocalPlayer:GetAttributeChangedSignal("MatchPaused"):Connect(function()
	if not folder or not folder.Parent then return end
	local paused = MatchClock.isPaused()
	for _, emitter in ipairs(folder:GetChildren()) do
		local sound = emitter:FindFirstChildOfClass("Sound")
		if sound then
			if paused then sound:Pause() else sound:Resume() end
		end
	end
end)

return CombatSFX
