-- Installed into ServerScriptService by InstallSelectedAssets.lua.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local remote = ReplicatedStorage:WaitForChild("SchoolPropDrop")
local held, registered, homes, cooldown = {}, {}, {}, {}

local function parts(model)
    local result = {}
    for _, p in model:GetDescendants() do
        if p:IsA("BasePart") then table.insert(result, p) end
    end
    return result
end

local function setPhysical(model, anchored, collidable)
    for _, p in parts(model) do
        p.Anchored = anchored
        p.CanCollide = collidable and p:GetAttribute("SchoolCollider") == true
        p.Massless = not collidable or p:GetAttribute("SchoolCollider") ~= true
    end
end

local function drop(player)
    local state = held[player]
    if not state then return end
    held[player] = nil
    if state.weld then state.weld:Destroy() end
    local model, root = state.model, state.model.PrimaryPart
    if model.Parent and root then
        setPhysical(model, false, false)
        local character = player.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = {character, model}
            local direction = hrp.CFrame.LookVector * 2.8
            local hit = workspace:Raycast(hrp.Position, direction, params)
            local point = hit and (hit.Position - direction.Unit * .6) or (hrp.Position + direction)
            model:PivotTo(CFrame.new(point) * model:GetPivot().Rotation)
            root.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity * .35 + hrp.CFrame.LookVector * 2
            root.AssemblyAngularVelocity = Vector3.new(1.4, .5, 2.2)
        end
        pcall(function() root:SetNetworkOwner(nil) end)
        model:SetAttribute("HeldBy", nil)
        task.delay(.2, function()
            if model.Parent and model:GetAttribute("HeldBy") == nil then
                setPhysical(model, false, true)
                if state.prompt.Parent then state.prompt.Enabled = true end
            end
        end)
    end
    if player.Parent then remote:FireClient(player, false) end
end

local function nearby(player, root, model)
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not humanoid or humanoid.Health <= 0 or not hrp then return false end
    if (hrp.Position - root.Position).Magnitude > 10 then return false end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {character, model}
    if workspace:Raycast(hrp.Position, root.Position - hrp.Position, params) then return false end
    return true
end

local function register(model)
    if registered[model] or not model:IsA("Model") or not model.PrimaryPart then return end
    registered[model] = true
    local root = model.PrimaryPart
    local prompt = root:FindFirstChild("SchoolInteractionPrompt")
    if not prompt then return end
    if model:GetAttribute("InteractionKind") == "pickup" then
        homes[model] = model:GetPivot()
        setPhysical(model, model:GetAttribute("InitialAnchored") ~= false, true)
        prompt.Triggered:Connect(function(player)
            if held[player] or model:GetAttribute("HeldBy") or not nearby(player, root, model) then return end
            if os.clock() - (cooldown[player] or 0) < .3 then return end
            local character = player.Character
            local hand = character and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm"))
            if not hand then return end
            cooldown[player] = os.clock()
            model:SetAttribute("HeldBy", player.UserId)
            prompt.Enabled = false
            setPhysical(model, false, false)
            model:PivotTo(hand.CFrame * CFrame.new(0, -.25, -.35))
            local weld = Instance.new("WeldConstraint")
            weld.Name = "SchoolCarryWeld";weld.Part0 = hand;weld.Part1 = root;weld.Parent = root
            held[player] = {model = model, weld = weld, prompt = prompt}
            remote:FireClient(player, true)
        end)
    elseif model:GetAttribute("InteractionKind") == "hinge" then
        local hinge = model:FindFirstChild("SchoolHinge", true)
        if not hinge then return end
        local last = 0
        prompt.Triggered:Connect(function(player)
            if not nearby(player, root, model) or os.clock() - last < .3 then return end
            last = os.clock()
            local opened = not model:GetAttribute("Open")
            model:SetAttribute("Open", opened)
            hinge.TargetAngle = opened and model:GetAttribute("OpenAngle") or 0
            prompt.ActionText = opened and "Close" or "Open"
        end)
    end
end

for _, m in CollectionService:GetTagged("SchoolInteractive") do register(m) end
CollectionService:GetInstanceAddedSignal("SchoolInteractive"):Connect(register)
remote.OnServerEvent:Connect(function(player)
    if held[player] and os.clock() - (cooldown[player] or 0) >= .2 then
        cooldown[player] = os.clock();drop(player)
    end
end)
local function watchPlayer(player)
    player.CharacterRemoving:Connect(function() drop(player) end)
    local function watchCharacter(character)
        local humanoid = character:WaitForChild("Humanoid", 10)
        if humanoid then humanoid.Died:Connect(function() drop(player) end) end
    end
    player.CharacterAdded:Connect(watchCharacter)
    if player.Character then task.spawn(watchCharacter, player.Character) end
end
for _, player in Players:GetPlayers() do watchPlayer(player) end
Players.PlayerAdded:Connect(watchPlayer)
Players.PlayerRemoving:Connect(function(player) drop(player);cooldown[player] = nil end)
local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
    elapsed += dt
    if elapsed < 1 then return end
    elapsed = 0
    for model, home in homes do
        if not model.Parent then homes[model] = nil;registered[model] = nil
        elseif model.PrimaryPart and not model:GetAttribute("HeldBy") and model.PrimaryPart.Position.Y < workspace.FallenPartsDestroyHeight + 30 then
            setPhysical(model, true, true);model:PivotTo(home)
            model.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
            model.PrimaryPart.AssemblyAngularVelocity = Vector3.zero
        end
    end
end)
