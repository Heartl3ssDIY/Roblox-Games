from pathlib import Path

ROOT = Path(__file__).resolve().parent
shared = (ROOT / 'BatContactShared.luau').read_text(encoding='utf-8')

def replace_method(source, name, replacement):
    start = source.index('function Service:' + name + '(')
    end = source.find('\nfunction ', start + 1)
    if end < 0:
        raise ValueError(name)
    return source[:start] + replacement.strip() + '\n' + source[end:]

tag = (ROOT / 'Before/TagService.luau').read_text(encoding='utf-8')
bb = (ROOT / 'Before/BritishBulldogService.luau').read_text(encoding='utf-8')
for name in ('tag', 'bb'):
    source = locals()[name]
    anchor = 'local BAT_RAGDOLL_SECONDS = 1.35\n'
    locals()[name] = source.replace(anchor, anchor + '\n' + shared + '\n', 1)

tag = tag.replace('hitAt = now + 0.16, endsAt = now + 0.30', 'hitAt = now + 0.10, endsAt = now + 0.38')
tag = tag.replace('\trecord.batSwingReadyAt = now + 0.75', '\tsampleBatSwing(record.batSwing, record, self.records, now)\n\trecord.batSwingReadyAt = now + 0.75', 1)
tag = replace_method(tag, '_swingCanHit', '''
function Service:_swingCanHit(from, target, now, rayParameters)
	local swing = from and from.batSwing
	if not swing or swing.hit or swing.character ~= from.character or swing.token ~= self.currentRound
		or not self:_tagEligible(from, target, now) then return false end
	return batContact(swing, from, target, now, math.clamp(self:_setting("TagDistance", 4.5, 1), 1, 5), rayParameters or self:_rayParameters())
end
''')
tag = replace_method(tag, '_canTag', '''
function Service:_tagEligible(from, target, now)
	if not self.active or self.phase ~= "Playing" or now >= self.endsAt or not alive(from) or not alive(target)
		or not from.participating or not target.participating or from ~= self.tagger or from.role ~= "Tagger" or target.role ~= "Runner"
		or from.frozen or target.frozen or from.ragdoll or target.ragdoll
		or now < (from.tagCooldownEndsAt or 0) or now < (target.protectedEndsAt or 0) then return false end
	return self:_batInField(from) and self:_batInField(target)
end

function Service:_canTag(from, target, now, rayParameters)
	if not self:_tagEligible(from, target, now) then return false end
	local offset = target.root.Position - from.root.Position
	return offset.Magnitude <= math.clamp(self:_setting("TagDistance", 4.5, 1), 1, 5)
		and not workspace:Raycast(from.root.Position, offset, rayParameters or self:_rayParameters())
end
''')
tag = tag.replace('if not self:_canTag(previous, target, now) or not self:_swingCanHit(previous, target, now) then return false end', 'if not self:_swingCanHit(previous, target, now) then return false end')
tag = tag.replace('now > record.batSwing.endsAt then record.batSwing = nil', 'now > record.batSwing.endsAt + BAT_SAMPLE_MAX_AGE then record.batSwing = nil')
old = '''		if self:_canTag(self.tagger, record, now, params) and self:_swingCanHit(self.tagger, record, now) then
			local distance = (record.root.Position - self.tagger.root.Position).Magnitude'''
new = '''		local hit, distance = self:_swingCanHit(self.tagger, record, now, params)
		if hit then'''
assert old in tag
tag = tag.replace(old, new, 1)
tag = tag.replace('\tif candidate then self:_transfer(candidate, now) end\nend', '''	if candidate then self:_transfer(candidate, now) end
	local attacker = self.tagger
	if attacker and attacker.batSwing then
		if now >= attacker.batSwing.endsAt then attacker.batSwing = nil
		else sampleBatSwing(attacker.batSwing, attacker, self.records, now) end
	end
end''', 1)

