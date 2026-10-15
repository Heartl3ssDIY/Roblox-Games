--!strict
-- ShopUI: builds the main shop (menu tab) into a given content frame.
-- Sections: Offers, Gems, Coins, Chips, Daily Deals. Tab bar jumps to each.
-- Called by LobbyMenuClient: ShopUI.build(contentFrame).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ShopConfig = require(ReplicatedStorage:WaitForChild("ShopConfig"))
local PlayerData = require(ReplicatedStorage:WaitForChild("PlayerData"))
local UnitData = require(ReplicatedStorage:WaitForChild("UnitData"))

local ShopUI = {}

-- Palette (matches lobby)
local C = {
	bg      = Color3.fromRGB(18, 12, 36),
	panel   = Color3.fromRGB(32, 20, 62),
	border  = Color3.fromRGB(148, 88, 255),
	btnBg   = Color3.fromRGB(50, 28, 98),
	btnHov  = Color3.fromRGB(78, 48, 145),
	btnTxt  = Color3.fromRGB(230, 210, 255),
	sub     = Color3.fromRGB(155, 130, 195),
	gold    = Color3.fromRGB(255, 210, 80),
	gem     = Color3.fromRGB(110, 220, 255),
	chip    = Color3.fromRGB(190, 130, 255),
	cellBg  = Color3.fromRGB(40, 24, 78),
	robux   = Color3.fromRGB(90, 215, 130),
}

local function mk(class, props, parent)
	local o = Instance.new(class)
	for k,v in pairs(props) do o[k]=v end
	o.Parent = parent
	return o
end
local function corner(p,r) Instance.new("UICorner", p).CornerRadius = UDim.new(0, r or 12) end
local function stroke(p,col,th)
	local s = Instance.new("UIStroke", p); s.Color=col; s.Thickness=th or 2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; return s
end

ShopUI._C = C
ShopUI._mk = mk
ShopUI._corner = corner
ShopUI._stroke = stroke

-- Section definitions in tab order.
local SECTIONS = {
	{ id = "offers", label = "Offers" },
	{ id = "gems",   label = "Gems" },
	{ id = "coins",  label = "Coins" },
	{ id = "chips",  label = "Chips" },
	{ id = "daily",  label = "Daily Deals" },
}

