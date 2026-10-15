assert(not game:GetService("RunService"):IsRunning(),"Edit mode only")
local Players=game:GetService("Players")
local Rules=require(game:GetService("ServerScriptService").BritishBulldogRules)
local function makeTag(workspace)
 local Service={}
 Service.__index=Service
local BAT_SAMPLE_MAX_AGE = 0.15
local BAT_FACING_DOT = 0.15

local function sampleBatSwing(swing, attacker, records, now)
	local targets = {}
	for _, target in pairs(records) do
		if target ~= attacker and target.root and target.root.Parent and target.character then
			targets[target] = { position = target.root.Position, character = target.character, root = target.root }
		end
	end
	swing.sample = { at = now, origin = attacker.root.Position, root = attacker.root,
		forward = attacker.root.CFrame.LookVector, targets = targets }
end

local function polynomialValue(coefficients, alpha)
	local value = 0
	for index = #coefficients, 1, -1 do value = value * alpha + coefficients[index] end
	return value
end

local function polynomialRoots(coefficients, first, last)
	local scale = 0
	for _, value in ipairs(coefficients) do scale = math.max(scale, math.abs(value)) end
	if scale < 1e-12 then return {} end
	local normalized = {}
	for index, value in ipairs(coefficients) do normalized[index] = value / scale end
	while #normalized > 1 and math.abs(normalized[#normalized]) < 1e-12 do table.remove(normalized) end
	local degree = #normalized - 1
	if degree < 1 then return {} end
	if degree == 1 then
		local root = -normalized[1] / normalized[2]
		return root >= first and root <= last and { root } or {}
	end
	local derivative = {}
	for index = 2, #normalized do derivative[index - 1] = normalized[index] * (index - 1) end
	local boundaries = { first }
	for _, root in ipairs(polynomialRoots(derivative, first, last)) do table.insert(boundaries, root) end
	table.insert(boundaries, last)
	table.sort(boundaries)
	local roots = {}
	for index, boundary in ipairs(boundaries) do
		local value = polynomialValue(normalized, boundary)
		if math.abs(value) < 1e-10 then table.insert(roots, boundary) end
		local nextBoundary = boundaries[index + 1]
		if nextBoundary then
			local nextValue = polynomialValue(normalized, nextBoundary)
			if value * nextValue < 0 then
				local left, right, leftValue = boundary, nextBoundary, value
				for _ = 1, 32 do
					local middle = (left + right) * 0.5
					local middleValue = polynomialValue(normalized, middle)
					if leftValue * middleValue <= 0 then right = middle
					else left, leftValue = middle, middleValue end
				end
				table.insert(roots, (left + right) * 0.5)
			end
		end
	end
	return roots
end

local function contactIntervals(relative, change, facing, turn, first, last, reach)
	local a, b, c = change:Dot(change), 2 * relative:Dot(change), relative:Dot(relative) - reach * reach
	if a < 1e-10 then
		if c > 0 then return {} end
	else
		local discriminant = b * b - 4 * a * c
		if discriminant < 0 then return {} end
		local root = math.sqrt(discriminant)
		first, last = math.max(first, (-b - root) / (2 * a)), math.min(last, (-b + root) / (2 * a))
		if first > last then return {} end
	end
	local horizontal, travel = Vector3.new(relative.X, 0, relative.Z), Vector3.new(change.X, 0, change.Z)
	facing, turn = Vector3.new(facing.X, 0, facing.Z), Vector3.new(turn.X, 0, turn.Z)
	local dot = { facing:Dot(horizontal), facing:Dot(travel) + turn:Dot(horizontal), turn:Dot(travel) }
	local facingLength = { facing:Dot(facing), 2 * facing:Dot(turn), turn:Dot(turn) }
	local horizontalLength = { horizontal:Dot(horizontal), 2 * horizontal:Dot(travel), travel:Dot(travel) }
	local cone = { 0, 0, 0, 0, 0 }
	for i = 1, 3 do
		for j = 1, 3 do cone[i + j - 1] += dot[i] * dot[j] - BAT_FACING_DOT * BAT_FACING_DOT * facingLength[i] * horizontalLength[j] end
	end
	local boundaries = { first, last }
	facingLength[1] -= 0.0001
	horizontalLength[1] -= 0.0001
	for _, polynomial in ipairs({ cone, dot, facingLength, horizontalLength }) do
		for _, root in ipairs(polynomialRoots(polynomial, first, last)) do table.insert(boundaries, root) end
	end
	table.sort(boundaries)
	local candidates = {}
	for index, boundary in ipairs(boundaries) do
		table.insert(candidates, boundary)
		if boundaries[index + 1] then table.insert(candidates, (boundary + boundaries[index + 1]) * 0.5) end
	end
	return candidates
