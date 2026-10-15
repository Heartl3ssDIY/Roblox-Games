local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local StarterGui = game:GetService("StarterGui")
local SoundService = game:GetService("SoundService")

local config = require(script:WaitForChild("LoadingConfig"))
if game.PlaceId ~= config.PlaceId then return end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local gui = script:WaitForChild("GBloxCourseLoadingScreen"):Clone()
gui.Parent = playerGui
ReplicatedFirst:RemoveDefaultLoadingScreen()

local root = gui.Root
local loading = root.LoadingScreen
local bar = loading.ProgressBar.Inner.Fill
local percentage = loading.ProgressBar.Inner.Percentage
local sounds = gui.Sounds
local state = "Loading"
local controls
local savedCoreGui = {}
local muted = false
local mutedSounds = setmetatable({}, { __mode = "k" })

local function tween(object, duration, properties)
	local animation = TweenService:Create(object,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), properties)
	animation:Play()
	return animation
end

local function setState(value)
	state = value
	gui:SetAttribute("State", value)
end

ContextActionService:BindActionAtPriority("GBloxCourseLoadingMovement", function()
	return Enum.ContextActionResult.Sink
end, false, 3000, table.unpack(Enum.PlayerActions:GetEnumItems()))

task.spawn(function()
	local playerScripts = player:WaitForChild("PlayerScripts")
	local playerModule = playerScripts:WaitForChild("PlayerModule", 15)
	if playerModule then
		controls = require(playerModule):GetControls()
		if state ~= "Playing" then controls:Disable() end
	end
end)

for _, kind in { Enum.CoreGuiType.Backpack, Enum.CoreGuiType.Chat,
	Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.Health } do
	local ok, enabled = pcall(function() return StarterGui:GetCoreGuiEnabled(kind) end)
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
	loading.LoadingText.Position = UDim2.fromScale(0.06, portrait and 0.70 or 0.66)
	loading.LoadingText.Size = UDim2.fromScale(0.88, portrait and 0.12 or 0.20)
	loading.ProgressBar.Size = UDim2.new(0.954, 0, 0, math.max(32, 89 * scale))
	local edge = math.max(3, 6 * scale)
	loading.ProgressBar.Inner.Position = UDim2.fromOffset(edge, edge)
	loading.ProgressBar.Inner.Size = UDim2.new(1, -edge * 2, 1, -edge * 2)
end
local layoutConnection = root:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateLayout)
updateLayout()

local function playSound(name)
	if muted then return end
	local sound = sounds[name]
	sound:Stop()
	sound.TimePosition = 0
	sound:Play()
end

local function rememberSound(object)
	if muted and object:IsA("Sound") and mutedSounds[object] == nil then
		mutedSounds[object] = object.Volume
		object.Volume = 0
	end
end

root.SoundButton.Activated:Connect(function()
	if state == "Fading" then return end
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
end)
root.SoundButton.MouseEnter:Connect(function()
	playSound("Hover")
	tween(root.SoundButton.HoverScale, 0.13, { Scale = 1.035 })
end)
root.SoundButton.MouseLeave:Connect(function()
	tween(root.SoundButton.HoverScale, 0.13, { Scale = 1 })
end)
-- The preference also applies to sounds created after loading.
for _, container in { workspace, SoundService, playerGui } do
	container.DescendantAdded:Connect(rememberSound)
end

local shineTween
task.spawn(function()
	while state ~= "Playing" do
		if state ~= "Fading" then
			local sweep = root.Title.Gloss.Sweep
			sweep.Offset = Vector2.new(-1.3, 0)
			shineTween = tween(sweep, 0.85, { Offset = Vector2.new(1.3, 0) })
		end
		task.wait(4)
	end
end)

local assets, seen, loaded = {}, {}, {}
local preloadFolder = Instance.new("Folder")
preloadFolder.Name = "PreloadAssets"
preloadFolder.Parent = gui

