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
local function typeof(value) return getmetatable(value)==vmeta and "Vector3" or type(value)end
local attributes={}
local root={Position=Vector3.zero,CFrame={RightVector=Vector3.xAxis},AssemblyLinearVelocity=Vector3.zero}
local humanoid={MoveDirection=Vector3.zero,WalkSpeed=20}
local character={FindFirstChild=function()return root end,FindFirstChildOfClass=function()return humanoid end}
local others={}
local Players={GetPlayers=function()return others end}
local player={Character=character,Parent=Players,attrs=attributes}
local workspace={CurrentCamera={CFrame={RightVector=Vector3.xAxis}},GetServerTimeNow=function()return 100 end}
local function dodgeDirection()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local camera = workspace.CurrentCamera
	local axis = camera and camera.CFrame.RightVector or Vector3.xAxis
	local right = Vector3.new(axis.X, 0, axis.Z)
	if right.Magnitude < 0.01 then right = Vector3.xAxis else right = right.Unit end
	if not root then return right end
	local lateral = humanoid and humanoid.MoveDirection:Dot(right) or 0
	if math.abs(lateral)>0.12 then return right * (lateral<0 and -1 or 1) end
	local nearest, distance
	for _, other in ipairs(Players:GetPlayers()) do
		local candidate=other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		if other~=player and candidate and other:GetAttribute("TGParticipating")==true and other:GetAttribute("TGRole")=="Tagger" then
			local delta=candidate.Position-root.Position
			if not distance or delta.Magnitude<distance then nearest,distance=candidate,delta.Magnitude end
		end
	end
	if nearest then local away=(root.Position-nearest.Position):Dot(right) if math.abs(away)>.1 then return right * (away<0 and -1 or 1) end end
	return right
end


local function same(a,b)return (a-b).Magnitude<.00001 end
for _,facing in ipairs({Vector3.xAxis,Vector3.zAxis,Vector3.xAxis*-1})do
 root.CFrame.RightVector=facing
 for _,cameraRight in ipairs({Vector3.xAxis,Vector3.zAxis,Vector3.new(1,.5,1).Unit})do
  workspace.CurrentCamera.CFrame.RightVector=cameraRight
  local horizontal=Vector3.new(cameraRight.X,0,cameraRight.Z).Unit
  humanoid.MoveDirection=horizontal*-1 check(same(dodgeDirection(),horizontal*-1),"Left input preserved at independent avatar/camera rotations")
  humanoid.MoveDirection=horizontal check(same(dodgeDirection(),horizontal),"Right input preserved at independent avatar/camera rotations")
  humanoid.MoveDirection=(horizontal+Vector3.new(-horizontal.Z,0,horizontal.X)).Unit
  check(same(dodgeDirection(),horizontal),"Diagonal input keeps camera-relative side")
 end
