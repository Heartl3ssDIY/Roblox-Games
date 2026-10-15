local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local gui = script.Parent
local state = ReplicatedStorage:WaitForChild("TagState")
local movement = ReplicatedStorage:WaitForChild("TagMovementRequest")
local top = gui:WaitForChild("Top")
local taggerName = top:WaitForChild("TaggerChip"):WaitForChild("Name")
local rolePanel = gui:WaitForChild("Role")
local controls = gui:WaitForChild("Controls")
local results = gui:WaitForChild("Results")
local blue = Color3.fromRGB(54, 174, 255)
local red = Color3.fromRGB(255, 83, 100)
local yellow = Color3.fromRGB(255, 204, 54)
local messageEndsAt = 0
local busy = false
local previousCamera
local phaseStartedAt = workspace:GetServerTimeNow()
local currentPhase = state:GetAttribute("Phase")
local movePose

local function camera(active)
	if active and not previousCamera then
		previousCamera = { minimum = player.CameraMinZoomDistance, maximum = player.CameraMaxZoomDistance }
		player.CameraMaxZoomDistance = math.max(player.CameraMaxZoomDistance, 28)
		player.CameraMinZoomDistance = 28
		player.CameraMaxZoomDistance = 28
	elseif not active and previousCamera then
		player.CameraMinZoomDistance = math.min(previousCamera.minimum, player.CameraMaxZoomDistance)
		player.CameraMaxZoomDistance = previousCamera.maximum
		player.CameraMinZoomDistance = previousCamera.minimum
		previousCamera = nil
	end
end

local function secondsRemaining(endsAt, now)
	return math.max(0, (tonumber(endsAt) or 0) - now)
end

local function update()
	local now = workspace:GetServerTimeNow()
	local participating = player:GetAttribute("TGParticipating") == true
	gui.Enabled = participating
	camera(participating)
	if not participating then return end
	local phase = state:GetAttribute("Phase") or "Waiting"
	if currentPhase ~= phase then currentPhase = phase phaseStartedAt = now end
	local remaining = phase == "Countdown" and (state:GetAttribute("RoundDuration") or 180) or secondsRemaining(state:GetAttribute("EndsAt"), now)
	local whole = math.ceil(remaining)
	top.Timer.Text = string.format("%d:%02d", math.floor(whole / 60), whole % 60)
	taggerName.Text = "IT: " .. tostring(state:GetAttribute("TaggerName") or "")
	local lastTaggerRule = state:GetAttribute("WinRule") == "LastTagger"
	local grace = secondsRemaining(state:GetAttribute("InitialGraceEndsAt"), now)
	top.Rule.Text = lastTaggerRule and "DON'T BE IT WHEN TIME RUNS OUT!" or grace > 0 and "FIRST CHASE GRACE: " .. tostring(math.ceil(grace)) .. "s" or "MOST TIME AS IT LOSES"
	local role = player:GetAttribute("TGRole") or "Runner"
	rolePanel.BackgroundColor3 = role == "Tagger" and red or blue
	rolePanel.Title.Text = role == "Tagger" and "YOU'RE IT!" or "RUNNER"
	rolePanel.Time.Text = string.format("TIME AS IT: %.1fs", tonumber(player:GetAttribute("TGTaggerSeconds")) or 0)
	local protected = secondsRemaining(player:GetAttribute("TGProtectedEndsAt"), now)
	gui.Protection.Visible = protected > 0 and role == "Runner" and phase == "Playing"
	gui.Protection.Text = "TAGBACK SHIELD: " .. tostring(math.ceil(protected)) .. "s"
	gui.Countdown.Visible = phase == "Countdown" or phase == "Playing" and now - phaseStartedAt < 0.7
	gui.Countdown.Text = phase == "Countdown" and tostring(state:GetAttribute("CountdownValue") or 3) or "GO!"
	controls.Visible = phase == "Playing"
	for _, action in ipairs({ "Vault", "Dodge" }) do
		local button = controls[action]
		local cooldown = secondsRemaining(player:GetAttribute("TG" .. action .. "ReadyAt"), now)
		local shortcut = action == "Vault" and "[Q]" or "[X]"
		button.Text = string.upper(action) .. " " .. (cooldown > 0 and string.format("%.1fs", cooldown) or shortcut)
		button.BackgroundColor3 = cooldown > 0 and Color3.fromRGB(194, 201, 206) or action == "Vault" and yellow or blue
		button.Active = cooldown == 0 and not busy
	end
	gui.MoveMessage.Visible = now < messageEndsAt
	results.Visible = phase == "Results"
	if phase == "Results" then
		local won = player:GetAttribute("TGResult") == "Won"
		results.Title.Text = won and "YOU WIN!" or "TRY AGAIN!"
		results.Title.TextColor3 = won and blue or red
		results.Loser.Text = (lastTaggerRule and "FINAL TAGGER: " or "MOST TIME AS IT: ") .. tostring(state:GetAttribute("LosersText") or "")
		results.WinnersScroll.Winners.Text = "WINNERS: " .. tostring(state:GetAttribute("WinnersText") or "")
	end
