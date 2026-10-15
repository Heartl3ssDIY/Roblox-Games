local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local gui = script.Parent
local toggle = gui:WaitForChild("Toggle")
local panel = gui:WaitForChild("Panel")
local close = panel:WaitForChild("Close")
local content = panel:WaitForChild("Body"):WaitForChild("Content")
local card = content:WaitForChild("GameCard")
local status = card:WaitForChild("Status")
local message = content:WaitForChild("Message")
local buttons = {
	StartRound = card:WaitForChild("StartRound"),
	PracticeRunner = card:WaitForChild("PracticeRunner"),
	PracticeBulldog = card:WaitForChild("PracticeBulldog"),
	StopRound = content:WaitForChild("StopRound"),
}

local ink = Color3.fromRGB(24, 35, 62)
local muted = Color3.fromRGB(162, 169, 184)
local failureColor = Color3.fromRGB(171, 38, 57)
local busy = false
local lastResponse = {}
local state = nil
local stateConnections = {}
local connections = {}
local phaseNames = {
	Waiting = "Ready",
	Intermission = "Starting soon",
	Countdown = "Countdown",
	Crossing = "Playing",
	Results = "Round finished",
}
local modeNames = {
	Round = "Multiplayer",
	PracticeRunner = "Solo practice",
	PracticeBulldog = "Solo practice",
}

local function isAdmin()
	return player:GetAttribute("PlaygroundAdmin") == true
end

local function updateStatus()
	local phase = state and state:GetAttribute("Phase") or lastResponse.phase
	local mode = state and state:GetAttribute("Mode") or lastResponse.mode
	local role = player:GetAttribute("BBRole") or lastResponse.role
	local parts = {}
	if typeof(mode) == "string" and mode ~= "" then
		local friendlyMode = modeNames[mode]
		if friendlyMode then
			table.insert(parts, friendlyMode)
		end
	end
	if typeof(role) == "string" and role ~= "" and role ~= "Spectator" then
		table.insert(parts, role)
	end
	if typeof(phase) == "string" and phase ~= "" then
		table.insert(parts, phaseNames[phase] or phase)
	end
	status.Text = #parts > 0 and table.concat(parts, " · ") or "Waiting for server"
end

local function updateButtons()
	for _, control in pairs(buttons) do
		local enabled = isAdmin() and not busy
		control.Active = enabled
		control.Selectable = enabled
		control.AutoButtonColor = enabled
		local readyColor = control:GetAttribute("ReadyColor")
		control.BackgroundColor3 = enabled and readyColor or muted
	end
end

local function request(action)
	if not isAdmin() or busy then
		return
	end
	busy = true
	updateButtons()
	if action ~= "GetStatus" then
		message.Text = "Waiting for server..."
		message.TextColor3 = ink
	end

	local remote = ReplicatedStorage:FindFirstChild("PlaygroundAdminRequest")
	local succeeded, response = false, nil
	if remote and remote:IsA("RemoteFunction") then
		succeeded, response = pcall(function()
			return remote:InvokeServer(action)
		end)
	end
	busy = false
	updateButtons()
	if not isAdmin() or not gui.Parent then
		return
	end
	if not succeeded or typeof(response) ~= "table" then
		message.Text = "Server unavailable. Try again."
		message.TextColor3 = failureColor
		return
	end

	lastResponse = response
	updateStatus()
	if typeof(response.message) == "string" and response.message ~= "" then
		message.Text = response.message
	else
		message.Text = response.ok == true and "Done." or "Could not start. Try again."
	end
	message.TextColor3 = response.ok == true and ink or failureColor
end

local function setOpen(open)
	panel.Visible = isAdmin() and open
	toggle.Text = panel.Visible and "CLOSE" or "ADMIN"
	if panel.Visible then
		updateStatus()
		task.spawn(request, "GetStatus")
	end
end

local function syncAccess()
	gui.Enabled = isAdmin()
	if not isAdmin() then
		setOpen(false)
	end
	updateButtons()
end

local function bindState(candidate)
	if candidate.Name ~= "BritishBulldogState" or state == candidate then
		return
	end
	for _, connection in ipairs(stateConnections) do
		connection:Disconnect()
	end
	table.clear(stateConnections)
	state = candidate
	for _, name in ipairs({ "Phase", "Mode" }) do
		table.insert(stateConnections, candidate:GetAttributeChangedSignal(name):Connect(updateStatus))
	end
	updateStatus()
end

for action, control in pairs(buttons) do
	table.insert(connections, control.Activated:Connect(function()
		request(action)
	end))
end
table.insert(connections, toggle.Activated:Connect(function()
	setOpen(not panel.Visible)
end))
table.insert(connections, close.Activated:Connect(function()
	setOpen(false)
end))
table.insert(connections, player:GetAttributeChangedSignal("PlaygroundAdmin"):Connect(syncAccess))
table.insert(connections, player:GetAttributeChangedSignal("BBRole"):Connect(updateStatus))
table.insert(connections, ReplicatedStorage.ChildAdded:Connect(bindState))
table.insert(connections, ReplicatedStorage.ChildRemoved:Connect(function(child)
	if child == state then
		for _, connection in ipairs(stateConnections) do
			connection:Disconnect()
		end
		table.clear(stateConnections)
		state = nil
		updateStatus()
	end
end))
table.insert(connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or UserInputService:GetFocusedTextBox() then
		return
	end
	if input.KeyCode == Enum.KeyCode.F6 and isAdmin() then
		setOpen(not panel.Visible)
	end
end))
table.insert(connections, script.Destroying:Connect(function()
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	for _, connection in ipairs(stateConnections) do
		connection:Disconnect()
	end
end))

local existingState = ReplicatedStorage:FindFirstChild("BritishBulldogState")
if existingState then
	bindState(existingState)
end
panel.Visible = false
syncAccess()
updateStatus()
