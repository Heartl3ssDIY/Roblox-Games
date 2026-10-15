local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")

local config = require(ReplicatedStorage:WaitForChild("RunnerConfig"))
if game.PlaceId ~= config.PlaceId then return end

local player = Players.LocalPlayer
local event = ReplicatedStorage:WaitForChild("RunnerEvent")
local cameraMarker = workspace:WaitForChild("Camera_Part")
local camera = workspace.CurrentCamera
local startX = -506.8
local courseCenterY = 23
local courseCenterZ = -9.5
local forward = Vector3.new(-1, 0, 0)
local cameraTarget = player
local smoothedCameraX
local spectateIndex = 0
local phase = "Waiting"

local function create(className, name, parent, properties)
	local object = Instance.new(className)
	object.Name = name
	for property, value in properties do
		object[property] = value
	end
	object.Parent = parent
	return object
end

local gui = create("ScreenGui", "RunnerUI", player:WaitForChild("PlayerGui"), {
	IgnoreGuiInset = true,
	ResetOnSpawn = false,
	DisplayOrder = 20,
})

local readyButton = create("TextButton", "TemporaryReadyButton", gui, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromScale(0.5, 0.94),
	Size = UDim2.fromOffset(260, 64),
	BackgroundColor3 = Color3.fromRGB(45, 192, 222),
	BorderSizePixel = 0,
	Font = Enum.Font.Arcade,
	Text = "READY",
	TextColor3 = Color3.new(1, 1, 1),
	TextSize = 30,
	Visible = false,
})
create("UICorner", "Corner", readyButton, { CornerRadius = UDim.new(0, 10) })

local countdown = create("TextLabel", "Countdown", gui, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.42),
	Size = UDim2.fromOffset(320, 160),
	BackgroundTransparency = 1,
	Font = Enum.Font.Arcade,
	Text = "",
	TextColor3 = Color3.new(1, 1, 1),
	TextScaled = true,
	TextStrokeColor3 = Color3.new(0, 0, 0),
	TextStrokeTransparency = 0,
})

local hint = create("TextLabel", "FlipHint", gui, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromScale(0.5, 0.995),
	Size = UDim2.fromOffset(450, 34),
	BackgroundTransparency = 1,
	Font = Enum.Font.Arcade,
	Text = "SPACE: FLIP GRAVITY",
	TextColor3 = Color3.fromRGB(220, 250, 255),
	TextSize = 18,
	TextStrokeTransparency = 0.25,
	Visible = false,
})

local flash = create("Frame", "RecoveryFlash", gui, {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(255, 30, 30),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 20,
})

local spectate = create("Frame", "Spectate", gui, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromScale(0.5, 0.96),
	Size = UDim2.fromOffset(420, 62),
	BackgroundColor3 = Color3.fromRGB(20, 28, 38),
	BackgroundTransparency = 0.2,
	BorderSizePixel = 0,
	Visible = false,
})
create("UICorner", "Corner", spectate, { CornerRadius = UDim.new(0, 10) })
local previous = create("TextButton", "Previous", spectate, {
	Size = UDim2.fromOffset(62, 62),
	BackgroundTransparency = 1,
	Font = Enum.Font.Arcade,
	Text = "<",
	TextColor3 = Color3.new(1, 1, 1),
	TextSize = 34,
})
local spectateName = create("TextLabel", "PlayerName", spectate, {
	Position = UDim2.fromOffset(62, 0),
	Size = UDim2.new(1, -124, 1, 0),
	BackgroundTransparency = 1,
	Font = Enum.Font.Arcade,
	Text = "SPECTATING",
	TextColor3 = Color3.new(1, 1, 1),
	TextScaled = true,
})
local nextButton = create("TextButton", "Next", spectate, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.fromOffset(62, 62),
	BackgroundTransparency = 1,
	Font = Enum.Font.Arcade,
	Text = ">",
	TextColor3 = Color3.new(1, 1, 1),
	TextSize = 34,
})

local function getControls()
	local scripts = player:FindFirstChild("PlayerScripts")
	local module = scripts and scripts:FindFirstChild("PlayerModule")
	if not module then return end
	local ok, result = pcall(require, module)
	if ok then return result:GetControls() end
end

ContextActionService:BindActionAtPriority("RunnerBlockMovement", function()
	return Enum.ContextActionResult.Sink
end, false, 3000, table.unpack(Enum.PlayerActions:GetEnumItems()))

task.spawn(function()
	local controls
	repeat
		controls = getControls()
		if not controls then task.wait(0.2) end
	until controls
	controls:Disable()
end)

local function canFlip()
	local status = player:GetAttribute("RunnerStatus")
	return status == "Waiting" or status == "Running"
end

local flipRay = RaycastParams.new()
flipRay.FilterType = Enum.RaycastFilterType.Exclude

local function touchingGravitySurface(root)
	if root.Anchored then return true end
	local character = player.Character
	if not character then return false end
	flipRay.FilterDescendantsInstances = { character }
	local sign = player:GetAttribute("GravitySign") or 1
	local direction = Vector3.new(0, -sign * config.GroundCheckDistance, 0)
	local hit = workspace:Raycast(root.Position, direction, flipRay)
	return hit ~= nil and hit.Instance.CanCollide
end

local function turnRunner(root)
	local sign = -(player:GetAttribute("GravitySign") or 1)
	root.CFrame = CFrame.lookAt(root.Position, root.Position + forward,
		Vector3.new(0, sign, 0))
	local velocity = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(velocity.X, velocity.Y, 0)
end

ContextActionService:BindActionAtPriority("RunnerFlipGravity", function(_, inputState)
	if inputState == Enum.UserInputState.Begin and canFlip() then
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and touchingGravitySurface(root) then
			turnRunner(root)
			event:FireServer("Flip")
		end
	end
	return Enum.ContextActionResult.Sink
end, false, 4000, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)

