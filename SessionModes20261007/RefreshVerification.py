from pathlib import Path

root = Path(__file__).parent
server = (root / 'After/PlaygroundCoordinator.luau').read_text(encoding='utf-8')
client = (root / 'After/SessionControls.client.luau').read_text(encoding='utf-8')
p = root / 'VerifyAFK.luau'
s = p.read_text(encoding='utf-8')
a = s.index('local Coordinator = (function()\n') + len('local Coordinator = (function()\n')
b = s.index('\nend)()\nlocal function player', a)
s = s[:a] + server + s[b:]
s = s.replace('local task = { spawn = function() end }', 'local task = { spawn = function() end }\nlocal workspace = {GetServerTimeNow = function() return now end}\nfunction Players:GetPlayerByUserId(id) for _, p in ipairs(self.list) do if p.UserId == id and p.Parent == self then return p end end end')
s = s.replace('result.Character = { FindFirstChildOfClass = function() return { Health = 100 } end }', '''result.Character = {Humanoid = {Health = 100}, HumanoidRootPart = {Position = {}}}
 function result.Character:FindFirstChildOfClass(name) return self.Humanoid end
 function result.Character:FindFirstChild(name) return self[name] end
 result.focuses = {}
 function result:AddReplicationFocus(root) self.focuses[root] = true end
 function result:RemoveReplicationFocus(root) self.focuses[root] = nil end''')
s += '''
services.TagYoureIt.active = true
services.TagYoureIt.state:SetAttribute("Phase", "Playing")
three:SetAttribute("TGParticipating", true)
now += 1
check(coordinator:SetSpectate(one, three.UserId, now).ok, "Valid distant target denied")
check(one.focuses[three.Character.HumanoidRootPart], "Target replication focus missing")
check(not coordinator:SetSpectate(one, three.UserId, now).ok, "Stale target request accepted")
now += 1
check(not coordinator:SetSpectate(one, one.UserId, now).ok, "Self spectate allowed")
check(next(one.focuses) == nil, "Invalid selection retained old focus")
now += 1
check(coordinator:SetSpectate(one, three.UserId, now).ok, "Second target focus failed")
now += 1
check(coordinator:SetSpectate(one, 0, now).ok and next(one.focuses) == nil, "Exit did not remove additional focus")
check(not coordinator:SetSpectate(one, three.UserId, now - 0.5).ok, "Late request refocused after exit")
now += 1
one:SetAttribute("BBParticipating", true)
check(not coordinator:SetSpectate(one, three.UserId, now).ok, "A round participant could spectate")
one:SetAttribute("BBParticipating", false)
now += 1
three.Character.Humanoid.Health = 0
check(not coordinator:SetSpectate(one, three.UserId, now).ok, "Dead target accepted")
three.Character.Humanoid.Health = 100
now += 1
check(coordinator:SetSpectate(one, three.UserId, now).ok, "Living target failed after recovery")
now += 13
coordinator:_updateSpectators()
check(next(one.focuses) == nil and coordinator.spectators[one] == nil, "Expired focus lease leaked")
now += 1
check(coordinator:SetSpectate(one, three.UserId, now).ok, "Focus failed before round-end check")
services.TagYoureIt.state:SetAttribute("Phase", "Results")
coordinator:_updateSpectators()
check(next(one.focuses) == nil, "Round results did not clear spectator focus")
check(not coordinator:SetSpectate(one, three.UserId, now + 1000).ok, "Forged future stamp accepted")
print(string.format("%d combined AFK and streaming-focus validation checks passed", passed))
'''
p.write_text(s, encoding='utf-8')
p = root / 'VerifySpectate.luau'
s = p.read_text(encoding='utf-8')
a = s.index('local api=(function()\n') + len('local api=(function()\n')
b = s.index('\nplayerControls=controls\nreturn {start=', a)
prefix = client[:client.index('connect(afkButton.Activated')]
s = s[:a] + prefix + s[b:]
s = s.replace('local workspace={CurrentCamera=camera}', 'local workspace={CurrentCamera=camera,GetServerTimeNow=function()return os.clock()end}')
s = s.replace('local task={}\n', '''local task={}
local scheduled={}
function task.spawn(callback) local t={callback=callback} table.insert(scheduled,t) return t end
function task.cancel(worker) worker.cancelled=true end
function task.delay(_, callback) return {callback=callback} end
function storage.PlaygroundSessionRequest:InvokeServer() return {ok=true} end
local function drain() local copy=scheduled scheduled={} for _,t in ipairs(copy) do if not t.cancelled then t.callback() end end end
''')
s = s.replace('local function check(value, message) assert(value, message) checks += 1 end', 'local function check(value, message) assert(value, message) checks += 1 end\nlocal time=10\nlocal os={clock=function()time+=0.1 return time end}')
s = s.replace('api.start()\n', 'api.start()\ndrain()\n')
s = s.replace('api.step(-1)\n', 'api.step(-1)\ndrain()\n')
s += '''
gui.Enabled=true
local savedCharacter=first.Character
first.Character=nil
api.start()
drain()
check(api.isWatching() and gui:GetAttribute("SpectatingUserId")==first.UserId, "Streamed-out participant was not selectable")
check(panel.Username.Text=="LOADING ARENA...", "Streamed-out target did not show loading state")
first.Character=savedCharacter
api.refresh()
check(workspace.CurrentCamera.CameraSubject==savedCharacter.Humanoid, "Camera did not attach when target streamed in")
api.exit()
drain()
print(string.format("%d combined camera lifecycle and streaming-arrival checks passed",checks))
'''
p.write_text(s, encoding='utf-8')
