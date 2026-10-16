local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local MatchClock = require(ReplicatedStorage:WaitForChild("MatchClock"))
local MatchSettings = require(ReplicatedStorage:WaitForChild("MatchSettings"))
local UnitData = require(ReplicatedStorage.UnitData)
local ArenaConfig = require(ReplicatedStorage.ArenaConfig)
local PlayerData = require(ReplicatedStorage.PlayerData)
local AttackAnimator = require(ReplicatedStorage.AttackAnimator)
local RockAnimationPlayer = require(ReplicatedStorage:WaitForChild("RockAnimationPlayer"))
local AttackTimeline = require(ReplicatedStorage:WaitForChild("AttackTimeline"))
local CombatVFX = require(ReplicatedStorage:WaitForChild("CombatVFX"))
local CombatSFX = require(ReplicatedStorage:WaitForChild("CombatSFX"))
local CombatController = {}
local active
local ranges = {7, 14, 22, 32, 44}
local ROCK_FIST_RADIUS = 0.45
local ROCK_FIST_EXIT_PADDING = 0.4
local ROCK_MAX_SWEEP_SECONDS = 0.1
local ROCK_MAX_SWEEP_STUDS = 3.5
local BEERAS_PIERCE_EXTRA = ArenaConfig.lineZ.back - ArenaConfig.lineZ.front + 1
local BEERAS_BEAM_RADIUS = 1.25
local colors = {
    ["Master Roshu"] = Color3.fromRGB(65, 165, 255),
    Guku = Color3.fromRGB(255, 210, 70),
    Pikkolo = Color3.fromRGB(170, 85, 255),
    Beeras = Color3.fromRGB(168, 77, 255),
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
    local masteryForm = side == "player" and model:GetAttribute("MasteryForm") == true
    if masteryForm then
        health = math.floor(health * (data.masteryHealthMultiplier or 1) + .5)
        damage = math.floor(damage * (data.masteryDamageMultiplier or 1) + .5)
    end
    model:SetAttribute("Health", health)
    model:SetAttribute("MaxHealth", health)
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid then humanoid.MaxHealth = health humanoid.Health = health end
    local joints = {}
    for _, joint in ipairs(model:GetDescendants()) do
        if joint:IsA("Motor6D") and joint.Part0 and joint.Part1 then joints[joint.Part1] = joint end
    end
    local profile = AttackTimeline.get(data.name, data.type, masteryForm and data.masteryHitSpeed or data.hitSpeed, masteryForm)
    model:SetAttribute("AttackCooldown", profile.cooldown)
    return {
        model = model, data = data, side = side, hp = health, maxHp = health,
        simPivot = model:GetPivot(), visualFrom = model:GetPivot(), visualTarget = model:GetPivot(),
        visualStarted = MatchClock.now(), visualDuration = .1,
        damage = damage, nextAttackAt = MatchClock.now() + .2,
        profile = profile, joints = joints,
        range = data.id == "RockLee" and 3 or (ranges[data.range.value] or 7),
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

local function beerasTargets(session, attacker, direction, reach)
    local hits = {}
    local origin = position(attacker)
    for _, enemy in ipairs(session.units) do
        if enemy.side ~= attacker.side and alive(enemy) then
            local offset = position(enemy) - origin
            local flat = Vector3.new(offset.X, 0, offset.Z)
            local along = flat:Dot(direction)
            if along >= 0 and along <= reach then
                local part = enemy.model.PrimaryPart
                local bodyRadius = part and math.max(part.Size.X, part.Size.Z) * .5 or 1
                local lateral = (flat - direction * along).Magnitude
                if lateral <= BEERAS_BEAM_RADIUS + bodyRadius then
                    table.insert(hits, {unit = enemy, along = along})
                end
            end
        end
    end
    table.sort(hits, function(a, b) return a.along < b.along end)
    return hits
end

local function effectPart(folder, color, name)
    local part = Instance.new("Part")
    part.Name = name
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.CastShadow = false
    part.Material = Enum.Material.Neon
    part.Color = color
    part.Transparency = 1
    part.Parent = folder
    return part
end

local function colorFor(unit)
    return colors[unit.data.name] or Color3.fromRGB(255, 190, 100)
end

local function posedFrame(unit, part, visited)
    local joint = unit.joints[part]
    if not joint or not joint.Parent or not joint.Part0 then return part.CFrame end
    visited = visited or {}
    if visited[part] then return part.CFrame end
    visited[part] = true
    return posedFrame(unit, joint.Part0, visited) * joint.C0 * joint.Transform * joint.C1:Inverse()
end

local function palm(unit, right)
    local model = unit.model
    local part = model:FindFirstChild(right and "RightHand" or "LeftHand")
        or model:FindFirstChild(right and "Right Arm" or "Left Arm") or model.PrimaryPart
    if not part then return model:GetPivot().Position end
    return posedFrame(unit, part):PointToWorldSpace(Vector3.new(0, -part.Size.Y * .4, -.08))
end

local function emissionPoint(unit)
    local right = palm(unit, true)
    if unit.profile.kind == "Roshi" or unit.data.name == "Tein" then
        return (right + palm(unit, false)) / 2
    end
    return right
end

local function bodyPoint(unit)
    local body = unit.model:FindFirstChild("UpperTorso") or unit.model:FindFirstChild("Torso") or unit.model.PrimaryPart
    return body and posedFrame(unit, body).Position or position(unit)
end

local function clearCharge(attack)
    if attack.charge then
        for _, part in ipairs(attack.charge) do part:Destroy() end
        attack.charge = nil
    end
end

local function beginAttack(session, unit, target, now)
    local profile = unit.profile
    local attack = {target = target, started = now, released = false}
    unit.attack = attack
    unit.nextAttackAt = now + profile.cooldown
    if profile.kind ~= "Rock" then
        AttackAnimator.setWalking(unit.model, false)
        AttackAnimator.play(unit.model, unit.data.name, profile, now)
    else
        RockAnimationPlayer.playAttack(unit.model, now, unit.model:GetAttribute("MasteryForm") == true)
    end
    CombatSFX.charge(emissionPoint(unit), profile.kind)
    if (unit.data.type ~= "Melee" or unit.data.id == "Beeras") and MatchSettings.effectsEnabled() then
        attack.charge = {
            effectPart(session.effects, colorFor(unit), "ChargeGlow"),
            effectPart(session.effects, Color3.new(1, 1, 1), "ChargeCore"),
        }
        for _, part in ipairs(attack.charge) do part.Shape = Enum.PartType.Ball end
    end
end

local function releaseEffect(session, unit, target, now, direction, reach)
    if not MatchSettings.effectsEnabled() then return end
    local color = colorFor(unit)
    local hit = effectPart(session.effects, color, "Impact")
    hit.Shape = Enum.PartType.Ball
    local shot = {
        unit = unit, target = target, direction = direction, reach = reach, started = now,
        duration = math.max(.22, unit.profile.beamDuration),
        finish = direction and (emissionPoint(unit) + direction * reach) or bodyPoint(target), impact = hit,
    }
    if unit.data.type ~= "Melee" or unit.data.id == "Beeras" then
        shot.beams = {
            effectPart(session.effects, color, "EnergyGlow"),
            effectPart(session.effects, Color3.new(1, 1, 1), "EnergyCore"),
        }
        for _, beam in ipairs(shot.beams) do beam.Shape = Enum.PartType.Cylinder end
    end
    table.insert(session.shots, shot)
end

local function releaseCue(session, unit, direction, leftHand)
    local point = leftHand and palm(unit, false) or emissionPoint(unit)
    CombatSFX.release(point, unit.profile.kind)
    CombatVFX.muzzle(session.effects, point, direction, colorFor(unit), unit.profile.kind)
end

local function hitCue(session, attacker, target)
    local point = bodyPoint(target)
    CombatSFX.hit(point)
    CombatVFX.hit(session.effects, point, colorFor(attacker), attacker.profile.kind)
end

local function defeat(unit)
    if unit.attack then clearCharge(unit.attack); unit.attack = nil end
    CombatSFX.knockout(bodyPoint(unit))
    AttackAnimator.stop(unit.model)
    RockAnimationPlayer.stop(unit.model)
    unit.model:SetAttribute("Defeated", true)
    for _, part in ipairs(unit.model:GetDescendants()) do
        if part:IsA("BasePart") then
            TweenService:Create(part, TweenInfo.new(.4), {Transparency = 1}):Play()
        end
    end
    Debris:AddItem(unit.model, .45)
end

local function applyDamage(session, damage)
    for unit, amount in pairs(damage) do
        if unit.ability then amount = 0 end
        local wasAlive = unit.hp > 0
        unit.hp = math.max(0, unit.hp - amount)
        unit.model:SetAttribute("Health", unit.hp)
        local humanoid = unit.model:FindFirstChildOfClass("Humanoid")
        if humanoid then humanoid.Health = math.max(.01, unit.hp) end
        if wasAlive and unit.hp == 0 then
            defeat(unit)
            if unit.side == "opponent" and session.onOpponentDefeated then
                local ok, reason = pcall(session.onOpponentDefeated)
                if not ok then warn("Opponent defeat callback failed: " .. tostring(reason)) end
            end
        end
    end
end

local function updateAttacks(session, now)
    local damage = {}
    for _, unit in ipairs(session.units) do
        local attack = unit.attack
        if attack then
            if not alive(unit) then
                clearCharge(attack)
                unit.attack = nil
            else
                local age = now - attack.started
                if unit.profile.kind == "Rock" then
                    local punches = unit.profile.punchTimes
                    while (attack.punchesApplied or 0) < #punches and age >= punches[(attack.punchesApplied or 0) + 1] do
                        attack.punchesApplied = (attack.punchesApplied or 0) + 1
                        if alive(attack.target) and flatDistance(unit, attack.target) <= unit.range + .15 then
                            attack.released = true
                            releaseEffect(session, unit, attack.target, now)
                            releaseCue(session, unit, nil, attack.punchesApplied % 2 == 0)
                            damage[attack.target] = (damage[attack.target] or 0) + unit.damage
                            hitCue(session, unit, attack.target)
                            session.attacks += 1
                        end
                    end
                elseif not attack.released and age >= unit.profile.releaseAt then
                    attack.released = true
                    clearCharge(attack)
                    AttackAnimator.poseNow(unit.model, age)
                    if unit.data.id == "Beeras" then
                        local look = unit.simPivot.LookVector
                        local direction = Vector3.new(look.X, 0, look.Z).Unit
                        local reach = unit.range + BEERAS_PIERCE_EXTRA
                        releaseEffect(session, unit, nil, now, direction, reach)
                        releaseCue(session, unit, direction)
                        for _, hit in ipairs(beerasTargets(session, unit, direction, reach)) do
                            damage[hit.unit] = (damage[hit.unit] or 0) + unit.damage
                            hitCue(session, unit, hit.unit)
                        end
                        session.attacks += 1
                    elseif alive(attack.target) and flatDistance(unit, attack.target) <= unit.range + .75 then
                        releaseEffect(session, unit, attack.target, now)
                        releaseCue(session, unit)
                        damage[attack.target] = (damage[attack.target] or 0) + unit.damage
                        hitCue(session, unit, attack.target)
                        session.attacks += 1
                    end
                end
                if age >= unit.profile.duration then
                    clearCharge(attack)
                    unit.attack = nil
                end
            end
        end
    end
    applyDamage(session, damage)
    session.arena:SetAttribute("CombatAttacks", session.attacks)
end

local function stepRockAbility(session, unit, now, dt)
    local ability = unit.ability
    local age = math.clamp(now - ability.started, 0, 7)
    local travel = ability.routeLength * (age / 7)
    local points = ability.points
    local point = points[#points]
    for index, length in ipairs(ability.segments) do
        if travel <= length or index == #ability.segments then
            point = points[index]:Lerp(points[index + 1], math.clamp(travel / math.max(length, .001), 0, 1))
            break
        end
        travel -= length
    end
    unit.simPivot = CFrame.lookAt(point, point + ArenaConfig.facing("player"))
    unit.visualFrom = unit.model:GetPivot()
    unit.visualTarget = unit.simPivot
    unit.visualStarted = now
    unit.visualDuration = dt

    if age >= 7 then
        unit.ability = nil
        unit.model:SetAttribute("DrunkenFistActive", false)
        unit.nextAttackAt = now + .2
    end
end

local function segmentDistanceSquared(point, a, b)
    local span = b - a
    local lengthSquared = span:Dot(span)
    local fraction = lengthSquared > 1e-5 and math.clamp((point - a):Dot(span) / lengthSquared, 0, 1) or 0
    local offset = point - (a + span * fraction)
    return offset:Dot(offset)
end

local function stepRockFistContacts(session, unit, now)
    local ability = unit.ability
    if not ability then return end
    local age = now - ability.started
    local right = palm(unit, true)
    local left = palm(unit, false)
    local previousRight = ability.lastRightPalm or right
    local previousLeft = ability.lastLeftPalm or left
    local previousAge = ability.lastFistSampleAge
    local canSweep = previousAge and age - previousAge <= ROCK_MAX_SWEEP_SECONDS
    local fistPoints = {
        {previous = previousRight, current = right, contacts = ability.fistContacts[1]},
        {previous = previousLeft, current = left, contacts = ability.fistContacts[2]},
    }
    local damage = {}
    local impactPalm
    for _, enemy in ipairs(session.units) do
        if enemy.side ~= unit.side and alive(enemy) then
            local body = enemy.model:FindFirstChild("UpperTorso") or enemy.model:FindFirstChild("Torso") or enemy.model.PrimaryPart
            local bodyRadius = body and math.max(body.Size.X, body.Size.Z) * 0.5 or 1
            local enterRadius = bodyRadius + ROCK_FIST_RADIUS
            local exitRadius = enterRadius + ROCK_FIST_EXIT_PADDING
            local currentBody = bodyPoint(enemy)
            local previousBody = ability.lastBodyPositions[enemy] or currentBody
            for _, fist in ipairs(fistPoints) do
                local relativeCurrent = fist.current - currentBody
                local currentDistanceSquared = relativeCurrent:Dot(relativeCurrent)
                if fist.contacts[enemy] then
                    if currentDistanceSquared > exitRadius * exitRadius then
                        fist.contacts[enemy] = nil
                    end
                else
                    local entered = currentDistanceSquared <= enterRadius * enterRadius
                    if not entered and canSweep then
                        local relativePrevious = fist.previous - previousBody
                        local travel = relativeCurrent - relativePrevious
                        if travel.Magnitude <= ROCK_MAX_SWEEP_STUDS then
                            entered = segmentDistanceSquared(Vector3.zero, relativePrevious, relativeCurrent)
                                <= enterRadius * enterRadius
                        end
                    end
                    if entered then
                        -- The first rendered pose is a baseline, not a new impact.
                        if previousAge then
                            damage[enemy] = (damage[enemy] or 0) + 50
                            impactPalm = impactPalm or fist.current
                            hitCue(session, unit, enemy)
                            session.attacks += 1
                        end
                        if currentDistanceSquared <= exitRadius * exitRadius then
                            fist.contacts[enemy] = true
                        end
                    end
                end
            end
            ability.lastBodyPositions[enemy] = currentBody
        end
    end
    ability.lastRightPalm, ability.lastLeftPalm = right, left
    ability.lastFistSampleAge = age
    if next(damage) then
        CombatSFX.release(impactPalm or emissionPoint(unit), "Rock")
        applyDamage(session, damage)
        session.arena:SetAttribute("CombatAttacks", session.attacks)
    end
end

local function stepCombat(session, dt, now)
    for _, unit in ipairs(session.units) do
        if alive(unit) then
            if unit.ability then
                stepRockAbility(session, unit, now, dt)
            elseif unit.attack then
                if unit.profile.kind ~= "Rock" then AttackAnimator.setWalking(unit.model, false) end
            else
                local target, distance = nearestEnemy(unit, session.units)
                unit.target = target
                if target then
                    local point = position(unit)
                    local direction = position(target) - point
                    direction = Vector3.new(direction.X, 0, direction.Z)
                    local moving = distance > unit.range
                    if moving and direction.Magnitude > .01 then
                        local speed = unit.data.mobile and 14 or 4.9
                        point = ArenaConfig.clampPosition(point + direction.Unit * math.min(speed * dt, distance - unit.range + .05))
                    end
                    if direction.Magnitude > .01 then
                        unit.simPivot = CFrame.lookAt(point, point + direction)
                        unit.visualFrom = unit.model:GetPivot()
                        unit.visualTarget = unit.simPivot
                        unit.visualStarted = now
                        unit.visualDuration = dt
                    end
                    if unit.profile.kind ~= "Rock" then AttackAnimator.setWalking(unit.model, moving) end
                    if not moving and now >= unit.nextAttackAt then beginAttack(session, unit, target, now) end
                else
                    if unit.profile.kind ~= "Rock" then AttackAnimator.setWalking(unit.model, false) end
                end
            end
        end
    end
end

local function renderEffects(session, now)
    local enabled = MatchSettings.effectsEnabled()
    for _, unit in ipairs(session.units) do
        local attack = unit.attack
        if attack and attack.charge then
            local age = now - attack.started
            local chargeStart = unit.profile.kind == "Roshi" and .48 or 0
            local progress = math.clamp((age - chargeStart) / math.max(.01, unit.profile.releaseAt - chargeStart), 0, 1)
            local size = .14 + progress * (unit.profile.kind == "Roshi" and 1.15 or unit.profile.kind == "Beeras" and 1.05 or .6)
            local point = emissionPoint(unit)
            for i, part in ipairs(attack.charge) do
                part.Position = point
                part.Size = Vector3.one * size * (i == 1 and 1.65 or .7)
                part.Transparency = enabled and age >= chargeStart and (i == 1 and .6 - .22 * progress or .2) or 1
            end
        end
    end
    for index = #session.shots, 1, -1 do
        local shot = session.shots[index]
        local age = now - shot.started
        if age >= shot.duration then
            shot.impact:Destroy()
            if shot.beams then for _, beam in ipairs(shot.beams) do beam:Destroy() end end
            table.remove(session.shots, index)
        else
            local fade = math.clamp(age / shot.duration, 0, 1)
            if shot.direction then
                shot.finish = emissionPoint(shot.unit) + shot.direction * shot.reach
            elseif shot.target.model.Parent then
                shot.finish = bodyPoint(shot.target)
            end
            shot.impact.Position = shot.finish
            shot.impact.Size = Vector3.one * (.3 + fade * (shot.unit.profile.kind == "Roshi" and 3.3 or shot.unit.profile.kind == "Beeras" and 2.2 or 1.7))
            shot.impact.Transparency = enabled and fade or 1
            if shot.beams then
                local start = emissionPoint(shot.unit)
                local distance = (shot.finish - start).Magnitude
                local beamFade = math.clamp(age / math.max(.01, shot.unit.profile.beamDuration), 0, 1)
                local width = (shot.unit.profile.kind == "Roshi" and 1.0 or shot.unit.profile.kind == "Beeras" and .65 or .32) * (1 - beamFade * .55)
                local beamFrame = distance > .01 and CFrame.lookAt((start + shot.finish) / 2, shot.finish) * CFrame.Angles(0, math.pi / 2, 0)
                for i, beam in ipairs(shot.beams) do
                    if beamFrame then
                        beam.Size = Vector3.new(math.max(.01, distance), width * (i == 1 and 2.5 or 1), width * (i == 1 and 2.5 or 1))
                        beam.CFrame = beamFrame
                    end
                    beam.Transparency = enabled and beamFrame and (i == 1 and .55 + beamFade * .45 or beamFade) or 1
                end
            end
        end
    end
end

local function renderCombat(session)
    if active ~= session then return end
    local now = MatchClock.now()
    if not MatchClock.isPaused() then
        for _, unit in ipairs(session.units) do
            if alive(unit) and unit.profile.kind ~= "Rock" then
                local alpha = math.clamp((now - unit.visualStarted) / math.max(unit.visualDuration, 1 / 240), 0, 1)
                unit.model:PivotTo(unit.visualFrom:Lerp(unit.visualTarget, alpha))
            end
        end
    end
    renderEffects(session, now)
end

local function poseRockUnits(session)
    if active ~= session then return end
    local now = MatchClock.now()
    local paused = MatchClock.isPaused()
    for _, unit in ipairs(session.units) do
        if unit.profile.kind == "Rock" then
            RockAnimationPlayer.sync(unit.model)
            if not paused and alive(unit) then
                local alpha = math.clamp((now - unit.visualStarted) / math.max(unit.visualDuration, 1 / 240), 0, 1)
                unit.model:PivotTo(unit.visualFrom:Lerp(unit.visualTarget, alpha))
            end
        end
    end
end

local function sampleRockFistContacts(session)
    if active ~= session or MatchClock.isPaused() then return end
    local now = MatchClock.now()
    for _, unit in ipairs(session.units) do
        if alive(unit) and unit.ability then stepRockFistContacts(session, unit, now) end
    end
end

local function result(session)
    local count = {player = 0, opponent = 0}
    local health = {player = 0, opponent = 0}
    local starting = {player = 0, opponent = 0}
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
    if math.abs(playerHealth - opponentHealth) < .001 then return true, nil end
    return true, playerHealth > opponentHealth and "player" or "opponent"
end

local function splitPikkolos(session)
    local originals = {}
    for _, unit in ipairs(session.units) do
        if unit.side == "player" and unit.data.id == "Pikkolo" and alive(unit) and not unit.model:GetAttribute("SplitClone") then
            table.insert(originals, unit)
        end
    end
    if #originals == 0 then return false, "Pikkolo is not active" end

    local now = MatchClock.now()
    for _, unit in ipairs(originals) do
        if unit.attack then clearCharge(unit.attack); unit.attack = nil end
        AttackAnimator.stop(unit.model)
        local cape = unit.model:FindFirstChild("Cape")
        if cape and cape:IsA("Accessory") then cape:Destroy() end

        local duplicate = unit.model:Clone()
        duplicate.Name = unit.model.Name .. "_Split"
        duplicate:SetAttribute("SplitClone", true)
        duplicate:SetAttribute("NameekianSplitActive", true)
        duplicate:SetAttribute("SpawnIndex", (unit.model:GetAttribute("SpawnIndex") or 0) + 10000 + #session.units)
        unit.model:SetAttribute("NameekianSplitActive", true)

        local facing = unit.simPivot.LookVector
        local right = unit.simPivot.RightVector
        local center = unit.simPivot.Position
        local originalPoint = ArenaConfig.clampPosition(center - right * 1.6)
        local duplicatePoint = ArenaConfig.clampPosition(center + right * 1.6)
        unit.simPivot = CFrame.lookAt(originalPoint, originalPoint + facing)
        unit.visualFrom, unit.visualTarget = unit.simPivot, unit.simPivot
        unit.visualStarted, unit.visualDuration = now, .1
        unit.model:PivotTo(unit.simPivot)
        unit.nextAttackAt = now + .25

        duplicate:PivotTo(CFrame.lookAt(duplicatePoint, duplicatePoint + facing))
        duplicate.Parent = unit.model.Parent
        local copy = makeUnit(duplicate)
        if copy then
            copy.hp, copy.maxHp, copy.damage = unit.hp, unit.maxHp, unit.damage
            copy.nextAttackAt = now + .25
            duplicate:SetAttribute("Health", copy.hp)
            duplicate:SetAttribute("MaxHealth", copy.maxHp)
            local humanoid = duplicate:FindFirstChildOfClass("Humanoid")
            if humanoid then humanoid.MaxHealth = copy.maxHp; humanoid.Health = math.max(.01, copy.hp) end
            table.insert(session.units, copy)
            CombatVFX.muzzle(session.effects, bodyPoint(copy), nil, Color3.fromRGB(55, 225, 255), "Pikkolo")
        else
            duplicate:Destroy()
        end
        CombatVFX.muzzle(session.effects, bodyPoint(unit), nil, Color3.fromRGB(55, 225, 255), "Pikkolo")
        CombatSFX.release(emissionPoint(unit), "Pikkolo")
    end
    return true
end

function CombatController.useAbility(unitId)
    local session = active
    if not session or session.finishAt or MatchClock.isPaused() then return false, "Ability is unavailable now" end
    if session.abilityUsed[unitId] then return false, "Already used this round" end
    if unitId == "Pikkolo" then
        local success, reason = splitPikkolos(session)
        if success then session.abilityUsed[unitId] = true end
        return success, reason
    end
    if unitId ~= "RockLee" then return false, "Ability is unavailable" end
    local unit
    for _, candidate in ipairs(session.units) do
        if candidate.side == "player" and candidate.data.id == unitId and alive(candidate) and not candidate.ability then
            unit = candidate
            break
        end
    end
    if not unit then return false, "Rock Lii is not active" end
    if unit.attack then clearCharge(unit.attack); unit.attack = nil end
    local origin = ArenaConfig.getOrigin()
    if not origin then return false, "Arena origin is missing" end
    RockAnimationPlayer.stop(unit.model)
    local start = unit.simPivot.Position
    local localStart = origin.CFrame:PointToObjectSpace(start)
    local function atLine(line)
        return origin.CFrame:PointToWorldSpace(Vector3.new(localStart.X, localStart.Y, ArenaConfig.lineZ[line]))
    end
    local rows = {front = {}, mid = {}, back = {}}
    for _, enemy in ipairs(session.units) do
        if enemy.side ~= unit.side and alive(enemy) then
            local line = ArenaConfig.lineForUnit(enemy.data)
            table.insert(rows[line == "tank" and "back" or line] or rows.front, enemy)
        end
    end
    local points = {start}
    for _, line in ipairs({"front", "mid", "back"}) do
        local row = rows[line]
        table.sort(row, function(a, b)
            return origin.CFrame:PointToObjectSpace(position(a)).X < origin.CFrame:PointToObjectSpace(position(b)).X
        end)
        if #row == 0 then
            table.insert(points, atLine(line))
        else
            for _, enemy in ipairs(row) do
                local enemyPoint = position(enemy)
                table.insert(points, Vector3.new(enemyPoint.X, start.Y, enemyPoint.Z))
            end
        end
    end
    table.insert(points, start)
    local segments, routeLength = {}, 0
    for index = 1, #points - 1 do
        local length = (points[index + 1] - points[index]).Magnitude
        segments[index] = length
        routeLength += length
    end
    unit.ability = {started = MatchClock.now(), points = points, segments = segments,
        routeLength = routeLength, fistContacts = { {}, {} }, lastBodyPositions = {}}
    unit.model:SetAttribute("DrunkenFistActive", true)
    RockAnimationPlayer.playAbility(unit.model, unit.ability.started)
    session.abilityUsed[unitId] = true
    CombatSFX.release(emissionPoint(unit), "Rock")
    CombatVFX.muzzle(session.effects, bodyPoint(unit), nil, Color3.fromRGB(100, 240, 160), "Rock")
    return true
end

function CombatController.cancel(allowSoundsToFinish)
    if active then
        if active.connection then active.connection:Disconnect() end
        if active.renderConnection then active.renderConnection:Disconnect() end
        if active.poseConnection then active.poseConnection:Disconnect() end
        if active.contactConnection then active.contactConnection:Disconnect() end
        for _, unit in ipairs(active.units) do
            if alive(unit) then unit.model:PivotTo(unit.simPivot) end
            if unit.data.id == "RockLee" then
                unit.ability = nil
                if unit.model.Parent then unit.model:SetAttribute("DrunkenFistActive", false) end
            end
        end
        if active.effects then active.effects:Destroy() end
        active = nil
    end
    if not allowSoundsToFinish then CombatSFX.stopAll() end
    AttackAnimator.stopAll()
    RockAnimationPlayer.stopAll()
end

function CombatController.run(onEnd, options)
    CombatController.cancel()
    options = options or {}
    local arena = ArenaConfig.getArena()
    local folder = arena and arena:FindFirstChild("DeployedUnits")
    if not folder then task.defer(onEnd, nil) return end
    local session = {arena = arena, units = {}, shots = {}, elapsed = 0, accumulator = 0, attacks = 0, limit = options.timeLimit or 30,
        abilityUsed = {}, onOpponentDefeated = options.onOpponentDefeated}
    session.effects = Instance.new("Folder")
    session.effects.Name = "CombatEffects"
    session.effects.Parent = arena
    for _, model in ipairs(folder:GetChildren()) do
        local unit = makeUnit(model)
        if unit then table.insert(session.units, unit) end
    end
    table.sort(session.units, function(a, b) return a.model:GetAttribute("SpawnIndex") < b.model:GetAttribute("SpawnIndex") end)
    for _, unit in ipairs(session.units) do
        if unit.profile.kind == "Rock" then RockAnimationPlayer.prepare(unit.model) end
    end
    active = session
    session.renderConnection = RunService.RenderStepped:Connect(function() renderCombat(session) end)
    -- PreAnimation advances Rock's route before Animator poses the rig.
    session.poseConnection = RunService.PreAnimation:Connect(function() poseRockUnits(session) end)
    -- PreSimulation samples the resulting current-frame Motor6D.Transform.
    session.contactConnection = RunService.PreSimulation:Connect(function() sampleRockFistContacts(session) end)
    arena:SetAttribute("CombatAttacks", 0)
    session.connection = RunService.Heartbeat:Connect(function(dt)
        if active ~= session then return end
        if not folder.Parent or (options.isCurrent and not options.isCurrent()) then CombatController.cancel(); return end
        if MatchClock.isPaused() then return end
        local now = MatchClock.now()
        if session.finishAt then
            if now >= session.finishAt then
                local winner = session.winner
                CombatController.cancel(true)
                arena:SetAttribute("LastRoundWinner", winner or "draw")
                task.defer(onEnd, winner)
            end
            return
        end
        session.elapsed += dt
        session.accumulator += dt
        updateAttacks(session, now)
        local finished, winner = result(session)
        local abilityInProgress = false
        for _, unit in ipairs(session.units) do
            if unit.ability then abilityInProgress = true; break end
        end
        if finished and not abilityInProgress then
            session.finishAt, session.winner = now + .4, winner
            for _, unit in ipairs(session.units) do
                if alive(unit) and unit.profile.kind ~= "Rock" then AttackAnimator.setWalking(unit.model, false) end
                if unit.attack then
                    clearCharge(unit.attack)
                    if alive(unit) and unit.attack.released then
                        session.finishAt = math.max(session.finishAt, unit.attack.started + unit.profile.duration)
                    elseif alive(unit) then
                        AttackAnimator.stop(unit.model)
                        if unit.profile.kind == "Rock" then RockAnimationPlayer.stop(unit.model) end
                    end
                end
            end
            return
        end
        if session.accumulator >= .1 then
            local step = math.min(session.accumulator, .2)
            session.accumulator = 0
            stepCombat(session, step, now)
        end
    end)
end

return CombatController
