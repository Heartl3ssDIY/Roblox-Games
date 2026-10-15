local IdleRules=assert(loadstring(game.ServerScriptService.RunnerIdleRules.Source))()
local players={}
local roundPhase="Running"
local courseVersion=1
local forward=Vector3.new(-1,0,0)
local config={SecondLifeAttribute="SecondLives"}
local removals,cleared,events,completed=0,0,{},0
local function currentRoundProgress(data) return .4 end
local function removeRunnerForces(data) removals+=1 data.removed=true end
local abilityService={Remove=function(player) cleared+=1 end}
local event={FireClient=function(_,player,action,payload) table.insert(events,{player=player,action=action,payload=payload}) end}
local function checkRoundComplete()
 for _,d in players do if d.status=="Running" then return end end
 completed+=1 roundPhase="Intermission"
end
local function setStatus(player, status)
	local data = players[player]
	if not data then return end
	data.status = status
 if status~="Running" then data.idleWatch=nil data.idleRecoveryUntil=nil end
 if status=="Loading" or status=="Running" then player:SetAttribute("RunnerOutReason",nil) end
	if status == "Out" or status == "Finished" or status == "Spectating" then
		data.secondLifeCourseVersion = nil
		player:SetAttribute(config.SecondLifeAttribute, 0)
	end
	player:SetAttribute("RunnerStatus", status)
end


local function eliminateIdlePlayer(player, data)
 if roundPhase~="Running" or players[player]~=data or data.status~="Running" then return end
 data.roundStoppedProgress=currentRoundProgress(data)
 -- This is a forfeit of this round, not a hazard death or a paid/free revive.
 data.recovering=false data.pendingRespawnVersion=nil data.recoveryPoint=nil
 data.recoveryVersion=(data.recoveryVersion or 0)+1
 data.boostVersion=(data.boostVersion or 0)+1
 data.idleWatch=nil data.idleRecoveryUntil=nil
 setStatus(player,"Out")
 player:SetAttribute("RunnerOutReason","No forward progress for 15 seconds")
 abilityService.Remove(player)
 removeRunnerForces(data)
 if data.root and data.root.Parent then
  data.root.Anchored=true
  data.root.AssemblyLinearVelocity=Vector3.zero
  data.root.AssemblyAngularVelocity=Vector3.zero
 end
 event:FireClient(player,"Out",{reason="No forward progress for 15 seconds",idleTimeout=true})
 checkRoundComplete()
end

local function stepIdleTimeout(now)
 for player,data in players do
  local active=roundPhase=="Running" and data.status=="Running"
  local root=data.root
  local progress=root and root.Parent and root.Position:Dot(forward) or nil
  -- Recovery grace is bounded: a broken recovery must not hang the round forever.
  local paused=(data.freezeUntil or 0)>now or (data.idleRecoveryUntil or 0)>now
  local expired
  data.idleWatch,expired=IdleRules.Step(data.idleWatch,now,progress,courseVersion,active,paused)
  if expired then eliminateIdlePlayer(player,data) end
 end
end


local function add(name)
 local p={Parent=true,attributes={SecondLives=1,RepeaterActive=true}}
 function p:SetAttribute(k,v) self.attributes[k]=v end
 local d={status="Running",root={Parent=true,Position=Vector3.new(0,0,0)},idleWatch=IdleRules.New(0,0,1),secondLifeCourseVersion=1}
 players[p]=d return p,d
end
local p,a=add("A") local q,b=add("B")
stepIdleTimeout(14.99) assert(a.status=="Running" and b.status=="Running")
b.root.Position=Vector3.new(-28,0,0)
stepIdleTimeout(15)
assert(a.status=="Out" and b.status=="Running" and completed==0,"one stuck racer must not end others' race")
assert(a.root.Anchored and a.root.AssemblyLinearVelocity==Vector3.zero and a.removed,"forces/body stopped")
assert(a.roundStoppedProgress==.4 and p.attributes.SecondLives==0 and p.attributes.RepeaterActive,"timeout bypasses recovery")
assert(events[1].action=="Out" and events[1].payload.idleTimeout and p.attributes.RunnerOutReason,"reason delivered")
stepIdleTimeout(29.99) assert(b.status=="Running")
stepIdleTimeout(30) assert(b.status=="Out" and completed==1 and roundPhase=="Intermission","last stalled racer advances results")
stepIdleTimeout(45) assert(#events==2 and removals==2 and cleared==2 and completed==1,"no repeated elimination")
roundPhase="Running" players={}
local r,c=add("C") c.freezeUntil=20
stepIdleTimeout(15) assert(c.status=="Running")
stepIdleTimeout(20) assert(c.status=="Running")
stepIdleTimeout(34.99) assert(c.status=="Running")
stepIdleTimeout(35) assert(c.status=="Out","15 seconds after intentional freeze")
roundPhase="Running" players={}
local u,d=add("D") d.recovering=true d.idleRecoveryUntil=3
stepIdleTimeout(2) stepIdleTimeout(3)
stepIdleTimeout(17.99) assert(d.status=="Running")
stepIdleTimeout(18) assert(d.status=="Out" and not d.recovering,"broken recovery has bounded grace")
return "12 integration assertions passed using the installed elimination/status/watchdog functions, synthetic racers, and no DataStore writes."

