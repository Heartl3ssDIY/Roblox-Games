local WS=game:GetService("Workspace")
local Players=game:GetService("Players")
local ServerStorage=game:GetService("ServerStorage")

local PlotService={plots={},byOwner={},templates={}}
local primaryPlot
local Truck,Worker,Time
local PLOT_COUNT=8

local function services()
 Truck=Truck or require(script.Parent.TruckService)
 Worker=Worker or require(script.Parent.WorkerService)
 Time=Time or require(script.Parent.TimeService)
 return Truck,Worker,Time
end

local function frameOf(model)
 local marker=model:FindFirstChild("PlotOrigin")
 return marker and marker.CFrame or CFrame.identity
end

function PlotService.townCentre()
 local town=WS:FindFirstChild("TownCentre")
 local plaza=town and town:FindFirstChild("Plaza")
 if plaza then return Vector3.new(plaza.Position.X,0,plaza.Position.Z) end
 return Vector3.new(20,0,-450)
end

function PlotService.slotFrame(slot)
 local first=frameOf(WS.Warehouse)
 if slot==1 then return first end
 local centre=PlotService.townCentre()
 local offset=first.Position-Vector3.new(centre.X,first.Y,centre.Z)
 local position=Vector3.new(centre.X,first.Y,centre.Z)+CFrame.Angles(0,(slot-1)*math.pi*2/PLOT_COUNT,0):VectorToWorldSpace(offset)
 return CFrame.lookAt(position,Vector3.new(centre.X,position.Y,centre.Z))
end

function PlotService.slotOffset(slot)
 return PlotService.slotFrame(slot or 1).Position-frameOf(WS.Warehouse).Position
end

local function moveTo(model,target)
 local delta=target*frameOf(model):Inverse()
 local pivots={}
 for _,d in model:GetDescendants() do
  if d:IsA("Model") and not d.PrimaryPart then pivots[d]=d:GetPivot() end
 end
 for _,d in model:GetDescendants() do if d:IsA("BasePart") then d.CFrame=delta*d.CFrame end end
 for m,cf in pivots do m.WorldPivot=delta*cf end
end


local function dockCollisions(wh)
 local visuals=wh:FindFirstChild("WarehouseVisuals")
 if not visuals then return end
 local floor=visuals:FindFirstChild("FloorSurface",true)
 if not floor then return end
 local top=floor.Position.Y+floor.Size.Y/2
 local folder=wh:FindFirstChild("DockCollisions") or Instance.new("Folder")
 folder.Name="DockCollisions";folder.Parent=wh
 for _,p in folder:GetChildren() do p:Destroy() end
 for _,spec in {{wall="WallDispatch",prefix="Load",count=4},{wall="WallReceiving",prefix="Receive",count=2}} do
  local wall=visuals.Shell:FindFirstChild(spec.wall)
  if wall then
   wall.CanCollide=false
   local openings={}
   for i=1,spec.count do
    local frame=visuals.Yard:FindFirstChild(spec.prefix..i.."_BayOutline")
    if frame then table.insert(openings,wall.CFrame:PointToObjectSpace(frame.Position).X) end
   end
   table.sort(openings)
   local function solid(name,x,width,bottom,height)
    if width<=0 or height<=0 then return end
    local p=Instance.new("Part");p.Name=spec.prefix..name;p.Size=Vector3.new(width,height,wall.Size.Z)
    local pos=wall.CFrame:PointToWorldSpace(Vector3.new(x,0,0))
    p.CFrame=CFrame.new(pos.X,bottom+height/2,pos.Z)*wall.CFrame.Rotation
    p.Anchored=true;p.Transparency=1;p.CanCollide=true;p.CanTouch=false;p.Parent=folder
   end
   local previous=-wall.Size.X/2
   for i,x in openings do
    local edge=x-6.75;solid("Pillar"..i,(previous+edge)/2,edge-previous,top,wall.Size.Y);previous=x+6.75
   end
   solid("End",(previous+wall.Size.X/2)/2,wall.Size.X/2-previous,top,wall.Size.Y)
   solid("Header",0,wall.Size.X,top+10.5,math.max(0,wall.Size.Y-10.5))
  end
 end
