local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local gui = script.Parent
gui.Enabled = false
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
local phaseStartedAt = workspace:GetServerTimeNow()
local currentPhase = state:GetAttribute("Phase")
local alive = true
local moveSerial = 0

local function secondsRemaining(endsAt, now)
	return math.max(0, (tonumber(endsAt) or 0) - now)
end

local function update()
	local now = workspace:GetServerTimeNow()
	local participating = player:GetAttribute("TGParticipating") == true
	local phase = state:GetAttribute("Phase") or "Waiting"
	gui.Enabled = participating and (phase == "Countdown" or phase == "Playing" or phase == "Results")
	if not gui.Enabled then return end
	top.Visible = phase ~= "Results"
	if currentPhase ~= phase then currentPhase = phase phaseStartedAt = now end
	local remaining = phase == "Countdown" and (state:GetAttribute("RoundDuration") or 180) or secondsRemaining(state:GetAttribute("EndsAt"), now)
	local whole = math.ceil(remaining)
	top.Timer.Text = string.format("%d:%02d", math.floor(whole / 60), whole % 60)
	taggerName.Text = "IT: " .. tostring(state:GetAttribute("TaggerName") or "")
	local lastTaggerRule = state:GetAttribute("WinRule") == "LastTagger"
	local grace = secondsRemaining(state:GetAttribute("InitialGraceEndsAt"), now)
	top.Rule.Text = lastTaggerRule and "DON'T BE IT WHEN TIME RUNS OUT!" or grace > 0 and "FIRST CHASE GRACE: " .. tostring(math.ceil(grace)) .. "s" or "MOST TIME AS IT LOSES"
	local role = player:GetAttribute("TGRole") or "Runner"
	rolePanel.Visible = not gui:FindFirstChild("SprintPanel")
	rolePanel.BackgroundColor3 = role == "Tagger" and red or blue
	rolePanel.Title.Text = role == "Tagger" and "YOU'RE IT!" or "RUNNER"
	rolePanel.Time.Text = string.format("TIME AS IT: %.1fs", tonumber(player:GetAttribute("TGTaggerSeconds")) or 0)
	local protected = secondsRemaining(player:GetAttribute("TGProtectedEndsAt"), now)
	gui.Protection.Visible = protected > 0 and role == "Runner" and phase == "Playing" and now >= messageEndsAt
	gui.Protection.Text = "TAGBACK SHIELD: " .. tostring(math.ceil(protected)) .. "s"
	gui.Countdown.Visible = phase == "Countdown" or phase == "Playing" and now - phaseStartedAt < 0.7
	gui.Countdown.Text = phase == "Countdown" and tostring(state:GetAttribute("CountdownValue") or 3) or "GO!"
	controls.Visible = phase == "Playing"
	local button = controls.Dodge
	local cooldown = secondsRemaining(player:GetAttribute("TGDodgeReadyAt"), now)
	button.Text = "DODGE\n" .. (cooldown > 0 and string.format("%.1fs", cooldown) or UserInputService.TouchEnabled and "TAP" or "[E]")
	button.Active = cooldown == 0 and not busy and player:GetAttribute("TGRagdolled") ~= true

	gui.MoveMessage.Visible = now < messageEndsAt
	results.Visible = phase == "Results"
	if phase == "Results" then
		local won = player:GetAttribute("TGResult") == "Won"
		results.Title.Text = won and "YOU WIN!" or "TRY AGAIN!"
		results.Title.TextColor3 = Color3.fromRGB(255,248,221)
		results.Loser.Text = (lastTaggerRule and "FINAL TAGGER: " or "MOST TIME AS IT: ") .. tostring(state:GetAttribute("LosersText") or "")
		results.WinnersScroll.Winners.Text = "WINNERS: " .. tostring(state:GetAttribute("WinnersText") or "")
	end
end

local function dodgeDirection()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local camera = workspace.CurrentCamera
	local axis = camera and camera.CFrame.RightVector or Vector3.xAxis
	local right = Vector3.new(axis.X, 0, axis.Z)
	if right.Magnitude < 0.01 then right = Vector3.xAxis else right = right.Unit end
	if not root then return right end
	local lateral = humanoid and humanoid.MoveDirection:Dot(right) or 0
	if math.abs(lateral)>0.12 then return right * (lateral<0 and -1 or 1) end
	local nearest, distance
	for _, other in ipairs(Players:GetPlayers()) do
		local candidate=other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		if other~=player and candidate and other:GetAttribute("TGParticipating")==true and other:GetAttribute("TGRole")=="Tagger" then
			local delta=candidate.Position-root.Position
			if not distance or delta.Magnitude<distance then nearest,distance=candidate,delta.Magnitude end
		end
	end
	if nearest then local away=(root.Position-nearest.Position):Dot(right) if math.abs(away)>.1 then return right * (away<0 and -1 or 1) end end
	return right
end

local function move()
	if not alive or busy or player:GetAttribute("TGParticipating")~=true or player:GetAttribute("TGRagdolled")==true or state:GetAttribute("Phase")~="Playing" then return end
	if secondsRemaining(player:GetAttribute("TGDodgeReadyAt"),workspace:GetServerTimeNow())>0 then return end
	busy=true moveSerial+=1
	local serial=moveSerial
	local direction=dodgeDirection()
	local worker=task.spawn(function()
		local ok,accepted,message=pcall(function() return movement:InvokeServer("Dodge",direction) end)
		if not alive or serial~=moveSerial then return end
		busy=false
		if not ok or not accepted then
			gui.MoveMessage.Text=ok and tostring(message or "Move is not ready") or "Move couldn't be sent. Try again."
			messageEndsAt=workspace:GetServerTimeNow()+1.8
		end
		update()
	end)
	task.delay(2,function()
		if alive and serial==moveSerial and busy then
			moveSerial+=1 busy=false pcall(task.cancel,worker)
			gui.MoveMessage.Text="Move couldn't be sent. Try again." messageEndsAt=workspace:GetServerTimeNow()+1.8
		end
	end)
end

controls.Dodge.Activated:Connect(move)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	if input.KeyCode==Enum.KeyCode.E or input.KeyCode==Enum.KeyCode.X then move() end
end)
player.AttributeChanged:Connect(update)
state.AttributeChanged:Connect(update)
local accumulator = 0
RunService.RenderStepped:Connect(function(dt)
	accumulator = accumulator + dt
	if accumulator >= 0.1 then accumulator = 0 update() end
end)
script.Destroying:Connect(function() alive=false moveSerial+=1 end)
update()

