local MatchClock = require(game:GetService("ReplicatedStorage"):WaitForChild("MatchClock"))
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UnitData = require(ReplicatedStorage:WaitForChild("UnitData"))
local Deployment = require(ReplicatedStorage:WaitForChild("Deployment"))
local UnitModels = ReplicatedStorage:WaitForChild("UnitModels")
local UnitViewport = require(ReplicatedStorage:WaitForChild("UnitViewport"))

local DraftController = {}
local SELECTIONS_PER_ROUND = 3
local CARDS_PER_SELECTION = 3
local PICK_TIME = 15
DraftController.SELECTIONS_PER_ROUND = SELECTIONS_PER_ROUND
DraftController.CARDS_PER_SELECTION = CARDS_PER_SELECTION
DraftController.PICK_TIME = PICK_TIME

local function validPool(pool)
	local result = {}
	for _, id in ipairs(pool) do
		local unit = UnitData.get(id)
		if unit and UnitModels:FindFirstChild(unit.model, true) then table.insert(result, id) end
	end
	return result
end

local function drawCards(pool)
	local available = table.clone(pool)
	local cards = {}
	for _ = 1, CARDS_PER_SELECTION do
		if #available == 0 then available = table.clone(pool) end
		local index = math.random(1, #available)
		table.insert(cards, table.remove(available, index))
	end
	return cards
end

local function current(ctx)
	return not ctx.isCurrent or ctx.isCurrent()
end

local function clearCards(region)
    for _, child in ipairs(region.Cards:GetChildren()) do
        if child:IsA("GuiObject") then child:Destroy() end
    end
    region.Visible = false
    region.ZIndex = 1
end
DraftController.clear = clearCards

local function createCard(region, id, index, selected, pityStyle)
    local unit = UnitData.get(id)
    local templates = region:FindFirstAncestorOfClass("ScreenGui").Templates.DraftCards
    local template = templates:FindFirstChild(unit.rarity) or templates.Common
    local card = template:Clone()
    card.Name = "Card" .. index
    card.LayoutOrder = index
    card.Visible = true
    card:SetAttribute("UnitId", id)
    card.UnitName.Text = unit.name
    card.Rarity.Text = unit.rarity
    if pityStyle then
        card.Image = "rbxassetid://86551066856363"
        card.ScaleType = Enum.ScaleType.Stretch
        card.ImageColor3 = Color3.new(1, 1, 1)
    end
    card.Selection.Enabled = false
    card.Parent = region.Cards
    UnitViewport.show(card.UnitModel, unit.model)
    card.Activated:Connect(function() selected(id, card) end)
    return card
end

local function runSelection(ctx, pitySide)
	if not current(ctx) then return false end
	local playerPool = validPool(ctx.playerPool)
	local opponentPool = validPool(ctx.opponentPool)
	if #playerPool == 0 or #opponentPool == 0 then
		warn("Cannot draft without valid unit models")
		return false
	end
	local region = ctx.optionRegion
	clearCards(region)
	local cards = drawCards(playerPool)
	local opponentCards = drawCards(opponentPool)
	local playerPick
	local resolved = false
	local duration = ctx.pickTime or PICK_TIME
	local deadline = MatchClock.now() + duration
	local opponentReady = MatchClock.now() + (ctx.quickRound and 0.6 or 0.8 + math.random() * 1.4)
	local timer = region:WaitForChild("Timer")
    if pitySide ~= "opponent" then
		for i, id in ipairs(cards) do
			createCard(region, id, i, function(pick, card)
				if resolved or playerPick or not current(ctx) or MatchClock.isPaused() then return end
				playerPick = pick
				card.Selection.Enabled = true
			end, pitySide == "player")
		end
		region.Visible = true
	end
	while current(ctx) do
		local now = MatchClock.now()
		local remaining = math.max(0, math.ceil(deadline - now))
		timer.Text = (pitySide and "Bonus pick" or "Choose your unit") .. "  ·  " .. remaining
		local ready = playerPick ~= nil or now >= deadline or pitySide == "opponent"
		if not MatchClock.isPaused() and ready and (pitySide == "player" or now >= opponentReady) then break end
		task.wait(0.05)
	end
	resolved = true
	if not current(ctx) then return false end
	clearCards(region)
	local function deploy(id, side)
		local model = Deployment.deploy(id, side)
		if model and ctx.onDeploy then ctx.onDeploy(side, id) end
		return model ~= nil
	end
	if pitySide ~= "opponent" then
		if not deploy(playerPick or cards[math.random(1, #cards)], "player") then return false end
	end
	if pitySide ~= "player" then
		if not deploy(opponentCards[math.random(1, #opponentCards)], "opponent") then return false end
	end
	return true
end

function DraftController.runPityPick(ctx, side)
	return runSelection(ctx, side)
end

function DraftController.runRound(ctx)
	for _ = 1, SELECTIONS_PER_ROUND do
		if not runSelection(ctx) then return false end
		MatchClock.wait(ctx.quickRound and 0.15 or 0.4, function() return current(ctx) end)
		if not current(ctx) then return false end
	end
	return true
end

return DraftController


