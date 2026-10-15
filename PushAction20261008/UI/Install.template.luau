assert(not game:GetService("RunService"):IsRunning(), "Edit only")
assert(game.GameId == 10769034155, "Wrong experience")
local starterGui = game:GetService("StarterGui")
local tagPanel = assert(starterGui:FindFirstChild("TagHUD")).SprintPanel
local bulldogPanel = assert(starterGui:FindFirstChild("BritishBulldogHUD")).MovementControls
local template = assert(starterGui:FindFirstChild("PlaygroundBatControls")).Swing
assert(not starterGui:FindFirstChild("PlaygroundPushControls"), "Push UI already installed")
assert(not tagPanel:FindFirstChild("Push") and not bulldogPanel:FindFirstChild("Push"), "Push slot already occupied")
assert(not starterGui.TagHUD.Controls:FindFirstChild("Vault"), "Vault has unexpectedly returned; review before replacing")
assert(not bulldogPanel.Dodge.Visible and not starterGui.TagHUD.Controls.Dodge.Visible, "Dodge visibility changed; review first")
assert(template.ReusableSkin.Image == "rbxassetid://84589903135132", "Reusable artwork changed")
local backup = Instance.new("Folder")
backup.Name = "PushUiBackup20261008"
assert(not game.ServerStorage:FindFirstChild(backup.Name), "UI backup already exists")
for name, object in { TagSprintPanel = tagPanel, BulldogMovementControls = bulldogPanel, SwingTemplate = template } do
	local copy = object:Clone()
	copy.Name = name
	copy.Parent = backup
end
backup:SetAttribute("CreatedAt", DateTime.now().UnixTimestamp)
backup.Parent = game.ServerStorage
local gui = Instance.new("ScreenGui")
gui.Name = "PlaygroundPushControls"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 23
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = true
local made
local ok, failure = xpcall(function()
	gui.Parent = starterGui
	local build = (function()
__BUILD__
	end)()
	made = build(starterGui)
	local controller = Instance.new("LocalScript")
	controller.Name = "Controller"
	controller.Sandboxed = true
	controller.Capabilities = SecurityCapabilities.new(
		Enum.SecurityCapability.RunClientScript, Enum.SecurityCapability.Basic,
		Enum.SecurityCapability.Players, Enum.SecurityCapability.Input, Enum.SecurityCapability.UI,
		Enum.SecurityCapability.Physics, Enum.SecurityCapability.RemoteEvent, Enum.SecurityCapability.AccessOutsideWrite,
		Enum.SecurityCapability.AvatarBehavior)
	controller.Source = [======[__CONTROLLER__]======]
	controller.Parent = gui
end, debug.traceback)
if not ok then
	for _, panel in { tagPanel, bulldogPanel } do
		local button = panel:FindFirstChild("Push")
		if button and button:GetAttribute("PlaygroundPushAction") == true then button:Destroy() end
	end
	gui:Destroy()
	error(failure)
end
return { gui=gui:GetFullName(), tag=made.Tag:GetFullName(), bulldog=made.Bulldog:GetFullName(), mobile=made.Mobile:GetFullName(), backup=backup:GetFullName() }
