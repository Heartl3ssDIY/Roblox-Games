-- FurnitureService: per-office desk laptop + office chairs, upgradeable & swappable from the Customise
-- tab. Every player starts with Laptop 1 + Office Chair 1. Tier 2 = $50k, Tier 3 = $100k (cash), bought
-- in order (1->2->3). Owned tiers can be freely re-selected. The selected laptop sits on the desk
-- (replacing the old PC); the selected chair is the player's desk chair; the investor chair is always
-- Office Chair 1. Placement is per-plot, so it lands on every warehouse.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local ServerStorage=game:GetService("ServerStorage")
local PlotService=require(script.Parent.PlotService)
local CurrencyService=require(script.Parent.CurrencyService)

local FurnitureService={}
local owned={}   -- [uid]={laptop=N, chair=N}  highest tier owned (>=1)
local sel={}     -- [uid]={laptop=N, chair=N}  selected tier
local placed={}  -- [uid]={laptop=Model, chair=Model, inv=Model}

local PRICES={[2]=50000, [3]=100000}
local MAXTIER=3

-- per-tier model + orientation + RELATIVE scale factor (these imported models have a non-1 base scale,
-- so we always scale by GetScale()*factor, never an absolute ScaleTo).
-- `front` = per-model yaw correction so the model's visual front (laptop screen / chair seat-opening)
-- aligns to its anchor's Front face. The OWNER aims each anchor; these just fix model-authoring offsets.
local LAPTOP={ [1]={m="Laptop1",front=180,f=1.0}, [2]={m="Laptop2",front=180,f=1.4}, [3]={m="Laptop3",front=180,f=0.5} }
local CHAIR ={ [1]={m="Chair1",front=0,f=1.0},   [2]={m="Chair2",front=0,f=1.85}, [3]={m="Chair3",front=180,f=0.6} }
local INV_CHAIR={m="Chair1",front=0,f=1.0}   -- investor seat: always Office Chair 1

local function models() return ServerStorage:FindFirstChild("FurnitureModels") end
local function notify(plr,text,kind) local r=RS:FindFirstChild("Remotes"); local n=r and r:FindFirstChild("Notify"); if n then n:FireClient(plr,{text=text,kind=kind or "info"}) end end

local function defaults(uid)
	if not owned[uid] then owned[uid]={laptop=1, chair=1} end
	if not sel[uid] then sel[uid]={laptop=1, chair=1} end
end

-- place a model so its bounding-box bottom-centre sits at `target`, rotated `yaw` deg about Y, scaled
-- by `factor` relative to its current displayed size.
local function placeModel(model, target, yaw, factor)
	pcall(function() model:ScaleTo(model:GetScale()*factor) end)
	model:PivotTo(CFrame.new(target)*CFrame.Angles(0, math.rad(yaw), 0))
	local cf,sz=model:GetBoundingBox()
	model:PivotTo(model:GetPivot()+(target-(cf.Position-Vector3.new(0,sz.Y/2,0))))
end

local function prep(model)
	for _,d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored=true; d.CanCollide=false; d.CanQuery=false end
	end
end

-- make a chair sittable: reuse a built-in Seat if present, else add an invisible sit pad at the
-- cushion, oriented to the chair's facing so the sitter faces the desk.
local function ensureSeat(chair, target, faceDir)
	-- Built-in seats on some imported chairs are authored facing the chair's BACK, so the sitter ends up
	-- looking away from the desk. We make any built-in seat visual-only and drive sitting with our own
	-- invisible pad, oriented to face the desk (faceDir).
	for _,d in ipairs(chair:GetDescendants()) do if d:IsA("Seat") and d.Name~="SitPad" then d.Disabled=true end end
	-- measure the chair BEFORE adding our pad, else a freshly-created pad at the origin skews the centre
	local cf=chair:GetBoundingBox()
	local f=Vector3.new(faceDir.X,0,faceDir.Z); if f.Magnitude<1e-3 then f=Vector3.new(0,0,-1) end; f=f.Unit
	local cushion=chair:FindFirstChildWhichIsA("Seat",true)
 local pos=cushion and Vector3.new(cushion.Position.X,cushion.Position.Y+cushion.Size.Y/2-.1,cushion.Position.Z) or Vector3.new(cf.Position.X,target.Y+1.7,cf.Position.Z)
	local seat=chair:FindFirstChild("SitPad")
	if not seat then
		seat=Instance.new("Seat"); seat.Name="SitPad"
		seat.Size=Vector3.new(1.8,0.4,1.8); seat.Transparency=1
		seat.CFrame=CFrame.lookAt(pos, pos+f); seat.Parent=chair
	end
	seat.Anchored=true; seat.CanCollide=true; seat.Disabled=false
	seat.CFrame=CFrame.lookAt(pos, pos+f)
