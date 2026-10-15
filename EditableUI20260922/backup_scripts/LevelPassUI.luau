--!strict
-- LevelPassUI: the account-level "pass" screen. Shows the level track with
-- per-level rewards and claim buttons (claimable once you've reached the level).
-- Rewards wait here until claimed (not auto-granted).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerData = require(ReplicatedStorage:WaitForChild("PlayerData"))

local C = {
	bg     = Color3.fromRGB(18, 12, 36),
	panel  = Color3.fromRGB(32, 20, 62),
	border = Color3.fromRGB(148, 88, 255),
	btnBg  = Color3.fromRGB(50, 28, 98),
	btnHov = Color3.fromRGB(78, 48, 145),
	btnTxt = Color3.fromRGB(230, 210, 255),
	sub    = Color3.fromRGB(155, 130, 195),
	gold   = Color3.fromRGB(255, 210, 80),
	gem    = Color3.fromRGB(110, 220, 255),
	chip   = Color3.fromRGB(190, 130, 255),
	green  = Color3.fromRGB(90, 215, 130),
	cellBg = Color3.fromRGB(40, 24, 78),
	close  = Color3.fromRGB(200, 70, 95),
	locked = Color3.fromRGB(70, 60, 95),
}
local function mk(cls, props, parent)
	local o = Instance.new(cls)
	for k,v in pairs(props) do o[k]=v end
	o.Parent = parent
	return o
end
local function corner(p,r) Instance.new("UICorner", p).CornerRadius = UDim.new(0, r or 12) end
local function stroke(p,col,th) local s=Instance.new("UIStroke",p); s.Color=col; s.Thickness=th or 2; s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; return s end

-- Build a short reward summary string from a reward table.
local function rewardText(rw)
	local parts = {}
	if rw.coins then table.insert(parts, "\xF0\x9F\xAA\x99 "..rw.coins) end
	if rw.gems then table.insert(parts, "\xF0\x9F\x92\x8E "..rw.gems) end
	if rw.masteryChips then table.insert(parts, "\xE2\x97\x88 "..rw.masteryChips) end
	return table.concat(parts, "   ")
end

local LevelPassUI = {}
local gui = nil
local rebuildTrack  -- forward decl

local function buildGui(playerGui)
	gui = mk("ScreenGui", { Name="LevelPassGui", ResetOnSpawn=false, IgnoreGuiInset=true,
		Enabled=false, ZIndexBehavior=Enum.ZIndexBehavior.Sibling }, playerGui)
	local dim = mk("TextButton", { Size=UDim2.new(1,0,1,0), BackgroundColor3=Color3.fromRGB(0,0,0),
		BackgroundTransparency=0.45, BorderSizePixel=0, Text="", AutoButtonColor=false }, gui)
	dim.Activated:Connect(function() gui.Enabled = false end)

	local panel = mk("Frame", { Name="Panel", Size=UDim2.new(0, 480, 0, 540),
		AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.new(0.5,0,0.5,0),
		BackgroundColor3=C.bg, BorderSizePixel=0 }, gui)
	corner(panel, 22); stroke(panel, C.border, 3)

	-- header: title + current level + xp bar
	mk("TextLabel", { Size=UDim2.new(1,-120,0,40), Position=UDim2.new(0,22,0,16), BackgroundTransparency=1,
		Text="\xF0\x9F\x8E\x96\xEF\xB8\x8F  Level Pass", TextColor3=C.gold, Font=Enum.Font.GothamBold,
		TextSize=24, TextXAlignment=Enum.TextXAlignment.Left }, panel)
	local closeBtn = mk("TextButton", { Size=UDim2.new(0,36,0,36), Position=UDim2.new(1,-48,0,16),
		BackgroundColor3=C.close, BorderSizePixel=0, Text="\xE2\x9C\x95", TextColor3=Color3.fromRGB(255,255,255),
		Font=Enum.Font.GothamBold, TextSize=16 }, panel)
	corner(closeBtn, 18)
	closeBtn.Activated:Connect(function() gui.Enabled = false end)

	local lvlLabel = mk("TextLabel", { Name="LvlLabel", Size=UDim2.new(1,-44,0,20), Position=UDim2.new(0,22,0,60),
		BackgroundTransparency=1, Text="Level 1", TextColor3=C.btnTxt, Font=Enum.Font.GothamBold,
		TextSize=15, TextXAlignment=Enum.TextXAlignment.Left }, panel)
	local xpTrack = mk("Frame", { Size=UDim2.new(1,-44,0,14), Position=UDim2.new(0,22,0,84),
		BackgroundColor3=Color3.fromRGB(20,12,42), BorderSizePixel=0 }, panel)
	corner(xpTrack, 7)
	local xpFill = mk("Frame", { Name="XpFill", Size=UDim2.new(0,0,1,0), BackgroundColor3=C.gem, BorderSizePixel=0 }, xpTrack)
	corner(xpFill, 7)
	local xpText = mk("TextLabel", { Name="XpText", Size=UDim2.new(1,0,1,0), BackgroundTransparency=1,
		Text="", TextColor3=Color3.fromRGB(255,255,255), Font=Enum.Font.GothamBold, TextSize=10 }, xpTrack)

	-- scrolling level track
	local track = mk("ScrollingFrame", { Name="Track", Size=UDim2.new(1,-32,1,-128),
		Position=UDim2.new(0,16,0,112), BackgroundTransparency=1, BorderSizePixel=0,
		ScrollBarThickness=6, ScrollBarImageColor3=C.border, CanvasSize=UDim2.new(0,0,0,0),
		AutomaticCanvasSize=Enum.AutomaticSize.Y }, panel)
	mk("UIListLayout", { Padding=UDim.new(0,8), SortOrder=Enum.SortOrder.LayoutOrder }, track)
	mk("UIPadding", { PaddingRight=UDim.new(0,8) }, track)

	LevelPassUI._refs = { panel=panel, lvlLabel=lvlLabel, xpFill=xpFill, xpText=xpText, track=track }
end

-- (re)build the level rows. Shows a window of levels around the current one.
rebuildTrack = function()
	local refs = LevelPassUI._refs
	if not refs then return end
	local track = refs.track
	for _, ch in ipairs(track:GetChildren()) do if ch:IsA("Frame") then ch:Destroy() end end

	local curLvl = PlayerData.level()
	refs.lvlLabel.Text = "Level "..curLvl
	local frac = math.clamp(PlayerData.xp() / PlayerData.xpNeeded(), 0, 1)
	refs.xpFill.Size = UDim2.new(frac, 0, 1, 0)
	refs.xpText.Text = PlayerData.xp().." / "..PlayerData.xpNeeded().." XP"

	-- show levels 2..(curLvl+8) so upcoming rewards are visible
	local maxShow = math.max(curLvl + 8, 10)
	for lvl = 2, maxShow do
		local stateStr = PlayerData.levelRewardState(lvl)
		local reward = PlayerData.levelReward(lvl)
		local row = mk("Frame", { Name="Lvl"..lvl, Size=UDim2.new(1,0,0,52),
			BackgroundColor3=C.cellBg, BorderSizePixel=0, LayoutOrder=lvl }, track)
		corner(row, 12)
		stroke(row, stateStr=="claimable" and C.gold or C.border, stateStr=="claimable" and 2 or 1)

		-- level badge
		local badge = mk("Frame", { Size=UDim2.new(0,42,0,42), Position=UDim2.new(0,6,0.5,-21),
			BackgroundColor3=(stateStr=="locked") and C.locked or C.btnBg, BorderSizePixel=0 }, row)
		corner(badge, 21)
		mk("TextLabel", { Size=UDim2.new(1,0,1,0), BackgroundTransparency=1, Text=tostring(lvl),
			TextColor3=(stateStr=="locked") and C.sub or C.gold, Font=Enum.Font.GothamBold, TextSize=18 }, badge)

		-- reward text
		mk("TextLabel", { Size=UDim2.new(0,200,1,0), Position=UDim2.new(0,58,0,0), BackgroundTransparency=1,
			Text=rewardText(reward), TextColor3=C.btnTxt, Font=Enum.Font.GothamBold, TextSize=15,
			TextXAlignment=Enum.TextXAlignment.Left }, row)

		-- claim button / state pill
		local claimBtn = mk("TextButton", { Size=UDim2.new(0,96,0,34), AnchorPoint=Vector2.new(1,0.5),
			Position=UDim2.new(1,-10,0.5,0), BorderSizePixel=0, AutoButtonColor=false,
			Font=Enum.Font.GothamBold, TextSize=14 }, row)
		corner(claimBtn, 10)
		if stateStr == "claimable" then
			claimBtn.Text = "Claim"; claimBtn.BackgroundColor3 = C.green; claimBtn.TextColor3 = Color3.fromRGB(15,50,25)
			claimBtn.Activated:Connect(function()
				if PlayerData.claimLevelReward(lvl) then rebuildTrack() end
			end)
		elseif stateStr == "claimed" then
			claimBtn.Text = "\xE2\x9C\x93 Claimed"; claimBtn.BackgroundColor3 = C.cellBg; claimBtn.TextColor3 = C.sub
			claimBtn.Active = false
		else
			claimBtn.Text = "\xF0\x9F\x94\x92"; claimBtn.BackgroundColor3 = C.cellBg; claimBtn.TextColor3 = C.sub
			claimBtn.Active = false
		end
	end
end

function LevelPassUI.open(playerGui)
	if not gui then buildGui(playerGui) end
	rebuildTrack()
	gui.Enabled = true
end
function LevelPassUI.close()
	if gui then gui.Enabled = false end
end
function LevelPassUI.isOpen()
	return gui ~= nil and gui.Enabled
end

return LevelPassUI
