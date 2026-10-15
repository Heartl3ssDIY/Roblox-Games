local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local gui = script.Parent
local panel = gui:WaitForChild("Panel")
local compact = gui:WaitForChild("CompactPanel")
local panels = { panel, compact }
local toggles = { gui.Toggle, gui:WaitForChild("CompactToggle") }
local contents = { panel.Body.Content, compact.Body.Content }
local controls = {}
local function addControl(control)
	controls[control.Name] = controls[control.Name] or {}
	table.insert(controls[control.Name], control)
end
for index, content in ipairs(contents) do
	for _, card in ipairs(content:GetChildren()) do
		if card:IsA("Frame") then
			for _, control in ipairs(card:GetChildren()) do if control:IsA("TextButton") then addControl(control) end end
		end
	end
	local footer = index == 1 and panel or content
	addControl(footer.StopRound)
	addControl(footer.ToggleAutomatic)
end
local phases = { Waiting = "Ready", Countdown = "Countdown", Crossing = "Playing", Playing = "Playing", Results = "Round finished", Intermission = "Next round" }
local busy = false
local opened = false
local connections = {}
local ink = Color3.fromRGB(24, 35, 62)
local failure = Color3.fromRGB(171, 38, 57)
local state = ReplicatedStorage:WaitForChild("PlaygroundState")
local bb = ReplicatedStorage:WaitForChild("BritishBulldogState")
local tag = ReplicatedStorage:WaitForChild("TagState")
local mud = ReplicatedStorage:WaitForChild("MudState")
local mudActions = { MudStart = true, MudShooter = true, MudMedic = true }
local function admin() return player:GetAttribute("PlaygroundAdmin") == true end
local function compactView()
	local camera = workspace.CurrentCamera
	return camera and (camera.ViewportSize.X < 980 or camera.ViewportSize.Y < 450) or false
end
local function syncVisibility()
	local enabled = admin()
	gui.Enabled = enabled
	if not enabled then opened = false end
	local useCompact = compactView()
	panel.Visible = enabled and opened and not useCompact
	compact.Visible = enabled and opened and useCompact
	gui.Toggle.Visible = not useCompact
	gui.CompactToggle.Visible = useCompact
	for _, toggle in ipairs(toggles) do toggle.Text = opened and "CLOSE" or "ADMIN" end
end
local function sync()
	syncVisibility()
	for action, duplicates in pairs(controls) do
		for _, control in ipairs(duplicates) do
			local enabled = admin() and not busy and (not mudActions[action] or mud:GetAttribute("GunAccessReady") == true)
			control.Active = enabled
			control.Selectable = enabled
			control.AutoButtonColor = enabled
			control.BackgroundColor3 = enabled and control:GetAttribute("ReadyColor") or Color3.fromRGB(162, 169, 184)
		end
	end
	for id, gameState in pairs({ BritishBulldog = bb, TagYoureIt = tag, StuckInTheMud = mud }) do
		local phase = gameState:GetAttribute("Phase") or "Waiting"
		local mode = gameState:GetAttribute("Mode") or ""
		local text = (string.find(mode, "Practice", 1, true) and "Solo practice · " or "") .. (phases[phase] or phase)
		if id == "StuckInTheMud" and mud:GetAttribute("GunAccessReady") ~= true then text = "Gun access pending" end
		for _, content in ipairs(contents) do content[id].Status.Text = text end
	end
	local text = state:GetAttribute("AutomaticRounds") == true and "AUTO ROUNDS: ON" or "AUTO ROUNDS: OFF"
	for _, control in ipairs(controls.ToggleAutomatic) do control.Text = text end
end
local function request(action)
	if not admin() or busy then return end
	if mudActions[action] and mud:GetAttribute("GunAccessReady") ~= true then return end
	busy = true
	sync()
	local ok, response = pcall(function() return ReplicatedStorage.PlaygroundAdminRequest:InvokeServer(action) end)
	busy = false
	if admin() and gui.Parent then
		local text = ok and typeof(response) == "table" and response.message or "Server unavailable. Try again."
		local color = ok and typeof(response) == "table" and response.ok and ink or failure
		panel.Message.Text = text
		panel.Message.TextColor3 = color
		compact.Body.Content.Message.Text = text
		compact.Body.Content.Message.TextColor3 = color
	end
	sync()
end
local function toggle()
	if not admin() then return end
	opened = not opened
	syncVisibility()
	if opened then task.spawn(request, "GetStatus") end
end
for action, duplicates in pairs(controls) do
	for _, control in ipairs(duplicates) do table.insert(connections, control.Activated:Connect(function() request(action) end)) end
end
for _, button in ipairs(toggles) do table.insert(connections, button.Activated:Connect(toggle)) end
for _, target in ipairs(panels) do table.insert(connections, target.Close.Activated:Connect(function() opened = false syncVisibility() end)) end
table.insert(connections, UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and not UserInputService:GetFocusedTextBox() and input.KeyCode == Enum.KeyCode.F6 then toggle() end
end))
table.insert(connections, player:GetAttributeChangedSignal("PlaygroundAdmin"):Connect(sync))
for _, object in ipairs({ state, bb, tag, mud }) do table.insert(connections, object.AttributeChanged:Connect(sync)) end
local elapsed = 0
table.insert(connections, RunService.Heartbeat:Connect(function(delta)
	elapsed += delta
	if elapsed >= 0.15 then elapsed = 0 syncVisibility() end
end))
script.Destroying:Connect(function() for _, connection in ipairs(connections) do connection:Disconnect() end end)
sync()
