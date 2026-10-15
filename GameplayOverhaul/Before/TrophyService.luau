-- TrophyService: per-player achievement trophies, shown in a display case in the player's office.
-- award(plr,key) adds a trophy, places it on the next shelf slot, persists it, and fires an unlock
-- popup. The case's frame colour and glass tint are per-player customisable.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local ServerStorage=game:GetService("ServerStorage")
local PlotService=require(script.Parent.PlotService)

local TrophyService={}
local earned={}    -- [uid] = { key, key, ... } in award order
local style={}     -- [uid] = {frame=Color3, glass=Color3, glassT=number}
local cases={}     -- [uid] = case Model
local PRIMARY_DESK=Vector3.new(78,3,11)
local CASE_PRIMARY=CFrame.new(71,0,1)*CFrame.Angles(0,math.pi,0)   -- against the SOUTH wall (z=-2), glass facing +Z into the room; shifted left of the desk
local CASE_SCALE=0.8        -- shrink so the case clears the office ceiling (~11.5 studs) instead of poking through the roof
local TROPHY_SCALE=0.55
local MAX=15

local function models() return ServerStorage:FindFirstChild("TrophyModels") end
local function caseTemplate() return ServerStorage:FindFirstChild("TrophyCase") end
local function notify(plr,text,kind) local r=RS:FindFirstChild("Remotes"); local n=r and r:FindFirstChild("Notify"); if n then n:FireClient(plr,{text=text,kind=kind or "success"}) end end
local function nameOf(key) local f=models(); local m=f and f:FindFirstChild(key); return (m and m:GetAttribute("DisplayName")) or key end

local function defaultStyle() return {frame=Color3.fromRGB(74,48,30), glass=Color3.fromRGB(150,205,235), glassT=0.6} end
local function getStyle(uid) if not style[uid] then style[uid]=defaultStyle() end return style[uid] end

local function applyStyle(caseModel, st)
	for _,d in ipairs(caseModel:GetDescendants()) do
		if d:IsA("BasePart") then
			local tag=d:GetAttribute("TrophyPart")
			if tag=="frame" then d.Color=st.frame
			elseif tag=="glass" then d.Color=st.glass; d.Transparency=st.glassT end
		end
	end
end

local function placeTrophy(caseModel, key, slotIdx)
	local tmpl=models() and models():FindFirstChild(key); if not tmpl then return end
	local slot=caseModel:FindFirstChild("Slot"..slotIdx); if not slot then return end
	local old=caseModel:FindFirstChild("T_"..slotIdx); if old then old:Destroy() end
	local t=tmpl:Clone(); t.Name="T_"..slotIdx
	for _,d in ipairs(t:GetDescendants()) do if d:IsA("BasePart") then d.Anchored=true; d.CanCollide=false; d.CanQuery=false end end
	pcall(function() t:ScaleTo(TROPHY_SCALE) end)
	local _,sz=t:GetBoundingBox()
	t:PivotTo(slot.CFrame * CFrame.new(0, sz.Y/2 - 0.1, 0))
	t.Parent=caseModel
end

local function ensureCase(plr)
	local plot=PlotService.forPlayer(plr); if not plot then return end
	local folder=plot.LoadBays and plot.LoadBays.Parent; if not folder then return end
	local existing=folder:FindFirstChild("TrophyCase")
	if existing then cases[plr.UserId]=existing; return existing end
	local desk; for _,d in ipairs(folder:GetDescendants()) do if d.Name=="DeskTop" then desk=d break end end
	if not desk then return end
	local tmpl=caseTemplate(); if not tmpl then return end
	local c=tmpl:Clone(); c.Name="TrophyCase"; c:SetAttribute("LabelOwner", plr.UserId)
	local off=desk.Position - PRIMARY_DESK
	c:PivotTo(CASE_PRIMARY + off)
	pcall(function() c:ScaleTo(CASE_SCALE) end)   -- scales about the case's bottom pivot, so it stays grounded and shrinks below the ceiling
	for _,d in ipairs(c:GetDescendants()) do if d:IsA("BasePart") then d.Anchored=true end end
	c.Parent=folder
	cases[plr.UserId]=c
	applyStyle(c, getStyle(plr.UserId))
	for i,key in ipairs(earned[plr.UserId] or {}) do placeTrophy(c, key, i) end
	return c