end

local function batContact(swing, attacker, target, now, reach, parameters)
	if now < swing.hitAt or now > swing.endsAt + BAT_SAMPLE_MAX_AGE then return false end
	local origin, position = attacker.root.Position, target.root.Position
	local forward = attacker.root.CFrame.LookVector
	local previous, oldTarget = swing.sample, swing.sample and swing.sample.targets[target]
	local elapsed = previous and now - previous.at or 0
	local hasHistory = previous and oldTarget and previous.root == attacker.root
		and oldTarget.character == target.character and oldTarget.root == target.root
		and elapsed > 0 and elapsed <= BAT_SAMPLE_MAX_AGE
		and (origin - previous.origin).Magnitude <= 12 and (position - oldTarget.position).Magnitude <= 12
	local first, last = 1, 1
	if hasHistory then
		first = math.clamp((math.max(swing.hitAt, target.protectedEndsAt or 0) - previous.at) / elapsed, 0, 1)
		last = math.clamp((swing.endsAt - previous.at) / elapsed, 0, 1)
		if previous.at > swing.endsAt or first > last then return false end
	elseif now > swing.endsAt then
		return false
	end
	local oldOrigin = hasHistory and previous.origin or origin
	local oldPosition = hasHistory and oldTarget.position or position
	local relative = oldPosition - oldOrigin
	local change = (position - origin) - relative
	local oldForward = hasHistory and previous.forward or forward
	if workspace:Raycast(origin, position - origin, parameters) then return false end
	local best
	for _, alpha in ipairs(contactIntervals(relative, change, oldForward, forward - oldForward, first, last, reach)) do
		local contactOrigin = oldOrigin:Lerp(origin, alpha)
		local offset = oldPosition:Lerp(position, alpha) - contactOrigin
		local distance = offset.Magnitude
		local direction = hasHistory and previous.forward:Lerp(forward, alpha) or forward
		local horizontal, facing = Vector3.new(offset.X, 0, offset.Z), Vector3.new(direction.X, 0, direction.Z)
		local inFront = horizontal.Magnitude < 0.01 or (facing.Magnitude > 0.01 and facing.Unit:Dot(horizontal.Unit) >= BAT_FACING_DOT - 1e-7)
		if distance <= reach + 1e-5 and inFront and (not best or distance < best)
			and not workspace:Raycast(contactOrigin, offset, parameters) then
			best = distance
		end
	end
	return best ~= nil, best
end


local function alive(record)
	return record and record.ready and record.character and record.character.Parent
		and record.root and record.root.Parent and record.humanoid and record.humanoid.Health > 0
end


function Service:_setting(name, fallback, minimum)
	local value = self.arena:GetAttribute(name)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return fallback end
	return math.max(minimum or 0, value)
end

function Service:_batInField(record)
	local point = self.bounds.CFrame:PointToObjectSpace(record.root.Position)
	local half = self.bounds.Size * 0.5
	return math.abs(point.X) <= half.X - 3 and math.abs(point.Z) <= half.Z - 3
		and math.abs(point.Y) <= half.Y and record.root.Position.Y >= self.spawnPads[1].Position.Y - 9
end

