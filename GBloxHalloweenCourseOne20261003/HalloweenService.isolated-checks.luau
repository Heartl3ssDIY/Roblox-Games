local Vector = {}
local vectorMeta = {}
vectorMeta.__index = function(self, key)
 if key == "Magnitude" then return math.sqrt(self.X*self.X + self.Y*self.Y + self.Z*self.Z) end
 if key == "Unit" then local n = self.Magnitude return n > 0 and self/n or setmetatable({X=0,Y=0,Z=0}, vectorMeta) end
 return Vector[key]
end
vectorMeta.__add = function(a,b) return setmetatable({X=a.X+b.X,Y=a.Y+b.Y,Z=a.Z+b.Z},vectorMeta) end
vectorMeta.__sub = function(a,b) return setmetatable({X=a.X-b.X,Y=a.Y-b.Y,Z=a.Z-b.Z},vectorMeta) end
vectorMeta.__unm = function(a) return setmetatable({X=-a.X,Y=-a.Y,Z=-a.Z},vectorMeta) end
vectorMeta.__mul = function(a,b)
 if type(a)=="number" then a,b=b,a end
 return setmetatable({X=a.X*b,Y=a.Y*b,Z=a.Z*b},vectorMeta)
end
vectorMeta.__div = function(a,b) return a*(1/b) end
function Vector:Dot(other) return self.X*other.X+self.Y*other.Y+self.Z*other.Z end
local Vector3 = {}
function Vector3.new(x,y,z) return setmetatable({X=x,Y=y,Z=z},vectorMeta) end
Vector3.zero=Vector3.new(0,0,0)
Vector3.xAxis=Vector3.new(1,0,0)
Vector3.yAxis=Vector3.new(0,1,0)
Vector3.zAxis=Vector3.new(0,0,1)

local Frame = {}
local frameMeta = {}
local CFrame = {}
function CFrame.new(x,y,z)
 local position = type(x)=="table" and x or Vector3.new(x or 0,y or 0,z or 0)
 return setmetatable({Position=position,sign=1},frameMeta)
end
frameMeta.__index = function(self,key)
 if key=="Rotation" then local rotation=CFrame.new() rotation.sign=self.sign return rotation end
 if key=="RightVector" then return Vector3.new(self.sign,0,0) end
 if key=="UpVector" then return Vector3.new(0,self.sign,0) end
 if key=="ZVector" then return Vector3.zAxis end
 return Frame[key]
end
function Frame:PointToObjectSpace(position)
 local offset=position-self.Position
 return Vector3.new(offset.X*self.sign,offset.Y*self.sign,offset.Z)
end
function Frame:ToObjectSpace(other)
 local result=CFrame.new(self:PointToObjectSpace(other.Position))
 result.sign=self.sign*other.sign
 return result
end
frameMeta.__mul = function(a,b)
 if getmetatable(b)==vectorMeta then return a.Position+Vector3.new(b.X*a.sign,b.Y*a.sign,b.Z) end
 local result=CFrame.new(a*b.Position)
 result.sign=a.sign*b.sign
 return result
end
function CFrame.lookAt(position,_target,up)
 local frame=CFrame.new(position) frame.sign=up.Y return frame
end
function CFrame.Angles() return CFrame.new() end
CFrame.identity=CFrame.new()

local methods = {}
local instanceMeta = {}
local Instance = {}
instanceMeta.__index=function(self,key)
 if key=="Position" then return self._properties.CFrame.Position end
 return methods[key] or self._properties[key]
end
instanceMeta.__newindex=function(self,key,value)
 if key=="Parent" then
  local previous=self._properties.Parent
  if previous then
   local index=table.find(previous._children,self)
   if index then table.remove(previous._children,index) end
  end
  self._properties.Parent=value
  if value then table.insert(value._children,self) end
 else self._properties[key]=value end
end
function Instance.new(class)
 return setmetatable({_attrs={},_children={},_properties={ClassName=class,Name=class,Size=Vector3.new(2,2,2),CFrame=CFrame.new(),WorldPivot=CFrame.new(),Transparency=0}},instanceMeta)
end
function methods:IsA(class)
 return self.ClassName==class or (class=="BasePart" and (self.ClassName=="Part" or self.ClassName=="SpawnLocation"))
end
function methods:SetAttribute(name,value) self._attrs[name]=value end
function methods:GetAttribute(name) return self._attrs[name] end
function methods:GetChildren() return table.clone(self._children) end
function methods:GetDescendants()
 local result={}
 local function add(object)
  for _,child in object._children do table.insert(result,child) add(child) end
 end
 add(self)
 return result
end
function methods:FindFirstChild(name,recursive)
 for _,child in self._children do if child.Name==name then return child end end
 if recursive then
  for _,child in self._children do local result=child:FindFirstChild(name,true) if result then return result end end
 end
 return nil
end
function methods:IsDescendantOf(ancestor)
 local current=self.Parent
 while current do if current==ancestor then return true end current=current.Parent end
 return false
end
function methods:Destroy()
 self.Parent=nil
 for _,child in self:GetChildren() do child:Destroy() end
 self.Destroyed=true
end
function methods:Clone()
 local clone=Instance.new(self.ClassName)
 for key,value in self._properties do if key~="Parent" then clone[key]=value end end
 clone._attrs=table.clone(self._attrs)
 for _,child in self._children do local copied=child:Clone() copied.Parent=clone end
 return clone
