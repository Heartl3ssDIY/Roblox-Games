local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UnitData = require(ReplicatedStorage.UnitData)
local Deployment = require(ReplicatedStorage.Deployment)
local UnitModels = ReplicatedStorage:WaitForChild("UnitModels")

local DraftController = {}

local SELECTIONS_PER_ROUND = 3
local CARDS_PER_SELECTION = 3
local PICK_TIME = 15

local C = {
	panel   = Color3.fromRGB(32, 20, 62),
	border  = Color3.fromRGB(148, 88, 255),
	cellBg  = Color3.fromRGB(40, 24, 78),
	cellHov = Color3.fromRGB(60, 38, 112),
	btnTxt  = Color3.fromRGB(230, 210, 255),
	sub     = Color3.fromRGB(155, 130, 195),
	gold    = Color3.fromRGB(255, 210, 80),
	timer   = Color3.fromRGB(255, 150, 90),
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

local function unitIcon(parent, modelName)
	local vp = mk("ViewportFrame", { Size=UDim2.new(1,0,1,0), BackgroundTransparency=1, BorderSizePixel=0 }, parent)
	local tmpl = UnitModels:FindFirstChild(modelName)
	if not tmpl then return end
	local m = tmpl:Clone()
	for _,p in ipairs(m:GetDescendants()) do if p:IsA("BasePart") then p.Anchored=true end end
	m.Parent = vp
	local cf, size = m:GetBoundingBox()
	local cam = Instance.new("Camera"); cam.Parent = vp; vp.CurrentCamera = cam
	local focus = cf.Position + Vector3.new(0, size.Y*0.12, 0)
	cam.CFrame = CFrame.lookAt(focus + Vector3.new(0, 0, -size.Y*0.95), focus)
end

DraftController._mk = mk
DraftController._corner = corner
DraftController._stroke = stroke
DraftController._unitIcon = unitIcon
DraftController._C = C
DraftController.SELECTIONS_PER_ROUND = SELECTIONS_PER_ROUND
DraftController.CARDS_PER_SELECTION = CARDS_PER_SELECTION
DraftController.PICK_TIME = PICK_TIME

local function validPool(pool)
	local result = {}
	for _, id in ipairs(pool) do
		local unit = UnitData.get(id)
		if unit and UnitModels:FindFirstChild(unit.model) then table.insert(result, id) end
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
	for _, child in ipairs(region:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	region.Visible = false
end

local function createCard(region, id, index, selected)
	local unit = UnitData.get(id)
	local card = mk("TextButton", {
		Name = "Card" .. index, Size = UDim2.fromOffset(150, 190),
		Position = UDim2.new(0.5, -245 + (index - 1) * 170, 0, 0),
		BackgroundColor3 = C.cellBg, BorderSizePixel = 0, AutoButtonColor = false, Text = "",
	}, region)
	corner(card, 14)
	stroke(card, C.border, 2)
	local icon = mk("Frame", {
		Size = UDim2.new(1, -16, 1, -50), Position = UDim2.fromOffset(8, 8), BackgroundTransparency = 1,
	}, card)
	unitIcon(icon, unit.model)
	mk("TextLabel", {
		Size = UDim2.new(1, 0, 0, 34), Position = UDim2.new(0, 0, 1, -38),
		BackgroundTransparency = 1, Text = unit.name, TextColor3 = C.gold,
		Font = Enum.Font.GothamBold, TextSize = 18,
	}, card)
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
	local deadline = os.clock() + duration
	local opponentReady = os.clock() + (ctx.quickRound and 0.6 or 0.8 + math.random() * 1.4)
	local timer = mk("TextLabel", {
		Name = "Timer", Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, -30),
		BackgroundTransparency = 1, TextColor3 = C.timer, Font = Enum.Font.GothamBold, TextSize = 18,
	}, region)
	if pitySide ~= "opponent" then
		for i, id in ipairs(cards) do
			createCard(region, id, i, function(pick, card)
				if resolved or playerPick or not current(ctx) then return end
				playerPick = pick
				stroke(card, C.gold, 3)
			end)
		end
		region.Visible = true
	end
	while current(ctx) do
		local now = os.clock()
		local remaining = math.max(0, math.ceil(deadline - now))
		timer.Text = (pitySide and "Bonus pick" or "Choose your unit") .. "  ·  " .. remaining
		local ready = playerPick ~= nil or now >= deadline or pitySide == "opponent"
		if ready and (pitySide == "player" or now >= opponentReady) then break end
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
		task.wait(ctx.quickRound and 0.15 or 0.4)
		if not current(ctx) then return false end
	end
	return true
end

return DraftController


