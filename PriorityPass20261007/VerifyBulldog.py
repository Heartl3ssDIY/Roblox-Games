from pathlib import Path
import re, subprocess

root = Path(__file__).resolve().parent
service = (root / 'After/BritishBulldogService.luau').read_text()
rules = (root / 'After/BritishBulldogRules.luau').read_text()
names = ['_counts', '_sprintCapacity', '_applyMovementSpeed', '_publishMovement', '_releaseSprint', '_updateMovement', '_keepRunnerLegal', '_outcome', '_finishCrossing', '_caught', '_forfeit', 'Move']
parts = []
for name in names:
    match = re.search(r'^function Service:' + re.escape(name) + r'\(.*?(?=^function |^return Service)', service, re.M | re.S)
    assert match, name
    parts.append(match.group())
harness = '''local Rules = (function()
''' + rules + '''
end)()
local Service = {}
local workspace = {GetServerTimeNow=function() return 100 end}
local Players = {}
local Vector3 = {new=function(x,y,z) return {Magnitude=math.sqrt(x*x+y*y+z*z)} end}
local function alive(r) return r.character and r.character.Parent and r.root and r.root.Parent and r.humanoid and r.humanoid.Health>0 end
local function setAttribute(p,k,v) p.attrs[k]=v end
''' + '\n'.join(parts) + '''
local checks=0
local function check(value, message) checks+=1 assert(value,message) end
local function record(role,index)
 return {role=role,spawnIndex=index or 1,participating=true,player={attrs={},Parent=Players},character={Parent=true},root={Parent=true,Position={},CFrame={},AssemblyLinearVelocity={X=10,Y=0,Z=0}},humanoid={Parent=true,Health=100},sprintRemaining=0,sprintHeld=true,sprintExhausted=true,sprintLeaseEndsAt=110}
end
local s=setmetatable({mode="Round",active=true,endsAt=200,initialRunnerCount=2,records={}}, {__index=Service})
function s:_setting(_,fallback) return fallback end
function s:_movementAllowed(r) return not r.arrived end
local r=record("Runner")
s:_updateMovement(r,.05,100)
check(r.sprintRemaining>0 and not r.sprintExhausted,"Any positive refill unlocks sprint")
check(r.humanoid.WalkSpeed==16 and not r.sprinting,"Empty tick refills without a free boosted frame")
s:_updateMovement(r,.01,100)
check(r.sprinting and r.sprintRemaining>0,"Held sprint resumes before full recharge")
check(r.humanoid.WalkSpeed==40,"Enough stamina for the entire tick grants full boost")
s:_updateMovement(r,.1,100)
check(r.sprintRemaining==0 and r.humanoid.WalkSpeed>16 and r.humanoid.WalkSpeed<40,"Final partial stamina grants only its fraction of boost")
s:_updateMovement(r,.05,100)
check(r.humanoid.WalkSpeed==16 and not r.sprinting,"Following empty tick stops sprint and refills")
r.sprintHeld=false
s:_updateMovement(r,.05,100)
check(r.sprintRemaining>0 and r.humanoid.WalkSpeed==16,"Released shift recharges without sprint")
r.sprintHeld=true r.sprintLeaseEndsAt=110
s:_updateMovement(r,.01,100)
check(r.sprinting,"Pressing sprint again uses a partial refill")
local boostedTicks=0
local boostedBudget=0
r.sprintRemaining=0 r.sprintHeld=true r.sprintLeaseEndsAt=110
for tick=1,20 do
 s:_updateMovement(r,.05,100)
 if r.humanoid.WalkSpeed>16 then
  boostedTicks+=1
  boostedBudget+=r.sprintFraction*.05
  check(r.sprinting and r.sprintRemaining==0 and r.sprintFraction>0 and r.sprintFraction<1 and r.humanoid.WalkSpeed<40,"Tiny refill grants an actual proportional boosted frame")
 end
end
check(boostedTicks>=10,"Holding sprint while empty repeatedly uses tiny refills")
check(math.abs(boostedBudget-10*(10/15*.05))<.00001,"Tiny boosts spend exactly the regenerated stamina budget")
r.departed=true r.sprintRemaining=1
s.bounds="Bounds" s.safeZones={North="North",South="South"} s.source="North" s.destination="South"
function s:_inside(part) return part~="North" end
function s:_pastSource() return true end
s:_keepRunnerLegal(r,100)
check(r.arrived and r.sprintRemaining==10 and not r.sprintExhausted,"Arrival fully refills runner stamina")
check(not r.sprintHeld and r.sprintLeaseEndsAt==0 and r.player.attrs.BBSprintRemaining==10,"Arrival releases sprint and publishes refill")
local a,b,d=record("Runner",1),record("Runner",2),record("Bulldog",3)
s.records={a,b,d}
check(s:_outcome()==nil,"Initial field of runners does not win immediately")
function s:_departure() end
function s:_setRole(rec,role) rec.role=role end
function s:_freeze(rec) rec.frozen=true end
check(s:_caught(a,"Tagged",100)==true,"First runner can be tagged")
check(s:_outcome()=="Runners","Last surviving runner wins before timer")
check(s:_caught(b,"Tagged",100)==false and b.role=="Runner","Second hit in same tick cannot eliminate the winner")
s:_forfeit(b,100)
check(b.role=="Runner","Same-tick departure processing preserves the winner")
b.humanoid.Health=0
check(s:_caught(b,"Reset",100)==true and s:_outcome()=="Bulldogs","Zero living runners does not award runner victory")
s.records={record("Runner"),record("Bulldog")}
s.initialRunnerCount=1
check(s:_outcome()==nil,"Two-player initial single runner does not auto-win")
s.initialRunnerCount=3 s.mode="PracticeRunner"
check(s:_outcome()==nil,"Runner practice remains playable")
s.mode="PracticeBulldog"
check(s:_outcome()==nil,"Bulldog practice remains playable")
s.mode="Round" s.records={} 
check(s:_outcome()=="None","Empty round is cancelled")
check(Rules.Outcome(0,2,1,3,false,true)=="Bulldogs","No runner always loses even with an eligible flag")
local dog,tagged,pending,runner=record("Bulldog",1),record("Tagged",2),record("Bulldog",3),record("Runner",4)
pending.pendingBulldog=true
s.records={dog,tagged,pending,runner}
function s:_spawnCFrame(side,index) return side..tostring(index) end
function s:_teleport(rec,dest) rec.destination=dest end
function s:_unfreeze(rec) rec.frozen=false end
s:_finishCrossing()
check(dog.destination=="Bulldog1" and tagged.destination=="Bulldog2" and pending.destination=="Bulldog3","Every Bulldog recentres after crossing")
check(tagged.role=="Bulldog" and not pending.pendingBulldog and runner.destination==nil,"Conversion and runner positions preserved")
check(s.source=="South" and s.destination=="North","Next crossing reverses direction")
local p=dog.player s.records={[p]=dog}
check(s:Move(p,"Dodge",1).ok==false,"Server rejects dodge")
print("Bulldog checks passed: "..checks)
'''
(root / 'BulldogChecks.luau').write_text(harness,encoding='utf-8',newline='')
result = subprocess.run([str(root.parent / 'AttackTiming20260926/tools/luau-0.740/luau.exe'),str(root / 'BulldogChecks.luau')],text=True,capture_output=True)
print(result.stdout,end='')
print(result.stderr,end='')
raise SystemExit(result.returncode)