-- Build the shop into `content` (a Frame). Safe to call once; rebuilds if called again.
function ShopUI.build(content)
	-- clear any prior shop build
	for _, ch in ipairs(content:GetChildren()) do
		if ch.Name == "ShopRoot" then ch:Destroy() end
	end

	local root = mk("Frame", {
		Name = "ShopRoot", Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1,
	}, content)

	-- ── Tab bar (jump to section) ──
	local tabBar = mk("Frame", {
		Name = "TabBar", Size = UDim2.new(1,0,0,40), Position = UDim2.new(0,0,0,0),
		BackgroundTransparency = 1,
	}, root)
	mk("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0,8),
	}, tabBar)

	-- ── Scrolling body that holds all sections stacked ──
	local body = mk("ScrollingFrame", {
		Name = "Body", Size = UDim2.new(1,0,1,-50), Position = UDim2.new(0,0,0,50),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.border, CanvasSize = UDim2.new(0,0,0,0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, root)
	mk("UIListLayout", { Padding = UDim.new(0,16), SortOrder = Enum.SortOrder.LayoutOrder }, body)
	mk("UIPadding", { PaddingRight = UDim.new(0,10), PaddingBottom = UDim.new(0,10) }, body)

	local sectionFrames = {}

	-- create a titled section container
	local function makeSection(def, order)
		local sec = mk("Frame", {
			Name = "Sec_"..def.id, Size = UDim2.new(1,0,0,0),
			AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order,
		}, body)
		mk("UIListLayout", { Padding = UDim.new(0,10), SortOrder = Enum.SortOrder.LayoutOrder }, sec)
		mk("TextLabel", {
			Name = "Title", Size = UDim2.new(1,0,0,28), BackgroundTransparency = 1,
			Text = def.label, TextColor3 = C.gold, Font = Enum.Font.GothamBold,
			TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 0,
		}, sec)
		sectionFrames[def.id] = sec
		return sec
	end

	-- tab buttons jump-scroll to their section
	for i, def in ipairs(SECTIONS) do
		local tab = mk("TextButton", {
			Name = "Tab_"..def.id, Size = UDim2.new(0, 120, 1, 0),
			BackgroundColor3 = C.panel, BorderSizePixel = 0, AutoButtonColor = false,
			Text = def.label, TextColor3 = C.btnTxt, Font = Enum.Font.GothamBold,
			TextSize = 14, LayoutOrder = i,
		}, tabBar)
		corner(tab, 12); stroke(tab, C.border, 1)
		tab.MouseEnter:Connect(function() tab.BackgroundColor3 = C.btnHov end)
		tab.MouseLeave:Connect(function() tab.BackgroundColor3 = C.panel end)
		tab.Activated:Connect(function()
			local sec = sectionFrames[def.id]
			if sec then
				body.CanvasPosition = Vector2.new(0, math.max(0, sec.AbsolutePosition.Y - body.AbsolutePosition.Y + body.CanvasPosition.Y - 6))
			end
		end)
	end

	-- ── OFFERS section (empty for now) ──
	local offers = makeSection(SECTIONS[1], 1)
	mk("TextLabel", {
		Name = "Empty", Size = UDim2.new(1,0,0,60), BackgroundColor3 = C.cellBg,
		BorderSizePixel = 0, Text = "No offers right now \xE2\x80\x94 check back later!",
		TextColor3 = C.sub, Font = Enum.Font.GothamMedium, TextSize = 15, LayoutOrder = 1,
	}, offers)
	corner(offers:FindFirstChild("Empty"), 12)

	-- ── GEMS section ──
	ShopUI._buildGems(makeSection(SECTIONS[2], 2))

	-- ── COINS section ──
	ShopUI._buildCoins(makeSection(SECTIONS[3], 3))

	-- ── CHIPS section ──
	ShopUI._buildChips(makeSection(SECTIONS[4], 4))

	-- ── DAILY DEALS section ──
	ShopUI._buildDaily(makeSection(SECTIONS[5], 5))

	ShopUI._sectionFrames = sectionFrames
	ShopUI._body = body
	return root
end

-- Format a countdown like 23h 14m or 9m 12s.
local function fmtTime(sec)
	sec = math.floor(sec)
	local h = math.floor(sec / 3600)
	local m = math.floor((sec % 3600) / 60)
	local s = sec % 60
	if h > 0 then return string.format("%dh %dm", h, m) end
	if m > 0 then return string.format("%dm %ds", m, s) end
	return string.format("%ds", s)
end

-- A purchasable row: icon/amount on the left, a buy button on the right.
-- spec = { name, amount, cost, currency, daily, id }
-- onBuy(spec, button) handles the purchase; returns true on success.
function ShopUI._itemRow(parent, order, spec, accentColor, onBuy)
	local row = mk("Frame", {
		Name = "Row_"..(spec.id or spec.name), Size = UDim2.new(1,0,0,58),
		BackgroundColor3 = C.cellBg, BorderSizePixel = 0, LayoutOrder = order,
	}, parent)
	corner(row, 12); stroke(row, C.border, 1)

	-- name + amount label
	mk("TextLabel", {
		Name = "Name", Size = UDim2.new(0.55,-12,1,0), Position = UDim2.new(0,14,0,0),
		BackgroundTransparency = 1, Text = spec.name, TextColor3 = C.btnTxt,
		Font = Enum.Font.GothamBold, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left,
	}, row)

	-- buy button (right)
	local buy = mk("TextButton", {
		Name = "Buy", Size = UDim2.new(0, 130, 0, 40), Position = UDim2.new(1,-144,0.5,-20),
		BackgroundColor3 = C.btnBg, BorderSizePixel = 0, AutoButtonColor = false,
		Text = "", Font = Enum.Font.GothamBold, TextSize = 15,
	}, row)
	corner(buy, 12); stroke(buy, accentColor or C.border, 1)

	local function setBuyLabel()
		if spec.currency == "robux" then
			buy.Text = "\xF0\x9F\x92\xB0 "..spec.cost
			buy.TextColor3 = C.robux
		elseif spec.currency == "gems" then
			buy.Text = "\xF0\x9F\x92\x8E "..spec.cost
			buy.TextColor3 = C.gem
		elseif spec.currency == "coins" then
			buy.Text = "\xF0\x9F\xAA\x99 "..spec.cost
			buy.TextColor3 = C.gold
		elseif spec.currency == "free" then
			if ShopConfig.canClaim(spec.id) then
				buy.Text = "CLAIM"; buy.TextColor3 = C.robux
			else
				buy.Text = fmtTime(ShopConfig.secondsUntilClaim(spec.id))
				buy.TextColor3 = C.sub
			end
		end
	end
	setBuyLabel()

	buy.MouseEnter:Connect(function() buy.BackgroundColor3 = C.btnHov end)
	buy.MouseLeave:Connect(function() buy.BackgroundColor3 = C.btnBg end)
	buy.Activated:Connect(function()
		onBuy(spec, buy, setBuyLabel)
	end)

	-- live-refresh free-claim timers every second
	if spec.currency == "free" then
		task.spawn(function()
			while row.Parent do
				setBuyLabel()
				task.wait(1)
			end
		end)
	end
	return row, buy, setBuyLabel
end

-- Build the gems section content.
function ShopUI._buildGems(sec)
	for order, spec in ipairs(ShopConfig.gemBundles) do
		ShopUI._itemRow(sec, order, spec, C.gem, function(s, buy, refresh)
			if s.currency == "free" then
				if ShopConfig.canClaim(s.id) then
					PlayerData.addGems(s.amount)
					ShopConfig.markClaimed(s.id)
					refresh()
				end
			elseif s.currency == "robux" then
				-- stub: real Robux product prompt comes later
				print("[Shop] (stub) buy "..s.amount.." gems for "..s.cost.." Robux")
			end
		end)
	end
end

-- Build the coins section content.
function ShopUI._buildCoins(sec)
	for order, spec in ipairs(ShopConfig.coinBundles) do
		ShopUI._itemRow(sec, order, spec, C.gold, function(s, buy, refresh)
			if s.currency == "free" then
				if ShopConfig.canClaim(s.id) then
					PlayerData.addCoins(s.amount)
					ShopConfig.markClaimed(s.id)
					refresh()
				end
			elseif s.currency == "robux" then
				-- daily 1500-coin Robux pack: stub for now (also has a daily reset)
				if s.daily and not ShopConfig.canClaim(s.id) then return end
				print("[Shop] (stub) buy "..s.amount.." coins for "..s.cost.." Robux")
				-- when real Robux purchase succeeds later, mark daily claimed + grant.
			elseif s.currency == "gems" then
				-- real purchase: spend gems, grant coins
				if PlayerData.spendGems(s.cost) then
					PlayerData.addCoins(s.amount)
				else
					-- not enough gems: flash the button red briefly
					local orig = buy.BackgroundColor3
					buy.BackgroundColor3 = Color3.fromRGB(170,50,50)
					task.delay(0.5, function() buy.BackgroundColor3 = orig end)
				end
			end
		end)
	end
end

-- Build the mastery chips section content.
function ShopUI._buildChips(sec)
	for order, spec in ipairs(ShopConfig.chipBundles) do
		ShopUI._itemRow(sec, order, spec, C.chip, function(s, buy, refresh)
			if s.currency == "robux" then
				-- 5-chip daily Robux pack: stub (daily reset)
				if s.daily and not ShopConfig.canClaim(s.id) then return end
				print("[Shop] (stub) buy "..s.amount.." chips for "..s.cost.." Robux")
			elseif s.currency == "gems" then
				-- real purchase: spend gems, grant mastery chips
				if PlayerData.spendGems(s.cost) then
					PlayerData.addMasteryChips(s.amount)
				else
					local orig = buy.BackgroundColor3
					buy.BackgroundColor3 = Color3.fromRGB(170,50,50)
					task.delay(0.5, function() buy.BackgroundColor3 = orig end)
				end
			end
		end)
	end
end

-- Rarity weights for random unit selection (rarer = lower weight).
-- Tunable later; only "Common" exists for now so this picks evenly.
local RARITY_WEIGHT = { Common = 100, Rare = 30, Epic = 10, Legendary = 3 }
local XP_PER_CARD = 25   -- flat XP per card for now; rarity-scaling later

-- Pick a random owned unit id, weighted so rarer units are less likely.
local function pickWeightedUnit()
	local all = UnitData.all()
	local pool, total = {}, 0
	for id, u in pairs(all) do
		local w = RARITY_WEIGHT[u.rarity] or 50
		total += w
		table.insert(pool, { id = id, w = w })
	end
	if total == 0 then return nil end
	local r = math.random() * total
	local acc = 0
	for _, e in ipairs(pool) do
		acc += e.w
		if r <= acc then return e.id end
	end
	return pool[#pool].id
end

-- Build the daily deals section content.
function ShopUI._buildDaily(sec)
	for order, spec in ipairs(ShopConfig.dailyDeals) do
		ShopUI._itemRow(sec, order, spec, C.gold, function(s, buy, refresh)
			-- All daily deals respect the daily reset.
			if s.daily and not ShopConfig.canClaim(s.id) then return end

			if s.currency == "robux" then
				-- 25 gems OR random XP card, both Robux: stub (would mark claimed on success)
				if s.giveGems then
					print("[Shop] (stub) buy "..s.giveGems.." gems for "..s.cost.." Robux")
				elseif s.randomCard then
					print("[Shop] (stub) buy random XP card for "..s.cost.." Robux")
				end
			elseif s.currency == "coins" then
				-- 4 random units + XP cards for coins: REAL purchase.
				if PlayerData.spendCoins(s.cost) then
					local granted = {}
					for _ = 1, 4 do
						local uid = pickWeightedUnit()
						if uid then
							PlayerData.addUnitXp(uid, XP_PER_CARD)
							table.insert(granted, uid)
						end
					end
					ShopConfig.markClaimed(s.id)
					refresh()
					print("[Shop] 4-unit XP bundle granted to: "..table.concat(granted, ", "))
				else
					local orig = buy.BackgroundColor3
					buy.BackgroundColor3 = Color3.fromRGB(170,50,50)
					task.delay(0.5, function() buy.BackgroundColor3 = orig end)
				end
			end
		end)
	end
end

return ShopUI