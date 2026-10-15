local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local PlayerData = require(game.ServerScriptService:WaitForChild("PlayerData"))

local Zone = require(
	ReplicatedStorage.Modules.Zone
)

local teleportZones =
	workspace:WaitForChild("TeleportZones")

local configuration =
	teleportZones:WaitForChild("Configuration")

local lobbyPosition =
	teleportZones:WaitForChild("LobbyPos")

local lowestPlayers = 2
local highestPlayers = 6

configuration:WaitForChild(
	"HighestPlayer"
).Value = highestPlayers

local countdownLength =
	math.max(
		1,
		configuration:WaitForChild(
			"Countdown"
		).Value
	)

local createTime =
	math.max(
		1,
		configuration:WaitForChild(
			"TimeBeforeExpires"
		).Value
	)

local defaultPlayers =
	math.min(6, highestPlayers)

local destinationValue =
	configuration:WaitForChild(
		"DestinationPlaceId"
	)

local queueEvent =
	ReplicatedStorage:FindFirstChild(
		"QueueEvent"
	)

if not queueEvent then
	queueEvent = Instance.new("RemoteEvent")
	queueEvent.Name = "QueueEvent"
	queueEvent.Parent = ReplicatedStorage
end

local zoneData = {}
local playerZones = {}

local function getRoot(player)
	local character = player.Character

	if not character then
		return nil
	end

	return character:FindFirstChild(
		"HumanoidRootPart"
	)
end

local function movePlayer(player, part)
	local character = player.Character

	if not character or not part then
		return
	end

	character:PivotTo(
		part.CFrame * CFrame.new(0, 3, 0)
	)
end

local function playerIndex(data, player)
	for index, member in ipairs(data.Players) do
		if member == player then
			return index
		end
	end

	return nil
end

local function leader(data)
	return data.Players[1]
end

local function stateText(data)
	if data.State == "Configuring" then
		return "Creating party..."

	elseif data.State == "Waiting" then
		return "Waiting for players..."

	elseif data.State == "Teleporting" then
		return "Teleporting..."
	end

	return "Waiting for players..."
end

