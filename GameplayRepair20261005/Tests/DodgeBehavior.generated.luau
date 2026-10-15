local checks=0
local function check(value,message) assert(value,message) checks+=1 end
local vmeta={}
local Vector3={}
function Vector3.new(x,y,z)return setmetatable({X=x,Y=y,Z=z},vmeta)end
Vector3.zero=Vector3.new(0,0,0) Vector3.xAxis=Vector3.new(1,0,0) Vector3.zAxis=Vector3.new(0,0,1)
vmeta.__add=function(a,b)return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
vmeta.__sub=function(a,b)return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
vmeta.__mul=function(a,b)if type(a)=="number"then a,b=b,a end return Vector3.new(a.X*b,a.Y*b,a.Z*b)end
vmeta.__div=function(a,b)return a*(1/b)end
vmeta.__index=function(a,k)
 if k=="Magnitude"then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z)end
 if k=="Unit"then return a/a.Magnitude end
 if k=="Dot"then return function(a,b)return a.X*b.X+a.Y*b.Y+a.Z*b.Z end end
end
local CFrame={}
function CFrame.new(position)
 return {Position=position or Vector3.zero,PointToObjectSpace=function(self,p)return p-self.Position end,VectorToObjectSpace=function(_,p)return p end}
end
local Vector2={new=function(x,y)return {X=x,Y=y}end}
local Enum={VelocityConstraintMode={Plane=1},ActuatorRelativeTo={World=1},ForceLimitMode={Magnitude=1}}
local clock=100
local Players={}
local wallX=nil
local blockedGround=false
local workspace={GetServerTimeNow=function()return clock end}
local OverlapParams={new=function()return {}end}
function workspace:GetPartBoundsInBox(frame,shape)
 if wallX and math.abs(wallX-frame.Position.X)<shape.X*.5 then return {"wall"}end
 return {}
end
function workspace:Raycast(position,direction)
 if blockedGround or direction.Y>=0 or position.Y>math.abs(direction.Y)then return nil end
 return {Distance=position.Y,Normal=Vector3.new(0,1,0),Position=Vector3.new(position.X,0,position.Z)}
end
function workspace:Blockcast(frame,shape,direction)
 if wallX and direction.X>0 then
  local fraction=(wallX-frame.Position.X-shape.X*.5)/direction.X
  if fraction>=0 and fraction<=1 then return {Distance=direction.Magnitude*fraction}end
 end
 return nil
end
local callback
local RunService={PreSimulation={Connect=function(_,fn)callback=fn return {Disconnect=function()callback=nil end}end}}
local Instance={new=function(class)return {ClassName=class,Destroy=function(self)self.Parent=nil self.destroyed=true end}end}
local function alive(record)return record.humanoid.Health>0 and record.root.Parent~=nil end
local function setAttribute(player,key,value)player.attrs[key]=value end
local Service={}
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

function Service:_stopDodgeBurst(record, expected)
	local burst = expected or record.dodgeBurst
	if not burst then return end
	if burst.connection then burst.connection:Disconnect() burst.connection = nil end
	if burst.velocity then burst.velocity:Destroy() burst.velocity = nil end
	if burst.attachment then burst.attachment:Destroy() burst.attachment = nil end
	if record.dodgeBurst ~= burst then return end
	record.dodgeBurst = nil
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

