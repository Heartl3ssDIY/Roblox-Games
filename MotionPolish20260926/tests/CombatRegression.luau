local function signal()
    local handlers = {}
    local api = {}
    function api:Connect(callback)
        local connection = {Connected = true}
        function connection:Disconnect() self.Connected = false end
        table.insert(handlers, {callback = callback, connection = connection})
        return connection
    end
    function api:Fire(dt)
        for _, entry in ipairs(handlers) do
            if entry.connection.Connected then entry.callback(dt) end
        end
    end
    function api:Count()
        local count = 0
        for _, entry in ipairs(handlers) do if entry.connection.Connected then count += 1 end end
        return count
    end
    return api
end

local fixture = {
    {id = "P_Melee", side = "player", point = Vector3.new(-18, 3, -10), kind = "Melee", health = 150, damage = 18, range = 1, hit = .45, mobile = true},
    {id = "P_Ranged", side = "player", point = Vector3.new(-25, 3, 7), kind = "Ranged", health = 100, damage = 13, range = 3, hit = .65, mobile = true},
    {id = "P_Tank", side = "player", point = Vector3.new(-30, 3, 16), kind = "Tank", health = 230, damage = 9, range = 2, hit = 1.1, mobile = false},
    {id = "E_Melee", side = "opponent", point = Vector3.new(18, 3, -8), kind = "Melee", health = 160, damage = 16, range = 1, hit = .5, mobile = true},
    {id = "E_Ranged", side = "opponent", point = Vector3.new(25, 3, 10), kind = "Ranged", health = 110, damage = 12, range = 3, hit = .7, mobile = true},
    {id = "E_Tank", side = "opponent", point = Vector3.new(34, 3, -15), kind = "Tank", health = 210, damage = 11, range = 2, hit = 1, mobile = false},
}

