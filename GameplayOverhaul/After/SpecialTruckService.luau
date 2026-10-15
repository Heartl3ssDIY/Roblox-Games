-- SpecialTruckService: the global special gift-truck event. A truck "crashes" at the town centre on
-- certain GLOBAL days, scattering gift packages players race to grab (carry mechanic + rewards are in
-- the carry/reward layer). Whether it appears on a given day is DETERMINISTIC (seeded by the global
-- day), so every server agrees and the schedule advances even while empty.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local WS=game:GetService("Workspace")
local SpecialConfig=require(RS.Configs.SpecialConfig)
local TimeService=require(script.Parent.TimeService)
local PromptService=game:GetService("ProximityPromptService")
local PlotService=require(script.Parent.PlotService)
local CurrencyService=require(script.Parent.CurrencyService)
local RewardService=require(script.Parent.RewardService)
local PackageService=require(script.Parent.PackageService)

local SpecialTruckService={}
local activeDay=nil
local giftsFolder=nil
local forcedDay=nil
local forcedEndTH=nil   -- a forced event also clears after WindowHours (in-game hrs) from when it was forced
local carryExtra={}    -- [uid] = +carry beyond base 1 (black-market upgrades; max 4 -> total 5)
local carriedGifts={}  -- [uid] = { gift, ... } currently carried

-- Deterministic "does the truck come on global day D?" 10% base, halving after each appearance that
-- week. Seeded by the day so every server computes the same answer.
local function appearsToday(day)
	local weekStart=day-((day-1)%7)
	local chance=SpecialConfig.BaseChance
	local appears=false
	for d=weekStart,day do
		local hit=Random.new(d*7919+13):NextNumber() < chance
		if d==day then appears=hit end
		if hit then chance=chance/2 end
	end
	return appears
end
SpecialTruckService.appearsToday=appearsToday
local function packageCount(day)
	local rng=Random.new(day*104729+1)
	return SpecialConfig.MinPackages + rng:NextInteger(0, SpecialConfig.MaxPackages-SpecialConfig.MinPackages)
end
-- Deterministic random ARRIVAL hour for global day D, kept within daytime. Seeded by the day so every
-- server agrees. This replaces the old "always starts at hour 0 (midnight)" behaviour.
local function startHourForDay(day)
	local lo=SpecialConfig.EarliestHour or 7
	local hi=SpecialConfig.LatestHour or 17
	if hi<lo then hi=lo end
	return Random.new(day*2654435761 + 97):NextInteger(lo, hi)
end
SpecialTruckService.startHourForDay=startHourForDay
-- Confirmations for a given day (defaults to the current global day): does it appear, and at what hour.
function SpecialTruckService.scheduleFor(day)
	day=day or TimeService.getDay()
	return {day=day, appears=appearsToday(day), hour=startHourForDay(day)}
end
-- The next upcoming event within `lookahead` days (default 14): {day, hour} or nil.
function SpecialTruckService.nextEvent(lookahead)
	local d0=TimeService.getDay()
	for d=d0, d0+(lookahead or 14) do
		if appearsToday(d) then return {day=d, hour=startHourForDay(d), daysAway=d-d0} end
	end
	return nil
end

local GIFT_VARIANTS={"Rose","Sky","Violet","Mint","Amber","Coral"}

local function placeGift(gift, cf)
 gift.CFrame=cf
 for _,part in gift:GetDescendants() do
  if part:IsA("BasePart") then
   local joint=part:FindFirstChild("GiftJoint")
   if joint then part.CFrame=cf*joint.C0 end
  end
 end
end