function Service:_swingCanHit(from, target, now, rayParameters)
	local swing = from and from.batSwing
	if not swing or swing.hit or swing.character ~= from.character or swing.token ~= self.currentRound
		or not self:_tagEligible(from, target, now) then return false end
	return batContact(swing, from, target, now, math.clamp(self:_setting("TagDistance", 10, 1), 1, 10), rayParameters or self:_rayParameters())
end

function Service:_tagEligible(from, target, now)
	if not self.active or self.phase ~= "Playing" or now >= self.endsAt or not alive(from) or not alive(target)
		or not from.participating or not target.participating or from ~= self.tagger or from.role ~= "Tagger" or target.role ~= "Runner"
		or from.frozen or target.frozen or from.ragdoll or (target.ragdoll and target.ragdoll.kind ~= "Push")
		or now < (from.tagCooldownEndsAt or 0) or now < (target.protectedEndsAt or 0) then return false end
	return self:_batInField(from) and self:_batInField(target)
end

function Service:_canTag(from, target, now, rayParameters)
	if not self:_tagEligible(from, target, now) then return false end
	local offset = target.root.Position - from.root.Position
	return offset.Magnitude <= math.clamp(self:_setting("TagDistance", 10, 1), 1, 10)
		and not workspace:Raycast(from.root.Position, offset, rayParameters or self:_rayParameters())
end

 return Service
end
local function makeBulldog(workspace)
 local Service={}
 Service.__index=Service
 local TAG_DISTANCE=10
local BAT_SAMPLE_MAX_AGE = 0.15
local BAT_FACING_DOT = 0.15

local function sampleBatSwing(swing, attacker, records, now)
	local targets = {}
	for _, target in pairs(records) do
		if target ~= attacker and target.root and target.root.Parent and target.character then
			targets[target] = { position = target.root.Position, character = target.character, root = target.root }
		end
	end
	swing.sample = { at = now, origin = attacker.root.Position, root = attacker.root,
		forward = attacker.root.CFrame.LookVector, targets = targets }
end

local function polynomialValue(coefficients, alpha)
	local value = 0
	for index = #coefficients, 1, -1 do value = value * alpha + coefficients[index] end
	return value
end

local function polynomialRoots(coefficients, first, last)
	local scale = 0
	for _, value in ipairs(coefficients) do scale = math.max(scale, math.abs(value)) end
	if scale < 1e-12 then return {} end
	local normalized = {}
	for index, value in ipairs(coefficients) do normalized[index] = value / scale end
	while #normalized > 1 and math.abs(normalized[#normalized]) < 1e-12 do table.remove(normalized) end
	local degree = #normalized - 1
	if degree < 1 then return {} end
	if degree == 1 then
		local root = -normalized[1] / normalized[2]
		return root >= first and root <= last and { root } or {}
	end
	local derivative = {}
	for index = 2, #normalized do derivative[index - 1] = normalized[index] * (index - 1) end
	local boundaries = { first }
	for _, root in ipairs(polynomialRoots(derivative, first, last)) do table.insert(boundaries, root) end
	table.insert(boundaries, last)
	table.sort(boundaries)
	local roots = {}
	for index, boundary in ipairs(boundaries) do
		local value = polynomialValue(normalized, boundary)
		if math.abs(value) < 1e-10 then table.insert(roots, boundary) end
		local nextBoundary = boundaries[index + 1]
		if nextBoundary then
			local nextValue = polynomialValue(normalized, nextBoundary)
			if value * nextValue < 0 then
				local left, right, leftValue = boundary, nextBoundary, value
				for _ = 1, 32 do
					local middle = (left + right) * 0.5
					local middleValue = polynomialValue(normalized, middle)
					if leftValue * middleValue <= 0 then right = middle
					else left, leftValue = middle, middleValue end
				end
				table.insert(roots, (left + right) * 0.5)
			end
		end
	end
	return roots
end

