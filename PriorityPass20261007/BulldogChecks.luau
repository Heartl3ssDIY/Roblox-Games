local Rules = (function()
local Rules = {}

function Rules.IsInside(x, y, z, halfX, halfY, halfZ)
	return math.abs(x) <= halfX and math.abs(y) <= halfY and math.abs(z) <= halfZ
end

function Rules.DepartureExpired(mustLeave, deadline, now)
	return mustLeave and deadline > 0 and now >= deadline
end

function Rules.CrossingResolved(unresolvedRunners)
	return unresolvedRunners == 0
end

function Rules.Outcome(runners, bulldogs, tagged, participants, timedOut, lastRunnerWins)
	if participants == 0 then
		return "None"
	end
	if runners == 0 then
		return "Bulldogs"
	end
	if lastRunnerWins or timedOut or bulldogs + tagged == 0 then
		return "Runners"
	end
	return nil
end

function Rules.CanTag(phase, runnerRole, runnerDeparted, runnerArrived, inField, bulldogFrozen)
	return phase == "Crossing"
		and runnerRole == "Runner"
		and runnerDeparted
		and not runnerArrived
		and inField
		and not bulldogFrozen
end

return Rules


end)()
local Service = {}
local workspace = {GetServerTimeNow=function() return 100 end}
local Players = {}
local Vector3 = {new=function(x,y,z) return {Magnitude=math.sqrt(x*x+y*y+z*z)} end}
local function alive(r) return r.character and r.character.Parent and r.root and r.root.Parent and r.humanoid and r.humanoid.Health>0 end
local function setAttribute(p,k,v) p.attrs[k]=v end
function Service:_counts()
	local runners, bulldogs, tagged, participants, unresolved = 0, 0, 0, 0, 0
	for _, record in pairs(self.records) do
		if record.participating then
			participants = participants + 1
			if record.role == "Runner" then
				runners = runners + 1
				if not record.arrived then
					unresolved = unresolved + 1
				end
			elseif record.role == "Bulldog" then
				bulldogs = bulldogs + 1
			elseif record.role == "Tagged" then
				tagged = tagged + 1
			end
		end
	end
	return runners, bulldogs, tagged, participants, unresolved
end


function Service:_sprintCapacity(record)
	local maximum = record.participating and (record.role == "Bulldog" and record.initialBulldog
		and self:_setting("InitialBulldogSprintSeconds", 15, 0.1) or self:_setting("RunnerSprintSeconds", 10, 0.1)) or 0
	record.sprintMax = maximum
	record.sprintRemaining = math.clamp(record.sprintRemaining or maximum, 0, maximum)
	setAttribute(record.player, "BBInitialBulldog", record.initialBulldog == true)
	setAttribute(record.player, "BBSprintMax", maximum)
	setAttribute(record.player, "BBSprintRemaining", math.floor(record.sprintRemaining * 10) / 10)
end


function Service:_applyMovementSpeed(record, now)
	if not record.participating or not record.humanoid or not record.humanoid.Parent then return end
	local base = record.role == "Bulldog" and self:_setting("BulldogWalkSpeed", 18, 0) or self:_setting("RunnerWalkSpeed", 16, 0)
	local multiplier = 1
	if self:_movementAllowed(record, now) then
		if record.sprintHeld and record.sprinting and now < (record.sprintLeaseEndsAt or 0) then
			multiplier = 1 + (self:_setting("SprintMultiplier", 2.5, 1) - 1) * (record.sprintFraction or 0)
		end
		if now < (record.boostEndsAt or 0) then multiplier = math.max(multiplier, self:_setting("DodgeBoostMultiplier", 2, 1)) end
	end
	if record.movement then record.movement.WalkSpeed = base end
	record.humanoid.WalkSpeed = record.frozen and 0 or base * multiplier
end


function Service:_publishMovement(record)
	setAttribute(record.player, "BBSprintRemaining", math.floor((record.sprintRemaining or 0) * 10) / 10)
	setAttribute(record.player, "BBSprintMax", record.sprintMax or 0)
	setAttribute(record.player, "BBSprinting", record.sprinting == true)
	setAttribute(record.player, "BBSprintExhausted", record.sprintExhausted == true)
	setAttribute(record.player, "BBDodgeReadyAt", record.dodgeReadyAt or 0)
	setAttribute(record.player, "BBBoostEndsAt", record.boostEndsAt or 0)
end


