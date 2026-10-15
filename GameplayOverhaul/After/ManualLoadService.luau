local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local RS=game:GetService("ReplicatedStorage")
local PromptService=game:GetService("ProximityPromptService")
local TruckService=require(script.Parent.TruckService)
local PlotService=require(script.Parent.PlotService)
local AccessService=require(script.Parent.AccessService)
local PackageService=require(script.Parent.PackageService)
local Remotes=RS:WaitForChild("Remotes")
local ManualLoadService={}
local carrying={}
local function notify(plr,text,kind) Remotes.Notify:FireClient(plr,{text=text,kind=kind or "info"}) end
local function alive(plr)
 local char=plr.Character
 local root=char and char:FindFirstChild("HumanoidRootPart")
 local hum=char and char:FindFirstChildOfClass("Humanoid")
 if not root or not hum or hum.Health<=0 or (plr:GetAttribute("SecDeadUntil") or 0)>os.time() then return nil end
 return root
end
local function carrySpeed(plr,list)
 local hum=plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
 if not hum or (plr:GetAttribute("FrozenUntil") or 0)>os.time() then return end
 local stolen=0;for _,e in list or {} do if e.stolen then stolen+=1 end end
 local base=(plr:GetAttribute("SpeedBoostUntil") or 0)>os.time() and 32 or 16
 hum.WalkSpeed=base*(1-.03*math.min(stolen,10))
end
function ManualLoadService.carryCount(plr)
 local n=0;for _,e in carrying[plr.UserId] or {} do if e.pkg.Parent then n+=1 end end;return n
end
function ManualLoadService.stolenCount(plr,ownerId)
 local n=0
 for _,e in carrying[plr.UserId] or {} do if e.pkg.Parent and e.stolen and (not ownerId or e.ownerId==ownerId) then n+=1 end end
 return n
end
function ManualLoadService.dropCarried(plr)
 local list=carrying[plr.UserId] or {};carrying[plr.UserId]=nil
 for _,e in list do
  if e.pkg.Parent then
   PackageService.detachCarry(e.pkg)
   local original=PlotService.plotById(e.plotId)
   if original and original.owner and original.owner.UserId==e.ownerId and original.active then TruckService.restage(e.pkg,original)
   else e.pkg:Destroy() end
  end
 end
 PackageService.refreshCarry(plr.Character)
 carrySpeed(plr,{})
end
function ManualLoadService.grab(plr,pkg)
 local root=alive(plr);if not root then return false end
 if not pkg or not pkg:IsA("BasePart") or not pkg:GetAttribute("Company") then return false end
 local plot=PlotService.plotOfInstance(pkg)
 local mine=PlotService.forPlayer(plr)
 if not plot or not plot.owner or not mine or mine.owner~=plr or pkg:GetAttribute("CarriedBy") then return false end
 if (root.Position-pkg.Position).Magnitude>10 then return false end
 if not PackageService.Motion.visible(root.Position,pkg.Position,{plr.Character},pkg) then return false end
 local stolen=plot.owner~=plr
 if stolen and not AccessService.isNight() then notify(plr,"Other warehouses can only be robbed at night.","error");return false end
 local list=carrying[plr.UserId] or {}
 local own,other=0,0
 for _,e in list do if e.stolen then other+=1 else own+=1 end end
 if (stolen and other>=10) or (not stolen and own>=1) then notify(plr,"Deliver or drop your carried parcels first.","error");return false end
 local taken=TruckService.takeSpecificStaged(pkg,plot);if not taken then return false end
 taken:SetAttribute("CarriedBy",plr.UserId)
 taken:SetAttribute("OriginalOwner",plot.owner.UserId)
 if not PackageService.attachCarry(taken,plr.Character) then taken:SetAttribute("CarriedBy",nil);TruckService.restage(taken,plot);return false end
 table.insert(list,{pkg=taken,stolen=stolen,ownerId=plot.owner.UserId,plotId=plot.id})
 carrying[plr.UserId]=list;carrySpeed(plr,list)
 if stolen then notify(plot.owner,plr.DisplayName.." took a parcel from your warehouse.","error") end
 notify(plr,stolen and "Stolen parcel — take it to your loading bay." or "Parcel picked up — take it to its company bay.")
 return true
end
local function step()
 for uid,list in carrying do
  local plr=Players:GetPlayerByUserId(uid)
  local root=plr and alive(plr)
  if not root then if plr then ManualLoadService.dropCarried(plr) else carrying[uid]=nil end;continue end
  local plot=PlotService.forPlayer(plr);local keep={}
  for _,e in list do
   local pkg=e.pkg
   if not pkg.Parent then continue end
   local bay=plot and plot.owner==plr and TruckService.getLoadBay(pkg:GetAttribute("Company"),plot)
   if e.stolen and (not bay or bay.leaving or bay.count>=bay.capacity) then
    for _,b in plot and plot.loadBays or {} do if not b.leaving and b.count<b.capacity then bay=b;break end end
   end
   if bay and (TruckService.loadPoint(bay)-root.Position).Magnitude<8 and not bay.leaving and bay.count<bay.capacity then
    PackageService.detachCarry(pkg)
    if bay:load(pkg) then notify(plr,"Parcel loaded. Payment arrives when the truck departs.","success")
    else PackageService.attachCarry(pkg,plr.Character);table.insert(keep,e) end
   else table.insert(keep,e) end
  end
  carrying[uid]=#keep>0 and keep or nil
  PackageService.refreshCarry(plr.Character);carrySpeed(plr,keep)
 end
end
function ManualLoadService.Start()
 Remotes.ManualAction.OnServerEvent:Connect(function(plr) ManualLoadService.dropCarried(plr) end)
 PromptService.PromptTriggered:Connect(function(prompt,plr) if prompt.Name=="GrabParcel" and prompt.Enabled then ManualLoadService.grab(plr,prompt.Parent) end end)
 local function hook(plr)
  plr.CharacterRemoving:Connect(function() ManualLoadService.dropCarried(plr) end)
  local function character(char) local hum=char:WaitForChild("Humanoid",5);if hum then hum.Died:Connect(function() ManualLoadService.dropCarried(plr) end) end end
  plr.CharacterAdded:Connect(character);if plr.Character then task.spawn(character,plr.Character) end
 end
 Players.PlayerAdded:Connect(hook);for _,plr in Players:GetPlayers() do hook(plr) end
 Players.PlayerRemoving:Connect(ManualLoadService.dropCarried)
 local elapsed=0
 RunService.Heartbeat:Connect(function(dt) elapsed+=dt;if elapsed>=.1 then elapsed=0;step() end end)
end
return ManualLoadService

