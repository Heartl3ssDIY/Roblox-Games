from pathlib import Path
import subprocess,re
folder=Path(__file__).resolve().parents[1]
runner=folder.parent/'AttackTiming20260926/tools/luau-0.740/luau.exe'
for kind,path,start,finish in [
 ('Tag','StarterGui.TagHUD.SprintController.luau','local function request(value)','local function action('),
 ('Bulldog','StarterGui.BritishBulldogHUD.MovementController.luau','local function requestSprint(value)','local function sprintAction('),
]:
 source=(folder/'After'/path).read_text()
 methods=source[source.index(start):source.index(finish)]
 if kind=='Bulldog':
  methods=re.sub(r'\bheld\b','desired',methods)
  for old,new in [('requestSprint','request'),('requestPending','pending'),('requestRunning','sending'),('sprintSerial','requestSerial'),('releaseHold','release'),('holdChanged','updateHold'),('shiftKeys','keys'),('touchHold','touch'),('requestedHeld','held'),('canSprint','active'),('lastKeepalive','lease')]:
   methods=methods.replace(old,new)
 script='''local checks=0
local function check(value,msg)assert(value,msg) checks+=1 end
local alive, focused, held, sending=true,true,false,false
local pending,touch
local keys={}
local requestSerial,lease=0,0
local allowed=true
local function active()return allowed end
local calls,callbacks={},{}
local hang=false
local remote={IsA=function()return true end,InvokeServer=function(_,a,b)if b~=nil then table.insert(calls,b)else table.insert(calls,a)end if hang then coroutine.yield()end return true end}
local ReplicatedStorage={FindFirstChild=function()return remote end}
local task={}
function task.spawn(fn)local co=coroutine.create(fn)local ok,err=coroutine.resume(co)assert(ok,err)return co end
function task.delay(_,fn)table.insert(callbacks,fn)end
function task.cancel(co)coroutine.close(co)end
__METHODS__
keys.LeftShift=true updateHold() check(held and calls[#calls]==true,"Key press requests hold")
keys.RightShift=true keys.LeftShift=nil updateHold() check(held,"Second shift remains held")
keys.RightShift=nil updateHold() check(not held and calls[#calls]==false,"Last key release clears hold")
touch={} updateHold() check(held,"Touch starts hold")
release() check(not held and touch==nil and next(keys)==nil and calls[#calls]==false,"Touch cancel clears hold")
keys.LeftShift=true updateHold() focused=false release()check(not held and calls[#calls]==false,"Focus loss releases") focused=true
keys.LeftShift=true updateHold() allowed=false updateHold()check(not held and calls[#calls]==false,"Ragdoll or round state releases")allowed=true release()
hang=true request(true)check(sending,"Pending network request tracked")request(false)check(pending==false,"Release queues while request pending")
for _,fn in ipairs(callbacks)do fn()end table.clear(callbacks)
check(not sending and pending==nil,"Timeout cancels blocked worker and clears queue")
hang=false request(true)check(not sending and calls[#calls]==true,"Fresh press works after timeout")
request(false)check(calls[#calls]==false,"Fresh release works after timeout")
alive=false local count=#calls request(true)check(#calls==count and not sending,"Destroyed controller creates no new worker")
print("__KIND__ sprint queue checks passed: "..checks)
'''.replace('__METHODS__',methods).replace('__KIND__',kind)
 output=folder/'Tests'/(kind+'SprintQueue.generated.luau')
 output.write_text(script)
 result=subprocess.run([str(runner),str(output)],capture_output=True,text=True)
 print(result.stdout,result.stderr)
 assert result.returncode==0
