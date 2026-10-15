local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local gui = script.Parent
local state = ReplicatedStorage:WaitForChild("BritishBulldogState")

local topCard = gui:WaitForChild("TopCard")
local topPanel = topCard:WaitForChild("Panel")
local timer = topPanel:WaitForChild("Timer")
local phaseLabel = topPanel:WaitForChild("PhaseLabel")
local bulldogChip = topPanel:WaitForChild("BulldogChip")
local runnerChip = topPanel:WaitForChild("RunnerChip")
local countdown = gui:WaitForChild("Countdown")
local rolePanel = gui:WaitForChild("RolePill"):WaitForChild("Panel")
local roleLabel = rolePanel:WaitForChild("RoleLabel")
local departure = gui:WaitForChild("Departure")
local departurePanel = departure:WaitForChild("Panel")
local departureSeconds = departurePanel:WaitForChild("SecondsBadge"):WaitForChild("Seconds")
local tagged = gui:WaitForChild("Tagged")
local taggedStatus = tagged:WaitForChild("Panel"):WaitForChild("Status")
local results = gui:WaitForChild("Results")
local resultPanel = results:WaitForChild("Panel")
local resultTitle = resultPanel:WaitForChild("Title")
local resultWinners = resultPanel:WaitForChild("WinnersScroll"):WaitForChild("Winners")

local colors = {
	Runner = Color3.fromRGB(42, 160, 255),
	Bulldog = Color3.fromRGB(255, 81, 92),
	Tagged = Color3.fromRGB(255, 204, 54),
	Spectator = Color3.fromRGB(122, 144, 177),
	Ink = Color3.fromRGB(24, 35, 62),
	White = Color3.fromRGB(255, 255, 255),
}

local previousPhase = nil
local previousRound = nil
local callEndsAt = 0
local musicStarted = false
local playingSound = nil
local playingSoundId = nil
local elapsed = 0
local connections = {}

local function numberAttribute(object, name, fallback)
	local value = object:GetAttribute(name)
	if typeof(value) == "number" and value == value and math.abs(value) < math.huge then
		return value
	end
	return fallback
end

local function textAttribute(object, name, fallback)
	local value = object:GetAttribute(name)
	if typeof(value) == "string" then
		return value
	end
	return fallback
end

local function stopMusic()
	if playingSound then
		playingSound:Stop()
	end
	playingSound = nil
	playingSoundId = nil
end

local function syncMusic(participating, phase)
	local sound = SoundService:FindFirstChild("BritishBulldogMusic")
	local canPlay = participating and musicStarted and (phase == "Countdown" or phase == "Crossing")
	canPlay = canPlay and sound and sound:IsA("Sound") and sound:GetAttribute("Enabled") == true
	canPlay = canPlay and sound.SoundId ~= "" and sound.SoundId ~= "rbxassetid://0"
	if not canPlay then
		stopMusic()
		return
	end
	if playingSound ~= sound or playingSoundId ~= sound.SoundId then
		stopMusic()
		playingSound = sound
		playingSoundId = sound.SoundId
		sound:Play()
	end
end

