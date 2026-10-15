local function signal()
    local entries = {}
    local api = {}
    function api:Connect(callback)
        local connection = {Connected = true}
        function connection:Disconnect() self.Connected = false end
        table.insert(entries, {callback = callback, connection = connection})
        return connection
    end
    function api:Fire(dt)
        for _, entry in ipairs(entries) do
            if entry.connection.Connected then entry.callback(dt) end
        end
    end
    function api:Count()
        local count = 0
        for _, entry in ipairs(entries) do if entry.connection.Connected then count += 1 end end
        return count
    end
    return api
end

local function compile(source, name, environment)
    local chunk, message = loadstring(assert(source, "Missing source: " .. name), "Regression_" .. name)
    assert(chunk, message)
    if environment then setfenv(chunk, environment) end
    return chunk()
end

local function near(a, b, message, tolerance)
    assert(math.abs(a - b) <= (tolerance or 1e-5), message .. ": " .. tostring(a) .. " versus " .. tostring(b))
end

local function sameFrame(a, b, message)
    assert((a.Position - b.Position).Magnitude < 1e-5, message .. " position")
    assert(a.LookVector:Dot(b.LookVector) > .99999, message .. " look")
    assert(a.UpVector:Dot(b.UpVector) > .99999, message .. " up")
end

local function unit(id, side, name, kind, hit, damage, health, x, z)
    return {id = id, side = side, name = name, type = kind, hitSpeed = hit,
        damage = damage or 13, health = health or 100000, range = {value = 5}, mobile = false,
        point = Vector3.new(x or 0, 3, z or 0)}
end