local function contactIntervals(relative, change, facing, turn, first, last, reach)
	local a, b, c = change:Dot(change), 2 * relative:Dot(change), relative:Dot(relative) - reach * reach
	if a < 1e-10 then
		if c > 0 then return {} end
	else
		local discriminant = b * b - 4 * a * c
		if discriminant < 0 then return {} end
		local root = math.sqrt(discriminant)
		first, last = math.max(first, (-b - root) / (2 * a)), math.min(last, (-b + root) / (2 * a))
		if first > last then return {} end
	end
	local horizontal, travel = Vector3.new(relative.X, 0, relative.Z), Vector3.new(change.X, 0, change.Z)
	facing, turn = Vector3.new(facing.X, 0, facing.Z), Vector3.new(turn.X, 0, turn.Z)
	local dot = { facing:Dot(horizontal), facing:Dot(travel) + turn:Dot(horizontal), turn:Dot(travel) }
	local facingLength = { facing:Dot(facing), 2 * facing:Dot(turn), turn:Dot(turn) }
	local horizontalLength = { horizontal:Dot(horizontal), 2 * horizontal:Dot(travel), travel:Dot(travel) }
	local cone = { 0, 0, 0, 0, 0 }
	for i = 1, 3 do
		for j = 1, 3 do cone[i + j - 1] += dot[i] * dot[j] - BAT_FACING_DOT * BAT_FACING_DOT * facingLength[i] * horizontalLength[j] end
	end
	local boundaries = { first, last }
	facingLength[1] -= 0.0001
	horizontalLength[1] -= 0.0001
	for _, polynomial in ipairs({ cone, dot, facingLength, horizontalLength }) do
		for _, root in ipairs(polynomialRoots(polynomial, first, last)) do table.insert(boundaries, root) end
	end
	table.sort(boundaries)
	local candidates = {}
	for index, boundary in ipairs(boundaries) do
		table.insert(candidates, boundary)
		if boundaries[index + 1] then table.insert(candidates, (boundary + boundaries[index + 1]) * 0.5) end
	end
	return candidates
end

local function batContact(swing, attacker, target, now, reach, parameters)
	if now < swing.hitAt or now > swing.endsAt + BAT_SAMPLE_MAX_AGE then return false end
	local origin, position = attacker.root.Position, target.root.Position
	local forward = attacker.root.CFrame.LookVector
	local previous, oldTarget = swing.sample, swing.sample and swing.sample.targets[target]
	local elapsed = previous and now - previous.at or 0
	local hasHistory = previous and oldTarget and previous.root == attacker.root
		and oldTarget.character == target.character and oldTarget.root == target.root
		and elapsed > 0 and elapsed <= BAT_SAMPLE_MAX_AGE
		and (origin - previous.origin).Magnitude <= 12 and (position - oldTarget.position).Magnitude <= 12
	local first, last = 1, 1
	if hasHistory then
		first = math.clamp((math.max(swing.hitAt, target.protectedEndsAt or 0) - previous.at) / elapsed, 0, 1)
		last = math.clamp((swing.endsAt - previous.at) / elapsed, 0, 1)
		if previous.at > swing.endsAt or first > last then return false end
	elseif now > swing.endsAt then
		return false
	end
	local oldOrigin = hasHistory and previous.origin or origin
	local oldPosition = hasHistory and oldTarget.position or position
	local relative = oldPosition - oldOrigin
	local change = (position - origin) - relative
	local oldForward = hasHistory and previous.forward or forward
	if workspace:Raycast(origin, position - origin, parameters) then return false end
	local best
	for _, alpha in ipairs(contactIntervals(relative, change, oldForward, forward - oldForward, first, last, reach)) do
		local contactOrigin = oldOrigin:Lerp(origin, alpha)
		local offset = oldPosition:Lerp(position, alpha) - contactOrigin
		local distance = offset.Magnitude
		local direction = hasHistory and previous.forward:Lerp(forward, alpha) or forward
		local horizontal, facing = Vector3.new(offset.X, 0, offset.Z), Vector3.new(direction.X, 0, direction.Z)
		local inFront = horizontal.Magnitude < 0.01 or (facing.Magnitude > 0.01 and facing.Unit:Dot(horizontal.Unit) >= BAT_FACING_DOT - 1e-7)
		if distance <= reach + 1e-5 and inFront and (not best or distance < best)
			and not workspace:Raycast(contactOrigin, offset, parameters) then
			best = distance
		end
	end
	return best ~= nil, best