end
function methods:GetPivot() return self.WorldPivot end
function methods:PivotTo(frame)
 local previous=self:GetPivot()
 for _,object in self:GetDescendants() do
  if object:IsA("BasePart") then object.CFrame=frame*previous:ToObjectSpace(object.CFrame)
  elseif object:IsA("Model") then object.WorldPivot=frame*previous:ToObjectSpace(object.WorldPivot) end
 end
 self.WorldPivot=frame
end
function methods:GetScale() return self.Scale or 1 end
function methods:ScaleTo(value)
 local factor=value/self:GetScale()
 local frame=self:GetPivot()
 for _,object in self:GetDescendants() do
  if object:IsA("BasePart") then
   object.Size*=factor
   object.CFrame=CFrame.new(frame.Position+(object.Position-frame.Position)*factor)
  end
 end
 self.Scale=value
end
function methods:GetBoundingBox()
 local center=self:GetPivot().Position
 local maximum=Vector3.new(0,0,0)
 for _,object in self:GetDescendants() do
  if object:IsA("BasePart") then
   local offset=object.Position-center
   maximum=Vector3.new(math.max(maximum.X,math.abs(offset.X)+object.Size.X/2),math.max(maximum.Y,math.abs(offset.Y)+object.Size.Y/2),math.max(maximum.Z,math.abs(offset.Z)+object.Size.Z/2))
  end
 end
 return CFrame.new(center),maximum*2
end

local Players=Instance.new("Folder")
local ReplicatedStorage=Instance.new("Folder")
local Workspace=Instance.new("Folder")
local currentSupport
function methods:Raycast(position,direction,_parameters)
 return currentSupport and {Position=Vector3.new(position.X,0,position.Z),Normal=direction.Y>0 and -Vector3.yAxis or Vector3.yAxis,Instance=currentSupport} or nil
end
local game={}
function game:GetService(name)
 if name=="Players" then return Players end
 if name=="ReplicatedStorage" then return ReplicatedStorage end
 if name=="Workspace" then return Workspace end
 error("Unexpected service "..name)
end
local Enum={RaycastFilterType={Include="Include"}}
local RaycastParams={new=function() return {} end}
local function typeof(value)
 if getmetatable(value)==vectorMeta then return "Vector3" end
 return type(value)
end

