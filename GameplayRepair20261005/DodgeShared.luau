local function dodgeSpeed(distance, duration, elapsed)
	local alpha = math.clamp(elapsed / duration, 0, 1)
	local attack = 0.16
	local envelope = alpha < attack and (0.5 + 0.5 * math.sin(alpha / attack * math.pi / 2))
		or math.cos((alpha - attack) / (1 - attack) * math.pi / 2)
	local area = attack * (0.5 + 1 / math.pi) + (1 - attack) * 2 / math.pi
	return distance / duration * envelope / area
end

function Service:_dodgeGrounded(record, params)
	local foot = record.humanoid.HipHeight + record.root.Size.Y * 0.5
	local leg = record.character:FindFirstChild("Left Leg")
	if leg then foot += leg.Size.Y end
	local hit = workspace:Raycast(record.root.Position, Vector3.new(0, -foot - 0.7, 0), params)
	return hit ~= nil and hit.Normal.Y > 0.45 and math.abs(record.root.AssemblyLinearVelocity.Y) < 12
end

function Service:_clipDodgeTravel(record, travel, params)
	local length = travel.Magnitude
	if length < 0.001 then return 0 end
	local overlap = OverlapParams.new()
	overlap.FilterType = params.FilterType
	overlap.FilterDescendantsInstances = params.FilterDescendantsInstances
	overlap.CollisionGroup = params.CollisionGroup
	overlap.RespectCanCollide = true
	overlap.MaxParts = 1
	if #workspace:GetPartBoundsInBox(CFrame.new(record.root.Position), Vector3.new(2.2, 3.4, 2.2), overlap) > 0 then return 0 end
	local origin = self.bounds.CFrame:PointToObjectSpace(record.root.Position)
	local delta = self.bounds.CFrame:VectorToObjectSpace(travel)
	local half = self.bounds.Size * 0.5
	local lowerZ = self.northZ and self.northZ + 1.5 or -half.Z + 1.5
	local upperZ = self.southZ and self.southZ - 1.5 or half.Z - 1.5
	if math.abs(origin.X) > half.X - 1.5 or origin.Z < lowerZ or origin.Z > upperZ then return 0 end
	local fraction = 1
	if delta.X > 0 then fraction = math.min(fraction, (half.X - 1.5 - origin.X) / delta.X)
	elseif delta.X < 0 then fraction = math.min(fraction, (-half.X + 1.5 - origin.X) / delta.X) end
	if delta.Z > 0 then fraction = math.min(fraction, (upperZ - origin.Z) / delta.Z)
	elseif delta.Z < 0 then fraction = math.min(fraction, (lowerZ - origin.Z) / delta.Z) end
	local hit = workspace:Blockcast(CFrame.new(record.root.Position), Vector3.new(2.4, 3.6, 2.4), travel * math.clamp(fraction, 0, 1), params)
	if hit then fraction = math.min(fraction, math.max(0, hit.Distance - 0.18) / length) end
	return math.clamp(fraction, 0, 1)
end

function Service:__STOP__(record, expected)
	local burst = expected or record.__BURST__
	if not burst then return end
	if burst.connection then burst.connection:Disconnect() burst.connection = nil end
	if burst.velocity then burst.velocity:Destroy() burst.velocity = nil end
	if burst.attachment then burst.attachment:Destroy() burst.attachment = nil end
	if record.__BURST__ ~= burst then return end
	record.__BURST__ = nil
	local root = burst.root
	if record.root ~= root or not root.Parent then return end
	local current = root.AssemblyLinearVelocity
	local excess = math.max(0, current:Dot(burst.direction))
	root.AssemblyLinearVelocity = current - burst.direction * excess
	if not record.frozen and not record.ragdoll then
		if record.humanoid == burst.humanoid and burst.humanoid.Parent then burst.humanoid.AutoRotate = burst.autoRotate end
		pcall(function()
			if burst.ownershipAuto then root:SetNetworkOwnershipAuto()
			else root:SetNetworkOwner(burst.owner and burst.owner.Parent == Players and burst.owner or nil) end
		end)
	end
end

function Service:__START__(record, direction, now, duration, distance, forwardVelocity, params)
	self:__STOP__(record)
	local root = record.root
	if root.Anchored then return false end
	local owner, ownershipAuto
	local ownershipOK = pcall(function()
		owner, ownershipAuto = root:GetNetworkOwner(), root:GetNetworkOwnershipAuto()
		root:SetNetworkOwner(nil)
	end)
	if not ownershipOK then return false end
	local attachment = Instance.new("Attachment")
	attachment.Name, attachment.Parent = "__PREFIX__DodgeAttachment", root
	local velocity = Instance.new("LinearVelocity")
	velocity.Name, velocity.Attachment0 = "__PREFIX__DodgeVelocity", attachment
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.PrimaryTangentAxis, velocity.SecondaryTangentAxis = Vector3.xAxis, Vector3.zAxis
	velocity.ForceLimitsEnabled, velocity.ForceLimitMode = true, Enum.ForceLimitMode.Magnitude
	velocity.MaxForce = math.max(root.AssemblyMass, 1) * 3000
	local initial = direction * dodgeSpeed(distance, duration, 0) + forwardVelocity
	velocity.PlaneVelocity, velocity.Parent = Vector2.new(initial.X, initial.Z), root
	local burst = {root=root,attachment=attachment,velocity=velocity,direction=direction,owner=owner,ownershipAuto=ownershipAuto,
		humanoid=record.humanoid,autoRotate=record.humanoid.AutoRotate,
		token=self.currentRound,crossing=self.crossingNumber,endsAt=now+duration}
	record.__BURST__ = burst
	record.humanoid.AutoRotate = false
	root.AssemblyLinearVelocity = initial + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
	__ATTR__(record.player, "__PREFIX__DodgeDirection", direction)
	__ATTR__(record.player, "__PREFIX__DodgeDuration", duration)
	__ATTR__(record.player, "__PREFIX__DodgeStartedAt", now)
	burst.connection = RunService.PreSimulation:Connect(function(dt)
		local time = workspace:GetServerTimeNow()
		if self.records[record.player] ~= record or record.root ~= root or not root.Parent or not self.active
			or self.currentRound ~= burst.token or self.crossingNumber ~= burst.crossing or self.phase ~= "__PHASE__"
			or not record.participating or record.frozen or record.ragdoll or not alive(record) or time >= self.endsAt
			or __ROLESTOP__ or time >= burst.endsAt then self:__STOP__(record, burst) return end
		local desired = direction * dodgeSpeed(distance, duration, time - now) + forwardVelocity
		local step = desired * math.clamp(dt, 0, 0.05)
		local hit = step.Magnitude > 0 and workspace:Blockcast(CFrame.new(root.Position), Vector3.new(2.4, 3.6, 2.4), step, params)
		if hit or not self:_inside(self.bounds, root.Position) then self:__STOP__(record, burst) return end
		velocity.PlaneVelocity = Vector2.new(desired.X, desired.Z)
	end)
	return true
end
