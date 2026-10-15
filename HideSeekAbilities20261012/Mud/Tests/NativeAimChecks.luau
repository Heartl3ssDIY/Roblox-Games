local Service = require(script.Parent.ServerCandidate)
local map = require(script.Parent.ClientMapping)
local results = {}
local function check(name, fn)
	local ok, err = pcall(fn)
	table.insert(results, { name = name, passed = ok, error = not ok and tostring(err) or nil })
end
local input = { PreferredInput = Enum.PreferredInput.KeyboardAndMouse, MouseBehavior = Enum.MouseBehavior.Default, pointer = Vector2.new(500,300) }
function input:GetMouseLocation() return self.pointer end
local guiService = { full = Rect.new(0,-58,1366,709), device = Rect.new(0,-58,1366,709) }
function guiService:GetInsetArea(kind) return kind == Enum.ScreenInsets.None and self.full or self.device end
local camera = { ViewportSize = Vector2.new(1366,767) }
function camera:ViewportPointToRay(x,y) self.last = Vector2.new(x,y) return Ray.new(Vector3.new(0,2,4),Vector3.new(0,0,-1)) end
local main = { AbsolutePosition = Vector2.new(0,-58), AbsoluteSize = Vector2.new(1366,767),
	Crosshair = { Visible = true, Position = UDim2.fromScale(0.5,0.5), Size = UDim2.fromOffset(14,14), AnchorPoint = Vector2.new(0.5,0.5) } }
check("Mouse ray uses raw viewport pixels without adding topbar inset", function()
	map(input,guiService,camera,main)
	assert(camera.last == Vector2.new(500,300))
end)
check("Crosshair points to same pixel as mouse ray", function()
	assert(math.abs(main.Crosshair.Position.X.Scale*1366-500)<0.001 and math.abs(main.Crosshair.Position.Y.Scale*767-300)<0.001)
end)
check("Authored reticle size and anchor preserved", function() assert(main.Crosshair.Size==UDim2.fromOffset(14,14) and main.Crosshair.AnchorPoint==Vector2.new(0.5,0.5)) end)
check("Device safe mouse coordinates do not subtract notch twice", function()
	guiService.full,guiService.device=Rect.new(-59,-58,792,334),Rect.new(0,-58,733,313)
	camera.ViewportSize,main.AbsoluteSize=Vector2.new(733,371),Vector2.new(733,371)
	map(input,guiService,camera,main)
	assert(camera.last==Vector2.new(500,300))
	assert(math.abs(main.Crosshair.Position.X.Scale*733-500)<0.001)
end)
check("Touch uses camera centre instead of fire-button finger", function()
	input.PreferredInput=Enum.PreferredInput.Touch
	map(input,guiService,camera,main)
	assert(camera.last==camera.ViewportSize*0.5)
end)
check("Gamepad uses camera centre instead of stale mouse", function()
	input.PreferredInput=Enum.PreferredInput.Gamepad
	map(input,guiService,camera,main)
	assert(camera.last==camera.ViewportSize*0.5)
end)
check("Mouse on touch-capable device follows current preferred input", function()
	input.TouchEnabled=true input.PreferredInput=Enum.PreferredInput.KeyboardAndMouse
	map(input,guiService,camera,main) assert(camera.last==Vector2.new(500,300))
end)
check("Locked-centre mouse follows camera forward", function()
	input.MouseBehavior=Enum.MouseBehavior.LockCenter
	map(input,guiService,camera,main) assert(camera.last==camera.ViewportSize*0.5)
end)
check("Out-of-viewport mouse is clamped", function()
	input.MouseBehavior=Enum.MouseBehavior.Default input.pointer=Vector2.new(-100,2000)
	map(input,guiService,camera,main) assert(camera.last==Vector2.new(0,371))
end)
local folder=Instance.new("Folder") folder.Name="MudAimNativeAudit" folder.Parent=workspace
local base=Vector3.new(44000,12000,44000)
local function part(parent,name,position,size)
	local p=Instance.new("Part") p.Name=name p.Anchored=true p.Size=size or Vector3.one p.Position=base+position p.Parent=parent return p
