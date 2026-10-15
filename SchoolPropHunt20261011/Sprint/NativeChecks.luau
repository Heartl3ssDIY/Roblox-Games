local checks, failures = 0, {}
local function check(ok, name) checks += 1 if not ok then table.insert(failures,name) end end
local host=Instance.new("Folder")
local now=100
local workspace={GetServerTimeNow=function() return now end}
local Players={list={}}
function Players:GetPlayers() return self.list end
local function set(player,name,value) player:SetAttribute(name,value) end
local setAttribute,attribute=set,set
local function alive(record) return record and record.humanoid and record.humanoid.Health>0 and record.root and record.root.Parent end
local function player()
 local p={attributes={},Parent=Players}
 function p:GetAttribute(k) return self.attributes[k] end
 function p:SetAttribute(k,v) self.attributes[k]=v end
 return p
end
local function record()
 local char=Instance.new("Model") char.Parent=host
 local root=Instance.new("Part") root.Name="HumanoidRootPart" root.Parent=char root.AssemblyLinearVelocity=Vector3.new(8,0,0)
 local hum=Instance.new("Humanoid") hum.Parent=char
 return {player=player(),character=char,root=root,humanoid=hum,participating=true,role="Runner",sprintHeld=true,sprintRemaining=10,sprintMax=10,sprintLeaseEndsAt=1000,sprintExhausted=false,stamina=5,original={JumpPower=50,JumpHeight=7.2,Anchored=false}}
end
local function setting(_,name,fallback) return fallback end
local BB={_setting=setting,_movementAllowed=function(_,r) return not r.frozen end,_inside=function(self) return self.safe==true end,_publishMovement=function() end,safeZones={North={},South={}}}
function BB:_releaseSprint(r) r.sprintHeld=false r.sprinting=false r.sprintLeaseEndsAt=0 end
local Mud={_setting=setting,_canAct=function(_,r) return not r.frozen end,_publishRecord=function() end}
local Bot={_setting=setting}
local Tag={_setting=setting,entries={},tag={active=true,phase="Playing",records={},currentRound={}}}
function Tag:_active(_,r) return r and not r.frozen and not r.ragdoll and r.humanoid.Health>0 end
local DG={_setting=setting,phase="Playing"}
local MAX_STAMINA=5

function BB:_updateMovement(record, dt, now)
	if not record.participating then return end
	dt = math.clamp(dt, 0, 0.25)
	self:_sprintCapacity(record)
	if record.sprintHeld and now >= (record.sprintLeaseEndsAt or 0) then self:_releaseSprint(record) end
	local allowed = self:_movementAllowed(record, now)
	if not allowed then self:_releaseSprint(record) end
	local speed = alive(record) and Vector3.new(record.root.AssemblyLinearVelocity.X, 0, record.root.AssemblyLinearVelocity.Z).Magnitude or 0
	if record.role == "Runner" and alive(record) and (self:_inside(self.safeZones.North, record.root.Position) or self:_inside(self.safeZones.South, record.root.Position)) then
		record.sprintRemaining = record.sprintMax
	end
	local draining = allowed and record.sprintHeld and record.sprintRemaining > 0 and speed > 1
	if draining then
		record.sprintRemaining = math.max(0, record.sprintRemaining - dt)
	elseif record.sprintRemaining <= 0 or not record.sprintHeld then
		record.sprintRemaining = math.min(record.sprintMax, record.sprintRemaining + record.sprintMax / self:_setting("SprintRefillSeconds", 15, 0.1) * dt)
	end
	record.sprintExhausted = record.sprintRemaining <= 0
	record.sprinting = allowed and record.sprintHeld and not record.sprintExhausted and speed > 1
	self:_publishMovement(record)
	self:_applyMovementSpeed(record, now)
end

function Mud:_tickSprint(record, dt, now)
	if not record.participating then return end
	if now >= (record.sprintLeaseEndsAt or 0) or not self:_canAct(record, now) then record.sprintHeld = false end
	local speed = alive(record) and Vector3.new(record.root.AssemblyLinearVelocity.X, 0, record.root.AssemblyLinearVelocity.Z).Magnitude or 0
	local draining = record.sprintHeld and record.sprintRemaining > 0 and speed > 1
	if draining then
		record.sprintRemaining = math.max(0, record.sprintRemaining - dt)
	else
		record.sprintRemaining = math.min(record.sprintMax, record.sprintRemaining + record.sprintMax / self:_setting("SprintRefillSeconds", 15, 0.1) * dt)
	end
	record.sprintExhausted = record.sprintRemaining <= 0
	record.sprinting = record.sprintHeld and not record.sprintExhausted and speed > 1
	self:_movement(record)
	self:_publishRecord(record)
end

