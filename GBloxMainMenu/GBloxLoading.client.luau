local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local config = require(script:WaitForChild("MenuConfig"))
if game.PlaceId ~= config.MainPlaceId then
	return
end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local gui = script:WaitForChild("GBloxMenu"):Clone()
gui.Parent = playerGui
ReplicatedFirst:RemoveDefaultLoadingScreen()

local root = gui.Root
local loading = root.LoadingScreen
local main = root.MainScreen
local bar = loading.ProgressBar.Inner.Fill
local percentage = loading.ProgressBar.Inner.Percentage
local sounds = gui.Sounds
local state = "Loading"
local muted = false
local controls
local savedCoreGui = {}
local mutedSounds = setmetatable({}, { __mode = "k" })
local connections = {}
local shineTweens = {}
local savedSelection = GuiService.SelectedObject

local function tween(object, duration, properties)
	local animation = TweenService:Create(object,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), properties)
	animation:Play()
	return animation
end

local function setState(nextState)
	state = nextState
	gui:SetAttribute("State", nextState)
end

-- Keep keyboard, controller and touch movement off until Play has finished.
ContextActionService:BindActionAtPriority("GBloxMenuMovement", function()
	return Enum.ContextActionResult.Sink
end, false, 3000, table.unpack(Enum.PlayerActions:GetEnumItems()))

task.spawn(function()
	local playerScripts = player:WaitForChild("PlayerScripts")
	local playerModule = playerScripts:WaitForChild("PlayerModule", 15)
	if playerModule then
		controls = require(playerModule):GetControls()
		if state ~= "Lobby" then
			controls:Disable()
		end
	end
end)

for _, kind in { Enum.CoreGuiType.Backpack, Enum.CoreGuiType.Chat,
	Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.Health } do
	local ok, enabled = pcall(function()
		return StarterGui:GetCoreGuiEnabled(kind)
	end)
	if ok then
		savedCoreGui[kind] = enabled
		pcall(function() StarterGui:SetCoreGuiEnabled(kind, false) end)
	end
end

local function updateLayout()
	local width, height = root.AbsoluteSize.X, root.AbsoluteSize.Y
	if width == 0 or height == 0 then return end
	local scale = math.min(width / 1800, height / 1000)
	local portrait = height > width
	local margin = math.max(16, width * 0.028)
	local titleWidth = portrait and width * 0.60 or 595 * scale
	root.Title.Position = UDim2.fromOffset(margin, math.max(52, 45 * scale))
	root.Title.Size = UDim2.fromOffset(titleWidth, titleWidth * 263 / 595)
	root.SoundButton.Position = UDim2.new(1, -margin, 0, math.max(52, 55 * scale))
	local soundSize = math.clamp(74 * scale, 40, 64)
	root.SoundButton.Size = UDim2.fromOffset(soundSize, soundSize)

	local buttonScale = portrait and math.min(width * 0.80 / 581, height * 0.095 / 136)
		or math.min(width * 0.38 / 581, math.max(scale, 0.35))
	for index, entry in { {main.PlayButton,439,128}, {main.ShopButton,498,136},
		{main.SettingsButton,581,128} } do
		local button, buttonWidth, buttonHeight = table.unpack(entry)
		button.Size = UDim2.fromOffset(buttonWidth * buttonScale, buttonHeight * buttonScale)
		button.Position = UDim2.new(1, -margin, 0,
			portrait and height * 0.48 + (index - 1) * (136 * buttonScale + 16)
			or height * 0.50 + (index - 1) * height * 0.15)
	end
	local platformWidth = portrait and width * 0.95 or 1069 * scale
	main.Platform.Size = UDim2.fromOffset(platformWidth, platformWidth * 591 / 1069)
	main.GroupLogo.Size = UDim2.fromOffset(321 * scale, 192 * scale)
	main.GroupLogo.Position = UDim2.fromScale(0.028, portrait and 0.87 or 0.78)
	loading.LoadingText.Position = UDim2.fromScale(0.06, portrait and 0.70 or 0.66)
	loading.LoadingText.Size = UDim2.fromScale(0.88, portrait and 0.12 or 0.20)
	local barHeight = math.max(32, 89 * scale)
	loading.ProgressBar.Size = UDim2.new(0.954, 0, 0, barHeight)
	local edge = math.max(3, 6 * scale)
	loading.ProgressBar.Inner.Position = UDim2.fromOffset(edge, edge)
	loading.ProgressBar.Inner.Size = UDim2.new(1, -edge * 2, 1, -edge * 2)
	main.Notice.Size = UDim2.fromScale(portrait and 0.92 or 0.5, 0.055)
end
table.insert(connections, root:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateLayout))
updateLayout()

