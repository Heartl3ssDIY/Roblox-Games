assert(not game.RunService:IsRunning(), "Edit mode required")
local starter = game.StarterGui
local controller = starter.PlaygroundShell.Controller
assert(controller.Source == before, "Shell controller changed since snapshot")
local wallet = starter.PlaygroundShell.Wallet
local emotes = starter.PlaygroundEmoteWheel.Toggle
assert(wallet.AnchorPoint == Vector2.zero and wallet.Size == UDim2.fromOffset(190, 56), "Wallet layout changed")
assert(emotes.AnchorPoint == Vector2.new(1, 1) and emotes.Size == UDim2.fromOffset(140, 38), "Emote toggle layout changed")
assert(wallet.Position == UDim2.new(0.881188095, 0, 0.0333333351, 0), "Wallet position changed")
assert(emotes.Position == UDim2.new(0.181684986, -18, 0.971354187, -160), "Emote position changed")
local specs = {
	{ starter.PlaygroundShell.Wallet, 0.82, 0.9 },
	{ starter.PlaygroundShell.LevelPanel, 0.75, 0.9 },
	{ starter.BritishBulldogHUD.TopCard, 0.85, 0.9 },
	{ starter.TagHUD.Top, 0.85, 0.9 },
	{ starter.BritishBulldogHUD.MovementControls, 0.94, 0.94 },
	{ starter.TagHUD.SprintPanel, 0.94, 0.94 },
	{ starter.MudHUD.Main.Controls, 0.94, 0.94 },
}
for _, spec in ipairs(specs) do assert(not spec[1]:FindFirstChildOfClass("UIScale"), "Existing scale on " .. spec[1]:GetFullName()) end
assert(not game.ServerStorage:FindFirstChild("SmallHudBackup20261007"), "HUD patch already installed")
local backup = Instance.new("Folder")
backup.Name = "SmallHudBackup20261007"
local oldController = controller:Clone()
oldController.Name = "ShellController"
oldController.Parent = backup
local oldWallet = wallet:Clone()
oldWallet.Name = "Wallet"
oldWallet.Parent = backup
local oldToggle = emotes:Clone()
oldToggle.Name = "EmoteToggle"
oldToggle.Parent = backup
backup.Parent = game.ServerStorage
for _, spec in ipairs(specs) do
	local scale = Instance.new("UIScale")
	scale.Name = "ResponsiveHudScale"
	scale.Scale = 1
	scale:SetAttribute("PhoneScale", spec[2])
	scale:SetAttribute("TabletScale", spec[3])
	scale:SetAttribute("DesktopScale", 1)
	scale.Parent = spec[1]
end
wallet.AnchorPoint = Vector2.new(1, 0)
wallet.Position = UDim2.new(1, -18, 0, 18)
emotes.AnchorPoint = Vector2.new(0, 1)
emotes.Position = UDim2.new(0, 18, 1, -194)
emotes.Size = UDim2.fromOffset(140, 48)
controller.Source = after
assert(controller.Source == after, "Source write mismatch")
game:GetService("ChangeHistoryService"):SetWaypoint("Small phone and tablet HUD pass")
return game.HttpService:JSONEncode({applied=true,scales=#specs,backup=backup:GetFullName(),play=game.RunService:IsRunning()})