end

local function move(action)
	if busy or player:GetAttribute("TGParticipating") ~= true or state:GetAttribute("Phase") ~= "Playing" then return end
	busy = true
	task.spawn(function()
		local ok, accepted, message = pcall(function() return movement:InvokeServer(action) end)
		busy = false
		if not ok or not accepted then
			gui.MoveMessage.Text = ok and tostring(message or "Move is not ready") or "Move couldn't be sent. Try again."
			messageEndsAt = workspace:GetServerTimeNow() + 1.8
		else
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root then
				for _, joint in ipairs(character:GetDescendants()) do
					if joint:IsA("Motor6D") and joint.Part0 == root then
						movePose = { joint = joint, action = action, startedAt = workspace:GetServerTimeNow() }
						break
					end
				end
			end
		end
		update()
	end)
end

controls.Vault.Activated:Connect(function() move("Vault") end)
controls.Dodge.Activated:Connect(function() move("Dodge") end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	if input.KeyCode == Enum.KeyCode.Q then move("Vault")
	elseif input.KeyCode == Enum.KeyCode.X then move("Dodge") end
end)
player.AttributeChanged:Connect(update)
state.AttributeChanged:Connect(update)
local accumulator = 0
RunService.RenderStepped:Connect(function(dt)
	accumulator = accumulator + dt
	if accumulator >= 0.1 then accumulator = 0 update() end
end)
RunService.PreSimulation:Connect(function()
	local now = workspace:GetServerTimeNow()
	if movePose then
		local progress = (now - movePose.startedAt) / 0.38
		if progress >= 1 or not movePose.joint.Parent or player:GetAttribute("TGParticipating") ~= true then
			if movePose.joint.Parent then movePose.joint.Transform = CFrame.identity end
			movePose = nil
		else
			local blend = math.sin(math.pi * math.clamp(progress, 0, 1))
			local tilt = movePose.action == "Vault" and -0.32 or -0.25
			movePose.joint.Transform = CFrame.Angles(tilt * blend, 0, movePose.action == "Dodge" and 0.12 * blend or 0)
		end
	end
	local bots = workspace:FindFirstChild("TagPracticeBots")
	if bots then
		for _, character in ipairs(bots:GetChildren()) do
			local root = character:FindFirstChild("HumanoidRootPart")
			local torso = character:FindFirstChild("Torso")
			if root and torso then
				local speed = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude
				local swing = math.sin(now * 10) * math.min(speed / 16, 1) * 0.42
				for _, joint in ipairs(torso:GetChildren()) do
					if joint:IsA("Motor6D") then
						local sign = (joint.Name == "Right Hip" or joint.Name == "Left Shoulder") and 1 or -1
						if string.find(joint.Name, "Hip") or string.find(joint.Name, "Shoulder") then
							joint.Transform = CFrame.Angles(swing * sign, 0, 0)
						end
					end
				end
			end
		end
	end
end)
script.Destroying:Connect(function() camera(false) end)
update()
