local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Toys = {}
Toys.__index = Toys

local actions = {
	M01 = { pose = "Kick", contact = 0.60, duration = 1.10, cooldown = 5 },
	M02 = { pose = "Lob", contact = 0.34, duration = 0.85, cooldown = 5 },
	M03 = { pose = "Bonk", contact = 0.23, duration = 0.58, cooldown = 0.8 },
	M04 = { pose = "BarrelThrow", contact = 0.52, duration = 1.10, cooldown = 5 },
	M05 = { pose = "Drink", contact = 0.82, duration = 1.30, cooldown = 25.82 },
	M06 = { pose = "Drink", contact = 0.82, duration = 1.30, cooldown = 10.82 },
	M07 = { pose = "Drink", contact = 0.82, duration = 1.30, cooldown = 15.82 },
	M08 = { pose = "Shake", contact = 0.65, duration = 1.05, cooldown = 3 },
	M10 = { pose = "Aim", contact = 0.35, duration = 0.80, cooldown = 5 },
	M11 = { pose = "Throw", contact = 0.30, duration = 0.78, cooldown = 2 },
	M12 = { pose = "Throw", contact = 0.30, duration = 0.78, cooldown = 3 },
	M13 = { pose = "Throw", contact = 0.30, duration = 0.78, cooldown = 3 },
	M14 = { pose = "Aim", contact = 0.35, duration = 0.80, cooldown = 1 },
	M15 = { pose = "Place", contact = 0.46, duration = 1, cooldown = 15.46 },
}
local palette = { Color3.fromRGB(255, 93, 131), Color3.fromRGB(70, 201, 255), Color3.fromRGB(255, 212, 72), Color3.fromRGB(117, 228, 137), Color3.fromRGB(195, 122, 255) }

local function now() return workspace:GetServerTimeNow() end
local function participating(player)
	return player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true or player:GetAttribute("MDParticipating") == true
end
local function finiteVector(value)
	return typeof(value) == "Vector3" and value.X == value.X and value.Y == value.Y and value.Z == value.Z
		and math.abs(value.X) < 1000000 and math.abs(value.Y) < 1000000 and math.abs(value.Z) < 1000000
end
local function setAttribute(object, key, value)
	if object:GetAttribute(key) ~= value then object:SetAttribute(key, value) end
end
local function part(name, size, color, parent)
	local object = Instance.new("Part")
	object.Name, object.Size, object.Color = name, size, color
	object.Anchored, object.CanCollide, object.CanTouch, object.CanQuery = true, false, false, false
	object.Material, object.TopSurface, object.BottomSurface = Enum.Material.SmoothPlastic, Enum.SurfaceType.Studs, Enum.SurfaceType.Smooth
	object.Parent = parent
	return object
end

function Toys.new(options)
	options = options or {}
	return setmetatable({ records = {}, objects = {}, running = false, playBonk = options.playBonk, random = Random.new() }, Toys)
end

function Toys:_inside(position)
	local bounds = self.bounds
	if not bounds or not bounds.Parent or not finiteVector(position) then return false end
	local point, half = bounds.CFrame:PointToObjectSpace(position), bounds.Size * 0.5
	return math.abs(point.X) <= half.X and math.abs(point.Z) <= half.Z and math.abs(point.Y) <= half.Y + 20
end

function Toys:_character(player)
	if not player or player.Parent ~= Players or player:GetAttribute("PCDataReady") ~= true or participating(player) then return nil end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not humanoid or humanoid.Health <= 0 or not self:_inside(root.Position) then return nil end
	return character, humanoid, root
end

function Toys:_record(player)
	local character, humanoid = self:_character(player)
	if not character then return nil end
	local record = self.records[player]
	if record and record.character ~= character then self:ClearPlayer(player) record = nil end
	if not record then
		record = { player = player, character = character, humanoid = humanoid, cooldowns = {}, serial = 0, speedUntil = 0, jumpUntil = 0, emberUntil = 0, freezeUntil = 0, burnUntil = 0, busyUntil = 0, nextFire = 0 }
		self.records[player] = record
	end
	return record
end

function Toys:Hold(player)
	return self:_record(player) ~= nil
end

