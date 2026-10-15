function Service:_tickSprint(record, dt, now)
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