end
workspace.CurrentCamera.CFrame.RightVector=Vector3.xAxis humanoid.MoveDirection=Vector3.zero
check(same(dodgeDirection(),Vector3.xAxis),"No input or threat defaults right")
others={{Character={FindFirstChild=function()return {Position=Vector3.new(2,0,0)}end},GetAttribute=function(_,key)return key=="TGRole"and "Tagger"or true end}}
check(same(dodgeDirection(),Vector3.xAxis*-1),"No input dodges away from nearby tagger")
others={} workspace.CurrentCamera=nil check(same(dodgeDirection(),Vector3.xAxis),"Missing camera safe horizontal fallback")
local Service={}
local function alive(record)return record.humanoid.Health~=0 end
local function attribute(p,key,value)p.attrs[key]=value end
function Service:Move(player, action, direction)
	local record = self.records[player]
	local now = workspace:GetServerTimeNow()
	if action ~= "Dodge" or typeof(direction) ~= "Vector3" or direction.X ~= direction.X or direction.Y ~= direction.Y
		or direction.Z ~= direction.Z or math.abs(direction.Y) > 0.01 or direction.Magnitude < 0.99 or direction.Magnitude > 1.01 then return false, "Unknown move" end
	if player.Parent ~= Players or not self.active or self.phase ~= "Playing" or now >= self.endsAt or not record
		or not record.participating or record.isBot or not alive(record) then return false, "Not in an active Tag game" end
	if record.frozen or record.ragdoll or not self:_batInField(record) then return false, "Wait until you can move again" end
	if now < (record.moveCooldowns.Dodge or 0) then return false, "Dodge is recharging" end
	local params = self:_rayParameters()
	params.CollisionGroup = "TGPlayer"
	if not self:_dodgeGrounded(record, params) then return false, "Dodge while on the ground" end
	direction = Vector3.new(direction.X, 0, direction.Z).Unit
	local right = direction
	local forward = Vector3.new(-right.Z,0,right.X).Unit
	local forwardVelocity = forward * math.clamp(record.root.AssemblyLinearVelocity:Dot(forward),-record.humanoid.WalkSpeed,record.humanoid.WalkSpeed)
	local duration, distance = 0.32, 8
	local fraction = self:_clipDodgeTravel(record,direction*distance+forwardVelocity*duration,params)
	if distance*fraction < 0.75 then return false, "No room to dodge" end
	if not self:_startBurst(record,direction,now,duration,distance*fraction,forwardVelocity*fraction,params) then return false, "Your character cannot dodge yet" end
	record.moveCooldowns.Dodge = now + 3
	attribute(player,"TGDodgeReadyAt",record.moveCooldowns.Dodge)
	return true
end


local record={player=player,root=root,humanoid=humanoid,participating=true,moveCooldowns={}}
local service=setmetatable({records={[player]=record},active=true,phase="Playing",endsAt=200},{__index=Service})
function service:_batInField()return true end
function service:_rayParameters()return {}end
function service:_dodgeGrounded()return true end
function service:_clipDodgeTravel()return self.fraction or 1 end
function service:_startBurst(_,direction,_,duration,distance,forward)self.direction,self.distance,self.forward=direction,distance,forward return not self.deny end
local function invoke(direction,action)
 record.moveCooldowns={} service.direction=nil attributes.TGDodgeReadyAt=nil
 return service:Move(player,action or "Dodge",direction)
end
for _,value in ipairs({false,"right",1,{},Vector3.zero,Vector3.new(8,0,0),Vector3.new(1,.1,0),Vector3.new(math.huge,0,0),Vector3.new(0/0,0,0)})do
 check(not invoke(value)and service.direction==nil and attributes.TGDodgeReadyAt==nil,"Malformed direction rejected without timer/motion")
end
check(not invoke(Vector3.xAxis,"Vault"),"Removed Vault endpoint rejected")
for _,direction in ipairs({Vector3.xAxis,Vector3.xAxis*-1,Vector3.zAxis,Vector3.zAxis*-1})do
 root.CFrame.RightVector=Vector3.new(direction.Z,0,-direction.X)
 check(invoke(direction)and same(service.direction,direction),"Server retains exact world side independent of root facing")
 check(service.distance==8 and attributes.TGDodgeReadyAt==103,"Valid dash has bounded distance and cooldown")
end
service.fraction=.4 check(invoke(Vector3.xAxis)and math.abs(service.distance-3.2)<.00001,"Partial collision clearance shortens accepted dash")
service.fraction=.05 check(not invoke(Vector3.xAxis)and attributes.TGDodgeReadyAt==nil,"Insufficient clearance consumes no cooldown")
service.fraction=nil service.deny=true check(not invoke(Vector3.xAxis)and attributes.TGDodgeReadyAt==nil,"Failed ownership consumes no cooldown")
service.deny=nil record.ragdoll=true check(not invoke(Vector3.xAxis),"Ragdoll cannot initiate")record.ragdoll=nil
record.frozen=true check(not invoke(Vector3.xAxis),"Frozen cannot initiate")record.frozen=nil
service.phase="Results" check(not invoke(Vector3.xAxis),"Round end cannot initiate")service.phase="Playing"
print("Tag direction and server validation checks passed: "..checks)
