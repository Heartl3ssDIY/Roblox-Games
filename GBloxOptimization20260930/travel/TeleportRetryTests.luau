local Retry = require("./GBloxTeleportRetry")
local checks = 0
local function check(value, message)
 checks += 1
 assert(value, message)
end
local function options(payload, code, reserve)
 return {payload=payload or {},ReservedServerAccessCode=code or "",ServerInstanceId="",ShouldReserveServer=reserve==true,
  GetTeleportData=function(self) return self.payload end}
end
local function fixture()
 local state = {calls={},delays={},failures={},reports={},reserves=0,serial=0,spawned={}}
 local a,b = {Name="a",present=true},{Name="b",present=true}
 local deps = {
  NewId=function() state.serial+=1 return tostring(state.serial) end,
  IsPresent=function(player) return player.present end,
  CopyOptions=function(old,payload)
   local out=options(payload,old.ReservedServerAccessCode,old.ShouldReserveServer)
   out.ServerInstanceId=old.ServerInstanceId
   return out
  end,
  Spawn=function(callback) table.insert(state.spawned,callback) end,
  Delay=function(seconds,callback) table.insert(state.delays,{seconds=seconds,callback=callback}) end,
  Wait=function(seconds) state.waited=(state.waited or 0)+seconds end,
  Reserve=function(place)
   state.reserves+=1
   if state.reserveError then error("reserve unavailable") end
   return "shared-destination"
  end,
  Teleport=function(place,players,opts)
   table.insert(state.calls,{place=place,players=table.clone(players),options=opts})
   if state.onCall then state.onCall(place,players,opts) end
   if state.callError then error("network unavailable") end
  end,
  Report=function(kind,player,place,attempt,detail) table.insert(state.reports,{kind=kind,detail=detail}) end,
 }
 state.controller=Retry.new(deps)
 state.callbacks={Failed=function(player,message) table.insert(state.failures,{player=player,message=message}) end}
 function state.start(members,reserve)
  return state.controller:Start(99,members or {a,b},options({GBloxPlaytimeTickets={a="ticket-a",b="ticket-b"},HumanCount=2},nil,reserve),state.callbacks)
 end
 function state.flushSpawn() local tasks=state.spawned state.spawned={} for _,callback in tasks do callback() end end
 function state.flushDelay() local tasks=state.delays state.delays={} for _,entry in tasks do entry.callback() end end
 function state.fail(player,result,opts,place)
  state.controller:Failed(player,result or "Failure","failure detail",place or 99,opts or state.calls[#state.calls].options)
 end
 return state,a,b
end

do
 local s,a,b=fixture()
 check(s.start(nil,true),"accept group")
 check(not s.start({a},true),"reject overlapping request")
 s.flushSpawn()
 check(s.reserves==1,"reserve exactly once")
 check(#s.calls==1 and #s.calls[1].players==2,"initial group together")
 check(s.calls[1].options.ShouldReserveServer==false,"disable new reservation on retries")
 check(s.calls[1].options.ReservedServerAccessCode=="shared-destination","fixed reservation")
 check(s.calls[1].options.payload.GBloxPlaytimeTickets.a=="ticket-a","preserve handoff data")
 check(s.calls[1].options.payload.HumanCount==2,"preserve party count")
 s.fail(a)
 check(#s.delays==1 and s.delays[1].seconds==2,"backoff first failure")
 s.fail(a)
 check(#s.delays==1,"duplicate event must not duplicate retry")
 local old=s.calls[1].options
 s.flushDelay()
 check(#s.calls==2 and #s.calls[2].players==1 and s.calls[2].players[1]==a,"retry failed member only")
 check(s.calls[2].options.ReservedServerAccessCode=="shared-destination","retry stays in same party server")
 check(s.calls[2].options.payload.GBloxTravelAttempt==2,"increment attempt identity")
 s.fail(a,"Failure",old)
 check(#s.delays==0,"ignore late failure from first attempt")
 s.fail(a,"Flooded")
 check(s.delays[1].seconds==15,"flood backoff")
 s.flushDelay()
 s.fail(a)
 check(#s.calls==3 and #s.delays==0,"bounded at three attempts")
 check(#s.failures==1 and s.failures[1].player==a,"failed member gets final error once")
 check(s.controller:IsPending(b),"other party member remains in flight")
 check(not s.controller:IsPending(a),"failed context released")
 s.fail(a)
 check(#s.failures==1,"late exhausted event ignored")
end
do
 local s,a,b=fixture()
 s.start(nil,true) s.flushSpawn()
 local initial=s.calls[1].options
 s.fail(a,"Unauthorized")
 check(#s.failures==1 and #s.delays==0,"terminal result does not retry")
 check(s.controller:IsPending(b),"terminal peer failure does not cancel another member")
 local foreign=options(table.clone(initial.payload),"shared-destination")
 foreign.payload.GBloxTravelRequestId="another-request"
 s.fail(b,"Failure",foreign)
 s.fail(b,"Failure",initial,100)
 check(#s.delays==0,"ignore foreign request or place")
end
do
 local s,a=fixture()
 s.callError=true s.start({a},true) s.flushSpawn()
 check(#s.delays==1,"synchronous exception schedules retry")
 s.flushDelay() s.flushDelay()
 check(#s.calls==3 and #s.failures==1,"synchronous errors are bounded")
 check(s.reserves==1,"synchronous retries never create new destination")
end
do
 local s,a=fixture()
 s.reserveError=true s.start({a},true) s.flushSpawn()
 check(s.reserves==3 and s.waited==6,"reservation bounded retry")
 check(#s.calls==0 and #s.failures==1,"reservation exhaustion returns player safely")
end
do
 local s,a,b=fixture()
 s.start(nil,true) a.present=false s.flushSpawn()
 check(#s.calls[1].players==1 and s.calls[1].players[1]==b,"exclude departed players before teleport")
 check(not s.controller:IsPending(a),"clean departed context")
 s.fail(b) b.present=false s.flushDelay()
 check(#s.calls==1 and #s.failures==0,"departed players are never retried or failed")
end
do
 local s,a=fixture()
 s.start({a},true) s.controller:Remove(a) s.flushSpawn()
 check(s.reserves==0 and #s.calls==0,"canceled preparation does not reserve or teleport")
 check(s.start({a},true),"removed contexts can start again")
 s.flushSpawn() s.fail(a) s.controller:Remove(a) s.flushDelay()
 check(#s.calls==1,"cancel delayed retry")
end
do
 local s,a=fixture()
 s.onCall=function(_,_,opts) s.fail(a,"Failure",opts) end
 s.start({a},true) s.flushSpawn()
 check(#s.delays==1,"async failure during call schedules once")
 s.onCall=nil s.flushDelay()
 check(#s.calls==2,"successful return does not overwrite pending failure")
end
do
 local s,a=fixture()
 s.start({a},false) s.flushSpawn()
 check(s.reserves==0 and #s.calls==1,"public return skips reservation")
end
print(string.format("Teleport retry: %d checks passed",checks))