function Toys:_restoreVisual(record)
	if not record.hidden then return end
	for object, transparency in pairs(record.hidden) do if object.Parent then object.Transparency = transparency end end
	record.hidden = nil
end

function Toys:_hideVisual(record, tool)
	self:_restoreVisual(record)
	local visual = tool:FindFirstChild("Visual")
	if not visual then return end
	record.hidden = {}
	for _, object in ipairs(visual:GetDescendants()) do
		if object:IsA("BasePart") then record.hidden[object] = object.Transparency object.Transparency = 1 end
	end
end

function Toys:_ray(origin, direction, owner, ignoreCharacters)
	local excludes = { self.folder }
	if owner and owner.Character then table.insert(excludes, owner.Character) end
	if ignoreCharacters then for _, player in ipairs(Players:GetPlayers()) do if player.Character then table.insert(excludes, player.Character) end end end
	local params = RaycastParams.new()
	params.FilterType, params.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude, excludes
	params.IgnoreWater = true
	return workspace:Raycast(origin, direction, params)
end

function Toys:_direction(root, aim)
	local direction = finiteVector(aim) and aim - root.Position or root.CFrame.LookVector
	if direction.Magnitude < 0.1 then direction = root.CFrame.LookVector end
	return direction.Unit
end

function Toys:_burst(position, color, kind, count)
	local anchor = part("ToyBurst", Vector3.new(0.1, 0.1, 0.1), color, self.folder)
	anchor.Transparency, anchor.Position = 1, position
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = kind == "fire" and "rbxasset://textures/particles/fire_main.dds" or "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Rate = 0
	emitter.Color = ColorSequence.new(color, kind == "fire" and Color3.fromRGB(255, 211, 80) or Color3.new(1, 1, 1))
	emitter.Lifetime, emitter.Speed, emitter.SpreadAngle = NumberRange.new(0.35, 0.8), NumberRange.new(3, 8), Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(kind == "fire" and 0.65 or 0.22, 0)
	emitter.LightEmission, emitter.Parent = 0.3, anchor
	emitter:Emit(count or 16)
	Debris:AddItem(anchor, 1)
end