function Service:_releaseSprint(record)
	record.sprintHeld = false
	record.sprinting = false
	record.sprintFraction = 0
	record.sprintLeaseEndsAt = 0
end




function Service:_updateMovement(record, dt, now)
	if not record.participating then return end
	dt = math.clamp(dt, 0, 0.25)
	self:_sprintCapacity(record)
	if record.sprintHeld and now >= (record.sprintLeaseEndsAt or 0) then self:_releaseSprint(record) end
	local allowed = self:_movementAllowed(record, now)
	if not allowed then self:_releaseSprint(record) end
	local speed = alive(record) and Vector3.new(record.root.AssemblyLinearVelocity.X, 0, record.root.AssemblyLinearVelocity.Z).Magnitude or 0
	record.sprinting = allowed and record.sprintHeld and record.sprintRemaining > 0 and speed > 1
	record.sprintFraction = 0
	if record.sprinting then
		record.sprintFraction = math.min(1, record.sprintRemaining / math.max(dt, 0.0001))
		record.sprintRemaining = math.max(0, record.sprintRemaining - dt)
	elseif record.sprintRemaining <= 0 or not record.sprintHeld then
		record.sprintRemaining = math.min(record.sprintMax, record.sprintRemaining + record.sprintMax / self:_setting("SprintRefillSeconds", 15, 0.1) * dt)
	end
	record.sprintExhausted = record.sprintRemaining <= 0
	self:_publishMovement(record)
	self:_applyMovementSpeed(record, now)
end


function Service:_keepRunnerLegal(record, now)
	local position = record.root.Position
	if not self:_inside(self.bounds, position) then
		self:_caught(record, "Left the arena", now)
		self:_teleport(record, self:_spawnCFrame("Bulldog", record.spawnIndex))
		return
	end
	if record.arrived then
		if not self:_inside(self.safeZones[self.destination], position) then
			self:_teleport(record, record.safeCFrame or self:_spawnCFrame(self.destination, record.spawnIndex))
		end
		return
	end
	if not record.departed then
		if self:_pastSource(position) then
			record.departed = true
			self:_departure(record, false, 0)
			setAttribute(record.player, "BBStatus", "Crossing")
		elseif Rules.DepartureExpired(record.mustLeave, record.departureEndsAt, now) then
			self:_forfeit(record, now)
			return
		end
	end
	if record.departed then
		if self:_inside(self.safeZones[self.source], position) or not self:_pastSource(position) then
			local fallback = record.lastFieldCFrame
			if not fallback then
				local point = self.bounds.CFrame:PointToObjectSpace(position)
				local z = self.source == "North" and self.northZ + 4 or self.southZ - 4
				local world = self.bounds.CFrame:PointToWorldSpace(Vector3.new(point.X, point.Y, z))
				fallback = CFrame.new(world) * record.root.CFrame.Rotation
			end
			self:_teleport(record, fallback)
			position = record.root.Position
		end
		if self:_inside(self.safeZones[self.destination], position) then
			record.arrived = true
			record.safeCFrame = record.root.CFrame
			self:_sprintCapacity(record)
			record.sprintRemaining = record.sprintMax
			record.sprintExhausted = false
			self:_releaseSprint(record)
			self:_publishMovement(record)
			setAttribute(record.player, "BBStatus", "Safe")
		elseif self:_inField(position) then
			record.lastFieldCFrame = record.root.CFrame
		end
	end
end


function Service:_outcome()
	local runners, bulldogs, tagged, participants = self:_counts()
	local lastRunnerWins = false
	if self.mode == "Round" and (self.initialRunnerCount or 0) > 1 and runners == 1 then
		for _, record in pairs(self.records) do
			if record.participating and record.role == "Runner" and alive(record) then
				lastRunnerWins = true
				break
			end
		end
	end
	return Rules.Outcome(runners, bulldogs, tagged, participants, self.endsAt > 0 and workspace:GetServerTimeNow() >= self.endsAt, lastRunnerWins)
end


function Service:_finishCrossing()
	for _, record in pairs(self.records) do
		if record.participating then
			if record.role == "Tagged" or record.pendingBulldog then
				record.pendingBulldog = false
				self:_setRole(record, "Bulldog", "Bulldog")
			end
			if record.role == "Bulldog" then
				if alive(record) then self:_teleport(record, self:_spawnCFrame("Bulldog", record.spawnIndex)) end
				self:_unfreeze(record)
			end
		end
	end
	self.source, self.destination = self.destination, self.source
