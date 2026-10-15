local function original(case)
 local clock=case.now or 10
 local os={clock=function() return clock end}
 local calls=0
 local lastLocalFlip=clock-(case.sinceFlip or 1)
 local soundMuteUntil=case.muted and clock+1 or 0
 local soundArmed=case.armed
 local soundAirSince=case.airSince and clock-case.airSince or nil
 local airborneLaunch=case.airborne
 local forwardBonus=12
 local lastGroundTime=-math.huge
 local lastGroundPosition,lastSupport,lastGroundSign
 local graceConsumed=true
 local landing={stops=0,plays=0}
 function landing:Stop() self.stops+=1 end
 function landing:Play() self.plays+=1 end
 local root={Position=Vector3.new(10,20,30),CFrame=CFrame.new(10,20,30),Anchored=case.anchored,
  AssemblyLinearVelocity=Vector3.new(-28,case.velocityY or 0,5),AssemblyMass=5}
 local speed,gravity,orientation={LineVelocity=28},{Force=Vector3.zero},{CFrame=CFrame.new()}
 function root:FindFirstChild(name)
  return ({RunnerForwardSpeed=speed,RunnerGravity=gravity,RunnerOrientation=orientation})[name]
 end
 local character={}
 function character:FindFirstChild(name) if name=="HumanoidRootPart" and not case.missingRoot then return root end end
 local player={Character=not case.missingCharacter and character or nil}
 function player:GetAttribute(name)
  if name=="RunnerLaneZ" and case.noLane then return nil end
  return ({RunnerStatus=case.status or "Running",RunnerLaneZ=case.noLane and false or 30.1,
   RunnerRaceStartedAt=0,RunnerSpeedMultiplier=1})[name]
 end
 local workspace={Gravity=196.2,GetServerTimeNow=function() return clock+1000 end}
 local GroundCheck={Support=function() calls+=1 return case.support,case.hit end}
 local landingRay={}
 local config={Gravity=120}
 local function currentSign() return case.sign or 1 end
 local Motion={Forward=function(_,multiplier,bonus) return (28+bonus)*multiplier end}
 local callback
 local RunService={PreSimulation={Connect=function(_,fn) callback=fn end}}

local function rememberGround(root)
 if os.clock()-lastLocalFlip<.12 then return nil end
 local sign=currentSign()
 local support=GroundCheck.Support(player.Character,root.Position,sign)
 if support and root.AssemblyLinearVelocity.Y*sign<=2 then
  lastGroundTime=workspace:GetServerTimeNow()
  lastGroundPosition=root.Position lastSupport=support lastGroundSign=sign
  graceConsumed=false
  return support
 end
end
local function updateLandingSound(character,root,sign)
 local now=os.clock()
 if now<soundMuteUntil then return end
 local supported=GroundCheck.Support(character,root.Position,sign)~=nil
 if supported then
  if soundArmed and soundAirSince and now-soundAirSince>=.1 and root.AssemblyLinearVelocity.Y*sign<=2 then
   landing:Stop()
   landing:Play()
  end
  soundArmed=true
  soundAirSince=nil
 elseif soundArmed then
  soundAirSince=soundAirSince or now
 end
end
local function stopLandingBounce(root)
	local character = player.Character
	if not character then return end
	landingRay.FilterDescendantsInstances = { character }

	local sign = currentSign()
	local velocity = root.AssemblyLinearVelocity
	if os.clock() - lastLocalFlip < 0.12 or math.abs(velocity.Y) > 12 then return end

 local _,hit=GroundCheck.Support(character,root.Position,sign)
	if hit and hit.Distance <= 3.08 and hit.Normal:Dot(Vector3.new(0, sign, 0)) > 0.9 then
		root.AssemblyLinearVelocity = Vector3.new(velocity.X, 0, 0)
	end
end
RunService.PreSimulation:Connect(function(deltaTime)
	local status = player:GetAttribute("RunnerStatus")
	if status ~= "Waiting" and status ~= "Running" then return end
	local laneZ = player:GetAttribute("RunnerLaneZ")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not laneZ or not root or root.Anchored then return end

	local sign = currentSign()
 local support=rememberGround(root)
 if support and os.clock()-lastLocalFlip>.12 then airborneLaunch=false end
 if not airborneLaunch then forwardBonus*=math.exp(-deltaTime/0.12) end
 local speed=root:FindFirstChild("RunnerForwardSpeed")
 if speed and status=="Running" then
  speed.LineVelocity=Motion.Forward(player:GetAttribute("RunnerRaceStartedAt"),player:GetAttribute("RunnerSpeedMultiplier") or 1,forwardBonus)
 end
 local gravity = root:FindFirstChild("RunnerGravity")
	local orientation = root:FindFirstChild("RunnerOrientation")
	if gravity then gravity.Force = Vector3.new(0, root.AssemblyMass * (workspace.Gravity - sign * config.Gravity), 0) end
	if orientation then orientation.CFrame = CFrame.lookAt(Vector3.zero, Vector3.new(-1,0,0), Vector3.new(0,sign,0)).Rotation end
	local velocity = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(velocity.X, velocity.Y, 0)
	updateLandingSound(character,root,sign)
	stopLandingBounce(root)
	local difference = laneZ - root.Position.Z
	if math.abs(difference) > 0.01 then
		root.CFrame += Vector3.new(0, 0, difference)
	end
end)
 local self={}
 function self:Step() callback(.016) end
 function self:Input() stopLandingBounce(root) rememberGround(root) end
 function self:Snapshot()
  return {
   groundTime=lastGroundTime,groundPosition=lastGroundPosition,support=lastSupport,sign=lastGroundSign,
   graceConsumed=graceConsumed,airborne=airborneLaunch,bonus=forwardBonus,
   soundArmed=soundArmed,soundAirSince=soundAirSince,stops=landing.stops,plays=landing.plays,
   velocity=root.AssemblyLinearVelocity,cframe=root.CFrame,force=gravity.Force,orientation=orientation.CFrame,
   speed=speed.LineVelocity,
  }
 end
 function self:Calls() return calls end
 return self