local function simulate(source, spec)
    local arena = Instance.new("Model")
    arena.Name = "IsolatedCombatRegression"
    local folder = Instance.new("Folder")
    folder.Name = "DeployedUnits"
    folder.Parent = arena
    local models, unitData = {}, {}
    for index, definition in ipairs(fixture) do
        local model = Instance.new("Model")
        model.Name = definition.id
        model:SetAttribute("UnitId", definition.id)
        model:SetAttribute("Side", definition.side)
        model:SetAttribute("SpawnIndex", index)
        local root = Instance.new("Part")
        root.Name = "HumanoidRootPart"
        root.Anchored = true
        root.CanCollide = false
        root.CFrame = CFrame.new(definition.point)
        root.Parent = model
        model.PrimaryPart = root
        model.Parent = folder
        models[index] = model
        unitData[definition.id] = {
            name = definition.id, health = definition.health, damage = definition.damage,
            type = definition.kind, range = {value = definition.range}, hitSpeed = definition.hit, mobile = definition.mobile,
        }
    end

    local heartbeat, render = signal(), signal()
    local clock, wall, paused, frame = 0, 0, false, 0
    local clampLog, attackLog, pendingDebris, samples = {}, {}, {}, {}
    local finishCount, winner, done, stopAllCount = 0, nil, false, 0
    local renderMoves, renderSamples, pauseFrames, pauseChecks = 0, {}, 0, 0
    local modules = {}
    modules.MatchClock = {now = function() return clock end, isPaused = function() return paused end}
    modules.MatchSettings = {effectsEnabled = function() return true end}
    modules.UnitData = {get = function(id) return unitData[id] end}
    modules.PlayerData = {unitStats = function(_, health, damage) return health, damage end}
    modules.ArenaConfig = {
        getArena = function() return arena end,
        clampPosition = function(point)
            table.insert(clampLog, {frame = frame, point = point})
            return Vector3.new(math.clamp(point.X, -50, 50), point.Y, math.clamp(point.Z, -30, 30))
        end,
    }
    modules.AttackAnimator = {
        setWalking = function() end,
        play = function(model, unitName) table.insert(attackLog, {frame = frame, id = model.Name, name = unitName}) end,
        stop = function() end,
        stopAll = function() stopAllCount += 1 end,
    }
    local storage = {}
    for name in pairs(modules) do storage[name] = name end
    function storage:WaitForChild(name) return assert(self[name], "Unexpected module " .. name) end
    local services = {
        ReplicatedStorage = storage, RunService = {Heartbeat = heartbeat, RenderStepped = render},
        TweenService = {Create = function(_, object, _, properties)
            return {Play = function() for key, value in pairs(properties) do object[key] = value end end}
        end},
        Debris = {AddItem = function(_, object, delay) table.insert(pendingDebris, {object = object, at = wall + delay}) end},
    }
    local environment = setmetatable({
        game = {GetService = function(_, name) return assert(services[name], "Unexpected service " .. name) end},
        require = function(name) return assert(modules[name], "Unexpected require " .. tostring(name)) end,
        task = {defer = function(callback, ...) callback(...) end},
    }, {__index = getfenv()})
    local load, message = loadstring(source, "IsolatedCombatController")
    assert(load, message)
    setfenv(load, environment)
    local controller

    local function healthState()
        local health = {}
        for index, model in ipairs(models) do health[index] = model:GetAttribute("Health") end
        return health
    end

    local function positions()
        local pivots = {}
        for index, model in ipairs(models) do
            if model.Parent then pivots[index] = model:GetPivot() end
        end
        return pivots
    end

    local function compareFrozen(beforeHealth, beforePivots, beforeAttacks)
        local afterHealth = healthState()
        for index, health in ipairs(beforeHealth) do assert(afterHealth[index] == health, "Paused/canceled health changed") end
        for index, pivot in pairs(beforePivots) do
            if models[index].Parent then
                assert((models[index]:GetPivot().Position - pivot.Position).Magnitude < 1e-6, "Paused/canceled position moved")
            end
        end
        assert(arena:GetAttribute("CombatAttacks") == beforeAttacks, "Paused/canceled attack count changed")
    end

    local function tick(dt)
        wall += dt
        paused = spec.pause and wall >= .75 and wall < 1.35 or false
        if not paused then clock += dt end
        local beforeHealth, beforePivots, beforeAttacks
        if paused then
            pauseFrames += 1
            beforeHealth, beforePivots, beforeAttacks = healthState(), positions(), arena:GetAttribute("CombatAttacks")
        end
        heartbeat:Fire(dt)
        local renderBefore = positions()
        render:Fire(dt)
        for index, pivot in pairs(renderBefore) do
            if models[index].Parent then
                local moved = (models[index]:GetPivot().Position - pivot.Position).Magnitude
                if moved > 1e-5 then
                    renderMoves += 1
                    if #renderSamples < 8 then
                        table.insert(renderSamples, {frame = frame, clock = clock, unit = models[index].Name, distance = moved})
                    end
                end
            end
        end
        if paused then compareFrozen(beforeHealth, beforePivots, beforeAttacks); pauseChecks += 1 end
        for index = #pendingDebris, 1, -1 do
            local item = pendingDebris[index]
            if wall >= item.at then item.object:Destroy(); table.remove(pendingDebris, index) end
        end
        table.insert(samples, {health = healthState(), attacks = arena:GetAttribute("CombatAttacks"), winner = winner})
    end

    local outcome
    local ok, err = xpcall(function()
        controller = load()
        controller.run(function(value) done = true; finishCount += 1; winner = value or "draw" end, {timeLimit = 12})
        while not done and frame < 3000 do
            frame += 1
            tick(spec.trace[(frame - 1) % #spec.trace + 1])
            if spec.cancel and wall >= 1.7 then break end
        end
        if not spec.cancel then assert(done, "Round never completed") end
        controller.cancel()
        local frozenHealth, frozenPivots, frozenAttacks = healthState(), positions(), arena:GetAttribute("CombatAttacks")
        local endedCallbacks = finishCount
        local clampsBefore = #clampLog
        for _ = 1, 24 do
            paused = false
            clock += 1 / 60
            heartbeat:Fire(1 / 60)
            render:Fire(1 / 60)
        end
        compareFrozen(frozenHealth, frozenPivots, frozenAttacks)
        assert(#clampLog == clampsBefore, "Canceled logical movement continued")
        assert(finishCount == endedCallbacks, "Completion callback repeated after cancel")
        assert(heartbeat:Count() == 0 and render:Count() == 0, "Combat connections leaked")
        if spec.cancel then assert(finishCount == 0, "Cancel called winner callback") else assert(finishCount == 1, "Winner callback count wrong") end
        outcome = {
            frames = frame, health = frozenHealth, attacks = frozenAttacks, winner = winner,
            finished = finishCount, clamps = clampLog, attackLog = attackLog, samples = samples,
            renderMoves = renderMoves, renderSamples = renderSamples, pauseFrames = pauseFrames,
            pauseChecks = pauseChecks, noUpdatesAfterCancel = true, connectionsAfterCancel = heartbeat:Count() + render:Count(),
            finalPivots = frozenPivots, stopAllCount = stopAllCount,
        }
    end, debug.traceback)
    if controller then controller.cancel() end
    arena:Destroy()
    if not ok then error(err) end
    return outcome
end

return function(sources)
    assert(type(sources.before) == "string" and type(sources.after) == "string", "Provide before/after source strings")
    local cases = {
        {name = "steady_60fps", trace = {1 / 60}},
        {name = "steady_30fps", trace = {1 / 30}},
        {name = "jitter_and_hitch", trace = {1 / 120, .023, .041, .014, .061, 1 / 60, .18, 1 / 30, .28}},
        {name = "pause_resume_60fps", trace = {1 / 60}, pause = true},
        {name = "cancel_during_motion", trace = {1 / 60}, cancel = true},
    }
    local results = {}
    for _, spec in ipairs(cases) do
        local old, new = simulate(sources.before, spec), simulate(sources.after, spec)
        assert(old.frames == new.frames, spec.name .. ": frame count differs")
        assert(old.attacks == new.attacks, spec.name .. ": attack total differs")
        assert(old.winner == new.winner, spec.name .. ": winner differs")
        assert(old.finished == new.finished, spec.name .. ": callback count differs")
        assert(#old.samples == #new.samples, spec.name .. ": sample count differs")
        for frameIndex, sample in ipairs(old.samples) do
            local other = new.samples[frameIndex]
            assert(sample.attacks == other.attacks and sample.winner == other.winner, spec.name .. ": frame result differs at " .. frameIndex)
            for index, health in ipairs(sample.health) do
                assert(health == other.health[index], spec.name .. ": health differs at frame " .. frameIndex .. ", unit " .. index)
            end
        end
        assert(#old.clamps == #new.clamps, spec.name .. ": logical movement count differs")
        local maxError = 0
        for index, entry in ipairs(old.clamps) do
            local other = new.clamps[index]
            assert(entry.frame == other.frame, spec.name .. ": movement tick differs")
            maxError = math.max(maxError, (entry.point - other.point).Magnitude)
        end
        assert(maxError <= .001, spec.name .. ": logical movement drift " .. maxError)
        assert(#old.attackLog == #new.attackLog, spec.name .. ": attack sequence length differs")
        for index, entry in ipairs(old.attackLog) do
            local other = new.attackLog[index]
            assert(entry.frame == other.frame and entry.id == other.id, spec.name .. ": attack actor/timing differs")
        end
        for index, pivot in pairs(old.finalPivots) do
            assert(new.finalPivots[index], spec.name .. ": final survivor missing")
            assert((pivot.Position - new.finalPivots[index].Position).Magnitude <= .001, spec.name .. ": final endpoint differs")
        end
        assert(old.renderMoves == 0, "Baseline unexpectedly has interpolated movement")
        assert(new.renderMoves > 0, spec.name .. ": no motion between simulation ticks")
        if spec.pause then assert(new.pauseChecks > 0, "Pause was not exercised") end
        table.insert(results, {
            name = spec.name, passed = true, frames = new.frames, attacks = new.attacks,
            winner = new.winner or "canceled", finalHealth = new.health,
            logicalMovementSamples = #new.clamps, maxLogicalPositionError = maxError,
            baselineRenderMotionSamples = old.renderMoves, interpolatedRenderMotionSamples = new.renderMoves,
            pauseFramesVerified = new.pauseChecks, noUpdatesAfterCancel = new.noUpdatesAfterCancel,
            connectionsAfterCancel = new.connectionsAfterCancel, firstMotionSamples = new.renderSamples,
        })
    end
    return {passed = true, cases = results, note = "Real unparented Model/Part geometry; mocked clocks, services and data. No game state or progression modified."}
end