function Bot:_botSprint(bot, now, wantsSprint)
	local dt = math.clamp(now - (bot.lastSprintAt or now), 0, 0.25)
	bot.lastSprintAt = now
	local capacity = math.clamp(self:_setting("SprintSeconds", 10, 1), 1, 30)
	bot.botSprintRemaining = math.clamp(bot.botSprintRemaining or capacity, 0, capacity)
	if wantsSprint and bot.botSprintRemaining > 0 then
		bot.botSprintRemaining = math.max(0, bot.botSprintRemaining - dt)
	else
		bot.botSprintRemaining = math.min(capacity, bot.botSprintRemaining + dt * capacity / self:_setting("SprintRefillSeconds", 15, 1))
	end
	bot.botSprintExhausted = bot.botSprintRemaining <= 0
	local sprinting = wantsSprint and not bot.botSprintExhausted
	local speed = bot.role == "Tagger" and self:_setting("TaggerWalkSpeed", 18, 1) or self:_setting("RunnerWalkSpeed", 16, 1)
	bot.humanoid.WalkSpeed = speed * (sprinting and math.clamp(self:_setting("SprintMultiplier", 2.5, 1), 1, 2.5) or 1)
end

function Tag:_tick(delta)
 local now=workspace:GetServerTimeNow()
 for _,player in ipairs(Players:GetPlayers()) do
  local record=self.tag.records[player]
  local participating=record and record.participating and player:GetAttribute("TGParticipating")==true
   and not player:GetAttribute("BBParticipating") and not player:GetAttribute("MDParticipating")
  local entry=self.entries[player]
  if not participating then
   if entry then self.entries[player]=nil end
   set(player,"TGSprinting",false)
   set(player,"TGSprintExhausted",false)
   set(player,"TGSprintRemaining",self:_setting("SprintSeconds",10,0.1))
  else
   local maximum=self:_setting("SprintSeconds",10,0.1)
   local round=self.tag.currentRound or self.tag.roundNumber
   if not entry or entry.round~=round then
    entry={remaining=maximum,held=false,locked=false,lease=0,character=record.character,round=round}
    self.entries[player]=entry
   elseif entry.character~=record.character then
    entry.character=record.character
    entry.held=false entry.lease=0
   end
   entry.remaining=math.clamp(entry.remaining,0,maximum)
   if now>entry.lease then entry.held=false end
   local canMove=self:_active(player,record)
   local velocity=record.root and record.root.AssemblyLinearVelocity or Vector3.zero
   local moving=Vector3.new(velocity.X,0,velocity.Z).Magnitude>1
   local draining=canMove and entry.held and entry.remaining>0 and moving
   if draining then
    entry.remaining=math.max(0,entry.remaining-delta)
   else
    entry.remaining=math.min(maximum,entry.remaining+delta*maximum/self:_setting("SprintRefillSeconds",15,0.1))
   end
   entry.locked=entry.remaining<=0
   local sprinting=canMove and entry.held and not entry.locked and moving
   if record.humanoid and record.humanoid.Health>0 then
    local fallback=record.role=="Tagger" and 18 or 16
    local base=self:_setting(record.role=="Tagger" and "TaggerWalkSpeed" or "RunnerWalkSpeed",fallback,0)
    record.humanoid.WalkSpeed=(record.frozen or record.ragdoll or player:GetAttribute("TGRagdolled")==true) and 0 or base*(sprinting and self:_setting("SprintMultiplier",2.5,1) or 1)
   end
   set(player,"TGSprintMax",maximum)
   set(player,"TGSprintRemaining",entry.remaining)
   set(player,"TGSprinting",sprinting)
   set(player,"TGSprintExhausted",entry.locked)
  end
 end
end

function BB:_applyMovementSpeed(record, now)
	if not record.participating or not record.humanoid or not record.humanoid.Parent then return end
	local base = record.role == "Bulldog" and self:_setting("BulldogWalkSpeed", 18, 0) or self:_setting("RunnerWalkSpeed", 16, 0)
	local multiplier = 1
	if self:_movementAllowed(record, now) then
		if record.sprintHeld and not record.sprintExhausted and (record.sprintRemaining or 0) > 0
			and now < (record.sprintLeaseEndsAt or 0) then multiplier = self:_setting("SprintMultiplier", 2.5, 1) end
		if now < (record.boostEndsAt or 0) then multiplier = math.max(multiplier, self:_setting("DodgeBoostMultiplier", 2, 1)) end
	end
	if record.movement then record.movement.WalkSpeed = base end
	record.humanoid.WalkSpeed = record.frozen and 0 or base * multiplier
end