local function makeGift(i, pos)
 local templates=game:GetService("ServerStorage"):WaitForChild("GiftModels")
 local variant=GIFT_VARIANTS[(i-1)%#GIFT_VARIANTS+1]
 local g=assert(templates:FindFirstChild(variant),"Missing gift model: "..variant):Clone()
 g.Name="Gift_"..i
 g:SetAttribute("SpecialGift",true)
 g:SetAttribute("RewardIdx",RewardService.rollIndex())
 g:SetAttribute("Carried",nil)
 g:SetAttribute("ClaimedBy",nil)
 g:SetAttribute("Redeemed",nil)
 placeGift(g,CFrame.new(pos+Vector3.new(0,g.Size.Y/2+.04,0)))
 local light=Instance.new("PointLight");light.Color=g.Color;light.Range=5;light.Brightness=.45;light.Parent=g
 local prompt=Instance.new("ProximityPrompt");prompt.Name="GrabGift"
 prompt.ActionText="Grab";prompt.ObjectText="Special Gift"
 prompt.KeyboardKeyCode=Enum.KeyCode.E;prompt.HoldDuration=0
 prompt.MaxActivationDistance=8;prompt.RequiresLineOfSight=true;prompt.Parent=g
 return g
end

local function announce(text)
	local rem=RS:FindFirstChild("Remotes"); local notify=rem and rem:FindFirstChild("Notify")
	if not notify then return end
	for _,plr in ipairs(Players:GetPlayers()) do pcall(function() notify:FireClient(plr,{text=text,kind="success"}) end) end
end

local function notifyOne(plr,text,kind)
	local rem=RS:FindFirstChild("Remotes"); local n=rem and rem:FindFirstChild("Notify")
	if n then n:FireClient(plr,{text=text,kind=kind or "info"}) end
end

-- ===== event IO: a RemoteEvent (banner) + a Configuration (HUD state) =====
local function ensureEventIO()
	local rem=RS:FindFirstChild("Remotes"); if not rem then rem=Instance.new("Folder"); rem.Name="Remotes"; rem.Parent=RS end
	local ev=rem:FindFirstChild("SpecialTruckEvent")
	if not ev then ev=Instance.new("RemoteEvent"); ev.Name="SpecialTruckEvent"; ev.Parent=rem end
	local cfg=RS:FindFirstChild("SpecialEvent")
	if not cfg then cfg=Instance.new("Configuration"); cfg.Name="SpecialEvent"; cfg.Parent=RS end
	return ev, cfg
end
local function publishEvent(active, endTH)
	local _,cfg=ensureEventIO(); cfg:SetAttribute("Active", active and true or false)
	if endTH then cfg:SetAttribute("EndTH", endTH) end
end
local function fireEvent(payload)
	local ev=ensureEventIO()
	for _,plr in ipairs(Players:GetPlayers()) do pcall(function() ev:FireClient(plr, payload) end) end
end
local function setTownDamage(crashed)
 local town=WS:FindFirstChild("TownCentre")
 local templates=game:GetService("ServerStorage"):FindFirstChild("TownCentreModels")
 local template=templates and templates:FindFirstChild(crashed and "Crashed" or "Normal")
 if not town or not template then return nil end
 local current=town:FindFirstChild("CivicBuilding")
 if current and current:GetAttribute("Crashed")==crashed then return current end
 local cf=current and current:GetPivot() or CFrame.new(SpecialConfig.TownCentre)
 local building=template:Clone()
 building.Name="CivicBuilding"
 building:PivotTo(cf)
 if current then current:Destroy() end
 building.Parent=town
 return building
end

local function groundY(position)
 local town=WS:FindFirstChild("TownCentre")
 local surfaces={}
 for _,p in {town and town:FindFirstChild("Plaza"), town and town:FindFirstChild("PlazaRing"), WS:FindFirstChild("Baseplate")} do
  if p then table.insert(surfaces,p) end
 end
 local rp=RaycastParams.new()
 rp.FilterType=Enum.RaycastFilterType.Include
 rp.FilterDescendantsInstances=surfaces
 local hit=WS:Raycast(position+Vector3.new(0,60,0),Vector3.new(0,-160,0),rp)
 return hit and hit.Position.Y or SpecialConfig.TownCentre.Y
end

local function scatterClear(position,parent)
 local params=OverlapParams.new()
 params.FilterType=Enum.RaycastFilterType.Include
 params.FilterDescendantsInstances={WS.TownCentre,parent}
 params.RespectCanCollide=true
 local cf=CFrame.new(position.X,groundY(position)+1.45,position.Z)
 return #WS:GetPartBoundsInBox(cf,Vector3.new(2.1,2.75,2.1),params)==0
end

local function buildDressing(C, parent)
 local building=setTownDamage(true)
 local markers=building and building:FindFirstChild("Markers")
 local truckMarker=markers and markers:FindFirstChild("GiftTruckRoot")
 local truckCF=truckMarker and truckMarker.CFrame or CFrame.new(C)*CFrame.new(10.8,0,21.65)*CFrame.Angles(0,math.rad(-6),0)
 truckCF+=Vector3.new(0,groundY(truckCF.Position)+.015-truckCF.Position.Y,0)
 local template=game:GetService("ServerStorage"):FindFirstChild("EventTruck")
 local truck
 if template then
  truck=template:Clone()
  truck.Name="CrashedTruck"
  truck:PivotTo(truckCF)
  truck.Parent=parent
 end
 local spill=truckCF.ZVector
 local truckMarkers=truck and truck:FindFirstChild("Markers")
 local spillMarker=truckMarkers and truckMarkers:FindFirstChild("GiftSpillOrigin")
 local mouth=(spillMarker and spillMarker.Position or truckCF:PointToWorldSpace(Vector3.new(0,2.52,9.35)))+spill*4
 local beam=Instance.new("Part")
 beam.Name="GiftBeam";beam.Anchored=true;beam.CanCollide=false;beam.CanQuery=false;beam.CanTouch=false
 beam.Material=Enum.Material.Neon;beam.Color=Color3.fromRGB(255,225,120);beam.Transparency=.62
 beam.Size=Vector3.new(7,400,7)
 beam.Position=Vector3.new(mouth.X,groundY(mouth)+200,mouth.Z)
 beam.Parent=parent
 for side=-1,1,2 do
  local centre=truckCF:PointToWorldSpace(Vector3.new(side*3.4,0,12))
  centre=Vector3.new(centre.X,groundY(centre)+.035,centre.Z)
  local skid=Instance.new("Part")
  skid.Name="Skid";skid.Anchored=true;skid.CanCollide=false;skid.CanQuery=false;skid.CanTouch=false
  skid.Size=Vector3.new(.8,.025,20);skid.Color=Color3.fromRGB(28,28,32)
  skid.Material=Enum.Material.SmoothPlastic;skid.Transparency=.25
  skid.CFrame=CFrame.lookAt(centre,centre-spill);skid.Parent=parent
 end
 return mouth,spill
end

function SpecialTruckService.despawnEvent()
	local wasActive = giftsFolder~=nil
	if wasActive then
		-- the Magic Carpet is per-event: consume it BEFORE clearing the event so clients re-fetch updated
		-- ownership (and the store shows it buyable again) the moment the gifts disappear.
		local BMS=require(script.Parent.BlackMarketService)
		for _,plr in ipairs(Players:GetPlayers()) do
			if BMS.owned(plr).carpet==true then BMS.consume(plr, "carpet") end
		end
	end
	if giftsFolder then giftsFolder:Destroy(); giftsFolder=nil end
	setTownDamage(false)
	for uid,list in pairs(carriedGifts) do
		for _,g in ipairs(list) do if g and g.Parent then PackageService.detachCarry(g);g:Destroy() end end
		carriedGifts[uid]={}
	end
	activeDay=nil
	if wasActive then publishEvent(false); fireEvent({phase="end"}) end
end
function SpecialTruckService.spawnEvent(day)
	if activeDay==day and giftsFolder then return end
	SpecialTruckService.despawnEvent()
	activeDay=day
	giftsFolder=Instance.new("Folder"); giftsFolder.Name="SpecialGifts"; giftsFolder.Parent=WS
	local C=SpecialConfig.TownCentre
	local n=packageCount(day)
	local rng=Random.new(day*1299709)
	local mouth,spill=buildDressing(C,giftsFolder)
 local perp=Vector3.new(-spill.Z,0,spill.X)
 local positions={}
 for i=1,n do
  local position
  for attempt=1,64 do
   local d=rng:NextNumber()
   local along=d*d*SpecialConfig.ScatterRadius
   local fan=(rng:NextNumber()-.5)*2*(2.5+d*15)
   local p=mouth+spill*along+perp*fan+Vector3.new(rng:NextNumber(-1,1),0,rng:NextNumber(-1,1))
   local clear=true
   for _,other in positions do
    if Vector3.new(p.X-other.X,0,p.Z-other.Z).Magnitude<2.3 then clear=false;break end
   end
   if clear and scatterClear(p,giftsFolder) then position=p;break end
  end
  if not position then
   local row=0
   repeat
    position=mouth+spill*(row*2.5+2)
    row+=1
    local clear=true
    for _,other in positions do
     if Vector3.new(position.X-other.X,0,position.Z-other.Z).Magnitude<2.3 then clear=false;break end
    end
   until clear and scatterClear(position,giftsFolder)
  end
  table.insert(positions,position)
  makeGift(i,Vector3.new(position.X,groundY(position),position.Z)).Parent=giftsFolder
 end
	local endTH = (forcedDay==day and forcedEndTH) or ((day-1)*24 + startHourForDay(day) + SpecialConfig.WindowHours)
	publishEvent(true, endTH)
	fireEvent({phase="start", count=n})
	announce("A special gift truck CRASHED at the town centre - "..n.." gifts scattered! Race there and grab them before they clear!")
end
function SpecialTruckService.isActive() return WS:FindFirstChild("SpecialGifts")~=nil end
function SpecialTruckService.giftsFolder() return giftsFolder end

local function update()
	local day=TimeService.getDay()
	local gt=RS:FindFirstChild("GameTime"); local hour=(gt and gt:GetAttribute("Hour")) or 0
	local th=(day-1)*24 + hour
	local forcedActive=(forcedDay==day) and forcedEndTH~=nil and (th < forcedEndTH)
	local isEventDay=forcedActive or appearsToday(day)
	local startH=startHourForDay(day)
	local inWindow=forcedActive or (hour >= startH and hour < startH + SpecialConfig.WindowHours)
	if isEventDay and inWindow then
		if activeDay~=day then SpecialTruckService.spawnEvent(day) end
	else
		if activeDay~=nil then SpecialTruckService.despawnEvent() end
	end
end

-- admin/test: force the event for the current global day (until day rolls over)
function SpecialTruckService.force()
	forcedDay=TimeService.getDay()
	local gt=RS:FindFirstChild("GameTime"); local hour=(gt and gt:GetAttribute("Hour")) or 0
	forcedEndTH=(forcedDay-1)*24 + hour + SpecialConfig.WindowHours
	SpecialTruckService.spawnEvent(forcedDay)
	return forcedDay
end

-- carry capacity (base 1) + black-market upgrades
function SpecialTruckService.getCarryCap(plr) return 1 + (carryExtra[plr.UserId] or 0) end
function SpecialTruckService.buyCarryUpgrade(plr)
	local cur=carryExtra[plr.UserId] or 0
	if cur>=4 then return {ok=false,msg="Max carry (5) reached"} end
	local cost=SpecialConfig.CarryUpgrades[cur+1]
	if not CurrencyService.Spend(plr,"Crypto",cost) then return {ok=false,msg="Need "..cost.." Crypto"} end
	carryExtra[plr.UserId]=cur+1
	pcall(function() CurrencyService.SaveNow(plr) end)
	return {ok=true, carry=1+carryExtra[plr.UserId], cost=cost}
end
function SpecialTruckService.getSavedCarry(plr) return carryExtra[plr.UserId] end
function SpecialTruckService.loadCarry(plr, n) if type(n)=="number" then carryExtra[plr.UserId]=math.clamp(math.floor(n),0,4) end end
function SpecialTruckService.clearPlayer(plr)
 SpecialTruckService.dropCarried(plr)
 carryExtra[plr.UserId]=nil
 carriedGifts[plr.UserId]=nil
end
-- drop a player's carried gifts back to the ground (used by the Bat) so they can be re-grabbed
function SpecialTruckService.dropCarried(plr)
 local list=carriedGifts[plr.UserId]
 carriedGifts[plr.UserId]={}
 if not list then return 0 end
 local char=plr.Character
 local hrp=char and char:FindFirstChild("HumanoidRootPart")
 local n=0
 for i,g in list do
  if not g.Parent or g:GetAttribute("Redeemed") then continue end
  if not giftsFolder or not giftsFolder.Parent then g:Destroy();continue end
  PackageService.detachCarry(g)
  local spot=hrp and hrp.CFrame:PointToWorldSpace(Vector3.new((i-1)*2.4-2.4,0,-4)) or g.Position
  local rp=RaycastParams.new()
  rp.FilterType=Enum.RaycastFilterType.Exclude
  rp.FilterDescendantsInstances=char and {char,giftsFolder} or {giftsFolder}
  rp.RespectCanCollide=true
  local hit=WS:Raycast(spot+Vector3.new(0,6,0),Vector3.new(0,-120,0),rp)
  local y=hit and hit.Position.Y or groundY(spot)
  g.Anchored=true;g.CanCollide=true;g.Massless=false
  g.AssemblyLinearVelocity=Vector3.zero;g.AssemblyAngularVelocity=Vector3.zero
  g.Parent=giftsFolder
  placeGift(g,CFrame.new(spot.X,y+g.Size.Y/2+.04,spot.Z))
  g:SetAttribute("Carried",nil);g:SetAttribute("ClaimedBy",nil)
  local prompt=g:FindFirstChild("GrabGift");if prompt then prompt.Enabled=true end
  n+=1
 end
 return n
end

local function grabGift(prompt,plr)
 if prompt.Name~="GrabGift" or not prompt.Enabled then return false end
 local gift=prompt.Parent
 if not gift or not gift:IsA("BasePart") or not giftsFolder or gift.Parent~=giftsFolder then return false end
 if not gift:GetAttribute("SpecialGift") or gift:GetAttribute("Carried") or gift:GetAttribute("Redeemed") then return false end
 local char=plr.Character
 local hrp=char and char:FindFirstChild("HumanoidRootPart")
 local hum=char and char:FindFirstChildOfClass("Humanoid")
 if not hrp or not hum or hum.Health<=0 or (plr:GetAttribute("SecDeadUntil") or 0)>os.time() then return false end
 if (hrp.Position-gift.Position).Magnitude>prompt.MaxActivationDistance+2 then return false end
 if not PackageService.Motion.visible(hrp.Position,gift.Position,{char},gift) then return false end
 local list=carriedGifts[plr.UserId] or {}
 carriedGifts[plr.UserId]=list
 if #list>=SpecialTruckService.getCarryCap(plr) then
  notifyOne(plr,"Your hands are full — take your gifts back to your warehouse.","error")
  return false
 end
 gift:SetAttribute("Carried",true);gift:SetAttribute("ClaimedBy",plr.UserId);prompt.Enabled=false
 PackageService.attachCarry(gift,char)
 table.insert(list,gift)
 return true
end

local function deliverGifts(plr)
 local uid=plr.UserId
 local list=carriedGifts[uid]
 if not list or #list==0 then return 0 end
 local plot=PlotService.forPlayer(plr)
 local char=plr.Character
 local hrp=char and char:FindFirstChild("HumanoidRootPart")
 local hum=char and char:FindFirstChildOfClass("Humanoid")
 if not plot or plot.owner~=plr or not plot.origin or not hrp or not hum or hum.Health<=0 then return 0 end
 local delta=hrp.Position-plot.origin
 if delta.X*delta.X+delta.Z*delta.Z>=45*45 or math.abs(delta.Y)>18 then return 0 end
 carriedGifts[uid]={}
 local n=0
 for _,gift in list do
  if gift.Parent~=char or gift:GetAttribute("ClaimedBy")~=uid or gift:GetAttribute("Redeemed") then continue end
  local index=gift:GetAttribute("RewardIdx")
  if type(index)~="number" or index%1~=0 or not SpecialConfig.Rewards[index] then gift:Destroy();continue end
  gift:SetAttribute("Redeemed",true)
  PackageService.detachCarry(gift)
  gift:Destroy()
  local ok,err=pcall(RewardService.giveByIndex,plr,index)
  if ok then n+=1 else warn("[SpecialTruckService] gift reward failed: "..tostring(err)) end
 end
 return n
end

SpecialTruckService.grabGift=grabGift
SpecialTruckService.deliverGifts=deliverGifts

function SpecialTruckService.Start()
 setTownDamage(false)
 ensureEventIO()
 update()
 TimeService.DayChanged.Event:Connect(update)
 task.spawn(function() while true do task.wait(5);update() end end)
 PromptService.PromptTriggered:Connect(grabGift)
 local function hookPlayer(plr)
  local function hookCharacter(char)
   local hum=char:WaitForChild("Humanoid",5)
   if hum then hum.Died:Connect(function() SpecialTruckService.dropCarried(plr) end) end
  end
  plr.CharacterAdded:Connect(hookCharacter)
  plr.CharacterRemoving:Connect(function() SpecialTruckService.dropCarried(plr) end)
  if plr.Character then task.spawn(hookCharacter,plr.Character) end
 end
 Players.PlayerAdded:Connect(hookPlayer)
 Players.PlayerRemoving:Connect(function(plr) SpecialTruckService.clearPlayer(plr) end)
 for _,plr in Players:GetPlayers() do hookPlayer(plr) end
 task.spawn(function()
  while true do
   task.wait(.5)
   for _,plr in Players:GetPlayers() do deliverGifts(plr) end
  end
 end)
 print("[SpecialTruckService] started")
end
return SpecialTruckService

