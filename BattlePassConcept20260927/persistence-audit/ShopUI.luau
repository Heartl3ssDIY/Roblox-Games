local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ShopConfig = require(ReplicatedStorage:WaitForChild("ShopConfig"))
local PlayerData = require(ReplicatedStorage:WaitForChild("PlayerData"))
local UnitData = require(ReplicatedStorage:WaitForChild("UnitData"))

local ShopUI = {}

local function unavailable()
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {Title="Shop", Text="Robux purchases are being configured.", Duration=4})
    end)
end

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

local SECTIONS = {
	{ id = "offers", label = "Offers" },
	{ id = "gems",   label = "Gems" },
	{ id = "coins",  label = "Coins" },
	{ id = "chips",  label = "Chips" },
	{ id = "daily",  label = "Daily Deals" },
}

function ShopUI.build(content)
    local root = content:WaitForChild("ShopRoot")
    if ShopUI._root == root then return root end
    ShopUI._root = root
    local body = root.Body
    local sections = {}
    for _, definition in ipairs(SECTIONS) do
        local section = body:WaitForChild("Sec_" .. definition.id)
        sections[definition.id] = section
        root.TabBar["Tab_" .. definition.id].Activated:Connect(function()
            body.CanvasPosition = Vector2.new(0, math.max(0, section.AbsolutePosition.Y - body.AbsolutePosition.Y + body.CanvasPosition.Y - 6))
        end)
    end
    ShopUI._buildGems(sections.gems)
    ShopUI._buildCoins(sections.coins)
    ShopUI._buildChips(sections.chips)
    ShopUI._buildDaily(sections.daily)
    ShopUI._sectionFrames = sections
    ShopUI._body = body
    return root
end

local function fmtTime(sec)
	sec = math.floor(sec)
	local h = math.floor(sec / 3600)
	local m = math.floor((sec % 3600) / 60)
	local s = sec % 60
	if h > 0 then return string.format("%dh %dm", h, m) end
	if m > 0 then return string.format("%dm %ds", m, s) end
	return string.format("%ds", s)
end



function ShopUI._itemRow(parent, order, spec, accentColor, onBuy)
	local row = parent:WaitForChild("Row_" .. (spec.id or spec.name))
    local buy = row:WaitForChild("Buy")
    local baseColor = buy.BackgroundColor3
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

	buy.MouseEnter:Connect(function() buy.BackgroundColor3 = baseColor:Lerp(Color3.new(1, 1, 1), 0.12) end)
	buy.MouseLeave:Connect(function() buy.BackgroundColor3 = baseColor end)
	buy.Activated:Connect(function()
		onBuy(spec, buy, setBuyLabel)
	end)

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

				unavailable()
			end
		end)
	end
end

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

				if s.daily and not ShopConfig.canClaim(s.id) then return end
				unavailable()

			elseif s.currency == "gems" then

				if PlayerData.spendGems(s.cost) then
					PlayerData.addCoins(s.amount)
				else

					local orig = buy.BackgroundColor3
					buy.BackgroundColor3 = Color3.fromRGB(170,50,50)
					task.delay(0.5, function() buy.BackgroundColor3 = orig end)
				end
			end
		end)
	end
end

function ShopUI._buildChips(sec)
	for order, spec in ipairs(ShopConfig.chipBundles) do
		ShopUI._itemRow(sec, order, spec, C.chip, function(s, buy, refresh)
			if s.currency == "robux" then

				if s.daily and not ShopConfig.canClaim(s.id) then return end
				unavailable()
			elseif s.currency == "gems" then

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


local RARITY_WEIGHT = { Common = 100, Rare = 30, Epic = 10, Legendary = 3 }
local XP_PER_CARD = 25

local function pickWeightedUnit()
	local all = UnitData.all()
	local pool, total = {}, 0
	for id, u in pairs(all) do
		local w = RARITY_WEIGHT[u.rarity]
		if w and u.packEligible ~= false then
			total += w
			table.insert(pool, { id = id, w = w })
		end
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

function ShopUI._buildDaily(sec)
	for order, spec in ipairs(ShopConfig.dailyDeals) do
		ShopUI._itemRow(sec, order, spec, C.gold, function(s, buy, refresh)

			if s.daily and not ShopConfig.canClaim(s.id) then return end

			if s.currency == "robux" then

				if s.giveGems then
					unavailable()
				elseif s.randomCard then
					unavailable()
				end
			elseif s.currency == "coins" then

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
