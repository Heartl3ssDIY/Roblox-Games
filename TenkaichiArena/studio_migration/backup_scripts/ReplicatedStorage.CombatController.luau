--!strict
-- CombatController: runs stationary/advancing combat for deployed units.
-- Mobile units advance to the nearest enemy and stop when one is in range.
-- Fixed units hold. Units focus one target until it dies, attacking on cooldown.
-- Range asymmetry: a unit only damages enemies within ITS OWN range.
-- No animations (movement is a glide, attacks are instant damage).
-- First side wiped loses; stalemate -> lowest total HP loses.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UnitData = require(ReplicatedStorage.UnitData)
local ArenaConfig = require(ReplicatedStorage.ArenaConfig)
local PlayerData = require(ReplicatedStorage.PlayerData)
local AttackAnimator = require(ReplicatedStorage.AttackAnimator)

local CombatController = {}

-- Convert a unit's range value (1..5) to studs. Tunable later.
local RANGE_STUDS = { [1]=7, [2]=14, [3]=22, [4]=32, [5]=44 }
local function rangeStuds(unit)
	return RANGE_STUDS[unit.range.value] or (unit.range.value * 8)
end

local MOVE_SPEED = 14   -- studs/sec glide for mobile units
local TICK = 0.1        -- combat step interval