local function playSound(name, pitch)
	if muted then return end
	local sound = sounds:FindFirstChild(name)
	if sound then
		sound:Stop()
		sound.PlaybackSpeed = pitch or 1
		sound.TimePosition = 0
		sound:Play()
	end
end

local function rememberSound(object)
	if muted and object:IsA("Sound") and mutedSounds[object] == nil then
		mutedSounds[object] = object.Volume
		object.Volume = 0
	end
end

local function toggleSound()
	muted = not muted
	gui:SetAttribute("SoundMuted", muted)
	player:SetAttribute("GBloxSoundMuted", muted)
	root.SoundButton.Image = muted and config.Images.SoundOff or config.Images.SoundOn
	if muted then
		for _, container in { workspace, SoundService, playerGui } do
			for _, object in container:GetDescendants() do rememberSound(object) end
		end
	else
		for sound, volume in mutedSounds do
			if sound.Parent then sound.Volume = volume end
		end
		table.clear(mutedSounds)
		playSound("Toggle")
	end
end

-- Keep the mute preference after the menu closes, including newly created sounds.
for _, container in { workspace, SoundService, playerGui } do
	container.DescendantAdded:Connect(rememberSound)
end

local function shine(target)
	local gradient = target.Gloss.Sweep
	if shineTweens[gradient] then shineTweens[gradient]:Cancel() end
	gradient.Offset = Vector2.new(-1.3, 0)
	shineTweens[gradient] = tween(gradient, 0.85, { Offset = Vector2.new(1.3, 0) })
end

local function bindButton(button, hoverPitch, onClick)
	local scale = button.HoverScale
	local hovered = false
	local function hover()
		if state == "Fading" or state == "Lobby" or hovered then return end
		hovered = true
		tween(scale, 0.13, { Scale = 1.035 })
		playSound("Hover", hoverPitch)
		if button:FindFirstChild("Gloss") then shine(button) end
	end
	local function leave()
		hovered = false
		tween(scale, 0.13, { Scale = 1 })
	end
	button.MouseEnter:Connect(hover)
	button.MouseLeave:Connect(leave)
	button.SelectionGained:Connect(hover)
	button.SelectionLost:Connect(leave)
	button.MouseButton1Down:Connect(function()
		tween(scale, 0.07, { Scale = 0.97 })
	end)
	button.MouseButton1Up:Connect(function()
		tween(scale, 0.1, { Scale = hovered and 1.035 or 1 })
	end)
	button.Activated:Connect(function()
		if state == "Fading" or state == "Lobby" then return end
		onClick()
	end)
end

local noticeVersion = 0
local function openPanel(name)
	if state ~= "Menu" then return end
	playSound(name)
	gui["Open"..name]:Fire()
	-- Tomorrow's panels can be placed here without changing the button wiring.
	local panel = main:FindFirstChild(name.."Panel")
	if panel and panel:IsA("GuiObject") then
		panel.Visible = true
		return
	end
	noticeVersion += 1
	local version = noticeVersion
	main.Notice.Text = name.." coming soon"
	task.delay(2, function()
		if version == noticeVersion then main.Notice.Text = "" end
	end)
end

local function enterLobby()
	if state ~= "Menu" then return end
	local remote = ReplicatedStorage:FindFirstChild("GBloxEnterLobby")
	if not remote then
		main.Notice.Text = "Connecting... try Play again"
		return
	end
	setState("Fading")
	playSound("Play")
	GuiService.SelectedObject = nil
	tween(root, config.FadeTime, { GroupTransparency = 1 }).Completed:Wait()
	remote:FireServer()

	-- Wait for the server to release the character before restoring movement.
	local deadline = os.clock() + 8
	while player:GetAttribute("GBloxLobbyReady") ~= true and os.clock() < deadline do
		task.wait(0.05)
	end
	if player:GetAttribute("GBloxLobbyReady") ~= true then
		setState("Menu")
		tween(root, 0.2, { GroupTransparency = 0 })
		main.Notice.Text = "Connection slow. Please try Play again."
		return
	end
	setState("Lobby")
	ContextActionService:UnbindAction("GBloxMenuMovement")
	if controls then controls:Enable() end
	for kind, enabled in savedCoreGui do
		pcall(function() StarterGui:SetCoreGuiEnabled(kind, enabled) end)
	end
	GuiService.SelectedObject = savedSelection
	for _, connection in connections do connection:Disconnect() end
	for _, animation in shineTweens do animation:Cancel() end
	gui.Enabled = false
	root:Destroy()
end

