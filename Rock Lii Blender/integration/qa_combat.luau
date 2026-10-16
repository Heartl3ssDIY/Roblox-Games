-- Client Play, idle lobby only. Runs the exact installed CombatController on
-- temporary clones. It restores the previous DeployedUnits folder and arena
-- attributes. No persistence/remotes/reward callbacks are invoked.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
assert(RunService:IsRunning() and RunService:IsClient(), "Client Play required")
assert(not workspace:FindFirstChild("RockLiiCombatQA"), "Read/remove previous combat QA report first")
local output = Instance.new("Folder")
output.Name = "RockLiiCombatQA"
output:SetAttribute("QAOwner", "RockLiiReviewed20260929")
output:SetAttribute("Status", "Running")
output.Parent = workspace
local report = {checks = {}, healthEvents = {}, startedAt = os.time()}
local function check(name, passed, detail)
    table.insert(report.checks, {name = name, passed = not not passed, detail = detail})
end

task.spawn(function()
    local Controller, Clock, Settings, arena, originalFolder, testFolder, testOrigin
    local connections = {}
    local oldAttributes, oldSounds, oldEffects, oldPaused, oldPausedAttribute
    local function waitSeconds(seconds)
        local untilTime = os.clock() + seconds
        repeat RunService.Heartbeat:Wait() until os.clock() >= untilTime
    end
    local function disconnectAll()
        for _, connection in ipairs(connections) do connection:Disconnect() end
        table.clear(connections)
    end
    local function clearTest()
        if Controller then Controller.cancel() end
        disconnectAll()
        if testFolder then testFolder:ClearAllChildren() end
    end
    local ok, problem = xpcall(function()
        Clock = require(ReplicatedStorage.MatchClock)
        Settings = require(ReplicatedStorage.MatchSettings)
        local Config = require(ReplicatedStorage.ArenaConfig)
        Controller = require(ReplicatedStorage.CombatController)
        oldPaused = Clock.isPaused()
        oldPausedAttribute = Players.LocalPlayer:GetAttribute("MatchPaused")
        assert(not oldPaused, "Idle, unpaused lobby required")
        arena = assert(Config.getArena(), "Arena missing")
        assert(not arena:FindFirstChild("CombatEffects"), "An existing combat session may be active")
        local origin = Config.getOrigin()
        if not origin then
            testOrigin = Instance.new("Part")
            testOrigin.Name = "BattleOrigin"
            testOrigin.Anchored = true
            testOrigin.CanCollide = false
            testOrigin.Transparency = 1
            testOrigin.CFrame = CFrame.new(0, 1000, 0)
            testOrigin:SetAttribute("HalfDepth", 43.5)
            testOrigin:SetAttribute("HalfWidth", 29)
            testOrigin.Parent = arena
            origin = testOrigin
        end
        originalFolder = arena:FindFirstChild("DeployedUnits")
        oldAttributes = {CombatAttacks = arena:GetAttribute("CombatAttacks"), LastRoundWinner = arena:GetAttribute("LastRoundWinner")}
        oldSounds, oldEffects = Settings.soundsEnabled(), Settings.effectsEnabled()
        Settings.setSounds(false)
        Settings.setEffects(false)
        if originalFolder then originalFolder.Parent = output end
        testFolder = Instance.new("Folder")
        testFolder.Name = "DeployedUnits"
        testFolder.Parent = arena

        local function rig(id, side, index, x, z)
            local model = ReplicatedStorage.UnitModels.Rare["ROCK LEE"]["Rock Lee"]:Clone()
            model.Name = "QA_" .. id .. "_" .. side
            for _, object in ipairs(model:GetDescendants()) do
                if object:IsA("BaseScript") then object:Destroy()
                elseif object:IsA("BasePart") then
                    object.Anchored = false
                    object.Massless = true
                    object.CanCollide = false
                    object.CanTouch = false
                    object.CanQuery = false
                end
            end
            model.PrimaryPart = model.HumanoidRootPart
            model.PrimaryPart.Anchored = true
            local humanoid = model:FindFirstChildOfClass("Humanoid")
            humanoid.AutoRotate = false
            humanoid.RequiresNeck = false
            humanoid.BreakJointsOnDeath = false
            humanoid.EvaluateStateMachine = false
            if not humanoid:FindFirstChildOfClass("Animator") then Instance.new("Animator", humanoid) end
            model:SetAttribute("UnitId", id)
            model:SetAttribute("Side", side)
            model:SetAttribute("SpawnIndex", index)
            model:SetAttribute("MasteryForm", false)
            model:SetAttribute("Defeated", nil)
            model.Parent = testFolder
            local point = origin.CFrame:PointToWorldSpace(Vector3.new(x, 3, z))
            model:PivotTo(CFrame.lookAt(point, point + Config.facing(side)))
            return model
        end
        local function recordHealth(model, list)
            local previous = model:GetAttribute("Health")
            table.insert(connections, model:GetAttributeChangedSignal("Health"):Connect(function()
                local value = model:GetAttribute("Health")
                if previous and value and value < previous then
                    table.insert(list, {time = Clock.now(), before = previous, after = value, damage = previous - value})
                end
                previous = value
            end))
        end
        local ended = {}
        local function onEnd(winner) table.insert(ended, winner or "draw") end

        output:SetAttribute("Stage", "Triple damage")
        -- Opponent Rock uses the unmodified base damage20. The player-side
        -- Beeras dummy has at least258 HP and cannot be killed by three20 hits.
        local rock = rig("RockLee", "opponent", 1, 0, 0)
        local target = rig("Beeras", "player", 2, 0, -2.7)
        Controller.run(onEnd, {timeLimit = 30})
        local punchEvents = {}
        recordHealth(target, punchEvents)
        local timeout = os.clock() + 2.2
        repeat RunService.Heartbeat:Wait() until #punchEvents >= 3 or os.clock() >= timeout
        Controller.cancel()
        report.punches = punchEvents
        check("Normal attack deals three damage ticks", #punchEvents == 3, punchEvents)
        local total = 0
        for _, hit in ipairs(punchEvents) do total += hit.damage end
        check("Normal attack totals3x20 damage", total == 60, total)
        for index, hit in ipairs(punchEvents) do check("Punch " .. index .. " deals20", hit.damage == 20, hit.damage) end
        clearTest()

        output:SetAttribute("Stage", "Ability contacts and immunity")
        rock = rig("RockLee", "player", 1, 0, -12)
        target = rig("Beeras", "opponent", 2, 0, 20)
        local startPivot = rock:GetPivot()
        local started, abilityEvents, rockEvents = nil, {}, {}
        local initialHealth, endedAge, maxDistance = nil, nil, 0
        local windowBefore, windowAfter = {}, {}
        local previousWindow = "far"

        local function posedPart(model, part, seen)
            seen = seen or {}
            if seen[part] then return part.CFrame end
            seen[part] = true
            for _, joint in ipairs(model:GetDescendants()) do
                if joint:IsA("Motor6D") and joint.Part1 == part and joint.Part0 then
                    return posedPart(model, joint.Part0, seen) * joint.C0 * joint.Transform * joint.C1:Inverse()
                end
            end
            return part.CFrame
        end
        local function palm(right)
            local part = rock[right and "Right Arm" or "Left Arm"]
            return posedPart(rock, part):PointToWorldSpace(Vector3.new(0, -part.Size.Y * 0.4, -0.08))
        end
        -- Controlled contact fixture: move the dummy's rendered body alongside
        -- the right fist in two separated windows, then outside both fists.
        -- The real controller still owns Rock's route, animation and damage.
        -- Connect before run() so it is sampled by the controller's later
        -- PreSimulation listener after Animator has posed the arms.
        table.insert(connections, RunService.PreSimulation:Connect(function()
            if not started or not target.Parent or not rock.Parent then return end
            local age = Clock.now() - started
            local window = age >= 0.60 and age < 1.00 and "first"
                or age >= 1.45 and age < 1.85 and "second" or "far"
            if window ~= previousWindow then
                if previousWindow ~= "far" then windowAfter[previousWindow] = target:GetAttribute("Health") end
                if window ~= "far" then windowBefore[window] = target:GetAttribute("Health") end
                previousWindow = window
            end
            local right, left = palm(true), palm(false)
            local separation = right - left
            local away = separation.Magnitude > 0.001 and separation.Unit or Vector3.xAxis
            local desired = window == "far" and (rock.PrimaryPart.Position + Vector3.new(0, 100, 0))
                or (right + away * 0.8)
            local body = posedPart(target, target.Torso).Position
            target:PivotTo(target:GetPivot() + (desired - body))
        end))
        Controller.run(onEnd, {timeLimit = 30})
        initialHealth = rock:GetAttribute("Health")
        recordHealth(target, abilityEvents)
        recordHealth(rock, rockEvents)
        started = Clock.now()
        local accepted, reason = Controller.useAbility("RockLee")
        check("Drunken Fist starts", accepted, reason)
        assert(accepted, tostring(reason))
        local again, againReason = Controller.useAbility("RockLee")
        check("Ability cannot be reused in same round", not again and againReason == "Already used this round", againReason)
        local pausedOnce = false
        timeout = os.clock() + 10
        while rock.Parent and rock:GetAttribute("DrunkenFistActive") and os.clock() < timeout do
            RunService.Heartbeat:Wait()
            local age = Clock.now() - started
            maxDistance = math.max(maxDistance, (rock:GetPivot().Position - startPivot.Position).Magnitude)
            if not pausedOnce and age > 2.5 then
                pausedOnce = true
                Clock.setPaused(true)
                local atPause = rock:GetPivot()
                local timeAtPause = Clock.now()
                waitSeconds(0.35)
                check("Combat pause freezes ability route", (rock:GetPivot().Position - atPause.Position).Magnitude < 0.01,
                    (rock:GetPivot().Position - atPause.Position).Magnitude)
                check("Combat pause preserves ability clock", math.abs(Clock.now() - timeAtPause) < 0.001,
                    Clock.now() - timeAtPause)
                Clock.setPaused(false)
            end
        end
        endedAge = Clock.now() - started
        Controller.cancel() -- Aligns the visual model to its final authoritative pivot.
        report.ability = {events = abilityEvents, rockDamageEvents = rockEvents, duration = endedAge,
            initialHealth = initialHealth, finalHealth = rock:GetAttribute("Health"), maxRouteDistance = maxDistance,
            returnDistance = (rock:GetPivot().Position - startPivot.Position).Magnitude,
            firstContactDamage = windowBefore.first and windowAfter.first and windowBefore.first - windowAfter.first,
            secondContactDamage = windowBefore.second and windowAfter.second and windowBefore.second - windowAfter.second}
        check("Ability lasts seven match seconds", endedAge >= 7 and endedAge < 7.25, endedAge)
        check("Ability travels through arena", maxDistance > 20, maxDistance)
        check("Ability returns to its starting position", report.ability.returnDistance < 0.05, report.ability.returnDistance)
        check("Rock remains immune during ability", #rockEvents == 0 and rock:GetAttribute("Health") == initialHealth, rockEvents)
        check("First fist entry deals50 without contact spam", report.ability.firstContactDamage == 50, report.ability.firstContactDamage)
        check("Fist exit and reentry deals another50", report.ability.secondContactDamage == 50, report.ability.secondContactDamage)
        check("Cancel clears ability state", rock:GetAttribute("DrunkenFistActive") == false, rock:GetAttribute("DrunkenFistActive"))
        report.unexpectedRoundCallbacks = ended
        check("No round/reward callback fired", #ended == 0, ended)
    end, debug.traceback)

    clearTest()
    if testFolder then testFolder:Destroy() end
    if testOrigin then testOrigin:Destroy() end
    if originalFolder and arena then originalFolder.Parent = arena end
    if arena and oldAttributes then
        arena:SetAttribute("CombatAttacks", oldAttributes.CombatAttacks)
        arena:SetAttribute("LastRoundWinner", oldAttributes.LastRoundWinner)
    end
    if Clock and oldPaused ~= nil then
        Clock.setPaused(oldPaused)
        Players.LocalPlayer:SetAttribute("MatchPaused", oldPausedAttribute)
    end
    if Settings and oldSounds ~= nil then
        Settings.setSounds(oldSounds)
        Settings.setEffects(oldEffects)
    end
    if not ok then report.error = problem end
    report.passed = ok
    for _, item in ipairs(report.checks) do if not item.passed then report.passed = false end end
    report.finishedAt = os.time()
    output:SetAttribute("Report", HttpService:JSONEncode(report))
    output:SetAttribute("Status", report.passed and "Passed" or "Failed")
    print("Rock Lii production combat QA:", report.passed and "PASSED" or "FAILED")
end)
return "Started. Poll workspace.RockLiiCombatQA Status and Report."
