-- GlobalLeaderboardService: cross-server Top-10 by Cash, shown on the town-centre board.
-- Writes each player's Cash to an OrderedDataStore periodically + on leave, reads the top page, and
-- fills the board rows (Workspace.TownCentre.Leaderboard.LB). Names are resolved + cached.
local DataStoreService=game:GetService("DataStoreService")
local Players=game:GetService("Players")
local orderedNW=DataStoreService:GetOrderedDataStore("GlobalNetWorth_v1")
local profileStore=DataStoreService:GetDataStore("GlobalProfile_v1")
local CRYPTO_RATE=3000

local GlobalLeaderboardService={}
local nameCache={}
local lvlCache={}

local function boardGui()
	local town=workspace:FindFirstChild("TownCentre")
	local board=town and town:FindFirstChild("Leaderboard")
	return board and board:FindFirstChild("LB")
end
local function nameFor(uid)
	if nameCache[uid] then return nameCache[uid] end
	local ok,name=pcall(function() return Players:GetNameFromUserIdAsync(uid) end)
	name=(ok and name) or ("User"..uid); nameCache[uid]=name; return name
end
local function abbrev(n)
	n=math.floor(n)
	if n>=1e9 then return string.format("%.1fB",n/1e9)
	elseif n>=1e6 then return string.format("%.1fM",n/1e6)
	elseif n>=1e3 then return string.format("%.1fK",n/1e3) end
	return tostring(n)
end
local function levelFor(uid)
	if lvlCache[uid] then return lvlCache[uid] end
	local ok,prof=pcall(function() return profileStore:GetAsync("p_"..uid) end)
	local lvl=(ok and type(prof)=="table" and prof.lvl) or 1
	lvlCache[uid]=lvl; return lvl
end

-- net worth = Cash + Crypto * exchange rate; ranks the board and is shown alongside the level.
local function writeScore(plr)
	local cur=plr:FindFirstChild("Currency"); if not cur then return end
	local cash=cur:FindFirstChild("Cash") and cur.Cash.Value; if not cash then return end
	local crypto=(cur:FindFirstChild("Crypto") and cur.Crypto.Value) or 0
	local level=(cur:FindFirstChild("Level") and cur.Level.Value) or 1
	local nw=math.clamp(math.floor(cash + crypto*CRYPTO_RATE),0,1e15)
	lvlCache[plr.UserId]=level
	pcall(function() orderedNW:SetAsync(tostring(plr.UserId), nw) end)
	pcall(function() profileStore:SetAsync("p_"..plr.UserId, {lvl=level, nw=nw}) end)
end
GlobalLeaderboardService.writeScore=writeScore

local function refreshBoard()
	local gui=boardGui(); if not gui then return end
	local ok,pages=pcall(function() return orderedNW:GetSortedAsync(false, 10) end)
	if not ok or not pages then return end
	local top=pages:GetCurrentPage()
	for i=1,10 do
		local row=gui:FindFirstChild("Row"..i, true)
		if row then
			local val=row:FindFirstChild("Val")
			if not val then
				val=Instance.new("TextLabel"); val.Name="Val"; val.BackgroundTransparency=1
				val.AnchorPoint=Vector2.new(1,0.5); val.Position=UDim2.new(1,-4,0.5,0); val.Size=UDim2.new(0.45,0,1,0)
				val.Font=Enum.Font.GothamBold; val.TextScaled=true; val.TextXAlignment=Enum.TextXAlignment.Right
				val.TextColor3=Color3.fromRGB(120,235,150); val.Parent=row
			end
			local e=top[i]
			if e then
				local uid=tonumber(e.key)
				row.Text=("  #%d  %s   Lv %d"):format(i, nameFor(uid), levelFor(uid))
				val.Text="$"..abbrev(e.value)
			else
				row.Text="  #"..i.."  \u{2014}"; val.Text=""
			end
		end
	end
end
GlobalLeaderboardService.refreshBoard=refreshBoard

function GlobalLeaderboardService.Start()
	task.spawn(function() task.wait(4); refreshBoard() end)
	task.spawn(function()
		while true do
			task.wait(60)
			for _,plr in ipairs(Players:GetPlayers()) do writeScore(plr) end
			task.wait(2); refreshBoard()
		end
	end)
	Players.PlayerRemoving:Connect(writeScore)
	print("[GlobalLeaderboardService] started")
end

return GlobalLeaderboardService

