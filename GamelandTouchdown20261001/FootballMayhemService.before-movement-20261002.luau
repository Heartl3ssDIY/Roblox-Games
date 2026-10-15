local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")
local ServerStorage = game:GetService("ServerStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Rules = require(script.Parent.FootballMayhemRules)
local assets = ReplicatedStorage:WaitForChild("FootballMayhem")
local arena = workspace:WaitForChild("Oni's Work"):WaitForChild("FootballMayhem")
local origin = assets.ArenaOrigin.Value
local remote = assets.Action
local feedback = assets.Feedback
local service = {}
local random = Random.new()
local round
local roundId = 0
local initialized = false
local cooldownUntil = 0
local connections = {}
local templates = ServerStorage:WaitForChild("FootballMayhemAssets")

local function prepareBall(player, state)
    local model = player.Character
    local hand = model and (model:FindFirstChild("RightHand") or model:FindFirstChild("Right Arm"))
    if not hand then return false end
    local ball = templates.AmericanFootball:Clone()
    ball.Name = "FootballMayhemBall"
    local primary = ball.PrimaryPart or ball:FindFirstChildWhichIsA("BasePart", true)
    if not primary then ball:Destroy() return false end
    ball.PrimaryPart = primary
    for _, part in ipairs(ball:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = false part.CanCollide = false part.CanTouch = false part.Massless = true
        end
    end
    ball:PivotTo(hand.CFrame * CFrame.new(0, -hand.Size.Y / 2, -0.45) * CFrame.Angles(math.pi / 2, 0, 0))
    ball:SetAttribute("CarrierUserId", player.UserId)
    ball.Parent = model
    local weld = Instance.new("WeldConstraint")
    weld.Name = "CarryWeld" weld.Part0 = hand weld.Part1 = primary weld.Parent = primary
    state.ball = ball
    state.ballWeld = weld
    return true
end

local function releaseBall(state, delivered)
    local ball = state.ball
    if not ball or not ball.Parent then return end
    if state.ballWeld then state.ballWeld:Destroy() state.ballWeld = nil end
    ball.Parent = arena.RoundEffects
    local primary = ball.PrimaryPart
    for _, part in ipairs(ball:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = true part.Massless = false end
    end
    if delivered then
        ball:PivotTo(origin * CFrame.new(0, 2, -131))
        primary.Anchored = true
    else
        primary:SetNetworkOwner(nil)
        primary.AssemblyLinearVelocity = Vector3.new(random:NextNumber(-12, 12), 18, random:NextNumber(-12, 12))
        primary.AssemblyAngularVelocity = Vector3.new(7, 4, 3)
    end
    Debris:AddItem(ball, 5)
    state.ball = nil
end

local function showQuarterback(player)
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local defender = templates.Quarterback:Clone()
    defender.Name = "QuarterbackFor_" .. player.UserId
    local humanoid = defender:FindFirstChildOfClass("Humanoid")
    if humanoid then humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
    for _, part in ipairs(defender:GetDescendants()) do
        if part:IsA("BasePart") then part.Anchored = true part.CanCollide = false part.CanTouch = false end
    end
    local flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
    if flat.Magnitude < 0.1 then flat = Vector3.new(0, 0, -1) end
    local front = root.Position + flat.Unit * 4
    defender:PivotTo(CFrame.lookAt(Vector3.new(front.X, origin.Position.Y + 3, front.Z), Vector3.new(root.Position.X, origin.Position.Y + 3, root.Position.Z)))
    local box, size = defender:GetBoundingBox()
    defender:PivotTo(defender:GetPivot() + Vector3.new(0, origin.Position.Y + 0.25 - (box.Position.Y - size.Y / 2), 0))
    defender.Parent = arena.RoundEffects
    Debris:AddItem(defender, 1.6)
end

local function character(player)
    local model = player.Character
    local humanoid = model and model:FindFirstChildOfClass("Humanoid")
    local root = model and model:FindFirstChild("HumanoidRootPart")
    if humanoid and root and humanoid.Health > 0 then return model, humanoid, root end
end

local function move(player, cf)
    local model, humanoid, root = character(player)
    if not model then return false end
    humanoid.Sit = false
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    model:PivotTo(cf)
    return true
end

local function restore(player, state)
    if state.fallTween then state.fallTween:Cancel() state.fallTween = nil end
    if state.grunt then state.grunt:Destroy() state.grunt = nil end
    if player.Parent then assets.Effects:FireAllClients("ClearStun", player.UserId) end
    for part, group in pairs(state.collisionGroups or {}) do
        if part.Parent then part.CollisionGroup = group end
    end
    if state.frozenRoot and state.frozenRoot.Parent then
        state.frozenRoot.Anchored = state.wasAnchored
    end
    local _, humanoid = character(player)
    if humanoid and humanoid == state.humanoid and state.savedMovement then
        humanoid.WalkSpeed = state.savedMovement.speed
        humanoid.JumpPower = state.savedMovement.jumpPower
        humanoid.JumpHeight = state.savedMovement.jumpHeight
        humanoid.AutoRotate = state.savedMovement.autoRotate
        humanoid.PlatformStand = state.savedMovement.platformStand
    end
end

local function returnToLobby(player, state)
    restore(player, state)
    if not player.Parent then return end
    local lobby = workspace:FindFirstChild("GamelandLobby")
    local spawn = lobby and lobby:FindFirstChild("LobbySpawn", true)
    if spawn then
        player.RespawnLocation = spawn
        move(player, spawn.CFrame + Vector3.new(random:NextNumber(-4, 4), 4, random:NextNumber(-3, 3)))
    end
    player:SetAttribute("InMinigame", false)
    player:SetAttribute("CurrentMinigame", nil)
end

local function remaining()
    local count = 0
    if round then
        for _, state in pairs(round.players) do
            if state.status == "Active" then count += 1 end
        end
    end
    return count
end

local function updateBoard()
    local text = arena.Scoreboard:FindFirstChild("Text", true)
    if text then
        if round and round.phase == "Active" then
            text.Text = "FOOTBALL MAYHEM\n" .. remaining() .. " STILL IN  /  " .. round.qualified .. " QUALIFIED"
        elseif round and round.phase == "Preparing" then
            text.Text = "FOOTBALL MAYHEM\nGET READY"
        else
            text.Text = "FOOTBALL MAYHEM\n10 ROWS  /  6 CHOICES  /  YOUR OWN PATH"
        end
    end
end

local function endIfComplete()
    if not round or round.phase ~= "Active" or remaining() > 0 then return end
    round.phase = "Finished"
    assets:SetAttribute("Phase", "Finished")
    cooldownUntil = os.clock() + 5
    local results = {}
    for player, state in pairs(round.players) do
        table.insert(results, {userId = player.UserId, status = state.status, rowsCompleted = state.progress,
            attemptedRow = state.lastRow, finishOrder = state.finishOrder})
    end
    service.RoundFinished:Fire(round.id, results)
    updateBoard()
end

local function finish(player, state, status, message)
    if not round or state.finished then return end
    state.finished = true
    state.status = status
    if state.tackled then showQuarterback(player) end
    releaseBall(state, status == "Qualified")
    if status == "Qualified" then
        round.qualified += 1
        state.finishOrder = round.qualified
    end
    if player.Parent then
        player:SetAttribute("FootballMayhemStatus", status)
        player:SetAttribute("FootballMayhemRowsCompleted", state.progress)
        player:SetAttribute("FootballMayhemFinishingRow", state.lastRow or state.progress)
        player:SetAttribute("FootballMayhemFinishOrder", state.finishOrder)
        feedback:FireClient(player, {kind = status, message = message, progress = state.progress,
            row = state.lastRow, lane = state.lastLane, tackled = state.tackled == true})
        local _, humanoid, root = character(player)
        if humanoid then
            state.humanoid = humanoid
            state.savedMovement = state.savedMovement or {speed = humanoid.WalkSpeed, jumpPower = humanoid.JumpPower,
                jumpHeight = humanoid.JumpHeight, autoRotate = humanoid.AutoRotate, platformStand = humanoid.PlatformStand}
            state.frozenRoot = root
            state.wasAnchored = root.Anchored
            root.Anchored = true
            humanoid.WalkSpeed = 0
            humanoid.JumpPower = 0
            humanoid.JumpHeight = 0
            humanoid.AutoRotate = false
            if state.tackled then
                humanoid.PlatformStand = true
                local facing = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
                if facing.Magnitude < 0.1 then facing = Vector3.new(0, 0, -1) end
                local floorPosition = Vector3.new(root.Position.X, origin.Position.Y + 1.3, root.Position.Z)
                local target = CFrame.lookAt(floorPosition, floorPosition + facing.Unit) * CFrame.Angles(-math.pi / 2, 0, 0)
                state.fallTween = TweenService:Create(root, TweenInfo.new(0.38, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = target})
                state.fallTween:Play()
                state.grunt = assets.Sounds.TackleGrunt:Clone()
                state.grunt.Parent = root
                state.grunt:Play()
                assets.Effects:FireAllClients("Stun", player.UserId, 3)
            end
        end
        local id = round.id
        task.delay(state.tackled and 3 or 1.8, function()
            if state.returnCancelled then return end
            if player.Parent and player:GetAttribute("FootballMayhemRoundId") == id then
                returnToLobby(player, state)
            else
                restore(player, state)
            end
        end)
    end
    updateBoard()
    endIfComplete()
end

function service.StartRound(roster)
    if round and (round.phase == "Active" or round.phase == "Preparing") then return false, "Round already running" end
    if os.clock() < cooldownUntil then return false, "Please wait for players to return" end
    local eligible, seen = {}, {}
    for _, player in ipairs(roster or Players:GetPlayers()) do
        if player:IsA("Player") and player.Parent == Players and not seen[player]
            and not player:GetAttribute("InMinigame") and character(player) then
            seen[player] = true
            table.insert(eligible, player)
        end
    end
    if #eligible == 0 then return false, "No ready players" end
    roundId += 1
    round = {id = roundId, phase = "Preparing", players = {}, qualified = 0}
    local thisRound = round
    assets:SetAttribute("Phase", "Preparing")
    assets:SetAttribute("RoundId", roundId)
    local rows = arena:GetAttribute("Rows")
    local lanes = arena:GetAttribute("Lanes")
    for index, player in ipairs(eligible) do
        local state = Rules.NewPlayerState(random, rows, lanes)
        state.spawnIndex = (index - 1) % 3 + 1
        state.spawnOffset = math.floor((index - 1) / 3) % 4
        round.players[player] = state
        player:SetAttribute("CurrentMinigame", "FootballMayhem")
        player:SetAttribute("InMinigame", true)
        player:SetAttribute("FootballMayhemStatus", "Preparing")
        player:SetAttribute("FootballMayhemRoundId", roundId)
        player:SetAttribute("FootballMayhemRowsCompleted", 0)
        player:SetAttribute("FootballMayhemFinishingRow", 0)
        player:SetAttribute("FootballMayhemFinishOrder", nil)
        feedback:FireClient(player, {kind = "Preparing", message = "Get ready — your wrong lanes are personal.", progress = 0})
    end
    updateBoard()
    task.delay(3, function()
        if round ~= thisRound or thisRound.phase ~= "Preparing" then return end
        round.phase = "Active"
        assets:SetAttribute("Phase", "Active")
        for player, state in pairs(round.players) do
            if state.status == "Active" and player.Parent then
                local pad = arena.StartPads:FindFirstChild("Start" .. state.spawnIndex)
                local cf = pad.CFrame + Vector3.new(0, 4, state.spawnOffset * 2)
                if move(player, cf) then
                    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
                    state.humanoid = humanoid
                    state.savedMovement = {speed = humanoid.WalkSpeed, jumpPower = humanoid.JumpPower,
                        jumpHeight = humanoid.JumpHeight, autoRotate = humanoid.AutoRotate, platformStand = humanoid.PlatformStand}
                    humanoid.WalkSpeed = state.savedMovement.speed * 2
                    state.collisionGroups = {}
                    for _, part in ipairs(player.Character:GetDescendants()) do
                        if part:IsA("BasePart") then
                            state.collisionGroups[part] = part.CollisionGroup
                            part.CollisionGroup = "FootballMayhemPlayers"
                        end
                    end
                    prepareBall(player, state)
                    state.lastPosition = origin:PointToObjectSpace(cf.Position)
                    state.lastChoiceAt = os.clock()
                    state.lastSafe = cf
                    player:SetAttribute("FootballMayhemStatus", "Active")
                    feedback:FireClient(player, {kind = "Active", message = "Pick one lane per row. Everyone has a different danger lane.", progress = 0})
                else
                    finish(player, state, "Eliminated", "Character unavailable — returned to the lobby.")
                end
            end
        end
        updateBoard()
        endIfComplete()
    end)
    return true, roundId
end

function service.ReturnPlayer(player)
    local state = round and round.players[player]
    if state and state.status == "Active" then
        finish(player, state, "Withdrawn", "Returned to the lobby by an admin.")
    end
    if state then state.returnCancelled = true end
    returnToLobby(player, state or {})
end

function service.StopRound()
    if not round or (round.phase ~= "Preparing" and round.phase ~= "Active") then
        return false, "No test is running."
    end
    round.phase = "Stopping"
    for player, state in pairs(round.players) do
        if state.status == "Active" then
            finish(player, state, "Stopped", "The admin stopped this test.")
        end
        state.returnCancelled = true
        if player.Parent and player:GetAttribute("CurrentMinigame") == "FootballMayhem" then
            returnToLobby(player, state)
        end
    end
    round.phase = "Active"
    endIfComplete()
    cooldownUntil = os.clock() + 0.5
    return true, "Test stopped. Players returned to the lobby."
end

function service.GetRoundSummary()
    local players = {}
    if round then
        for player, state in pairs(round.players) do
            table.insert(players, {userId = player.UserId, status = state.status, progress = state.progress})
        end
    end
    return {id = round and round.id or 0, phase = round and round.phase or "Idle", remaining = remaining(), players = players}
end

local function trackPlayer(player)
    if connections[player] then return end
    connections[player] = player.CharacterRemoving:Connect(function()
        local state = round and round.players[player]
        if state and state.status == "Active" then
            finish(player, state, "Eliminated", "Resetting or dying ends this attempt.")
        end
    end)
end

function service.Init()
    if initialized then return end
    initialized = true
    pcall(function() PhysicsService:RegisterCollisionGroup("FootballMayhemPlayers") end)
    PhysicsService:CollisionGroupSetCollidable("FootballMayhemPlayers", "FootballMayhemPlayers", false)
    service.RoundFinished = Instance.new("BindableEvent")
    service.RoundFinished.Name = "RoundFinished"
    service.RoundFinished.Parent = script.Parent
    local start = Instance.new("BindableFunction")
    start.Name = "StartRound"
    start.OnInvoke = service.StartRound
    start.Parent = script.Parent
    remote.OnServerEvent:Connect(function(player, action)
        local state = round and round.players[player]
        if action == "Leave" and state and state.status == "Active" then
            finish(player, state, "Eliminated", "You left the round.")
        end
    end)
    Players.PlayerAdded:Connect(trackPlayer)
    Players.PlayerRemoving:Connect(function(player)
        local state = round and round.players[player]
        if state and state.status == "Active" then
            releaseBall(state, false)
            restore(player, state)
            state.status = "Disconnected"
            state.finished = true
            endIfComplete()
            updateBoard()
        end
        if connections[player] then connections[player]:Disconnect() end
        connections[player] = nil
    end)
    for _, player in ipairs(Players:GetPlayers()) do trackPlayer(player) end
    local elapsed = 0
    RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed < 0.05 then return end
        local step = elapsed
        elapsed = 0
        if not round or round.phase ~= "Active" then return end
        for player, state in pairs(round.players) do
            if state.status ~= "Active" then continue end
            local _, humanoid, root = character(player)
            if not root then
                finish(player, state, "Eliminated", "Your attempt ended.")
                continue
            end
            local position = origin:PointToObjectSpace(root.Position)
            local previous = state.lastPosition or position
            local travel = (position - previous).Magnitude
            if math.abs(position.X) > 50 or position.Y < -6 or position.Y > 40 or math.abs(position.Z) > 145 then
                finish(player, state, "Eliminated", "Out of bounds — attempt ended.")
                continue
            end
            if travel > math.max(22, humanoid.WalkSpeed * step * 3 + 6) then
                move(player, state.lastSafe)
                state.lastPosition = origin:PointToObjectSpace(state.lastSafe.Position)
                continue
            end
            local oldDepth, depth = 110 - previous.Z, 110 - position.Z
            if state.lockedLane and depth >= state.releaseDepth then
                state.minimumDepth = math.max(state.minimumDepth, state.releaseDepth + 0.1)
                state.lockedLane = nil
                state.lastSafe = origin * CFrame.new(position.X, 4, 110 - state.minimumDepth - 0.2)
            end
            if state.minimumDepth then
                local correctedDepth = math.max(depth, state.minimumDepth)
                local correctedX = position.X
                if state.lockedLane then
                    local center = -40 + (state.lockedLane - 1) * 16
                    correctedX = math.clamp(correctedX, center - 7.1, center + 7.1)
                end
                if correctedDepth ~= depth or correctedX ~= position.X then
                    local corrected = Vector3.new(correctedX, position.Y, 110 - correctedDepth)
                    move(player, origin * CFrame.new(corrected) * origin:ToObjectSpace(root.CFrame).Rotation)
                    state.lastPosition = corrected
                    continue
                end
            end
            while state.progress < state.rows and state.status == "Active" do
                local row = state.progress + 1
                local threshold = 1 + (row - 1) * 22
                if depth < threshold then break end
                local alpha = depth > oldDepth and math.clamp((threshold - oldDepth) / (depth - oldDepth), 0, 1) or 1
                local x = previous.X + (position.X - previous.X) * alpha
                local lane = Rules.GetLane(x, 16, state.lanes)
                if not lane then
                    finish(player, state, "Eliminated", "Stay inside the six lanes.")
                    break
                end
                local accepted, result = Rules.ResolveChoice(state, row, lane)
                if not accepted then break end
                feedback:FireClient(player, {kind = "Reveal", row = row, lane = lane, dangerLane = state.wrong[row]})
                if result == "Eliminated" then
                    state.tackled = true
                    finish(player, state, "Eliminated", "OUT ON ROW " .. row .. " — " .. state.progress .. "/10 rows cleared")
                    break
                end
                state.lastChoiceAt = os.clock()
                state.warned = false
                state.minimumDepth = threshold + 0.15
                state.lockedLane = lane
                state.releaseDepth = (row - 1) * 22 + 16
                state.lastSafe = origin * CFrame.new(x, 4, 110 - state.minimumDepth - 0.2)
                player:SetAttribute("FootballMayhemRowsCompleted", state.progress)
                feedback:FireClient(player, {kind = "Safe", message = "SAFE — " .. state.progress .. "/10 rows cleared", progress = state.progress, row = row, lane = lane})
            end
            if state.status == "Active" and depth >= 220 and Rules.Qualify(state) then
                finish(player, state, "Qualified", "TOUCHDOWN! You qualified — returning to the lobby.")
            end
            if state.status == "Active" then
                local idle = os.clock() - state.lastChoiceAt
                local limit = math.max(15, arena:GetAttribute("InactivitySeconds") or 45)
                if idle >= limit then
                    finish(player, state, "Eliminated", "No progress — returned to the lobby so the round can finish.")
                elseif idle >= limit - 15 and not state.warned then
                    state.warned = true
                    feedback:FireClient(player, {kind = "Warning", message = "Choose your next row within 15 seconds to stay in.", progress = state.progress})
                end
            end
            state.lastPosition = position
        end
    end)
    updateBoard()
end

return service