function Service:_startDodgeBurst(record, direction, now, duration, distance, forwardVelocity, params)
	self:_stopDodgeBurst(record)
	local root = record.root
	if root.Anchored then return false end
	local owner, ownershipAuto
	local ownershipOK = pcall(function()
		owner, ownershipAuto = root:GetNetworkOwner(), root:GetNetworkOwnershipAuto()
		root:SetNetworkOwner(nil)
	end)
	if not ownershipOK then return false end
	local attachment = Instance.new("Attachment")
	attachment.Name, attachment.Parent = "BBDodgeAttachment", root
	local velocity = Instance.new("LinearVelocity")
	velocity.Name, velocity.Attachment0 = "BBDodgeVelocity", attachment
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
	record.dodgeBurst = burst
	record.humanoid.AutoRotate = false
	root.AssemblyLinearVelocity = initial + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
	setAttribute(record.player, "BBDodgeDirection", direction)
	setAttribute(record.player, "BBDodgeDuration", duration)
	setAttribute(record.player, "BBDodgeStartedAt", now)
	burst.connection = RunService.PreSimulation:Connect(function(dt)
		local time = workspace:GetServerTimeNow()
		if self.records[record.player] ~= record or record.root ~= root or not root.Parent or not self.active
			or self.currentRound ~= burst.token or self.crossingNumber ~= burst.crossing or self.phase ~= "Crossing"
			or not record.participating or record.frozen or record.ragdoll or not alive(record) or time >= self.endsAt
			or record.role ~= "Runner" or record.arrived or time >= burst.endsAt then self:_stopDodgeBurst(record, burst) return end
		local desired = direction * dodgeSpeed(distance, duration, time - now) + forwardVelocity
		local step = desired * math.clamp(dt, 0, 0.05)
		local hit = step.Magnitude > 0 and workspace:Blockcast(CFrame.new(root.Position), Vector3.new(2.4, 3.6, 2.4), step, params)
		if hit or not self:_inside(self.bounds, root.Position) then self:_stopDodgeBurst(record, burst) return end
		velocity.PlaneVelocity = Vector2.new(desired.X, desired.Z)
	end)
	return true
end


local function fresh(owner,auto)
 clock=100 wallX=nil blockedGround=false callback=nil
 local player={Parent=Players,attrs={}}
 local humanoid={Parent=true,Health=100,HipHeight=2,AutoRotate=true}
 local root={Parent=workspace,Position=Vector3.new(0,3,0),Size=Vector3.new(2,2,1),AssemblyLinearVelocity=Vector3.zero,AssemblyMass=10,Anchored=false,owner=owner,auto=auto,ownershipCalls={}}
 function root:GetNetworkOwner()return self.owner end
 function root:GetNetworkOwnershipAuto()return self.auto end
 function root:SetNetworkOwner(who)table.insert(self.ownershipCalls,who and "player"or"server") self.owner=who self.auto=false end
 function root:SetNetworkOwnershipAuto()self.auto=true table.insert(self.ownershipCalls,"auto")end
 local record={player=player,humanoid=humanoid,root=root,character={FindFirstChild=function()return nil end},participating=true,role="Runner",frozen=false}
 local service=setmetatable({records={[player]=record},bounds={CFrame=CFrame.new(),Size=Vector3.new(40,20,40)},active=true,currentRound={},crossingNumber=1,phase="Crossing",endsAt=200,northZ=-20,southZ=20},{__index=Service})
 function service:_inside(_,p)return math.abs(p.X)<20 and math.abs(p.Z)<20 end
 return service,record,root,player
end
do
 local s,r,root=fresh(nil,true)
 check(s:_dodgeGrounded(r,{}),"Ground ray accepts standing runner independent of FloorMaterial replication")
 blockedGround=true check(not s:_dodgeGrounded(r,{}),"Ground ray rejects absent ground") blockedGround=false
 root.AssemblyLinearVelocity=Vector3.new(0,15,0)check(not s:_dodgeGrounded(r,{}),"Rising jump cannot dodge")root.AssemblyLinearVelocity=Vector3.zero
 check(s:_clipDodgeTravel(r,Vector3.new(8,0,0),{})==1,"Open lateral path keeps full distance")
 wallX=4 local fraction=s:_clipDodgeTravel(r,Vector3.new(8,0,0),{})
 check(math.abs(fraction*8-2.62)<.00001,"Close wall clips rather than rejects entire dodge")
 wallX=nil root.Position=Vector3.new(16,3,0)
 check(math.abs(s:_clipDodgeTravel(r,Vector3.new(8,0,0),{})*8-2.5)<.00001,"Arena edge clips body margin")
 root.Position=Vector3.new(0,3,0)wallX=5
 local diagonal=Vector3.new(8,0,4)
 fraction=s:_clipDodgeTravel(r,diagonal,{})
 check(fraction>0 and fraction<1,"Diagonal forward momentum is swept with lateral dash")
 check(diagonal.X*fraction<3.8,"Diagonal sweep retains wall clearance")
 wallX=.8 check(s:_clipDodgeTravel(r,Vector3.new(8,0,0),{})==0,"Initially overlapping wall cannot bypass the swept collision check")