end
local function optimized(case)
 local clock=case.now or 10
 local os={clock=function() return clock end}
 local calls=0
 local lastLocalFlip=clock-(case.sinceFlip or 1)
 local soundMuteUntil=case.muted and clock+1 or 0
 local soundArmed=case.armed
 local soundAirSince=case.airSince and clock-case.airSince or nil
 local airborneLaunch=case.airborne
 local forwardBonus=12
 local lastGroundTime=-math.huge
 local lastGroundPosition,lastSupport,lastGroundSign
 local graceConsumed=true
 local landing={stops=0,plays=0}
 function landing:Stop() self.stops+=1 end
 function landing:Play() self.plays+=1 end
 local root={Position=Vector3.new(10,20,30),CFrame=CFrame.new(10,20,30),Anchored=case.anchored,
  AssemblyLinearVelocity=Vector3.new(-28,case.velocityY or 0,5),AssemblyMass=5}
 local speed,gravity,orientation={LineVelocity=28},{Force=Vector3.zero},{CFrame=CFrame.new()}
 function root:FindFirstChild(name)
  return ({RunnerForwardSpeed=speed,RunnerGravity=gravity,RunnerOrientation=orientation})[name]
 end
 local character={}
 function character:FindFirstChild(name) if name=="HumanoidRootPart" and not case.missingRoot then return root end end
 local player={Character=not case.missingCharacter and character or nil}
 function player:GetAttribute(name)
  if name=="RunnerLaneZ" and case.noLane then return nil end
  return ({RunnerStatus=case.status or "Running",RunnerLaneZ=case.noLane and false or 30.1,
   RunnerRaceStartedAt=0,RunnerSpeedMultiplier=1})[name]
 end
 local workspace={Gravity=196.2,GetServerTimeNow=function() return clock+1000 end}
 local GroundCheck={Support=function() calls+=1 return case.support,case.hit end}
 local landingRay={}
 local config={Gravity=120}
 local function currentSign() return case.sign or 1 end
 local Motion={Forward=function(_,multiplier,bonus) return (28+bonus)*multiplier end}
 local callback
 local RunService={PreSimulation={Connect=function(_,fn) callback=fn end}}

local function rememberGround(root,support,sampled)
 if os.clock()-lastLocalFlip<.12 then return nil end
 local sign=currentSign()
 if not sampled then support=GroundCheck.Support(player.Character,root.Position,sign) end
 if support and root.AssemblyLinearVelocity.Y*sign<=2 then
  lastGroundTime=workspace:GetServerTimeNow()
  lastGroundPosition=root.Position lastSupport=support lastGroundSign=sign
  graceConsumed=false
  return support
 end
end
local function updateLandingSound(root,sign,support)
 local now=os.clock()
 if now<soundMuteUntil then return end
 local supported=support~=nil
 if supported then
  if soundArmed and soundAirSince and now-soundAirSince>=.1 and root.AssemblyLinearVelocity.Y*sign<=2 then
   landing:Stop()
   landing:Play()
  end
  soundArmed=true
  soundAirSince=nil
 elseif soundArmed then
  soundAirSince=soundAirSince or now
 end
end
local function stopLandingBounce(root,hit,sampled)
	local character = player.Character
	if not character then return end

	local sign = currentSign()
	local velocity = root.AssemblyLinearVelocity
	if os.clock() - lastLocalFlip < 0.12 or math.abs(velocity.Y) > 12 then return end

 if not sampled then
  local _,checkedHit=GroundCheck.Support(character,root.Position,sign)
  hit=checkedHit
 end
	if hit and hit.Distance <= 3.08 and hit.Normal:Dot(Vector3.new(0, sign, 0)) > 0.9 then
		root.AssemblyLinearVelocity = Vector3.new(velocity.X, 0, 0)
	end
