--!strict
-- PackReveal: shared pack-opening animation. Given a PackOpening result, plays
-- a reveal overlay: the pack shakes then bursts, then reward cards flip/fade in
-- one by one (new units highlighted, XP-card dupes shown per unit).
-- Used by both the shop (instant gem-buys) and banked daily packs.
--
--   PackReveal.play(playerGui, result, onDone)
--
-- `result` is a PackOpening result table. `onDone` is called when the player
-- dismisses the reveal.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UnitData = require(ReplicatedStorage:WaitForChild("UnitData"))
local T = require(ReplicatedStorage:WaitForChild("UITheme"))

local C = {
	bg     = Color3.fromRGB(14, 9, 28),
	panel  = Color3.fromRGB(30, 19, 56),
	card   = Color3.fromRGB(40, 26, 74),
	border = Color3.fromRGB(150, 95, 255),
	gold   = Color3.fromRGB(255, 210, 80),
	txt    = Color3.fromRGB(235, 222, 255),
	sub    = Color3.fromRGB(160, 138, 200),
	newU   = Color3.fromRGB(255, 180, 90),   -- new-unit highlight
	common = Color3.fromRGB(170, 178, 190),
	rare   = Color3.fromRGB(90, 170, 255),
	epic   = Color3.fromRGB(190, 120, 255),
	legend = Color3.fromRGB(255, 180, 70),
}
local RARITY_COLOR = { Common=C.common, Rare=C.rare, Epic=C.epic, Legendary=C.legend }

local function mk(cls, props, parent)
	local o = Instance.new(cls)
	for k,v in pairs(props) do o[k]=v end
	o.Parent = parent
	return o
end
local function corner(p,r) Instance.new("UICorner", p).CornerRadius = UDim.new(0, r or 12) end
local function stroke(p,col,th) local s=Instance.new("UIStroke",p); s.Color=col; s.Thickness=th or 2; return s end

local PACK_LABEL = { bronze="Bronze Pack", silver="Silver Pack", gold="Gold Pack", diamond="Diamond Pack" }
local PACK_TINT = {
	bronze = Color3.fromRGB(190, 130, 70),
	silver = Color3.fromRGB(190, 200, 215),
	gold   = Color3.fromRGB(255, 205, 90),
	diamond= Color3.fromRGB(130, 225, 255),
}

local PackReveal = {}
local gui = nil

local function ensureGui(playerGui)
	if gui then return end
	gui = mk("ScreenGui", { Name="PackRevealGui", ResetOnSpawn=false, IgnoreGuiInset=true,
		Enabled=false, DisplayOrder=50, ZIndexBehavior=Enum.ZIndexBehavior.Sibling }, playerGui)
end

-- Build a single reward card frame (returned hidden/scaled for the flip-in).
local function makeRewardCard(parent, info)
	-- info = { kind="unit"|"xp", unitId, name, rarity, count }
	local rarColor = T.rarityColor(info.rarity)
	local rarDark = T.rarityDark(info.rarity)
	local card = mk("Frame", { Size=UDim2.new(0, 120, 0, 150), BackgroundColor3=rarDark,
		BorderSizePixel=0, ZIndex=52 }, parent)
	corner(card, 14)
	T.outline(card, info.kind=="unit" and 4 or 3, info.kind=="unit" and C.newU or T.C.outline)
	T.gradient(card, rarColor, rarDark, 90)
	T.shadow(card, 14, 0.4)

	-- glossy top band
	local band = mk("Frame", { Size=UDim2.new(1,0,0,40), BackgroundColor3=rarColor, BorderSizePixel=0, ZIndex=53 }, card)
	corner(band, 14)
	mk("Frame", { Size=UDim2.new(1,0,0,20), Position=UDim2.new(0,0,0,20), BackgroundColor3=rarColor, BorderSizePixel=0, ZIndex=53 }, card)

	-- unit name (outlined)
	T.label({ Size=UDim2.new(1,-10,0,30), Position=UDim2.new(0,5,0,6), Text=info.name,
		TextColor3=Color3.fromRGB(255,255,255), Font=Enum.Font.FredokaOne, TextSize=15,
		TextWrapped=true, ZIndex=54 }, card)

	-- rarity label
	T.label({ Size=UDim2.new(1,-10,0,16), Position=UDim2.new(0,5,0,44), Text=string.upper(info.rarity or ""),
		TextColor3=Color3.fromRGB(255,255,255), Font=Enum.Font.GothamBold, TextSize=11, ZIndex=54 }, card)

	-- center icon / amount
	if info.kind == "unit" then
		T.label({ Size=UDim2.new(1,0,0,46), Position=UDim2.new(0,0,0,72), Text="\xE2\x9C\xA8",
			Font=Enum.Font.FredokaOne, TextSize=36, ZIndex=54 }, card)
		T.label({ Size=UDim2.new(1,0,0,22), Position=UDim2.new(0,0,1,-28), Text="NEW UNIT!",
			TextColor3=C.newU, Font=Enum.Font.FredokaOne, TextSize=15, ZIndex=54 }, card)
	else
		T.label({ Size=UDim2.new(1,0,0,48), Position=UDim2.new(0,0,0,70), Text="+"..info.count,
			Font=Enum.Font.FredokaOne, TextSize=34, ZIndex=54 }, card)
		T.label({ Size=UDim2.new(1,0,0,20), Position=UDim2.new(0,0,1,-26), Text="XP CARDS",
			TextColor3=Color3.fromRGB(245,240,255), Font=Enum.Font.GothamBold, TextSize=11, ZIndex=54 }, card)
	end
	return card