tag = replace_method(tag, '_path', '''
function Service:_path(bot, goal, now)
	if bot.pathBusy or now < (bot.nextPathAt or 0) then return end
	local request = {}
	bot.pathBusy = request
	bot.nextPathAt = now + (bot == self.tagger and 0.65 or 0.9)
	bot.pathGoal = goal
	local token, character, origin = self.currentRound, bot.character, bot.root.Position
	task.spawn(function()
		local route, path
		local ok = pcall(function()
			path = PathfindingService:CreatePath({ AgentRadius = 2.4, AgentHeight = 5.5, AgentCanJump = true, WaypointSpacing = 4 })
			path:ComputeAsync(origin, goal)
			if path.Status == Enum.PathStatus.Success then route = path:GetWaypoints() end
		end)
		if path then path:Destroy() end
		if bot.pathBusy ~= request then return end
		bot.pathBusy = false
		if not self.active or self.currentRound ~= token or self.records[bot.player] ~= bot or bot.character ~= character then return end
		if not ok or not route or #route == 0 then route = self:_fallbackRoute(origin, goal) end
		bot.route, bot.routeIndex = route, route and #route > 1 and 2 or 1
	end)
end
''')
tag = replace_method(tag, '_botTarget', '''
function Service:_botTarget(bot, now)
	bot.chaseTarget = nil
	if bot == self.tagger then
		local nearest, target
		for _, runner in pairs(self.records) do
			if runner.participating and runner.role == "Runner" and alive(runner) and not runner.ragdoll and now >= (runner.protectedEndsAt or 0) then
				local distance = (runner.root.Position - bot.root.Position).Magnitude
				if not nearest or distance < nearest then nearest, target = distance, runner end
			end
		end
		bot.chaseTarget = target
		if target then
			local point = self.bounds.CFrame:PointToObjectSpace(chaseGoal(bot, target))
			local half = self.bounds.Size * 0.5
			return self.bounds.CFrame:PointToWorldSpace(Vector3.new(math.clamp(point.X, -half.X + 4, half.X - 4), point.Y, math.clamp(point.Z, -half.Z + 4, half.Z - 4)))
		end
		return nil
	end
	if not bot.escapeGoal or now >= (bot.nextEscapeAt or 0) or (bot.escapeGoal - bot.root.Position).Magnitude < 8 then
		local best, bestScore
		for _, pad in ipairs(self.spawnPads) do
			local taggerDistance = self.tagger and alive(self.tagger) and (pad.Position - self.tagger.root.Position).Magnitude or 100
			local travel = (pad.Position - bot.root.Position).Magnitude
			local score = taggerDistance - travel * 0.18 + self.random:NextNumber(0, 30)
			if travel > 24 and (not bestScore or score > bestScore) then best, bestScore = pad.Position, score end
		end
		bot.escapeGoal = best
		bot.nextEscapeAt = now + 5
	end
	return bot.escapeGoal
end
''')
tag = replace_method(tag, '_driveBots', '''
function Service:_directBotRoute(origin, goal, parameters)
	local offset = goal - origin
	if math.abs(offset.Y) > 2.5 or offset.Magnitude > 45 then return false end
	if workspace:Blockcast(CFrame.new(origin), Vector3.new(3, 3, 2), offset, parameters) then return false end
	local count = math.max(1, math.ceil(offset.Magnitude / 4))
	for index = 0, count do
		local point = origin:Lerp(goal, index / count)
		local ground = workspace:Raycast(point + Vector3.new(0, 1, 0), Vector3.new(0, -7, 0), parameters)
		if not ground or ground.Normal.Y < 0.55 then return false end
	end
	return true
end

function Service:_botSprint(bot, now, wantsSprint)
	local dt = math.clamp(now - (bot.lastSprintAt or now), 0, 0.25)
	bot.lastSprintAt = now
	local capacity = math.clamp(self:_setting("SprintSeconds", 10, 1), 1, 30)
	bot.botSprintRemaining = math.clamp(bot.botSprintRemaining or capacity, 0, capacity)
	local sprinting = wantsSprint and not bot.botSprintExhausted and bot.botSprintRemaining > 0
	if sprinting then
		bot.botSprintRemaining = math.max(0, bot.botSprintRemaining - dt)
		if bot.botSprintRemaining <= 0 then bot.botSprintExhausted, sprinting = true, false end
	else
		bot.botSprintRemaining = math.min(capacity, bot.botSprintRemaining + dt * capacity / self:_setting("SprintRefillSeconds", 15, 1))
		if bot.botSprintRemaining >= capacity then bot.botSprintExhausted = false end
	end
	local speed = bot.role == "Tagger" and self:_setting("TaggerWalkSpeed", 18, 1) or self:_setting("RunnerWalkSpeed", 16, 1)
	bot.humanoid.WalkSpeed = speed * (sprinting and math.clamp(self:_setting("SprintMultiplier", 2.5, 1), 1, 2.5) or 1)
end

function Service:_driveBots(now)
	local parameters = self:_rayParameters()
	for _, bot in pairs(self.records) do
		if bot.isBot and bot.participating and alive(bot) and not bot.frozen and not bot.ragdoll and now >= (bot.nextBotMoveAt or 0) then
			bot.nextBotMoveAt = now + 0.1
			local goal = self:_botTarget(bot, now)
			local target = bot.chaseTarget
			local wantsSprint = target and ((target.root.Position - bot.root.Position).Magnitude > 12 or target.root.AssemblyLinearVelocity.Magnitude > 19)
			self:_botSprint(bot, now, wantsSprint == true)
			if goal then
				local direct = self:_directBotRoute(bot.root.Position, goal, parameters)
				local destination = goal
				if not direct then
					self:_path(bot, goal, now)
					local route, index = bot.route, bot.routeIndex or 1
					while route and route[index] do
						local offset = route[index].Position - bot.root.Position
						if Vector3.new(offset.X, 0, offset.Z).Magnitude >= 2.5 or math.abs(offset.Y) > 4.5 then break end
						index = index + 1
					end
					bot.routeIndex = index
					local waypoint = route and route[index]
					if waypoint then
						destination = waypoint.Position
						if waypoint.Action == Enum.PathWaypointAction.Jump then bot.humanoid.Jump = true end
					else destination = bot.root.Position end
				end
				if bot.previousBotPosition and (bot.root.Position - bot.previousBotPosition).Magnitude < 0.2 and (destination - bot.root.Position).Magnitude > 3 then
					bot.stuckSince = (bot.stuckSince or 0) + 0.1
					if bot.stuckSince > 0.8 then bot.humanoid.Jump = true end
				else bot.stuckSince = 0 end
				bot.previousBotPosition = bot.root.Position
				bot.humanoid:MoveTo(destination)
			end
			if target and self:_tagEligible(bot, target, now) and (target.root.Position - bot.root.Position).Magnitude <= 5.25 then
				self:TryBatSwing(bot.player)
			end
		end
	end
end
''')
tag = tag.replace('if not workspace:Raycast(startPosition, goal - startPosition, params) then\n\t\treturn { { Position = goal', 'if self:_directBotRoute(startPosition, goal, params) then\n\t\treturn { { Position = goal', 1)

