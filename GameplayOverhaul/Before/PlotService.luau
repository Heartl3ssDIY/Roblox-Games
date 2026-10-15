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

local function record(id,model,owner)
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
 return (plr and PlotService.byOwner[plr.UserId]) or primaryPlot
end
function PlotService.plotById(id) return PlotService.plots[id] end
function PlotService.plotOfInstance(inst)
 for _,plot in PlotService.all() do if inst:IsDescendantOf(plot.wh) then return plot end end
 return primaryPlot
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

