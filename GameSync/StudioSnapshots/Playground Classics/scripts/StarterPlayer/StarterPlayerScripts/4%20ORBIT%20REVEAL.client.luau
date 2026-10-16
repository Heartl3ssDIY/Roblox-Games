-- ============================================
-- VARIAN 2: ORBIT REVEAL
-- Kamera orbit 180° dari depan karakter ke belakang, perlahan zoom in
-- Efek "reveal" - pertama melihat wajah, lalu berputar ke belakang
-- Taruh di: StarterPlayerScripts (LocalScript)
-- ============================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local hasPlayed = false

local CONFIG = {
	-- Fase 1: Hold di depan wajah (dramatis)
	holdFaceDuration = 2.5,
	faceDistance = 6,
	faceHeight = 2,

	-- Fase 2: Orbit 180° dari depan ke belakang
	orbitDuration = 5.0,
	orbitRadius = 14,
	orbitEndRadius = 6,
	orbitHeight = 4,
	orbitEndHeight = 2.5,

	-- Fase 3: Zoom out ke posisi gameplay
	zoomOutDuration = 2.5,

	returnDuration = 0.8,
}

local function waitForCharacterReady(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local rootPart = character:WaitForChild("HumanoidRootPart", 10)
	local head = character:WaitForChild("Head", 10)
	if not humanoid or not rootPart or not head then return false end
	if not player:HasAppearanceLoaded() then
		player.CharacterAppearanceLoaded:Wait()
	end
	return true
end

local function smoothStep(t)
	return t * t * t * (t * (t * 6 - 15) + 10)
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function smoothReturnToDefault(duration)
	local startCF = camera.CFrame
	camera.CameraType = Enum.CameraType.Custom
	RunService.RenderStepped:Wait()
	local targetCF = camera.CFrame
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = startCF

	local elapsed = 0
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		elapsed = elapsed + dt
		local alpha = math.min(elapsed / duration, 1)
		camera.CFrame = startCF:Lerp(targetCF, smoothStep(alpha))
		if alpha >= 1 then
			conn:Disconnect()
			camera.CameraType = Enum.CameraType.Custom
		end
	end)
end

local function playCinematic(character)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChild("Humanoid")
	if not rootPart or not humanoid then return end

	local savedWS = humanoid.WalkSpeed
	local savedJH = humanoid.JumpHeight
	humanoid.WalkSpeed = 0
	humanoid.JumpHeight = 0

	camera.CameraType = Enum.CameraType.Scriptable

	local origin = rootPart.Position
	local lookTarget = origin + Vector3.new(0, 1.5, 0)
	local facing = rootPart.CFrame.LookVector

	-- Fase 1: Hold close-up di depan wajah
	local faceCamPos = origin + facing * CONFIG.faceDistance + Vector3.new(0, CONFIG.faceHeight, 0)
	camera.CFrame = CFrame.lookAt(faceCamPos, lookTarget)

	-- Sedikit zoom in perlahan selama hold
	local elapsed = 0
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		elapsed = elapsed + dt
		local alpha = math.min(elapsed / CONFIG.holdFaceDuration, 1)
		local smooth = smoothStep(alpha)
		local dist = lerp(CONFIG.faceDistance, CONFIG.faceDistance - 1, smooth)
		local pos = origin + facing * dist + Vector3.new(0, CONFIG.faceHeight, 0)
		camera.CFrame = CFrame.lookAt(pos, lookTarget)

		if alpha >= 1 then
			conn:Disconnect()
		end
	end)

	task.wait(CONFIG.holdFaceDuration)

	-- Fase 2: Orbit 180° dari depan ke belakang
	local startAngle = math.atan2(facing.Z, facing.X)
	elapsed = 0

	conn = RunService.RenderStepped:Connect(function(dt)
		elapsed = elapsed + dt
		local alpha = math.min(elapsed / CONFIG.orbitDuration, 1)
		local smooth = smoothStep(alpha)

		local angle = startAngle + smooth * math.pi
		local radius = lerp(CONFIG.orbitRadius, CONFIG.orbitEndRadius, smooth)
		local height = lerp(CONFIG.orbitHeight, CONFIG.orbitEndHeight, smooth)

		local x = origin.X + math.cos(angle) * radius
		local z = origin.Z + math.sin(angle) * radius
		local y = origin.Y + height

		camera.CFrame = CFrame.lookAt(Vector3.new(x, y, z), lookTarget)

		if alpha >= 1 then
			conn:Disconnect()
		end
	end)

	task.wait(CONFIG.orbitDuration)

	-- Fase 3: Dari posisi orbit akhir, zoom out ke posisi gameplay
	local currentCF = camera.CFrame
	local behindPos = origin - facing * 8 + Vector3.new(0, 3, 0)
	local finalCF = CFrame.lookAt(behindPos, lookTarget)

	local tween = TweenService:Create(
		camera,
		TweenInfo.new(CONFIG.zoomOutDuration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{CFrame = finalCF}
	)
	tween:Play()
	tween.Completed:Wait()

	smoothReturnToDefault(CONFIG.returnDuration)
	humanoid.WalkSpeed = savedWS
	humanoid.JumpHeight = savedJH
end

local function onCharacterAdded(character)
	if hasPlayed then return end
	hasPlayed = true
	if not waitForCharacterReady(character) then return end
	task.wait(0.3)
	playCinematic(character)
end

if player.Character then
	task.spawn(function() onCharacterAdded(player.Character) end)
end
player.CharacterAdded:Connect(onCharacterAdded)