end

-- Build the ordered list of reward-card infos from a result.
local function buildRewardInfos(result)
	local infos = {}
	-- new units first (highlighted)
	for _, id in ipairs(result.newUnits) do
		local u = UnitData.get(id)
		if u then table.insert(infos, { kind="unit", unitId=id, name=u.name, rarity=u.rarity }) end
	end
	-- then XP-card piles per unit (sorted by rarity for nice grouping)
	local rarOrder = { Common=1, Rare=2, Epic=3, Legendary=4 }
	local piles = {}
	for unitId, count in pairs(result.cards) do
		local u = UnitData.get(unitId)
		if u then table.insert(piles, { kind="xp", unitId=unitId, name=u.name, rarity=u.rarity, count=count }) end
	end
	table.sort(piles, function(a,b)
		local ra, rb = rarOrder[a.rarity] or 9, rarOrder[b.rarity] or 9
		if ra ~= rb then return ra < rb end
		return a.name < b.name
	end)
	for _, p in ipairs(piles) do table.insert(infos, p) end
	return infos
end

function PackReveal.play(playerGui, result, onDone)
	ensureGui(playerGui)
	for _, ch in ipairs(gui:GetChildren()) do ch:Destroy() end
	gui.Enabled = true

	local packId = result and result.packId or "bronze"
	local tint = PACK_TINT[packId] or C.gold

	-- dim background
	local dim = mk("Frame", { Size=UDim2.new(1,0,1,0), BackgroundColor3=Color3.fromRGB(0,0,0),
		BackgroundTransparency=1, BorderSizePixel=0, ZIndex=50 }, gui)
	TweenService:Create(dim, TweenInfo.new(0.3), { BackgroundTransparency=0.25 }):Play()

	-- the pack (a tinted rounded box) that shakes then bursts
	local pack = mk("Frame", { Size=UDim2.new(0,160,0,200), AnchorPoint=Vector2.new(0.5,0.5),
		Position=UDim2.new(0.5,0,0.5,0), BackgroundColor3=tint, BorderSizePixel=0, ZIndex=51 }, gui)
	corner(pack, 18); T.outline(pack, 4); T.gradient(pack, Color3.new(math.min(1,tint.R*1.15),math.min(1,tint.G*1.15),math.min(1,tint.B*1.15)), tint, 90); T.shadow(pack, 24, 0.4)
	mk("TextLabel", { Size=UDim2.new(1,0,1,0), BackgroundTransparency=1, Text="\xF0\x9F\x8E\x81",
		TextSize=78, ZIndex=52 }, pack)
	local packLabel = T.label({ Size=UDim2.new(0,340,0,32), AnchorPoint=Vector2.new(0.5,0),
		Position=UDim2.new(0.5,0,0.5,116), Text=PACK_LABEL[packId] or "Pack",
		TextColor3=C.gold, Font=Enum.Font.FredokaOne, TextSize=24, ZIndex=52 }, gui)
	mk("TextLabel", { Name="Tap", Size=UDim2.new(0,300,0,20), AnchorPoint=Vector2.new(0.5,0),
		Position=UDim2.new(0.5,0,0.5,150), BackgroundTransparency=1, Text="tap to open",
		TextColor3=C.sub, Font=Enum.Font.GothamMedium, TextSize=14, ZIndex=52 }, gui)

	local opened = false
	local function burst()
		if opened then return end
		opened = true
		-- shake
		local shake = TweenService:Create(pack, TweenInfo.new(0.06, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 4, true),
			{ Rotation = 8 })
		shake:Play()
		shake.Completed:Wait()
		-- burst: scale up + fade
		pack.Rotation = 0
		local up = TweenService:Create(pack, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.In),
			{ Size=UDim2.new(0,40,0,50), BackgroundTransparency=1 })
		up:Play()
		TweenService:Create(packLabel, TweenInfo.new(0.18), { TextTransparency=1 }):Play()
		local tap = gui:FindFirstChild("Tap")
		if tap then TweenService:Create(tap, TweenInfo.new(0.1), { TextTransparency=1 }):Play() end
		up.Completed:Wait()
		pack:Destroy(); packLabel:Destroy()

		-- results header (outlined)
		T.label({ Size=UDim2.new(1,0,0,44), Position=UDim2.new(0,0,0.1,0), Text="YOU GOT:",
			TextColor3=C.gold, Font=Enum.Font.FredokaOne, TextSize=32, ZIndex=52 }, gui)

		-- scrolling card grid
		local holder = mk("ScrollingFrame", { Size=UDim2.new(0,560,0,360), AnchorPoint=Vector2.new(0.5,0.5),
			Position=UDim2.new(0.5,0,0.5,10), BackgroundTransparency=1, BorderSizePixel=0,
			ScrollBarThickness=6, ScrollBarImageColor3=C.border, CanvasSize=UDim2.new(0,0,0,0),
			AutomaticCanvasSize=Enum.AutomaticSize.Y, ZIndex=52 }, gui)
		local grid = mk("UIGridLayout", { CellSize=UDim2.new(0,120,0,150), CellPadding=UDim2.new(0,12,0,12),
			HorizontalAlignment=Enum.HorizontalAlignment.Center, SortOrder=Enum.SortOrder.LayoutOrder }, holder)

		local infos = buildRewardInfos(result)
		if #infos == 0 then
			mk("TextLabel", { Size=UDim2.new(1,0,0,40), BackgroundTransparency=1, Text="(nothing this time)",
				TextColor3=C.sub, Font=Enum.Font.GothamMedium, TextSize=16, ZIndex=53 }, holder)
		end
		-- flip/fade the cards in one by one
		for i, info in ipairs(infos) do
			local card = makeRewardCard(holder, info)
			card.LayoutOrder = i
			card.Size = UDim2.new(0,120,0,0)   -- start flat (flip)
			TweenService:Create(card, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Size=UDim2.new(0,120,0,150) }):Play()
			task.wait(0.12)
		end

		-- continue button (chunky beveled)
		local cont = T.button(gui, UDim2.new(0,240,0,52), UDim2.new(0.5,0,1,-34),
			T.C.green, T.C.greenDk, { text="CONTINUE", textSize=20, anchor=Vector2.new(0.5,1), zindex=53 })
		cont.Activated:Connect(function()
			gui.Enabled = false
			for _, ch in ipairs(gui:GetChildren()) do ch:Destroy() end
			if onDone then onDone() end
		end)
	end

	-- tap anywhere to open
	local tapBtn = mk("TextButton", { Size=UDim2.new(1,0,1,0), BackgroundTransparency=1, Text="",
		ZIndex=49 }, gui)
	tapBtn.Activated:Connect(function() task.spawn(burst) end)
	-- auto-open after a moment if they don't tap
	task.delay(1.4, function() if not opened then task.spawn(burst) end end)
end

return PackReveal
