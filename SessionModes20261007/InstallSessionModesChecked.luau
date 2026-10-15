assert(not game:GetService("RunService"):IsRunning(), "Edit mode required")
local ServerScriptService=game:GetService("ServerScriptService")
local ServerStorage=game:GetService("ServerStorage")
local StarterGui=game:GetService("StarterGui")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local coordinator=ServerScriptService:FindFirstChild("PlaygroundCoordinator")
assert(coordinator and coordinator.Source==game:GetService("HttpService"):JSONDecode([=======["local Players = game:GetService(\"Players\")\nlocal ReplicatedStorage = game:GetService(\"ReplicatedStorage\")\nlocal RunService = game:GetService(\"RunService\")\n\nlocal Coordinator = {}\nCoordinator.__index = Coordinator\nlocal games = { \"BritishBulldog\", \"TagYoureIt\", \"StuckInTheMud\" }\nlocal titles = { BritishBulldog = \"British Bulldog\", TagYoureIt = \"Tag You're It\", StuckInTheMud = \"Stuck in the Mud\" }\n\nfunction Coordinator.new(services, lobby, economy)\n\tlocal self = setmetatable({}, Coordinator)\n\tself.services = services\n\tself.lobby = lobby\n\tself.economy = economy\n\tself.zone = lobby.Gameplay.VoteZone\n\tself.state = ReplicatedStorage:WaitForChild(\"PlaygroundState\")\n\tself.votes = {}\n\tself.lastVote = {}\n\tself.connections = {}\n\tself.running = false\n\tself.autoEnabled = true\n\tself.votingEndsAt = 0\n\tself.random = Random.new()\n\tself.lastGame = nil\n\treturn self\nend\n\nfunction Coordinator:ActiveGame()\n\tfor _, id in ipairs(games) do if self.services[id] and self.services[id].active then return id end end\n\treturn nil\nend\n\nfunction Coordinator:_readyPlayers()\n\tlocal list = {}\n\tfor _, player in ipairs(Players:GetPlayers()) do\n\t\tlocal humanoid = player.Character and player.Character:FindFirstChildOfClass(\"Humanoid\")\n\t\tif humanoid and humanoid.Health > 0 and not player:GetAttribute(\"BBParticipating\") and not player:GetAttribute(\"TGParticipating\") and not player:GetAttribute(\"MDParticipating\") and player:GetAttribute(\"PCDataReady\") == true then\n\t\t\ttable.insert(list, player)\n\t\tend\n\tend\n\treturn list\nend\n\nfunction Coordinator:MinimumPlayers(id)\n\tlocal service=self.services[id]\n\tlocal minimum=service and service.arena and service.arena:GetAttribute(\"MinimumPlayers\")\n\tif typeof(minimum)~=\"number\" or minimum~=minimum or math.abs(minimum)==math.huge then minimum=id==\"StuckInTheMud\" and 4 or 2 end\n\treturn math.max(2,math.floor(minimum))\nend\n\nfunction Coordinator:GameAvailable(id, readyCount)\n\tlocal service=self.services[id]\n\tif not service then return false end\n\tif id==\"StuckInTheMud\" and service.state:GetAttribute(\"GunAccessReady\")==false then return false end\n\treturn (readyCount or #self:_readyPlayers())>=self:MinimumPlayers(id)\nend\n\nfunction Coordinator:_availability(readyCount)\n\tself.state:SetAttribute(\"ReadyPlayerCount\",readyCount)\n\tfor _,id in ipairs(games) do\n\t self.state:SetAttribute(\"Available\"..id,self:GameAvailable(id,readyCount))\n\t if self.services[id] then self.state:SetAttribute(\"Minimum\"..id,self:MinimumPlayers(id)) end\n\tend\nend\n\nfunction Coordinator:_insideZone(player)\n\tlocal root = player.Character and player.Character:FindFirstChild(\"HumanoidRootPart\")\n\tif not root then return false end\n\tlocal point = self.zone.CFrame:PointToObjectSpace(root.Position)\n\tlocal half = self.zone.Size / 2\n\treturn math.abs(point.X) <= half.X and math.abs(point.Y) <= half.Y and math.abs(point.Z) <= half.Z\nend\n\nfunction Coordinator:_counts()\n\tlocal counts = { BritishBulldog = 0, TagYoureIt = 0, StuckInTheMud = 0 }\n\tfor player, id in pairs(self.votes) do\n\t\tif player.Parent == Players and counts[id] then counts[id] += 1 end\n\tend\n\tfor id, count in pairs(counts) do self.state:SetAttribute(\"Votes\" .. id, count) end\n\treturn counts\nend\n\nfunction Coordinator:_clearVotes()\n\tfor player in pairs(self.votes) do if player.Parent == Players then player:SetAttribute(\"PCVote\", \"\") end end\n\ttable.clear(self.votes)\n\tself:_counts()\nend\n\nfunction Coordinator:SetAutoEnabled(enabled)\n\tself.autoEnabled = enabled == true\n\tself.votingEndsAt = 0\n\tself.state:SetAttribute(\"AutomaticRounds\", self.autoEnabled)\n\tself.state:SetAttribute(\"VotingEndsAt\", 0)\n\tif not self:ActiveGame() then\n\t\tself.state:SetAttribute(\"Phase\", self.autoEnabled and \"Waiting\" or \"Paused\")\n\t\tself:_clearVotes()\n\tend\nend\n\nfunction Coordinator:Vote(player, id)\n\tif typeof(id) ~= \"string\" or not self.services[id] then return { ok = false, message = \"Choose an available game.\" } end\n\tif self.state:GetAttribute(\"Phase\") ~= \"Voting\" or self:ActiveGame() or not self.autoEnabled then return { ok = false, message = \"Voting opens between rounds.\" } end\n\tif player:GetAttribute(\"PCDataReady\") ~= true then return { ok = false, message = \"Your player data is loading.\" } end\n\tif not self:GameAvailable(id) then return {ok=false,message=\"This game is not ready for the next round.\"} end\n\tif player:GetAttribute(\"BBParticipating\") or player:GetAttribute(\"TGParticipating\") or player:GetAttribute(\"MDParticipating\") or not self:_insideZone(player) then return { ok = false, message = \"Walk into the voting area first.\" } end\n\tlocal humanoid = player.Character and player.Character:FindFirstChildOfClass(\"Humanoid\")\n\tif not humanoid or humanoid.Health <= 0 then return { ok = false, message = \"Your character is loading.\" } end\n\tlocal now = os.clock()\n\tif now - (self.lastVote[player] or -math.huge) < 0.35 then return { ok = false, message = \"Please wait a moment.\" } end\n\tself.lastVote[player] = now\n\tself.votes[player] = id\n\tplayer:SetAttribute(\"PCVote\", id)\n\tself:_counts()\n\treturn { ok = true, message = \"Vote saved.\" }\nend\n\nfunction Coordinator:StartGame(id, player, role, automatic)\n\tlocal service = self.services[id]\n\tif not service then return false, \"This game is not available yet.\" end\n\tif self:ActiveGame() then return false, \"A game is running. Stop it first.\" end\n\tif not automatic then self:SetAutoEnabled(false) end\n\tself.votingEndsAt = 0\n\tself.state:SetAttribute(\"VotingEndsAt\", 0)\n\tself:_clearVotes()\n\tlocal started, reason\n\tif role then started, reason = service:StartPractice(player, role)\n\telse started, reason = service:StartRound(self:_readyPlayers()) end\n\tif started then\n\t\tself.lastGame = id\n\t\tself.state:SetAttribute(\"ActiveGame\", id)\n\t\tself.state:SetAttribute(\"GameTitle\", titles[id])\n\t\tself.state:SetAttribute(\"Phase\", \"Playing\")\n\tend\n\treturn started, reason\nend\n\nfunction Coordinator:StopGame()\n\tlocal stopped = false\n\tfor _, id in ipairs(games) do\n\t\tif self.services[id] and self.services[id].active then self.services[id]:StopRound() stopped = true end\n\tend\n\tself:SetAutoEnabled(false)\n\tself.state:SetAttribute(\"ActiveGame\", \"\")\n\tself.state:SetAttribute(\"GameTitle\", \"\")\n\treturn true, stopped and \"Back in the lobby.\" or \"Ready in the lobby.\"\nend\n\nfunction Coordinator:_chooseGame()\n\tlocal counts = self:_counts()\n\tlocal readyCount=#self:_readyPlayers()\n\tlocal maximum = 0\n\tfor _, id in ipairs(games) do if self:GameAvailable(id,readyCount) then maximum = math.max(maximum, counts[id]) end end\n\tlocal tied = {}\n\tfor _, id in ipairs(games) do if self:GameAvailable(id,readyCount) and counts[id] == maximum then table.insert(tied, id) end end\n\tif maximum == 0 and self.lastGame then\n\t\tfor _, id in ipairs(tied) do if id ~= self.lastGame then return id end end\n\tend\n\treturn #tied>0 and tied[self.random:NextInteger(1, #tied)] or nil\nend\n\nfunction Coordinator:_rewardBulldog()\n\tlocal service = self.services.BritishBulldog\n\tif service.phase ~= \"Results\" then return end\n\tlocal state = service.state\n\tlocal team = state:GetAttribute(\"WinnerTeam\")\n\tif team ~= \"Runners\" and team ~= \"Bulldogs\" then return end\n\tlocal winnerIds, participantIds = {}, {}\n\tfor player, record in pairs(service.records) do\n\t\tif not record.isBot and record.participating and player.Parent == Players then\n\t\t\ttable.insert(participantIds, player.UserId)\n\t\t\tif (team == \"Runners\" and record.role == \"Runner\") or (team == \"Bulldogs\" and record.role == \"Bulldog\") then table.insert(winnerIds, player.UserId) end\n\t\tend\n\tend\n\ttable.sort(winnerIds)\n\ttable.sort(participantIds)\n\tself.economy:AwardRound(\"BB:\" .. tostring(state:GetAttribute(\"RoundNumber\")), winnerIds, string.find(state:GetAttribute(\"Mode\") or \"\", \"Practice\", 1, true) ~= nil, participantIds, { gameId = \"BritishBulldog\" })\nend\n\nfunction Coordinator:_rewardTag()\n\tlocal state = self.services.TagYoureIt.state\n\tlocal ids, participants = {}, {}\n\tfor value in string.gmatch(state:GetAttribute(\"LastResultWinnerIds\") or \"\", \"%-?%d+\") do table.insert(ids, tonumber(value)) end\n\tfor value in string.gmatch(state:GetAttribute(\"LastResultParticipantIds\") or \"\", \"%-?%d+\") do table.insert(participants, tonumber(value)) end\n\tself.economy:AwardRound(\"TAG:\" .. tostring(state:GetAttribute(\"LastResultRound\")), ids, state:GetAttribute(\"LastResultPractice\") == true, participants, { gameId = \"TagYoureIt\" })\nend\n\nfunction Coordinator:_rewardMud()\n local service=self.services.StuckInTheMud\n if not service then return end\n local state=service.state\n local ids,participants={},{}\n for value in string.gmatch(state:GetAttribute(\"LastResultWinnerIds\") or \"\", \"%-?%d+\") do table.insert(ids,tonumber(value)) end\n for value in string.gmatch(state:GetAttribute(\"LastResultParticipantIds\") or \"\", \"%-?%d+\") do table.insert(participants,tonumber(value)) end\n self.economy:AwardRound(\"MUD:\"..tostring(state:GetAttribute(\"LastResultRound\")),ids,state:GetAttribute(\"LastResultPractice\")==true,participants,{gameId=\"StuckInTheMud\",winnerXP=50,loserXP=50})\nend\n\nfunction Coordinator:_padVoting()\n self.padChoices=self.padChoices or {}\n if self.state:GetAttribute(\"Phase\")~=\"Voting\" then table.clear(self.padChoices) return end\n local choices=self.lobby.Gameplay:FindFirstChild(\"VoteChoices\")\n if not choices then return end\n for _,player in ipairs(Players:GetPlayers()) do\n  local root=player.Character and player.Character:FindFirstChild(\"HumanoidRootPart\")\n  local choice\n  if root and self:_insideZone(player) then\n   for _,pad in ipairs(choices:GetChildren()) do\n    if pad:IsA(\"BasePart\") and pad:GetAttribute(\"Available\")~=false then\n     local point=pad.CFrame:PointToObjectSpace(root.Position)\n     local half=pad.Size/2\n     if math.abs(point.X)<=half.X and math.abs(point.Y)<=half.Y and math.abs(point.Z)<=half.Z then choice=pad:GetAttribute(\"GameId\") break end\n    end\n   end\n  end\n  if choice and not self:GameAvailable(choice) then choice=nil end\n  if choice~=self.padChoices[player] then\n   self.padChoices[player]=choice\n   if choice then self:Vote(player,choice) end\n  end\n end\nend\n\nfunction Coordinator:_loop()\n\twhile self.running do\n\t\tlocal active = self:ActiveGame()\n\t\tlocal readyCount=#self:_readyPlayers()\n\t\tself:_availability(readyCount)\n\t\tlocal now = workspace:GetServerTimeNow()\n\t\tif active then\n\t\t\tself.votingEndsAt = 0\n\t\t\tself.state:SetAttribute(\"Phase\", \"Playing\")\n\t\t\tself.state:SetAttribute(\"ActiveGame\", active)\n\t\t\tself.state:SetAttribute(\"GameTitle\", titles[active])\n\t\t\tself.state:SetAttribute(\"VotingEndsAt\", 0)\n\t\telseif not self.autoEnabled then\n\t\t\tself.state:SetAttribute(\"Phase\", \"Paused\")\n\t\t\tself.state:SetAttribute(\"ActiveGame\", \"\")\n\t\t\tself.state:SetAttribute(\"GameTitle\", \"\")\n\t\telseif readyCount < 2 then\n\t\t\tself.votingEndsAt = 0\n\t\t\tself.state:SetAttribute(\"Phase\", \"Waiting\")\n\t\t\tself.state:SetAttribute(\"ActiveGame\", \"\")\n\t\t\tself.state:SetAttribute(\"GameTitle\", \"\")\n\t\t\tself.state:SetAttribute(\"VotingEndsAt\", 0)\n\t\t\tself:_clearVotes()\n\t\telseif self.votingEndsAt == 0 then\n\t\t\tself:_clearVotes()\n\t\t\tself.votingEndsAt = now + 35\n\t\t\tself.state:SetAttribute(\"Phase\", \"Voting\")\n\t\t\tself.state:SetAttribute(\"ActiveGame\", \"\")\n\t\t\tself.state:SetAttribute(\"VotingEndsAt\", self.votingEndsAt)\n\t\telseif now >= self.votingEndsAt then\n\t\t\tlocal selected = self:_chooseGame()\n\t\t\tself.votingEndsAt = 0\n\t\t\tlocal started = self:StartGame(selected, nil, nil, true)\n\t\t\tif not started then self.state:SetAttribute(\"Phase\", \"Waiting\") end\n\t\tend\n\t\tself:_padVoting()\n\t\ttask.wait(0.25)\n\tend\nend\n\nfunction Coordinator:Start()\n\tif self.running then return end\n\tself.running = true\n\tself.state:SetAttribute(\"AutomaticRounds\", true)\n\tself.state:SetAttribute(\"Phase\", \"Waiting\")\n\tself.state:SetAttribute(\"ActiveGame\", \"\")\n\tself.state:SetAttribute(\"VotingEndsAt\", 0)\n\tself:_counts()\n\tlocal remote = ReplicatedStorage:WaitForChild(\"PlaygroundVoteRequest\")\n\tremote.OnServerInvoke = function(player, id) return self:Vote(player, id) end\n\tself.remote = remote\n\ttable.insert(self.connections, Players.PlayerRemoving:Connect(function(player)\n\t\tself.votes[player] = nil\n\t\tself.lastVote[player] = nil\n\t\tself:_counts()\n\tend))\n\ttable.insert(self.connections, self.services.BritishBulldog.state:GetAttributeChangedSignal(\"Phase\"):Connect(function() self:_rewardBulldog() end))\n\ttable.insert(self.connections, self.services.TagYoureIt.state:GetAttributeChangedSignal(\"LastResultRound\"):Connect(function() self:_rewardTag() end))\n\tif self.services.StuckInTheMud then table.insert(self.connections,self.services.StuckInTheMud.state:GetAttributeChangedSignal(\"LastResultRound\"):Connect(function() self:_rewardMud() end)) end\n\ttask.spawn(function() self:_loop() end)\nend\n\nfunction Coordinator:Stop()\n\tself.running = false\n\tself:StopGame()\n\tfor _, connection in ipairs(self.connections) do connection:Disconnect() end\n\tif self.remote then self.remote.OnServerInvoke = nil end\nend\n\nreturn Coordinator\n\n\r\n"]=======]), "Coordinator changed since AFK snapshot; preserve live edits")
assert(not StarterGui:FindFirstChild("PlaygroundSessionControls"), "Session UI already exists")
assert(not ReplicatedStorage:FindFirstChild("PlaygroundSessionRequest"), "Session request already exists")
assert(not ServerStorage:FindFirstChild("SessionModesBackup20261007"), "Session backup already exists")
local gui=(function()
local ink = Color3.fromRGB(24, 30, 51)
local cream = Color3.fromRGB(255, 249, 229)
local skins = {
	Panel = "rbxassetid://117403446558356",
	Blue = "rbxassetid://90528629970043",
	Gold = "rbxassetid://84589903135132",
	Green = "rbxassetid://78972575698291",
	Red = "rbxassetid://96220174131051",
	Disabled = "rbxassetid://101720017581430",
}

local function label(parent, name, text, position, size, maximum, minimum)
	local object = Instance.new("TextLabel")
	object.Name = name
	object.BackgroundTransparency = 1
	object.BorderSizePixel = 0
	object.Position = position
	object.Size = size
	object.Text = text
	object.Font = Enum.Font.FredokaOne
	object.TextColor3 = cream
	object.TextScaled = true
	object.TextWrapped = true
	object.TextStrokeTransparency = 1
	object.ZIndex = parent.ZIndex + 2
	object.Parent = parent
	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize = minimum or 10
	limit.MaxTextSize = maximum or 18
	limit.Parent = object
	local stroke = Instance.new("UIStroke")
	stroke.Name = "TextOutline"
	stroke.Color = ink
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	stroke.BorderStrokePosition = Enum.BorderStrokePosition.Outer
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Thickness = 0.085
	stroke.Parent = object
	return object
end

local function skin(parent, image)
	local object = Instance.new("ImageLabel")
	object.Name = "ReusableSkin"
	object.BackgroundTransparency = 1
	object.Size = UDim2.fromScale(1, 1)
	object.Image = image
	object.ScaleType = Enum.ScaleType.Slice
	object.SliceCenter = Rect.new(88, 88, 424, 232)
	object.SliceScale = 0.25
	object.ZIndex = parent.ZIndex
	object.Parent = parent
	return object
end

local function button(parent, name, text, position, size, image)
	local object = Instance.new("TextButton")
	object.Name = name
	object.Position = position
	object.Size = size
	object.BackgroundTransparency = 1
	object.Text = ""
	object.AutoButtonColor = false
	object.ZIndex = parent:IsA("GuiObject") and parent.ZIndex + 1 or 2
	object:SetAttribute("NormalImage", image)
	object:SetAttribute("SelectedImage", skins.Green)
	object:SetAttribute("DisabledImage", skins.Disabled)
	object.Parent = parent
	skin(object, image)
	label(object, "Label", text, UDim2.fromOffset(8, 6), UDim2.new(1, -16, 1, -14), 18, 10)
	return object
end

local gui = Instance.new("ScreenGui")
gui.Name = "PlaygroundSessionControls"
gui.ResetOnSpawn = false
gui.DisplayOrder = 32
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui:SetAttribute("AuthoredUIVersion", 1)
gui:SetAttribute("Spectating", false)
gui:SetAttribute("SpectatingUserId", 0)
gui:SetAttribute("SessionMenuOpen", false)
local backdrop = Instance.new("TextButton")
backdrop.Name = "MenuBackdrop"
backdrop.BackgroundTransparency = 0.7
backdrop.BackgroundColor3 = ink
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.Text = ""
backdrop.AutoButtonColor = false
backdrop.Selectable = false
backdrop.ZIndex = 1
backdrop.Visible = false
backdrop.Parent = gui
local toggle = button(gui, "Toggle", "•••", UDim2.fromOffset(126, 8), UDim2.fromOffset(44, 44), skins.Blue)
toggle.ZIndex = 5
toggle.ReusableSkin.ZIndex = 5
toggle.Label.ZIndex = 7
toggle.Label:FindFirstChildOfClass("UITextSizeConstraint").MaxTextSize = 24
local dock = Instance.new("Frame")
dock.Name = "Dock"
dock.BackgroundTransparency = 1
dock.AnchorPoint = Vector2.new(0.5, 0)
dock.Position = UDim2.new(0.5, 0, 0, 76)
dock.Size = UDim2.fromOffset(232, 104)
dock.ZIndex = 2
dock.Visible = false
dock.Parent = gui
local afk = button(dock, "AFK", "AFK: OFF", UDim2.fromOffset(0, 0), UDim2.fromOffset(112, 48), skins.Gold)
local spectate = button(dock, "Spectate", "SPECTATE", UDim2.fromOffset(120, 0), UDim2.fromOffset(112, 48), skins.Blue)
afk.NextSelectionRight = spectate
spectate.NextSelectionLeft = afk
label(dock, "Notice", "", UDim2.fromOffset(0, 50), UDim2.fromOffset(232, 32), 12, 10)
local hint = label(dock, "Hint", "D-PAD UP: CONTROLS", UDim2.fromOffset(0, 86), UDim2.fromOffset(232, 16), 10, 9)
hint.Visible = false
local panel = Instance.new("Frame")
panel.Name = "SpectatePanel"
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.Position = UDim2.new(0.5, 0, 1, -80)
panel.Size = UDim2.fromOffset(304, 146)
panel.BackgroundTransparency = 1
panel.ZIndex = 3
panel.Visible = false
panel.Parent = gui
skin(panel, skins.Panel)
label(panel, "Title", "SPECTATING", UDim2.fromOffset(58, 8), UDim2.fromOffset(188, 16), 13, 10)
label(panel, "PlayerName", "PLAYER", UDim2.fromOffset(56, 26), UDim2.fromOffset(192, 23), 18, 10)
label(panel, "Username", "@Username", UDim2.fromOffset(56, 50), UDim2.fromOffset(192, 16), 12, 10)
label(panel, "Counter", "1 / 1", UDim2.fromOffset(12, 8), UDim2.fromOffset(40, 16), 12, 10)
local previous = button(panel, "Previous", "<", UDim2.fromOffset(8, 24), UDim2.fromOffset(44, 48), skins.Blue)
local nextButton = button(panel, "Next", ">", UDim2.fromOffset(252, 24), UDim2.fromOffset(44, 48), skins.Blue)
local exit = button(panel, "Exit", "BACK TO LOBBY", UDim2.fromOffset(72, 72), UDim2.fromOffset(160, 44), skins.Red)
previous.NextSelectionRight = exit
exit.NextSelectionLeft = previous
exit.NextSelectionRight = nextButton
nextButton.NextSelectionLeft = exit
label(panel, "Controls", "ARROWS: PLAYER   BACKSPACE: EXIT", UDim2.fromOffset(10, 118), UDim2.fromOffset(284, 12), 10, 9)
label(panel, "JoinStatus", "YOU WILL JOIN THE NEXT ROUND", UDim2.fromOffset(10, 130), UDim2.fromOffset(284, 12), 10, 9)
return gui
end)()
local controller=StarterGui.PlaygroundEmoteWheel.Controller:Clone()
controller.Name="Controller"
controller.Source=[=======[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local gui = script.Parent
local dock = gui:WaitForChild("Dock")
local toggle = gui:WaitForChild("Toggle")
local backdrop = gui:WaitForChild("MenuBackdrop")
local panel = gui:WaitForChild("SpectatePanel")
local state = ReplicatedStorage:WaitForChild("PlaygroundState")
local remote = ReplicatedStorage:WaitForChild("PlaygroundSessionRequest")
local afkButton = dock:WaitForChild("AFK")
local watchButton = dock:WaitForChild("Spectate")
local connections = {}
local watching = false
local menuOpen = false
local target
local savedCamera
local savedSelection
local watchingGame
local watchingRound
local busy = false
local alive = true
local requestSerial = 0
local requestWorker
local controlsWorker
local playerControls
local controlsWereEnabled
local noticeUntil = 0
local actionName = "PlaygroundSessionControls"
local movementAction = "PlaygroundSpectateMovement"
local movementStep = "PlaygroundSpectateHoldPosition"
local participatingNames = { "BBParticipating", "TGParticipating", "MDParticipating" }
local roundStates = { BritishBulldog = "BritishBulldogState", TagYoureIt = "TagState", StuckInTheMud = "MudState" }
local roundAttributes = { BritishBulldog = "BBParticipating", TagYoureIt = "TGParticipating", StuckInTheMud = "MDParticipating" }
local refresh

local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end

local function inRound()
	for _, name in ipairs(participatingNames) do
		if player:GetAttribute(name) == true then return true end
	end
	return false
end

local function gamepadActive()
	return string.find(UserInputService:GetLastInputType().Name, "Gamepad", 1, true) ~= nil
end

local function otherModalOpen()
	if GuiService.MenuIsOpen then return true end
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then return false end
	for name, panels in pairs({
		PlaygroundShell = { "ShopPanel", "VotePanel", "CompactVotePanel" },
		PlaygroundEmoteWheel = { "Panel" },
		PlaygroundAdminPanel = { "Panel", "CompactPanel", "AdminHub" },
	}) do
		local other = playerGui:FindFirstChild(name)
		if other and other.Enabled then
			for _, panelName in ipairs(panels) do
				local object = other:FindFirstChild(panelName)
				if object and object.Visible then return true end
			end
		end
	end
	return false
end

local function activeRound()
	local gameId = state:GetAttribute("ActiveGame")
	local roundState = roundStates[gameId] and ReplicatedStorage:FindFirstChild(roundStates[gameId])
	if state:GetAttribute("Phase") ~= "Playing" or not roundState then return nil end
	local phase = roundState:GetAttribute("Phase")
	if phase == "Waiting" or phase == "Results" or phase == "Intermission" then return nil end
	return gameId, roundState:GetAttribute("RoundNumber")
end

local function targetsFor(gameId)
	local result = {}
	local attribute = roundAttributes[gameId]
	if not attribute then return result end
	for _, candidate in ipairs(Players:GetPlayers()) do
		local character = candidate.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if candidate ~= player and candidate:GetAttribute(attribute) == true and humanoid and humanoid.Health > 0 and character:FindFirstChild("HumanoidRootPart") then
			table.insert(result, candidate)
		end
	end
	table.sort(result, function(a, b) return a.UserId < b.UserId end)
	return result
end

local function tell(message)
	dock.Notice.Text = message
	noticeUntil = os.clock() + 4
end

local function buttonState(button, enabled, selected)
	button.Active = enabled
	button.Interactable = enabled
	button.Selectable = enabled
	button.ReusableSkin.Image = button:GetAttribute(not enabled and "DisabledImage" or selected and "SelectedImage" or "NormalImage")
end

local function disableMovement()
	if playerControls and controlsWereEnabled == nil then
		controlsWereEnabled = playerControls.controlsEnabled ~= false
		if controlsWereEnabled then playerControls:Disable() end
	end
end

local function restoreMovement()
	if playerControls and controlsWereEnabled then playerControls:Enable() end
	controlsWereEnabled = nil
end

local function closeMenu()
	menuOpen = false
	gui:SetAttribute("SessionMenuOpen", false)
	local selected = GuiService.SelectedObject
	if selected and selected:IsDescendantOf(gui) then GuiService.SelectedObject = savedSelection and savedSelection.Parent and savedSelection or nil end
end

local function exitSpectate(message)
	if not watching then return end
	watching = false
	target = nil
	watchingGame = nil
	watchingRound = nil
	gui:SetAttribute("Spectating", false)
	gui:SetAttribute("SpectatingUserId", 0)
	ContextActionService:UnbindAction(movementAction)
	restoreMovement()
	local camera = workspace.CurrentCamera
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if camera then
		local subject = humanoid or (savedCamera and savedCamera.subject and savedCamera.subject.Parent and savedCamera.subject)
		camera.CameraSubject = subject
		camera.CameraType = inRound() and Enum.CameraType.Custom or (savedCamera and savedCamera.kind or Enum.CameraType.Custom)
		if savedCamera and not inRound() then
			camera.CFrame = savedCamera.cframe
			camera.Focus = savedCamera.focus
		end
	end
	savedCamera = nil
	local selected = GuiService.SelectedObject
	if selected and selected:IsDescendantOf(gui) then
		GuiService.SelectedObject = savedSelection and savedSelection.Parent and savedSelection or nil
	end
	savedSelection = nil
	panel.Visible = false
	if message then tell(message) end
end

local function setTarget(candidate)
	local humanoid = candidate and candidate.Character and candidate.Character:FindFirstChildOfClass("Humanoid")
	local camera = workspace.CurrentCamera
	if not camera or not humanoid or humanoid.Health <= 0 then return false end
	target = candidate
	camera.CameraType = Enum.CameraType.Custom
	camera.CameraSubject = humanoid
	gui:SetAttribute("SpectatingUserId", candidate.UserId)
	panel.PlayerName.Text = candidate.DisplayName
	panel.Username.Text = "@" .. candidate.Name
	return true
end

local function stepTarget(direction)
	if not watching then return end
	local list = targetsFor(watchingGame)
	if #list == 0 then exitSpectate("No players left to watch.") return end
	local index = table.find(list, target)
	local nextIndex = index and ((index - 1 + direction) % #list + 1) or 1
	setTarget(list[nextIndex])
	panel.Counter.Text = string.format("%d / %d", nextIndex, #list)
end

local function startSpectate()
	if watching or inRound() or otherModalOpen() or not gui.Enabled then return end
	local gameId, roundNumber = activeRound()
	local list = targetsFor(gameId)
	local camera = workspace.CurrentCamera
	if not gameId or #list == 0 or not camera then tell("No round to watch yet.") return end
	savedCamera = { subject = camera.CameraSubject, kind = camera.CameraType, cframe = camera.CFrame, focus = camera.Focus }
	local selected = GuiService.SelectedObject
	if not selected or not selected:IsDescendantOf(gui) then savedSelection = selected end
	watching = true
	closeMenu()
	disableMovement()
	watchingGame = gameId
	watchingRound = roundNumber
	gui:SetAttribute("Spectating", true)
	panel.Visible = true
	ContextActionService:BindActionAtPriority(movementAction, function()
		return watching and Enum.ContextActionResult.Sink or Enum.ContextActionResult.Pass
	end, false, Enum.ContextActionPriority.High.Value + 2,
		Enum.PlayerActions.CharacterForward, Enum.PlayerActions.CharacterBackward,
		Enum.PlayerActions.CharacterLeft, Enum.PlayerActions.CharacterRight, Enum.PlayerActions.CharacterJump)
	stepTarget(1)
	if gamepadActive() then GuiService.SelectedObject = panel.Exit end
	refresh()
end

local function toggleAFK()
	if busy or not gui.Enabled then return end
	busy = true
	requestSerial += 1
	local serial = requestSerial
	refresh()
	requestWorker = task.spawn(function()
		local ok, response = pcall(remote.InvokeServer, remote, "SetAFK", player:GetAttribute("PCAFKRequested") ~= true)
		if not alive or serial ~= requestSerial then return end
		requestWorker = nil
		busy = false
		if ok and typeof(response) == "table" then tell(response.message or "AFK updated.") else tell("Could not update AFK. Try again.") end
		refresh()
	end)
	task.delay(8, function()
		if alive and busy and serial == requestSerial then
			requestSerial += 1
			busy = false
			if requestWorker then pcall(task.cancel, requestWorker) requestWorker = nil end
			tell("AFK request timed out. Try again.")
			refresh()
		end
	end)
end

refresh = function()
	if not alive then return end
	local modal = otherModalOpen()
	local participating = inRound()
	if modal or not gui.Enabled then closeMenu() end
	local gameId, roundNumber = activeRound()
	local localHumanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if watching then
		if participating or not gui.Enabled or modal or not localHumanoid or localHumanoid.Health <= 0 then
			exitSpectate()
		elseif not gameId or gameId ~= watchingGame or roundNumber ~= watchingRound then
			exitSpectate("The round has ended.")
		else
			disableMovement()
			local list = targetsFor(gameId)
			local index = table.find(list, target)
			if not index then
				stepTarget(1)
			else
				local camera = workspace.CurrentCamera
				local humanoid = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
				if camera and humanoid and (camera.CameraSubject ~= humanoid or camera.CameraType ~= Enum.CameraType.Custom) then setTarget(target) end
				panel.Counter.Text = string.format("%d / %d", index, #list)
			end
		end
	end
	dock.Visible = gui.Enabled and not modal and not watching and menuOpen
	backdrop.Visible = dock.Visible
	toggle.Visible = gui.Enabled and not modal and not watching
	panel.Visible = watching and not modal
	local requested = player:GetAttribute("PCAFKRequested") == true
	local queued = player:GetAttribute("PCAFKQueued") == true
	panel.JoinStatus.Text = requested and "AFK ON • STAYING IN LOBBY" or "YOU WILL JOIN THE NEXT ROUND"
	afkButton.Label.Text = queued and "AFK NEXT ROUND" or requested and "AFK: ON" or "AFK: OFF"
	buttonState(afkButton, not busy, requested)
	buttonState(toggle, true, requested)
	watchButton.Visible = not participating and not watching
	buttonState(watchButton, gameId ~= nil and #targetsFor(gameId) > 0)
	if os.clock() >= noticeUntil then
		dock.Notice.Text = queued and "After this round" or requested and "Staying in the lobby" or ""
	end
	local controller = gamepadActive()
	dock.Hint.Visible = controller
	dock.Hint.Text = "D-PAD UP: CONTROLS"
	panel.Controls.Text = controller and "L1 / R1: PLAYER   B / ○: EXIT" or "ARROWS: PLAYER   BACKSPACE: EXIT"
end

connect(afkButton.Activated, toggleAFK)
connect(toggle.Activated, function()
	if menuOpen then closeMenu() else menuOpen = true gui:SetAttribute("SessionMenuOpen", true) end
	refresh()
end)
connect(backdrop.Activated, function() closeMenu() refresh() end)
connect(watchButton.Activated, startSpectate)
connect(panel.Previous.Activated, function() stepTarget(-1) end)
connect(panel.Next.Activated, function() stepTarget(1) end)
connect(panel.Exit.Activated, function() exitSpectate() refresh() end)
ContextActionService:BindActionAtPriority(actionName, function(_, inputState, input)
	if not gui.Enabled or UserInputService:GetFocusedTextBox() or otherModalOpen() then return Enum.ContextActionResult.Pass end
	local key = input.KeyCode
	if key == Enum.KeyCode.DPadUp then
		if inputState == Enum.UserInputState.Begin then
			local selected = GuiService.SelectedObject
			if not selected or not selected:IsDescendantOf(gui) then savedSelection = selected end
			if not watching then menuOpen = true gui:SetAttribute("SessionMenuOpen", true) refresh() end
			GuiService.SelectedObject = watching and panel.Exit or afkButton
		end
		return Enum.ContextActionResult.Sink
	end
	if key == Enum.KeyCode.ButtonB and not watching then
		local selected = GuiService.SelectedObject
		if menuOpen or (selected and selected:IsDescendantOf(gui)) then
			if inputState == Enum.UserInputState.Begin then closeMenu() refresh() savedSelection = nil end
			return Enum.ContextActionResult.Sink
		end
	end
	if not watching then return Enum.ContextActionResult.Pass end
	if inputState == Enum.UserInputState.Begin then
		if key == Enum.KeyCode.ButtonB or key == Enum.KeyCode.Backspace then exitSpectate() refresh()
		elseif key == Enum.KeyCode.ButtonL1 or key == Enum.KeyCode.Left then stepTarget(-1)
		elseif key == Enum.KeyCode.ButtonR1 or key == Enum.KeyCode.Right then stepTarget(1) end
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.ContextActionPriority.High.Value + 2, Enum.KeyCode.DPadUp, Enum.KeyCode.ButtonB, Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1, Enum.KeyCode.Left, Enum.KeyCode.Right, Enum.KeyCode.Backspace)

for _, name in ipairs({ "PCAFK", "PCAFKRequested", "PCAFKQueued", table.unpack(participatingNames) }) do
	connect(player:GetAttributeChangedSignal(name), refresh)
end
connect(player.CharacterAdded, function() exitSpectate() refresh() end)
connect(player.CharacterRemoving, function() exitSpectate() refresh() end)
connect(Players.PlayerRemoving, function(candidate) if candidate == target then target = nil task.defer(refresh) end end)
connect(UserInputService.LastInputTypeChanged, refresh)
connect(gui:GetPropertyChangedSignal("Enabled"), refresh)
connect(state:GetAttributeChangedSignal("ActiveGame"), refresh)
connect(state:GetAttributeChangedSignal("Phase"), refresh)
RunService:BindToRenderStep(movementStep, Enum.RenderPriority.Input.Value + 1, function()
	if not watching or inRound() then return end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid:Move(Vector3.zero, false) humanoid.Jump = false end
end)
local elapsed = 0
connect(RunService.Heartbeat, function(dt)
	elapsed += dt
	if elapsed >= 0.2 then elapsed = 0 refresh() end
end)
script.Destroying:Connect(function()
	alive = false
	requestSerial += 1
	if requestWorker then pcall(task.cancel, requestWorker) end
	if controlsWorker then pcall(task.cancel, controlsWorker) end
	exitSpectate()
	closeMenu()
	ContextActionService:UnbindAction(actionName)
	ContextActionService:UnbindAction(movementAction)
	RunService:UnbindFromRenderStep(movementStep)
	for _, connection in ipairs(connections) do connection:Disconnect() end
end)
controlsWorker = task.spawn(function()
	local playerScripts = player:WaitForChild("PlayerScripts", 10)
	local playerModule = playerScripts and playerScripts:WaitForChild("PlayerModule", 10)
	if playerModule then
		local ok, controls = pcall(function() return require(playerModule):GetControls() end)
		if ok and controls and alive then
			playerControls = controls
			if watching then disableMovement() end
		end
	end
	controlsWorker = nil
end)
gui:SetAttribute("Spectating", false)
gui:SetAttribute("SessionMenuOpen", false)
gui:SetAttribute("SpectatingUserId", 0)
panel.Visible = false
refresh()]=======]
controller.Enabled=true
controller.Parent=gui
local remote=Instance.new("RemoteFunction")
remote.Name="PlaygroundSessionRequest"
local backup=Instance.new("Folder")
backup.Name="SessionModesBackup20261007"
backup:SetAttribute("CreatedFor","AFK and Spectate")
local previous=coordinator:Clone()
previous.Name="PlaygroundCoordinatorBefore"
previous.Parent=backup
backup.Parent=ServerStorage
local ok,reason=pcall(function()
 remote.Parent=ReplicatedStorage
 gui.Parent=StarterGui
 coordinator.Source=[=======[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Coordinator = {}
Coordinator.__index = Coordinator
local games = { "BritishBulldog", "TagYoureIt", "StuckInTheMud" }
local titles = { BritishBulldog = "British Bulldog", TagYoureIt = "Tag You're It", StuckInTheMud = "Stuck in the Mud" }

function Coordinator.new(services, lobby, economy)
	local self = setmetatable({}, Coordinator)
	self.services = services
	self.lobby = lobby
	self.economy = economy
	self.zone = lobby.Gameplay.VoteZone
	self.state = ReplicatedStorage:WaitForChild("PlaygroundState")
	self.votes = {}
	self.lastVote = {}
	self.lastSessionRequest = {}
	self.sessionConnections = {}
	self.connections = {}
	self.running = false
	self.autoEnabled = true
	self.votingEndsAt = 0
	self.random = Random.new()
	self.lastGame = nil
	return self
end

function Coordinator:ActiveGame()
	for _, id in ipairs(games) do if self.services[id] and self.services[id].active then return id end end
	return nil
end

function Coordinator:_participating(player)
	return player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true or player:GetAttribute("MDParticipating") == true
end

function Coordinator:_afkRequested(player)
	return player:GetAttribute("PCAFK") == true or player:GetAttribute("PCAFKRequested") == true
end

function Coordinator:_syncAFK(player)
	local requested = player:GetAttribute("PCAFKRequested") == true
	local participating = self:_participating(player)
	player:SetAttribute("PCAFK", requested and not participating)
	player:SetAttribute("PCAFKQueued", requested and participating)
end

function Coordinator:SetAFK(player, enabled)
	if player.Parent ~= Players or typeof(enabled) ~= "boolean" then
		return { ok = false, message = "Invalid AFK request." }
	end
	local now = os.clock()
	if now - (self.lastSessionRequest[player] or -math.huge) < 0.4 then
		return { ok = false, message = "Please wait a moment." }
	end
	self.lastSessionRequest[player] = now
	player:SetAttribute("PCAFKRequested", enabled)
	self:_syncAFK(player)
	if enabled then
		self.votes[player] = nil
		if self.padChoices then self.padChoices[player] = nil end
		player:SetAttribute("PCVote", "")
		self:_counts()
	end
	return {
		ok = true,
		afk = player:GetAttribute("PCAFK") == true,
		queued = player:GetAttribute("PCAFKQueued") == true,
		requested = enabled,
		message = enabled and (self:_participating(player) and "AFK after this round." or "AFK on. You will stay in the lobby.") or "AFK off. You can join the next round.",
	}
end

function Coordinator:_watchSessionPlayer(player)
	if self.sessionConnections[player] then return end
	player:SetAttribute("PCAFKRequested", false)
	player:SetAttribute("PCAFK", false)
	player:SetAttribute("PCAFKQueued", false)
	local connections = {}
	self.sessionConnections[player] = connections
	for _, name in ipairs({ "BBParticipating", "TGParticipating", "MDParticipating" }) do
		table.insert(connections, player:GetAttributeChangedSignal(name):Connect(function()
			self:_syncAFK(player)
		end))
	end
end

function Coordinator:_readyPlayers()
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 and not self:_afkRequested(player) and not player:GetAttribute("BBParticipating") and not player:GetAttribute("TGParticipating") and not player:GetAttribute("MDParticipating") and player:GetAttribute("PCDataReady") == true then
			table.insert(list, player)
		end
	end
	return list
end

function Coordinator:MinimumPlayers(id)
	local service=self.services[id]
	local minimum=service and service.arena and service.arena:GetAttribute("MinimumPlayers")
	if typeof(minimum)~="number" or minimum~=minimum or math.abs(minimum)==math.huge then minimum=id=="StuckInTheMud" and 4 or 2 end
	return math.max(2,math.floor(minimum))
end

function Coordinator:GameAvailable(id, readyCount)
	local service=self.services[id]
	if not service then return false end
	if id=="StuckInTheMud" and service.state:GetAttribute("GunAccessReady")==false then return false end
	return (readyCount or #self:_readyPlayers())>=self:MinimumPlayers(id)
end

function Coordinator:_availability(readyCount)
	self.state:SetAttribute("ReadyPlayerCount",readyCount)
	for _,id in ipairs(games) do
	 self.state:SetAttribute("Available"..id,self:GameAvailable(id,readyCount))
	 if self.services[id] then self.state:SetAttribute("Minimum"..id,self:MinimumPlayers(id)) end
	end
end

function Coordinator:_insideZone(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	local point = self.zone.CFrame:PointToObjectSpace(root.Position)
	local half = self.zone.Size / 2
	return math.abs(point.X) <= half.X and math.abs(point.Y) <= half.Y and math.abs(point.Z) <= half.Z
end

function Coordinator:_counts()
	local counts = { BritishBulldog = 0, TagYoureIt = 0, StuckInTheMud = 0 }
	for player, id in pairs(self.votes) do
		if player.Parent == Players and not self:_afkRequested(player) and counts[id] then counts[id] += 1 end
	end
	for id, count in pairs(counts) do self.state:SetAttribute("Votes" .. id, count) end
	return counts
end

function Coordinator:_clearVotes()
	for player in pairs(self.votes) do if player.Parent == Players then player:SetAttribute("PCVote", "") end end
	table.clear(self.votes)
	self:_counts()
end

function Coordinator:SetAutoEnabled(enabled)
	self.autoEnabled = enabled == true
	self.votingEndsAt = 0
	self.state:SetAttribute("AutomaticRounds", self.autoEnabled)
	self.state:SetAttribute("VotingEndsAt", 0)
	if not self:ActiveGame() then
		self.state:SetAttribute("Phase", self.autoEnabled and "Waiting" or "Paused")
		self:_clearVotes()
	end
end

function Coordinator:Vote(player, id)
	if typeof(id) ~= "string" or not self.services[id] then return { ok = false, message = "Choose an available game." } end
	if self.state:GetAttribute("Phase") ~= "Voting" or self:ActiveGame() or not self.autoEnabled then return { ok = false, message = "Voting opens between rounds." } end
	if self:_afkRequested(player) then return { ok = false, message = "Turn AFK off before voting." } end
	if player:GetAttribute("PCDataReady") ~= true then return { ok = false, message = "Your player data is loading." } end
	if not self:GameAvailable(id) then return {ok=false,message="This game is not ready for the next round."} end
	if player:GetAttribute("BBParticipating") or player:GetAttribute("TGParticipating") or player:GetAttribute("MDParticipating") or not self:_insideZone(player) then return { ok = false, message = "Walk into the voting area first." } end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return { ok = false, message = "Your character is loading." } end
	local now = os.clock()
	if now - (self.lastVote[player] or -math.huge) < 0.35 then return { ok = false, message = "Please wait a moment." } end
	self.lastVote[player] = now
	self.votes[player] = id
	player:SetAttribute("PCVote", id)
	self:_counts()
	return { ok = true, message = "Vote saved." }
end

function Coordinator:StartGame(id, player, role, automatic)
	local service = self.services[id]
	if not service then return false, "This game is not available yet." end
	if self:ActiveGame() then return false, "A game is running. Stop it first." end
	if role and (not player or self:_afkRequested(player)) then return false, "Turn AFK off before starting practice." end
	if not automatic then self:SetAutoEnabled(false) end
	self.votingEndsAt = 0
	self.state:SetAttribute("VotingEndsAt", 0)
	self:_clearVotes()
	local started, reason
	if role then started, reason = service:StartPractice(player, role)
	else started, reason = service:StartRound(self:_readyPlayers()) end
	if started then
		self.lastGame = id
		self.state:SetAttribute("ActiveGame", id)
		self.state:SetAttribute("GameTitle", titles[id])
		self.state:SetAttribute("Phase", "Playing")
	end
	return started, reason
end

function Coordinator:StopGame()
	local stopped = false
	for _, id in ipairs(games) do
		if self.services[id] and self.services[id].active then self.services[id]:StopRound() stopped = true end
	end
	self:SetAutoEnabled(false)
	self.state:SetAttribute("ActiveGame", "")
	self.state:SetAttribute("GameTitle", "")
	return true, stopped and "Back in the lobby." or "Ready in the lobby."
end

function Coordinator:_chooseGame()
	local counts = self:_counts()
	local readyCount=#self:_readyPlayers()
	local maximum = 0
	for _, id in ipairs(games) do if self:GameAvailable(id,readyCount) then maximum = math.max(maximum, counts[id]) end end
	local tied = {}
	for _, id in ipairs(games) do if self:GameAvailable(id,readyCount) and counts[id] == maximum then table.insert(tied, id) end end
	if maximum == 0 and self.lastGame then
		for _, id in ipairs(tied) do if id ~= self.lastGame then return id end end
	end
	return #tied>0 and tied[self.random:NextInteger(1, #tied)] or nil
end

function Coordinator:_rewardBulldog()
	local service = self.services.BritishBulldog
	if service.phase ~= "Results" then return end
	local state = service.state
	local team = state:GetAttribute("WinnerTeam")
	if team ~= "Runners" and team ~= "Bulldogs" then return end
	local winnerIds, participantIds = {}, {}
	for player, record in pairs(service.records) do
		if not record.isBot and record.participating and player.Parent == Players then
			table.insert(participantIds, player.UserId)
			if (team == "Runners" and record.role == "Runner") or (team == "Bulldogs" and record.role == "Bulldog") then table.insert(winnerIds, player.UserId) end
		end
	end
	table.sort(winnerIds)
	table.sort(participantIds)
	self.economy:AwardRound("BB:" .. tostring(state:GetAttribute("RoundNumber")), winnerIds, string.find(state:GetAttribute("Mode") or "", "Practice", 1, true) ~= nil, participantIds, { gameId = "BritishBulldog" })
end

function Coordinator:_rewardTag()
	local state = self.services.TagYoureIt.state
	local ids, participants = {}, {}
	for value in string.gmatch(state:GetAttribute("LastResultWinnerIds") or "", "%-?%d+") do table.insert(ids, tonumber(value)) end
	for value in string.gmatch(state:GetAttribute("LastResultParticipantIds") or "", "%-?%d+") do table.insert(participants, tonumber(value)) end
	self.economy:AwardRound("TAG:" .. tostring(state:GetAttribute("LastResultRound")), ids, state:GetAttribute("LastResultPractice") == true, participants, { gameId = "TagYoureIt" })
end

function Coordinator:_rewardMud()
 local service=self.services.StuckInTheMud
 if not service then return end
 local state=service.state
 local ids,participants={},{}
 for value in string.gmatch(state:GetAttribute("LastResultWinnerIds") or "", "%-?%d+") do table.insert(ids,tonumber(value)) end
 for value in string.gmatch(state:GetAttribute("LastResultParticipantIds") or "", "%-?%d+") do table.insert(participants,tonumber(value)) end
 self.economy:AwardRound("MUD:"..tostring(state:GetAttribute("LastResultRound")),ids,state:GetAttribute("LastResultPractice")==true,participants,{gameId="StuckInTheMud",winnerXP=50,loserXP=50})
end

function Coordinator:_padVoting()
 self.padChoices=self.padChoices or {}
 if self.state:GetAttribute("Phase")~="Voting" then table.clear(self.padChoices) return end
 local choices=self.lobby.Gameplay:FindFirstChild("VoteChoices")
 if not choices then return end
 for _,player in ipairs(Players:GetPlayers()) do
  local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  local choice
  if root and not self:_afkRequested(player) and self:_insideZone(player) then
   for _,pad in ipairs(choices:GetChildren()) do
    if pad:IsA("BasePart") and pad:GetAttribute("Available")~=false then
     local point=pad.CFrame:PointToObjectSpace(root.Position)
     local half=pad.Size/2
     if math.abs(point.X)<=half.X and math.abs(point.Y)<=half.Y and math.abs(point.Z)<=half.Z then choice=pad:GetAttribute("GameId") break end
    end
   end
  end
  if choice and not self:GameAvailable(choice) then choice=nil end
  if choice~=self.padChoices[player] then
   self.padChoices[player]=choice
   if choice then self:Vote(player,choice) end
  end
 end
end

function Coordinator:_loop()
	while self.running do
		local active = self:ActiveGame()
		local readyCount=#self:_readyPlayers()
		self:_availability(readyCount)
		local now = workspace:GetServerTimeNow()
		if active then
			self.votingEndsAt = 0
			self.state:SetAttribute("Phase", "Playing")
			self.state:SetAttribute("ActiveGame", active)
			self.state:SetAttribute("GameTitle", titles[active])
			self.state:SetAttribute("VotingEndsAt", 0)
		elseif not self.autoEnabled then
			self.state:SetAttribute("Phase", "Paused")
			self.state:SetAttribute("ActiveGame", "")
			self.state:SetAttribute("GameTitle", "")
		elseif readyCount < 2 then
			self.votingEndsAt = 0
			self.state:SetAttribute("Phase", "Waiting")
			self.state:SetAttribute("ActiveGame", "")
			self.state:SetAttribute("GameTitle", "")
			self.state:SetAttribute("VotingEndsAt", 0)
			self:_clearVotes()
		elseif self.votingEndsAt == 0 then
			self:_clearVotes()
			self.votingEndsAt = now + 35
			self.state:SetAttribute("Phase", "Voting")
			self.state:SetAttribute("ActiveGame", "")
			self.state:SetAttribute("VotingEndsAt", self.votingEndsAt)
		elseif now >= self.votingEndsAt then
			local selected = self:_chooseGame()
			self.votingEndsAt = 0
			local started = self:StartGame(selected, nil, nil, true)
			if not started then self.state:SetAttribute("Phase", "Waiting") end
		end
		self:_padVoting()
		task.wait(0.25)
	end
end

function Coordinator:Start()
	if self.running then return end
	self.running = true
	self.state:SetAttribute("AutomaticRounds", true)
	self.state:SetAttribute("Phase", "Waiting")
	self.state:SetAttribute("ActiveGame", "")
	self.state:SetAttribute("VotingEndsAt", 0)
	self:_counts()
	local remote = ReplicatedStorage:WaitForChild("PlaygroundVoteRequest")
	remote.OnServerInvoke = function(player, id) return self:Vote(player, id) end
	self.remote = remote
	local sessionRemote = ReplicatedStorage:WaitForChild("PlaygroundSessionRequest")
	sessionRemote.OnServerInvoke = function(player, action, value)
		if action ~= "SetAFK" then return { ok = false, message = "Invalid session request." } end
		return self:SetAFK(player, value)
	end
	self.sessionRemote = sessionRemote
	table.insert(self.connections, Players.PlayerAdded:Connect(function(player) self:_watchSessionPlayer(player) end))
	for _, player in ipairs(Players:GetPlayers()) do self:_watchSessionPlayer(player) end
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player)
		self.votes[player] = nil
		self.lastVote[player] = nil
		self.lastSessionRequest[player] = nil
		for _, connection in ipairs(self.sessionConnections[player] or {}) do connection:Disconnect() end
		self.sessionConnections[player] = nil
		self:_counts()
	end))
	table.insert(self.connections, self.services.BritishBulldog.state:GetAttributeChangedSignal("Phase"):Connect(function() self:_rewardBulldog() end))
	table.insert(self.connections, self.services.TagYoureIt.state:GetAttributeChangedSignal("LastResultRound"):Connect(function() self:_rewardTag() end))
	if self.services.StuckInTheMud then table.insert(self.connections,self.services.StuckInTheMud.state:GetAttributeChangedSignal("LastResultRound"):Connect(function() self:_rewardMud() end)) end
	task.spawn(function() self:_loop() end)
end

function Coordinator:Stop()
	self.running = false
	self:StopGame()
	for _, connection in ipairs(self.connections) do connection:Disconnect() end
	if self.remote then self.remote.OnServerInvoke = nil end
	if self.sessionRemote then self.sessionRemote.OnServerInvoke = nil end
	for player, connections in pairs(self.sessionConnections) do
		for _, connection in ipairs(connections) do connection:Disconnect() end
		if player.Parent == Players then
			player:SetAttribute("PCAFKRequested", false)
			player:SetAttribute("PCAFK", false)
			player:SetAttribute("PCAFKQueued", false)
		end
	end
	table.clear(self.sessionConnections)
	table.clear(self.lastSessionRequest)
end

return Coordinator


]=======]
end)
if not ok then
 coordinator.Source=previous.Source
 gui:Destroy()
 remote:Destroy()
 error(reason)
end
assert(controller.Capabilities==StarterGui.PlaygroundEmoteWheel.Controller.Capabilities, "UI permissions changed")
assert(coordinator.Capabilities==previous.Capabilities,"Coordinator permissions changed")
return game:GetService("HttpService"):JSONEncode({
 coordinatorBytes=#coordinator.Source,controllerBytes=#controller.Source,
 gui=gui:GetFullName(),remote=remote:GetFullName(),backup=backup:GetFullName(),
 capabilitiesUnchanged=true
})
