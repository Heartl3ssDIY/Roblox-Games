local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local gui = script.Parent
local button = gui:WaitForChild("Swing")
local skin = button:WaitForChild("ReusableSkin")
local fallback = button:WaitForChild("Fallback")
local connections = {}
local nextTapAt = 0
local focused = true
local elapsed = 0

local function equippedBat()
	if not UserInputService.TouchEnabled or player:GetAttribute("PCDataReady") ~= true
		or player:GetAttribute("MDParticipating") == true then return nil end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or player:GetAttribute("BBRagdolled") == true
		or player:GetAttribute("TGRagdolled") == true or player:GetAttribute("HSRagdolled") == true or player:GetAttribute("DGRagdolled") == true then return nil end
	local gameId
	if player:GetAttribute("BBParticipating") == true and player:GetAttribute("BBRole") == "Bulldog" then
		local state = ReplicatedStorage:FindFirstChild("BritishBulldogState")
		if state and state:GetAttribute("Phase") == "Crossing" then gameId = "BritishBulldog" end
	elseif player:GetAttribute("TGParticipating") == true and player:GetAttribute("TGRole") == "Tagger" then
		local state = ReplicatedStorage:FindFirstChild("TagState")
		if state and state:GetAttribute("Phase") == "Playing" then gameId = "TagYoureIt" end
	elseif player:GetAttribute("HSParticipating") == true and player:GetAttribute("HSRole") == "Seeker" then
		local state = ReplicatedStorage:FindFirstChild("HideAndSeekState")
		if state and state:GetAttribute("Phase") == "Seeking" then gameId = "HideAndSeek" end
	elseif player:GetAttribute("DGParticipating") == true and player:GetAttribute("DGRole") == "Goose" then
		local state = ReplicatedStorage:FindFirstChild("DuckDuckGooseState")
		if state and state:GetAttribute("Phase") == "Playing" and state:GetAttribute("TurnPhase") == "Chasing" then gameId = "DuckDuckGoose" end
	end
	if not gameId then return nil end
	for _, tool in character:GetChildren() do
		if tool:IsA("Tool") and tool.Enabled and tool:GetAttribute("PCBatWeapon") == true
			and tool:GetAttribute("WeaponGame") == gameId then return tool end
	end
	return nil
end

local function remainingCooldown()
	local at = player:GetAttribute("PCBatSwingAt")
	local serverRemaining = typeof(at) == "number" and at > 0 and at + 0.75 - workspace:GetServerTimeNow() or 0
	return math.max(0, nextTapAt - os.clock(), serverRemaining)
end

local function refresh()
	local bat = equippedBat()
	button.Visible = bat ~= nil
	local ready = bat ~= nil and focused and not GuiService.MenuIsOpen
		and not UserInputService:GetFocusedTextBox() and remainingCooldown() <= 0
	button.Active = ready
	button.Selectable = false
	skin.ImageColor3 = ready and Color3.new(1, 1, 1) or Color3.fromRGB(164, 170, 184)
	button.Hint.Text = remainingCooldown() > 0 and string.format("%.1fs", remainingCooldown()) or "TAP"
	fallback.Visible = not skin.IsLoaded
end

local function swing()
	local bat = equippedBat()
	if not button.Visible or not gui.Enabled or not bat or not focused or GuiService.MenuIsOpen
		or UserInputService:GetFocusedTextBox() or remainingCooldown() > 0 then return end
	nextTapAt = os.clock() + 0.75
	local ok = pcall(function()
		bat:Activate()
		bat:Deactivate()
	end)
	if not ok then nextTapAt = 0 end
	refresh()
end

local function connect(signal, callback)
	table.insert(connections, signal:Connect(callback))
end
connect(button.Activated, swing)
connect(UserInputService.WindowFocusReleased, function() focused = false refresh() end)
connect(UserInputService.WindowFocused, function() focused = true refresh() end)
connect(UserInputService:GetPropertyChangedSignal("TouchEnabled"), refresh)
connect(player.CharacterRemoving, function() nextTapAt = 0 button.Visible = false end)
connect(player.CharacterAdded, function() nextTapAt = 0 refresh() end)
connect(RunService.Heartbeat, function(delta)
	elapsed += delta
	if elapsed >= 0.05 then elapsed = 0 refresh() end
end)
connect(script.Destroying, function()
	for _, connection in connections do connection:Disconnect() end
	button.Visible = false
end)
refresh()

