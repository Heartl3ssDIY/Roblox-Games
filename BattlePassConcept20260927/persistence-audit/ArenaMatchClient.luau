local MatchClock = require(game:GetService("ReplicatedStorage"):WaitForChild("MatchClock"))
local PauseMenu = require(game:GetService("ReplicatedStorage"):WaitForChild("PauseMenu"))
local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UnitData = require(ReplicatedStorage:WaitForChild("UnitData"))
local UnitModels = ReplicatedStorage:WaitForChild("UnitModels")
local UnitViewport = require(ReplicatedStorage:WaitForChild("UnitViewport"))
local Loadout = require(ReplicatedStorage:WaitForChild("Loadout"))
local DraftController = require(ReplicatedStorage:WaitForChild("DraftController"))
local Deployment = require(ReplicatedStorage:WaitForChild("Deployment"))
local CombatController = require(ReplicatedStorage:WaitForChild("CombatController"))
local PlayerData = require(ReplicatedStorage:WaitForChild("PlayerData"))
local SeasonPassData = require(ReplicatedStorage:WaitForChild("SeasonPassData"))
local MatchResultsUI = require(ReplicatedStorage:WaitForChild("MatchResultsUI"))

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ArenaConfig = require(ReplicatedStorage:WaitForChild("ArenaConfig"))
local ArenaTravelClient = require(ReplicatedStorage:WaitForChild("ArenaTravelClient"))

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local C = {
    bg      = Color3.fromRGB(18, 12, 36),
    panel   = Color3.fromRGB(32, 20, 62),
    btnHov = Color3.fromRGB(60, 38, 112),
    border  = Color3.fromRGB(148, 88, 255),
    accent  = Color3.fromRGB(180, 120, 255),
    btnTxt  = Color3.fromRGB(230, 210, 255),
    sub     = Color3.fromRGB(155, 130, 195),
    gold    = Color3.fromRGB(255, 210, 80),
    cellBg  = Color3.fromRGB(40, 24, 78),
    heart   = Color3.fromRGB(235, 70, 90),
    heartOff= Color3.fromRGB(70, 50, 90),
    red     = Color3.fromRGB(200, 70, 90),
    blue    = Color3.fromRGB(80, 110, 220),
}
local function corner(p, r) Instance.new("UICorner", p).CornerRadius = UDim.new(0, r or 12) end
local function stroke(p, col, th)
    local s = Instance.new("UIStroke", p); s.Color = col; s.Thickness = th or 2
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; return s
end
local function mk(class, props, parent)
    local o = Instance.new(class)
    for k,v in pairs(props) do o[k]=v end
    o.Parent = parent; return o
end

local MAX_LIVES = 4
local EQUIPPED_SLOTS = 4

local hud = playerGui:WaitForChild("ArenaHUD")
hud.Enabled = false
local banner = hud:WaitForChild("RoundBanner")
local rewardOverlay = hud:WaitForChild("RewardOverlay")
local rewardPanel = rewardOverlay:WaitForChild("RewardPanel")
local rewardTitle = rewardPanel:WaitForChild("Title")
local rewardBody = rewardPanel:WaitForChild("Body")
local rewardPanelSize = rewardPanel.Size
local bannerStrokeTransparency = banner.TextStrokeTransparency