end


local function alive(record)
	return record.character and record.character.Parent and record.root and record.root.Parent
		and record.humanoid and record.humanoid.Health > 0
end


function Service:_inField(position)
	local point = self.bounds.CFrame:PointToObjectSpace(position)
	return math.abs(point.X) <= self.bounds.Size.X / 2
		and math.abs(point.Y) <= self.bounds.Size.Y / 2
		and point.Z > self.northZ and point.Z < self.southZ
end

function Service:_batSwingAllowed(record, now)
	return self.running and self.active and self.phase == "Crossing" and self.endsAt > now
		and record and record.ready and record.participating and record.role == "Bulldog"
		and not record.frozen and not record.ragdoll and not record.pendingBulldog and alive(record)
		and (record.isBot or record.player.Parent == Players) and self:_inField(record.root.Position)
end

function Service:_resolveBatSwings(now, rayParams)
	for _, attacker in pairs(self.records) do
		local swing = attacker.batSwing
		if swing then
			if not self:_batSwingAllowed(attacker, now) or swing.character ~= attacker.character
				or swing.round ~= self.currentRound or swing.crossing ~= self.crossingNumber or now > swing.endsAt + BAT_SAMPLE_MAX_AGE then
				attacker.batSwing = nil
			else
				local nearest, nearestDistance
				for _, runner in pairs(self.records) do
					if runner ~= attacker and runner.participating and alive(runner) and (not runner.frozen or runner.ragdoll and runner.ragdoll.kind == "Push")
						and (not runner.ragdoll or runner.ragdoll.kind == "Push")
						and Rules.CanTag(self.phase, runner.role, runner.departed, runner.arrived, self:_inField(runner.root.Position), false) then
						local hit, distance = batContact(swing, attacker, runner, now, TAG_DISTANCE, rayParams)
						if hit and (not nearestDistance or distance < nearestDistance) then nearest, nearestDistance = runner, distance end
					end
				end
				if nearest and self:_caught(nearest, "Tagged", now, attacker) then attacker.batSwing = nil end
				if attacker.batSwing then
					if now >= swing.endsAt then attacker.batSwing = nil
					else sampleBatSwing(swing, attacker, self.records, now) end
				end
			end
		end
	end
end

 return Service
end
local fixture=Instance.new("Folder")
fixture.Name="BatReachTransientFixture"
fixture.Parent=workspace
local function part(name,position,size)
 local p=Instance.new("Part")
 p.Name=name p.Anchored=true p.CanCollide=false p.Transparency=1
 p.Size=size or Vector3.new(2,2,1)
 p.Position=position p.Parent=fixture
 return p
end
local base=Vector3.new(10000,10000,10000)
local bounds=part("Bounds",base,Vector3.new(100,100,100))
local aRoot=part("Attacker",base)
local bRoot=part("Target",base+Vector3.new(0,0,-9.9))
local wall=part("Wall",base+Vector3.new(0,0,-5),Vector3.new(20,20,1))
local params=RaycastParams.new()
params.FilterType=Enum.RaycastFilterType.Include
params.FilterDescendantsInstances={}
local function record(root,role)
 return {root=root,character={Parent=true},humanoid={Health=100},ready=true,
 participating=true,role=role,departed=true,arrived=false,isBot=true,player={}}
end
local attacker=record(aRoot,"Tagger")
local target=record(bRoot,"Runner")
local token={}
local tagClass=makeTag(workspace)
local tag=setmetatable({active=true,phase="Playing",endsAt=20,tagger=attacker,currentRound=token,
 bounds=bounds,spawnPads={bounds},arena={GetAttribute=function() return nil end}},tagClass)
local bulldogClass=makeBulldog(workspace)
local bulldog=setmetatable({running=true,active=true,phase="Crossing",endsAt=20,currentRound=token,
 crossingNumber=1,bounds=bounds,northZ=-50,southZ=50,records={attacker,target}},bulldogClass)
function bulldog:_caught(victim)
 self.hitTarget=victim
 return true
