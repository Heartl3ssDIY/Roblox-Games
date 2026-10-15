from pathlib import Path
import json
root=Path('PhoneHudRepair20261009/Session')
old=(root/'Before/PlaygroundSessionControls.luau').read_text()
source=old.replace('local roundToggle = gui:WaitForChild("RoundToggle")','local roundToggle = gui:WaitForChild("RoundToggle")\nlocal compactToggle = gui:WaitForChild("CompactToggle")\nlocal portraitToggle = gui:WaitForChild("PortraitToggle")')
source=source.replace('local watchButton = gui:WaitForChild("Spectate")','local watchButton = gui:WaitForChild("Spectate")\nlocal compactWatch = gui:WaitForChild("CompactSpectate")\nlocal portraitWatch = gui:WaitForChild("PortraitSpectate")\nlocal settingsLaunchers = { toggle, compactToggle, portraitToggle }\nlocal watchLaunchers = { watchButton, compactWatch, portraitWatch }')
source=source.replace('local function gamepadActive()', '''local function compactLayout()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	local short = math.min(viewport.X, viewport.Y)
	local long = math.max(viewport.X, viewport.Y)
	return viewport.X <= 900 or short <= 600 or (short <= 1024 and long <= 1400), viewport.Y > viewport.X
end

local function gamepadActive()''')
source=source.replace('toggle.Visible = gui.Enabled and not modal and not participating','''local compact, portrait = compactLayout()
	local showSettings = gui.Enabled and not modal and not participating
	toggle.Visible = showSettings and not compact
	compactToggle.Visible = showSettings and compact and not portrait
	portraitToggle.Visible = showSettings and compact and portrait''')
source=source.replace('buttonState(toggle, true)','for _, launcher in ipairs(settingsLaunchers) do buttonState(launcher, true) end')
source=source.replace('''watchButton.Visible = gui.Enabled and not modal and not participating and not menuOpen
	watchButton.Label.Text = watching and "STOP WATCHING" or "SPECTATE"
	buttonState(watchButton, watching or (gameId ~= nil and #targetsFor(gameId) > 0))''','''local showWatch = gui.Enabled and not modal and not participating and not menuOpen
	watchButton.Visible = showWatch and not compact
	compactWatch.Visible = showWatch and compact and not portrait
	portraitWatch.Visible = showWatch and compact and portrait
	local canWatch = watching or (gameId ~= nil and #targetsFor(gameId) > 0)
	for _, launcher in ipairs(watchLaunchers) do
		launcher.Label.Text = watching and "STOP" or "SPECTATE"
		buttonState(launcher, canWatch)
	end
	watchButton.Label.Text = watching and "STOP WATCHING" or "SPECTATE"''')
source=source.replace('connect(toggle.Activated, toggleSettings)','for _, launcher in ipairs(settingsLaunchers) do connect(launcher.Activated, toggleSettings) end')
source=source.replace('''connect(watchButton.Activated, function()
	if watching then exitSpectate() refresh() else startSpectate() end
end)''','''for _, launcher in ipairs(watchLaunchers) do
	connect(launcher.Activated, function()
		if watching then exitSpectate() refresh() else startSpectate() end
	end)
end''')
assert source!=old
(root/'PlaygroundSessionControls.luau').write_text(source)
old=(root/'Before/PlaygroundEmoteWheel.luau').read_text()
source=old.replace('local toggle = gui:WaitForChild("Toggle")','local toggle = gui:WaitForChild("Toggle")\nlocal compactToggle = gui:WaitForChild("CompactEmoteToggle")\nlocal portraitToggle = gui:WaitForChild("PortraitEmoteToggle")\nlocal launchers = { toggle, compactToggle, portraitToggle }')
source=source.replace('if not catalogObject then toggle.Visible = false return end','if not catalogObject then for _, launcher in ipairs(launchers) do launcher.Visible = false end return end')
source=source.replace('local function gamepadActive()', '''local function compactLayout()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	local short = math.min(viewport.X, viewport.Y)
	local long = math.max(viewport.X, viewport.Y)
	return viewport.X <= 900 or short <= 600 or (short <= 1024 and long <= 1400), viewport.Y > viewport.X
end

local function gamepadActive()''')
source=source.replace('connect(toggle.Activated, function() setOpen(not panel.Visible) end)','for _, launcher in ipairs(launchers) do connect(launcher.Activated, function() setOpen(not panel.Visible) end) end')
source=source.replace('''    toggle.Visible = not blocked and not panel.Visible''','''    local compact, portrait = compactLayout()
    local show = not blocked and not panel.Visible
    toggle.Visible = show and not compact
    compactToggle.Visible = show and compact and not portrait
    portraitToggle.Visible = show and compact and portrait''')
assert source!=old
(root/'PlaygroundEmoteWheel.luau').write_text(source)
def quote(text):
    for count in range(8):
        d='='*count
        if ']'+d+']' not in text:
            return '['+d+'['+text+']'+d+']'
    raise Exception()
