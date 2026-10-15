local checks=0
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
local function request(value)
 pending=value
 if sending or not alive then return end
 sending=true requestSerial+=1
 local serial=requestSerial
 local worker=task.spawn(function()
  while pending~=nil and alive and serial==requestSerial do
   local value=pending pending=nil
   pcall(function() remote:InvokeServer(value) end)
  end
  if serial==requestSerial then sending=false end
 end)
 task.delay(2,function()
  if serial==requestSerial and sending then requestSerial+=1 sending=false pending=nil pcall(task.cancel,worker) end
 end)
end
local function updateHold()
 local value=focused and active() and (next(keys)~=nil or touch~=nil)
 if value~=held then held=value request(value) lease=os.clock() end
end
local function release()
 table.clear(keys) touch=nil
 if held then held=false request(false) end
end

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
print("Tag sprint queue checks passed: "..checks)
