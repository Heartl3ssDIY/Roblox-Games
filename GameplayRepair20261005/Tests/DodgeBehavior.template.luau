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
__SHARED__
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
