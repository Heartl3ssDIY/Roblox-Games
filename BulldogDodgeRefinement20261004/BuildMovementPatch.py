from pathlib import Path

root = Path(__file__).resolve().parent
service_path = root / 'BritishBulldogService.lua'
service = service_path.read_text(encoding='utf-8')

def replace_once(source, before, after):
    assert source.count(before) == 1, f'Expected one patch anchor: {before[:100]}'
    return source.replace(before, after, 1)

start = service.index('function Service:_startDodgeBurst(')
end = service.index('function Service:_updateMovement(', start)
service = service[:start] + '''local function dodgeSpeed(distance, duration, elapsed)
	local alpha = math.clamp(elapsed / duration, 0, 1)
	local attack = 0.16
	local envelope = alpha < attack and (0.5 + 0.5 * math.sin(alpha / attack * math.pi / 2))
		or math.cos((alpha - attack) / (1 - attack) * math.pi / 2)
	local area = attack * (0.5 + 1 / math.pi) + (1 - attack) * 2 / math.pi
	return distance / duration * envelope / area
end

function Service:_startDodgeBurst(record, direction, now, duration, distance, forwardVelocity, params)
	self:_stopDodgeBurst(record)
	local root = record.root
	local attachment = Instance.new("Attachment")
	attachment.Name = "BBDodgeAttachment"
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "BBDodgeVelocity"
	velocity.Attachment0 = attachment
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.PrimaryTangentAxis = Vector3.xAxis
	velocity.SecondaryTangentAxis = Vector3.zAxis
	velocity.ForceLimitsEnabled = true
	velocity.ForceLimitMode = Enum.ForceLimitMode.Magnitude
	velocity.MaxForce = math.max(root.AssemblyMass, 1) * 3000
	local initial = direction * dodgeSpeed(distance, duration, 0) + forwardVelocity
	velocity.PlaneVelocity = Vector2.new(initial.X, initial.Z)
	velocity.Parent = root
	local burst = { root = root, attachment = attachment, velocity = velocity, direction = direction,
		token = self.currentRound, crossing = self.crossingNumber, endsAt = now + duration }
	record.dodgeBurst = burst
	pcall(function() root:SetNetworkOwner(nil) end)
	root.AssemblyLinearVelocity = initial + Vector3.new(0, math.min(root.AssemblyLinearVelocity.Y, 0), 0)
	setAttribute(record.player, "BBDodgeDirection", direction)
	setAttribute(record.player, "BBDodgeDuration", duration)
	setAttribute(record.player, "BBDodgeStartedAt", now)
	burst.connection = RunService.PreSimulation:Connect(function(dt)
		local time = workspace:GetServerTimeNow()
		if self.records[record.player] ~= record or record.root ~= root or not root.Parent or not self.active
			or self.currentRound ~= burst.token or self.crossingNumber ~= burst.crossing or self.phase ~= "Crossing"
			or record.frozen or record.role ~= "Runner" or record.arrived or not alive(record) or time >= burst.endsAt then
			self:_stopDodgeBurst(record, burst)
			return
		end
		local desired = direction * dodgeSpeed(distance, duration, time - now) + forwardVelocity
		local step = desired * math.clamp(dt, 0, 0.05)
		if step.Magnitude > 0 and workspace:Raycast(root.Position, step + step.Unit * 1.4, params) then
			self:_stopDodgeBurst(record, burst)
			return
		end
		velocity.PlaneVelocity = Vector2.new(desired.X, desired.Z)
	end)
end

''' + service[end:]
service = replace_once(service, 'local params = self:_movementRayParameters()\n\tif not self:_dodgeClear(record, direction, 8, params) then', '''local params = self:_movementRayParameters()
	local duration = math.clamp(self:_setting("DodgeDurationSeconds", 0.32, 0.2), 0.2, 0.5)
	local distance = math.clamp(self:_setting("DodgeDistance", 8, 3), 3, 10)
	local look = self.bounds.CFrame.LookVector
	local forward = Vector3.new(look.X, 0, look.Z).Unit
	local forwardSpeed = math.clamp(record.root.AssemblyLinearVelocity:Dot(forward), -record.humanoid.WalkSpeed, record.humanoid.WalkSpeed)
	local forwardVelocity = forward * forwardSpeed
	local travel = direction * distance + forwardVelocity * duration
	if not self:_dodgeClear(record, travel.Unit, travel.Magnitude, params) then''')
service = replace_once(service, 'record.pendingEscape = { checkAt = now + 0.25,', 'record.pendingEscape = { checkAt = now + duration,')
service = replace_once(service, 'self:_startDodgeBurst(record, direction, now)', 'self:_startDodgeBurst(record, direction, now, duration, distance, forwardVelocity, params)')
service = replace_once(service, 'self:_publishMovement(record)\n\treturn { ok = true }\nend\n\nfunction Service:_restoreJump', 'self:_publishMovement(record)\n\treturn { ok = true, startedAt = now, direction = direction, duration = duration }\nend\n\nfunction Service:_restoreJump')
service = replace_once(service, 'self:_stopDodgeBurst(record)\n\trecord.boostEndsAt = 0', 'self:_stopDodgeBurst(record)\n\tsetAttribute(record.player, "BBDodgeStartedAt", 0)\n\trecord.boostEndsAt = 0')
service_path.write_text(service,encoding='utf-8')

