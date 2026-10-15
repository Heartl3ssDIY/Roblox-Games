local checks = 0
local function check(value, message)
	assert(value, message)
	checks += 1
end
local sourceGui = game.StarterGui.PlaygroundFishingHUD
local fixture = Instance.new("Folder")
fixture.Name = "FishingHUDChecks_20261007"
fixture.Parent = game.ServerStorage
local ok, result = pcall(function()
	local gui = sourceGui:Clone()
	gui.Parent = fixture
	local session = Instance.new("ScreenGui")
	session.Name = "PlaygroundSessionControls"
	session.Parent = fixture
	local shell = Instance.new("ScreenGui")
	shell.Name = "PlaygroundShell"
	shell.Parent = fixture
	local shop = Instance.new("Frame")
	shop.Name = "ShopPanel"
	shop.Visible = false
	shop.Parent = shell
	local player = Instance.new("Folder")
	player.Parent = fixture
	local heartbeat = Instance.new("BindableEvent")
	heartbeat.Parent = fixture
	local controller = gui.Controller
	local module = game.ServerScriptService.PlaygroundToyService:Clone()
	module:ClearAllChildren()
	module.Name = "HUDCheckModule"
	module.Source = "return function(game, workspace, script)\n" .. controller.Source .. "\nend"
	module.Parent = fixture
	local input = { TouchEnabled = false }
	local services = { Players = { LocalPlayer = player }, RunService = { Heartbeat = heartbeat.Event }, UserInputService = input }
	local now = 1000
	local fakeWorkspace = { CurrentCamera = { ViewportSize = Vector2.new(1920, 1080) }, GetServerTimeNow = function() return now end }
	local fakeGame = { GetService = function(_, name) return assert(services[name], name) end }
	require(module)(fakeGame, fakeWorkspace, controller)
	local function step() heartbeat:Fire(0.26) task.wait() end
	check(not gui.DesktopDock.Coins.Visible and not gui.DesktopDock.XP.Visible, "Inactive boosts must hide")
	player:SetAttribute("PCFishingCoinsExpires", 1300)
	step()
	check(gui.DesktopDock.Visible and gui.DesktopDock.Coins.Visible, "Coins timer appears on desktop")
	check(gui.DesktopDock.Coins.Timer.Text == "5:00", "Five-minute countdown")
	check(not gui.DesktopDock.XP.Visible, "Independent XP state")
	player:SetAttribute("PCFishingCoinsExpires", 1600)
	player:SetAttribute("PCFishingXPExpires", 1300)
	step()
	check(gui.DesktopDock.Coins.Timer.Text == "10:00", "Stacked minutes are shown")
	check(gui.DesktopDock.XP.Timer.Text == "5:00", "Both boosts display independently")
	now = 1300
	step()
	check(not gui.DesktopDock.XP.Visible and gui.DesktopDock.Coins.Timer.Text == "5:00", "Expired XP hides while coins continue")
	input.TouchEnabled = true
	step()
	check(gui.CompactDock.Visible and not gui.DesktopDock.Visible, "Touch switches authored layouts")
	check(gui.CompactDock.Coins.Timer.Text == "5:00", "Compact timer stays synchronized")
	session:SetAttribute("UIHidden", true)
	step()
	check(not gui.CompactDock.Visible and not gui.DesktopDock.Visible, "Hide UI hides boost dock")
	session:SetAttribute("UIHidden", false)
	shop.Visible = true
	step()
	check(not gui.CompactDock.Visible, "Shop modal hides boost dock")
	shop.Visible = false
	step()
	check(gui.CompactDock.Visible, "Closing shop restores active boosts")
	now = 1600
	step()
	check(not gui.CompactDock.Coins.Visible and not gui.CompactDock.XP.Visible, "Both boost icons clear at expiry")
	check(not string.find(controller.Source, "%.Position%s*="), "Runtime must not overwrite authored positions")
	check(not string.find(controller.Source, "%.Size%s*="), "Runtime must not overwrite authored sizes")
	controller:Destroy()
	return checks
end)
fixture:Destroy()
assert(ok, result)
return { passed = true, checks = result }