local function rewardSection(titleText, order)
    local sec = mk("Frame", {
        Name = "Sec_"..titleText, Size = UDim2.new(1,0,0,0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = C.panel, BorderSizePixel = 0, LayoutOrder = order, ZIndex = 32,
    }, rewardBody)
    corner(sec, 12); stroke(sec, C.border, 1)
    mk("UIPadding", { PaddingTop=UDim.new(0,8), PaddingBottom=UDim.new(0,10),
        PaddingLeft=UDim.new(0,12), PaddingRight=UDim.new(0,12) }, sec)
    mk("UIListLayout", { Padding = UDim.new(0,6), SortOrder = Enum.SortOrder.LayoutOrder }, sec)
    mk("TextLabel", { Name="SecTitle", Size=UDim2.new(1,0,0,22), BackgroundTransparency=1,
        Text=titleText, TextColor3=C.gold, Font=Enum.Font.PermanentMarker, TextSize=16,
        TextXAlignment=Enum.TextXAlignment.Left, LayoutOrder=0, ZIndex=33 }, sec)
    return sec
end

local function rewardRow(parent, order, icon, label, color)
    local row = mk("Frame", { Size=UDim2.new(1,0,0,28), BackgroundTransparency=1, LayoutOrder=order, ZIndex=33 }, parent)
    mk("TextLabel", { Size=UDim2.new(0,32,1,0), BackgroundTransparency=1, Text=icon,
        TextColor3=color, Font=Enum.Font.PermanentMarker, TextSize=18, ZIndex=34 }, row)
    mk("TextLabel", { Size=UDim2.new(1,-40,1,0), Position=UDim2.new(0,38,0,0), BackgroundTransparency=1,
        Text=label, TextColor3=C.btnTxt, Font=Enum.Font.PermanentMarker, TextSize=14,
        TextXAlignment=Enum.TextXAlignment.Left, ZIndex=34 }, row)
    return row
end

local backLobbyBtn = rewardPanel:WaitForChild("BackLobby")
local nextMatchBtn = rewardPanel:WaitForChild("NextMatch")

local rewardConnections = {}

local function clearRewardConnections()
    for _, connection in ipairs(rewardConnections) do connection:Disconnect() end
    table.clear(rewardConnections)
end

local function showRewards(data, onLobby, onNextMatch)
    clearRewardConnections()
    MatchResultsUI.show(playerGui, data, onLobby, onNextMatch)
end
local function lifeCluster(name)
    local holder = hud:WaitForChild(name)
    local hearts = {}
    for index = 1, MAX_LIVES do hearts[index] = holder.Hearts:WaitForChild("Heart" .. index) end
    return {name = holder:WaitForChild("NameLbl"), hearts = hearts}
end

local playerCluster = lifeCluster("PlayerCluster")
local opponentCluster = lifeCluster("OpponentCluster")

local function setLives(cluster, lives)
    for index, heart in ipairs(cluster.hearts) do
        heart.ImageTransparency = index <= lives and 0 or 0.7
        heart.ImageColor3 = index <= lives and Color3.new(1, 1, 1) or Color3.fromRGB(80, 65, 75)
        heart:SetAttribute("Full", index <= lives)
    end
end
setLives(playerCluster, MAX_LIVES)
setLives(opponentCluster, MAX_LIVES)

local unitBar = hud:WaitForChild("EquippedBar")
local function refreshEquippedBar()
    local equipped = Loadout.getAll()
    for index = 1, EQUIPPED_SLOTS do
        local slot = unitBar:WaitForChild("Slot" .. index)
        local unit = equipped[index] and UnitData.get(equipped[index])
        slot.UnitName.Text = unit and unit.name or tostring(index)
        slot:SetAttribute("UnitId", unit and unit.id or nil)
        if unit then
            UnitViewport.show(slot.UnitModel, unit.model)
        else
            UnitViewport.clear(slot.UnitModel)
        end
    end
end
refreshEquippedBar()
Loadout.Changed:Connect(refreshEquippedBar)
local function refreshMasteryBadges()
    for index = 1, EQUIPPED_SLOTS do
        local slot = unitBar["Slot" .. index]
        local id = slot:GetAttribute("UnitId")
        local unit = id and UnitData.get(id)
        slot.MasteryBadge.Visible = unit ~= nil
        if unit then slot.MasteryBadge.Level.Text = tostring(PlayerData.masteryLevel(id, unit.rarity)) end
    end
end
refreshMasteryBadges()
Loadout.Changed:Connect(refreshMasteryBadges)
PlayerData.Changed:Connect(refreshMasteryBadges)

local optionRegion = hud:WaitForChild("OptionRegion")
local draftScale = optionRegion:WaitForChild("FitToScreen")
local function resizeDraft()
    if hud:GetAttribute("AutoFitDraft") == false then return end
    draftScale.Scale = math.min(1, (hud.AbsoluteSize.X - 24) / math.max(1, optionRegion.Size.X.Offset))
end
hud:GetPropertyChangedSignal("AbsoluteSize"):Connect(resizeDraft)
resizeDraft()

local hiddenGuis = {}
local session
local entering = false
local leaveArena
local startMatch
local startRound
local exitButton = hud:WaitForChild("Pause")

local function isCurrent(match)
	return session == match and match.active
end

local function setPhase(phase)
	player:SetAttribute("MatchPhase", phase)
    exitButton.Visible = phase ~= "Lobby" and phase ~= "Results"
end

local function hideLobbyGui(gui)
	if not gui:IsA("ScreenGui") or gui == hud or gui.Name == "TouchGui" then return end
	if gui.ResetOnSpawn == false then
		if hiddenGuis[gui] == nil then hiddenGuis[gui] = gui.Enabled end
		gui.Enabled = false
	end
end

local function showLobby()
	for gui, enabled in pairs(hiddenGuis) do
		if gui.Parent then
			gui.Enabled = enabled and gui.Name ~= "ModePickerGui" and gui.Name ~= "ArenaSelectGui"
		end
	end
	table.clear(hiddenGuis)
end

local function cancelMatch()
    MatchClock.setPaused(false)
    PauseMenu.hide()
	if session then session.active = false end
	session = nil
	CombatController.cancel()
	Deployment.reset()
	clearRewardConnections()
	MatchResultsUI.hide(playerGui)
	rewardOverlay.Visible = false
	banner.Visible = false
	optionRegion.Visible = false
	DraftController.clear(optionRegion)
end

local function showBanner(match, text, duration)
	if not isCurrent(match) then return false end
	banner.Text = text
	banner.TextTransparency = 0
	banner.TextStrokeTransparency = bannerStrokeTransparency
	banner.Visible = true
	MatchClock.wait(duration, function() return isCurrent(match) end)
	if not isCurrent(match) then return false end
	banner.Visible = false
	return true
end

local function rollOpponentPool()
	local pool = {}
	for id, data in pairs(UnitData.all()) do
		if UnitModels:FindFirstChild(data.model) then table.insert(pool, id) end
	end
	for i = #pool, 2, -1 do
		local j = math.random(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	while #pool > 4 do table.remove(pool) end
	return pool
end

local function grantRewards(match, playerWon)
	local result = PlayerData.recordResult(ArenaConfig.progressionKey, playerWon)
	local data = {
		playerWon = playerWon, coins = playerWon and 100 or 35,
		accountXp = playerWon and 50 or 18, masteryChips = playerWon and 10 or 4,
		arenaDelta = result.delta, arenaPoints = result.points,
		milestoneCoins = result.coinsAwarded, milestoneGems = result.gemsAwarded,
		unlockedUnits = result.unlockedUnits, unitMastery = {},
	}
	PlayerData.addCoins(data.coins)
	if PlayerData.addXp(data.accountXp) > 0 then data.leveledTo = PlayerData.level() end
	if playerWon then data.dailyPack = PlayerData.grantDailyWinPack() end
	PlayerData.addMasteryChips(data.masteryChips)
	for _, id in ipairs(match.playerPool) do
		local unit = UnitData.get(id)
		local gained = playerWon and PlayerData.MASTERY_PER_MATCH or 4
		PlayerData.addMasteryPoints(id, gained)
		table.insert(data.unitMastery, {
			id = id, name = unit.name, rarity = unit.rarity, gained = gained,
		})
	end
	SeasonPassData.applyMatchOutcome(playerWon and "win" or "loss")
	data.passXp = playerWon and 5 or 2
	data.trophyDelta = playerWon and 10 or -4
	return data
end

local function finishMatch(match, winner)
	if not isCurrent(match) or match.finished then return end
	match.finished = true
	setPhase("Results")
	player:SetAttribute("RoundWinner", winner or "draw")
	local function replay()
		if isCurrent(match) then startMatch(match.quickRound) end
	end
	local function back()
		if isCurrent(match) then leaveArena() end
	end
	if match.quickRound or not winner then
		clearRewardConnections()
		for _, child in ipairs(rewardBody:GetChildren()) do
			if child:IsA("Frame") then child:Destroy() end
		end
		rewardTitle.Text = winner == "player" and "ROUND WON!" or winner == "opponent" and "ROUND LOST" or "DRAW"
		rewardTitle.TextColor3 = C.gold
		local section = rewardSection(match.quickRound and "Quick Round" or "Match Draw", 1)
		rewardRow(section, 1, "", match.quickRound and "Test round complete. No rewards awarded." or "Both teams were evenly matched.", C.btnTxt)
		nextMatchBtn.Text = match.quickRound and "Play Again" or "Next Match"
		rewardPanel.Size = rewardPanelSize
		rewardOverlay.Visible = true
		rewardConnections = {
			backLobbyBtn.Activated:Connect(back),
			nextMatchBtn.Activated:Connect(replay),
		}
	else
		nextMatchBtn.Text = "Next Match"
		showRewards(grantRewards(match, winner == "player"), back, replay)
	end
end

local function roundEnded(match, winner)
    if not MatchClock.wait(0, function() return isCurrent(match) end) then return end
	if not isCurrent(match) then return end
	setPhase("RoundEnd")
	player:SetAttribute("RoundWinner", winner or "draw")
	if winner == "player" then
		match.opponentLives -= 1
		match.pityFor = "opponent"
	elseif winner == "opponent" then
		match.playerLives -= 1
		match.pityFor = "player"
	else
		match.pityFor = nil
		match.draws += 1
	end
	setLives(playerCluster, match.playerLives)
	setLives(opponentCluster, match.opponentLives)
	task.spawn(function()
		local title = winner == "player" and "Round Won!" or winner == "opponent" and "Round Lost!" or "Draw!"
		if not showBanner(match, title, 1.2) then return end
		if match.quickRound then finishMatch(match, winner)
		elseif match.playerLives == 0 then finishMatch(match, "opponent")
		elseif match.opponentLives == 0 then finishMatch(match, "player")
		elseif match.draws >= 3 then finishMatch(match, nil)
		else startRound(match) end
	end)
end

startRound = function(match)
	if not isCurrent(match) then return end
	match.round += 1
	player:SetAttribute("MatchRound", match.round)
	setPhase("Draft")
	task.spawn(function()
		Deployment.reset()
		for _, id in ipairs(match.playerArmy) do Deployment.deploy(id, "player") end
		for _, id in ipairs(match.opponentArmy) do Deployment.deploy(id, "opponent") end
		if not showBanner(match, "Round " .. match.round, match.quickRound and 0.5 or 1) then return end
		local ctx = {
			optionRegion = optionRegion, playerPool = match.playerPool,
			opponentPool = match.opponentPool, quickRound = match.quickRound,
			pickTime = match.quickRound and 3 or 15,
			isCurrent = function() return isCurrent(match) end,
			onDeploy = function(side, id)
				table.insert(side == "player" and match.playerArmy or match.opponentArmy, id)
			end,
		}
		if match.pityFor and not DraftController.runPityPick(ctx, match.pityFor) then return end
		if not DraftController.runRound(ctx) then
			if isCurrent(match) then
				warn("Round stopped because a unit could not deploy")
				leaveArena()
			end
			return
		end
		if not showBanner(match, "Fight!", 0.5) then return end
		setPhase("Combat")
		CombatController.run(function(winner) roundEnded(match, winner) end, {
			isCurrent = ctx.isCurrent, timeLimit = match.quickRound and 20 or 30,
		})
	end)
end

startMatch = function(quickRound)
	cancelMatch()
	local pool = Loadout.getAll()
	if #pool ~= EQUIPPED_SLOTS then
		warn("Equip four units before starting a match")
		leaveArena()
		return
	end
	local match = {
		active = true, quickRound = quickRound == true, finished = false,
		playerPool = pool, opponentPool = rollOpponentPool(),
		playerArmy = {}, opponentArmy = {}, playerLives = MAX_LIVES, opponentLives = MAX_LIVES,
		round = 0, draws = 0,
	}
	session = match
	player:SetAttribute("QuickRound", match.quickRound)
	player:SetAttribute("RoundWinner", nil)
	setLives(playerCluster, MAX_LIVES)
	setLives(opponentCluster, MAX_LIVES)
	playerCluster.name.Text = player.DisplayName
	opponentCluster.name.Text = match.quickRound and "Practice Opponent" or "Opponent"
	refreshEquippedBar()
	startRound(match)
end

leaveArena = function()
	local success, message = ArenaTravelClient.leave()
	if not success then warn(message) return false, message end
	cancelMatch()
	hud.Enabled = false
	showLobby()
	setPhase("Lobby")
	player:SetAttribute("QuickRound", nil)
	player:SetAttribute("MatchRound", nil)
    return true
end

local function enterArena(arenaName, quickRound)
	if entering or session or arenaName ~= ArenaConfig.arenaName then return end
    if PlayerData.pendingDailyPack() then
        require(ReplicatedStorage:WaitForChild("ArenaSelectionUI")).open(playerGui)
        return
    end
	if #Loadout.getAll() ~= EQUIPPED_SLOTS then return end
	entering = true
	local success, message = ArenaTravelClient.enter()
	entering = false
	if not success then warn(message) return end
	for _, gui in ipairs(playerGui:GetChildren()) do hideLobbyGui(gui) end
	hud.Enabled = true
	startMatch(quickRound)
end

PauseMenu.build(hud, {
    canPause = function() return session ~= nil and session.active and not session.finished end,
    pause = MatchClock.setPaused,
    quit = function()
        local match = session
        if not match or not match.active or match.finished then return false, "The match has already ended." end
        local success, message = leaveArena()
        if not success then return false, message end
        if not match.quickRound then
            PlayerData.recordResult(ArenaConfig.progressionKey, false)
            SeasonPassData.applyMatchOutcome("forfeit")
        end
        player:SetAttribute("LastMatchForfeited", true)
        require(ReplicatedStorage:WaitForChild("ArenaSelectionUI")).open(playerGui)
        return true
    end,
})
playerGui.ChildAdded:Connect(function(gui)
	task.defer(function()
		if session and gui.Parent then hideLobbyGui(gui) end
	end)
end)
player.CharacterRemoving:Connect(function()
	cancelMatch()
	ArenaTravelClient.restore()
	hud.Enabled = false
	showLobby()
	setPhase("Lobby")
end)

local events = ReplicatedStorage:WaitForChild("ArenaEvents")
events:WaitForChild("EnterArena").Event:Connect(function(name, quickRound)
	enterArena(name or ArenaConfig.arenaName, quickRound == true and RunService:IsStudio())
end)
local leaveEvent = events:FindFirstChild("LeaveArena")
if not leaveEvent then
	leaveEvent = Instance.new("BindableEvent")
	leaveEvent.Name = "LeaveArena"
	leaveEvent.Parent = events
end
leaveEvent.Event:Connect(function()
    if session and session.active and not session.finished then PauseMenu.open()
    else leaveArena() end
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and RunService:IsStudio() and input.KeyCode == Enum.KeyCode.F6 then
		enterArena(ArenaConfig.arenaName, true)
	end
end)
setPhase("Lobby")

if RunService:IsStudio() and workspace:GetAttribute("StudioQuickRoundOnPlay") then
	task.spawn(function()
		local character = player.Character or player.CharacterAdded:Wait()
		character:WaitForChild("HumanoidRootPart")
		task.wait(1.5)
		enterArena(ArenaConfig.arenaName, true)
	end)
end




