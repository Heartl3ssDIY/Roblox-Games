local OrderedWrites = require("./GBloxOrderedWrites")
local count = 0
local function check(ok, message) count += 1 assert(ok, message) end
local function fixture()
 local s = {scheduled = {}, calls = {}, warnings = {}, values = {}, fail = false}
 s.queue = OrderedWrites.new({
  Spawn = function(f) table.insert(s.scheduled, f) end,
  Warn = function(metric, userId, message) table.insert(s.warnings, message) end,
  Write = function(metric, userId, value, ascending)
   table.insert(s.calls, {metric=metric, userId=userId, value=value, ascending=ascending})
   if s.onWrite then s.onWrite(metric,userId,value,ascending) end
   if s.fail then error("simulated outage") end
   local key=tostring(userId)..":"..metric
   local old=s.values[key]
   s.values[key]=ascending and (old and math.min(old,value) or value) or math.max(old or 0,value)
  end,
 })
 function s.flush()
  local tasks=s.scheduled s.scheduled={}
  for _,f in tasks do f() end
 end
 return s
end
do
 local s,p=fixture(),{}
 s.queue:Submit(p,"Wins",1,10,false)
 check(#s.scheduled==1,"initial save queues")
 s.flush()
 check(#s.calls==1 and s.values["1:Wins"]==10,"first write commits")
 for _=1,20 do s.queue:Submit(p,"Wins",1,10,false) end
 check(#s.scheduled==0 and #s.calls==1,"unchanged repeated saves do not write")
 s.queue:Submit(p,"Wins",1,11,false) s.flush()
 check(#s.calls==2 and s.values["1:Wins"]==11,"changed value writes")
end
do
 local s,p=fixture(),{}
 s.queue:Submit(p,"Wins",2,1,false)
 s.queue:Submit(p,"Wins",2,2,false)
 s.queue:Submit(p,"Wins",2,3,false)
 check(#s.scheduled==1,"queued changes share one worker")
 s.flush()
 check(#s.calls==1 and s.calls[1].value==3,"coalesce latest before starting")
end
do
 local s,p=fixture(),{}
 local active,maxActive=0,0
 s.onWrite=function()
  active+=1 maxActive=math.max(maxActive,active)
  if #s.calls==1 then
   s.queue:Submit(p,"Wins",3,6,false)
   s.queue:Submit(p,"Wins",3,7,false)
   check(#s.scheduled==0,"in-flight update never spawns concurrent worker")
  end
  active-=1
 end
 s.queue:Submit(p,"Wins",3,5,false) s.flush()
 check(#s.calls==2 and s.calls[2].value==7,"latest in-flight desired value is flushed")
 check(maxActive==1,"single in-flight per key")
 s.queue:Submit(p,"Wins",3,7,false)
 check(#s.scheduled==0,"cache tracks actual final successful value")
end
do
 local s,p=fixture(),{}
 s.fail=true
 s.queue:Submit(p,"Wins",4,5,false) s.flush()
 check(#s.warnings==1 and #s.calls==1,"failure reports once without busy retry")
 check(#s.scheduled==0,"no automatic outage loop")
 s.fail=false
 s.queue:Submit(p,"Wins",4,5,false) s.flush()
 check(#s.calls==2 and s.values["4:Wins"]==5,"failed value retries on later save")
 s.queue:Submit(p,"Wins",4,5,false)
 check(#s.scheduled==0,"retry success is cached")
end
do
 local s,p=fixture(),{}
 s.queue:Submit(p,"Wins",5,1,false) s.flush()
 s.fail=true
 s.onWrite=function()
  if #s.calls==2 then s.queue:Submit(p,"Wins",5,3,false) end
 end
 s.queue:Submit(p,"Wins",5,2,false) s.flush()
 check(#s.calls==2,"failed in-flight write stops even when new desired arrived")
 s.fail=false s.onWrite=nil
 s.queue:Submit(p,"Wins",5,3,false) s.flush()
 check(s.calls[3].value==3,"superseded failure never marks newer value saved")
end
do
 local s,p1,p2=fixture(),{},{}
 s.queue:Submit(p1,"Wins",6,8,false) s.flush()
 s.queue:Submit(p2,"Wins",6,8,false) s.flush()
 check(#s.calls==2,"new profile identity does not inherit old success cache")
 s.onWrite=function()
  if #s.calls==3 then s.queue:Submit(p2,"Wins",6,10,false) end
 end
 s.queue:Submit(p1,"Wins",6,9,false) s.flush()
 check(#s.calls==4 and s.calls[4].value==10,"profile changes still serialize same key")
 s.queue:Submit(p2,"Wins",6,10,false)
 check(#s.scheduled==0,"new profile final success cached")
 s.queue:Submit(p1,"Wins",6,9,false)
 check(#s.scheduled==0,"old profile cache only contains its own successful write")
end
do
 local s,p=fixture(),{}
 s.values["7:Wins"]=20
 s.values["7:FastestTime"]=80
 s.queue:Submit(p,"Wins",7,10,false)
 s.queue:Submit(p,"FastestTime",7,100,true)
 check(#s.scheduled==2,"different metrics may run independently")
 s.flush()
 check(s.values["7:Wins"]==20,"existing maximum is preserved")
 check(s.values["7:FastestTime"]==80,"existing minimum is preserved")
 s.queue:Submit(p,"FastestTime",7,70,true) s.flush()
 check(s.values["7:FastestTime"]==70,"improved minimum writes")
end
print(string.format("Ordered writes: %d checks passed",count))