end
local function character(name,offset,userId)
	local model=Instance.new("Model") model.Name=name model.Parent=folder
	local root=part(model,"HumanoidRootPart",offset,Vector3.new(2,2,1))
	local head=part(model,"Head",offset+Vector3.new(0,2,0),Vector3.new(2,2,1))
	local humanoid=Instance.new("Humanoid") humanoid.Parent=model
	local player={Character=model,UserId=userId}
	function player:GetAttribute() return nil end
	function player:SetAttribute() end
	return {character=model,root=root,humanoid=humanoid,ready=true,participating=true,player=player,teamId=1,requests={}}
end
local shooter=character("Shooter",Vector3.zero,1)
local target=character("Target",Vector3.new(0,0,-40),2) target.teamId=2
local function tool(kind)
	local t=Instance.new("Tool") t.Name=kind.."Gun" t.Enabled=true
	t:SetAttribute("MDManaged",true) t:SetAttribute("MDRound",12) t:SetAttribute("MDOwnerUserId",1) t:SetAttribute("GunKind",kind)
	local h=part(t,"Handle",Vector3.new(2,1,-1))
	local a=Instance.new("Attachment") a.Name="MuzzleAttachment" a.Parent=h
	t.Parent=shooter.character return t,a
end
local mud,muzzle=tool("Mud") local heat=tool("Heat")
local bounds=part(folder,"Bounds",Vector3.zero,Vector3.new(300,100,300)) bounds.CanCollide=false bounds.CanQuery=false
local gameplay=Instance.new("Folder") gameplay.Parent=folder
local arena=Instance.new("Folder") arena.Parent=folder
local effectFolder=Instance.new("Folder") effectFolder.Parent=folder
local service=setmetatable({running=true,active=true,phase="Playing",endsAt=workspace:GetServerTimeNow()+100,currentRound=5,roundNumber=12,
	records={shooter,target},bounds=bounds,gameplay=gameplay,arena=arena,projectiles={},effects=effectFolder},Service)