end

function PlotService.alignLayout(wh)
 dockCollisions(wh)
 local visuals=wh:FindFirstChild("WarehouseVisuals")
 local yard=visuals and visuals:FindFirstChild("Yard")
 local floor=visuals and visuals:FindFirstChild("FloorSurface",true)
 if not yard or not floor then return end
 local top=floor.Position.Y+floor.Size.Y/2
 local frame=frameOf(wh)
 local staging=wh:FindFirstChild("Staging")
 local outline=yard:FindFirstChild("StagingOutline")
 local shift=outline and staging and Vector3.new(outline.Position.X-staging.Position.X,0,outline.Position.Z-staging.Position.Z) or Vector3.zero
 for _,entry in {{name="LoadBays",prefix="Load",apron="DispatchApron",inbound=false},{name="OffloadBays",prefix="Receive",apron="ReceivingApron",inbound=true}} do
  local group=wh:FindFirstChild(entry.name);local apron=yard:FindFirstChild(entry.apron)
  if group and apron then
   for _,pad in group:GetChildren() do if pad:IsA("BasePart") then
    local number=pad.Name:match("(%d+)$")
    local visual=yard:FindFirstChild(entry.prefix..number.."_BayOutline")
    if visual then
     local position=Vector3.new(visual.Position.X,top+.04,visual.Position.Z)
     local out=apron.Position-position;out=Vector3.new(out.X,0,out.Z)
     local wall=visuals.Shell:FindFirstChild(entry.inbound and "WallReceiving" or "WallDispatch")
     local normal=wall and wall.CFrame.ZVector or frame.ZVector
     if normal:Dot(out)<0 then normal=-normal end
     pad.CFrame=CFrame.lookAt(position,position+(entry.inbound and normal or -normal))
     pad.Size=Vector3.new(pad.Size.X,.06,pad.Size.Z)
     pad.CanCollide=false;pad.CanTouch=false
     local sign=wh:FindFirstChild("BaySign_"..pad.Name,true)
     if sign then
      local delta=position-sign.Position
      local axis=pad.CFrame.RightVector
      sign.CFrame+=axis*delta:Dot(axis)
     end
     local route=pad:FindFirstChild("Doorway") or Instance.new("Attachment")
     route.Name="Doorway"
     if wall then
      local door=visuals.Docks:FindFirstChild(entry.prefix..number.."_Frame")
      local point=door and door.Position or (position+normal*((wall.Position-position):Dot(normal)+.8))
      route.WorldPosition=Vector3.new(point.X,top,point.Z)
      route.Parent=pad
      route.Position=pad.CFrame:PointToObjectSpace(Vector3.new(point.X,top,point.Z))
     end
    end
   end end
  end
 end
 if staging and outline then staging.CFrame=CFrame.new(outline.Position.X,top+.035,outline.Position.Z)*frame.Rotation;staging.Size=Vector3.new(42,.05,32);staging.CanCollide=false end
 local slots=wh:FindFirstChild("CameraSlots")
 if slots and shift.Magnitude>.01 then for _,slot in slots:GetChildren() do if slot:IsA("BasePart") then slot.CFrame+=shift end end end
 local desk=visuals:FindFirstChild("DeskTop",true)
 if desk then
  local function marker(name,position,facing)
   local p=wh:FindFirstChild(name)
   if not p then p=Instance.new("Part");p.Name=name;p.Size=Vector3.new(.8,.1,.8);p.Parent=wh end
   p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Transparency=1
   p.CFrame=CFrame.lookAt(position,Vector3.new(facing.X,position.Y,facing.Z))
   return p
  end
  local function at(x,z,y) local q=desk.CFrame:PointToWorldSpace(Vector3.new(x,0,z));return Vector3.new(q.X,y,q.Z) end
  local player=at(0,-4,top+.1);local investor=at(0,4,top+.1)
  marker("PlayerChairAnchor",player,desk.Position)
  marker("InvestorChairAnchor",investor,desk.Position)
  marker("LaptopAnchor",at(0,1,desk.Position.Y+desk.Size.Y/2+.015),player)
  marker("TrophyAnchor",at(7,10,top),at(7,0,top))
  marker("ArmouryAnchor",at(-12,-9,top),at(0,-9,top))
 end