local function addAsset(kind, id)
	if not id or id == "" then return end
	local key = kind..":"..id
	if seen[key] then return end
	seen[key] = true

	-- Use an object of the correct type so Roblox loads the right content.
	local object
	if kind == "Mesh" then
		object = Instance.new("SpecialMesh")
		object.MeshType = Enum.MeshType.FileMesh
		object.MeshId = id
	elseif kind == "Sound" then
		object = Instance.new("Sound")
		object.SoundId = id
	elseif kind == "Animation" then
		object = Instance.new("Animation")
		object.AnimationId = id
	else
		object = Instance.new("ImageLabel")
		object.Image = id
	end
	object.Parent = preloadFolder
	table.insert(assets, { key = key, id = id, object = object })
end

for _, id in config.Images do addAsset("Image", id) end
for _, id in config.Sounds do addAsset("Sound", id) end
for _, asset in config.CourseAssets do addAsset(asset.kind, asset.id) end

local function updateProgress()
	local count = 0
	for _ in loaded do count += 1 end
	local progress = math.min(math.floor(count / #assets * 100), 99)
	percentage.Text = progress.."%"
	gui:SetAttribute("Progress", progress)
	tween(bar, 0.15, { Size = UDim2.fromScale(progress / 100, 1) })
end

local function showRetry(message)
	loading.LoadingText.Text = message
	loading.Retry.Visible = true
	setState("Loading")
end

local function finishLoading()
	local remote = ReplicatedStorage:WaitForChild("GBloxCourseLoaded", 10)
	if not remote then
		showRetry("Connecting...")
		return
	end
	percentage.Text = "100%"
	gui:SetAttribute("Progress", 100)
	tween(bar, 0.18, { Size = UDim2.fromScale(1, 1) }).Completed:Wait()
	task.wait(0.35)
	setState("Fading")
	tween(root, config.FadeTime, { GroupTransparency = 1 }).Completed:Wait()
	remote:FireServer()

	local deadline = os.clock() + 8
	while player:GetAttribute("GBloxCourseReady") ~= true and os.clock() < deadline do
		task.wait(0.05)
	end
	if player:GetAttribute("GBloxCourseReady") ~= true then
		tween(root, 0.2, { GroupTransparency = 0 })
		showRetry("Connecting...")
		return
	end

	setState("Playing")
	ContextActionService:UnbindAction("GBloxCourseLoadingMovement")
	if controls then controls:Enable() end
	for kind, enabled in savedCoreGui do
		pcall(function() StarterGui:SetCoreGuiEnabled(kind, enabled) end)
	end
	layoutConnection:Disconnect()
	if shineTween then shineTween:Cancel() end
	preloadFolder:Destroy()
	gui.Enabled = false
	root:Destroy()
end

local loadingInProgress = false
local function loadCourse()
	if loadingInProgress or state ~= "Loading" then return end
	loadingInProgress = true
	loading.Retry.Visible = false
	loading.LoadingText.Text = "Loading..."

	local pending = {}
	for _, asset in assets do
		if not loaded[asset.key] then table.insert(pending, asset) end
	end
	local nextAsset, finished = 0, 0
	local workers = {}
	for _ = 1, math.min(4, #pending) do
		table.insert(workers, task.spawn(function()
			while true do
				nextAsset += 1
				local asset = pending[nextAsset]
				if not asset then return end
				for attempt = 1, 2 do
					local success = false
					local ok = pcall(function()
						ContentProvider:PreloadAsync({ asset.object }, function(_, status)
							success = status == Enum.AssetFetchStatus.Success
						end)
					end)
					if ok and success then
						loaded[asset.key] = true
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
	for _, asset in assets do
		if not loaded[asset.key] then table.insert(failed, asset.id) end
	end
	gui:SetAttribute("FailedAssets", table.concat(failed, ", "))
	if #failed > 0 then
		warn("[Course loading] Couldn't load: "..table.concat(failed, ", "))
		showRetry("Load interrupted")
		loadingInProgress = false
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
		showRetry("Waiting for course")
		loadingInProgress = false
		return
	end
	if workspace.StreamingEnabled then
		local ok = pcall(function()
			player:RequestStreamAroundAsync(characterRoot.Position, 10)
		end)
		if not ok then
			showRetry("Waiting for course")
			loadingInProgress = false
			return
		end
	end
	finishLoading()
	loadingInProgress = false
end

loading.Retry.Activated:Connect(loadCourse)
task.spawn(loadCourse)

