-- ManualLoadService: a player grabs staged parcels and carries them to a bay. In their OWN warehouse
-- this works any time. At NIGHT, every warehouse is open and parcels in OTHER players' warehouses are
-- STEALABLE -- a thief can carry up to MAX_CARRY and fence them at their own bays for the value.
local Players=game:GetService("Players"); local RunService=game:GetService("RunService"); local RS=game:GetService("ReplicatedStorage")
local ProximityPromptService=game:GetService("ProximityPromptService")
local TruckService=require(script.Parent.TruckService)
local PlotService=require(script.Parent.PlotService)
local AccessService=require(script.Parent.AccessService)
local Remotes=RS:WaitForChild("Remotes")
local ManualLoadService={}
local carrying={}        -- [uid] = { {pkg=, stolen=bool}, ... }
local MAX_CARRY=10
local OWN_CARRY=1   -- you can only hand-carry this many of your OWN parcels at once; stealing uses MAX_CARRY

local function hrpOf(plr) local c=plr.Character; local h=c and c:FindFirstChild("HumanoidRootPart"); return h end
local function listOf(uid) local l=carrying[uid]; if not l then l={}; carrying[uid]=l end return l end
local function notify(plr,text,kind) Remotes.Notify:FireClient(plr,{text=text,kind=kind or "info"}) end

-- Each STOLEN parcel a player carries slows them 3% (10 -> 30% slower) so they choose how greedy to be
-- and victims get a chance to catch them. Skips frozen players (their WalkSpeed stays 0).
local function applyCarrySpeed(plr, stolen)
	local char=plr.Character; local hum=char and char:FindFirstChildOfClass("Humanoid"); if not hum then return end
	local hrp=char:FindFirstChild("HumanoidRootPart")
	if (hrp and hrp.Anchored) or ((plr:GetAttribute("FrozenUntil") or 0) > os.time()) then return end
	local base = ((plr:GetAttribute("SpeedBoostUntil") or 0) > os.time()) and 32 or 16
	hum.WalkSpeed = base * (1 - 0.03*math.min(stolen,10))
end

local function restageAll(plr)
	local l=carrying[plr.UserId]; if not l then return end
	local plot=PlotService.forPlayer(plr)
	for _,e in ipairs(l) do if e.pkg and e.pkg.Parent then pcall(function() TruckService.restage(e.pkg, plot) end) end end
	carrying[plr.UserId]=nil
	applyCarrySpeed(plr, 0)   -- restore full speed once they're not carrying anything
end
-- public: drop everything a player is carrying (used by the WASTED death handler)
function ManualLoadService.dropCarried(plr) restageAll(plr) end
-- public: how many parcels a player is carrying (CCTV freeze ray reads this)
function ManualLoadService.carryCount(plr) local l=carrying[plr.UserId]; return l and #l or 0 end

local function grab(plr, pkg)
	local hrp=hrpOf(plr); if not hrp then return end
	-- downed (WASTED) players can't grab
	local okOut,SC=pcall(function() return require(script.Parent.SecurityCombatService) end)
	if okOut and SC and SC.isOut(plr) then return end
	if not (pkg and pkg:IsA("BasePart") and pkg:GetAttribute("Company")) then return end
	local l=listOf(plr.UserId)
	local pkgPlot=PlotService.plotOfInstance(pkg)
	local mine=PlotService.forPlayer(plr)
	local stolen = (pkgPlot~=nil) and (pkgPlot~=mine) and (pkgPlot.owner~=plr)
	if stolen and not AccessService.isNight() then
		notify(plr,"You can only take parcels from other warehouses at NIGHT.","error"); return
	end
	-- carry caps: STOLEN parcels up to MAX_CARRY (the stealing limit); your OWN only OWN_CARRY at a time
	local ownN,stolenN=0,0
	for _,e in ipairs(l) do if e.stolen then stolenN+=1 else ownN+=1 end end
	if stolen then
		if stolenN>=MAX_CARRY then notify(plr,"Your hands are full ("..MAX_CARRY..") -- fence them first (F to drop)","error"); return end
	else
		if ownN>=OWN_CARRY then notify(plr,"You can carry "..OWN_CARRY.." of your own parcels at a time -- drop it at a bay (F).","error"); return end
	end
	local taken=TruckService.takeSpecificStaged(pkg, pkgPlot or mine)
	if not taken then return end
	taken.Parent=plr.Character
	for _,d in ipairs(taken:GetDescendants()) do if d:IsA("BasePart") then d.Anchored=false; d.CanCollide=false; d.Massless=true end end
	taken.Anchored=false; taken.CanCollide=false; taken.Massless=true
	table.insert(l, {pkg=taken, stolen=stolen})
	if stolen then
		notify(plr,"Stole a "..(taken:GetAttribute("Rarity") or "").." parcel ("..#l.."/"..MAX_CARRY..") -- fence it at your own bays!","success")
		local victim=pkgPlot.owner
		if victim and victim.Parent then notify(victim, (plr.DisplayName or "Someone").." is stealing parcels from your warehouse!","error") end
	else
		notify(plr,"Grabbed a "..(taken:GetAttribute("Rarity") or "").." parcel -- take it to that bay","info")
	end
end

function ManualLoadService.Start()
	Remotes.ManualAction.OnServerEvent:Connect(function(plr)
		if carrying[plr.UserId] and #carrying[plr.UserId]>0 then restageAll(plr); notify(plr,"Dropped your parcels","info") end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt, plr)
		if prompt.Name~="GrabParcel" then return end
		grab(plr, prompt.Parent)
	end)
	RunService.Heartbeat:Connect(function()
		for uid,l in pairs(carrying) do
			local plr=Players:GetPlayerByUserId(uid); local hrp=plr and hrpOf(plr)
			if not hrp then carrying[uid]=nil
			else
				local mine=PlotService.forPlayer(plr)
				local keep={}
				for i,e in ipairs(l) do
					local pkg=e.pkg
					if pkg and pkg.Parent then
						-- stacked low in front of the body
						local col=((i-1)%2)-0.5; local rowi=math.floor((i-1)/2)
						pkg.CFrame=hrp.CFrame*CFrame.new(col*1.3, -0.4 + rowi*1.0, -(1.4+pkg.Size.Z*0.4))
						-- target bay: own parcels -> their company bay; stolen -> any of your bays with room
						local bay=mine and TruckService.getLoadBay(pkg:GetAttribute("Company"), mine)
						if (not bay or bay.leaving or (bay.count or 0)>=(bay.capacity or 0)) and e.stolen and mine then
							for _,b in ipairs(mine.loadBays or {}) do if not b.leaving and (b.count or 0)<(b.capacity or 0) then bay=b break end end
						end
						if bay and not bay.leaving and (bay.count or 0)<(bay.capacity or 0) and (bay.pad.Position-hrp.Position).Magnitude<12 then
							bay:load(pkg)
							notify(plr,(e.stolen and "Fenced stolen goods! +$" or "Loaded! +$")..(pkg:GetAttribute("Value") or 0),"success")
						else
							table.insert(keep, e)
						end
					end
				end
				carrying[uid]=(#keep>0) and keep or nil
				local stolenN=0; for _,e in ipairs(keep) do if e.stolen then stolenN+=1 end end
				applyCarrySpeed(plr, stolenN)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(plr) restageAll(plr) end)
	print("[ManualLoadService] started (night stealing enabled)")
end
return ManualLoadService

