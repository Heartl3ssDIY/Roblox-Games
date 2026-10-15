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
__SERVICE_SOURCE__
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
