local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local Models = ReplicatedStorage:WaitForChild("UnitModels")
local Animator = require(ReplicatedStorage:WaitForChild("UnitPreviewAnimator"))
local UnitViewport = {}
local states = {}

local function reduced(viewport)
    if GuiService.ReducedMotionEnabled then return true end
    local node = viewport
    while node do
        if node:GetAttribute("ReducedMotion") == true then return true end
        node = node.Parent
    end
    return false
end

local function cancelCamera(state)
    if state.tween then state.tween:Cancel(); state.tween = nil end
end

function UnitViewport.clear(viewport)
    local state = states[viewport]
    states[viewport] = nil
    if state then
        cancelCamera(state)
        for _, connection in ipairs(state.connections) do connection:Disconnect() end
    end
    Animator.detach(viewport)
    viewport.CurrentCamera = nil
    for _, object in ipairs(viewport:GetChildren()) do
        if object:IsA("WorldModel") or object:IsA("Camera") then object:Destroy() end
    end
end

local function visibleGeometry(model)
    local points = {}
    local minimum, maximum
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") and part.Transparency < 1 then
            local half = part.Size / 2
            for x = -1, 1, 2 do
                for y = -1, 1, 2 do
                    for z = -1, 1, 2 do
                        local point = part.CFrame:PointToWorldSpace(Vector3.new(half.X * x, half.Y * y, half.Z * z))
                        table.insert(points, point)
                        minimum = minimum and minimum:Min(point) or point
                        maximum = maximum and maximum:Max(point) or point
                    end
                end
            end
        end
    end
    if not minimum then
        local cf, size = model:GetBoundingBox()
        minimum, maximum = cf.Position - size / 2, cf.Position + size / 2
        for x = -1, 1, 2 do
            for y = -1, 1, 2 do
                for z = -1, 1, 2 do
                    table.insert(points, cf:PointToWorldSpace(Vector3.new(size.X * x, size.Y * y, size.Z * z) / 2))
                end
            end
        end
    end
    return (minimum + maximum) / 2, points
end

local function frame(state, immediate)
    local viewport = state.viewport
    local size = viewport.AbsoluteSize
    if size.X <= 0 or size.Y <= 0 then return end
    local aspect = size.X / size.Y
    if not immediate and state.aspect and math.abs(aspect - state.aspect) < .004 then return end
    state.aspect = aspect
    local tangent = math.tan(math.rad(state.camera.FieldOfView / 2))
    local distance = .1
    local padding = viewport:GetAttribute("PreviewPadding")
    padding = type(padding) == "number" and math.clamp(padding, 1, 1.5) or 1.12
    for _, point in ipairs(state.points) do
        local delta = point - state.center
        local x = math.abs(delta:Dot(state.basis.RightVector))
        local y = math.abs(delta:Dot(state.basis.UpVector))
        local depth = delta:Dot(state.direction)
        distance = math.max(distance, x * padding / (tangent * aspect) + depth, y * padding / tangent + depth)
    end
    state.distance = distance
    state.target = CFrame.lookAt(state.center + state.direction * distance, state.center)
    cancelCamera(state)
    if immediate or reduced(viewport) then
        state.camera.CFrame = state.target
    else
        state.tween = TweenService:Create(state.camera, TweenInfo.new(.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {CFrame = state.target})
        state.tween:Play()
    end
end

function UnitViewport.reveal(viewport, seconds)
    local state = states[viewport]
    if not state or not state.target or reduced(viewport) then return end
    cancelCamera(state)
    state.camera.CFrame = CFrame.lookAt(state.center + state.direction * state.distance * 1.12, state.center)
    state.tween = TweenService:Create(state.camera, TweenInfo.new(seconds or .4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {CFrame = state.target})
    state.tween:Play()
end

function UnitViewport.show(viewport, modelName)
    local template = Models:FindFirstChild(modelName)
    local existing = states[viewport]
    if existing and existing.template == template and existing.model.Parent == existing.world and existing.world.Parent == viewport then
        frame(existing, false)
        return true
    end
    UnitViewport.clear(viewport)
    if not template or not template:IsA("Model") then return false end
    local world = Instance.new("WorldModel")
    world.Name = "World"
    world.Parent = viewport
    local model = template:Clone()
    local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
    for _, object in ipairs(model:GetDescendants()) do
        if object:IsA("BasePart") then
            object.Anchored = object == root
            object.CanCollide = false
            object.CanTouch = false
            object.CanQuery = false
            object.Massless = true
        elseif object:IsA("BaseScript") then
            object:Destroy()
        end
    end
    model:PivotTo(model:GetPivot().Rotation)
    model.Parent = world
    local direction = root and root.CFrame.LookVector or Vector3.new(0, 0, -1)
    local forward = Vector3.new(direction.X, 0, direction.Z)
    if forward.Magnitude < .01 then forward = Vector3.new(0, 0, -1) end
    forward = forward.Unit
    local right = forward:Cross(Vector3.yAxis)
    local viewDirection = (forward + right * .28 + Vector3.yAxis * .035).Unit
    local center, points = visibleGeometry(model)
    local camera = Instance.new("Camera")
    camera.Name = "Camera"
    camera.FieldOfView = 34
    camera.Parent = viewport
    viewport.CurrentCamera = camera
    local state = {
        viewport = viewport, template = template, world = world, model = model, camera = camera,
        center = center, points = points, direction = viewDirection,
        basis = CFrame.lookAt(Vector3.zero, -viewDirection), connections = {},
    }
    states[viewport] = state
    frame(state, true)
    table.insert(state.connections, viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        frame(state, state.target == nil)
    end))
    table.insert(state.connections, viewport:GetAttributeChangedSignal("PreviewPadding"):Connect(function()
        state.aspect = nil
        frame(state, false)
    end))
    table.insert(state.connections, viewport.Destroying:Connect(function() UnitViewport.clear(viewport) end))
    Animator.attach(viewport, model)
    return true
end

return UnitViewport