end

local function record(id,model,owner)
 PlotService.alignLayout(model)
 local frame=frameOf(model)
 return {id=id,model=model,wh=model,owner=owner,origin=frame.Position,frame=frame,
  staging=model:WaitForChild("Staging"),LoadBays=model:WaitForChild("LoadBays"),
  OffloadBays=model:WaitForChild("OffloadBays"),active=false,loadBays={},stagedPackages={}}
end

local function unclaimed(rec)
 rec.wh:SetAttribute("PlotId",rec.id)
 rec.wh:SetAttribute("OwnerUserId",0)
 rec.wh:SetAttribute("Claimed",false)
 local sign=rec.wh:FindFirstChild("NameSign")
 local label=sign and sign:FindFirstChild("Name",true)
 if label then label.Text="UNCLAIMED WAREHOUSE" end
 local spawn=rec.wh:FindFirstChild("SpawnLocation")
 if spawn then spawn.Enabled=false end
end

function PlotService.floorY(plot)
 local floor=plot.wh:FindFirstChild("FloorSurface",true)
 if floor then return floor.Position.Y+floor.Size.Y/2 end
 return plot.staging.Position.Y+plot.staging.Size.Y/2
end

function PlotService.primary() return primaryPlot end
function PlotService.all()
 local list={}
 for id=1,PLOT_COUNT do if PlotService.plots[id] then table.insert(list,PlotService.plots[id]) end end
 return list
end
function PlotService.forPlayer(plr)
 if plr then return PlotService.byOwner[plr.UserId] end
 return primaryPlot
end
function PlotService.plotById(id) return PlotService.plots[id] end
function PlotService.plotOfInstance(inst)
 for _,plot in PlotService.all() do if inst:IsDescendantOf(plot.wh) then return plot end end
 return nil
end

function PlotService.captureTemplate()
 if PlotService.template then return end
 local folder=Instance.new("Folder");folder.Name="PlotTemplates";folder.Parent=ServerStorage
 for _,plot in PlotService.all() do
  local model=plot.wh:Clone();model.Name="Plot"..plot.id
  for _,name in {"Workers","Trucks"} do local runtime=model:FindFirstChild(name);if runtime then runtime:Destroy() end end
  model.Parent=folder
  PlotService.templates[plot.id]=model
 end
 PlotService.template=PlotService.templates[1]
end

function PlotService.spawnPlotAt(slot,owner)
 local current=PlotService.plots[slot]
 if current then return current end
 local folder=WS:FindFirstChild("Plots")
 if not folder then folder=Instance.new("Folder");folder.Name="Plots";folder.Parent=WS end
 local model=folder:FindFirstChild("Plot"..slot)
 if not model then
  model=(PlotService.templates[slot] or PlotService.template or WS.Warehouse):Clone()
  model.Name="Plot"..slot
  moveTo(model,PlotService.slotFrame(slot))
  model.Parent=folder
 end
 local rec=record(slot,model,owner)
 PlotService.plots[slot]=rec
 unclaimed(rec)
 return rec
end

function PlotService.verifyPlot(rec)
 if not rec or not rec.wh then return false end
 for _,name in {"PlotOrigin","WarehouseVisuals","LoadBays","OffloadBays","Staging","Teleporter","NameSign","LaptopAnchor"} do
  if not rec.wh:FindFirstChild(name) then warn("Plot "..rec.id.." missing "..name);return false end
 end
 return true