end

local function deskOf(plr)
	local plot=PlotService.forPlayer(plr); if not plot then return nil end
	local folder=plot.LoadBays and plot.LoadBays.Parent; if not folder then return nil end
	local desk; for _,d in ipairs(folder:GetDescendants()) do if d.Name=="DeskTop" then desk=d break end end
	return folder, desk
end

-- Place a model at an anchor part: scale, align its visual front to the anchor's Front face (+frontFix),
-- then rest its bounding-box bottom-centre on the anchor's position. The OWNER moves/rotates the anchor
-- in Studio to set exactly where + which way each piece sits.
local function placeAtAnchor(model, anchorPart, frontFix, factor)
	pcall(function() model:ScaleTo(model:GetScale()*factor) end)
	local pos=anchorPart.Position
	model:PivotTo(CFrame.new(pos)*anchorPart.CFrame.Rotation*CFrame.Angles(0, math.rad(frontFix or 0), 0))
	local cf,sz=model:GetBoundingBox()
	model:PivotTo(model:GetPivot()+(pos - Vector3.new(cf.Position.X, cf.Position.Y - sz.Y/2, cf.Position.Z)))
end

function FurnitureService.placeFor(plr)
	local uid=plr.UserId; defaults(uid)
	local folder, desk=deskOf(plr); if not folder then return end
	for _,nm in ipairs({"DeskLaptop","PlayerChair","InvestorChair"}) do local o=folder:FindFirstChild(nm); if o then o:Destroy() end end
	local mdl=models(); if not mdl then return end
	local lapA=folder:FindFirstChild("LaptopAnchor")
	local pcA=folder:FindFirstChild("PlayerChairAnchor")
	local invA=folder:FindFirstChild("InvestorChairAnchor")
	for _,a in ipairs({lapA,pcA,invA}) do if a then a.Transparency=1; a.CanQuery=false; a.CanCollide=false end end  -- markers hidden in-game; stay visible in Edit for positioning
	-- laptop -> LaptopAnchor (screen faces the anchor's Front)
	local lc=LAPTOP[sel[uid].laptop] or LAPTOP[1]
	local src=mdl:FindFirstChild(lc.m)
	if src and lapA then local lap=src:Clone(); lap.Name="DeskLaptop"; prep(lap); placeAtAnchor(lap, lapA, lc.front, lc.f); lap.Parent=folder end
	-- player's chair -> PlayerChairAnchor (sitter faces the anchor's Front)
	local cc=CHAIR[sel[uid].chair] or CHAIR[1]
	local cs=mdl:FindFirstChild(cc.m)
	if cs and pcA then local chair=cs:Clone(); chair.Name="PlayerChair"; prep(chair); placeAtAnchor(chair, pcA, cc.front, cc.f); ensureSeat(chair, pcA.Position, pcA.CFrame.LookVector); chair.Parent=folder end
	-- investor chair (always Office Chair 1) -> InvestorChairAnchor
	local is=mdl:FindFirstChild(INV_CHAIR.m)
	if is and invA then local inv=is:Clone(); inv.Name="InvestorChair"; prep(inv); placeAtAnchor(inv, invA, INV_CHAIR.front, INV_CHAIR.f); ensureSeat(inv, invA.Position, invA.CFrame.LookVector); inv.Parent=folder end
 placed[uid]=true
