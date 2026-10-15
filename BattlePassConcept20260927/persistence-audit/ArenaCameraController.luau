local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local arena
local savedCamera
local zoom = 1
local pinchZoom = 1

local function restoreCamera()
	RunService:UnbindFromRenderStep("ArenaCamera")
	arena = nil
	local camera = workspace.CurrentCamera
	if savedCamera and camera then
		camera.CameraType = savedCamera.cameraType
		camera.FieldOfView = savedCamera.fieldOfView
		camera.CameraSubject = player.Character and player.Character:FindFirstChildOfClass("Humanoid") or savedCamera.subject
		savedCamera = nil
	end
end

local function updateCamera()
	local camera = workspace.CurrentCamera
	local focus = arena and arena:FindFirstChild("CameraFocus")
	if not camera or not focus then return end
	local aspect = camera.ViewportSize.X / math.max(1, camera.ViewportSize.Y)
	local height = math.max(79, 52 / math.max(0.45, aspect)) * zoom
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 52
	local position = focus.CFrame:PointToWorldSpace(Vector3.new(0, height, -height * 0.7))
	camera.CFrame = CFrame.lookAt(position, focus.Position)
	camera.Focus = focus.CFrame
end

local function arenaChanged()
    if player:GetAttribute("ArenaVisitOnly") == true then restoreCamera() return end
	local name = player:GetAttribute("ActiveArena")
	local nextArena = name and workspace:FindFirstChild(name)
	if not nextArena then restoreCamera() return end
	if not savedCamera then
		local camera = workspace.CurrentCamera
		savedCamera = { cameraType = camera.CameraType, fieldOfView = camera.FieldOfView, subject = camera.CameraSubject }
	end
	arena = nextArena
	zoom = 1
	RunService:UnbindFromRenderStep("ArenaCamera")
	RunService:BindToRenderStep("ArenaCamera", Enum.RenderPriority.Camera.Value + 1, updateCamera)
end

player:GetAttributeChangedSignal("ActiveArena"):Connect(arenaChanged)
player:GetAttributeChangedSignal("ArenaVisitOnly"):Connect(arenaChanged)
player.CharacterRemoving:Connect(restoreCamera)
UserInputService.InputChanged:Connect(function(input, processed)
	if arena and not processed and input.UserInputType == Enum.UserInputType.MouseWheel then
		zoom = math.clamp(zoom - input.Position.Z * 0.05, 0.85, 1.25)
	end
end)
UserInputService.TouchPinch:Connect(function(_, scale, _, state, processed)
	if not arena or processed then return end
	if state == Enum.UserInputState.Begin then pinchZoom = zoom end
	if state == Enum.UserInputState.Change then zoom = math.clamp(pinchZoom / math.max(scale, 0.1), 0.85, 1.25) end
end)
arenaChanged()