local function update()
	local now = workspace:GetServerTimeNow()
	local phase = textAttribute(state, "Phase", "Waiting")
	local round = numberAttribute(state, "RoundNumber", 0)
	local participating = player:GetAttribute("BBParticipating") == true
	local role = textAttribute(player, "BBRole", "Spectator")
	local active = phase == "Countdown" or phase == "Crossing" or phase == "Results"

	if round ~= previousRound then
		musicStarted = false
		callEndsAt = 0
		previousRound = round
	end
	if phase ~= previousPhase then
		if phase == "Crossing" then
			musicStarted = true
			if previousPhase == "Countdown" then
				callEndsAt = now + 0.9
			end
		elseif phase == "Waiting" or phase == "Intermission" or phase == "Results" then
			musicStarted = false
			callEndsAt = 0
		end
		previousPhase = phase
	end

	gui.Enabled = participating and active
	topCard.Visible = phase ~= "Results"
	gui.RolePill.Visible = phase ~= "Results" and not gui:FindFirstChild("MovementControls")
	results.Visible = phase == "Results"
	tagged.Visible = role == "Tagged" and phase ~= "Results"

	local endsAt = numberAttribute(state, "EndsAt", 0)
	local timeLeft = math.max(0, math.ceil(endsAt - now))
	if phase == "Countdown" and endsAt <= 0 then
		timeLeft = math.max(0, math.ceil(numberAttribute(state, "RoundDuration", 180)))
	end
	local minutes = math.floor(timeLeft / 60)
	timer.Text = string.format("%d:%02d", minutes, timeLeft % 60)
	timer.TextColor3 = timeLeft <= 30 and colors.Bulldog or colors.Ink
	bulldogChip.Count.Text = tostring(math.max(0, math.floor(numberAttribute(state, "BulldogCount", 0))))
	runnerChip.Count.Text = tostring(math.max(0, math.floor(numberAttribute(state, "RunnerCount", 0))))
	bulldogChip.Caption.Text = numberAttribute(state, "BulldogCount", 0) == 1 and "BULLDOG" or "BULLDOGS"
	runnerChip.Caption.Text = numberAttribute(state, "RunnerCount", 0) == 1 and "RUNNER" or "RUNNERS"
	phaseLabel.Text = "CROSSING " .. tostring(math.max(1, math.floor(numberAttribute(state, "CrossingNumber", 1))))

	local roleColor = colors[role] or colors.Spectator
	rolePanel.BackgroundColor3 = roleColor
	roleLabel.TextColor3 = role == "Tagged" and colors.Ink or colors.White
	roleLabel.Text = string.upper(role)
	local status = textAttribute(player, "BBStatus", "")
	taggedStatus.Text = status ~= "" and status or "FROZEN"

	local deadline = numberAttribute(player, "BBDepartureEndsAt", 0)
	local departureTime = math.max(0, math.ceil(deadline - now))
	local showDeparture = participating and role == "Runner" and phase == "Crossing" and player:GetAttribute("BBMustLeave") == true and departureTime > 0
	local compactDeparture = gui:FindFirstChild("CompactDeparture")
	local camera = workspace.CurrentCamera
	local useCompactDeparture = compactDeparture and camera and (camera.ViewportSize.X < 980 or camera.ViewportSize.Y < 450)
	departure.Visible = showDeparture and not useCompactDeparture
	if compactDeparture then
		compactDeparture.Visible = showDeparture and useCompactDeparture == true
		compactDeparture.Panel.SecondsBadge.Seconds.Text = tostring(departureTime)
	end
	departureSeconds.Text = tostring(departureTime)

	local count = math.floor(numberAttribute(state, "CountdownValue", 0))
	local counting = phase == "Countdown" and count >= 1 and count <= 3
	local called = phase == "Crossing" and now < callEndsAt
	countdown.Visible = counting or called
	countdown.Text = called and "BULLDOG!" or tostring(count)
	countdown.TextColor3 = called and colors.Tagged or colors.White

	local winnerTeam = textAttribute(state, "WinnerTeam", "None")
	if winnerTeam == "Bulldogs" then
		resultTitle.Text = "BULLDOGS WIN!"
		resultTitle.TextColor3 = colors.Bulldog
	elseif winnerTeam == "Runners" then
		resultTitle.Text = "SURVIVORS WIN!"
		resultTitle.TextColor3 = colors.Runner
	else
		resultTitle.Text = "ROUND FINISHED!"
		resultTitle.TextColor3 = colors.Ink
	end
	resultWinners.Text = textAttribute(state, "WinnersText", "")
	syncMusic(participating, phase)
end

table.insert(connections, state.AttributeChanged:Connect(update))
table.insert(connections, player.AttributeChanged:Connect(function(name)
	if string.sub(name, 1, 2) == "BB" then
		update()
	end
end))
table.insert(connections, RunService.Heartbeat:Connect(function(delta)
	elapsed += delta
	if elapsed >= 0.08 then
		elapsed = 0
		update()
	end
end))
script.Destroying:Connect(function()
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	stopMusic()
end)

update()
