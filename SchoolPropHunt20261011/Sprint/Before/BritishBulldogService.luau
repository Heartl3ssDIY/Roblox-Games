function Service:_updateMovement(record, dt, now)
	if not record.participating then return end
	dt = math.clamp(dt, 0, 0.25)
	self:_sprintCapacity(record)
	if record.sprintHeld and now >= (record.sprintLeaseEndsAt or 0) then self:_releaseSprint(record) end
	local allowed = self:_movementAllowed(record, now)
	if not allowed then self:_releaseSprint(record) end
	local speed = alive(record) and Vector3.new(record.root.AssemblyLinearVelocity.X, 0, record.root.AssemblyLinearVelocity.Z).Magnitude or 0
	if record.role == "Runner" and alive(record) and (self:_inside(self.safeZones.North, record.root.Position) or self:_inside(self.safeZones.South, record.root.Position)) then
		record.sprintRemaining = record.sprintMax
		record.sprintExhausted = false
	end
	record.sprinting = allowed and record.sprintHeld and not record.sprintExhausted and record.sprintRemaining > 0 and speed > 1
	if record.sprinting then
		record.sprintRemaining = math.max(0, record.sprintRemaining - dt)
		if record.sprintRemaining == 0 then record.sprintExhausted = true record.sprinting = false end
	elseif record.sprintExhausted or not record.sprintHeld then
		record.sprintRemaining = math.min(record.sprintMax, record.sprintRemaining + record.sprintMax / self:_setting("SprintRefillSeconds", 15, 0.1) * dt)
		if record.sprintExhausted and record.sprintRemaining >= self:_setting("SprintResumeSeconds", 0.5, 0.05) then
			record.sprintExhausted = false
		end
		if record.sprintRemaining >= record.sprintMax - 0.0001 then
			record.sprintRemaining = record.sprintMax
			record.sprintExhausted = false
		end
	end
	self:_publishMovement(record)
	self:_applyMovementSpeed(record, now)
end