end
RunService.PreSimulation:Connect(function(deltaTime)
	local status = player:GetAttribute("RunnerStatus")
	if status ~= "Waiting" and status ~= "Running" then return end
	local laneZ = player:GetAttribute("RunnerLaneZ")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not laneZ or not root or root.Anchored then return end

	local sign = currentSign()
 local support,groundHit=GroundCheck.Support(character,root.Position,sign)
 local rememberedSupport=rememberGround(root,support,true)
 if rememberedSupport and os.clock()-lastLocalFlip>.12 then airborneLaunch=false end
 if not airborneLaunch then forwardBonus*=math.exp(-deltaTime/0.12) end
 local speed=root:FindFirstChild("RunnerForwardSpeed")
 if speed and status=="Running" then
  speed.LineVelocity=Motion.Forward(player:GetAttribute("RunnerRaceStartedAt"),player:GetAttribute("RunnerSpeedMultiplier") or 1,forwardBonus)
 end
 local gravity = root:FindFirstChild("RunnerGravity")
	local orientation = root:FindFirstChild("RunnerOrientation")
	if gravity then gravity.Force = Vector3.new(0, root.AssemblyMass * (workspace.Gravity - sign * config.Gravity), 0) end
	if orientation then orientation.CFrame = CFrame.lookAt(Vector3.zero, Vector3.new(-1,0,0), Vector3.new(0,sign,0)).Rotation end
	local velocity = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(velocity.X, velocity.Y, 0)
	updateLandingSound(root,sign,support)
	stopLandingBounce(root,groundHit,true)
	local difference = laneZ - root.Position.Z
	if math.abs(difference) > 0.01 then
		root.CFrame += Vector3.new(0, 0, difference)
	end
end)
 local self={}
 function self:Step() callback(.016) end
 function self:Input() stopLandingBounce(root) rememberGround(root) end
 function self:Snapshot()
  return {
   groundTime=lastGroundTime,groundPosition=lastGroundPosition,support=lastSupport,sign=lastGroundSign,
   graceConsumed=graceConsumed,airborne=airborneLaunch,bonus=forwardBonus,
   soundArmed=soundArmed,soundAirSince=soundAirSince,stops=landing.stops,plays=landing.plays,
   velocity=root.AssemblyLinearVelocity,cframe=root.CFrame,force=gravity.Force,orientation=orientation.CFrame,
   speed=speed.LineVelocity,
  }
 end
 function self:Calls() return calls end
 return self

end
local checks,cases=0,0
local function check(value,message) checks+=1 assert(value,message) end
local function compare(a,b)
 local old=a:Snapshot() local new=b:Snapshot()
 for key,value in old do check(new[key]==value,"mismatch "..key) end
 for key,value in new do check(old[key]==value,"missing field "..key) end
end
local surface={Parent=true}
for _,sign in {1,-1} do
 for _,velocity in {-13,-12,-3,-2,0,2,3,12,13} do
  for _,sinceFlip in {.119,.12,.121,1} do
   for _,kind in {"none","landing","distant","steep"} do
    for _,sound in {"cold","armed","muted"} do
     local case={sign=sign,velocityY=velocity,sinceFlip=sinceFlip,airborne=true,
      armed=sound~="cold",airSince=.2,muted=sound=="muted",
      support=kind~="none" and surface or nil,
      hit=kind~="none" and {Distance=kind=="distant" and 3.081 or 3.08,Normal=Vector3.new(0,sign*(kind=="steep" and .9 or 1),0)} or nil}
     local a,b=original(case),optimized(case)
     a:Step() b:Step() compare(a,b)
     check(b:Calls()==1,"one support query per eligible physics step")
     cases+=1
    end
   end
  end
 end
end
for _,status in {"Out","Finished","Loading","Spectating","Podium"} do
 local case={status=status,sign=1,velocityY=0,armed=true,airborne=true}
 local a,b=original(case),optimized(case) a:Step() b:Step() compare(a,b)
 check(a:Calls()==0 and b:Calls()==0,"inactive status skips support") cases+=1
end
for _,flag in {"anchored","missingCharacter","missingRoot","noLane"} do
 local case={status="Running",sign=1,velocityY=0,armed=true,airborne=true,[flag]=true}
 local a,b=original(case),optimized(case) a:Step() b:Step() compare(a,b)
 check(a:Calls()==0 and b:Calls()==0,"missing/anchored guard") cases+=1
end
local case={sign=1,velocityY=0,sinceFlip=1,armed=true,airSince=.2,airborne=true,
 support=surface,hit={Distance=3,Normal=Vector3.yAxis}}
local a,b=original(case),optimized(case)
a:Step() b:Step()
case.support=nil case.hit=nil
local beforeA,beforeB=a:Calls(),b:Calls()
a:Input() b:Input() compare(a,b)
check(a:Calls()-beforeA==2 and b:Calls()-beforeB==2,"input performs two fresh checks instead of old frame cache")
case.support=surface case.hit={Distance=3,Normal=Vector3.yAxis}
beforeA,beforeB=a:Calls(),b:Calls()
a:Input() b:Input() compare(a,b)
check(a:Calls()-beforeA==2 and b:Calls()-beforeB==2,"fresh input sees newly available support")
return {scenarios=cases,comparisons=checks}