function Toys:_confetti(position, owner)
	for i = 1, 16 do
		local confetti = part("Confetti", Vector3.new(0.12, 0.05, 0.23), palette[(i - 1) % #palette + 1], self.folder)
		confetti.Position = position
		self:_object(owner, confetti, 2, { position = position, velocity = Vector3.new(self.random:NextNumber(-8, 8), self.random:NextNumber(7, 14), self.random:NextNumber(-8, 8)), gravity = 18, spin = Vector3.new(5, 3, 2), cosmetic = true })
	end
end

function Toys:_object(owner, object, lifetime, data)
	data = data or {}
	data.owner, data.object, data.expiresAt = owner, object, now() + lifetime
	data.bornAt, data.originalPivot = now(), object:GetPivot()
	data.visualOffset = object:GetAttribute("ToyVisualOffset") or CFrame.identity
	table.insert(self.objects, data)
	return data
end

function Toys:_visual(id, position, length)
	local assets = ReplicatedStorage:FindFirstChild("PlaygroundCosmeticAssets")
	local source = assets and assets:FindFirstChild(id)
	if not source or not source:IsA("Model") then return nil end
	local clone = source:Clone()
	clone.Name = "Toy_" .. id
	for _, child in ipairs(clone:GetDescendants()) do
		if child:IsA("LuaSourceContainer") then child:Destroy()
		elseif child:IsA("BasePart") then
			child.Anchored, child.CanCollide, child.CanTouch, child.CanQuery = true, false, false, false
		elseif child:IsA("Highlight") then child.Adornee = clone end
	end
	local box, size = clone:GetBoundingBox()
	clone:ScaleTo(clone:GetScale() * length / math.max(size.X, size.Y, size.Z, 0.1))
	box = clone:GetBoundingBox()
	local offset = box:Inverse() * clone:GetPivot()
	clone:SetAttribute("ToyVisualOffset", offset)
	clone:PivotTo(CFrame.new(position) * offset)
	clone.Parent = self.folder
	return clone
end

function Toys:_ground(root, distance)
	local horizontal = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if horizontal.Magnitude < 0.1 then horizontal = Vector3.new(0, 0, -1) else horizontal = horizontal.Unit end
	local origin = root.Position + horizontal * distance + Vector3.new(0, 2, 0)
	local hit = self:_ray(origin, Vector3.new(0, -12, 0), nil, true)
	if hit and hit.Normal.Y > 0.75 and self:_inside(hit.Position) then return hit.Position end
	return nil
end

function Toys:_padGround(root)
	local position = self:_ground(root, 5)
	if not position then return nil end
	for x = -1, 1, 2 do for z = -1, 1, 2 do
		local corner = position + Vector3.new(x * 2.7, 0, z * 2.7)
		if not self:_inside(corner) then return nil end
		local ground = self:_ray(corner + Vector3.new(0, 2, 0), Vector3.new(0, -4, 0), nil, true)
		if not ground or ground.Normal.Y < 0.75 or math.abs(ground.Position.Y - position.Y) > 0.5 then return nil end
	end end
	return position
end

function Toys:_boundedRange(origin, direction, distance)
	local target = origin + direction * distance
	if self:_inside(target) then return distance end
	local low, high = 0, distance
	for _ = 1, 14 do
		local middle = (low + high) / 2
		if self:_inside(origin + direction * middle) then low = middle else high = middle end
	end
	return low
end

function Toys:_movement(record, time)
	local humanoid = record.humanoid
	local active = record.speedUntil > time or record.jumpUntil > time or record.freezeUntil > time
	if active and not record.base then
		record.base = { WalkSpeed = humanoid.WalkSpeed, JumpPower = humanoid.JumpPower, JumpHeight = humanoid.JumpHeight, AutoRotate = humanoid.AutoRotate }
		record.written = {}
	end
	if not record.base then return end
	local frozen = record.freezeUntil > time
	local values = {
		WalkSpeed = frozen and 0 or record.base.WalkSpeed * (record.speedUntil > time and 3 or 1),
		JumpPower = frozen and 0 or record.base.JumpPower * (record.jumpUntil > time and math.sqrt(5) or 1),
		JumpHeight = frozen and 0 or record.base.JumpHeight * (record.jumpUntil > time and 5 or 1),
		AutoRotate = not frozen and record.base.AutoRotate,
	}
	for key, value in pairs(values) do humanoid[key] = value record.written[key] = humanoid[key] end
	if frozen then humanoid.Jump = false end
	if not active then record.base, record.written = nil, nil end
end

function Toys:_burn(owner, target)
	if owner == target or not self:_character(owner) then return end
	local record = self:_record(target)
	if not record or now() < (record.burnImmuneUntil or 0) then return end
	record.burnUntil, record.nextBurn, record.burnImmuneUntil, record.burnOwner = now() + 10, now() + 1, now() + 12, owner
	setAttribute(target, "PCToyBurnUntil", record.burnUntil)
	local root = record.character:FindFirstChild("HumanoidRootPart")
	local fire = Instance.new("Fire")
	fire.Name, fire.Size, fire.Heat = "ToyCampfire", 3, 2
	fire.Color, fire.SecondaryColor = Color3.fromRGB(255, 142, 45), Color3.fromRGB(255, 224, 102)
	fire.Parent, record.fire = root, fire
end

function Toys:_freeze(target)
	local record = self:_record(target)
	if not record or now() < (record.freezeImmuneUntil or 0) then return end
	record.freezeUntil, record.freezeImmuneUntil = now() + 2.5, now() + 6
	self:CancelAction(target)
	setAttribute(target, "PCToyFrozenUntil", record.freezeUntil)
	local outline = Instance.new("Highlight")
	outline.Name, outline.Adornee = "ToyFrost", record.character
	outline.FillColor, outline.FillTransparency = Color3.fromRGB(142, 233, 255), 0.35
	outline.OutlineColor, outline.DepthMode = Color3.fromRGB(214, 252, 255), Enum.HighlightDepthMode.Occluded
	outline.Parent, record.frost = record.character, outline
	self:_movement(record, now())
end

function Toys:_target(hit)
	if not hit then return nil end
	for _, player in ipairs(Players:GetPlayers()) do
		local character = self:_character(player)
		if character and hit.Instance:IsDescendantOf(character) then return player end
	end
	return nil
end

function Toys:_beam(origin, destination, color)
	local delta = destination - origin
	if delta.Magnitude < 0.01 then return end
	local beam = part("ToyRay", Vector3.new(0.14, 0.14, delta.Magnitude), color, self.folder)
	beam.Material, beam.CFrame = Enum.Material.Neon, CFrame.lookAt((origin + destination) / 2, destination)
	Debris:AddItem(beam, 0.16)
end

function Toys:_splat(position, normal, owner, cake)
	local color = cake and Color3.fromRGB(255, 238, 209) or palette[self.random:NextInteger(1, #palette)]
	local frame = CFrame.lookAt(position + normal * 0.04, position + normal)
	for i = 0, 6 do
		local size = i == 0 and 1.55 or self.random:NextNumber(0.25, 0.7)
		local blob = part(cake and "Frosting" or "PaintSplat", Vector3.new(size, size, 0.045), color, self.folder)
		blob.Shape = Enum.PartType.Ball
		local angle = i * math.pi / 3
		blob.CFrame = frame * CFrame.new(i == 0 and 0 or math.cos(angle) * 0.9, i == 0 and 0 or math.sin(angle) * 0.9, 0)
		self:_object(owner, blob, cake and 5 or 10)
	end
end

function Toys:_launch(record, id, root, direction)
	local position = root.Position + Vector3.new(0, 1.3, 0) + direction * 2
	local length, velocity = 1.6, direction * 48 + Vector3.new(0, 15, 0)
	if id == "M02" then velocity = direction * 20 + Vector3.new(0, 48, 0) length = 1.8 end
	if id == "M04" then position = root.Position + Vector3.new(0, 4, 0) velocity = direction * 38 + Vector3.new(0, 18, 0) length = 2.7 end
	if id == "M01" then
		local ground = self:_ground(root, 3)
		if not ground then return end
		local forward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		direction = forward.Magnitude > 0.1 and forward.Unit or Vector3.new(0, 0, -1)
		position, velocity = ground + Vector3.new(0, 0.9, 0), direction * 54 + Vector3.new(0, 5, 0)
		if record.stagedBall then
			local staged = record.stagedBall
			record.stagedBall = nil
			staged.kind, staged.position, staged.velocity, staged.gravity, staged.spin, staged.bounces = id, position, velocity, 60, Vector3.new(2, 1, 0), 0
			staged.expiresAt = now() + 5
			return
		end
	end
	local object
	if id == "M11" then
		object = part("FlyingPaint", Vector3.new(0.7, 0.7, 0.7), palette[self.random:NextInteger(1, #palette)], self.folder)
		object.Shape, object.Position = Enum.PartType.Ball, position
	else object = self:_visual(id, position, length) end
	if not object then return end
	self:_object(record.player, object, 5, { kind = id, position = position, velocity = velocity, gravity = 60, spin = Vector3.new(2, 1, 0), bounces = 0 })
end

function Toys:_placePad(record, root)
	local position = self:_padGround(root)
	if not position then return false end
	local model = self:_visual("M15", position + Vector3.new(0, 0.45, 0), 6)
	if not model then return false end
	local surface = part("BounceSurface", Vector3.new(5.2, 0.45, 5.2), Color3.fromRGB(73, 196, 228), model)
	surface.Transparency, surface.CanCollide, surface.CanQuery = 1, true, true
	surface.Position = position + Vector3.new(0, 0.45, 0)
	local entry = self:_object(record.player, model, 15, { kind = "Pad", surface = surface, nextBounce = {} })
	entry.padPosition = position
	setAttribute(record.player, "PCToyPadUntil", entry.expiresAt)
	return true
end

function Toys:_effect(record, id, aim, fireShot)
	local _, _, root = self:_character(record.player)
	if not root then return end
	local direction = self:_direction(root, aim)
	if id == "M05" then record.speedUntil = now() + 25 self:_movement(record, now()) setAttribute(record.player, "PCToySpeedUntil", record.speedUntil)
	elseif id == "M06" then record.jumpUntil = now() + 10 self:_movement(record, now()) setAttribute(record.player, "PCToyJumpUntil", record.jumpUntil)
	elseif id == "M07" and not fireShot then record.emberUntil = now() + 10 setAttribute(record.player, "PCToyEmberUntil", record.emberUntil)
	elseif id == "M07" or id == "M10" then
		local origin = root.Position + Vector3.new(0, 1.4, 0)
		local range = self:_boundedRange(origin, direction, id == "M10" and 55 or 32)
		local hit = self:_ray(origin, direction * range, record.player)
		local destination = hit and hit.Position or origin + direction * range
		self:_beam(origin, destination, id == "M10" and Color3.fromRGB(140, 233, 255) or Color3.fromRGB(255, 160, 55))
		self:_burst(destination, id == "M10" and Color3.fromRGB(140, 233, 255) or Color3.fromRGB(255, 160, 55), id == "M10" and "frost" or "fire", 12)
		local target = self:_target(hit)
		if target then if id == "M10" then self:_freeze(target) else self:_burn(record.player, target) end end
	elseif id == "M03" then
		local hit = self:_ray(root.Position + Vector3.new(0, 0.6, 0), direction * 6, record.player)
		if hit then self:_burst(hit.Position, Color3.fromRGB(255, 227, 96), "stars", 12) if self.playBonk then self.playBonk(hit.Position) end end
	elseif id == "M08" then
		self:_confetti(root.Position + root.CFrame.LookVector * 2 + Vector3.new(0, 1, 0), record.player)
	elseif id == "M14" then self:_burst(root.Position + direction * 2, Color3.fromRGB(255, 174, 65), "fire", 6)
	elseif id == "M15" then
		if not self:_placePad(record, root) then
			record.cooldowns.M15 = 0
			setAttribute(record.player, "PCToyCooldown_M15", 0)
			self:_restoreVisual(record)
		end
	else self:_launch(record, id, root, direction) end
end

function Toys:Use(player, tool, aim)
	local record = self:_record(player)
	if not self.running or not record then return { ok = false, message = "Toys are for the lobby." } end
	local id = player:GetAttribute("PCGear")
	if not tool or tool.Parent ~= record.character or tool:GetAttribute("CatalogId") ~= id or record.character:GetAttribute("PCToyHeld") ~= id then return { ok = false, message = "Choose a toy first." } end
	local config = actions[id]
	if not config then return { ok = false, message = "Plunger Popper is waiting for its plunger model." } end
	local time = now()
	if time < record.freezeUntil then return { ok = false, message = "Frozen for a moment!" } end
	if time < record.busyUntil then return { ok = false, message = "Finish this action first." } end
	local fireShot = id == "M07" and time < record.emberUntil
	local readyAt = fireShot and record.nextFire or (record.cooldowns[id] or 0)
	if time < readyAt then return { ok = false, message = "Recharging", cooldownEndsAt = readyAt } end
	if aim ~= nil and not finiteVector(aim) then return { ok = false, message = "Invalid aim." } end
	if id == "M15" then local _, _, root = self:_character(player) if not self:_padGround(root) then return { ok = false, message = "Place the pad on open ground." } end end
	local duration, contact, pose = config.duration, config.contact, config.pose
	if fireShot then
		duration, contact, pose = 0.8, 0.35, "Aim"
		record.nextFire = time + 0.8
		setAttribute(player, "PCToyEmberShotUntil", record.nextFire)
	else record.cooldowns[id] = time + config.cooldown end
	record.busyUntil, record.serial = time + duration, record.serial + 1
	local serial = record.serial
	player:SetAttribute("PCToyActionItem", id)
	player:SetAttribute("PCToyAction", pose)
	player:SetAttribute("PCToyActionAt", time)
	player:SetAttribute("PCToyCooldown_" .. id, record.cooldowns[id] or 0)
	local thrown = id == "M01" or id == "M02" or id == "M04" or id == "M12" or id == "M13" or id == "M15"
	if id == "M01" then
		task.delay(0.24, function()
			if self.records[player] ~= record or record.serial ~= serial or tool.Parent ~= record.character then return end
			local _, _, root = self:_character(player)
			local ground = root and self:_ground(root, 3)
			if ground then
				self:_hideVisual(record, tool)
				local object = self:_visual(id, ground + Vector3.new(0, 0.9, 0), 1.6)
				if object then record.stagedBall = self:_object(player, object, 5.4) end
			end
		end)
	end
	task.delay(contact, function()
		if not self.running or self.records[player] ~= record or record.serial ~= serial or not self:_character(player)
			or tool.Parent ~= record.character or player:GetAttribute("PCGear") ~= id or record.character:GetAttribute("PCToyHeld") ~= id then return end
		if now() < record.freezeUntil then return end
		if fireShot and now() >= record.emberUntil then return end
		if thrown then self:_hideVisual(record, tool) end
		self:_effect(record, id, aim, fireShot)
	end)
	if thrown then
		task.delay(id == "M15" and config.cooldown or duration, function()
			if self.records[player] == record and record.serial == serial then self:_restoreVisual(record) end
		end)
	end
	return { ok = true, cooldownEndsAt = fireShot and record.nextFire or record.cooldowns[id], message = id == "M07" and not fireShot and "Drink, then tap to breathe fire!" or "" }
end

function Toys:CancelAction(player)
	local record = self.records[player]
	if record then
		record.serial += 1 record.busyUntil = 0
		self:_restoreVisual(record)
		if record.stagedBall then record.stagedBall.object:Destroy() record.stagedBall = nil end
	end
	for _, key in ipairs({ "PCToyAction", "PCToyActionAt", "PCToyActionItem" }) do player:SetAttribute(key, nil) end
end

function Toys:ClearPlayer(player)
	self:CancelAction(player)
	local record = self.records[player]
	if record then
		if record.base and record.humanoid and record.humanoid.Parent then
			for key, value in pairs(record.base) do if record.humanoid[key] == record.written[key] then record.humanoid[key] = value end end
		end
		if record.fire then record.fire:Destroy() end
		if record.frost then record.frost:Destroy() end
		self.records[player] = nil
	end
	for i = #self.objects, 1, -1 do local entry = self.objects[i] if entry.owner == player then entry.object:Destroy() table.remove(self.objects, i) end end
	for _, target in pairs(self.records) do
		if target.burnOwner == player then target.burnUntil = 0 target.burnOwner = nil end
	end
	for _, key in ipairs({ "PCToySpeedUntil", "PCToyJumpUntil", "PCToyEmberUntil", "PCToyEmberShotUntil", "PCToyFrozenUntil", "PCToyBurnUntil", "PCToyPadUntil" }) do setAttribute(player, key, 0) end
	for id in pairs(actions) do setAttribute(player, "PCToyCooldown_" .. id, 0) end
end

function Toys:_tickPlayer(record, time)
	local player = record.player
	local _, _, root = self:_character(player)
	if not root or player.Character ~= record.character then self:ClearPlayer(player) return end
	self:_movement(record, time)
	if time >= record.freezeUntil and record.frost then record.frost:Destroy() record.frost = nil end
	if record.burnOwner and not self:_character(record.burnOwner) then record.burnUntil = 0 end
	if record.burnUntil > 0 and time >= record.nextBurn and record.nextBurn <= record.burnUntil then
		record.nextBurn += 1
		record.humanoid:TakeDamage(1)
	end
	if time >= record.burnUntil and record.fire then record.fire:Destroy() record.fire = nil setAttribute(player, "PCToyBurnUntil", 0) end
	if record.character:GetAttribute("PCToyHeld") == "M14" and time >= (record.nextTorch or 0) then
		record.nextTorch = time + 0.3
		local hand = record.character:FindFirstChild("RightHand") or record.character:FindFirstChild("Right Arm")
		local origin = hand and hand.Position or root.Position
		for _, target in ipairs(Players:GetPlayers()) do
			local _, _, targetRoot = self:_character(target)
			if target ~= player and targetRoot and (targetRoot.Position - origin).Magnitude <= 4 then
				local hit = self:_ray(origin, targetRoot.Position - origin, player)
				if hit and hit.Instance:IsDescendantOf(target.Character) then self:_burn(player, target) end
			end
		end
	end
end

function Toys:_tickObject(entry, time, dt)
	local object = entry.object
	if not object.Parent or time >= entry.expiresAt or not self:_character(entry.owner) then
		if entry.kind == "Pad" and object.Parent then self:_burst(entry.padPosition, Color3.fromRGB(100, 217, 240), "stars", 18) end
		return false
	end
	if entry.kind == "Pad" then
		for _, player in ipairs(Players:GetPlayers()) do
			local _, humanoid, root = self:_character(player)
			if root then
				local delta = root.Position - entry.surface.Position
				local footHeight = humanoid.HipHeight + root.Size.Y * 0.5
				local leg = player.Character:FindFirstChild("Left Leg")
				if leg then footHeight += leg.Size.Y end
				if math.abs(delta.X) < 2.8 and math.abs(delta.Z) < 2.8 and math.abs(delta.Y - footHeight) < 1.3 and root.AssemblyLinearVelocity.Y <= 2 and time >= (entry.nextBounce[player] or 0) then
					entry.nextBounce[player] = time + 0.9
					local velocity = root.AssemblyLinearVelocity
					root.AssemblyLinearVelocity = Vector3.new(velocity.X, 75, velocity.Z)
					self:_burst(entry.surface.Position, Color3.fromRGB(105, 236, 242), "stars", 10)
				end
			end
		end
		return true
	end
	if entry.shakeUntil then
		if time >= entry.shakeUntil then self:_confetti(entry.position, entry.owner) return false end
		object:PivotTo(CFrame.new(entry.position) * CFrame.Angles(0, 0, math.sin(time * 38) * 0.13) * entry.visualOffset)
		return true
	end
	if not entry.velocity then return true end
	entry.velocity += Vector3.new(0, -(entry.gravity or 60) * dt, 0)
	local nextPosition = entry.position + entry.velocity * dt
	if not self:_inside(nextPosition) then return false end
	local hit = not entry.cosmetic and self:_ray(entry.position, nextPosition - entry.position, entry.owner)
	if hit then
		if entry.kind == "M11" or entry.kind == "M13" then self:_splat(hit.Position, hit.Normal, entry.owner, entry.kind == "M13") return false
		elseif entry.kind == "M12" then
			entry.position = hit.Position + hit.Normal * 0.35
			entry.originalPivot = CFrame.new(entry.position) * entry.visualOffset
			entry.velocity, entry.shakeUntil = nil, time + 0.65
			object:PivotTo(entry.originalPivot)
			return true
		else
			entry.bounces = (entry.bounces or 0) + 1
			if entry.bounces > 8 or entry.velocity.Magnitude < 3 then entry.velocity = nil return true end
			entry.velocity = (entry.velocity - 2 * entry.velocity:Dot(hit.Normal) * hit.Normal) * 0.6
			nextPosition = hit.Position + hit.Normal * (entry.kind == "M04" and 1.1 or 0.75)
		end
	end
	entry.position = nextPosition
	local angle = entry.spin and entry.spin * (time - entry.bornAt) or Vector3.zero
	object:PivotTo(CFrame.new(nextPosition) * CFrame.Angles(angle.X, angle.Y, angle.Z) * entry.visualOffset)
	return true
end

function Toys:Start()
	if self.running then return self end
	local lobby = workspace:WaitForChild("Playground Lobby")
	self.bounds = lobby:WaitForChild("Gameplay"):WaitForChild("LobbyBounds")
	self.folder = Instance.new("Folder")
	self.folder.Name, self.folder.Parent = "PlaygroundToyEffects", workspace
	self.running = true
	self.heartbeat = RunService.Heartbeat:Connect(function(dt)
		local time = now()
		for _, record in pairs(self.records) do self:_tickPlayer(record, time) end
		for i = #self.objects, 1, -1 do local entry = self.objects[i] if not self:_tickObject(entry, time, math.min(dt, 0.1)) then entry.object:Destroy() table.remove(self.objects, i) end end
	end)
	self.leaving = Players.PlayerRemoving:Connect(function(player) self:ClearPlayer(player) end)
	return self
end

function Toys:Stop()
	self.running = false
	if self.heartbeat then self.heartbeat:Disconnect() end
	if self.leaving then self.leaving:Disconnect() end
	local players = {}
	for player in pairs(self.records) do table.insert(players, player) end
	for _, player in ipairs(players) do self:ClearPlayer(player) end
	if self.folder then self.folder:Destroy() end
	table.clear(self.objects)
end

return Toys