service._publishRecord=function() end
local packet={cameraOrigin=base+Vector3.new(0,2,4),cameraDirection=Vector3.new(0,0,-1)}
local now=workspace:GetServerTimeNow()
local ok,problem=xpcall(function()
	check("Native ray packet converges real muzzle onto camera target",function()
		local unit,origin=service:_resolveAim(shooter,"Mud",packet)
		assert(unit and origin==muzzle.WorldPosition)
		local params=service:_rayParameters(shooter,false)
		local hit=workspace:Raycast(origin,unit*100,params)
		assert(hit and hit.Instance:IsDescendantOf(target.character))
		assert(unit.X<0,"muzzle orientation was incorrectly used")
	end)
	check("Unbounded remote camera origin rejected",function() assert(not service:_resolveAim(shooter,"Mud",{cameraOrigin=base+Vector3.new(100,0,0),cameraDirection=Vector3.new(0,0,-1)})) end)
	check("NaN aim rejected",function() assert(not service:_resolveAim(shooter,"Mud",{cameraOrigin=packet.cameraOrigin,cameraDirection=Vector3.new(0/0,0,-1)})) end)
	check("Infinite camera position rejected",function() assert(not service:_resolveAim(shooter,"Mud",{cameraOrigin=Vector3.new(math.huge,0,0),cameraDirection=Vector3.new(0,0,-1)})) end)
	check("Zero direction rejected",function() assert(not service:_resolveAim(shooter,"Mud",{cameraOrigin=packet.cameraOrigin,cameraDirection=Vector3.zero})) end)
	check("Missing camera fields rejected",function() assert(not service:_resolveAim(shooter,"Mud",{})) end)
	check("Managed equipped gun remains mandatory",function()
		mud.Enabled=false local unit=service:_resolveAim(shooter,"Mud",packet) mud.Enabled=true assert(not unit)
	end)
	local wall=part(folder,"CameraWall",Vector3.new(0,2,2),Vector3.new(4,4,0.5))
	check("Camera cannot be spoofed through cover behind shooter",function() assert(not service:_resolveAim(shooter,"Mud",packet)) end)
	wall:Destroy()
	wall=part(folder,"MuzzleWall",Vector3.new(1.5,1,-10),Vector3.new(0.8,5,0.6))
	local hits=0 service._stick=function() hits+=1 end
	check("Camera-visible enemy remains blocked by muzzle-side wall",function()
		assert(service:_fire(shooter,packet,now))
		service:_tickProjectiles(0.2)
		assert(#service.projectiles==0 and hits==0)
	end)
	wall:Destroy()
	check("Cooldown still rejects immediate repeat",function() assert(not service:_fire(shooter,packet,now+0.1)) end)
	check("Clear camera-guided shot reaches enemy with unchanged projectile motion",function()
		assert(service:_fire(shooter,packet,now+1))
		for _=1,5 do service:_tickProjectiles(0.1) end
		assert(hits==1 and #service.projectiles==0)
	end)
	check("Muddy player cannot shoot",function() shooter.muddy=true assert(not service:_fire(shooter,packet,now+2)) shooter.muddy=false end)
	check("Bot legacy vector aiming remains supported",function()
		local unit,origin=service:_resolveAim(shooter,"Mud",Vector3.new(0,0,-1)) assert(unit==Vector3.new(0,0,-1) and origin)
	end)
	check("Heat stores camera-ray aim packet",function()
		local result=service:_action(shooter,"Heat",true,packet)
		assert(result.ok and shooter.heatAim==packet and shooter.heatDirection)
	end)
	check("Heat release clears packet and lease",function()
		service:_clearHeat(shooter,true)
		assert(shooter.heatAim==nil and shooter.heatDirection==nil and shooter.heatLeaseEndsAt==0)
	end)
	check("Muzzle cannot protrude through close wall",function()
		local close=part(folder,"CloseWall",Vector3.new(1,0.5,-0.5),Vector3.new(0.3,4,4))
		assert(not service:_resolveAim(shooter,"Mud",packet)) close:Destroy()
	end)
	check("Visible edge of mud ball hits instead of passing through avatar",function()
  muzzle.Parent.Position=base+Vector3.new(1.35,0,-1)
  assert(service:_fire(shooter,Vector3.new(0,0,-1),now+3))
  for _=1,5 do service:_tickProjectiles(0.1) end
  assert(hits==2,"visible mud edge missed the player")
  muzzle.Parent.Position=base+Vector3.new(2,1,-1)
 end)
 check("Sphere-sized shot remains stopped by walls",function()
  local wall=part(folder,"SolidCover",Vector3.new(0,1,-10),Vector3.new(10,10,1))
  assert(service:_fire(shooter,packet,now+4))
  for _=1,5 do service:_tickProjectiles(0.1) end
  assert(#service.projectiles==0)
  wall:Destroy()
 end)
 check("Heat aims from barrel at camera-selected muddy teammate",function()
  target.teamId=1 target.muddy=true
  target.character:PivotTo(target.character:GetPivot()+Vector3.new(0,0,25))
  shooter.requests.Heat=nil
  local result=service:_action(shooter,"Heat",true,packet)
  assert(result.ok)
  local rescued,origin,point=service:_heatTarget(shooter,workspace:GetServerTimeNow())
  assert(rescued==target and origin and point)
 end)
 check("Heat cannot reach teammate through wall",function()
  local wall=part(folder,"RescueCover",Vector3.new(0,2,-7),Vector3.new(12,10,1))
  assert(service:_heatTarget(shooter,workspace:GetServerTimeNow())==nil)
  wall:Destroy()
 end)
end,debug.traceback)
folder:Destroy()
if not ok then table.insert(results,{name="fixture completed",passed=false,error=problem}) end
local passed=0 for _,r in ipairs(results) do if r.passed then passed+=1 end end
return {passed=passed,total=#results,checks=results}
