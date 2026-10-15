--!strict
-- DraftController: runs the per-round unit draft.
-- Per round = 3 selections. Each selection: 3 random cards from the player's 4
-- equipped units (repeats allowed across selections). Player picks within 15s or
-- auto-picks randomly. Opponent (AI) drafts from its own equipped set with a
-- human-feeling delay, hidden. A selection is GATED: it resolves only when both
-- sides have chosen, at which point BOTH units deploy simultaneously, then the
-- next set of cards appears. No combat — units just stand at start positions.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UnitData = require(ReplicatedStorage.UnitData)
local Deployment = require(ReplicatedStorage.Deployment)
local UnitModels = ReplicatedStorage:WaitForChild("UnitModels")

local DraftController = {}

local SELECTIONS_PER_ROUND = 3
local CARDS_PER_SELECTION = 3
local PICK_TIME = 15

-- Palette (matches HUD)
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

-- Build a unit-model viewport icon (face shot) inside a parent.
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

-- ── Card draw ────────────────────────────────────────────────────────────────
-- Draw N random unit ids from a pool (the equipped list). Repeats across draws
-- are fine; within a single draw of 3 we pick distinct cards when possible.
local function drawCards(pool, n)
	local cards = {}
	local available = {}
	for _, id in ipairs(pool) do table.insert(available, id) end
	for _ = 1, n do
		if #available == 0 then
			-- pool smaller than n: refill so we can still show n cards
			for _, id in ipairs(pool) do table.insert(available, id) end
		end
		local idx = math.random(1, #available)
		table.insert(cards, available[idx])
		table.remove(available, idx)
	end
	return cards
end

-- ── Opponent AI: pick a card index, with a human-feeling delay ───────────────
local function opponentChoose(cards, onChosen)
	task.spawn(function()
		-- sometimes quick, sometimes deliberate (but always within PICK_TIME)
		local delay = math.random() * (PICK_TIME - 2) + 0.8
		task.wait(delay)
		local idx = math.random(1, #cards)
		onChosen(cards[idx])
	end)
end

-- ── One selection (gated, timed) ─────────────────────────────────────────────
-- ctx holds UI refs + sides. Returns once BOTH have chosen; deploys both.
local function runSelection(ctx, selectionIndex)
	local region = ctx.optionRegion
	-- clear old cards
	for _, ch in ipairs(region:GetChildren()) do
		if ch:IsA("Frame") or ch:IsA("TextButton") or ch:IsA("TextLabel") then ch:Destroy() end
	end

	-- timer label at top of region
	local timerLbl = mk("TextLabel", {
		Name = "Timer", Size = UDim2.new(1,0,0,26), Position = UDim2.new(0,0,0,-30),
		BackgroundTransparency = 1, Text = "Choose your unit  \xC2\xB7  "..PICK_TIME,
		TextColor3 = C.timer, Font = Enum.Font.GothamBold, TextSize = 18,
	}, region)

	-- draw both sides' cards
	local playerCards = drawCards(ctx.playerPool, CARDS_PER_SELECTION)
	local oppCards    = drawCards(ctx.opponentPool, CARDS_PER_SELECTION)

	local playerPick, opponentPick = nil, nil
	local resolved = false

	-- card row
	local cardW, cardH, gap = 150, 190, 20
	local totalW = CARDS_PER_SELECTION*cardW + (CARDS_PER_SELECTION-1)*gap
	for i, unitId in ipairs(playerCards) do
		local unit = UnitData.get(unitId)
		local card = mk("TextButton", {
			Name = "Card"..i, Size = UDim2.new(0, cardW, 0, cardH),
			Position = UDim2.new(0.5, -totalW/2 + (i-1)*(cardW+gap), 0, 0),
			BackgroundColor3 = C.cellBg, BorderSizePixel = 0, AutoButtonColor = false, Text = "",
		}, region)
		corner(card, 14); stroke(card, C.border, 2)
		-- icon
		local iconHolder = mk("Frame", { Size=UDim2.new(1,-16,1,-50), Position=UDim2.new(0,8,0,8), BackgroundTransparency=1 }, card)
		unitIcon(iconHolder, unit.model)
		-- name strip
		mk("TextLabel", {
			Size=UDim2.new(1,0,0,34), Position=UDim2.new(0,0,1,-38), BackgroundTransparency=1,
			Text = unit.name, TextColor3 = C.gold, Font = Enum.Font.GothamBold, TextSize = 18,
		}, card)
		card.MouseEnter:Connect(function()
			if not resolved then TweenService:Create(card, TweenInfo.new(0.1), {BackgroundColor3=C.cellHov}):Play() end
		end)
		card.MouseLeave:Connect(function()
			TweenService:Create(card, TweenInfo.new(0.1), {BackgroundColor3=C.cellBg}):Play()
		end)
		card.Activated:Connect(function()
			if resolved or playerPick then return end
			playerPick = unitId
			-- highlight chosen, dim others
			for _, c in ipairs(region:GetChildren()) do
				if c:IsA("TextButton") then
					if c == card then stroke(c, C.gold, 3)
					else c.BackgroundTransparency = 0.5; c.Active = false end
				end
			end
		end)
	end

	region.Visible = true

	-- opponent chooses (hidden)
	opponentChoose(oppCards, function(id) opponentPick = id end)

	-- timer + gating loop
	local t = PICK_TIME
	while t > 0 do
		timerLbl.Text = "Choose your unit  \xC2\xB7  "..math.ceil(t)
		-- if both picked, break early
		if playerPick and opponentPick then break end
		task.wait(0.2)
		t -= 0.2
	end

	-- auto-pick for whoever didn't choose
	if not playerPick then playerPick = playerCards[math.random(1, #playerCards)] end
	if not opponentPick then opponentPick = oppCards[math.random(1, #oppCards)] end

	resolved = true
	region.Visible = false

	-- simultaneous deploy (the reveal)
	Deployment.deploy(playerPick, "player")
	Deployment.deploy(opponentPick, "opponent")
	-- record picks into the running army history (for respawn next round)
	if ctx.onDeploy then
		ctx.onDeploy("player", playerPick)
		ctx.onDeploy("opponent", opponentPick)
	end
end

-- Public: run one selection (used for the pity pick). Same 15s rule.
-- pityFor = "player" or "opponent": only that side actually picks+deploys.
function DraftController.runPityPick(ctx, pityFor)
	-- reuse runSelection but only deploy the pity side.
	-- We run a normal gated selection but the non-pity side auto-resolves instantly
	-- with no deploy (they don't get a pick).
	local region = ctx.optionRegion
	for _, ch in ipairs(region:GetChildren()) do
		if ch:IsA("Frame") or ch:IsA("TextButton") or ch:IsA("TextLabel") then ch:Destroy() end
	end
	local pool = (pityFor == "player") and ctx.playerPool or ctx.opponentPool
	local cards = drawCards(pool, CARDS_PER_SELECTION)

	-- label
	local timerLbl = mk("TextLabel", {
		Name = "Timer", Size = UDim2.new(1,0,0,26), Position = UDim2.new(0,0,0,-30),
		BackgroundTransparency = 1, Text = "Pity pick  \xC2\xB7  "..PICK_TIME,
		TextColor3 = C.gold, Font = Enum.Font.GothamBold, TextSize = 18,
	}, region)

	local pick = nil
	local resolved = false
	local cardW, cardH, gap = 150, 190, 20
	local totalW = CARDS_PER_SELECTION*cardW + (CARDS_PER_SELECTION-1)*gap

	if pityFor == "player" then
		-- show cards for the player to choose
		for i, unitId in ipairs(cards) do
			local unit = UnitData.get(unitId)
			local card = mk("TextButton", {
				Name = "Card"..i, Size = UDim2.new(0, cardW, 0, cardH),
				Position = UDim2.new(0.5, -totalW/2 + (i-1)*(cardW+gap), 0, 0),
				BackgroundColor3 = C.cellBg, BorderSizePixel = 0, AutoButtonColor = false, Text = "",
			}, region)
			corner(card, 14); stroke(card, C.gold, 2)
			local iconHolder = mk("Frame", { Size=UDim2.new(1,-16,1,-50), Position=UDim2.new(0,8,0,8), BackgroundTransparency=1 }, card)
			unitIcon(iconHolder, unit.model)
			mk("TextLabel", { Size=UDim2.new(1,0,0,34), Position=UDim2.new(0,0,1,-38), BackgroundTransparency=1,
				Text = unit.name, TextColor3 = C.gold, Font = Enum.Font.GothamBold, TextSize = 18 }, card)
			card.Activated:Connect(function()
				if resolved or pick then return end
				pick = unitId
			end)
		end
		region.Visible = true
		local t = PICK_TIME
		while t > 0 and not pick do
			timerLbl.Text = "Pity pick  \xC2\xB7  "..math.ceil(t)
			task.wait(0.2); t -= 0.2
		end
		if not pick then pick = cards[math.random(1,#cards)] end
		resolved = true
		region.Visible = false
		Deployment.deploy(pick, "player")
		if ctx.onDeploy then ctx.onDeploy("player", pick) end
	else
		-- opponent pity: AI picks (hidden), brief delay, deploy
		task.wait(math.random()*2 + 0.5)
		local oppPity = cards[math.random(1,#cards)]
		Deployment.deploy(oppPity, "opponent")
		if ctx.onDeploy then ctx.onDeploy("opponent", oppPity) end
	end
end

-- ── Run a full round (3 selections) ──────────────────────────────────────────
function DraftController.runRound(ctx)
	-- ctx = { optionRegion=Frame, playerPool={ids}, opponentPool={ids} }
	for i = 1, SELECTIONS_PER_ROUND do
		runSelection(ctx, i)
		task.wait(0.6)  -- brief beat between selections (deploy reveal)
	end
end

return DraftController

