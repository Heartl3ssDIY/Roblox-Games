-- Run once through Studio MCP in Client Play, from the idle lobby.
-- Returns immediately; poll workspace.RockLiiAnimationQA's Status/Report attributes.
-- All test rigs are temporary. No remotes, rewards, persistence, or combat stats are used.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local HttpService = game:GetService("HttpService")
assert(RunService:IsClient() and RunService:IsRunning(), "Run in the Client Play datamodel")
assert(not workspace:FindFirstChild("RockLiiAnimationQA"), "Read/remove the previous QA report before rerunning")

local output = Instance.new("Folder")
output.Name = "RockLiiAnimationQA"
output:SetAttribute("QAOwner", "RockLiiReviewed20260929")
output:SetAttribute("Status", "Running")
output.Parent = workspace

local ASSETS = {TriplePunch = 91381829613134, DrunkenFist = 82528180377250}
local report = {passed = false, checks = {}, clips = {}, startedAt = os.time()}
local function check(name, passed, detail)
    table.insert(report.checks, {name = name, passed = not not passed, detail = detail})
end

task.spawn(function()
    local rigs, loadedAnimations, connections = {}, {}, {}
    local MatchClock, Player, priorPause, priorPauseAttribute
    local localPlayer = Players.LocalPlayer
    local activeModel
    local function frame()
        RunService.Heartbeat:Wait()
    end
    local function realWait(seconds)
        local deadline = os.clock() + seconds
        repeat frame() until os.clock() >= deadline
    end
    local function poseDifference(a, b)
        local delta = a:ToObjectSpace(b)
        local _, angle = delta:ToAxisAngle()
        return delta.Position.Magnitude, math.abs(angle)
    end
    local function motors(model)
        local result = {}
        for _, object in ipairs(model:GetDescendants()) do
            if object:IsA("Motor6D") and object.Part0 and object.Part1 then
                result[object.Part1.Name] = object
            end
        end
        return result
    end
    local function capture(joints)
        local result = {}
        for name, motor in pairs(joints) do result[name] = motor.Transform end
        return result
    end
    local function comparePoses(a, b)
        local distance, angle = 0, 0
        for name, cf in pairs(a) do
            local d, r = poseDifference(cf, assert(b[name]))
            distance, angle = math.max(distance, d), math.max(angle, r)
        end
        return distance, angle
    end
    local function soleHeight(model)
        local lowest = math.huge
        for _, name in ipairs({"Right Leg", "Left Leg"}) do
            local part = assert(model:FindFirstChild(name))
            for _, x in ipairs({-0.5, 0.5}) do
                for _, y in ipairs({-0.5, 0.5}) do
                    for _, z in ipairs({-0.5, 0.5}) do
                        local p = part.CFrame:PointToWorldSpace(part.Size * Vector3.new(x, y, z))
                        lowest = math.min(lowest, p.Y)
                    end
                end
            end
        end
        return lowest
    end
    local function makeRig(name, offset)
        local original = ReplicatedStorage.UnitModels.Rare["ROCK LEE"][name]
        local model = assert(original, "Rock Lee template missing"):Clone()
        model.Name = "QA_" .. name
        for _, object in ipairs(model:GetDescendants()) do
            if object:IsA("BaseScript") then
                object:Destroy()
            elseif object:IsA("BasePart") then
                object.Anchored = false
                object.Massless = true
                object.CanCollide = false
                object.CanTouch = false
                object.CanQuery = false
            end
        end
        local root = assert(model:FindFirstChild("HumanoidRootPart"))
        root.Anchored = true
        model.PrimaryPart = root
        local humanoid = assert(model:FindFirstChildOfClass("Humanoid"))
        humanoid.AutoRotate = false
        humanoid.RequiresNeck = false
        humanoid.BreakJointsOnDeath = false
        humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        humanoid.EvaluateStateMachine = false
        local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
        model.Parent = output
        model:PivotTo(CFrame.new(offset or 0, 1000, 0))
        table.insert(rigs, model)
        return model, animator
    end
    local function playing(animator)
        return animator:GetPlayingAnimationTracks()
    end
    local function trackDetails(animator)
        local details = {}
        for _, track in ipairs(playing(animator)) do
            table.insert(details, {name = track.Name, asset = track.Animation and track.Animation.AnimationId,
                playing = track.IsPlaying, weight = track.WeightCurrent, targetWeight = track.WeightTarget,
                time = track.TimePosition, length = track.Length, priority = tostring(track.Priority)})
        end
        return details
    end
    local function findTrack(animator, assetId)
        local expected = tostring(assetId)
        for _, track in ipairs(playing(animator)) do
            if track.Animation and track.Animation.AnimationId:match("(%d+)$") == expected then
                return track
            end
        end
    end

    local ok, problem = xpcall(function()
        MatchClock = require(ReplicatedStorage:WaitForChild("MatchClock", 5))
        Player = require(ReplicatedStorage:WaitForChild("RockAnimationPlayer", 5))
        priorPause = MatchClock.isPaused()
        priorPauseAttribute = localPlayer:GetAttribute("MatchPaused")
        assert(not priorPause, "QA expects an idle, unpaused lobby")

        -- Preload the published assets before testing timing. Track.Length below is
        -- the authoritative playback-duration check, independently of this callback.
        local preloadStatuses = {}
        for kind, id in pairs(ASSETS) do
            local animation = Instance.new("Animation")
            animation.Name = "QA_Preload_" .. kind
            animation.AnimationId = "rbxassetid://" .. tostring(id)
            animation.Parent = output
            table.insert(loadedAnimations, animation)
        end
        ContentProvider:PreloadAsync(loadedAnimations, function(id, status)
            preloadStatuses[id] = tostring(status)
        end)
        report.preloadStatuses = preloadStatuses
        local model, animator = makeRig("Rock Lee")
        local joints = motors(model)
        for _, name in ipairs({"Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg"}) do
            assert(joints[name], "Missing R6 motor for " .. name)
        end
        activeModel = model
        table.insert(connections, RunService.PreAnimation:Connect(function()
            if activeModel and activeModel.Parent then Player.sync(activeModel) end
        end))
        realWait(0.1)

        local function testClip(kind, duration, pauseAt)
            local started = MatchClock.now()
            local accepted = kind == "TriplePunch" and Player.playAttack(model, started, false)
                or kind == "DrunkenFist" and Player.playAbility(model, started)
            assert(accepted, kind .. " production playback was rejected")
            local track = findTrack(animator, ASSETS[kind])
            local deadline = os.clock() + 2
            while not track and os.clock() < deadline do
                frame()
                track = findTrack(animator, ASSETS[kind])
            end
            assert(track, kind .. " did not become a playing Animator track")
            while track.Length == 0 and os.clock() < deadline do frame() end
            assert(track.Length > 0, kind .. " published animation did not load")
            local result = {
                assetId = ASSETS[kind], length = track.Length,
                samples = 0, rootDrift = 0, maxJointOffset = 0,
                motionRadians = {}, markers = {}, minSoleDelta = 0, maxSoleDelta = 0,
            }
            report.clips[kind] = result
            check(kind .. " loaded duration", math.abs(track.Length - duration) < 0.035, track.Length)
            check(kind .. " not looped", not track.Looped, track.Looped)
            local markerConnection = track:GetMarkerReachedSignal("Hit"):Connect(function(value)
                table.insert(result.markers, {value = value, time = MatchClock.now() - started})
            end)
            table.insert(connections, markerConnection)
            local root = model.HumanoidRootPart
            local initialRoot = root.CFrame
            local initialSole = soleHeight(model)
            local initialPose = capture(joints)
            local previousYaw, accumulatedYaw, paused = nil, 0, false
            local realDeadline = os.clock() + duration + 5
            while MatchClock.now() - started < duration + 0.18 and os.clock() < realDeadline do
                frame()
                result.samples += 1
                result.rootDrift = math.max(result.rootDrift, (root.Position - initialRoot.Position).Magnitude)
                local soleDelta = soleHeight(model) - initialSole
                result.minSoleDelta = math.min(result.minSoleDelta, soleDelta)
                result.maxSoleDelta = math.max(result.maxSoleDelta, soleDelta)
                for name, motor in pairs(joints) do
                    local _, angle = poseDifference(initialPose[name], motor.Transform)
                    result.motionRadians[name] = math.max(result.motionRadians[name] or 0, angle)
                    result.maxJointOffset = math.max(result.maxJointOffset, motor.Transform.Position.Magnitude)
                end
                local look = joints.Torso.Transform.LookVector
                local yaw = math.atan2(-look.X, -look.Z)
                if previousYaw then
                    local delta = (yaw - previousYaw + math.pi) % (2 * math.pi) - math.pi
                    accumulatedYaw += delta
                end
                previousYaw = yaw
                if not paused and MatchClock.now() - started >= pauseAt then
                    paused = true
                    MatchClock.setPaused(true)
                    Player.sync(model)
                    frame()
                    frame()
                    local frozenPose = capture(joints)
                    local frozenPosition, frozenClock = track.TimePosition, MatchClock.now()
                    realWait(0.35)
                    local d, a = comparePoses(frozenPose, capture(joints))
                    result.pause = {
                        jointTranslation = d, jointAngle = a,
                        trackDrift = math.abs(track.TimePosition - frozenPosition),
                        clockDrift = math.abs(MatchClock.now() - frozenClock), speed = track.Speed,
                    }
                    check(kind .. " pause freezes joints", d < 0.01 and a < 0.01, result.pause)
                    check(kind .. " pause freezes time", result.pause.trackDrift < 0.025
                        and result.pause.clockDrift < 0.001 and math.abs(track.Speed) < 0.001, result.pause)
                    MatchClock.setPaused(false)
                    Player.sync(model)
                    realWait(0.12)
                    result.resumedBy = track.TimePosition - frozenPosition
                    check(kind .. " resumes", result.resumedBy > 0.05, result.resumedBy)
                end
            end
            result.torsoYawDegrees = math.deg(accumulatedYaw)
            result.completed = not track.IsPlaying
            check(kind .. " stopped at end", result.completed, track.TimePosition)
            check(kind .. " anchored gameplay root", result.rootDrift < 0.005, result.rootDrift)
            check(kind .. " no exported world offset", result.maxJointOffset < 4, result.maxJointOffset)
            for _, name in ipairs({"Right Arm", "Left Arm", "Right Leg", "Left Leg"}) do
                check(kind .. " animates " .. name, (result.motionRadians[name] or 0) > 0.08, result.motionRadians[name])
            end
            if kind == "TriplePunch" then
                check("TriplePunch three Hit markers", #result.markers == 3, result.markers)
                for index, expected in ipairs({8/30, 19/30, 32/30}) do
                    local marker = result.markers[index]
                    check("TriplePunch Hit " .. index .. " timing", marker and math.abs(marker.time - expected) < 0.12,
                        {expected = expected, actual = marker and marker.time})
                end
                check("TriplePunch sole stays planted", result.minSoleDelta > -0.10
                    and result.maxSoleDelta < 0.10, {min = result.minSoleDelta, max = result.maxSoleDelta})
            else
                check("DrunkenFist completes one torso turn", math.abs(result.torsoYawDegrees) > 340
                    and math.abs(result.torsoYawDegrees) < 380, result.torsoYawDegrees)
            end
            markerConnection:Disconnect()
            Player.stop(model)
            -- A naturally finished track may remain in Animator's fade-out
            -- registry briefly even after Stop/Destroy. Allow that bounded
            -- engine tail to settle, then verify weights AND actual joint pose.
            realWait(0.35)
            result.tracksAfterStop = trackDetails(animator)
            local activeOwnTracks = 0
            for _, detail in ipairs(result.tracksAfterStop) do
                local id = detail.asset and tonumber(detail.asset:match("(%d+)$"))
                if (id == ASSETS.TriplePunch or id == ASSETS.DrunkenFist)
                    and (detail.playing or detail.weight > 0.005) then
                    activeOwnTracks += 1
                end
            end
            local neutral = {}
            for name in pairs(joints) do neutral[name] = CFrame.identity end
            local neutralDistance, neutralAngle = comparePoses(neutral, capture(joints))
            result.poseAfterStop = {translation = neutralDistance, angle = neutralAngle}
            -- Animator may briefly enumerate a finished zero-weight track.
            -- What matters is no playing/weighted clip and neutral Motor6Ds.
            check(kind .. " stop clears animation influence", activeOwnTracks == 0
                and neutralDistance < 0.01 and neutralAngle < 0.01,
                {tracks = result.tracksAfterStop, pose = result.poseAfterStop})
        end

        testClip("TriplePunch", 1.5, 0.40)
        testClip("DrunkenFist", 7, 2.00)
        assert(Player.playAttack(model, MatchClock.now(), false), "Replay after cleanup rejected")
        realWait(0.18)
        Player.stop(model)
        realWait(0.1)
        check("Explicit cancellation stops track", #playing(animator) == 0, #playing(animator))
        check("Mastery attack does not substitute triple", Player.playAttack(model, MatchClock.now(), true) == false,
            "Dedicated four-hit mastery clip is still required")

        local mastery, masteryAnimator = makeRig("Rock Lee Mastery 4", 15)
        activeModel = mastery
        assert(Player.playAbility(mastery, MatchClock.now()), "Mastery ability playback rejected")
        realWait(0.25)
        local masteryTrack = findTrack(masteryAnimator, ASSETS.DrunkenFist)
        check("Mastery rig loads same DrunkenFist", masteryTrack and math.abs(masteryTrack.Length - 7) < 0.035,
            masteryTrack and masteryTrack.Length)
        local masteryJoints = motors(mastery)
        local _, masteryArmAngle = poseDifference(CFrame.identity, masteryJoints["Right Arm"].Transform)
        check("Mastery rig receives animation pose", masteryArmAngle > 0.02, masteryArmAngle)
        mastery:Destroy()
        activeModel = nil
        realWait(0.1)
        local trackReadable, stillPlaying = pcall(function() return masteryTrack and masteryTrack.IsPlaying end)
        check("Destroyed model cleans up playback", not trackReadable or not stillPlaying, tostring(stillPlaying))
    end, debug.traceback)

    for _, connection in ipairs(connections) do connection:Disconnect() end
    for _, model in ipairs(rigs) do
        if Player then pcall(Player.stop, model) end
        if model.Parent then model:Destroy() end
    end
    for _, animation in ipairs(loadedAnimations) do animation:Destroy() end
    if MatchClock and priorPause ~= nil then
        MatchClock.setPaused(priorPause)
        localPlayer:SetAttribute("MatchPaused", priorPauseAttribute)
    end
    if not ok then report.error = problem end
    report.passed = ok
    for _, item in ipairs(report.checks) do
        if not item.passed then report.passed = false end
    end
    report.finishedAt = os.time()
    output:SetAttribute("Report", HttpService:JSONEncode(report))
    output:SetAttribute("Status", report.passed and "Passed" or "Failed")
    print("Rock Lii isolated animation QA:", report.passed and "PASSED" or "FAILED")
end)

return "Started. Poll workspace.RockLiiAnimationQA attributes Status and Report."