end
local function swing()
 attacker.batSwing={hitAt=1.1,endsAt=1.38,character=attacker.character,token=token,round=token,crossing=1}
end
local checks=0
local evidence={}
local function check(ok,message)
 checks+=1 assert(ok,message) table.insert(evidence,message)
end
local function tagHit(offset,time)
 attacker.role="Tagger" bRoot.Position=base+offset swing()
 return tag:_swingCanHit(attacker,target,time or 1.2,params)
end
local function bulldogHit(offset,time)
 attacker.role="Bulldog" bRoot.Position=base+offset swing()
 bulldog.hitTarget=nil bulldog:_resolveBatSwings(time or 1.2,params)
 return bulldog.hitTarget==target
end
local ok,err=xpcall(function()
 for _,case in ipairs({
  {Vector3.new(0,0,-9.9),true,"9.9 studs"},
  {Vector3.new(0,0,-10),true,"10 stud boundary"},
  {Vector3.new(0,0,-10.01),false,"beyond 10 studs"},
  {Vector3.new(0,0,-6),true,"existing nearby hit"},
  {Vector3.new(0,0,5),false,"behind attacker"},
  {Vector3.new(5,0,0),false,"sideways"},
  {Vector3.new(0,10.1,-0.1),false,"vertical range"},
  {Vector3.new(7,0,-7),true,"diagonal within sphere"},
  {Vector3.new(8,0,-8),false,"diagonal outside sphere"},
 }) do
  check(tagHit(case[1])==case[2],"Tag "..case[3])
  check(bulldogHit(case[1])==case[2],"Bulldog "..case[3])
 end
 params.FilterDescendantsInstances={wall}
 check(not tagHit(Vector3.new(0,0,-9.9)),"Tag actual wall blocks extended hit")
 check(not bulldogHit(Vector3.new(0,0,-9.9)),"Bulldog actual wall blocks extended hit")
 params.FilterDescendantsInstances={}
 for _,mode in ipairs({"Tag","Bulldog"}) do
  local hit=mode=="Tag" and tagHit or bulldogHit
  check(not hit(Vector3.new(0,0,-9.9),1.09),mode.." contact windup preserved")
  check(not hit(Vector3.new(0,0,-9.9),1.54),mode.." expired swing rejected")
  target.participating=false
  check(not hit(Vector3.new(0,0,-9.9)),mode.." nonparticipant rejected")
  target.participating=true
  target.role="Tagger"
  check(not hit(Vector3.new(0,0,-9.9)),mode.." wrong target role rejected")
  target.role="Runner"
 end
 target.arrived=true
 check(not bulldogHit(Vector3.new(0,0,-9.9)),"Bulldog safe arrival protected")
 target.arrived=false
 target.departed=false
 check(not bulldogHit(Vector3.new(0,0,-9.9)),"Bulldog unstarted crossing protected")
 target.departed=true
 target.protectedEndsAt=2
 check(not tagHit(Vector3.new(0,0,-9.9)),"Tag spawn/tag back protection preserved")
 target.protectedEndsAt=0
 tag.arena.GetAttribute=function() return 100 end
 check(not tagHit(Vector3.new(0,0,-10.01)),"Tag arena cannot exceed 10 stud hard cap")
 tag.arena.GetAttribute=function() return nil end
 attacker.role="Tagger" bRoot.Position=base+Vector3.new(0,0,-9.9) swing()
 attacker.batSwing.token={}
 check(not tag:_swingCanHit(attacker,target,1.2,params),"Tag old round swing rejected")
 attacker.role="Bulldog" swing() attacker.batSwing.crossing=2
 bulldog.hitTarget=nil bulldog:_resolveBatSwings(1.2,params)
 check(bulldog.hitTarget==nil,"Bulldog old crossing swing rejected")
end,debug.traceback)
fixture:Destroy()
assert(ok,err)
return game:GetService("HttpService"):JSONEncode({checks=checks,evidence=evidence,nativeVectors=true,actualWallRaycasts=true,newReach=10,playStarted=false})

