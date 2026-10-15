local Players = game:GetService("Players")
local entriesFolder = script.Parent.Entries
local allowedUserIds = {[1201803949] = true}
local cache = {}
local lastAction = {}
local lastRead = {}
local service = {}

function service.IsAdmin(player)
    return typeof(player) == "Instance" and player:IsA("Player")
        and player.Parent == Players and allowedUserIds[player.UserId] == true
end

local function entries()
    local result = {}
    for _, module in ipairs(entriesFolder:GetChildren()) do
        if module:IsA("ModuleScript") then
            local entry = cache[module]
            if not entry then
                local ok, value = pcall(require, module)
                if ok and type(value) == "table" and type(value.Start) == "function"
                    and type(value.Stop) == "function" and type(value.Summary) == "function" then
                    cache[module] = value
                    entry = value
                end
            end
            if entry then result[module.Name] = entry end
        end
    end
    return result
end

local function snapshot(registry)
    local games = {}
    for id, entry in pairs(registry) do
        local state = entry.Summary()
        table.insert(games, {id = id, name = entry.DisplayName or id, description = entry.Description or "",
            badge = entry.Badge or "MG", phase = state.phase, remaining = state.remaining or 0})
    end
    table.sort(games, function(a, b) return a.name < b.name end)
    local ready = 0
    for _, player in ipairs(Players:GetPlayers()) do
        local c = player.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if h and h.Health > 0 and c:FindFirstChild("HumanoidRootPart") and not player:GetAttribute("InMinigame") then ready += 1 end
    end
    return {games = games, readyPlayers = ready}
end

local function returnToLobby(player, registry)
    for _, entry in pairs(registry) do
        if entry.ReleasePlayer then entry.ReleasePlayer(player) end
    end
    local model = player.Character
    local root = model and model:FindFirstChild("HumanoidRootPart")
    local humanoid = model and model:FindFirstChildOfClass("Humanoid")
    local lobby = workspace:FindFirstChild("GamelandLobby")
    local spawn = lobby and lobby:FindFirstChild("LobbySpawn", true)
    if not root or not humanoid or humanoid.Health <= 0 or not spawn then return false end
    root.Anchored = false
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    humanoid.Sit = false
    model:PivotTo(spawn.CFrame + Vector3.new(0, 4, 0))
    player:SetAttribute("CurrentMinigame", nil)
    player:SetAttribute("InMinigame", false)
    player:SetAttribute("AdminInspecting", nil)
    return true
end

function service.Handle(player, request)
    if not service.IsAdmin(player) then return {ok = false, message = "Admin access required."} end
    if type(request) ~= "table" or type(request.action) ~= "string" then
        return {ok = false, message = "Invalid request."}
    end
    local action = request.action
    if action ~= "Catalog" and action ~= "Start" and action ~= "Stop" and action ~= "Visit" and action ~= "Lobby" then
        return {ok = false, message = "Unknown action."}
    end
    local now = os.clock()
    local timers = action == "Catalog" and lastRead or lastAction
    if now - (timers[player] or -10) < (action == "Catalog" and 0.15 or 0.4) then
        return {ok = false, message = "Please wait a moment."}
    end
    timers[player] = now
    local registry = entries()
    if action == "Catalog" then return {ok = true, data = snapshot(registry)} end
    if action == "Lobby" then
        local ok = returnToLobby(player, registry)
        return {ok = ok, message = ok and "Returned to the lobby." or "Wait for your character to respawn.", data = snapshot(registry)}
    end
    if type(request.gameId) ~= "string" or #request.gameId > 80 or not registry[request.gameId] then
        return {ok = false, message = "Choose a registered minigame."}
    end
    local entry = registry[request.gameId]
    local ok, message
    if action == "Start" then
        if request.scope ~= "Self" and request.scope ~= "Lobby" then
            return {ok = false, message = "Choose who should join the test."}
        end
        local phase = entry.Summary().phase
        if phase == "Active" or phase == "Preparing" then
            return {ok = false, message = "A test is already running. Stop it before starting another.", data = snapshot(registry)}
        end
        if player:GetAttribute("AdminInspecting") then
            returnToLobby(player, registry)
            player:SetAttribute("AdminInspecting", nil)
        end
        local roster = request.scope == "Self" and {player} or Players:GetPlayers()
        ok, message = entry.Start(roster)
        if ok then message = request.scope == "Self" and "Your test is starting. Get ready!" or "Test starting for available lobby players." end
    elseif action == "Stop" then
        ok, message = entry.Stop()
    elseif action == "Visit" then
        if not returnToLobby(player, registry) then return {ok = false, message = "Wait for your character to respawn."} end
        if not entry.InspectionCFrame then return {ok = false, message = "This game has no inspection point."} end
        player:SetAttribute("AdminInspecting", request.gameId)
        player:SetAttribute("InMinigame", true)
        player:SetAttribute("CurrentMinigame", request.gameId .. "Preview")
        player.Character:PivotTo(entry.InspectionCFrame())
        ok, message = true, "Visiting " .. entry.DisplayName .. ". This does not start a round."
    end
    return {ok = ok == true, message = tostring(message or "Done."), data = snapshot(registry)}
end

Players.PlayerRemoving:Connect(function(player)
    lastAction[player] = nil
    lastRead[player] = nil
end)

return service