local function fixture(controllerSource, timeline, definitions, enabled)
    local arena = Instance.new("Model")
    arena.Name = "UnparentedAttackTimingRegression"
    local folder = Instance.new("Folder")
    folder.Name, folder.Parent = "DeployedUnits", arena
    local models, data = {}, {}
    for index, definition in ipairs(definitions) do
        local model = Instance.new("Model")
        model.Name = definition.id
        model:SetAttribute("UnitId", definition.id)
        model:SetAttribute("Side", definition.side)
        model:SetAttribute("SpawnIndex", index)
        local root = Instance.new("Part")
        root.Name, root.Anchored, root.CanCollide = "HumanoidRootPart", true, false
        root.CFrame, root.Parent = CFrame.new(definition.point), model
        model.PrimaryPart, model.Parent = root, folder
        models[definition.id], data[definition.id] = model, definition
    end
    local heart, render = signal(), signal()
    local now, wall, paused, effects = 0, 0, false, enabled ~= false
    local starts, releases, last, debris, delayed = {}, {}, {}, {}, {}
    local finishCount, winner, controller = 0, nil, nil
    local modules = {
        AttackTimeline = timeline,
        MatchClock = {now = function() return now end, isPaused = function() return paused end},
        MatchSettings = {effectsEnabled = function() return effects end},
        UnitData = {get = function(id) return data[id] end},
        PlayerData = {unitStats = function(_, health, damage) return health, damage end},
        ArenaConfig = {getArena = function() return arena end, clampPosition = function(point) return point end},
        AttackAnimator = {
            setWalking = function() end,
            play = function(model, name, profile, started)
                local previous = last[model]
                if previous then
                    assert(now - previous.started + 1e-7 >= previous.profile.cooldown, "Attack cooldown violated: " .. model.Name)
                    assert(now - previous.started + 1e-7 >= previous.profile.duration, "Overlapping attack animation: " .. model.Name)
                end
                local event = {id = model.Name, started = started or now, profile = profile, releases = 0}
                table.insert(starts, event)
                last[model] = event
                return true
            end,
            poseNow = function(model, age)
                local event = assert(last[model], "Release without an attack")
                assert(age + 1e-7 >= event.profile.releaseAt, "Release pose requested before windup completes")
                event.releases += 1
                assert(event.releases == 1, "Attack released twice")
                table.insert(releases, {id = model.Name, at = now, age = age, event = event})
                return true
            end,
            stop = function() end, stopAll = function() end,
        },
    }
    local storage = {}
    for name in pairs(modules) do storage[name] = name end
    function storage:WaitForChild(name) return assert(self[name], "Unexpected module: " .. name) end
    local services = {
        ReplicatedStorage = storage, RunService = {Heartbeat = heart, RenderStepped = render},
        TweenService = {Create = function(_, object, _, properties)
            return {Play = function() for key, value in pairs(properties) do object[key] = value end end}
        end},
        Debris = {AddItem = function(_, object, delay) table.insert(debris, {object = object, at = wall + delay}) end},
    }
    local environment = setmetatable({
        game = {GetService = function(_, name) return assert(services[name], "Unexpected service: " .. name) end},
        require = function(name) return assert(modules[name], "Unexpected require: " .. tostring(name)) end,
        task = {defer = function(callback, ...) callback(...) end,
            delay = function(delay, callback, ...) table.insert(delayed, {at = wall + delay, callback = callback, args = {...}}) end},
    }, {__index = getfenv()})
    local api = {arena = arena, models = models, starts = starts, releases = releases}
    function api:time() return now end
    function api:health(id) return models[id]:GetAttribute("Health") end
    function api:pause(value) paused = value end
    function api:effects(value) effects = value end
    function api:connections() return heart:Count() + render:Count() end
    function api:callbacks() return finishCount, winner end
    function api:effectCount()
        local effectsFolder = arena:FindFirstChild("CombatEffects")
        return effectsFolder and #effectsFolder:GetChildren() or 0
    end
    function api:tick(dt)
        wall += dt
        if not paused then now += dt end
        heart:Fire(dt)
        render:Fire(dt)
        for index = #delayed, 1, -1 do
            local job = delayed[index]
            if wall >= job.at then table.remove(delayed, index); job.callback(table.unpack(job.args)) end
        end
        for index = #debris, 1, -1 do
            if wall >= debris[index].at then debris[index].object:Destroy(); table.remove(debris, index) end
        end
    end
    function api:advance(seconds, trace)
        local target, step = now + seconds, 0
        while now + 1e-8 < target do
            step += 1
            local dt = trace and trace[(step - 1) % #trace + 1] or 1 / 60
            self:tick(math.min(dt, target - now))
        end
    end
    function api:cancel() controller.cancel() end
    function api:destroy()
        if controller then controller.cancel() end
        arena:Destroy()
    end
    local ok, err = xpcall(function()
        controller = compile(controllerSource, "CombatController", environment)
        controller.run(function(value) finishCount += 1; winner = value or "draw" end, {timeLimit = 60})
    end, debug.traceback)
    if not ok then api:destroy(); error(err) end
    return api
end

local function using(source, timeline, definitions, enabled, callback)
    local state = fixture(source, timeline, definitions, enabled)
    local ok, result = xpcall(function() return callback(state) end, debug.traceback)
    state:destroy()
    if not ok then error(result) end
    return result
end

local function countFor(events, id)
    local count = 0
    for _, event in ipairs(events) do if event.id == id then count += 1 end end
    return count
end

local function ordinaryPair(name, kind, hit)
    return {unit("Attacker", "player", name, kind, hit, 13, 100000, 0),
        unit("Target", "opponent", "Target", "Ranged", 1000, 0, 100000, 4)}
end

local function assertCanceled(state)
    local before = {}
    for id in pairs(state.models) do before[id] = state:health(id) end
    local attacks, releases = #state.starts, #state.releases
    local callbacks = state:callbacks()
    state:cancel()
    assert(state:connections() == 0, "Canceled combat kept a connection")
    assert(state:effectCount() == 0, "Canceled combat kept charge/shot effects")
    state:advance(4)
    assert(#state.starts == attacks and #state.releases == releases, "Canceled attack fired later")
    assert(state:callbacks() == callbacks, "Canceled combat called completion again")
    assert(state:connections() == 0 and state:effectCount() == 0, "Canceled combat recreated work")
    for id, health in pairs(before) do assert(state:health(id) == health, "Canceled combat applied delayed damage") end
end

local function releaseCase(source, timeline, definition, trace)
    return using(source, timeline, ordinaryPair(definition[1], definition[2], definition[3]), true, function(state)
        local profile = timeline.get(definition[1], definition[2], definition[3])
        local duration = profile.cooldown * 2 + profile.releaseAt + .6
        local elapsed, step, maximumDt = 0, 0, 0
        local lastHealth, damageEvents = 100000, 0
        while elapsed < duration do
            step += 1
            local dt = trace[(step - 1) % #trace + 1]
            maximumDt = math.max(maximumDt, dt)
            state:tick(dt)
            elapsed += dt
            local health = state:health("Target")
            local releaseCount = countFor(state.releases, "Attacker")
            near(100000 - health, releaseCount * 13, "Damage did not match release count")
            if health ~= lastHealth then
                near(lastHealth - health, 13, "A single shot hit more than once")
                damageEvents += 1
            end
            if countFor(state.starts, "Attacker") > 0 then
                local first
                for _, event in ipairs(state.starts) do if event.id == "Attacker" then first = event; break end end
                if state:time() < first.started + profile.releaseAt then
                    near(health, 100000, "Damage before windup/charge completed")
                end
            end
            lastHealth = health
        end
        assert(damageEvents >= 2, "Did not exercise successive shots")
        for _, release in ipairs(state.releases) do
            if release.id == "Attacker" then
                assert(release.age + 1e-7 >= profile.releaseAt, "Shot released early")
                assert(release.age <= profile.releaseAt + maximumDt + 1e-6, "Shot release skipped a frame")
            end
        end
        assert(state.models.Attacker:GetAttribute("AttackCooldown") == profile.cooldown, "Displayed cooldown differs from actual cooldown")
        assertCanceled(state)
        return {name = definition[1], shots = damageEvents, releaseAt = profile.releaseAt,
            animationDuration = profile.duration, cooldown = profile.cooldown, noOverlap = true, exactlyOneHitPerShot = true}
    end)
end

local function effectSnapshot(state)
    local snapshot = {}
    local folder = state.arena:FindFirstChild("CombatEffects")
    if folder then
        for _, part in ipairs(folder:GetChildren()) do
            snapshot[part] = {frame = part.CFrame, size = part.Size, transparency = part.Transparency}
        end
    end
    return snapshot
end

local function frozenEffects(state, snapshot)
    assert(state:effectCount() == (function() local n = 0; for _ in pairs(snapshot) do n += 1 end; return n end)(), "Paused effect count changed")
    for part, before in pairs(snapshot) do
        assert(part.Parent, "Paused effect was removed")
        sameFrame(part.CFrame, before.frame, "Paused effect moved")
        assert((part.Size - before.size).Magnitude < 1e-5, "Paused effect grew")
        near(part.Transparency, before.transparency, "Paused effect faded")
    end
end

local function lifecycleCases(source, timeline)
    local results = {}
    table.insert(results, using(source, timeline, ordinaryPair("Master Roshu", "Tank", 5.3), true, function(state)
        state:advance(.9)
        assert(countFor(state.starts, "Attacker") == 1, "Roshi never began charge")
        assert(countFor(state.releases, "Attacker") == 0, "Roshi charge was too short")
        local health, time, starts, releases = state:health("Target"), state:time(), #state.starts, #state.releases
        local snapshot = effectSnapshot(state)
        assert(state:effectCount() > 0, "Charge pause did not exercise visible effects")
        state:pause(true)
        for _ = 1, 120 do state:tick(1 / 60) end
        near(state:time(), time, "Paused clock advanced")
        near(state:health("Target"), health, "Damage continued during charge pause")
        assert(#state.starts == starts and #state.releases == releases, "Attack phase advanced during pause")
        frozenEffects(state, snapshot)
        state:pause(false)
        state:advance(.8)
        assert(countFor(state.releases, "Attacker") == 1, "Paused charge did not resume exactly once")
        near(state:health("Target"), health - 13, "Resumed charge damage wrong")
        local firing = effectSnapshot(state)
        assert(state:effectCount() > 0, "Beam pause did not exercise effects")
        state:pause(true)
        for _ = 1, 45 do state:tick(1 / 60) end
        frozenEffects(state, firing)
        state:pause(false)
        assertCanceled(state)
        return {name = "pause_charge_and_beam", pausedFrames = 165, passed = true}
    end))
    table.insert(results, using(source, timeline, ordinaryPair("Master Roshu", "Tank", 5.3), true, function(state)
        state:advance(.8)
        assert(countFor(state.releases, "Attacker") == 0, "Cancel did not occur during windup")
        assertCanceled(state)
        near(state:health("Target"), 100000, "Windup cancel applied damage")
        assert(state:callbacks() == 0, "Cancel incorrectly completed a match")
        return {name = "cancel_during_windup", delayedHits = 0, remainingConnections = 0, passed = true}
    end))
    local deadAttacker = {
        unit("Roshi", "player", "Master Roshu", "Tank", 5.3, 13, 1, 0),
        unit("Survivor", "player", "Survivor", "Ranged", 1000, 0, 100000, -5),
        unit("Enemy", "opponent", "Enemy", "Melee", 1000, 1, 100000, 4),
    }
    table.insert(results, using(source, timeline, deadAttacker, true, function(state)
        state:advance(2.4)
        near(state:health("Roshi"), 0, "Fixture did not defeat charging attacker")
        assert(countFor(state.starts, "Roshi") == 1, "Defeated attacker restarted")
        assert(countFor(state.releases, "Roshi") == 0, "Dead attacker released queued shot")
        near(state:health("Enemy"), 100000, "Dead attacker applied delayed damage")
        assert(state:callbacks() == 0, "Surviving team should keep match active")
        assertCanceled(state)
        return {name = "dead_attacker_cancels_queued_shot", passed = true}
    end))
    local deadTarget = {
        unit("Roshi", "player", "Master Roshu", "Tank", 5.3, 13, 100000, 0),
        unit("Ally", "player", "Ally", "Melee", 1000, 1, 100000, 0, 1),
        unit("FirstTarget", "opponent", "FirstTarget", "Ranged", 1000, 0, 1, 4),
        unit("SecondTarget", "opponent", "SecondTarget", "Ranged", 1000, 0, 100000, 6),
    }
    table.insert(results, using(source, timeline, deadTarget, true, function(state)
        state:advance(2.4)
        near(state:health("FirstTarget"), 0, "Fixture did not defeat original target")
        assert(countFor(state.starts, "Roshi") == 1, "Target loss restarted attack")
        near(state:health("SecondTarget"), 100000, "Queued shot hit or retargeted after target died")
        assertCanceled(state)
        return {name = "dead_target_does_not_receive_or_redirect_queued_hit", passed = true}
    end))
    table.insert(results, using(source, timeline, deadTarget, true, function(state)
        state:advance(.3)
        state.models.FirstTarget.Parent = nil
        state:advance(2)
        near(state:health("SecondTarget"), 100000, "Removed target redirected queued shot")
        state.models.FirstTarget:Destroy()
        assertCanceled(state)
        return {name = "removed_target_does_not_redirect_queued_hit", passed = true}
    end))
    local traces = {}
    for _, mode in ipairs({"on", "off", "toggle"}) do
        traces[mode] = using(source, timeline, ordinaryPair("Goku", "Ranged", 1.05), mode ~= "off", function(state)
            local samples = {}
            for frame = 1, 300 do
                if mode == "toggle" then state:effects(frame % 47 > 17) end
                state:tick(1 / 60)
                samples[frame] = state:health("Target")
            end
            assertCanceled(state)
            return samples
        end)
    end
    for index, health in ipairs(traces.on) do
        near(traces.off[index], health, "Disabled effects altered damage")
        near(traces.toggle[index], health, "Toggling effects altered damage")
    end
    table.insert(results, {name = "effects_preference_has_no_damage_effect", matchedFrames = 300, passed = true})
    local lethal = {unit("Left", "player", "Goku", "Ranged", 1.05, 20, 10, 0),
        unit("Right", "opponent", "Goku", "Ranged", 1.05, 20, 10, 4)}
    table.insert(results, using(source, timeline, lethal, true, function(state)
        state:advance(3)
        near(state:health("Left"), 0, "Simultaneous lethal shot was lost")
        near(state:health("Right"), 0, "Simultaneous lethal shot was lost")
        local callbacks, winner = state:callbacks()
        assert(callbacks == 1 and winner == "draw", "Simultaneous lethal shots must draw once")
        assert(countFor(state.starts, "Left") == 1 and countFor(state.starts, "Right") == 1, "Attack began after outcome")
        assert(countFor(state.releases, "Left") == 1 and countFor(state.releases, "Right") == 1, "Repeated damage after outcome")
        assert(state:connections() == 0, "Finished match leaked connections")
        assertCanceled(state)
        return {name = "simultaneous_lethal_draw", callbacks = callbacks, winner = winner, passed = true}
    end))
    local lastEnemy = {
        unit("Roshi", "player", "Master Roshu", "Tank", 5.3, 13, 100000, 0),
        unit("Ally", "player", "Ally", "Melee", 1000, 1, 100000, 0, 1),
        unit("Enemy", "opponent", "Enemy", "Ranged", 1000, 0, 1, 4),
    }
    table.insert(results, using(source, timeline, lastEnemy, true, function(state)
        state:advance(3)
        assert(countFor(state.releases, "Roshi") == 0, "Windup fired after outcome was decided")
        local callbacks, winner = state:callbacks()
        assert(callbacks == 1 and winner == "player", "Settled outcome did not complete once")
        assert(countFor(state.starts, "Ally") == 1 and countFor(state.starts, "Roshi") == 1, "Outcome settling began new attacks")
        assertCanceled(state)
        return {name = "settling_cancels_unreleased_attacks", passed = true, callbacks = callbacks}
    end))
    local roshiLethal = ordinaryPair("Master Roshu", "Tank", 5.3)
    roshiLethal[2].health = 1
    table.insert(results, using(source, timeline, roshiLethal, true, function(state)
        state:advance(1.8)
        near(state:health("Target"), 0, "Roshi lethal shot did not release")
        assert(state:callbacks() == 0, "Result cut off Roshi's landing")
        local start
        for _, event in ipairs(state.starts) do if event.id == "Attacker" then start = event; break end end
        local landingAt = assert(start).started + start.profile.duration
        state:advance(landingAt - state:time() - .02)
        assert(state:callbacks() == 0, "Result occurred before attack recovery finished")
        state:advance(.1)
        local callbacks, winner = state:callbacks()
        assert(callbacks == 1 and winner == "player", "Landed result did not complete")
        assert(countFor(state.releases, "Attacker") == 1, "Settling repeated the final shot")
        assertCanceled(state)
        return {name = "roshi_finishes_landing_before_result", passed = true, callbacks = callbacks}
    end))
    return results
end

local function makeRig(r15, parent)
    local model = Instance.new("Model")
    model.Name, model.Parent = r15 and "R15Fixture" or "R6Fixture", parent
    local parts, joints, originals, transforms, c1s = {}, {}, {}, {}, {}
    local function part(name)
        local value = Instance.new("Part")
        value.Name, value.Anchored, value.CanCollide = name, true, false
        value.CFrame = CFrame.new(31, 7, -22) * CFrame.Angles(0, .37, 0)
        value.Parent = model
        parts[name] = value
        return value
    end
    local root = part("HumanoidRootPart")
    model.PrimaryPart = root
    local function joint(name, from, to, index)
        local motor = Instance.new("Motor6D")
        motor.Name, motor.Part0, motor.Part1 = name, parts[from], parts[to]
        motor.C0 = CFrame.new(.01 * index, .13 * index, -.02 * index)
            * (r15 and CFrame.Angles(.03 * index, .02, -.01) or CFrame.Angles(-math.pi / 2, .03 * index, math.pi))
        motor.C1 = CFrame.new(.02, -.11, .03) * CFrame.Angles(.01, .02, .03)
        motor.Transform = CFrame.new(.001, .002, .003) * CFrame.Angles(.001, .002, .003)
        motor.Parent = parts[from]
        joints[name], originals[name], transforms[name], c1s[name] = motor, motor.C0, motor.Transform, motor.C1
    end
    if r15 then
        for _, name in ipairs({"LowerTorso", "UpperTorso", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot"}) do part(name) end
        joint("Root", "HumanoidRootPart", "LowerTorso", 1)
        joint("Waist", "LowerTorso", "UpperTorso", 2)
        joint("Neck", "UpperTorso", "Head", 3)
        local index = 3
        for _, side in ipairs({"Left", "Right"}) do
            for _, spec in ipairs({{"Shoulder", "UpperTorso", side .. "UpperArm"}, {"Elbow", side .. "UpperArm", side .. "LowerArm"}, {"Wrist", side .. "LowerArm", side .. "Hand"}, {"Hip", "LowerTorso", side .. "UpperLeg"}, {"Knee", side .. "UpperLeg", side .. "LowerLeg"}, {"Ankle", side .. "LowerLeg", side .. "Foot"}}) do
                index += 1
                joint(side .. spec[1], spec[2], spec[3], index)
            end
        end
    else
        for _, name in ipairs({"Torso", "Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}) do part(name) end
        joint("RootJoint", "HumanoidRootPart", "Torso", 1)
        joint("Neck", "Torso", "Head", 2)
        joint("Left Shoulder", "Torso", "Left Arm", 3)
        joint("Right Shoulder", "Torso", "Right Arm", 4)
        joint("Left Hip", "Torso", "Left Leg", 5)
        joint("Right Hip", "Torso", "Right Leg", 6)
    end
    return {model = model, root = root, joints = joints, originals = originals, transforms = transforms, c1s = c1s}
end

local function animatorCases(source, timeline)
    local clock, paused = 0, false
    local preSimulation = signal()
    local storage = {MatchClock = "MatchClock", AttackTimeline = "AttackTimeline"}
    function storage:WaitForChild(name) return self[name] end
    local modules = {MatchClock = {now = function() return clock end, isPaused = function() return paused end}, AttackTimeline = timeline}
    local services = {ReplicatedStorage = storage, RunService = {PreSimulation = preSimulation}}
    local environment = setmetatable({
        game = {GetService = function(_, name) return assert(services[name], "Unexpected animator service: " .. name) end},
        require = function(name) return assert(modules[name], "Unexpected animator require: " .. tostring(name)) end,
    }, {__index = getfenv()})
    local animator = compile(source, "AttackAnimator", environment)
    local parent = Instance.new("Folder")
    parent.Name = "UnparentedAttackAnimatorRegression"
    local profile = timeline.get("Master Roshu", "Tank", 5.3)
    local results = {}
    local function checkIntegrity(rig, rootFrame, rest, stopped)
        sameFrame(rig.root.CFrame, rootFrame, "Animator moved logical root")
        for name, joint in pairs(rig.joints) do
            sameFrame(joint.C1, rig.c1s[name], "Animator altered C1: " .. name)
            sameFrame(joint.Transform, stopped and rig.transforms[name] or CFrame.identity, "Animator track mask/restoration incorrect: " .. name)
            if rest then sameFrame(joint.C0, rig.originals[name], "Animator failed to restore C0: " .. name) end
        end
    end
    local function advanceTo(target, fps)
        while clock + 1e-8 < target do
            local dt = math.min(1 / fps, target - clock)
            clock += dt
            preSimulation:Fire(dt)
        end
    end
    local ok, err = xpcall(function()
        for _, r15 in ipairs({false, true}) do
            local rootName = r15 and "Root" or "RootJoint"
            local sampleAt = function(time) return (animator.sample(profile, time, r15))[rootName] or CFrame.identity end
            near(sampleAt(.16).Position.Y, -.32, "Roshi must crouch before takeoff")
            assert(sampleAt(.42).Position.Y > 1.8, "Roshi did not rise into jump")
            near(sampleAt(.68).Position.Y, 2.8, "Roshi jump peak")
            near(sampleAt(1.05).Position.Y, 2.8, "Roshi did not hang during charge")
            assert(math.abs(sampleAt(1.25).Position.Y - sampleAt(.68).Position.Y) < .05, "Roshi air charge lacks a sustained hang")
            assert(sampleAt(profile.releaseAt).Position.Y > 2.6, "Roshi fired after dropping from jump")
            assert(sampleAt(1.96).Position.Y > .9 and sampleAt(1.96).Position.Y < 1.2, "Roshi lacks visible descent")
            assert(sampleAt(2.09).Position.Y < 0, "Roshi landing did not absorb impact")
            sameFrame(sampleAt(profile.duration), CFrame.identity, "Roshi did not finish at rest")
            local baseline
            for _, fps in ipairs({30, 60, 120}) do
                clock, paused = 0, false
                local rig = makeRig(r15, parent)
                local rootFrame = rig.root.CFrame
                assert(animator.play(rig.model, "Master Roshu", profile, clock), "Animator rejected first attack")
                advanceTo(.10, fps)
                assert(animator.play(rig.model, "Master Roshu", profile, clock) == false, "Animator allowed overlapping attack")
                advanceTo(1.05, fps)
                local capture = {}
                for name, joint in pairs(rig.joints) do capture[name] = joint.C0 end
                local rootOffset = rig.joints[rootName].C0.Position - rig.originals[rootName].Position
                near(rootOffset.Y, 2.8, "Actual Motor6D jump offset uses wrong axes")
                if baseline then
                    for name, frame in pairs(capture) do sameFrame(frame, baseline[name], "Attack pose changed with frame rate") end
                else
                    baseline = capture
                end
                checkIntegrity(rig, rootFrame, false)
                paused = true
                for _ = 1, 45 do
                    for _, joint in pairs(rig.joints) do joint.Transform = CFrame.Angles(.2, .3, .4) end
                    preSimulation:Fire(1 / fps)
                    for _, joint in pairs(rig.joints) do sameFrame(joint.Transform, CFrame.identity, "Paused track overwrote combat pose") end
                end
                assert(animator.poseNow(rig.model, 1.8) == false, "poseNow ignored paused clock")
                for name, joint in pairs(rig.joints) do sameFrame(joint.C0, capture[name], "Paused animator advanced") end
                paused = false
                advanceTo(profile.releaseAt, fps)
                local posed, phase = animator.poseNow(rig.model, profile.releaseAt)
                assert(posed and phase == "Release", "Release pose was not sampled on release frame")
                checkIntegrity(rig, rootFrame, false)
                advanceTo(profile.duration + .1, fps)
                checkIntegrity(rig, rootFrame, true)
                assert(animator.play(rig.model, "Master Roshu", profile, clock), "Recovered animator cannot attack again")
                advanceTo(clock + .8, fps)
                animator.stop(rig.model)
                checkIntegrity(rig, rootFrame, true, true)
                assert(preSimulation:Count() == 0, "Stopped animator kept frame connection")
                rig.model:Destroy()
            end
            table.insert(results, {rig = r15 and "R15" or "R6", passed = true, comparedFps = {30, 60, 120},
                airChargeSeconds = .57, peakOffset = 2.8, releaseHeight = 2.72, logicalRootUnchanged = true,
                restC0Restored = true, c1PreservedAndTransformRestored = true, pausedTrackInjectionSuppressed = true, remainingConnections = 0})
        end
        for _, definition in ipairs({{"Goku", "Ranged", 1.05}, {"Yumcha", "Melee", .6}, {"Pikkolo", "Energy", .82}, {"Tein", "Energy", 1.05}, {"Bluma", "Artillery", .72}}) do
            local current = timeline.get(definition[1], definition[2], definition[3])
            for _, r15 in ipairs({false, true}) do
                local pose, phase = animator.sample(current, current.releaseAt, r15)
                assert(phase == "Release", "Wrong release phase: " .. definition[1])
                assert(pose.RightShoulder, "Release pose missing firing/striking arm: " .. definition[1])
                local rest, restingPhase = animator.sample(current, current.duration, r15)
                assert(next(rest) == nil and restingPhase == "Idle", "Attack does not end at idle: " .. definition[1])
            end
        end
        local a, b = makeRig(false, parent), makeRig(true, parent)
        animator.setWalking(a.model, true)
        animator.setWalking(b.model, true)
        advanceTo(clock + .3, 60)
        assert(preSimulation:Count() == 1, "Animator created duplicate frame loops")
        animator.stopAll()
        assert(preSimulation:Count() == 0, "stopAll leaked frame connection")
        for _, rig in ipairs({a, b}) do
            for name, joint in pairs(rig.joints) do sameFrame(joint.C0, rig.originals[name], "stopAll failed to restore rig"); sameFrame(joint.Transform, rig.transforms[name], "stopAll failed to restore Transform") end
        end
    end, debug.traceback)
    animator.stopAll()
    parent:Destroy()
    if not ok then error(err) end
    return results
end

return function(sources)
    assert(type(sources) == "table", "Supply source strings keyed by module name")
    local timeline = compile(sources.AttackTimeline, "AttackTimeline")
    local roshi = timeline.get("Master Roshu", "Tank", 5.3)
    assert(roshi.releaseAt >= 1.35 and roshi.duration >= 2.25, "Roshi choreography was shortened")
    near(roshi.cooldown, 5.3, "Roshi existing cooldown must stay 5.3 seconds")
    if sources.UnitData then
        local data = compile(sources.UnitData, "UnitData")
        near(data.get("MasterRoshu").hitSpeed, 5.3, "Actual Roshi UnitData cooldown changed")
        for _, definition in pairs(data.all()) do
            local profile = timeline.get(definition.name, definition.type, definition.hitSpeed)
            near(definition.hitSpeed, profile.cooldown, "UnitData UI cooldown and combat cooldown differ: " .. definition.name)
        end
    end
    local definitions = {
        {"Yumcha", "Melee", .6}, {"Krillen", "Melee", .6}, {"Goku", "Ranged", 1.05},
        {"Pikkolo", "Energy", .82}, {"Tein", "Energy", 1.05}, {"Bluma", "Artillery", .72},
        {"Master Roshu", "Tank", 5.3},
    }
    local traces = {
        {name = "30fps", values = {1 / 30}}, {name = "60fps", values = {1 / 60}},
        {name = "120fps", values = {1 / 120}},
        {name = "jitter_and_hitch", values = {1 / 120, .03, .016, .07, .018, .18, .021, .38}},
    }
    local releases = {}
    for _, trace in ipairs(traces) do
        for _, definition in ipairs(definitions) do
            local result = releaseCase(sources.CombatController, timeline, definition, trace.values)
            result.trace, result.passed = trace.name, true
            table.insert(releases, result)
        end
    end
    return {passed = true, controller = releases, lifecycle = lifecycleCases(sources.CombatController, timeline),
        animator = animatorCases(sources.AttackAnimator, timeline),
        note = "Isolated, unparented native Instances; mocked frame signals, clock, damage data and effects preferences. No live game state, rewards, assets or progression modified."}
end
