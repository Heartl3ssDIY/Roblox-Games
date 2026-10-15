local clock = 100
local deferred = {}
local checks, failures = 0, {}
local function check(condition, message)
	checks += 1
	if not condition then table.insert(failures, message) print("FAIL: " .. message) end
end
local function near(a, b) return math.abs(a-b)<0.00001 end
local vectorMeta = {}
local Vector3 = {}
function Vector3.new(x,y,z) return setmetatable({X=x,Y=y,Z=z,__type="Vector3"},vectorMeta) end
Vector3.zero=Vector3.new(0,0,0)
vectorMeta.__add=function(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vectorMeta.__sub=function(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vectorMeta.__mul=function(a,b) if type(a)=="number" then a,b=b,a end return Vector3.new(a.X*b,a.Y*b,a.Z*b) end
vectorMeta.__index=function(a,key)
	if key=="Magnitude" then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z) end
	if key=="Unit" then return a*(1/a.Magnitude) end
	if key=="Dot" then return function(b,c) return b.X*c.X+b.Y*c.Y+b.Z*c.Z end end
end
local CFrame = {}
local frameMeta = {}
function CFrame.new(x,y,z)
	local position = type(x)=="table" and x or Vector3.new(x or 0,y or 0,z or 0)
	return setmetatable({Position=position,LookVector=Vector3.new(0,0,-1)},frameMeta)
end
function CFrame.Angles() return CFrame.new() end
function CFrame.lookAt(position) return CFrame.new(position) end
CFrame.identity=CFrame.new()
frameMeta.__mul=function(a,b) return CFrame.new(a.Position+b.Position) end
frameMeta.__index={PointToObjectSpace=function(a,p)return p-a.Position end,Inverse=function(a)return CFrame.new(a.Position*-1) end}
local function typeof(value) return type(value)=="table" and value.__type or type(value) end
local function object(class, fields)
	local result = fields or {}
	result.class, result.attributes, result.children = class, {}, {}
	function result:GetAttribute(key) return self.attributes[key] end
	function result:SetAttribute(key,value) self.attributes[key]=value end
	function result:FindFirstChild(name) return self.children[name] end
	function result:FindFirstChildOfClass(name) for _,v in pairs(self.children) do if v.class==name then return v end end end
	function result:IsA(name) return self.class==name end
	function result:Destroy() self.Parent=nil self.destroyed=true end
	function result:GetPivot() return self.pivot or CFrame.new() end
	function result:PivotTo(pivot) self.pivot=pivot end
	function result:IsDescendantOf(ancestor) return self.Parent==ancestor end
	return result
end
local Players=object("Players",{list={}})
function Players:GetPlayers() return self.list end
local services={Players=Players,ReplicatedStorage=object("ReplicatedStorage"),RunService={},Debris={AddItem=function()end}}
local game={GetService=function(_,name) return services[name] end}
local workspace={GetServerTimeNow=function()return clock end,Raycast=function()return nil end}
local Color3={fromRGB=function(...)return {...}end,new=function(...)return {...}end}
local ColorSequence={new=function(...)return {...}end}
local NumberRange={new=function(...)return {...}end}
local NumberSequence={new=function(...)return {...}end}
local Vector2={new=function(...)return {...}end}
local Random={new=function()return {NextNumber=function(_,a,b)return (a+b)/2 end,NextInteger=function(_,a)return a end}end}
local Enum={Material={SmoothPlastic="SmoothPlastic",Neon="Neon"},SurfaceType={Studs="Studs",Smooth="Smooth"},RaycastFilterType={Exclude="Exclude"},HighlightDepthMode={Occluded="Occluded"},PartType={Ball="Ball"},HumanoidRigType={R6="R6",R15="R15"}}
local RaycastParams={new=function()return {}end}
local Instance={new=function(class)return object(class)end}
local task={delay=function(seconds,callback)table.insert(deferred,{at=clock+seconds,callback=callback})end}
local Toys=(function()
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

end)()
local function makePlayer(rig)
	local player=object("Player",{Parent=Players})
	player:SetAttribute("PCDataReady",true)
	local character=object("Model",{Parent=workspace})
	local humanoid=object("Humanoid",{Parent=character,Health=100,WalkSpeed=16,JumpPower=50,JumpHeight=7.2,AutoRotate=true,HipHeight=rig=="R6" and 0 or 2,RigType=rig or "R15"})
	function humanoid:TakeDamage(value)self.Health-=value end
	local root=object("Part",{Parent=character,Position=Vector3.new(0,3.675,0),CFrame=CFrame.new(0,3.675,0),Size=Vector3.new(2,2,1),AssemblyLinearVelocity=Vector3.zero})
	character.children.Humanoid,character.children.HumanoidRootPart=humanoid,root
	character.children[rig=="R6" and "Right Leg" or "RightFoot"]=object("Part",{Size=Vector3.new(1,rig=="R6" and 2 or 1,1)})
	if rig=="R6" then character.children["Left Leg"]=object("Part",{Size=Vector3.new(1,2,1)}) end
	player.Character=character
	table.insert(Players.list,player)
	return player,character,humanoid,root
end
local function fresh()
	clock=100 deferred={} Players.list={}
	local service=Toys.new()
	service.running=true service.folder=object("Folder",{Parent=workspace})
	service.bounds=object("Part",{Parent=workspace,CFrame=CFrame.new(),Size=Vector3.new(200,20,200)})
	service._burst=function()end
	return service
end
local function equip(player,id)
	player:SetAttribute("PCGear",id) player.Character:SetAttribute("PCToyHeld",id)
	local tool=object("Tool",{Parent=player.Character})tool:SetAttribute("CatalogId",id)return tool
end
do
	local service=fresh() local player,character,humanoid,root=makePlayer()
	check(service:_character(player)==character,"ready lobby player accepted")
	for _,key in ipairs({"BBParticipating","TGParticipating","MDParticipating"}) do player:SetAttribute(key,true) check(service:_character(player)==nil,"reject "..key) player:SetAttribute(key,nil) end
	player:SetAttribute("PCDataReady",false) check(service:_character(player)==nil,"reject unready profile") player:SetAttribute("PCDataReady",true)
	root.Position=Vector3.new(500,0,0) check(service:_character(player)==nil,"reject outside lobby") root.Position=Vector3.new(0,3,0)
	humanoid.Health=0 check(service:_character(player)==nil,"reject dead player")
end
do
	local service=fresh() local player,_,humanoid=makePlayer() local record=service:_record(player)
	service:_effect(record,"M05") check(humanoid.WalkSpeed==48,"speed is 3x") check(record.speedUntil==125,"speed lasts 25s")
	service:_effect(record,"M06") check(near(humanoid.JumpHeight,36),"height is 5x") check(near(humanoid.JumpPower,50*math.sqrt(5)),"power is sqrt5 for 5x height") check(record.jumpUntil==110,"jump lasts 10s")
	service:_freeze(player) check(humanoid.WalkSpeed==0 and humanoid.JumpPower==0,"freeze stops movement") check(record.freezeUntil==102.5 and record.freezeImmuneUntil==106,"freeze and immunity timing")
	clock=101 service:_freeze(player) check(record.freezeUntil==102.5,"repeated freeze blocked")
	clock=102.5 service:_movement(record,clock) check(humanoid.WalkSpeed==48,"unfreeze preserves speed effect")
	clock=110 service:_movement(record,clock) check(near(humanoid.JumpHeight,7.2) and humanoid.JumpPower==50,"jump expiry restores height and power")
	clock=125 service:_movement(record,clock) check(humanoid.WalkSpeed==16 and record.base==nil,"speed expiry restores baseline")
	service:_effect(record,"M05") humanoid.WalkSpeed=22 service:ClearPlayer(player) check(humanoid.WalkSpeed==22,"teardown preserves externally changed walk speed")
end
do
	local service=fresh() local owner=makePlayer() local target,_,humanoid=makePlayer()
	service:_burn(owner,target) local record=service.records[target]
	check(record.burnUntil==110 and record.nextBurn==101,"burn starts 10s timed ticks")
	for step=1,10 do clock=100+step service:_tickPlayer(record,clock) end
	check(humanoid.Health==90,"burn exactly 10 one-HP ticks") clock=111 service:_tickPlayer(record,clock) check(humanoid.Health==90,"no extra burn ticks")
	check(record.fire==nil,"fire removed on expiry")
end
do
	local service=fresh() local player=makePlayer() local tool=equip(player,"M03") local effects=0
	service._effect=function()effects+=1 end
	check(service:Use(player,tool).ok,"valid use accepted") check(not service:Use(player,tool).ok,"busy use rejected")
	service:CancelAction(player) clock=100.23 deferred[1].callback() check(effects==0,"cancelled contact cannot apply effect")
	clock=101 check(service:Use(player,tool).ok,"use recovers after cooldown") player:SetAttribute("BBParticipating",true) clock=101.23 deferred[2].callback() check(effects==0,"round entry cancels queued effect")
end
do
	local service=fresh() local player=makePlayer() local tool=equip(player,"M03") local effects=0
	service._effect=function()effects+=1 end service:Use(player,tool) service:_freeze(player) clock=100.23 deferred[1].callback()
	check(effects==0,"a freeze arriving during windup cancels queued contact")
end
for _,rig in ipairs({"R6","R15"}) do
	local service=fresh() local owner=makePlayer(rig) local target,_,_,root=makePlayer(rig)
	local model=object("Model",{Parent=service.folder}) local surface=object("Part",{Position=Vector3.new(0,0.45,0)})
	local entry={owner=owner,object=model,kind="Pad",expiresAt=115,padPosition=Vector3.zero,surface=surface,nextBounce={}}
	service:_tickObject(entry,100,0.016)
	check(root.AssemblyLinearVelocity.Y==75,rig.." standing on pad receives bounce")
end
do
	local service=fresh() local owner=makePlayer() local position=Vector3.new(0,4,0)
	local offset=CFrame.new(5,0,0) local model=object("Model",{Parent=service.folder,pivot=CFrame.new(position)*offset})
	model:SetAttribute("ToyVisualOffset",offset)
	local entry=service:_object(owner,model,5,{kind="M02",position=position,velocity=Vector3.zero,gravity=0,visualPivotOffset=offset})
	service:_tickObject(entry,100.01,0.01)
	check(near(model:GetPivot().Position.X,5),"projectile motion preserves imported bounds-to-pivot offset")
end
do
	local service=fresh() local player,_,humanoid=makePlayer() local record=service:_record(player)
	local tool=equip(player,"M07")
	check(service:Use(player,tool).ok,"Ember drink accepted")
	check(record.cooldowns.M07==115.82,"Ember cooldown includes ten active seconds and five recovery seconds")
	clock=100.82 deferred[1].callback() check(record.emberUntil==110.82,"Ember active window starts after drinking")
	clock=101.3 check(service:Use(player,tool).ok,"Ember fire allowed during bottle cooldown")
	check(player:GetAttribute("PCToyAction")=="Aim","Ember repeat activation requests aiming")
	check(not service:Use(player,tool).ok,"Ember rapid activation rejected")
	clock=111 check(not service:Use(player,tool).ok,"Ember redrink blocked for five seconds after effect")
	clock=115.82 check(service:Use(player,tool).ok,"Ember redrink after recovery accepted")
	service:_effect(record,"M05") humanoid.Health=0 service:_tickPlayer(record,clock)
	check(service.records[player]==nil and humanoid.WalkSpeed==16,"death restores movement and clears record")
	check(player:GetAttribute("PCToyAction")==nil and player:GetAttribute("PCToySpeedUntil")==0,"death clears effect and action attributes")
end
do
	local service=fresh() local player=makePlayer() local tool=equip(player,"M03") local effects=0
	service._effect=function()effects+=1 end
	check(not service:Use(player,tool,Vector3.new(0/0,0,0)).ok,"nonfinite aim rejected")
	check(not service:Use(player,tool,"bad").ok,"wrong aim type rejected")
	check(service:Use(player,tool).ok,"bad requests do not consume cooldown")
	equip(player,"M02") clock=100.23 deferred[1].callback()
	check(effects==0,"changed active item invalidates pending contact")
	clock=101 tool=equip(player,"M09") check(not service:Use(player,tool).ok,"deferred plunger rejected")
	tool=equip(player,"M15") check(not service:Use(player,tool).ok,"pad placement without ground rejected")
	check(service.records[player].cooldowns.M15==nil,"invalid pad does not consume cooldown")
end
do
	local service=fresh() local owner=makePlayer() local target=makePlayer()
	service:_record(owner) service:_burn(owner,target)
	local targetRecord=service.records[target]
	local model=object("Model",{Parent=service.folder}) local entry=service:_object(owner,model,5)
	service:ClearPlayer(owner)
	check(model.destroyed and #service.objects==0,"owner cleanup destroys owned objects")
	check(targetRecord.burnUntil==0 and targetRecord.burnOwner==nil,"departing owner cancels their burns")
	service:_tickPlayer(targetRecord,clock) check(targetRecord.fire==nil,"cancelled burn visual cleaned")
	service:Stop()
	check(not service.running and next(service.records)==nil and #service.objects==0,"Stop clears all records and objects")
	check(service.folder.destroyed,"Stop destroys effects folder")
end
print("Toy service review: "..tostring(checks-#failures).."/"..tostring(checks).." passed; failures="..tostring(#failures))
if #failures>0 then error(table.concat(failures,"; ")) end