local function updateBillboard(data)
	local billboard =
		data.Model:FindFirstChild(
			"BillboardGui"
		)

	if not billboard then
		return
	end

	local playerCount =
		billboard:FindFirstChild(
			"PlayerCount"
		)

	local stateLabel =
		billboard:FindFirstChild(
			"StateLabel"
		)

	if playerCount then
		playerCount.Text =
			tostring(#data.Players)
			.. "/"
			.. tostring(data.MaxPlayers)
	end

	if stateLabel then
		stateLabel.Text = stateText(data)
	end
end

local function sendPartyState(data, timeLeft)
	local currentLeader = leader(data)

	for _, player in ipairs(data.Players) do
		if player.Parent == Players then
			queueEvent:FireClient(
				player,
				"PartyState",
				{
					Zone = data.Model.Name,
					State = data.State,
					Players = #data.Players,
					MaxPlayers = data.MaxPlayers,
					BotCount = data.BotCount,
					IsLeader = player == currentLeader,
					TimeLeft = timeLeft,
					ExpiresAt = data.ExpiresAt,
					HighestPlayer = highestPlayers
				}
			)
		end
	end
end

local function resetZone(data, movePlayers)
	data.Version += 1

	local oldPlayers =
		table.clone(data.Players)

	table.clear(data.Players)

	data.State = "Idle"
	data.MaxPlayers = defaultPlayers
	data.BotCount = 0
	data.ExpiresAt = 0

	for _, player in ipairs(oldPlayers) do
		if playerZones[player] == data then
			playerZones[player] = nil
            player:SetAttribute("GBloxInParty", false)
		end

		if player.Parent == Players then
			queueEvent:FireClient(
				player,
				"Hide"
			)

			if movePlayers then
				movePlayer(
					player,
					lobbyPosition
				)
			end
		end
	end

	updateBillboard(data)
end

local function removePlayer(
	player,
	data,
	moveToLobby
)
	local index =
		playerIndex(
			data,
			player
		)

	if not index then
		return
	end

	table.remove(
		data.Players,
		index
	)

	if playerZones[player] == data then
		playerZones[player] = nil
        player:SetAttribute("GBloxInParty", false)
	end

	if player.Parent == Players then
		queueEvent:FireClient(
			player,
			"Hide"
		)

		if moveToLobby then
			movePlayer(
				player,
				lobbyPosition
			)
		end
	end

	if #data.Players == 0 then
		resetZone(data, false)
		return
	end

	updateBillboard(data)
	sendPartyState(data)
end

local function teleportParty(data)
	if data.State == "Teleporting"
		or #data.Players == 0 then

		return
	end

	data.State = "Teleporting"
	data.Version += 1

	local party = {}

	for _, player in ipairs(data.Players) do
		if player.Parent == Players then
			table.insert(party, player)
		end
	end

	if #party == 0 then
		resetZone(data, false)
		return
	end

	updateBillboard(data)
	sendPartyState(data, 0)

	local destinationPlaceId = destinationValue.Value

	local options = Instance.new(
		"TeleportOptions"
	)

	options.ShouldReserveServer = true

 local playtimeTickets={}
 for _,player in ipairs(party) do
  local token,reason=PlayerData.PreparePlaytimeTeleport(player,destinationPlaceId)
  if not token then
   for _,prepared in ipairs(party) do
    local ticket=playtimeTickets[tostring(prepared.UserId)]
    if ticket then PlayerData.CancelPlaytimeTeleport(prepared,ticket) end
   end
   for _,member in ipairs(party) do
    if member.Parent==Players then queueEvent:FireClient(member,"Error",reason or "Save busy. Please retry.") end
   end
   resetZone(data,true)
   return
  end
  playtimeTickets[tostring(player.UserId)]=token
 end
 options:SetTeleportData({
  GBloxPlaytimeTickets=playtimeTickets,
		FromLobby = true,
		PartySize = data.MaxPlayers,
		HumanCount = #party,
		BotCount = data.BotCount,
		Zone = data.Model.Name
	})

	local success, message =
		pcall(function()
			TeleportService:TeleportAsync(
				destinationPlaceId,
				party,
				options
			)
		end)

	if not success then
  for _,player in ipairs(party) do PlayerData.CancelPlaytimeTeleport(player,playtimeTickets[tostring(player.UserId)]) end
		warn(
			"[Queue]",
			"Teleport failed:",
			message
		)

		for _, player in ipairs(party) do
			if player.Parent == Players then
				queueEvent:FireClient(
					player,
					"Error",
					"Teleport failed. Please try again."
				)
			end
		end

		resetZone(data, true)
	end
end

TeleportService.TeleportInitFailed:Connect(function(player,_,message,placeId,options)
 if placeId~=destinationValue.Value or not options then return end
 local payload=options:GetTeleportData()
 local tickets=typeof(payload)=="table" and payload.GBloxPlaytimeTickets
 local token=typeof(tickets)=="table" and tickets[tostring(player.UserId)]
 if not token then return end
 PlayerData.CancelPlaytimeTeleport(player,token)
 local data=playerZones[player]
 if data and data.State=="Teleporting" then
  -- Other party members may already be in flight: preserve their handoff tickets.
  warn("[Queue] Teleport initialization failed:",message)
  resetZone(data,true)
 end
end)

local function startCountdown(data)
	if data.State == "Teleporting" then
		return
	end

	data.State = "Waiting"
	data.Version += 1

	local version = data.Version

	updateBillboard(data)

	task.spawn(function()
		for timeLeft = countdownLength, 0, -1 do
			if version ~= data.Version
				or data.State ~= "Waiting" then

				return
			end

			updateBillboard(data)
			sendPartyState(data, timeLeft)

			if #data.Players >= data.MaxPlayers
				or timeLeft == 0 then

				teleportParty(data)
				return
			end

			task.wait(1)
		end
	end)
end

local function startCreateTimer(data)
	data.Version += 1

	local version = data.Version
	local expiresAt =
		workspace:GetServerTimeNow()
		+ createTime

	data.ExpiresAt = expiresAt

	queueEvent:FireClient(
		leader(data),
		"ShowCreate",
		{
			Zone = data.Model.Name,
			PlayerCount = data.MaxPlayers,
			BotCount = data.BotCount,
			HighestPlayer = highestPlayers,
			ExpiresAt = expiresAt
		}
	)

	task.delay(createTime, function()
		if version ~= data.Version
			or data.State ~= "Configuring"
			or #data.Players == 0 then

			return
		end

		startCountdown(data)
	end)
end

local function addPlayer(player, data)
	if player:GetAttribute("GBloxLobbyReady") ~= true then
		return
	end

	local oldData =
		playerZones[player]

	if oldData == data then
		return
	end

	if oldData then
		removePlayer(
			player,
			oldData,
			false
		)
	end

	if data.State == "Teleporting"
		or #data.Players >= data.MaxPlayers then

		movePlayer(player, lobbyPosition)
		return
	end

	table.insert(
		data.Players,
		player
	)

	playerZones[player] = data
 player:SetAttribute("GBloxInParty",true)

	movePlayer(
		player,
		data.Container
	)

	if #data.Players == 1 then
		data.State = "Configuring"
		data.MaxPlayers = defaultPlayers
		data.BotCount = 0

		startCreateTimer(data)
	end

	updateBillboard(data)
	sendPartyState(data)

	if data.State == "Waiting"
		and #data.Players >= data.MaxPlayers then

		teleportParty(data)
	end
end

queueEvent.OnServerEvent:Connect(
	function(player, action, settings)
		local data =
			playerZones[player]

		if action == "Leave" then
			if data
				and data.State
					~= "Teleporting" then

				removePlayer(
					player,
					data,
					true
				)
			end

			return
		end

		if not data
			or leader(data) ~= player
			or data.State ~= "Configuring" then

			return
		end

		if action == "SetOptions"
			and typeof(settings) == "table" then

			local maxPlayers =
				math.clamp(
					math.floor(
						tonumber(
							settings.PlayerCount
						) or data.MaxPlayers
					),
					math.max(
						#data.Players,
						lowestPlayers
					),
					highestPlayers
				)

			local botCount =
				math.clamp(
					math.floor(
						tonumber(
							settings.BotCount
						) or data.BotCount
					),
					0,
					highestPlayers - maxPlayers
				)

			data.MaxPlayers = maxPlayers
			data.BotCount = botCount

			updateBillboard(data)
			sendPartyState(data)

		elseif action == "Create" then
			startCountdown(data)
		end
	end
)

Players.PlayerRemoving:Connect(
	function(player)
		local data =
			playerZones[player]

		if data then
			removePlayer(
				player,
				data,
				false
			)
		end
	end
)

for _, zoneModel in ipairs(
	teleportZones:GetChildren()
) do
	if zoneModel:IsA("Model") then
		local container =
			zoneModel:FindFirstChild(
				"ZoneContainer"
			)

		if container
			and container:IsA("BasePart") then

			local data = {
				Model = zoneModel,
				Container = container,
				Players = {},
				MaxPlayers = defaultPlayers,
				BotCount = 0,
				State = "Idle",
				Version = 0,
				ExpiresAt = 0
			}

			zoneData[zoneModel] = data

			local zone =
				Zone.new(container)

			data.Zone = zone

			zone.playerEntered:Connect(
				function(player)
					addPlayer(
						player,
						data
					)
				end
			)

			zone.playerExited:Connect(
				function(player)
					if playerZones[player] == data
						and data.State
							~= "Teleporting" then

						removePlayer(
							player,
							data,
							false
						)
					end
				end
			)

			updateBillboard(data)
		end
	end
end