local function runnersToWatch()
	local result = {}
	for _, other in Players:GetPlayers() do
		if other:GetAttribute("RunnerStatus") == "Running" then
			table.insert(result, other)
		end
	end
	table.sort(result, function(first, second)
		return first.UserId < second.UserId
	end)
	return result
end

local function chooseSpectatorTarget(direction)
	local runners = runnersToWatch()
	if #runners == 0 then
		cameraTarget = player
		smoothedCameraX = nil
		spectateName.Text = "WAITING FOR NEXT ROUND"
		return
	end
	spectateIndex = (spectateIndex - 1 + direction) % #runners + 1
	cameraTarget = runners[spectateIndex]
	smoothedCameraX = nil
	spectateName.Text = cameraTarget.DisplayName
end

previous.Activated:Connect(function() chooseSpectatorTarget(-1) end)
nextButton.Activated:Connect(function() chooseSpectatorTarget(1) end)

ContextActionService:BindActionAtPriority("RunnerSpectate", function(_, inputState, input)
	if inputState ~= Enum.UserInputState.Begin or not spectate.Visible then
		return Enum.ContextActionResult.Sink
	end
	if input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.DPadLeft then
		chooseSpectatorTarget(-1)
	else
		chooseSpectatorTarget(1)
	end
	return Enum.ContextActionResult.Sink
end, false, 4000, Enum.KeyCode.Q, Enum.KeyCode.E,
	Enum.KeyCode.DPadLeft, Enum.KeyCode.DPadRight)

readyButton.Activated:Connect(function()
	if phase == "Waiting" then event:FireServer("Ready") end
end)

local function updateReadyButton()
	local status = player:GetAttribute("RunnerStatus")
	local isReady = player:GetAttribute("RunnerReady")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	readyButton.Visible = phase == "Waiting" and status == "Waiting" and root ~= nil
	readyButton.Text = isReady and "CANCEL READY" or "READY"
	readyButton.BackgroundColor3 = isReady
		and Color3.fromRGB(88, 210, 118)
		or Color3.fromRGB(45, 192, 222)
	hint.Visible = status == "Waiting" or status == "Running"
end

player:GetAttributeChangedSignal("RunnerReady"):Connect(updateReadyButton)
player:GetAttributeChangedSignal("RunnerStatus"):Connect(updateReadyButton)
player:GetAttributeChangedSignal("GBloxCourseReady"):Connect(updateReadyButton)
player.CharacterAdded:Connect(function(character)
	character:WaitForChild("HumanoidRootPart", 10)
	updateReadyButton()
end)

RunService.PreSimulation:Connect(function()
	local status = player:GetAttribute("RunnerStatus")
	if status ~= "Waiting" and status ~= "Running" then return end
	local laneZ = player:GetAttribute("RunnerLaneZ")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not laneZ or not root or root.Anchored then return end

	local velocity = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(velocity.X, velocity.Y, 0)
	local difference = laneZ - root.Position.Z
	if math.abs(difference) > 0.01 then
		root.CFrame += Vector3.new(0, 0, difference)
	end
end)

event.OnClientEvent:Connect(function(action, data)
	data = data or {}
	if action == "State" then
		phase = data.phase or phase
		if phase == "Waiting" then
			countdown.Text = ""
			spectate.Visible = false
			cameraTarget = player
			smoothedCameraX = nil
		elseif phase == "Countdown" then
			countdown.Text = tostring(data.number or "")
			readyButton.Visible = false
		elseif phase == "Running" then
			countdown.Text = ""
			readyButton.Visible = false
		end
		updateReadyButton()
	elseif action == "ReadyChanged" then
		updateReadyButton()
	elseif action == "Recover" then
		smoothedCameraX = nil
		flash.BackgroundTransparency = 0.45
		TweenService:Create(flash, TweenInfo.new(0.5), {
			BackgroundTransparency = 1,
		}):Play()
	elseif action == "Boost" then
		hint.Text = "2X SPEED!"
		task.delay(data.seconds or 3, function()
			hint.Text = "SPACE: FLIP GRAVITY"
		end)
	elseif action == "Finished" or action == "Out" then
		countdown.Text = action == "Finished" and "FINISHED!" or "OUT!"
		hint.Visible = false
		spectate.Visible = true
		spectateIndex = 0
		chooseSpectatorTarget(1)
	elseif action == "SaveFailed" then
		countdown.Text = "SAVE FAILED - TRY THE FINISH AGAIN"
	elseif action == "ReturnFailed" then
		countdown.Text = "REJOIN G-BLOX TO ENTER THE LOBBY"
	end
end)

task.spawn(function()
	while not player:GetAttribute("GBloxCourseReady") do task.wait(0.1) end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = config.CameraFieldOfView
	updateReadyButton()
end)

RunService:BindToRenderStep("RunnerCamera", Enum.RenderPriority.Camera.Value + 1,
	function(deltaTime)
		if not player:GetAttribute("GBloxCourseReady") then return end
		local character = cameraTarget and cameraTarget.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then return end
		local desiredX = root.Position.X
		if not smoothedCameraX then
			smoothedCameraX = desiredX
		else
			local alpha = 1 - math.exp(-config.CameraFollowSpeed * deltaTime)
			smoothedCameraX += (desiredX - smoothedCameraX) * alpha
		end
		local xOffset = smoothedCameraX - startX
		local cameraPosition = cameraMarker.Position + Vector3.new(xOffset, 0, 0)
		local courseCenter = Vector3.new(smoothedCameraX, courseCenterY, courseCenterZ)
		camera.CFrame = CFrame.lookAt(cameraPosition, courseCenter)
	end)