bindButton(main.PlayButton, 1.12, enterLobby)
bindButton(main.ShopButton, 0.98, function() openPanel("Shop") end)
bindButton(main.SettingsButton, 0.86, function() openPanel("Settings") end)
bindButton(root.SoundButton, 1.25, toggleSound)

task.spawn(function()
	while state ~= "Lobby" do
		if state ~= "Fading" then
			shine(root.Title)
			if state == "Menu" then
				for _, button in { main.PlayButton, main.ShopButton, main.SettingsButton } do
					shine(button)
				end
			end
		end
		task.wait(4)
	end
end)

local assets, seen, loaded = {}, {}, {}
local preloadObjects = {}
local preloadFolder = Instance.new("Folder")
preloadFolder.Name = "PreloadAssets"
preloadFolder.Parent = gui
local function addAsset(id)
	if id ~= "" and not seen[id] then
		seen[id] = true
		table.insert(assets, id)
	end
end
for _, imageIds in { config.Images, config.LobbyAssets } do
	for _, id in imageIds do
		addAsset(id)
		local image = Instance.new("ImageLabel")
		image.Image = id
		image.Parent = preloadFolder
		preloadObjects[id] = image
	end
end
for name, id in config.Sounds do
	addAsset(id)
	preloadObjects[id] = sounds[name]
end

local function updateProgress()
	local count = 0
	for _ in loaded do count += 1 end
	local progress = math.min(math.floor(count / #assets * 100), 99)
	percentage.Text = progress.."%"
	gui:SetAttribute("Progress", progress)
	tween(bar, 0.15, { Size = UDim2.fromScale(progress / 100, 1) })
end

local loadingInProgress = false
local function loadAssets()
	if loadingInProgress or state ~= "Loading" then return end
	loadingInProgress = true
	loading.Retry.Visible = false
	loading.LoadingText.Text = "Loading..."
	local pending = {}
	for _, id in assets do
		if not loaded[id] then table.insert(pending, id) end
	end

	local nextAsset, finished = 0, 0
	local workers = {}
	-- A few parallel requests keep loading fast without guessing a percentage.
	for _ = 1, math.min(4, #pending) do
		table.insert(workers, task.spawn(function()
			while true do
				nextAsset += 1
				local id = pending[nextAsset]
				if not id then return end
				for attempt = 1, 2 do
					local success = false
					local ok = pcall(function()
						ContentProvider:PreloadAsync({ preloadObjects[id] }, function(_, status)
							success = status == Enum.AssetFetchStatus.Success
						end)
					end)
					if ok and success then
						loaded[id] = true
						break
					end
					if attempt == 1 then task.wait(0.5) end
				end
				finished += 1
				updateProgress()
			end
		end))
	end

	local deadline = os.clock() + 45
	while finished < #pending and os.clock() < deadline do task.wait(0.1) end
	for _, worker in workers do
		if coroutine.status(worker) ~= "dead" then task.cancel(worker) end
	end

	local failed = {}
	for _, id in assets do
		if not loaded[id] then table.insert(failed, id) end
	end
	gui:SetAttribute("FailedAssets", table.concat(failed, ", "))
	if #failed > 0 then
		loading.LoadingText.Text = "Load interrupted"
		loading.Retry.Visible = true
		loadingInProgress = false
		warn("[G-Blox menu] Couldn't load: "..table.concat(failed, ", "))
		return
	end

	deadline = os.clock() + 30
	while not game:IsLoaded() and os.clock() < deadline do task.wait(0.1) end
	local character = player.Character
	while not character and os.clock() < deadline do
		task.wait(0.1)
		character = player.Character
	end
	local characterRoot = character and character:WaitForChild("HumanoidRootPart", 10)
	if not game:IsLoaded() or not characterRoot then
		loading.LoadingText.Text = "Waiting for lobby"
		loading.Retry.Visible = true
		loadingInProgress = false
		return
	end
	if workspace.StreamingEnabled then
		local ok = pcall(function()
			player:RequestStreamAroundAsync(characterRoot.Position, 10)
		end)
		if not ok then
			loading.LoadingText.Text = "Waiting for lobby"
			loading.Retry.Visible = true
			loadingInProgress = false
			return
		end
	end

	percentage.Text = "100%"
	gui:SetAttribute("Progress", 100)
	tween(bar, 0.18, { Size = UDim2.fromScale(1, 1) }).Completed:Wait()
	task.wait(0.35)
	preloadFolder:Destroy()
	loading.Visible = false
	main.Visible = true
	setState("Menu")
	if UserInputService.GamepadEnabled then GuiService.SelectedObject = main.PlayButton end
	shine(main.PlayButton)
	loadingInProgress = false
end

loading.Retry.Activated:Connect(loadAssets)
task.spawn(loadAssets)
