local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Models = ReplicatedStorage:WaitForChild("UnitModels")
local Animator = require(ReplicatedStorage:WaitForChild("UnitPreviewAnimator"))
local UnitViewport = {}
local connections = setmetatable({}, {__mode = "k"})

function UnitViewport.clear(viewport)
    Animator.detach(viewport)
    local connection = connections[viewport]
    if connection then connection:Disconnect(); connections[viewport] = nil end
    viewport.CurrentCamera = nil
    for _, object in ipairs(viewport:GetChildren()) do
        if object:IsA("WorldModel") or object:IsA("Camera") then object:Destroy() end
    end
end

function UnitViewport.show(viewport, modelName)
    UnitViewport.clear(viewport)
    local template = Models:FindFirstChild(modelName)
    if not template then return false end
    local world = Instance.new("WorldModel")
    world.Name = "World"
    world.Parent = viewport
    local model = template:Clone()
    local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
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
    model.Parent = world
    local direction = root and root.CFrame.LookVector or Vector3.new(0, 0, -1)
    local forward = Vector3.new(direction.X, 0, direction.Z)
    if forward.Magnitude < 0.01 then forward = Vector3.new(0, 0, -1) end
    forward = forward.Unit
    local cf, size = model:GetBoundingBox()
    local camera = Instance.new("Camera")
    camera.Name = "Camera"
    camera.FieldOfView = 34
    camera.Parent = viewport
    viewport.CurrentCamera = camera
    local function frame()
        local visibleSize = viewport.AbsoluteSize
        local aspect = visibleSize.Y > 0 and visibleSize.X / visibleSize.Y
            or math.max(1, viewport.Size.X.Offset) / math.max(1, viewport.Size.Y.Offset)
        local halfHeight = math.max(size.Y / 2, math.max(size.X, size.Z) / (2 * aspect))
        local distance = halfHeight / math.tan(math.rad(camera.FieldOfView / 2)) + math.min(size.X, size.Z) / 2
        local right = forward:Cross(Vector3.yAxis)
        camera.CFrame = CFrame.lookAt(cf.Position + (forward + right * 0.28 + Vector3.yAxis * 0.035).Unit * distance * 1.1, cf.Position)
    end
    frame()
    connections[viewport] = viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(frame)
    Animator.attach(viewport, model)
    return true
end

return UnitViewport
