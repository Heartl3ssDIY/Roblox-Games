from pathlib import Path
import re, subprocess

root = Path(__file__).resolve().parent
rules = (root / 'After/BritishBulldogRules.luau').read_text(encoding='utf-8')
source = (root / 'After/BritishBulldogService.luau').read_text(encoding='utf-8')
functions = []
for name in ['_counts', '_outcome', '_keepRunnerLegal', '_caught']:
    match = re.search(r'^function Service:' + name + r'\(.*?(?=^function |^return Service)', source, re.M | re.S)
    assert match, name
    functions.append(match.group())
harness = '''local Rules = (function()
''' + rules + '''
end)()
local now = 100
local workspace = { GetServerTimeNow = function() return now end }
local Service = {}
local function alive(r) return r.character and r.character.Parent and r.root and r.root.Parent and r.humanoid and r.humanoid.Health > 0 end
local function setAttribute(p,k,v) p.attrs[k] = v end
''' + '\n'.join(functions) + '''
local n=0
local function check(condition, message) n+=1 assert(condition, message) end
local function runner()
 return {participating=true,role="Runner",arrived=false,departed=false,player={attrs={}},character={Parent=true},root={Parent=true,Position="Source",CFrame="Source"},humanoid={Health=100}}
end
local a,b=runner(),runner()
local dog={participating=true,role="Bulldog"}
local s=setmetatable({active=true,phase="Crossing",records={a,b,dog},lastRunnerWins=true,endsAt=200,bounds="Bounds",source="North",destination="South",safeZones={North="Source",South="Destination"}}, {__index=Service})
function s:_inside(part, position) return part=="Bounds" or part==position end
function s:_pastSource(position) return position~="Source" end
function s:_inField(position) return position=="Field" end
function s:_departure() end
function s:_setRole(r, role) r.role=role end
function s:_freeze(r) r.frozen=true end
check(s:_outcome()==nil,"Multiple runners keep playing")
check(s:_caught(a,"Tagged",100),"First runner can be caught")
check(s:_outcome()==nil,"Sole remaining runner in source safe zone must still cross")
b.root.Position="Field" b.root.CFrame="Field"
s:_keepRunnerLegal(b,100)
check(b.departed and not b.arrived,"Field entry is not arrival")
check(s:_outcome()==nil,"Sole runner mid-crossing must still reach other side")
check(Rules.CanTag("Crossing","Runner",b.departed,b.arrived,true,false),"Last runner remains taggable during crossing")
b.root.Position="Destination" b.root.CFrame="Destination"
s:_keepRunnerLegal(b,100)
check(b.arrived and b.departed and b.player.attrs.BBStatus=="Safe","Actual opposite-zone arrival confirms safe")
check(s:_outcome()=="Runners","Completed crossing grants immediate sole runner win")
check(not Rules.CanTag("Crossing","Runner",b.departed,b.arrived,false,false),"Safe last runner is protected")
b.departed=false
check(s:_outcome()==nil,"An arrived flag without departure does not grant early win")
b.departed=true b.humanoid.Health=0
check(s:_outcome()==nil,"Dead runner cannot claim an early crossing win")
b.humanoid.Health=100 b.arrived=false b.departed=true
check(s:_caught(b,"Tagged",100) and s:_outcome()=="Bulldogs","Last runner can be caught before arrival")
local c=runner()
s.records={c,dog} s.lastRunnerWins=false
check(s:_outcome()==nil,"Round beginning with a single runner remains playable")
c.departed=true c.arrived=true
check(s:_outcome()==nil,"Original single-runner match does not end on its first crossing")
s.lastRunnerWins=true c.arrived=false now=201
check(s:_outcome()=="Bulldogs","Timeout cannot award lone runner before finishing crossing")
c.arrived=true
check(s:_outcome()=="Runners","Already-completed crossing wins at timeout")
s.records={runner(),runner(),dog}
check(s:_outcome()=="Runners","Ordinary timer rule for multiple survivors preserved")
s.records={dog}
check(s:_outcome()=="Bulldogs","No runners means Bulldogs win")
s.records={}
check(s:_outcome()=="None","Empty round cancels")
check(Rules.Outcome(2,0,0,2,false,false,false)=="Runners","All-opponents-left ordinary rule preserved")
print("Crossing checks passed: "..n)
'''
(root / 'CrossingChecks.luau').write_text(harness, encoding='utf-8')
exe = root.parents[1] / 'AttackTiming20260926/tools/luau-0.740/luau.exe'
subprocess.run([str(exe), str(root/'CrossingChecks.luau')], check=True)
for file in ['BulldogMovement','TagSprint','MudController']:
    script=(root/'After'/f'{file}.luau').read_text(encoding='utf-8')
    assert 'LeftControl' not in script and 'RightControl' not in script
    assert '3000,Enum.KeyCode.LeftShift)' in script
    assert 'RightShift' not in script
    assert 'HOLD SHIFT' in script and 'HOLD CTRL' not in script
    assert 'return Enum.ContextActionResult.Sink' in script
print('Sprint binding checks passed: all 3 clients, Left Shift only, Right Shift untouched')