end


function Service:_caught(record, status, now, attacker)
	now = now or workspace:GetServerTimeNow()
	if not self.active or not record.participating or record.role ~= "Runner" or self.phase == "Results" or (self.endsAt > 0 and now >= self.endsAt) then
		return false
	end
	if alive(record) and self:_outcome() == "Runners" then return false end
	record.arrived = false
	record.departed = false
	self:_departure(record, false, 0)
	self:_setRole(record, "Tagged", status or "Tagged")
	if attacker and alive(record) then
		self:_ragdoll(record, attacker, now)
		local serial = attacker.player:GetAttribute("PCBatHitSerial")
		setAttribute(attacker.player, "PCBatHitSerial", (typeof(serial) == "number" and serial or 0) + 1)
	else
		self:_freeze(record)
	end
	return true
end


function Service:_forfeit(record, now)
	if record.role ~= "Runner" or (self.endsAt > 0 and now >= self.endsAt) or self:_outcome() == "Runners" then
		return
	end
	record.pendingBulldog = true
	record.arrived = false
	self:_departure(record, false, 0)
	self:_setRole(record, "Bulldog", "Departure expired")
	self:_teleport(record, self:_spawnCFrame("Bulldog", record.spawnIndex))
	self:_freeze(record)
end


function Service:Move(player, action, value)
	local record = self.records[player]
	if not record or record.isBot or player.Parent ~= Players then return { ok = false, message = "Your character is not ready." } end
	if action == "Dodge" then return { ok = false, message = "Dodge is temporarily disabled." } end
	if action == "Sprint" and value == false then
		self:_releaseSprint(record)
		self:_publishMovement(record)
		self:_applyMovementSpeed(record, workspace:GetServerTimeNow())
		return { ok = true }
	end
	local now = workspace:GetServerTimeNow()
	if not self:_movementAllowed(record, now) then return { ok = false, message = "Wait for the crossing." } end
	if action == "Sprint" then
		if typeof(value) ~= "boolean" then return { ok = false, message = "Unknown sprint request." } end
		record.sprintHeld = true
		record.sprintLeaseEndsAt = now + 1
		self:_applyMovementSpeed(record, now)
		return { ok = true }
	end
	if action ~= "Dodge" or (value ~= -1 and value ~= 1) then return { ok = false, message = "Unknown move." } end
	if record.role ~= "Runner" or not record.departed or record.arrived or not self:_inField(record.root.Position)
		then return { ok = false, message = "Dodge while crossing the field." } end
	if now < (record.dodgeReadyAt or 0) then return { ok = false, message = "Dodge is recharging." } end
	local right = self.bounds.CFrame.RightVector
	local direction = Vector3.new(right.X, 0, right.Z).Unit * value
	local params = self:_movementRayParameters()
	if not self:_dodgeGrounded(record, params) then return {ok=false,message="Dodge while on the ground."} end
	local duration = math.clamp(self:_setting("DodgeDurationSeconds", 0.32, 0.2), 0.2, 0.5)
	local distance = math.clamp(self:_setting("DodgeDistance", 8, 3), 3, 10)
	local look = self.bounds.CFrame.LookVector
	local forward = Vector3.new(look.X, 0, look.Z).Unit
	local forwardSpeed = math.clamp(record.root.AssemblyLinearVelocity:Dot(forward), -record.humanoid.WalkSpeed, record.humanoid.WalkSpeed)
	local forwardVelocity = forward * forwardSpeed
	local travel = direction * distance + forwardVelocity * duration
	local fraction = self:_clipDodgeTravel(record, travel, params)
	if distance * fraction < 0.75 then return {ok=false,message="No room to dodge."} end
	distance, forwardVelocity = distance * fraction, forwardVelocity * fraction
	local threatened = self:_threat(record, params)
	if threatened then
		record.pendingEscape = { checkAt = now + duration, token = self.currentRound, crossing = self.crossingNumber,
			character = record.character, startPosition = record.root.Position }
	end
	if not self:_startDodgeBurst(record, direction, now, duration, distance, forwardVelocity, params) then record.pendingEscape=nil return {ok=false,message="Your character cannot dodge yet."} end
	record.dodgeReadyAt = now + self:_setting("DodgeCooldownSeconds", 4, 0.1)
	self:_publishMovement(record)
	return { ok = true, startedAt = now, direction = direction, duration = duration }
end


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
