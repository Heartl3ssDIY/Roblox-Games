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

function Rules.Outcome(runners, bulldogs, tagged, participants, timedOut, lastRunnerWins, lastRunnerArrived)
	if participants == 0 then
		return "None"
	end
	if runners == 0 then
		return "Bulldogs"
	end
	if lastRunnerWins and runners == 1 then
		if lastRunnerArrived then return "Runners" end
		if timedOut then return "Bulldogs" end
		return nil
	end
	if timedOut or bulldogs + tagged == 0 then
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
local now = 100
local workspace = { GetServerTimeNow = function() return now end }
local Service = {}
local function alive(r) return r.character and r.character.Parent and r.root and r.root.Parent and r.humanoid and r.humanoid.Health > 0 end
local function setAttribute(p,k,v) p.attrs[k] = v end
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


function Service:_outcome()
	local runners, bulldogs, tagged, participants = self:_counts()
	local lastRunnerArrived = false
	if self.lastRunnerWins and runners == 1 then
		for _, record in pairs(self.records) do
			if record.participating and record.role == "Runner" and alive(record) then
				lastRunnerArrived = record.arrived == true and record.departed == true
				break
			end
		end
	end
	return Rules.Outcome(runners, bulldogs, tagged, participants, self.endsAt > 0 and workspace:GetServerTimeNow() >= self.endsAt,
		self.lastRunnerWins == true, lastRunnerArrived)
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
			setAttribute(record.player, "BBStatus", "Safe")
		elseif self:_inField(position) then
			record.lastFieldCFrame = record.root.CFrame
		end
	end
end


function Service:_caught(record, status, now, attacker)
	now = now or workspace:GetServerTimeNow()
	if not self.active or not record.participating or record.role ~= "Runner" or self.phase == "Results" or (self.endsAt > 0 and now >= self.endsAt) then
		return false
	end
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


local n=0
local function check(condition, message) n+=1 assert(condition, message) end
local function runner()
 return {participating=true,role="Runner",arrived=false,departed=false,player={attrs={}},character={Parent=true},root={Parent=true,Position="Source",CFrame="Source"},humanoid={Health=100}}
end
local a,b=runner(),runner()
local dog={participating=true,role="Bulldog"}
local s=setmetatable({active=true,phase="Crossing",records={a,b,dog},lastRunnerWins=true,endsAt=200,bounds="Bounds",source="North",destination="South",safeZones={North="Source",South="Destination"}}, {__index=Service})
function s:_inside(part, position) return part=="Bounds" or part==position end
function s:_pastSource(position) return position~="Source" end
function s:_inField(position) return position=="Field" end
function s:_departure() end
function s:_setRole(r, role) r.role=role end
function s:_freeze(r) r.frozen=true end
check(s:_outcome()==nil,"Multiple runners keep playing")
check(s:_caught(a,"Tagged",100),"First runner can be caught")
check(s:_outcome()==nil,"Sole remaining runner in source safe zone must still cross")
b.root.Position="Field" b.root.CFrame="Field"
s:_keepRunnerLegal(b,100)
check(b.departed and not b.arrived,"Field entry is not arrival")
check(s:_outcome()==nil,"Sole runner mid-crossing must still reach other side")
check(Rules.CanTag("Crossing","Runner",b.departed,b.arrived,true,false),"Last runner remains taggable during crossing")
b.root.Position="Destination" b.root.CFrame="Destination"
s:_keepRunnerLegal(b,100)
check(b.arrived and b.departed and b.player.attrs.BBStatus=="Safe","Actual opposite-zone arrival confirms safe")
check(s:_outcome()=="Runners","Completed crossing grants immediate sole runner win")
check(not Rules.CanTag("Crossing","Runner",b.departed,b.arrived,false,false),"Safe last runner is protected")
b.departed=false
check(s:_outcome()==nil,"An arrived flag without departure does not grant early win")
b.departed=true b.humanoid.Health=0
check(s:_outcome()==nil,"Dead runner cannot claim an early crossing win")
b.humanoid.Health=100 b.arrived=false b.departed=true
check(s:_caught(b,"Tagged",100) and s:_outcome()=="Bulldogs","Last runner can be caught before arrival")
local c=runner()
s.records={c,dog} s.lastRunnerWins=false
check(s:_outcome()==nil,"Round beginning with a single runner remains playable")
c.departed=true c.arrived=true
check(s:_outcome()==nil,"Original single-runner match does not end on its first crossing")
s.lastRunnerWins=true c.arrived=false now=201
check(s:_outcome()=="Bulldogs","Timeout cannot award lone runner before finishing crossing")
c.arrived=true
check(s:_outcome()=="Runners","Already-completed crossing wins at timeout")
s.records={runner(),runner(),dog}
check(s:_outcome()=="Runners","Ordinary timer rule for multiple survivors preserved")
s.records={dog}
check(s:_outcome()=="Bulldogs","No runners means Bulldogs win")
s.records={}
check(s:_outcome()=="None","Empty round cancels")
check(Rules.Outcome(2,0,0,2,false,false,false)=="Runners","All-opponents-left ordinary rule preserved")
print("Crossing checks passed: "..n)
