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

local GIFTCOLORS={Color3.fromRGB(235,70,95),Color3.fromRGB(80,200,255),Color3.fromRGB(120,90,235),Color3.fromRGB(90,210,120),Color3.fromRGB(255,150,60),Color3.fromRGB(245,90,180)}
local RIBBON=Color3.fromRGB(252,228,150)   -- soft gold ribbon
local function makeGift(i, pos)
	local sz=1.3+math.random()*0.55   -- hand-held scale: visible on the ground but small enough to carry in-hand
	local g=Instance.new("Part"); g.Name="Gift_"..i; g.Anchored=true; g.Size=Vector3.new(sz,sz,sz); g.Position=pos+Vector3.new(0,sz/2+.04,0)
	g.Color=GIFTCOLORS[((i-1)%#GIFTCOLORS)+1]; g.Material=Enum.Material.Foil; g.Reflectance=0.06
	g:SetAttribute("SpecialGift",true)
	g:SetAttribute("RewardIdx", RewardService.rollIndex())   -- each package independently rolls its own reward at spawn
	-- premium present: glossy gold ribbon cross + a bow (knot + two loops). Weld AFTER positioning so the
	-- pieces keep their offset when the gift is unanchored to be carried.
	local function piece(size, cf, shape, color, mat)
		local b=Instance.new("Part"); b.Anchored=true; b.CanCollide=false; b.Size=size
		b.Color=color or RIBBON; b.Material=mat or Enum.Material.Metal; if shape then b.Shape=shape end
		b.CFrame=cf; b.Parent=g
		local w=Instance.new("WeldConstraint"); w.Part0=g; w.Part1=b; w.Parent=g
		return b
	end
	piece(Vector3.new(sz+0.06, sz+0.06, sz*0.2), g.CFrame)   -- ribbon band (front-back)
	piece(Vector3.new(sz*0.2, sz+0.06, sz+0.06), g.CFrame)   -- ribbon band (left-right)
	piece(Vector3.new(sz*0.34, sz*0.34, sz*0.34), g.CFrame*CFrame.new(0, sz*0.5+0.12, 0), Enum.PartType.Ball)   -- centre knot
	for s=-1,1,2 do
		piece(Vector3.new(sz*0.5, sz*0.46, sz*0.16), g.CFrame*CFrame.new(s*sz*0.26, sz*0.5+0.18, 0)*CFrame.Angles(0,0,math.rad(s*40)), Enum.PartType.Ball)   -- bow loop
	end
	-- coloured glow + faint sparkle so the scatter reads premium from afar
	local light=Instance.new("PointLight"); light.Color=g.Color; light.Range=6; light.Brightness=1.1; light.Parent=g
	local spk=Instance.new("ParticleEmitter"); spk.Texture="rbxasset://textures/particles/sparkles_main.dds"
	spk.Rate=4; spk.Lifetime=NumberRange.new(0.7,1.3); spk.Speed=NumberRange.new(0.3,0.9); spk.Size=NumberSequence.new(0.28)
	spk.LightEmission=1; spk.Color=ColorSequence.new(RIBBON); spk.Rotation=NumberRange.new(0,360); spk.Parent=g
	local prompt=Instance.new("ProximityPrompt"); prompt.Name="GrabGift"; prompt.ActionText="Grab"; prompt.ObjectText="Special Gift"
	prompt.KeyboardKeyCode=Enum.KeyCode.E; prompt.HoldDuration=0; prompt.MaxActivationDistance=8; prompt.RequiresLineOfSight=false; prompt.Parent=g
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
		for _,g in ipairs(list) do if g and g.Parent then g:Destroy() end end
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
function SpecialTruckService.clearPlayer(plr) carryExtra[plr.UserId]=nil; carriedGifts[plr.UserId]=nil end
-- drop a player's carried gifts back to the ground (used by the Bat) so they can be re-grabbed
function SpecialTruckService.dropCarried(plr)
	local list=carriedGifts[plr.UserId]; if not list or #list==0 then return 0 end
	local char=plr.Character; local hrp=char and char:FindFirstChild("HumanoidRootPart")
	local n=0
	for _,g in ipairs(list) do
		if g and g.Parent then
			local w=g:FindFirstChild("CarryWeld"); if w then w:Destroy() end
			g.Parent=(giftsFolder or workspace); g.CanCollide=true
			if hrp then
				-- drop it on the FLOOR under the player (raycast down) rather than leaving it floating at head height
				local spot=hrp.Position+Vector3.new(math.random(-5,5),0,math.random(-5,5))
				local rp=RaycastParams.new(); rp.FilterType=Enum.RaycastFilterType.Exclude; rp.FilterDescendantsInstances={char, giftsFolder, g}
				local hit=workspace:Raycast(spot+Vector3.new(0,6,0), Vector3.new(0,-60,0), rp)
				local groundY=(hit and hit.Position.Y) or (hrp.Position.Y-2.5)
				g.Anchored=true; g.Position=Vector3.new(spot.X, groundY+1.6, spot.Z)
			else
				g.Anchored=true
			end
			g:SetAttribute("Carried", nil)
			local p=g:FindFirstChild("GrabGift"); if p then p.Enabled=true end
			n+=1
		end
	end
	carriedGifts[plr.UserId]={}
	return n
end

function SpecialTruckService.Start()
	setTownDamage(false)
	ensureEventIO()
	update()
	TimeService.DayChanged.Event:Connect(update)
	task.spawn(function() while true do task.wait(5); update() end end)
	-- grab a scattered gift -> carry it (up to your cap), stacked above your head
	PromptService.PromptTriggered:Connect(function(prompt, plr)
		if prompt.Name~="GrabGift" then return end
		local gift=prompt.Parent
		if not (gift and gift:GetAttribute("SpecialGift")) or gift:GetAttribute("Carried") then return end
		local list=carriedGifts[plr.UserId] or {}; carriedGifts[plr.UserId]=list
		if #list >= SpecialTruckService.getCarryCap(plr) then
			notifyOne(plr, "You can carry "..SpecialTruckService.getCarryCap(plr).." at a time - deliver them to your warehouse first.", "error"); return
		end
		local char=plr.Character; local hrp=char and char:FindFirstChild("HumanoidRootPart")
		if not hrp then return end
		-- carry in the HAND (R15 RightHand / R6 Right Arm), not stacked above the head
		local hand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm") or hrp
		gift:SetAttribute("Carried", true); prompt.Enabled=false
		for _,d in ipairs(gift:GetDescendants()) do if d:IsA("BasePart") then d.CanCollide=false; d.Massless=true; d.Anchored=false end end
		gift.Anchored=false; gift.CanCollide=false; gift.Massless=true
		local idx=#list
		local weld=Instance.new("Motor6D"); weld.Name="CarryWeld"; weld.Part0=hand; weld.Part1=gift
		-- rest it in the palm; extra parcels cradle up the forearm so a full carry doesn't clip into one spot
		weld.C0=CFrame.new(0, 0.45 + idx*0.6, -0.35)   -- sits at the hand (R15 RightHand -Y points up the arm, so +Y lowers it to the palm)
		weld.Parent=gift
		gift.Parent=char
		table.insert(list, gift)
	end)
	-- deliver carried gifts once the player returns to their own warehouse -> open each for a reward
	task.spawn(function()
		while true do
			task.wait(0.5)
			for uid,list in pairs(carriedGifts) do
				if #list>0 then
					local plr=Players:GetPlayerByUserId(uid)
					local plot=plr and PlotService.forPlayer(plr)
					local char=plr and plr.Character; local hrp=char and char:FindFirstChild("HumanoidRootPart")
					if plot and hrp and plot.origin then
						local dx=hrp.Position.X-plot.origin.X; local dz=hrp.Position.Z-plot.origin.Z
						if (dx*dx+dz*dz) < (45*45) then
							for _,gift in ipairs(list) do local idx=gift and gift:GetAttribute("RewardIdx"); if gift and gift.Parent then gift:Destroy() end; RewardService.giveByIndex(plr, idx) end
							carriedGifts[uid]={}
						end
					end
				end
			end
		end
	end)
	print("[SpecialTruckService] started")
end
return SpecialTruckService
