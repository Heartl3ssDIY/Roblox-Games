local MatchClock = require(game:GetService("ReplicatedStorage"):WaitForChild("MatchClock"))
local MatchSettings = require(game:GetService("ReplicatedStorage"):WaitForChild("MatchSettings"))
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local UnitData = require(ReplicatedStorage.UnitData)
local ArenaConfig = require(ReplicatedStorage.ArenaConfig)
local PlayerData = require(ReplicatedStorage.PlayerData)
local AttackAnimator = require(ReplicatedStorage.AttackAnimator)
local CombatController = {}
local active
local ranges = { 7, 14, 22, 32, 44 }
local colors = {
	["Master Roshu"] = Color3.fromRGB(65, 165, 255),
	Goku = Color3.fromRGB(255, 210, 70),
	Pikkolo = Color3.fromRGB(170, 85, 255),
	Tein = Color3.fromRGB(255, 155, 65),
}

local function position(unit)
	return unit.simPivot.Position
end

local function flatDistance(a, b)
	local delta = position(a) - position(b)
	return Vector2.new(delta.X, delta.Z).Magnitude
end

local function makeUnit(model)
	local id = model:GetAttribute("UnitId")
	local data = UnitData.get(id)
	if not data or not model.PrimaryPart then return nil end
	local side = model:GetAttribute("Side")
	local health, damage = data.health, data.damage
	if side == "player" then health, damage = PlayerData.unitStats(id, health, damage) end
	model:SetAttribute("Health", health)
	model:SetAttribute("MaxHealth", health)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.MaxHealth = health humanoid.Health = health end
	return {
		model = model, data = data, side = side, hp = health, maxHp = health,
		simPivot = model:GetPivot(), visualFrom = model:GetPivot(), visualTarget = model:GetPivot(),
		visualStarted = MatchClock.now(), visualDuration = 0.1,
		damage = damage, cooldown = 0.2, range = ranges[data.range.value] or 7,
	}
end

local function alive(unit)
	return unit.hp > 0 and unit.model.Parent ~= nil
end

local function nearestEnemy(unit, units)
	local nearest, distance = nil, math.huge
	if unit.target and alive(unit.target) then
		local current = flatDistance(unit, unit.target)
		if current <= unit.range then return unit.target, current end
	end
	for _, enemy in ipairs(units) do
		if enemy.side ~= unit.side and alive(enemy) then
			local current = flatDistance(unit, enemy)
			if current < distance then nearest, distance = enemy, current end
		end
	end
	return nearest, distance
end

local function effectPart(folder, color)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Parent = folder
	return part
end

local function flash(folder, point, color, size)
	local part = effectPart(folder, color)
	part.Name = "Impact"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * 0.3
	part.Position = point
	TweenService:Create(part, TweenInfo.new(0.2), { Size = Vector3.one * size, Transparency = 1 }):Play()
	Debris:AddItem(part, 0.22)
end

local function attackEffect(session, unit, target)
    if not MatchSettings.effectsEnabled() then return end
	local color = colors[unit.data.name] or Color3.fromRGB(255, 190, 100)
	local targetBody = target.model:FindFirstChild("UpperTorso") or target.model:FindFirstChild("Torso") or target.model.PrimaryPart
	local finish = targetBody.Position
	flash(session.effects, finish, color, unit.data.type == "Melee" and 1.8 or 2.6)
	if unit.data.type == "Melee" then return end
	local hand = unit.model:FindFirstChild("RightHand") or unit.model:FindFirstChild("Right Arm") or unit.model.PrimaryPart
	if unit.data.name == "Tein" then hand = unit.model:FindFirstChild("Head") or hand end
	local start = hand.Position
	local length = (finish - start).Magnitude
	if length < 0.1 then return end
	local thickness = unit.data.type == "Tank" and 0.9 or 0.35
	for i = 1, 2 do
		local beam = effectPart(session.effects, i == 1 and color or Color3.new(1, 1, 1))
		beam.Name = "EnergyBeam"
		local width = i == 1 and thickness * 2 or thickness
		beam.Size = Vector3.new(width, width, length)
		beam.CFrame = CFrame.lookAt((start + finish) / 2, finish)
		beam.Transparency = i == 1 and 0.55 or 0
		TweenService:Create(beam, TweenInfo.new(0.18), { Transparency = 1 }):Play()
		Debris:AddItem(beam, 0.2)
	end
end

