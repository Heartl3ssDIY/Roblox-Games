local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local gui = script.Parent
local panel = gui:WaitForChild("Panel")
local content = panel.Body.Content
local controls = {}
for _, card in ipairs(content:GetChildren()) do
	if card:IsA("Frame") then
		for _, control in ipairs(card:GetChildren()) do if control:IsA("TextButton") then controls[control.Name] = control end end
	end
end
controls.StopRound = panel.StopRound
controls.ToggleAutomatic = panel.ToggleAutomatic
local phases = { Waiting = "Ready", Countdown = "Countdown", Crossing = "Playing", Playing = "Playing", Results = "Round finished", Intermission = "Next round" }
local busy = false
local connections = {}
local ink = Color3.fromRGB(24, 35, 62)
local failure = Color3.fromRGB(171, 38, 57)
local state = ReplicatedStorage:WaitForChild("PlaygroundState")
local bb = ReplicatedStorage:WaitForChild("BritishBulldogState")
local tag = ReplicatedStorage:WaitForChild("TagState")
local function admin() return player:GetAttribute("PlaygroundAdmin") == true end
local function sync()
	gui.Enabled = admin()
	if not admin() then panel.Visible = false end
	for name, control in pairs(controls) do
		local enabled = admin() and not busy
		control.Active = enabled
		control.Selectable = enabled
		control.AutoButtonColor = enabled
		control.BackgroundColor3 = enabled and control:GetAttribute("ReadyColor") or Color3.fromRGB(162, 169, 184)
	end
	for id, gameState in pairs({ BritishBulldog = bb, TagYoureIt = tag }) do
		local phase = gameState:GetAttribute("Phase") or "Waiting"
		local mode = gameState:GetAttribute("Mode") or ""
		content[id].Status.Text = (string.find(mode, "Practice", 1, true) and "Solo practice · " or "") .. (phases[phase] or phase)
	end
	panel.ToggleAutomatic.Text = state:GetAttribute("AutomaticRounds") == true and "AUTO ROUNDS: ON" or "AUTO ROUNDS: OFF"
end
local function request(action)
	if not admin() or busy then return end
	busy = true
	sync()
	local ok, response = pcall(function() return ReplicatedStorage.PlaygroundAdminRequest:InvokeServer(action) end)
	busy = false
	if admin() and gui.Parent then
		panel.Message.Text = ok and typeof(response) == "table" and response.message or "Server unavailable. Try again."
		panel.Message.TextColor3 = ok and response and response.ok and ink or failure
	end
	sync()
end
local function toggle()
	if not admin() then return end
	panel.Visible = not panel.Visible
	gui.Toggle.Text = panel.Visible and "CLOSE" or "ADMIN"
	if panel.Visible then task.spawn(request, "GetStatus") end
end
for action, control in pairs(controls) do table.insert(connections, control.Activated:Connect(function() request(action) end)) end
table.insert(connections, gui.Toggle.Activated:Connect(toggle))
table.insert(connections, panel.Close.Activated:Connect(function() panel.Visible = false gui.Toggle.Text = "ADMIN" end))
table.insert(connections, UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and not UserInputService:GetFocusedTextBox() and input.KeyCode == Enum.KeyCode.F6 then toggle() end
end))
table.insert(connections, player:GetAttributeChangedSignal("PlaygroundAdmin"):Connect(sync))
for _, object in ipairs({ state, bb, tag }) do table.insert(connections, object.AttributeChanged:Connect(sync)) end
script.Destroying:Connect(function() for _, connection in ipairs(connections) do connection:Disconnect() end end)
panel.Visible = false
sync()