source = root.parent / 'PlaygroundUIImplementation20261004' / 'Before' / 'StarterGui_BritishBulldogHUD_MovementController.luau'
client = source.read_text(encoding='utf-8')
client = replace_once(client, 'local animation=nil', 'local animation=nil\nlocal jumpHumanoid=nil\nlocal jumpWasEnabled=nil\nlocal jumpBound=false\nlocal jumpActionName="BritishBulldogNoJump"')
anchor = 'local function canSprint()'
lock = '''local function releaseJumpLock()
 if jumpHumanoid and jumpHumanoid.Parent and jumpWasEnabled~=nil then
  jumpHumanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping,jumpWasEnabled)
 end
 jumpHumanoid=nil
 jumpWasEnabled=nil
 if jumpBound then ContextActionService:UnbindAction(jumpActionName) jumpBound=false end
end

local function syncJumpLock()
 local character=player.Character
 local humanoid=character and character:FindFirstChildOfClass("Humanoid")
 if not alive or player:GetAttribute("BBParticipating")~=true or not humanoid then releaseJumpLock() return end
 if jumpHumanoid~=humanoid then
  releaseJumpLock()
  jumpHumanoid=humanoid
  jumpWasEnabled=humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping)
 end
 humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping,false)
 humanoid.Jump=false
 if not jumpBound then
  ContextActionService:BindActionAtPriority(jumpActionName,function()
   if alive and player:GetAttribute("BBParticipating")==true then return Enum.ContextActionResult.Sink end
   return Enum.ContextActionResult.Pass
  end,false,3000,Enum.PlayerActions.CharacterJump)
  jumpBound=true
 end
end

'''
client = replace_once(client, anchor, lock+anchor)
client = replace_once(client, 'local function beginPose(direction)', 'local function beginPose(direction,startedAt,duration)')
client = replace_once(client, 'local motors={}\n for _,descendant', 'local motors={}\n local hasWaist=character:FindFirstChild("Waist",true)~=nil\n for _,descendant')
client = replace_once(client, 'if descendant.Name=="RootJoint" or descendant.Name=="Root" or descendant.Name=="Waist" then motors[descendant]="Body"', 'if descendant.Name=="RootJoint" or descendant.Name=="Root" then motors[descendant]=hasWaist and "Root" or "Body"\n   elseif descendant.Name=="Waist" then motors[descendant]="Waist"')
client = replace_once(client, 'animation={started=os.clock(),direction=direction,motors=motors,bases={}}', '''local root=character:FindFirstChild("HumanoidRootPart")
 local world=typeof(direction)=="Vector3" and direction or arenaRight()*direction
 local localDirection=root and root.CFrame:VectorToObjectSpace(world) or Vector3.xAxis
 animation={started=startedAt or workspace:GetServerTimeNow(),duration=(duration or 0.32)+0.14,
  direction=localDirection.X,motors=motors,bases={},character=character}''')
client = replace_once(client, 'if alive and success and typeof(response)=="table" and response.ok then beginPose(lastDodgeDirection) end', '''if alive and success and typeof(response)=="table" and response.ok and canSprint()
   and player:GetAttribute("BBStatus")=="Crossing" then
   beginPose(response.direction or lastDodgeDirection,response.startedAt,response.duration)
  end''')
client = replace_once(client, 'local function refresh()\n syncBinding()', 'local function refresh()\n syncJumpLock()\n syncBinding()')
client = replace_once(client, 'connect(player.CharacterRemoving,function() releaseHold() restorePose() animation=nil end)', 'connect(player.CharacterRemoving,function() releaseHold() releaseJumpLock() restorePose() animation=nil end)')
client = replace_once(client, 'connect(player.CharacterAdded,function() releaseHold() restorePose() animation=nil end)', 'connect(player.CharacterAdded,function() releaseHold() releaseJumpLock() restorePose() animation=nil syncJumpLock() end)\nconnect(player:GetAttributeChangedSignal("BBParticipating"),syncJumpLock)\nconnect(UserInputService.JumpRequest,function() if jumpHumanoid then jumpHumanoid.Jump=false end end)')
start = client.index('connect(RunService.PreSimulation,function()')
end = client.index('local elapsed=0',start)
client = client[:start] + '''connect(RunService.PreSimulation,function()
 if jumpHumanoid then jumpHumanoid.Jump=false end
 if not animation then return end
 local elapsed=workspace:GetServerTimeNow()-animation.started
 if elapsed>=animation.duration or not canSprint() or player:GetAttribute("BBStatus")~="Crossing"
  or player:GetAttribute("BBRole")~="Runner" or player.Character~=animation.character then
  restorePose() animation=nil return
 end
 local alpha=math.clamp(elapsed/animation.duration,0,1)
 local strength=alpha<0.22 and math.sin(alpha/0.22*math.pi/2)
  or math.cos((alpha-0.22)/0.78*math.pi/2)^2
 for motor,kind in pairs(animation.motors) do
  if motor.Parent then
   local base=motor.Transform
   animation.bases[motor]=base
   local direction=animation.direction
   local weight=kind=="Root" and 0.65 or kind=="Waist" and 0.35 or 1
   local body=kind=="Body" or kind=="Root" or kind=="Waist"
   local pose=body and CFrame.new(0,-0.16*strength*weight,0)
     *CFrame.Angles(math.rad(-9)*strength*weight,math.rad(8)*strength*direction*weight,math.rad(-26)*strength*direction*weight)
    or CFrame.Angles(math.rad(-12)*strength,0,math.rad(kind=="Right" and 18 or -18)*strength)
   if body then
    local jointRotation=motor.C0.Rotation
    pose=jointRotation:Inverse()*pose*jointRotation
   end
   motor.Transform=base*pose
  end
 end
end)
''' + client[end:]
client = replace_once(client,' alive=false\n releaseHold()', ' alive=false\n releaseHold()\n releaseJumpLock()')
(root/'BBMovement.client.luau').write_text(client,encoding='utf-8')
print('Prepared server jump lock, grounded eased sidestep, client jump input block and dodge lean.')