sources='{'+','.join('['+json.dumps(n)+']={before='+quote((root/'Before'/f'{n}.luau').read_text())+',after='+quote((root/f'{n}.luau').read_text())+'}' for n in ['PlaygroundSessionControls','PlaygroundEmoteWheel'])+'}'
installer='''assert(not game:GetService("RunService"):IsRunning(), "Stop Play before applying the authored HUD repair")
assert(game.PlaceId == 95034648955135, "Unexpected place")
local StarterGui = game:GetService("StarterGui")
local ServerStorage = game:GetService("ServerStorage")
local sources = SOURCES
for name, record in pairs(sources) do
	local gui = assert(StarterGui:FindFirstChild(name), name .. " missing")
	assert(gui.Controller.Source == record.before, name .. " controller changed; refresh the patch")
end
local backupName = "PhoneHudSessionBackup20261009"
assert(not ServerStorage:FindFirstChild(backupName), "HUD backup already exists")
local backup = Instance.new("Folder")
backup.Name = backupName
backup.Parent = ServerStorage
for name in pairs(sources) do StarterGui[name]:Clone().Parent = backup end
local session = StarterGui.PlaygroundSessionControls
local emotes = StarterGui.PlaygroundEmoteWheel
local function icon(target)
	target.Size = UDim2.fromOffset(44, 44)
	target.BackgroundTransparency = 1
	target.ReusableSkin.AnchorPoint = Vector2.new(0.5, 0)
	target.ReusableSkin.Position = UDim2.new(0.5, 0, 0, 0)
	target.ReusableSkin.Size = UDim2.fromOffset(32, 32)
	target.Label.AnchorPoint = Vector2.zero
	target.Label.Position = UDim2.fromOffset(0, 32)
	target.Label.Size = UDim2.fromOffset(44, 12)
	target.Label.TextScaled = true
	target.Label.TextWrapped = false
	for _, c in target.Label:GetChildren() do
		if c:IsA("UITextSizeConstraint") then c.MinTextSize = 8 c.MaxTextSize = 10 end
	end
	target:SetAttribute("PlacementNote", "Authored compact launcher with 44-pixel touch target")
end
local function addIcon(template, name, position, anchor)
	assert(not session:FindFirstChild(name), name .. " already exists")
	local button = template:Clone()
	button.Name = name
	button.AnchorPoint = anchor or Vector2.zero
	button.Position = position
	icon(button)
	button.Visible = false
	button.Parent = session
	return button
end
addIcon(session.Toggle, "CompactToggle", UDim2.fromOffset(8, 62))
addIcon(session.Spectate, "CompactSpectate", UDim2.fromOffset(60, 62))
addIcon(session.Toggle, "PortraitToggle", UDim2.new(0.5, -92, 0, 112))
addIcon(session.Spectate, "PortraitSpectate", UDim2.new(0.5, -40, 0, 112))
session.Toggle.Position = UDim2.fromOffset(18, 70)
session.Spectate.Position = UDim2.fromOffset(74, 70)
session.RoundToggle.Position = UDim2.new(1, -8, 0, 48)
icon(session.RoundToggle)
local function addEmote(name, position, anchor)
	assert(not emotes:FindFirstChild(name), name .. " already exists")
	local button = emotes.Toggle:Clone()
	button.Name = name
	button.AnchorPoint = anchor
	button.Position = position
	button.Size = UDim2.fromOffset(80, 44)
	local limit = button:FindFirstChild("MinimumHitSize")
	if limit then limit.MinSize = Vector2.new(80, 44) limit.MaxSize = Vector2.new(80, 44) end
	button.LiveCaption.Text = "EMOTES"
	button.LiveCaption.Position = UDim2.new(0.06, 0, 0.16, 0)
	button.LiveCaption.Size = UDim2.new(0.88, 0, 0.64, 0)
	for _, c in button.LiveCaption:GetChildren() do
		if c:IsA("UITextSizeConstraint") then c.MinTextSize = 10 c.MaxTextSize = 15 end
	end
	button.Visible = false
	button:SetAttribute("PlacementNote", "Authored compact launcher with 44-pixel touch target")
	button.Parent = emotes
end
addEmote("CompactEmoteToggle", UDim2.new(1, -8, 0, 62), Vector2.new(1, 0))
addEmote("PortraitEmoteToggle", UDim2.new(0.5, 12, 0, 112), Vector2.zero)
emotes.Toggle.Position = UDim2.new(0, 18, 1, -194)
emotes.Toggle.Size = UDim2.fromOffset(140, 48)
for name, record in pairs(sources) do StarterGui[name].Controller.Source = record.after end
return {ok=true,backup=backup:GetFullName(),launchers=6}
'''.replace('SOURCES',sources)
(root/'Install.luau').write_text(installer)