end
for _,mode in ipairs({"auto","player","server"})do
 local original=mode=="player"and {Parent=Players}or nil
 local s,r,root,player=fresh(original,mode=="auto")
 check(s:_startDodgeBurst(r,Vector3.xAxis,clock,.32,8,Vector3.new(0,0,-6),{}),mode.." dash accepted")
 check(root.owner==nil and root.auto==false,mode.." server owns authoritative burst")
 check(r.dodgeBurst.velocity.MaxForce==30000 and r.dodgeBurst.velocity.VelocityConstraintMode==1,mode.." horizontal physics actuator configured")
 check(not r.humanoid.AutoRotate,mode.." dash keeps facing stable")
 local elapsed=0
 while r.dodgeBurst and elapsed<.5 do
  local dt=1/240 elapsed+=dt clock=100+elapsed
  local fn=callback if fn then fn(dt)end
  if r.dodgeBurst then local v=r.dodgeBurst.velocity.PlaneVelocity root.AssemblyLinearVelocity=Vector3.new(v.X,0,v.Y) root.Position+=root.AssemblyLinearVelocity*dt end
 end
 check(root.Position.X>7.7 and root.Position.X<8.1,mode.." integrated actuator advances approximately eight studs")
 check(root.Position.Z<-1.8 and root.Position.Z>-2.1,mode.." forward momentum retained")
 check(r.dodgeBurst==nil and callback==nil,mode.." burst cleans on duration")
 check(r.humanoid.AutoRotate,mode.." facing restored")
 check(mode=="auto"and root.auto or mode~="auto"and root.owner==original and not root.auto,mode.." original ownership mode restored")
 check(player.attrs.BBDodgeStartedAt==100 and player.attrs.BBDodgeDuration==.32,mode.." clients receive authoritative pose timing")
end
do
 local s,r,root=fresh(nil,true)
 s:_startDodgeBurst(r,Vector3.xAxis,clock,.32,8,Vector3.zero,{})
 root.Position=Vector3.new(2.6,3,0)wallX=4 clock=100.10 callback(.016)
 check(r.dodgeBurst==nil,"New obstruction stops running burst")
 check(root.AssemblyLinearVelocity.X==0,"Wall stop removes residual velocity into obstacle")
end
for _,reason in ipairs({"frozen","ragdoll","phase","round","death","arrived","role","departed"})do
 local s,r,root=fresh(nil,true) s:_startDodgeBurst(r,Vector3.xAxis,clock,.32,8,Vector3.zero,{})
 if reason=="phase"then s.phase="Results"elseif reason=="round"then s.currentRound={}elseif reason=="death"then r.humanoid.Health=0 elseif reason=="role"then r.role="Bulldog" elseif reason=="departed"then r.participating=false else r[reason]=true end
 clock=100.1 callback(.016)
 check(r.dodgeBurst==nil,reason.." cancels immediately")
 if reason=="frozen"or reason=="ragdoll"then check(root.owner==nil and not root.auto,reason.." retains server ownership for immobilizer")end
end
do
 local s,r,root=fresh(nil,true)root.Anchored=true
 check(not s:_startDodgeBurst(r,Vector3.xAxis,clock,.32,8,Vector3.zero,{})and r.dodgeBurst==nil,"Anchored rig cannot consume a fake dash")
 root.Anchored=false root.SetNetworkOwner=function()error("unavailable")end
 check(not s:_startDodgeBurst(r,Vector3.xAxis,clock,.32,8,Vector3.zero,{})and r.dodgeBurst==nil,"Ownership failure rejects rather than accepting timer-only dash")
end
print("Dodge behavior checks passed: "..checks)
