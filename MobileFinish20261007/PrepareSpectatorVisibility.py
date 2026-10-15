import json
from pathlib import Path

root = Path(__file__).resolve().parent
before = json.loads((root / 'SpectatorVisibilityBefore.json').read_text(encoding='utf-8'))
after = dict(before)
helper = '''local function spectating()
    local controls = player.PlayerGui:FindFirstChild("PlaygroundSessionControls")
    return controls and controls:GetAttribute("Spectating") == true
end

'''
shell = after['Shell']
shell = shell.replace('local function refreshHudScale()', helper + 'local function refreshHudScale()', 1)
shell = shell.replace('local function setShop(visible)\n', 'local function setShop(visible)\n\tif visible and spectating() then return end\n',1)
shell = shell.replace(' dock.Visible=not participating', ' dock.Visible=not participating and not spectating()',1)
shell = shell.replace(' if participating and shop.Visible then', ' if (participating or spectating()) and shop.Visible then',1)
shell = shell.replace(' local showVote=not participating and insideZone', ' local showVote=not participating and not spectating() and insideZone',1)
shell = shell.replace('local elapsed=0\nRunService.Heartbeat:Connect(function(delta)', '''local function refreshSpectatorVisibility()
    local watching = spectating()
    local participating = player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true or player:GetAttribute("MDParticipating") == true
    dock.Visible = not participating and not watching
    if watching then
        setShop(false)
        vote.Visible = false
        compactVote.Visible = false
    end
end
local spectatorConnection
local function bindSpectatorControls(controls)
    if controls.Name ~= "PlaygroundSessionControls" then return end
    if spectatorConnection then spectatorConnection:Disconnect() end
    spectatorConnection = controls:GetAttributeChangedSignal("Spectating"):Connect(refreshSpectatorVisibility)
    refreshSpectatorVisibility()
end
local sessionChildConnection = player.PlayerGui.ChildAdded:Connect(bindSpectatorControls)
local sessionControls = player.PlayerGui:FindFirstChild("PlaygroundSessionControls")
if sessionControls then bindSpectatorControls(sessionControls) end
script.Destroying:Connect(function()
    sessionChildConnection:Disconnect()
    if spectatorConnection then spectatorConnection:Disconnect() end
end)
local elapsed=0
RunService.Heartbeat:Connect(function(delta)''',1)
after['Shell'] = shell

level = after['Level']
level = level.replace(' local modal=(shop and shop.Visible)', ' local controls=gui.Parent and gui.Parent:FindFirstChild("PlaygroundSessionControls")\n local watching=controls and controls:GetAttribute("Spectating")==true\n local modal=watching or (shop and shop.Visible)',1)
level = level.replace('connect(player.CharacterAdded,bindCharacter)', '''local spectatorConnection
local function bindSpectatorControls(controls)
 if controls.Name~="PlaygroundSessionControls" then return end
 if spectatorConnection then spectatorConnection:Disconnect() end
 spectatorConnection=connect(controls:GetAttributeChangedSignal("Spectating"),scheduleRefresh)
 scheduleRefresh()
end
connect(player.PlayerGui.ChildAdded,bindSpectatorControls)
local sessionControls=player.PlayerGui:FindFirstChild("PlaygroundSessionControls")
if sessionControls then bindSpectatorControls(sessionControls) end
connect(player.CharacterAdded,bindCharacter)''',1)
after['Level'] = level

emote = after['Emote']
emote = emote.replace('local function otherModalOpen()\n', '''local function otherModalOpen()
    local controls = player.PlayerGui:FindFirstChild("PlaygroundSessionControls")
    if controls and controls:GetAttribute("Spectating") == true then return true end
''',1)
old = '''		local blocked = inRound() or otherModalOpen() or not gui.Enabled
		toggle.Visible = not blocked and not panel.Visible
		if blocked then setOpen(false) end'''
assert old in emote
emote = emote.replace(old, '\t\trefreshAvailability()',1)
anchor = 'task.spawn(function()\n\twhile alive do\n\t\trefreshAvailability()'
assert anchor in emote
emote = emote.replace(anchor, '''local function refreshAvailability()
    local blocked = inRound() or otherModalOpen() or not gui.Enabled
    toggle.Visible = not blocked and not panel.Visible
    if blocked then setOpen(false) end
end
local spectatorConnection
local function bindSpectatorControls(controls)
    if controls.Name ~= "PlaygroundSessionControls" then return end
    if spectatorConnection then spectatorConnection:Disconnect() end
    spectatorConnection = connect(controls:GetAttributeChangedSignal("Spectating"), refreshAvailability)
    refreshAvailability()
end
connect(player.PlayerGui.ChildAdded, bindSpectatorControls)
local sessionControls = player.PlayerGui:FindFirstChild("PlaygroundSessionControls")
if sessionControls then bindSpectatorControls(sessionControls) end

task.spawn(function()
	while alive do
		refreshAvailability()''',1)
after['Emote'] = emote

names = {'Shell':'PlaygroundShell.Controller', 'Level':'PlaygroundShell.PlayerLevelController', 'Emote':'PlaygroundEmoteWheel.Controller'}
for key, name in names.items():
    assert before[key] != after[key]
    assert before[key].count('.Position =') == after[key].count('.Position =')
    assert before[key].count('.Size =') == after[key].count('.Size =')
    (root / 'After' / (name+'.luau')).write_bytes(after[key].encode('utf-8'))
(root / 'SpectatorVisibilityAfter.json').write_text(json.dumps(after,indent=2),encoding='utf-8')
print('Prepared three fresh controller visibility guards; no layout or capability changes.')
