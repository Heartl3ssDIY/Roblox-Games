-- Published Blender animations for Rock Lii.
-- Both clips are owned by Deus Invictus Studios (168026080).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local MatchClock = require(ReplicatedStorage:WaitForChild("MatchClock"))

local RockAnimationPlayer = {}
local ASSET_IDS = {
    TriplePunch = 91381829613134,
    DrunkenFist = 82528180377250,
}
local DURATIONS = {
    TriplePunch = 1.5,
    DrunkenFist = 7,
}
local states = {}
local warned = {}
local R6_BODY_PARTS = {
    Torso = true, Head = true,
    ["Right Arm"] = true, ["Left Arm"] = true,
    ["Right Leg"] = true, ["Left Leg"] = true,
}

local function resetPose(state)
    -- Match-clock completion can stop a track just before Animator evaluates
    -- its final neutral sample. Clear only these clips' six R6 pose offsets;
    -- retain the rig's C0/C1 bind transforms and every cached animation track.
    for _, joint in ipairs(state.joints) do
        if joint.Parent then joint.Transform = CFrame.identity end
    end
end

-- Fetch both clips while the player is still in the lobby. PreloadAsync yields,
-- so run it separately and never delay requiring CombatController.
task.spawn(function()
    local assets = {}
    for kind, assetId in pairs(ASSET_IDS) do
        if type(assetId) == "number" and assetId > 0 then
            local animation = Instance.new("Animation")
            animation.Name = "RockLiiPrewarm" .. kind
            animation.AnimationId = "rbxassetid://" .. tostring(assetId)
            table.insert(assets, animation)
        end
    end
    if #assets > 0 then
        local ok, reason = pcall(function()
            ContentProvider:PreloadAsync(assets, function(contentId, status)
                if status ~= Enum.AssetFetchStatus.Success then
                    warn("Rock Lii animation preload failed for " .. tostring(contentId) .. ": " .. tostring(status))
                end
            end)
        end)
        if not ok then warn("Rock Lii animation preload failed: " .. tostring(reason)) end
    end
    for _, animation in ipairs(assets) do animation:Destroy() end
end)

local function animationFor(state, kind)
    local existing = state.tracks[kind]
    if existing then return existing end
    local assetId = ASSET_IDS[kind]
    if type(assetId) ~= "number" or assetId <= 0 then
        if not warned[kind] then
            warned[kind] = true
            warn("Rock Lii " .. kind .. " animation ID has not been set")
        end
        return nil
    end
    local humanoid = state.model:FindFirstChildOfClass("Humanoid")
    local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
    if not animator or not state.model:IsDescendantOf(workspace) then return nil end
    local animation = Instance.new("Animation")
    animation.Name = "RockLii" .. kind
    animation.AnimationId = "rbxassetid://" .. tostring(assetId)
    local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
    if not ok then
        warn("Rock Lii " .. kind .. " animation failed to load: " .. tostring(track))
        animation:Destroy()
        return nil
    end
    track.Priority = Enum.AnimationPriority.Action4
    track.Looped = false
    state.animations[kind] = animation
    state.tracks[kind] = track
    return track
end

local function getState(model)
    local state = states[model]
    if not state then
        local joints = {}
        for _, joint in ipairs(model:GetDescendants()) do
            if joint:IsA("Motor6D") and joint.Part1 and R6_BODY_PARTS[joint.Part1.Name] then
                table.insert(joints, joint)
            end
        end
        state = {model = model, tracks = {}, animations = {}, current = nil, joints = joints}
        states[model] = state
        state.destroying = model.Destroying:Connect(function()
            RockAnimationPlayer.stop(model)
        end)
    end
    return state
end

function RockAnimationPlayer.prepare(model)
    if not model or not model:IsDescendantOf(workspace) then return false end
    local state = getState(model)
    -- Loading the track now caches it on the deployed Animator. Playback still
    -- begins only when combat requests the move.
    local ability = animationFor(state, "DrunkenFist")
    if model:GetAttribute("MasteryForm") ~= true then
        animationFor(state, "TriplePunch")
    end
    return ability ~= nil
end

local function play(model, kind, startedAt)
    local state = getState(model)
    local track = animationFor(state, kind)
    if not track then return false end
    if state.current and state.current.track.IsPlaying then
        state.current.track:Stop(0.04)
    end
    state.current = {track = track, duration = DURATIONS[kind], startedAt = startedAt}
    track:Play(0.04, 1, 1)
    RockAnimationPlayer.sync(model)
    return true
end

function RockAnimationPlayer.playAttack(model, startedAt, masteryForm)
    -- Mastery 4 deals four hits in one second. No reviewed four-hit clip exists yet.
    if masteryForm then return false end
    return play(model, "TriplePunch", startedAt)
end

function RockAnimationPlayer.playAbility(model, startedAt)
    return play(model, "DrunkenFist", startedAt)
end

function RockAnimationPlayer.sync(model)
    local state = states[model]
    local current = state and state.current
    if not current then return end
    local track = current.track
    if not track.IsPlaying then
        state.current = nil
        resetPose(state)
        return
    end
    local age = math.max(0, MatchClock.now() - current.startedAt)
    if age >= current.duration then
        track:Stop(0)
        state.current = nil
        resetPose(state)
        return
    end
    local length = track.Length
    local speed = length > 0 and length / current.duration or 1
    track:AdjustSpeed(MatchClock.isPaused() and 0 or speed)
    if length > 0 then
        local expected = math.clamp(age / current.duration * length, 0, length)
        if math.abs(track.TimePosition - expected) > 0.08 then
            track.TimePosition = expected
        end
    end
end

function RockAnimationPlayer.stop(model)
    local state = states[model]
    if not state then return end
    states[model] = nil
    if state.destroying then state.destroying:Disconnect() end
    -- A track may still be fading after sync() clears state.current. Stop every
    -- cached track before destruction so no pose lingers into the next round.
    for _, track in pairs(state.tracks) do
        pcall(function() track:Stop(0) end)
        pcall(function() track:Destroy() end)
    end
    resetPose(state)
    for _, animation in pairs(state.animations) do animation:Destroy() end
end

function RockAnimationPlayer.stopAll()
    local models = {}
    for model in pairs(states) do table.insert(models, model) end
    for _, model in ipairs(models) do RockAnimationPlayer.stop(model) end
end

return RockAnimationPlayer