end

-- ---- public API ---------------------------------------------------------
function TrophyService.award(plr, key)
	if not (models() and models():FindFirstChild(key)) then return {ok=false,msg="Unknown trophy"} end
	local list=earned[plr.UserId] or {}; earned[plr.UserId]=list
	for _,k in ipairs(list) do if k==key then return {ok=false,msg="Already earned"} end end
	if #list>=MAX then return {ok=false,msg="Trophy case is full"} end
	list[#list+1]=key
	local c=cases[plr.UserId] or ensureCase(plr)
	if c then placeTrophy(c, key, #list) end
	local nm=nameOf(key)
	local r=RS:FindFirstChild("Remotes"); local ev=r and r:FindFirstChild("TrophyUnlock")
	if ev then ev:FireClient(plr, {key=key, name=nm}) end
	notify(plr, "\u{1F3C6} Trophy unlocked: "..nm.."!", "success")
	return {ok=true, key=key, name=nm}
end

function TrophyService.setStyle(plr, frame, glass, glassT)
	local st=getStyle(plr.UserId)
	if typeof(frame)=="Color3" then st.frame=frame end
	if typeof(glass)=="Color3" then st.glass=glass end
	if type(glassT)=="number" then st.glassT=math.clamp(glassT,0,0.95) end
	local c=cases[plr.UserId]; if c then applyStyle(c, st) end
	return {ok=true}
end
function TrophyService.getEarned(plr) return earned[plr.UserId] or {} end

-- ---- persistence (Econ save) -------------------------------------------
local function packC(c) return {math.floor(c.R*255),math.floor(c.G*255),math.floor(c.B*255)} end
local function unpackC(t) return (type(t)=="table" and #t==3) and Color3.fromRGB(t[1],t[2],t[3]) or nil end
function TrophyService.getSaved(plr)
	local st=getStyle(plr.UserId)
	return {earned=earned[plr.UserId] or {}, frame=packC(st.frame), glass=packC(st.glass), glassT=st.glassT}
end
function TrophyService.loadSaved(plr, data)
	if type(data)~="table" then return end
	earned[plr.UserId]=(type(data.earned)=="table") and data.earned or {}
	local st=defaultStyle()
	st.frame=unpackC(data.frame) or st.frame; st.glass=unpackC(data.glass) or st.glass
	if type(data.glassT)=="number" then st.glassT=data.glassT end
	style[plr.UserId]=st
end
function TrophyService.clear(plr) earned[plr.UserId]=nil; style[plr.UserId]=nil; cases[plr.UserId]=nil end

function TrophyService.Start()
	local r=RS:WaitForChild("Remotes")
	if not r:FindFirstChild("TrophyUnlock") then local e=Instance.new("RemoteEvent"); e.Name="TrophyUnlock"; e.Parent=r end
	local rf=r:FindFirstChild("Trophy") or Instance.new("RemoteFunction"); rf.Name="Trophy"; rf.Parent=r
	rf.OnServerInvoke=function(plr, req)
		req=req or {}
		if req.action=="get" then
			local catalog={}; local f=models()
			if f then for _,m in ipairs(f:GetChildren()) do catalog[#catalog+1]={key=m.Name, name=m:GetAttribute("DisplayName") or m.Name} end end
			local st=getStyle(plr.UserId)
			return {ok=true, earned=earned[plr.UserId] or {}, catalog=catalog, frame=packC(st.frame), glass=packC(st.glass), glassT=st.glassT}
		end
		if req.action=="setStyle" then
			return TrophyService.setStyle(plr, unpackC(req.frame), unpackC(req.glass), req.glassT)
		end
		return {ok=false,msg="unknown action"}
	end
	task.spawn(function()
		while true do
			for _,plr in ipairs(Players:GetPlayers()) do pcall(function() ensureCase(plr) end) end
			task.wait(4)
		end
	end)
	Players.PlayerRemoving:Connect(function(plr) cases[plr.UserId]=nil end)
	print("[TrophyService] started")
end
return TrophyService

