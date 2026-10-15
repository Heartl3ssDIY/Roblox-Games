assert(not game:GetService("RunService"):IsRunning())
local StarterGui = game:GetService("StarterGui")
local ServerStorage = game:GetService("ServerStorage")
local session = StarterGui.PlaygroundSessionControls
local emotes = StarterGui.PlaygroundEmoteWheel
local function section(source, first, last)
	local startAt = assert(string.find(source, first, 1, true))
	local endAt = assert(string.find(source, last, startAt, true))
	return string.sub(source, startAt, endAt - 1)
end
local helper = section(session.Controller.Source, "local function compactLayout()", "local function gamepadActive()")
local settingsBlock = section(session.Controller.Source, "\tlocal compact, portrait = compactLayout()", "\troundToggle.Visible =")
local watchBlock = section(session.Controller.Source, "\tlocal showWatch =", "\tif os.clock() >= noticeUntil")
local available = section(emotes.Controller.Source, "local function refreshAvailability()", "local spectatorConnection")
local test = Instance.new("ModuleScript")
test.Name = "CompactLauncherNativeFixture"
test.Capabilities = session.Controller.Capabilities
test.Source = "return function(workspace, gui, modal, participating, menuOpen, watching, gameId)\n"
	.. helper .. [[
local toggle, compactToggle, portraitToggle = gui.Toggle, gui.CompactToggle, gui.PortraitToggle
local watchButton, compactWatch, portraitWatch = gui.Spectate, gui.CompactSpectate, gui.PortraitSpectate
local watchLaunchers = { watchButton, compactWatch, portraitWatch }
local function targetsFor() return { true } end
local function buttonState(button, enabled) button.Active = enabled end
]]
	.. settingsBlock .. watchBlock .. "return compact, portrait\nend"
test.Parent = ServerStorage
local emoteTest = Instance.new("ModuleScript")
emoteTest.Name = "CompactEmoteNativeFixture"
emoteTest.Capabilities = emotes.Controller.Capabilities
emoteTest.Source = "return function(workspace, gui, participating, modal, opened)\n"
	.. helper .. [[
local toggle, compactToggle, portraitToggle = gui.Toggle, gui.CompactEmoteToggle, gui.PortraitEmoteToggle
local panel = gui.Panel
panel.Visible = opened
local function inRound() return participating end
local function otherModalOpen() return modal end
local function setOpen(show) panel.Visible = show end
]] .. available .. "\nrefreshAvailability()\nreturn compactLayout()\nend"
emoteTest.Parent = ServerStorage
local testSession, testEmotes = require(test), require(emoteTest)
local clonedSession, clonedEmotes = session:Clone(), emotes:Clone()
clonedSession.Parent = ServerStorage
clonedEmotes.Parent = ServerStorage
local checks = 0
local function check(value, message) checks += 1 assert(value, message) end
local function visibleOnly(gui, names, expected)
	for index, name in names do check(gui[name].Visible == (index == expected), name .. " incorrect variant") end
end
local positions = {}
for _, gui in { clonedSession, clonedEmotes } do
	for _, x in gui:GetChildren() do
		if x:IsA("GuiObject") then positions[x] = { x.Position, x.Size } end
	end
end
local ok, result = pcall(function()
	for _, case in {
		{Vector2.new(852, 393), true, false}, {Vector2.new(667, 375), true, false},
		{Vector2.new(390, 844), true, true}, {Vector2.new(320, 568), true, true},
		{Vector2.new(1180, 820), true, false}, {Vector2.new(768, 1024), true, true},
		{Vector2.new(1920, 1080), false, false},
	} do
		local mockedWorkspace = { CurrentCamera = { ViewportSize = case[1] } }
		local compact, portrait = testSession(mockedWorkspace, clonedSession, false, false, false, false, "TagYoureIt")
		check(compact == case[2] and portrait == case[3], "Incorrect responsive profile")
		local expected = not compact and 1 or portrait and 3 or 2
		visibleOnly(clonedSession, {"Toggle", "CompactToggle", "PortraitToggle"}, expected)
		visibleOnly(clonedSession, {"Spectate", "CompactSpectate", "PortraitSpectate"}, expected)
		testEmotes(mockedWorkspace, clonedEmotes, false, false, false)
		visibleOnly(clonedEmotes, {"Toggle", "CompactEmoteToggle", "PortraitEmoteToggle"}, expected)
		testSession(mockedWorkspace, clonedSession, false, true, false, false, nil)
		visibleOnly(clonedSession, {"Toggle", "CompactToggle", "PortraitToggle"}, 0)
		visibleOnly(clonedSession, {"Spectate", "CompactSpectate", "PortraitSpectate"}, 0)
		testEmotes(mockedWorkspace, clonedEmotes, true, false, false)
		visibleOnly(clonedEmotes, {"Toggle", "CompactEmoteToggle", "PortraitEmoteToggle"}, 0)
		testSession(mockedWorkspace, clonedSession, true, false, false, false, nil)
		visibleOnly(clonedSession, {"Toggle", "CompactToggle", "PortraitToggle"}, 0)
		visibleOnly(clonedSession, {"Spectate", "CompactSpectate", "PortraitSpectate"}, 0)
		testEmotes(mockedWorkspace, clonedEmotes, false, true, false)
		visibleOnly(clonedEmotes, {"Toggle", "CompactEmoteToggle", "PortraitEmoteToggle"}, 0)
	end
	for x, geometry in pairs(positions) do
		check(x.Position == geometry[1] and x.Size == geometry[2], x.Name .. " geometry changed at runtime")
	end
	check(string.find(session.Controller.Source, 'for _, launcher in ipairs(settingsLaunchers) do connect(launcher.Activated, toggleSettings) end', 1, true) ~= nil, "Settings bindings missing")
	check(string.find(session.Controller.Source, 'connect(launcher.Activated, function()', 1, true) ~= nil, "Spectate bindings missing")
	check(string.find(emotes.Controller.Source, 'for _, launcher in ipairs(launchers) do connect(launcher.Activated, function() setOpen(not panel.Visible) end) end', 1, true) ~= nil, "Emote bindings missing")
	return {ok=true,checks=checks,profiles=7,runtimeGeometryChanged=false}
end)
clonedSession:Destroy() clonedEmotes:Destroy() test:Destroy() emoteTest:Destroy()
assert(ok, result)
return result