end

-- ---- public API ---------------------------------------------------------
function FurnitureService.get(plr) defaults(plr.UserId); return {owned=owned[plr.UserId], sel=sel[plr.UserId], prices=PRICES, max=MAXTIER} end

function FurnitureService.buy(plr, kind)
	local uid=plr.UserId; defaults(uid)
	if kind~="laptop" and kind~="chair" then return {ok=false,msg="bad kind"} end
	local nxt=(owned[uid][kind] or 1)+1
	if nxt>MAXTIER then return {ok=false,msg="Already at the top tier"} end
	local price=PRICES[nxt] or 0
	if not CurrencyService.Spend(plr,"Cash",price) then return {ok=false,msg="You need $"..price.."."} end
	owned[uid][kind]=nxt; sel[uid][kind]=nxt
	pcall(function() FurnitureService.placeFor(plr) end)
	notify(plr, (kind=="laptop" and "Laptop " or "Office Chair ")..nxt.." unlocked!","success")
	return {ok=true, owned=owned[uid], sel=sel[uid]}
end

function FurnitureService.select(plr, kind, tier)
	local uid=plr.UserId; defaults(uid)
	if kind~="laptop" and kind~="chair" then return {ok=false,msg="bad kind"} end
	tier=tonumber(tier)
	if not tier or tier~=tier or tier%1~=0 or tier<1 or tier>(owned[uid][kind] or 1) then return {ok=false,msg="You don't own that yet."} end
	sel[uid][kind]=tier
	pcall(function() FurnitureService.placeFor(plr) end)
	return {ok=true, owned=owned[uid], sel=sel[uid]}
end

-- ---- persistence (Econ save) -------------------------------------------
function FurnitureService.getSaved(plr) defaults(plr.UserId); return {owned=owned[plr.UserId], sel=sel[plr.UserId]} end
function FurnitureService.loadSaved(plr, data)
	local uid=plr.UserId; defaults(uid)
	if type(data)=="table" then
		if type(data.owned)=="table" then
			owned[uid].laptop=math.clamp(tonumber(data.owned.laptop) or 1,1,MAXTIER)
			owned[uid].chair=math.clamp(tonumber(data.owned.chair) or 1,1,MAXTIER)
		end
		if type(data.sel)=="table" then
			sel[uid].laptop=math.clamp(tonumber(data.sel.laptop) or 1,1,owned[uid].laptop)
			sel[uid].chair=math.clamp(tonumber(data.sel.chair) or 1,1,owned[uid].chair)
		end
	end
end
function FurnitureService.clear(plr) owned[plr.UserId]=nil; sel[plr.UserId]=nil; placed[plr.UserId]=nil end

function FurnitureService.Start()
	local r=RS:WaitForChild("Remotes")
	local rf=r:FindFirstChild("Furniture") or Instance.new("RemoteFunction"); rf.Name="Furniture"; rf.Parent=r
	rf.OnServerInvoke=function(plr, req)
		if type(req)~="table" then return {ok=false,msg="Invalid request"} end
		if req.action=="get" then return FurnitureService.get(plr) end
		if req.action=="buy" then return FurnitureService.buy(plr, req.kind) end
		if req.action=="select" then return FurnitureService.select(plr, req.kind, req.tier) end
		return {ok=false,msg="unknown action"}
	end
	task.spawn(function()
		while true do
			for _,plr in ipairs(Players:GetPlayers()) do
				local folder=select(1, deskOf(plr))
				if folder and (not placed[plr.UserId] or not folder:FindFirstChild("DeskLaptop") or not folder:FindFirstChild("PlayerChair") or not folder:FindFirstChild("InvestorChair")) then pcall(function() FurnitureService.placeFor(plr) end) end
			end
			task.wait(3)
		end
	end)
	Players.PlayerRemoving:Connect(function(plr) FurnitureService.clear(plr) end)
	print("[FurnitureService] started")
end
return FurnitureService
