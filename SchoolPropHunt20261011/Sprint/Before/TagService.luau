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

