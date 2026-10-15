local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local assets = game:GetService("ReplicatedStorage"):WaitForChild("FootballMayhem")
local presentation = {}
local reveals
local stuns = {}

local function part(name, size, color, parent, shape)
    local p = Instance.new("Part")
    p.Name = name p.Size = size p.Color = color p.Anchored = true
    p.CanCollide = false p.CanTouch = false p.CanQuery = false p.CastShadow = false
    p.Material = Enum.Material.Neon
    p.Shape = shape or Enum.PartType.Block
    p.Parent = parent
    return p
end

function presentation.ClearReveals()
    if reveals then reveals:Destroy() reveals = nil end
end

function presentation.Reveal(row, lane, dangerLane)
    local arena = workspace:FindFirstChild("Oni's Work") and workspace["Oni's Work"]:FindFirstChild("FootballMayhem")
    local rowModel = arena and arena.Rows:FindFirstChild(string.format("Row%02d", row))
    local tile = rowModel and rowModel:FindFirstChild("Choice" .. dangerLane)
    if not tile then return end
    if not reveals then
        reveals = Instance.new("Folder") reveals.Name = "PersonalFootballReveals" reveals.Parent = workspace
    end
    if reveals:FindFirstChild("Row" .. row) then return end
    local folder = Instance.new("Folder") folder.Name = "Row" .. row
    folder:SetAttribute("DangerLane", dangerLane) folder.Parent = reveals
    local lock = part("CommittedRow", Vector3.new(96, 0.07, 0.22), Color3.fromRGB(255, 187, 55), folder)
    local relative = assets.ArenaOrigin.Value:PointToObjectSpace(tile.Position)
    lock.CFrame = assets.ArenaOrigin.Value * CFrame.new(0, relative.Y + 0.17, relative.Z + 7.75)
    if lane ~= dangerLane then
        local defender = assets.Visuals.Quarterback:Clone()
        defender.Name = "RevealedQuarterback"
        local humanoid = defender:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
            humanoid.EvaluateStateMachine = false
        end
        for _, p in ipairs(defender:GetDescendants()) do
            if p:IsA("BasePart") then
                p.Anchored = true p.CanCollide = false p.CanTouch = false p.CanQuery = false
                p.CollisionGroup = "FootballMayhemVisuals"
            end
        end
        defender:PivotTo(tile.CFrame * CFrame.new(0, 3, 0) * CFrame.Angles(0, math.pi, 0))
        local cf, size = defender:GetBoundingBox()
        defender:PivotTo(defender:GetPivot() + Vector3.new(0, tile.Position.Y + tile.Size.Y / 2 - (cf.Position.Y - size.Y / 2), 0))
        defender.Parent = folder
    end
    local sound = assets.Sounds.RevealPop:Clone()
    sound.Parent = game:GetService("SoundService") sound:Play() Debris:AddItem(sound, 3)
end

function presentation.ClearStun(userId)
    local state = stuns[userId]
    if state then
        state.model:Destroy()
        stuns[userId] = nil
    end
end

function presentation.Stun(userId, duration)
    presentation.ClearStun(userId)
    local player = Players:GetPlayerByUserId(userId)
    if not player or not player.Character then return end
    local model = Instance.new("Model") model.Name = "FootballStun_" .. userId model.Parent = workspace
    local state = {model = model, player = player, started = os.clock(), duration = duration, stars = {}, birds = {}, ring = {}}
    stuns[userId] = state
    for index = 1, 14 do
        local ring = part("Swirl", Vector3.new(0.065, 0.065, 0.51), Color3.fromRGB(255, 214, 76), model)
        table.insert(state.ring, ring)
    end
    for index = 1, 3 do
        local anchor = part("Star", Vector3.new(0.1, 0.1, 0.1), Color3.new(1, 1, 1), model)
        anchor.Transparency = 1
        local billboard = Instance.new("BillboardGui") billboard.Name = "StarIcon"
        billboard.Size = UDim2.fromScale(0.85, 0.85) billboard.AlwaysOnTop = false billboard.MaxDistance = 120 billboard.Parent = anchor
        local star = Instance.new("TextLabel") star.Size = UDim2.fromScale(1, 1) star.BackgroundTransparency = 1
        star.Text = "★" star.Font = Enum.Font.FredokaOne star.TextScaled = true
        star.TextColor3 = Color3.fromRGB(255, 225, 49) star.TextStrokeColor3 = Color3.fromRGB(169, 99, 15)
        star.TextStrokeTransparency = 0.12 star.Parent = billboard
        table.insert(state.stars, anchor)
    end
    for index = 1, 2 do
        local bird = Instance.new("Model") bird.Name = "LittleBird" bird.Parent = model
        local body = part("Body", Vector3.new(0.55, 0.4, 0.7), Color3.fromRGB(70, 212, 255), bird, Enum.PartType.Ball)
        local head = part("Head", Vector3.new(0.38, 0.38, 0.38), Color3.fromRGB(115, 232, 255), bird, Enum.PartType.Ball)
        local beak = part("Beak", Vector3.new(0.18, 0.14, 0.25), Color3.fromRGB(255, 163, 52), bird)
        local left = part("LeftWing", Vector3.new(0.6, 0.07, 0.36), Color3.fromRGB(44, 144, 232), bird)
        local right = part("RightWing", Vector3.new(0.6, 0.07, 0.36), Color3.fromRGB(44, 144, 232), bird)
        table.insert(state.birds, {body = body, head = head, beak = beak, left = left, right = right})
    end
end

RunService.RenderStepped:Connect(function()
    for userId, state in pairs(stuns) do
        local character = state.player.Character
        local head = character and character:FindFirstChild("Head")
        local elapsed = os.clock() - state.started
        if not head or elapsed > state.duration or not state.player.Parent then
            presentation.ClearStun(userId)
            continue
        end
        local center = head.Position + Vector3.new(0, 2, 0)
        for i, ring in ipairs(state.ring) do
            local angle = i / #state.ring * math.pi * 2 + elapsed * 1.8
            local p = center + Vector3.new(math.cos(angle) * 1.15, math.sin(angle * 2 + elapsed) * 0.08, math.sin(angle) * 1.15)
            ring.CFrame = CFrame.lookAt(p, p + Vector3.new(-math.sin(angle), 0, math.cos(angle)))
        end
        for i, star in ipairs(state.stars) do
            local angle = elapsed * 3.2 + i / 3 * math.pi * 2
            star.Position = center + Vector3.new(math.cos(angle) * 1.8, math.sin(elapsed * 4 + i) * 0.2 + 0.1, math.sin(angle) * 1.8)
        end
        for i, bird in ipairs(state.birds) do
            local angle = -elapsed * 3 + i * math.pi
            local p = center + Vector3.new(math.cos(angle) * 1.5, 0.45 + math.sin(elapsed * 7) * 0.08, math.sin(angle) * 1.5)
            local cf = CFrame.lookAt(p, p + Vector3.new(math.sin(angle), 0, -math.cos(angle)))
            bird.body.CFrame = cf
            bird.head.CFrame = cf * CFrame.new(0, 0.17, -0.3)
            bird.beak.CFrame = cf * CFrame.new(0, 0.14, -0.55)
            local flap = math.sin(elapsed * 22) * 0.7
            bird.left.CFrame = cf * CFrame.new(-0.37, 0.1, 0) * CFrame.Angles(0, 0, flap)
            bird.right.CFrame = cf * CFrame.new(0.37, 0.1, 0) * CFrame.Angles(0, 0, -flap)
        end
    end
end)

return presentation