-- Build a live combat-unit record from a deployed model.
local function makeCombatUnit(model)
	local unitId = model:GetAttribute("UnitId")
	local data = UnitData.get(unitId)
	if not data then return nil end
	local hum = model:FindFirstChildOfClass("Humanoid")
	local side = model:GetAttribute("Side")
	-- The PLAYER's units use their leveled stats (compounded +10%/level). The
	-- opponent AI uses base stats (the AI doesn't level units).
	local hp, dmg = data.health, data.damage
	if side == "player" then
		hp, dmg = PlayerData.unitStats(unitId, data.health, data.damage)
	end
	return {
		model = model,
		data = data,
		side = side,
		hp = hp,
		maxHp = hp,
		dmg = dmg,
		hum = hum,
		cooldown = 0,
		target = nil,         -- current focused enemy record
		alive = true,
		rangeStuds = rangeStuds(data),
		mobile = data.mobile,
	}
end

local function pos(u) return u.model:GetPivot().Position end
local function dist(a, b) return (pos(a) - pos(b)).Magnitude end

CombatController._makeCombatUnit = makeCombatUnit
CombatController._dist = dist
CombatController._pos = pos
CombatController.RANGE_STUDS = RANGE_STUDS
CombatController.MOVE_SPEED = MOVE_SPEED
CombatController.TICK = TICK

-- Per-unit beam styling: core color, glow color, and thickness.
local BEAM_STYLE = {
	["Master Roshu"] = { core = Color3.fromRGB(150, 210, 255), glow = Color3.fromRGB(60, 120, 255),  thick = 1.1 },
	Goku             = { core = Color3.fromRGB(255, 255, 200), glow = Color3.fromRGB(255, 200, 60),  thick = 0.7 },
	Pikkolo          = { core = Color3.fromRGB(220, 180, 255), glow = Color3.fromRGB(150, 70, 230),  thick = 0.7 },
	Tein             = { core = Color3.fromRGB(255, 235, 180), glow = Color3.fromRGB(255, 170, 50),  thick = 0.6 },
	Bluma            = { core = Color3.fromRGB(255, 240, 210), glow = Color3.fromRGB(255, 150, 60),  thick = 0.45 },
	Krillen          = { core = Color3.fromRGB(255, 230, 200), glow = Color3.fromRGB(255, 160, 90),  thick = 0.4 },
	Yumcha           = { core = Color3.fromRGB(255, 230, 200), glow = Color3.fromRGB(255, 160, 90),  thick = 0.4 },
}
local DEFAULT_BEAM = { core = Color3.fromRGB(255, 235, 200), glow = Color3.fromRGB(255, 170, 90), thick = 0.4 }

local function makeNeonPart(parent, color, material)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = material or Enum.Material.Neon
	p.Color = color
	p.Parent = parent
	return p
end

-- A brief glowing point-flash (muzzle / impact burst) that pops and fades.
local function spawnFlash(parent, position, color, size)
	local f = makeNeonPart(parent, color)
	f.Shape = Enum.PartType.Ball
	f.Size = Vector3.new(0.2, 0.2, 0.2)
	f.CFrame = CFrame.new(position)
	local light = Instance.new("PointLight")
	light.Color = color; light.Range = size * 4; light.Brightness = 4; light.Parent = f
	task.spawn(function()
		for i = 1, 6 do
			local a = i / 6
			f.Size = Vector3.new(size, size, size) * (0.4 + a)
			f.Transparency = a
			light.Brightness = 4 * (1 - a)
			task.wait(0.025)
		end
		f:Destroy()
	end)
end

-- Flashier attack beam: a bright neon core wrapped in a translucent glow, with a
-- muzzle burst at the firing point and an impact burst at the target.
local function spawnAttackVisual(attacker, target)
	local a = pos(attacker) + Vector3.new(0, 3, 0)
	local b = pos(target) + Vector3.new(0, 3, 0)
	local mid = (a + b) / 2
	local len = (b - a).Magnitude
	if len < 0.1 then return end

	local style = BEAM_STYLE[attacker.data.name] or DEFAULT_BEAM
	local parent = attacker.model.Parent
	local cf = CFrame.lookAt(mid, b)

	-- bright inner core
	local core = makeNeonPart(parent, style.core)
	core.Size = Vector3.new(style.thick, style.thick, len)
	core.CFrame = cf
	-- translucent outer glow (thicker, softer)
	local glow = makeNeonPart(parent, style.glow)
	glow.Size = Vector3.new(style.thick * 2.6, style.thick * 2.6, len)
	glow.CFrame = cf
	glow.Transparency = 0.55

	-- muzzle flash at the attacker, impact flash at the target
	spawnFlash(parent, a, style.glow, style.thick * 5)
	spawnFlash(parent, b, style.core, style.thick * 6)

	-- expand slightly then fade out
	task.spawn(function()
		for i = 1, 7 do
			local t = i / 7
			core.Transparency = t
			glow.Transparency = 0.55 + t * 0.45
			local grow = 1 + t * 0.6
			core.Size = Vector3.new(style.thick * grow, style.thick * grow, len)
			glow.Size = Vector3.new(style.thick * 2.6 * grow, style.thick * 2.6 * grow, len)
			task.wait(0.022)
		end
		core:Destroy(); glow:Destroy()
	end)
end

-- Apply damage to a unit; update its Humanoid health bar; mark dead at 0.
local function damage(u, amount)
	u.hp = math.max(0, u.hp - amount)
	if u.hum then u.hum.Health = (u.hp / u.maxHp) * u.hum.MaxHealth end
	if u.hp <= 0 and u.alive then
		u.alive = false
		-- Death animation: the unit topples over (falls) and fades out over ~0.5s.
		task.spawn(function()
			AttackAnimator.setWalking(u.model, false)
			local model = u.model
			local startPivot = model:GetPivot()
			-- tip over: rotate ~90° onto the back while sinking slightly, over 0.28s
			-- (pick a fall direction away from the attacker / toward +X for variety)
			local fallAxis = (math.random() < 0.5) and 1 or -1
			local endPivot = startPivot
				* CFrame.Angles(math.rad(92 * fallAxis), 0, 0)
				+ Vector3.new(0, -1.5, 0)
			local fallTime = 0.28
			local t0 = os.clock()
			while os.clock() - t0 < fallTime do
				local a = (os.clock() - t0) / fallTime
				-- ease-in (accelerate as it falls)
				a = a * a
				pcall(function() model:PivotTo(startPivot:Lerp(endPivot, a)) end)
				task.wait()
			end
			pcall(function() model:PivotTo(endPivot) end)
			-- fade out over ~0.5s, then remove
			local parts = {}
			for _, p in ipairs(model:GetDescendants()) do
				if p:IsA("BasePart") or p:IsA("Decal") or p:IsA("Texture") then
					table.insert(parts, p)
				end
			end
			local steps = 12
			for i = 1, steps do
				local tr = i / steps
				for _, p in ipairs(parts) do
					pcall(function() p.Transparency = tr end)
				end
				task.wait(0.5 / steps)
			end
			model:Destroy()
		end)
	end
end

-- Find an enemy in range for unit u (any enemy in range; keeps current target if still valid).
local function acquireTarget(u, enemies)
	-- keep focusing current target if alive and in range
	if u.target and u.target.alive then
		if dist(u, u.target) <= u.rangeStuds then return u.target end
	end
	-- otherwise pick any enemy currently in range
	for _, e in ipairs(enemies) do
		if e.alive and dist(u, e) <= u.rangeStuds then
			return e
		end
	end
	return nil
end

-- Nearest living enemy (for mobile units to advance toward).
local function nearestEnemy(u, enemies)
	local best, bestD = nil, math.huge
	for _, e in ipairs(enemies) do
		if e.alive then
			local d = dist(u, e)
			if d < bestD then best, bestD = e, d end
		end
	end
	return best, bestD
end

-- Glide a unit toward a target position by up to `step` studs (no animation).
local function glideToward(u, targetPos, step)
	local p = pos(u)
	local flatTarget = Vector3.new(targetPos.X, p.Y, targetPos.Z)
	local delta = flatTarget - p
	if delta.Magnitude <= step then
		u.model:PivotTo(CFrame.lookAt(flatTarget, flatTarget + (u.side=="player" and Vector3.new(0,0,1) or Vector3.new(0,0,-1))))
	else
		local move = delta.Unit * step
		local newPos = p + move
		u.model:PivotTo(CFrame.lookAt(newPos, newPos + (u.side=="player" and Vector3.new(0,0,1) or Vector3.new(0,0,-1))))
	end
end

-- Run combat to a conclusion. Returns "player" or "opponent" (the WINNER).
-- onEnd(winner) called when done. Runs async.
function CombatController.run(onEnd)
	local arena = workspace:FindFirstChild(ArenaConfig.arenaName)
	local folder = arena and arena:FindFirstChild("DeployedUnits")
	if not folder then if onEnd then onEnd(nil) end return end

	-- build unit records
	local units = {}
	for _, m in ipairs(folder:GetChildren()) do
		local cu = makeCombatUnit(m)
		if cu then table.insert(units, cu) end
	end

	local function sideUnits(side, aliveOnly)
		local t = {}
		for _, u in ipairs(units) do
			if u.side == side and (not aliveOnly or u.alive) then table.insert(t, u) end
		end
		return t
	end

	task.spawn(function()
		local elapsed = 0
		local STALEMATE_TIME = 25  -- seconds before forcing a result
		while true do
			-- check end conditions
			local pAlive = #sideUnits("player", true)
			local oAlive = #sideUnits("opponent", true)
			if pAlive == 0 or oAlive == 0 then
				local winner = (pAlive > 0) and "player" or (oAlive > 0 and "opponent" or nil)
				if onEnd then onEnd(winner) end
				return
			end
			if elapsed >= STALEMATE_TIME then
				-- stalemate: lowest total HP loses
				local function totalHp(side)
					local s = 0
					for _, u in ipairs(units) do if u.side==side and u.alive then s += u.hp end end
					return s
				end
				local pHp, oHp = totalHp("player"), totalHp("opponent")
				local winner = (pHp >= oHp) and "player" or "opponent"
				if onEnd then onEnd(winner) end
				return
			end

			-- step each living unit
			for _, u in ipairs(units) do
				if u.alive then
					local enemies = sideUnits(u.side == "player" and "opponent" or "player", true)
					local target = acquireTarget(u, enemies)
					if target then
						u.target = target
						-- in range: stop walking, attack on cooldown
						AttackAnimator.setWalking(u.model, false)
						u.cooldown -= TICK
						if u.cooldown <= 0 then
							AttackAnimator.play(u.model, u.data.name, u.side)
							spawnAttackVisual(u, target)
							damage(target, u.dmg)
							u.cooldown = u.data.hitSpeed
						end
					else
						-- no enemy in range: advance toward nearest enemy (walking).
						-- Mobile units move full speed; fixed units slow-creep.
						u.target = nil
						local ne = nearestEnemy(u, enemies)
						if ne then
							local speed = u.mobile and MOVE_SPEED or (MOVE_SPEED * 0.35)
							glideToward(u, pos(ne), speed * TICK)
							AttackAnimator.setWalking(u.model, true)
						else
							AttackAnimator.setWalking(u.model, false)
						end
					end
				end
			end

			task.wait(TICK)
			elapsed += TICK
		end
	end)
end

return CombatController