end
function PlotService.verifyAll()
 for _,rec in PlotService.all() do if not PlotService.verifyPlot(rec) then return false end end
 return true
end

local function setPlotRef(plr,model)
 local ref=plr:FindFirstChild("PlotModel")
 if not ref then ref=Instance.new("ObjectValue");ref.Name="PlotModel";ref.Parent=plr end
 ref.Value=model
end

local function spawnCF(rec)
 local pad=rec.wh:FindFirstChild("SpawnLocation") or rec.wh:FindFirstChild("SpawnPad")
 return (pad and pad.CFrame or rec.frame)+Vector3.new(0,4,0)
end

function PlotService.teleportToPlot(plr,rec)
 local root=plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
 if not root or not rec then return false end
 root.CFrame=spawnCF(rec)
 return true
end

local function bindSpawn(plr)
 local function teleport()
  local char=plr.Character
  if not char then return end
  local root=char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart",5)
  local rec=PlotService.byOwner[plr.UserId]
  if root and rec then task.wait(.1);if root.Parent and PlotService.byOwner[plr.UserId]==rec then root.CFrame=spawnCF(rec) end end
 end
 if plr.Character then task.spawn(teleport) end
 plr.CharacterAdded:Connect(teleport)
end

function PlotService.visitList(plr)
 local mine=PlotService.byOwner[plr.UserId]
 local list={}
 for _,p in PlotService.all() do
  if p~=mine then table.insert(list,{id=p.id,name=p.owner and p.owner.DisplayName or "Unclaimed Plot "..p.id,owned=p.owner~=nil}) end
 end
 return list,mine~=nil
end

function PlotService.assignPlayer(plr)
 if PlotService.byOwner[plr.UserId] then return PlotService.byOwner[plr.UserId] end
 local rec
 for _,p in PlotService.all() do if not p.owner and not p.releasing then rec=p;break end end
 if not rec then return nil end
 rec.owner=plr;PlotService.byOwner[plr.UserId]=rec
 rec.wh:SetAttribute("OwnerUserId",plr.UserId);rec.wh:SetAttribute("Claimed",true)
 setPlotRef(plr,rec.wh)
 local trucks,workers,time=services()
 trucks.initPlot(rec)
 workers.spawnShiftForPlot(rec,time.getShift())
 bindSpawn(plr)
 require(script.Parent.WarehouseNameService).apply(plr)
 return rec
end

function PlotService.releasePlayer(plr)
 local rec=PlotService.byOwner[plr.UserId]
 if not rec or rec.releasing then return end
 rec.releasing=true
 pcall(function() require(script.Parent.SaveService).save(plr) end)
 rec.active=false
 local _,workers=services()
 workers.despawnPlot(rec)
 for _,bay in rec.loadBays or {} do bay:destroy() end
 local model=PlotService.templates[rec.id]:Clone()
 model.Name=rec.wh.Name
 local parent=rec.wh.Parent
 local replacement=record(rec.id,model,nil)
 unclaimed(replacement)
 PlotService.byOwner[plr.UserId]=nil
 local ref=plr:FindFirstChild("PlotModel");if ref then ref.Value=nil end
 rec.owner=nil
 rec.wh:Destroy()
 model.Parent=parent
 PlotService.plots[rec.id]=replacement
 if rec==primaryPlot then primaryPlot=replacement;Truck.loadBays=replacement.loadBays end
end

function PlotService.Start()
 primaryPlot=record(1,WS:WaitForChild("Warehouse"),nil)
 PlotService.plots[1]=primaryPlot
 unclaimed(primaryPlot)
 for slot=2,PLOT_COUNT do PlotService.spawnPlotAt(slot,nil) end
 PlotService.captureTemplate()
 Players.PlayerAdded:Connect(PlotService.assignPlayer)
 Players.PlayerRemoving:Connect(PlotService.releasePlayer)
 for _,plr in Players:GetPlayers() do task.spawn(PlotService.assignPlayer,plr) end
 return primaryPlot
end

return PlotService
