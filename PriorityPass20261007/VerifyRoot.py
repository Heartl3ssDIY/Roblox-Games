from pathlib import Path
import re, subprocess

root = Path(__file__).resolve().parent
source = (root/'After/TagSprintService.luau').read_text(encoding='utf-8')
parts = []
for name in ['_setting', '_active', '_tick']:
    match = re.search(r'^function Service:' + re.escape(name) + r'\(.*?(?=^function |^return Service)', source, re.M | re.S)
    assert match, name
    parts.append(match.group())
harness = '''local Service={}
local workspace={GetServerTimeNow=function() return 100 end}
local Players={}
local Vector3={new=function(x,y,z) return {X=x,Y=y,Z=z,Magnitude=math.sqrt(x*x+y*y+z*z)} end}
Vector3.zero=Vector3.new(0,0,0)
local function set(p,k,v) p.attrs[k]=v end
''' + '\n'.join(parts) + '''
local checks=0
local function check(v,m) checks+=1 assert(v,m) end
local player={attrs={TGParticipating=true},Parent=Players}
function player:GetAttribute(k) return self.attrs[k] end
function Players:GetPlayers() return {player} end
local record={participating=true,role="Runner",character={},humanoid={Health=100},root={Parent=true,AssemblyLinearVelocity=Vector3.new(10,0,0)}}
local arena={GetAttribute=function() return nil end}
local entry={remaining=0,held=true,locked=true,lease=110,character=record.character,round=1}
local service=setmetatable({tag={active=true,phase="Playing",currentRound=1,records={[player]=record}},arena=arena,entries={[player]=entry}}, {__index=Service})
service:_tick(.05)
check(entry.remaining>0 and not entry.locked,"Any refill unlocks Tag sprint")
check(record.humanoid.WalkSpeed==16 and not player.attrs.TGSprinting,"Empty tick walks and recharges")
service:_tick(.05)
check(entry.remaining==0 and record.humanoid.WalkSpeed>16 and record.humanoid.WalkSpeed<40 and player.attrs.TGSprinting,"Tiny partial gives proportional actual movement")
entry.remaining=1
service:_tick(.05)
check(record.humanoid.WalkSpeed==40 and math.abs(entry.remaining-.95)<.00001,"Enough stamina gives full multiplier")
entry.held=false
service:_tick(.05)
check(record.humanoid.WalkSpeed==16 and entry.remaining>.95,"Release recharges at normal speed")
entry.held=true entry.remaining=.01
service:_tick(.1)
check(math.abs(record.humanoid.WalkSpeed-18.4)<.00001,"Final .01s budget only buys .01s of boost")
entry.remaining=0
local spent=0
for tick=1,20 do
 service:_tick(.05)
 spent+=(record.humanoid.WalkSpeed/16-1)/1.5*.05
end
check(math.abs(spent-10*(10/15*.05))<.00001,"Holding sprint conserves regenerated budget")
record.frozen=true entry.remaining=1
service:_tick(.05)
check(record.humanoid.WalkSpeed==0 and not player.attrs.TGSprinting,"Frozen cannot sprint")
record.frozen=false entry.lease=99
service:_tick(.05)
check(record.humanoid.WalkSpeed==16 and not entry.held,"Expired input lease releases sprint")
player.attrs.TGParticipating=false
service:_tick(.05)
check(service.entries[player]==nil and not player.attrs.TGSprinting,"Leaving round clears stamina entry")
print(tostring(checks).." Tag stamina checks passed")
'''
(root/'TagStaminaChecks.luau').write_text(harness,encoding='utf-8')
subprocess.run([str(root.parent/'AttackTiming20260926/tools/luau-0.740/luau.exe'), str(root/'TagStaminaChecks.luau')], check=True)