local Subject=(function()


local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Service = {}

local defaults = {
 Enabled = true,
 PollInterval = 0.1,
 WebHoldSeconds = 5,
 WebCooldown = 30,
 WebLifetime = 8,
 WebRadius = 7,
 WebMaxActive = 6,
 CornerWebHoldSeconds = 5,
 CornerWebImmunity = 3,
 GraveStuckSeconds = 1,
 GraveHoldSeconds = 5,
 GraveStillRadius = 0.75,
 GraveStillSpeed = 2.5,
 GhostInitialDelay = 8,
 GhostBaseSpeed = 24,
 GhostMaxSpeed = 60,
 GhostSpeedIncrease = 1.1,
 GhostSpeedInterval = 1.1,
 GhostSpawnBehind = 22,
 GhostCatchRadius = 3.2,
 PumpkinCooldown = 10,
 PumpkinRange = 70,
 PumpkinSpeed = 70,
 PumpkinLifetime = 2,
 PumpkinHitRadius = 3,
 PumpkinSplatSeconds = 3,
}

local limits = {
 PollInterval = {0.1, 0.5},
 WebHoldSeconds = {0.5, 10},
 WebCooldown = {1, 120},
 WebLifetime = {1, 20},
 WebRadius = {2, 12},
 WebMaxActive = {1, 12},
 CornerWebHoldSeconds = {0.5, 10},
 CornerWebImmunity = {0.5, 15},
 GraveStuckSeconds = {0.5, 5},
 GraveHoldSeconds = {1, 10},
 GraveStillRadius = {0.1, 2},
 GraveStillSpeed = {0.5, 5},
 GhostInitialDelay = {2, 30},
 GhostBaseSpeed = {5, 60},
 GhostMaxSpeed = {5, 100},
 GhostSpeedIncrease = {0, 5},
 GhostSpeedInterval = {0.5, 10},
 GhostSpawnBehind = {12, 50},
 GhostCatchRadius = {1, 5},
 PumpkinCooldown = {1, 120},
 PumpkinRange = {10, 100},
 PumpkinSpeed = {20, 100},
 PumpkinLifetime = {0.5, 4},
 PumpkinHitRadius = {1, 4},
 PumpkinSplatSeconds = {0.5, 5},
}

local function validNumber(value)
 return typeof(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function destroy(instance)
 if instance then instance:Destroy() end
end

local function pivot(instance, cframe)
 if instance:IsA("Model") then instance:PivotTo(cframe)
 elseif instance:IsA("BasePart") then instance.CFrame = cframe end
end

local function assetPivot(instance)
 if instance:IsA("Model") then return instance:GetPivot() end
 return instance.CFrame
end

local function assetSize(instance)
 if instance:IsA("Model") then
  local _, size = instance:GetBoundingBox()
  return size
 end
 return instance.Size
end

local function visibleClone(source, name, parent, maximumSize, centered)
 if not source or (not source:IsA("Model") and not source:IsA("BasePart")) then return nil end
 local clone = source:Clone()
 clone.Name = name
 clone:SetAttribute("HalloweenRestHidden", nil)
 local parts = clone:GetDescendants()
 if clone:IsA("BasePart") then table.insert(parts, clone) end
 for _, object in parts do
  if object:IsA("BasePart") then
   object.Anchored = true
   object.CanCollide = false
   object.CanTouch = false
   object.CanQuery = false
   object.CastShadow = false
   object:SetAttribute("HalloweenRestHidden", nil)
   local visible = object:GetAttribute("HalloweenVisibleTransparency")
   if validNumber(visible) then object.Transparency = math.clamp(visible, 0, 1) end
  elseif object:IsA("Script") or object:IsA("LocalScript") then
   object:Destroy()
  end
 end
 if maximumSize then
  local size = assetSize(clone)
  local largest = math.max(size.X, size.Y, size.Z)
  if largest > 0.01 then
   local scale = maximumSize / largest
   if clone:IsA("Model") then clone:ScaleTo(clone:GetScale() * scale)
   else clone.Size *= scale end
  end
 end
 if centered and clone:IsA("Model") then
  local center = clone:GetBoundingBox()
  local rotation = assetPivot(clone).Rotation
  clone.PrimaryPart = nil
  clone.WorldPivot = CFrame.new(center.Position) * rotation
 end
 clone.Parent = parent
 return clone
end

local function frameAt(position, sign)
 return CFrame.lookAt(position, position - Vector3.xAxis, Vector3.new(0, sign, 0))
end

local function contains(sensor, data)
 local collider = data.collider or data.root
 local half = collider.Size * 0.5
 local colliderFrame = sensor.CFrame:ToObjectSpace(collider.CFrame)
 local right, up, back = colliderFrame.RightVector, colliderFrame.UpVector, colliderFrame.ZVector
 local extent = Vector3.new(
  math.abs(right.X) * half.X + math.abs(up.X) * half.Y + math.abs(back.X) * half.Z,
  math.abs(right.Y) * half.X + math.abs(up.Y) * half.Y + math.abs(back.Y) * half.Z,
  math.abs(right.Z) * half.X + math.abs(up.Z) * half.Y + math.abs(back.Z) * half.Z
 )
 local offset = sensor.CFrame:PointToObjectSpace(data.root.Position)
 local bounds = sensor.Size * 0.5 + extent
 return math.abs(offset.X) <= bounds.X and math.abs(offset.Y) <= bounds.Y and math.abs(offset.Z) <= bounds.Z
end

local function segmentDistanceSquared(point, from, to)
 local delta = to - from
 local lengthSquared = delta:Dot(delta)
 local alpha = lengthSquared > 0.0001 and math.clamp((point - from):Dot(delta) / lengthSquared, 0, 1) or 0
 local offset = point - (from + delta * alpha)
 return offset:Dot(offset)
end

function Service.new(context)
 local self = {}
 local runtime
 local activeRound
 local activeCourse
 local activeSince
 local previousRound
 local spentRound
 local clock = 0
 local ghost
 local webs = {}
 local projectiles = {}
 local traps = {}
 local holds = {}
 local frozen = {}
 local cooldowns = {}
 local lastRequest = {}
 local nextId = 0
 local raycast = RaycastParams.new()
 raycast.FilterType = Enum.RaycastFilterType.Include
 raycast.RespectCanCollide = true

 local function setting(name)
  local value = context.Settings and context.Settings:GetAttribute(name)
  if name == "Enabled" then return value ~= false end
  if not validNumber(value) then value = defaults[name] end
  local bounds = limits[name]
  return bounds and math.clamp(value, bounds[1], bounds[2]) or value
 end

 local function enabled()
  local theme = ReplicatedStorage:FindFirstChild("GBloxCourseTheme")
  return setting("Enabled") and theme and theme:GetAttribute("ActiveTheme") == "Halloween"
   and context.CourseNumber() == 1 and context.Phase() == "Running"
 end

 local function validRunner(player, data, allowFrozen)
  if not data or context.Runners[player] ~= data or player.Parent ~= Players
   or data.status ~= "Running" or data.recovering or data.courseVersion ~= context.RoundKey()
   or not data.character or data.character ~= player.Character
   or not data.root or not data.root.Parent or not data.root:IsDescendantOf(data.character)
   or not data.humanoid or data.humanoid.Health <= 0
   or (data.invulnerableUntil or 0) > context.Now() then return false end
  if not allowFrozen and (data.root.Anchored or (data.freezeUntil or 0) > context.Now()) then return false end
  return data.gravitySign == 1 or data.gravitySign == -1
 end

 local function source(name)
  return context.Templates and context.Templates:FindFirstChild(name)
 end

 local function allocateId()
  nextId += 1
  return nextId
 end

 local function makeRuntime()
  if runtime and runtime.Parent then return runtime end
  runtime = Instance.new("Folder")
  runtime.Name = "GBloxHalloweenRuntime"
  runtime:SetAttribute("CourseVersion", context.RoundKey())
  runtime.Parent = Workspace
  return runtime
 end

 local function clearFreeze(player)
  if not frozen[player] then return end
  frozen[player] = nil
  if context.ClearFreeze then context.ClearFreeze(player) end
  player:SetAttribute("GBloxHalloweenTrappedUntil", nil)
 end

 local function freeze(player, data, seconds)
  local untilTime = context.Now() + seconds
  local acceptedUntil = context.Freeze(player, seconds)
  if validNumber(acceptedUntil) then untilTime = acceptedUntil end
  frozen[player] = {data = data, root = data.root, round = context.RoundKey(), untilTime = untilTime}
  player:SetAttribute("GBloxHalloweenTrappedUntil", untilTime)
  return untilTime
 end

 local function clearHold(player)
  local hold = holds[player]
  if not hold then return end
  holds[player] = nil
  destroy(hold.hand)
  player:SetAttribute("GBloxHalloweenGraveUntil", nil)
 end

 local function supportHit(data)
  if not activeCourse or not activeCourse.Parent then return nil end
  raycast.FilterDescendantsInstances = {activeCourse}
  local up = Vector3.new(0, data.gravitySign, 0)
  local result = Workspace:Raycast(data.root.Position, -up * 6.5, raycast)
  if not result or result.Normal:Dot(up) < 0.9 then return nil end
  if context.IsPlatform then
   if not context.IsPlatform(result.Instance) then return nil end
  elseif result.Instance.Name ~= "Flat_Platform_RunSurface" and not result.Instance:IsA("SpawnLocation") then
   return nil
  end
  return result
 end

 local function trapGrounded(trap, data)
  local sign = trap.model:GetAttribute("SurfaceNormalY")
  if sign and sign ~= data.gravitySign then return false end
  local hit = supportHit(data)
  if not hit then return false end
  local reference = trap.model:FindFirstChild("Support")
  local support = reference and reference:IsA("ObjectValue") and reference.Value
  return not support or hit.Instance == support or hit.Instance:IsDescendantOf(support)
 end

 local function loadTraps()
  traps = {}
  local gameplay = activeCourse and activeCourse:FindFirstChild("HalloweenGameplay")
  local folder = gameplay and gameplay:FindFirstChild("Traps")
  if not folder then return end
  for _, model in folder:GetChildren() do
   local kind = model:GetAttribute("TrapType")
   local sensor = model:FindFirstChild("Sensor")
   if (kind == "CornerWeb" or kind == "Grave") and sensor and sensor:IsA("BasePart") then
    table.insert(traps, {model = model, sensor = sensor, kind = kind, dwell = {}, immune = {}})
   end
  end
 end

 local function begin()
  activeRound = context.RoundKey()
  activeCourse = context.Course()
  activeSince = context.Now()
  makeRuntime()
  loadTraps()
 end

 local function animateHand(hold, now)
  if not hold.hand or not hold.hand.Parent then return end
  local rise = math.clamp((now - hold.startedAt) / 0.6, 0, 1)
  local sink = math.clamp((now - (hold.untilTime - 0.7)) / 0.7, 0, 1)
  local up = Vector3.new(0, hold.sign, 0)
  local handFrame = frameAt(hold.position - up * (0.35 + (1 - rise) * 3 + sink * 3), hold.sign)
   * CFrame.new(-hold.palmOffset)
  pivot(hold.hand, handFrame)
  local curl = math.clamp((now - hold.startedAt - 0.3) / 0.6, 0, 1)
  for _, finger in hold.fingers do
   if finger.model.Parent then
    finger.model:PivotTo(handFrame * finger.localPivot * CFrame.Angles(math.rad(finger.degrees) * curl, 0, 0))
   end
  end
 end

 local function captureGrave(trap, player, data, now)
  local nested = trap.model:FindFirstChild("ZombieHand")
  local hand = visibleClone(nested or source("Zombie_Hand"), "GraveGrab_" .. player.UserId, makeRuntime(), 5.5)
  local hold = {
   data = data, root = data.root, round = activeRound, sign = data.gravitySign,
   position = data.root.Position, startedAt = now, untilTime = now + setting("GraveHoldSeconds"),
   hand = hand, fingers = {}, palmOffset = Vector3.zero,
  }
  if hand and hand:IsA("Model") then
   local handFrame = assetPivot(hand)
   local palm = hand:FindFirstChild("Halloween_Palm", true)
   if palm and palm:IsA("BasePart") then hold.palmOffset = handFrame:PointToObjectSpace(palm.Position) end
   for _, object in hand:GetDescendants() do
    if object:IsA("Model") and (object.Name:match("^Finger%d+$") or object.Name == "Thumb") then
     local degrees = object:GetAttribute("CurlDegrees")
     table.insert(hold.fingers, {model = object, localPivot = handFrame:ToObjectSpace(object:GetPivot()), degrees = validNumber(degrees) and degrees or -55})
    end
   end
  end
  holds[player] = hold
  trap.dwell[player] = nil
  freeze(player, data, setting("GraveHoldSeconds"))
  player:SetAttribute("GBloxHalloweenGraveUntil", hold.untilTime)
  animateHand(hold, now)
  context.Broadcast("GraveGrab", {
   userId = player.UserId, position = hold.position, gravitySign = hold.sign,
   startedAt = now, untilTime = hold.untilTime, roundKey = activeRound,
  })
 end

 local function stepHolds(now)
  for player, hold in holds do
   if not validRunner(player, hold.data, true) or hold.root ~= hold.data.root
    or hold.round ~= activeRound or hold.sign ~= hold.data.gravitySign then
    clearHold(player)
    clearFreeze(player)
   elseif now >= hold.untilTime then
    clearHold(player)
    clearFreeze(player)
    context.Eliminate(player, "A zombie hand pulled you into the grave")
   else
    animateHand(hold, now)
   end
  end
 end

 local function stepTraps(now)
  for _, trap in traps do
   if not trap.model.Parent or not trap.sensor.Parent then continue end
   for player, data in context.Runners do
    local inTrap = validRunner(player, data, false) and not holds[player]
     and contains(trap.sensor, data) and trapGrounded(trap, data)
    if trap.kind == "CornerWeb" then
     if inTrap and now >= (trap.immune[player] or 0) then
      local seconds = setting("CornerWebHoldSeconds")
      trap.immune[player] = now + seconds + setting("CornerWebImmunity")
      freeze(player, data, seconds)
     end
    elseif not inTrap then
     trap.dwell[player] = nil
    else
     local dwell = trap.dwell[player]
     local radius = setting("GraveStillRadius")
     local stationary = data.root.AssemblyLinearVelocity.Magnitude <= setting("GraveStillSpeed")
     if not stationary or not dwell or dwell.root ~= data.root or dwell.sign ~= data.gravitySign
      or (data.root.Position - dwell.position).Magnitude > radius then
      trap.dwell[player] = stationary and {root = data.root, sign = data.gravitySign, since = now, position = data.root.Position} or nil
     elseif now - dwell.since >= setting("GraveStuckSeconds") then
      captureGrave(trap, player, data, now)
     end
    end
   end
  end
 end

 local function removeWeb(id)
  local web = webs[id]
  if web then webs[id] = nil destroy(web.model) end
 end

 local function stepWebs(now)
  for id, web in webs do
   if now >= web.untilTime or not web.model.Parent or not web.support.Parent then
    removeWeb(id)
   else
    local moved = web.support.CFrame * web.localFrame
    pivot(web.model, moved)
    web.frame = moved
    for player, data in context.Runners do
     if player ~= web.owner and not web.victims[player] and validRunner(player, data, false)
      and data.gravitySign == web.sign and not holds[player] then
      local position = web.frame:PointToObjectSpace(data.root.Position)
      if position.X * position.X + position.Z * position.Z <= web.radius * web.radius
       and position.Y >= 1 and position.Y <= 5.5 then
       local hit = supportHit(data)
       if hit and hit.Instance == web.support then
        web.victims[player] = true
        freeze(player, data, setting("WebHoldSeconds"))
       end
      end
     end
    end
   end
  end
 end

 local function leastProgress()
  local selectedPlayer, selectedData, selectedProgress
  for player, data in context.Runners do
   if validRunner(player, data, true) then
    local progress = context.Progress(data)
    if validNumber(progress) and (not selectedPlayer or progress < selectedProgress
     or (progress == selectedProgress and player.UserId < selectedPlayer.UserId)) then
     selectedPlayer, selectedData, selectedProgress = player, data, progress
    end
   end
  end
  return selectedPlayer, selectedData
 end

 local function stepGhost(now, dt)
  if spentRound == activeRound or now - activeSince < setting("GhostInitialDelay") then return end
  local player, data = leastProgress()
  if not player then destroy(ghost and ghost.model) ghost = nil return end
  if not ghost then
   local model = visibleClone(source("Ghost"), "LastPlaceGhost", makeRuntime(), 8, true)
   if not model then return end
   ghost = {model = model, position = data.root.Position + Vector3.xAxis * setting("GhostSpawnBehind")}
  end
  local elapsed = math.max(0, now - activeSince - setting("GhostInitialDelay"))
  local speed = math.min(setting("GhostMaxSpeed"), setting("GhostBaseSpeed")
   + math.floor(elapsed / setting("GhostSpeedInterval")) * setting("GhostSpeedIncrease"))
  local targetPosition = data.root.Position
  local previousPosition = ghost.position
  local offset = targetPosition - previousPosition
  local distance = offset.Magnitude
  if distance > 0.001 then ghost.position += offset.Unit * math.min(speed * dt, distance) end
  ghost.model:SetAttribute("TargetUserId", player.UserId)
  ghost.model:SetAttribute("Speed", speed)
  pivot(ghost.model, frameAt(ghost.position, data.gravitySign))
  local radius = setting("GhostCatchRadius")
  if segmentDistanceSquared(targetPosition, previousPosition, ghost.position) <= radius * radius then
   spentRound = activeRound
   destroy(ghost.model)
   ghost = nil
   clearHold(player)
   clearFreeze(player)
   context.Eliminate(player, "The ghost caught the last racer")
  end
 end

 local function removeProjectile(id)
  local projectile = projectiles[id]
  if projectile then projectiles[id] = nil destroy(projectile.model) end
 end

 local function stepProjectiles(now, dt)
  for id, projectile in projectiles do
   local data = projectile.data
   if now >= projectile.untilTime or not validRunner(projectile.target, data, true)
    or data.root ~= projectile.root or projectile.round ~= activeRound
    or data.gravitySign ~= projectile.sign or not projectile.model.Parent then
    removeProjectile(id)
   else
    local targetPosition = data.root.Position
    local previousPosition = projectile.position
    local offset = targetPosition - previousPosition
    if offset.Magnitude > 0.001 then
     projectile.position += offset.Unit * math.min(setting("PumpkinSpeed") * dt, offset.Magnitude)
    end
    pivot(projectile.model, frameAt(projectile.position, projectile.sign) * CFrame.Angles(0, 0, (now - projectile.startedAt) * 8))
    local radius = setting("PumpkinHitRadius")
    local relativeFrom = previousPosition - projectile.lastTargetPosition
    local relativeTo = projectile.position - targetPosition
    if segmentDistanceSquared(Vector3.zero, relativeFrom, relativeTo) <= radius * radius then
     context.Send(projectile.target, "PumpkinSplat", {
      duration = setting("PumpkinSplatSeconds"), sourceUserId = projectile.owner.UserId, roundKey = activeRound,
     })
     removeProjectile(id)
    else
     projectile.lastTargetPosition = targetPosition
    end
   end
  end
 end

 local function activateWeb(player, data, now)
  local count = 0
  for _, web in webs do
   count += 1
   if web.owner == player then return false, "Your previous web is still active." end
  end
  if count >= math.floor(setting("WebMaxActive")) then return false, "Too many webs are active. Try again shortly." end
  local hit = supportHit(data)
  if not hit then return false, "Place the web while touching a platform." end
  local frame = frameAt(hit.Position + hit.Normal * 0.12, data.gravitySign)
  local model = visibleClone(source("Trap_Web"), "PlayerWeb_" .. player.UserId, makeRuntime(), setting("WebRadius") * 2)
  if not model then return false, "The web artwork is not ready." end
  pivot(model, frame)
  model:SetAttribute("OwnerUserId", player.UserId)
  model:SetAttribute("ExpiresAt", now + setting("WebLifetime"))
  webs[allocateId()] = {
   model = model, owner = player, support = hit.Instance, localFrame = hit.Instance.CFrame:ToObjectSpace(frame),
   frame = frame, sign = data.gravitySign, radius = setting("WebRadius"), victims = {},
   untilTime = now + setting("WebLifetime"),
  }
  return true, "Web placed!", now + setting("WebCooldown")
 end

 local function activatePumpkin(player, data, now)
  local count = 0
  for _, projectile in projectiles do
   count += 1
   if projectile.owner == player then return false, "Your previous pumpkin is still flying." end
  end
  if count >= 12 then return false, "Too many pumpkins are flying. Try again shortly." end
  local target, targetData, nearest
  local range = setting("PumpkinRange")
  for other, otherData in context.Runners do
   if other ~= player and validRunner(other, otherData, true) and otherData.gravitySign == data.gravitySign
    and otherData.root.Position.X < data.root.Position.X - 0.1 then
    local distance = (otherData.root.Position - data.root.Position).Magnitude
    if distance <= range and (not nearest or distance < nearest
     or (distance == nearest and other.UserId < target.UserId)) then
     target, targetData, nearest = other, otherData, distance
    end
   end
  end
  if not target then return false, "No racer ahead is in pumpkin range." end
  local model = visibleClone(source("Throwable_Pumpkin"), "ThrownPumpkin_" .. player.UserId, makeRuntime(), 2.5, true)
  if not model then return false, "The pumpkin artwork is not ready." end
  local position = data.root.Position - Vector3.xAxis * 2
  pivot(model, frameAt(position, data.gravitySign))
  projectiles[allocateId()] = {
   owner = player, target = target, data = targetData, root = targetData.root, sign = targetData.gravitySign,
   round = activeRound, model = model, position = position, lastTargetPosition = targetData.root.Position,
   startedAt = now, untilTime = now + setting("PumpkinLifetime"),
  }
  return true, "Pumpkin thrown!", now + setting("PumpkinCooldown")
 end

 function self:Activate(player, action)
  if action ~= "Web" and action ~= "Pumpkin" then return false, "Unknown Halloween ability." end
  local now = context.Now()
  if now - (lastRequest[player] or -math.huge) < 0.15 then return false, "Please wait a moment." end
  lastRequest[player] = now
  if not enabled() or activeRound ~= context.RoundKey() then return false, "Halloween abilities are available in Halloween Course 1." end
  local data = context.Runners[player]
  if not validRunner(player, data, false) or holds[player] then return false, "You cannot use that ability right now." end
  local state = cooldowns[player] or {}
  cooldowns[player] = state
  if now < (state[action] or 0) then return false, "That ability is cooling down.", state[action] end
  local ok, message, untilTime
  if action == "Web" then ok, message, untilTime = activateWeb(player, data, now)
  else ok, message, untilTime = activatePumpkin(player, data, now) end
  if ok then
   state[action] = untilTime
   player:SetAttribute("GBloxHalloween" .. action .. "CooldownUntil", untilTime)
   if context.OnUsed then context.OnUsed(player) end
  end
  return ok, message, untilTime
 end

 function self:Remove(player)
  clearHold(player)
  clearFreeze(player)
  for id, web in webs do if web.owner == player then removeWeb(id) end end
  for id, projectile in projectiles do
   if projectile.owner == player or projectile.target == player then removeProjectile(id) end
  end
  for _, trap in traps do trap.dwell[player] = nil trap.immune[player] = nil end
  if player.Parent ~= Players then cooldowns[player] = nil lastRequest[player] = nil end
 end

 function self:Clear()
  local hadActiveRound = activeRound
  activeRound = nil
  activeCourse = nil
  activeSince = nil
  clock = 0
  for player in holds do clearHold(player) end
  for player in frozen do clearFreeze(player) end
  for player in cooldowns do
   player:SetAttribute("GBloxHalloweenWebCooldownUntil", nil)
   player:SetAttribute("GBloxHalloweenPumpkinCooldownUntil", nil)
  end
  cooldowns = {}
  lastRequest = {}
  holds = {}
  frozen = {}
  webs = {}
  projectiles = {}
  traps = {}
  ghost = nil
  destroy(runtime)
  runtime = nil
  if hadActiveRound then context.Broadcast("HalloweenClear", {roundKey = hadActiveRound}) end
 end

 function self:Step(dt)
  if not validNumber(dt) or dt <= 0 then return end
  local round = context.RoundKey()
  if previousRound ~= round then
   self:Clear()
   previousRound = round
   spentRound = nil
  end
  if not enabled() then
   if activeRound then self:Clear() end
   return
  end
  if activeRound ~= round or activeCourse ~= context.Course() then
   self:Clear()
   begin()
  end
  clock += math.min(dt, 0.5)
  if clock < setting("PollInterval") then return end
  local elapsed = math.min(clock, 0.25)
  clock = 0
  local now = context.Now()
  for player, entry in frozen do
   if now >= entry.untilTime or entry.round ~= activeRound or not validRunner(player, entry.data, true)
    or entry.root ~= entry.data.root then clearFreeze(player) end
  end
  stepHolds(now)
  if not activeRound or not enabled() or activeRound ~= context.RoundKey() then return end
  stepTraps(now)
  stepWebs(now)
  stepProjectiles(now, elapsed)
  stepGhost(now, elapsed)
 end

 return self
end

Service.Defaults = defaults
return Service


end)()

local checks=0
local function expect(condition,message)
 assert(condition,message)
 checks+=1
end
local theme=Instance.new("Folder")
theme.Name="GBloxCourseTheme"
theme:SetAttribute("ActiveTheme","Halloween")
theme.Parent=ReplicatedStorage
local templates=Instance.new("Folder")
for _,name in {"Ghost","Trap_Web","Throwable_Pumpkin","Zombie_Hand"} do
 local model=Instance.new("Model") model.Name=name
 local part=Instance.new("Part") part.Name=name=="Zombie_Hand" and "Halloween_Palm" or "Artwork" part.Parent=model
 model.Parent=templates
end
local settings=Instance.new("Folder")
for name,value in Subject.Defaults do settings:SetAttribute(name,value) end
local course=Instance.new("Model") course.Name="Course1" course.Parent=Workspace
local support=Instance.new("Part") support.Name="Flat_Platform_RunSurface" support.Size=Vector3.new(200,2,20) support.Parent=course
currentSupport=support
local gameplay=Instance.new("Folder") gameplay.Name="HalloweenGameplay" gameplay.Parent=course
local trapFolder=Instance.new("Folder") trapFolder.Name="Traps" trapFolder.Parent=gameplay
local grave=Instance.new("Model") grave.Name="Grave" grave:SetAttribute("TrapType","Grave") grave:SetAttribute("SurfaceNormalY",1)
local sensor=Instance.new("Part") sensor.Name="Sensor" sensor.Size=Vector3.new(7,6,7) sensor.CFrame=CFrame.new(50,3,0) sensor.Parent=grave
local reference=Instance.new("ObjectValue") reference.Name="Support" reference.Value=support reference.Parent=grave
grave.Parent=trapFolder

local runners={}
local function player(id,x,z)
 local p=Instance.new("Player") p.UserId=id p.Parent=Players
 local character=Instance.new("Model") character.Parent=Workspace p.Character=character
 local root=Instance.new("Part") root.Size=Vector3.new(2,6,1.5) root.CFrame=CFrame.new(x,3,z or 0) root.AssemblyLinearVelocity=Vector3.zero root.Anchored=false root.Parent=character
 local data={player=p,character=character,root=root,collider=root,humanoid={Health=100},status="Running",gravitySign=1,courseVersion=1}
 runners[p]=data
 return p,data
end
local owner,ownerData=player(1,0)
local victimA,aData=player(2,2,1)
local victimB,bData=player(3,2,-1)
local now,round,courseNumber,phase=0,1,1,"Running"
local frozen,eliminated,packets={},{},{}
local service
service=Subject.new({
 Runners=runners,Settings=settings,Templates=templates,
 Now=function() return now end,RoundKey=function() return round end,CourseNumber=function() return courseNumber end,
 Phase=function() return phase end,Course=function() return course end,
 Progress=function(data) return -data.root.Position.X/100 end,
 Freeze=function(p,seconds)
  frozen[p]=now+seconds runners[p].freezeUntil=now+seconds runners[p].root.Anchored=true
  return now+seconds
 end,
 ClearFreeze=function(p)
  frozen[p]=nil
  local data=runners[p]
  if data then data.freezeUntil=nil data.root.Anchored=false end
 end,
 Eliminate=function(p,reason)
  table.insert(eliminated,{player=p,reason=reason}) runners[p].status="Out" service:Remove(p)
 end,
 Send=function(p,action,payload) table.insert(packets,{player=p,action=action,payload=payload}) end,
 Broadcast=function(action,payload) table.insert(packets,{action=action,payload=payload}) end,
 IsPlatform=function(part) return part==support end,
})
local function step(seconds)
 local remaining=seconds
 while remaining>0.0001 do local dt=math.min(0.1,remaining) now+=dt service:Step(dt) remaining-=dt end
end
service:Step(.1)
local ok,_,untilTime=service:Activate(owner,"Web")
expect(ok and untilTime==30,"Web activates with 30-second cooldown")
step(.1)
expect(not frozen[owner],"Web owner is immune")
expect(frozen[victimA] and frozen[victimB],"A web freezes multiple other racers")
expect(math.abs(frozen[victimA]-(now+5))<.001,"Web freeze is five seconds")
expect(owner:GetAttribute("GBloxHalloweenWebCooldownUntil")==30,"Cooldown attribute uses server clock")
step(5.1)
expect(not frozen[victimA] and not frozen[victimB],"Web victims are released")
step(.2)
expect(not frozen[victimA],"Same web cannot retrap its victim")
service:Remove(owner)
step(.2)
ok,_,untilTime=service:Activate(owner,"Web")
expect(not ok and untilTime==30,"Recovery/Remove cannot bypass cooldown")
service:Clear()
expect(not owner:GetAttribute("GBloxHalloweenWebCooldownUntil"),"Clear removes seasonal cooldowns")
theme:SetAttribute("ActiveTheme","Normal")
service:Step(.1)
ok=service:Activate(owner,"Web")
expect(not ok,"Normal theme gates abilities")
theme:SetAttribute("ActiveTheme","Halloween") courseNumber=2
service:Step(.1)
ok=service:Activate(owner,"Web")
expect(not ok,"Course two gates abilities")

courseNumber=1 round+=1
for _,data in runners do data.courseVersion=round data.status="Running" data.root.Anchored=false end
aData.root.CFrame=CFrame.new(50,3,0)
aData.root.AssemblyLinearVelocity=Vector3.new(-20,0,0)
service:Step(.1)
step(1.2)
expect(not aData.freezeUntil,"Passing through a grave does not capture")
aData.root.AssemblyLinearVelocity=Vector3.zero
step(1.2)
expect(aData.freezeUntil and victimA:GetAttribute("GBloxHalloweenGraveUntil"),"One stationary second starts grave capture")
local graveEnds=victimA:GetAttribute("GBloxHalloweenGraveUntil")
step(4.5)
expect(aData.status=="Running","Grave holds for five seconds before elimination")
step(math.max(0,graveEnds-now)+.2)
expect(aData.status=="Out" and #eliminated==1,"Grave eliminates directly at end of hold")
expect(not frozen[victimA] and not victimA:GetAttribute("GBloxHalloweenGraveUntil"),"Terminal grave cleanup releases seasonal hold")

service:Clear() round+=1
settings:SetAttribute("GhostInitialDelay",2)
settings:SetAttribute("GhostBaseSpeed",24)
settings:SetAttribute("GhostSpawnBehind",22)
ownerData.courseVersion=round ownerData.root.CFrame=CFrame.new(10,3,0) ownerData.status="Running"
bData.courseVersion=round bData.root.CFrame=CFrame.new(0,3,0) bData.status="Running"
aData.status="Out"
service:Step(.1)
step(2.3)
local runtime=Workspace:FindFirstChild("GBloxHalloweenRuntime")
local ghost=runtime and runtime:FindFirstChild("LastPlaceGhost")
expect(ghost and ghost:GetAttribute("TargetUserId")==owner.UserId,"Ghost chooses last-progress racer")
ownerData.root.CFrame=CFrame.new(-20,3,0)
step(.1)
ghost=runtime:FindFirstChild("LastPlaceGhost")
expect(ghost and ghost:GetAttribute("TargetUserId")==victimB.UserId,"Ghost switches target after overtaking")
step(2)
expect(#eliminated==2 and bData.status=="Out","Ghost catches exactly one racer")
step(3)
expect(#eliminated==2 and ownerData.status=="Running","Ghost stops eating after its first victim")
theme:SetAttribute("ActiveTheme","Normal") service:Step(.1)
theme:SetAttribute("ActiveTheme","Halloween") service:Step(.1)
step(5)
expect(#eliminated==2,"Theme toggling cannot grant another ghost elimination in same course version")

service:Clear() round+=1
settings:SetAttribute("GhostInitialDelay",30)
ownerData.courseVersion=round ownerData.status="Running" ownerData.root.CFrame=CFrame.new(10,3,0)
bData.courseVersion=round bData.status="Running" bData.root.CFrame=CFrame.new(0,3,0)
service:Step(.1)
ok,_,untilTime=service:Activate(owner,"Pumpkin")
expect(ok and math.abs(untilTime-(now+10))<.001,"Pumpkin has configurable provisional 10-second cooldown")
step(.3)
local splat
for _,packet in packets do if packet.action=="PumpkinSplat" then splat=packet end end
expect(splat and splat.player==victimB and splat.payload.duration==3 and splat.payload.roundKey==round,"Pumpkin hits ahead target with versioned three-second splat")
expect(not bData.freezeUntil and not bData.root.Anchored,"Pumpkin obscures view without immobilizing")

service:Clear()
expect(not Workspace:FindFirstChild("GBloxHalloweenRuntime"),"Clear destroys runtime visuals")
expect(not owner:GetAttribute("GBloxHalloweenPumpkinCooldownUntil"),"Clear removes pumpkin cooldown attribute")

round+=1
ownerData.courseVersion=round ownerData.status="Running" ownerData.gravitySign=-1 ownerData.root.CFrame=CFrame.new(10,-3,0)
bData.courseVersion=round bData.status="Running" bData.gravitySign=-1 bData.root.CFrame=CFrame.new(12,-3,0)
service:Step(.1)
ok=service:Activate(owner,"Web")
expect(ok,"Upside-down runner can place a web on ceiling support")
step(.2)
expect(frozen[victimB] and not frozen[owner],"Ceiling web traps another inverted runner but not owner")
service:Remove(victimB)
expect(not frozen[victimB] and not victimB:GetAttribute("GBloxHalloweenTrappedUntil"),"Recovery/Remove cancels an active seasonal freeze")
service:Clear()

round+=1
settings:SetAttribute("GhostInitialDelay",2) settings:SetAttribute("GhostSpawnBehind",50)
ownerData.courseVersion=round ownerData.gravitySign=1 ownerData.root.CFrame=CFrame.new(10,3,0)
bData.courseVersion=round bData.gravitySign=1 bData.root.CFrame=CFrame.new(-100,3,0)
service:Step(.1)
step(2.3)
runtime=Workspace:FindFirstChild("GBloxHalloweenRuntime") ghost=runtime:FindFirstChild("LastPlaceGhost")
expect(ghost and ghost:GetAttribute("Speed")==24,"Ghost starts at configurable base speed")
step(1.1)
ghost=runtime:FindFirstChild("LastPlaceGhost")
expect(ghost and math.abs(ghost:GetAttribute("Speed")-25.1)<.001,"Ghost increases 1.1 studs per second after each 1.1-second interval")
service:Clear()
print("HalloweenService isolated behavior checks passed: "..checks)


