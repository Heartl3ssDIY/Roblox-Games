local hiddenGuis = {}
local session
local entering = false
local leaveArena
local startMatch
local startRound
local exitButton = mk("TextButton", {
	Name = "LeaveArena", Text = "Back to Lobby", Size = UDim2.fromOffset(130, 32),
	Position = UDim2.fromOffset(16, 60), BackgroundColor3 = C.panel,
	TextColor3 = C.btnTxt, Font = Enum.Font.GothamBold, TextSize = 13,
	BorderSizePixel = 0, ZIndex = 25,
}, hud)
corner(exitButton, 10)

local function isCurrent(match)
	return session == match and match.active
end

local function setPhase(phase)
	player:SetAttribute("MatchPhase", phase)
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
	if session then session.active = false end
	session = nil
	CombatController.cancel()
	Deployment.reset()
	clearRewardConnections()
	rewardOverlay.Visible = false
	banner.Visible = false
	optionRegion.Visible = false
	for _, child in ipairs(optionRegion:GetChildren()) do child:Destroy() end
end

local function showBanner(match, text, duration)
	if not isCurrent(match) then return false end
	banner.Text = text
	banner.TextTransparency = 0
	banner.TextStrokeTransparency = 0.2
	banner.Visible = true
	task.wait(duration)
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
		PlayerData.addMasteryPoints(id, PlayerData.MASTERY_PER_MATCH)
		table.insert(data.unitMastery, {
			id = id, name = unit.name, rarity = unit.rarity, gained = PlayerData.MASTERY_PER_MATCH,
		})
	end
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
		rewardPanel.Size = UDim2.fromOffset(560, 300)
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
	if not success then warn(message) return end
	cancelMatch()
	hud.Enabled = false
	showLobby()
	setPhase("Lobby")
	player:SetAttribute("QuickRound", nil)
	player:SetAttribute("MatchRound", nil)
end

local function enterArena(arenaName, quickRound)
	if entering or session or arenaName ~= ArenaConfig.arenaName then return end
	if #Loadout.getAll() ~= EQUIPPED_SLOTS then return end
	entering = true
	local success, message = ArenaTravelClient.enter()
	entering = false
	if not success then warn(message) return end
	for _, gui in ipairs(playerGui:GetChildren()) do hideLobbyGui(gui) end
	hud.Enabled = true
	startMatch(quickRound)
end

exitButton.Activated:Connect(leaveArena)
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
leaveEvent.Event:Connect(leaveArena)
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