function BB:_sprintCapacity(record)
	local maximum = record.participating and (record.role == "Bulldog" and record.initialBulldog
		and self:_setting("InitialBulldogSprintSeconds", 15, 0.1) or self:_setting("RunnerSprintSeconds", 10, 0.1)) or 0
	record.sprintMax = maximum
	record.sprintRemaining = math.clamp(record.sprintRemaining or maximum, 0, maximum)
	setAttribute(record.player, "BBInitialBulldog", record.initialBulldog == true)
	setAttribute(record.player, "BBSprintMax", maximum)
	setAttribute(record.player, "BBSprintRemaining", math.floor(record.sprintRemaining * 10) / 10)
end

function Mud:_movement(record)
	if not record.participating or not alive(record) then return end
	local humanoid = record.humanoid
	if not record.originalMovement then record.originalMovement = { WalkSpeed = humanoid.WalkSpeed, JumpPower = humanoid.JumpPower, JumpHeight = humanoid.JumpHeight, AutoRotate = humanoid.AutoRotate } end
	local multiplier = not record.frozen and record.sprinting and not record.sprintExhausted and (record.sprintRemaining or 0) > 0 and workspace:GetServerTimeNow() < (record.sprintLeaseEndsAt or 0) and self:_setting("SprintMultiplier", 2.5, 1) or 1
	humanoid.WalkSpeed = record.frozen and 0 or self:_setting("BaseSpeed", 16, 0) * multiplier
	humanoid.JumpPower = record.frozen and 0 or record.originalMovement.JumpPower
	humanoid.JumpHeight = record.frozen and 0 or record.originalMovement.JumpHeight
	humanoid.AutoRotate = not record.frozen and record.originalMovement.AutoRotate
	if record.frozen then
		record.lockedCFrame = record.lockedCFrame or record.root.CFrame
		humanoid.Jump = false
		pcall(function() record.root:SetNetworkOwner(nil) end)
	elseif not record.isBot then pcall(function() record.root:SetNetworkOwnershipAuto() end) end
end

function DG:_movement(record)
	if not alive(record) then return end
	local sitting = record.participating and record.role == "Duck"
	local locked = sitting or record.frozen or record.ragdoll
	local allowed = record.participating and self.phase == "Playing" and not locked and (record.role == "Picker" or record.role == "Runner" or record.role == "Goose")
	local sprinting = allowed and record.sprintHeld and record.stamina > 0
	local anchor = sitting or (record.frozen and not record.ragdoll) or record.original.Anchored
	if record.root.Anchored ~= anchor then
		if anchor then pcall(function() record.root:SetNetworkOwner(nil) end) end
		record.root.Anchored = anchor
		if not anchor then pcall(function() record.root:SetNetworkOwnershipAuto() end) end
	end
	record.humanoid.WalkSpeed = locked and 0 or sprinting and 26 or self:_setting("BaseSpeed", 16, 8, 24)
	record.humanoid.JumpPower, record.humanoid.JumpHeight = locked and 0 or record.original.JumpPower, locked and 0 or record.original.JumpHeight
	attribute(record.player, "DGSprinting", sprinting == true)
	attribute(record.player, "DGStamina", math.floor(record.stamina * 10) / 10)
	attribute(record.player, "DGMaxStamina", MAX_STAMINA)
end