bb = bb.replace('local BAT_SWING_CONTACT_START = 0.16', 'local BAT_SWING_CONTACT_START = 0.10').replace('local BAT_SWING_CONTACT_END = 0.30', 'local BAT_SWING_CONTACT_END = 0.38')
bb = bb.replace('local BAT_SWING_FRONT_DOT = 0.25\n', '')
bb = bb.replace('\tlocal serial = player:GetAttribute("PCBatSwingSerial")', '\tsampleBatSwing(record.batSwing, record, self.records, now)\n\tlocal serial = player:GetAttribute("PCBatSwingSerial")', 1)
bb = replace_method(bb, '_resolveBatSwings', '''
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
					if runner ~= attacker and runner.participating and alive(runner) and not runner.frozen and not runner.ragdoll
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
''')
bb = replace_method(bb, '_drivePracticeBots', '''
function Service:_drivePracticeBots(now)
	for _, bot in pairs(self.records) do
		if bot.isBot and bot.participating and alive(bot) and not bot.frozen and not bot.ragdoll and now >= bot.nextBotMoveAt then
			bot.nextBotMoveAt = now + 0.1
			local target, chaseTarget
			if bot.role == "Runner" and not bot.arrived then
				target = self:_spawnCFrame(self.destination, bot.spawnIndex).Position
			elseif bot.role == "Bulldog" then
				local nearest = math.huge
				for _, runner in pairs(self.records) do
					if runner.participating and alive(runner) and not runner.ragdoll and Rules.CanTag(self.phase, runner.role, runner.departed, runner.arrived, self:_inField(runner.root.Position), false) then
						local distance = (runner.root.Position - bot.root.Position).Magnitude
						if distance < nearest then nearest, chaseTarget = distance, runner end
					end
				end
				if chaseTarget then
					local point = self.bounds.CFrame:PointToObjectSpace(chaseGoal(bot, chaseTarget))
					local halfX = self.bounds.Size.X / 2 - 4
					target = self.bounds.CFrame:PointToWorldSpace(Vector3.new(math.clamp(point.X, -halfX, halfX), point.Y, math.clamp(point.Z, self.northZ + 4, self.southZ - 4)))
					if nearest <= TAG_DISTANCE + 0.75 then self:TryBatSwing(bot.player) end
				end
			end
			bot.sprintHeld = chaseTarget ~= nil and ((chaseTarget.root.Position - bot.root.Position).Magnitude > 12 or chaseTarget.root.AssemblyLinearVelocity.Magnitude > 19)
			bot.sprintLeaseEndsAt = bot.sprintHeld and now + 0.3 or 0
			self:_applyMovementSpeed(bot, now)
			if target then bot.humanoid:MoveTo(target)
			else bot.humanoid:MoveTo(bot.root.Position) bot.humanoid:Move(Vector3.zero) end
		end
	end
end
''')

for name, source in [('TagService', tag), ('BritishBulldogService', bb)]:
    (ROOT / 'After' / (name + '.luau')).write_text(source, encoding='utf-8')
    print(name, len(source))