local function defeat(unit)
	AttackAnimator.stop(unit.model)
	unit.model:SetAttribute("Defeated", true)
	for _, part in ipairs(unit.model:GetDescendants()) do
		if part:IsA("BasePart") then
			TweenService:Create(part, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		end
	end
	Debris:AddItem(unit.model, 0.45)
end

local function stepCombat(session, dt)
	local damage = {}
	for _, unit in ipairs(session.units) do
		if alive(unit) then
			unit.cooldown = math.max(0, unit.cooldown - dt)
			local target, distance = nearestEnemy(unit, session.units)
			unit.target = target
			if target then
				local point = position(unit)
				local direction = position(target) - point
				direction = Vector3.new(direction.X, 0, direction.Z)
				local moving = distance > unit.range
				if moving and direction.Magnitude > 0.01 then
					local speed = unit.data.mobile and 14 or 4.9
					point = ArenaConfig.clampPosition(point + direction.Unit * math.min(speed * dt, distance - unit.range + 0.05))
				end
				if direction.Magnitude > 0.01 then
					unit.simPivot = CFrame.lookAt(point, point + direction)
					unit.visualFrom = unit.model:GetPivot()
					unit.visualTarget = unit.simPivot
					unit.visualStarted = MatchClock.now()
					unit.visualDuration = dt
				end
				AttackAnimator.setWalking(unit.model, moving)
				if not moving and unit.cooldown <= 0 then
					AttackAnimator.play(unit.model, unit.data.name)
					attackEffect(session, unit, target)
					damage[target] = (damage[target] or 0) + unit.damage
					unit.cooldown = math.max(0.1, unit.data.hitSpeed)
					session.attacks += 1
				end
			else
				AttackAnimator.setWalking(unit.model, false)
			end
		end
	end
	for unit, amount in pairs(damage) do
		unit.hp = math.max(0, unit.hp - amount)
		unit.model:SetAttribute("Health", unit.hp)
		local humanoid = unit.model:FindFirstChildOfClass("Humanoid")
		if humanoid then humanoid.Health = math.max(0.01, unit.hp) end
		if unit.hp == 0 then defeat(unit) end
	end
	session.arena:SetAttribute("CombatAttacks", session.attacks)
end

local function renderCombat(session)
	if active ~= session or MatchClock.isPaused() then return end
	local now = MatchClock.now()
	for _, unit in ipairs(session.units) do
		if alive(unit) then
			local alpha = math.clamp((now - unit.visualStarted) / math.max(unit.visualDuration, 1 / 240), 0, 1)
			unit.model:PivotTo(unit.visualFrom:Lerp(unit.visualTarget, alpha))
		end
	end
end

local function result(session)
	local count = { player = 0, opponent = 0 }
	local health = { player = 0, opponent = 0 }
	local starting = { player = 0, opponent = 0 }
	for _, unit in ipairs(session.units) do
		starting[unit.side] += unit.maxHp
		if alive(unit) then
			count[unit.side] += 1
			health[unit.side] += unit.hp
		end
	end
	if count.player == 0 or count.opponent == 0 then
		return true, count.player > 0 and "player" or (count.opponent > 0 and "opponent" or nil)
	end
	if session.elapsed < session.limit then return false end
	local playerHealth = health.player / math.max(1, starting.player)
	local opponentHealth = health.opponent / math.max(1, starting.opponent)
	if math.abs(playerHealth - opponentHealth) < 0.001 then return true, nil end
	return true, playerHealth > opponentHealth and "player" or "opponent"
end

function CombatController.cancel()
	if active then
		if active.connection then active.connection:Disconnect() end
		if active.renderConnection then active.renderConnection:Disconnect() end
		for _, unit in ipairs(active.units) do
			if alive(unit) then unit.model:PivotTo(unit.simPivot) end
		end
		if active.effects then active.effects:Destroy() end
		active = nil
	end
	AttackAnimator.stopAll()
end

function CombatController.run(onEnd, options)
	CombatController.cancel()
	options = options or {}
	local arena = ArenaConfig.getArena()
	local folder = arena and arena:FindFirstChild("DeployedUnits")
	if not folder then task.defer(onEnd, nil) return end
	local session = { arena = arena, units = {}, elapsed = 0, accumulator = 0, attacks = 0, limit = options.timeLimit or 30 }
	session.effects = Instance.new("Folder")
	session.effects.Name = "CombatEffects"
	session.effects.Parent = arena
	for _, model in ipairs(folder:GetChildren()) do
		local unit = makeUnit(model)
		if unit then table.insert(session.units, unit) end
	end
	table.sort(session.units, function(a, b) return a.model:GetAttribute("SpawnIndex") < b.model:GetAttribute("SpawnIndex") end)
	active = session
	session.renderConnection = RunService.RenderStepped:Connect(function() renderCombat(session) end)
	arena:SetAttribute("CombatAttacks", 0)
	session.connection = RunService.Heartbeat:Connect(function(dt)
		if active ~= session then return end
		if not folder.Parent or (options.isCurrent and not options.isCurrent()) then
			CombatController.cancel()
			return
		end
        if MatchClock.isPaused() then return end
		session.elapsed += dt
		session.accumulator += dt
		if session.accumulator < 0.1 then return end
		local step = math.min(session.accumulator, 0.2)
		session.accumulator = 0
		stepCombat(session, step)
		local finished, winner = result(session)
		if finished then
			CombatController.cancel()
			arena:SetAttribute("LastRoundWinner", winner or "draw")
			task.defer(onEnd, winner)
		end
	end)
end

return CombatController