local ok,err=xpcall(function()
 for _,spec in ipairs({{name="Bulldog",service=BB,method="_updateMovement"},{name="Mud",service=Mud,method="_tickSprint"}}) do
  local r=record() local service=spec.service local step=service[spec.method]
  r.sprintRemaining=.001 r.sprintExhausted=true
  step(service,r,0,now)
  check(r.sprinting and not r.sprintExhausted and r.humanoid.WalkSpeed>16,spec.name.." any positive energy overrides stale exhausted flag")
  r.sprintRemaining=0 r.sprintExhausted=true
  step(service,r,0,now)
  check(not r.sprinting and r.humanoid.WalkSpeed==16,spec.name.." empty stops sprint")
  step(service,r,.05,now)
  check(r.sprintRemaining>0 and r.sprintRemaining<.5 and r.sprinting and r.humanoid.WalkSpeed>16,spec.name.." first small recharge resumes while held")
  local boosted=0
  for i=1,20 do now+=.05 step(service,r,.05,now) if r.humanoid.WalkSpeed>16 then boosted+=1 end end
  check(boosted>0 and boosted<20,spec.name.." held-empty repeated recharge gives real movement instead of permanent lock")
  r.sprintHeld=false local previous=r.sprintRemaining step(service,r,.05,now)
  check(r.sprintRemaining>previous and not r.sprinting and r.humanoid.WalkSpeed==16,spec.name.." release refills and stops boosting")
  r.sprintHeld=true r.frozen=true step(service,r,.05,now)
  check(not r.sprintHeld and not r.sprinting and r.humanoid.WalkSpeed==0,spec.name.." frozen cannot sprint")
  r.frozen=false r.sprintHeld=true r.sprintLeaseEndsAt=now-.01 step(service,r,.05,now)
  check(not r.sprintHeld and not r.sprinting,spec.name.." expired hold lease releases")
  r.sprintRemaining=10 r.sprintHeld=false step(service,r,.05,now)
  check(r.sprintRemaining==10 and r.sprintMax==10,spec.name.." original ten second capacity remains")
 end
 local bulldog=record() bulldog.role="Bulldog" bulldog.initialBulldog=true bulldog.sprintHeld=false bulldog.sprintRemaining=15
 BB:_updateMovement(bulldog,0,now)
 check(bulldog.sprintMax==15 and bulldog.sprintRemaining==15,"Initial Bulldog fifteen-second capacity remains")
 local safe=record() safe.sprintRemaining=.1 safe.sprintHeld=false BB.safe=true BB:_updateMovement(safe,.05,now) BB.safe=false
 check(safe.sprintRemaining==10,"Bulldog safe zone still restores stamina")
 local r=record() local p=r.player p:SetAttribute("TGParticipating",true)
 Players.list={p} Tag.tag.records[p]=r Tag.entries[p]={remaining=.001,held=true,locked=true,lease=1000,character=r.character,round=Tag.tag.currentRound}
 local entry=Tag.entries[p]
 Tag:_tick(0)
 check(not entry.locked and p:GetAttribute("TGSprinting") and r.humanoid.WalkSpeed>16,"Tag any positive energy clears exhausted lock")
 entry.remaining=0 entry.locked=true Tag:_tick(0)
 check(not p:GetAttribute("TGSprinting") and r.humanoid.WalkSpeed==16,"Tag empty stops sprint")
 Tag:_tick(.05)
 check(entry.remaining>0 and entry.remaining<.5 and not entry.locked and p:GetAttribute("TGSprinting") and r.humanoid.WalkSpeed>16,"Tag first small recharge resumes while held")
 local boosted=0 for i=1,20 do now+=.05 Tag:_tick(.05) if r.humanoid.WalkSpeed>16 then boosted+=1 end end
 check(boosted>0 and boosted<20,"Tag held-empty recharge keeps giving movement")
 entry.held=false local before=entry.remaining Tag:_tick(.05)
 check(entry.remaining>before and not p:GetAttribute("TGSprinting"),"Tag release refills")
 entry.held=true r.frozen=true Tag:_tick(.05)
 check(not p:GetAttribute("TGSprinting") and r.humanoid.WalkSpeed==0,"Tag frozen stops sprint")
 r.frozen=false entry.held=true entry.lease=now-.1 Tag:_tick(.05)
 check(not entry.held and not p:GetAttribute("TGSprinting"),"Tag hold lease still expires")
 entry.remaining=10 entry.held=false Tag:_tick(.05)
 check(entry.remaining==10 and p:GetAttribute("TGSprintMax")==10,"Tag original ten-second capacity remains")
 local bot=record() bot.botSprintRemaining=.001 bot.botSprintExhausted=true bot.lastSprintAt=now
 Bot:_botSprint(bot,now,true)
 check(bot.humanoid.WalkSpeed>16 and not bot.botSprintExhausted,"Tag bot also resumes from any positive energy")
 bot.botSprintRemaining=0 Bot:_botSprint(bot,now,true)
 check(bot.humanoid.WalkSpeed==16,"Tag bot empty stops sprint")
 now+=.05 Bot:_botSprint(bot,now,true)
 check(bot.botSprintRemaining>0 and bot.botSprintRemaining<.5 and bot.humanoid.WalkSpeed>16,"Tag bot first recharge resumes")
 local duck=record() duck.role="Runner" duck.stamina=.001 DG:_movement(duck)
 check(duck.humanoid.WalkSpeed==26 and duck.player:GetAttribute("DGSprinting"),"Duck Duck Goose any positive stamina already sprints")
 duck.stamina=0 DG:_movement(duck)
 check(duck.humanoid.WalkSpeed==16 and not duck.player:GetAttribute("DGSprinting"),"Duck Duck Goose zero stamina stops")
 duck.stamina=.075 DG:_movement(duck)
 check(duck.humanoid.WalkSpeed==26 and duck.player:GetAttribute("DGMaxStamina")==5,"Duck Duck Goose partial resume retains five-second capacity")
 duck.role="Duck" DG:_movement(duck)
 check(duck.humanoid.WalkSpeed==0 and not duck.player:GetAttribute("DGSprinting"),"Seated ducks still cannot sprint")
end,debug.traceback)
host:Destroy()
if not ok then table.insert(failures,err) end
return game:GetService("HttpService"):JSONEncode({passed=ok and #failures==0,checks=checks,failures=failures})

