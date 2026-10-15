local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local MatchSettings = require(ReplicatedStorage:WaitForChild("MatchSettings"))

local CombatVFX = {}
local budgetStarted = 0
local burstsThisSecond = 0
local MAX_BURSTS_PER_SECOND = 24

local function canBurst(folder)
	if not folder or not folder.Parent or not MatchSettings.effectsEnabled() then return false end
	local now = os.clock()
	if now - budgetStarted >= 1 then
		budgetStarted = now
		burstsThisSecond = 0
	end
	if burstsThisSecond >= MAX_BURSTS_PER_SECOND then return false end
	burstsThisSecond += 1
	return true
end

local function effectPart(folder, name, point, color)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.CFrame = CFrame.new(point)
	part.Parent = folder
	return part
end

local function pulse(folder, point, color, diameter, duration)
	local part = effectPart(folder, "AnimeImpactPulse", point, color)
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * .18
	part.Transparency = .22
	TweenService:Create(part, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * diameter,
		Transparency = 1,
	}):Play()
	Debris:AddItem(part, duration + .04)
end

local function sparks(folder, point, color, count, speed)
	local origin = effectPart(folder, "AnimeSparks", point, color)
	origin.Size = Vector3.one * .05
	origin.Transparency = 1
	local emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	emitter.Rate = 0
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color)
	emitter.Lifetime = NumberRange.new(.12, .27)
	emitter.Speed = NumberRange.new(speed * .65, speed)
	emitter.Drag = 3
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.RotSpeed = NumberRange.new(-220, 220)
	emitter.LightEmission = .75
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, .23),
		NumberSequenceKeypoint.new(.5, .15),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(.7, .1),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = origin
	emitter:Emit(count)
	Debris:AddItem(origin, .35)
end

local function crossFlash(folder, point, color)
	for side = -1, 1, 2 do
		local streak = effectPart(folder, "AnimeHitStreak", point, color)
		streak.Size = Vector3.new(.08, .35, .08)
		streak.Transparency = .08
		streak.CFrame = CFrame.new(point) * CFrame.Angles(math.rad(30 * side), math.rad(25 * side), math.rad(47 * side))
		TweenService:Create(streak, TweenInfo.new(.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(.08, 2.1, .08),
			Transparency = 1,
		}):Play()
		Debris:AddItem(streak, .22)
	end
end

function CombatVFX.muzzle(folder, point, _direction, color, kind)
	if not canBurst(folder) then return end
	color = color or Color3.fromRGB(255, 190, 100)
	local major = kind == "Roshi" or kind == "Beeras"
	pulse(folder, point, color, major and 1.65 or .95, .22)
	sparks(folder, point, color, major and 7 or 4, major and 7 or 5)
end

function CombatVFX.hit(folder, point, color, kind)
	if not canBurst(folder) then return end
	color = color or Color3.fromRGB(255, 190, 100)
	local melee = kind == "Melee"
	pulse(folder, point, color, melee and 1.4 or 2.05, melee and .16 or .26)
	sparks(folder, point, color, melee and 8 or 6, melee and 11 or 8)
	crossFlash(folder, point, color)
end

return CombatVFX
