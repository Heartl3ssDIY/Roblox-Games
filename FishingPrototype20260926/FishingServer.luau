local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local ConfigService = game:GetService("ConfigService")

local lobby = workspace:WaitForChild("Lobby_MainModeZone")
local markers = lobby:WaitForChild("Markers")
local spots = {
    markers:WaitForChild("HOBBY_Fishing"),
    markers:WaitForChild("HOBBY_OuterGardenFishing"),
}
local events = ReplicatedStorage:WaitForChild("ArenaEvents")
local request = events:FindFirstChild("FishingRequest")
if not request then
    request = Instance.new("RemoteFunction")
    request.Name = "FishingRequest"
    request.Parent = events
end
assert(request:IsA("RemoteFunction"), "FishingRequest must be a RemoteFunction")

local snapshot
task.spawn(function()
    local ok, loaded = pcall(function() return ConfigService:GetConfigAsync() end)
    if not ok then return end
    snapshot = loaded
    snapshot.UpdateAvailable:Connect(function()
        pcall(function() snapshot:Refresh() end)
    end)
end)

local function setting(key, fallback, minimum, maximum)
    local value
    if snapshot then pcall(function() value = snapshot:GetValue(key) end) end
    if type(value) ~= "number" or value ~= value then return fallback end
    return math.clamp(value, minimum, maximum)
end

local function atSpot(player)
    if player:GetAttribute("ActiveArena") ~= nil then return false end
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not humanoid or humanoid.Health <= 0 or not root then return false end
    local maximum = setting("fishingInteractionDistance", 12, 6, 20)
    for _, spot in ipairs(spots) do
        if spot:IsDescendantOf(lobby) and (root.Position - spot.Position).Magnitude <= maximum then
            return true
        end
    end
    return false
end

local sessions = {}
local function stateFor(player)
    local state = sessions[player]
    if not state then
        state = { claimed = false, cast = nil, lastStart = -math.huge }
        sessions[player] = state
    end
    return state
end

local function meterPosition(now, cast)
    local phase = ((now - cast.startedAt) / cast.period + cast.offset) % 2
    return phase <= 1 and phase or 2 - phase
end

request.OnServerInvoke = function(player, action, token)
    if type(action) ~= "string" then return { ok = false, message = "Unknown action." } end
    local state = stateFor(player)
    if action == "Cancel" then
        if state.cast and token == state.cast.token then state.cast = nil end
        return { ok = true }
    end
    if not atSpot(player) then
        state.cast = nil
        return { ok = false, message = "Move closer to a fishing spot." }
    end
    local now = workspace:GetServerTimeNow()
    if action == "Start" then
        if state.claimed then
            return { ok = false, message = "You already earned this session's fishing pack." }
        end
        if state.cast and now - state.cast.startedAt < 14 then
            return { ok = false, message = "Finish your current cast first." }
        end
        local cooldown = setting("fishingAttemptCooldown", 2.5, 1, 10)
        if now - state.lastStart < cooldown then
            return { ok = false, message = "Wait a moment before casting again." }
        end
        local halfWidth = setting("fishingCatchHalfWidth", 0.075, 0.04, 0.16)
        local cast = {
            token = HttpService:GenerateGUID(false),
            startedAt = now,
            period = setting("fishingMeterPeriod", 1.65, 1.2, 3),
            offset = math.random(),
            targetMin = 0.5 - halfWidth,
            targetMax = 0.5 + halfWidth,
        }
        state.cast = cast
        state.lastStart = now
        return {
            ok = true,
            token = cast.token,
            startedAt = cast.startedAt,
            period = cast.period,
            offset = cast.offset,
            targetMin = cast.targetMin,
            targetMax = cast.targetMax,
        }
    end
    if action ~= "Reel" then return { ok = false, message = "Unknown action." } end
    local cast = state.cast
    if not cast or type(token) ~= "string" or token ~= cast.token then
        return { ok = false, message = "Cast again before reeling." }
    end
    state.cast = nil
    if state.claimed then return { ok = false, message = "Pack already awarded this session." } end
    if now - cast.startedAt > 14 then
        return { ok = false, message = "The fish got away. Cast again." }
    end
    local position = meterPosition(now, cast)
    local tolerance = setting("fishingLatencyTolerance", 0.035, 0, 0.08)
    if position < cast.targetMin - tolerance or position > cast.targetMax + tolerance then
        return { ok = false, message = "Missed the catch band. Try again." }
    end
    state.claimed = true
    return {
        ok = true,
        caught = true,
        packId = "bronze",
        claimId = HttpService:GenerateGUID(false),
        message = "Common Pack earned for this session. Open it at the Packs hall.",
    }
end

Players.PlayerRemoving:Connect(function(player)
    sessions[player] = nil
end)
