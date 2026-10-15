local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local queueEvent =
	ReplicatedStorage:WaitForChild(
		"QueueEvent"
	)

local ui = script.Parent
local create = ui:WaitForChild("Create")
local inParty = ui:WaitForChild("InParty")

local background =
	create:WaitForChild("Background")

local expireBar =
	create:WaitForChild("ExpireBar")

local percentage =
	expireBar:WaitForChild("Percentage")

local createButton =
	background:WaitForChild("CreateButton")

local title =
	background:WaitForChild("Title")

local playerCount =
	background.PlayerCount.Frame.TextLabel

local playerAdd =
	background.PlayerCount.Frame.Add

local playerSubtract =
	background.PlayerCount.Frame.Subtract

-- Bot controls are optional until that part of the party UI is added.
local botSection = background:FindFirstChild("BotCount")
local botFrame = botSection and botSection:FindFirstChild("Frame")
local botCount = botFrame and botFrame:FindFirstChild("TextLabel")
local botAdd = botFrame and botFrame:FindFirstChild("Add")
local botSubtract = botFrame and botFrame:FindFirstChild("Subtract")

local leaveButton =
	inParty:WaitForChild("LeaveButton")

local selectedPlayers = 1
local selectedBots = 0
local currentPlayers = 1
local highestPlayers = 10
local expiresAt = 0
local createDuration = 20
local isLeader = false

local function showCreate(visible)
	background.Visible = visible
	expireBar.Visible = visible
end

local function hide()
	showCreate(false)
	leaveButton.Visible = false
	ui.Enabled = false
	expiresAt = 0
end

local function refreshCounts()
	playerCount.Text =
		tostring(selectedPlayers)

	if botCount then
		botCount.Text = tostring(selectedBots)
	end
end

local function sendOptions()
	queueEvent:FireServer(
		"SetOptions",
		{
			PlayerCount = selectedPlayers,
			BotCount = selectedBots
		}
	)
end

playerAdd.Activated:Connect(function()
	selectedPlayers =
		math.min(
			selectedPlayers + 1,
			highestPlayers - selectedBots
		)

	refreshCounts()
	sendOptions()
end)

playerSubtract.Activated:Connect(function()
	selectedPlayers =
		math.max(
			selectedPlayers - 1,
			currentPlayers
		)

	refreshCounts()
	sendOptions()
end)

if botAdd then
botAdd.Activated:Connect(function()
	selectedBots =
		math.min(
			selectedBots + 1,
			highestPlayers - selectedPlayers
		)

	refreshCounts()
	sendOptions()
end)

end

if botSubtract then
botSubtract.Activated:Connect(function()
	selectedBots =
		math.max(
			selectedBots - 1,
			0
		)

	refreshCounts()
	sendOptions()
end)

end

createButton.Activated:Connect(function()
	sendOptions()
	queueEvent:FireServer("Create")
end)

leaveButton.Activated:Connect(function()
	queueEvent:FireServer("Leave")
end)

queueEvent.OnClientEvent:Connect(
	function(action, data)
		if action == "ShowCreate" then
			data = data or {}

			selectedPlayers =
				tonumber(
					data.PlayerCount
				) or selectedPlayers

			selectedBots =
				tonumber(
					data.BotCount
				) or selectedBots

			highestPlayers =
				tonumber(
					data.HighestPlayer
				) or highestPlayers

			expiresAt =
				tonumber(
					data.ExpiresAt
				) or 0

			createDuration =
				math.max(
					expiresAt
					- workspace:GetServerTimeNow(),
					1
				)

			isLeader = true

			title.Text = "Create Party"
			ui.Enabled = true
			leaveButton.Visible = true
			showCreate(true)
			refreshCounts()

		elseif action == "PartyState" then
			data = data or {}

			currentPlayers =
				tonumber(
					data.Players
				) or currentPlayers

			selectedPlayers =
				tonumber(
					data.MaxPlayers
				) or selectedPlayers

			selectedBots =
				tonumber(
					data.BotCount
				) or selectedBots

			isLeader =
				data.IsLeader == true

			highestPlayers =
				tonumber(
					data.HighestPlayer
				) or highestPlayers

			if isLeader
				and data.State == "Configuring"
				and tonumber(data.ExpiresAt) then

				expiresAt = data.ExpiresAt
				createDuration =
					math.max(
						expiresAt
						- workspace:GetServerTimeNow(),
						1
					)
			end

			ui.Enabled = true
			leaveButton.Visible =
				data.State ~= "Teleporting"

			showCreate(
				isLeader
				and data.State
					== "Configuring"
			)

			if data.State == "Waiting" then
				title.Text =
					"Waiting "
					.. tostring(
						data.TimeLeft
						or ""
					)

			elseif data.State == "Teleporting" then
				title.Text =
					"Teleporting"
			end

			refreshCounts()

		elseif action == "Error" then
			ui.Enabled = true
			title.Text =
				tostring(data or "Something went wrong")

			task.delay(3, function()
				if title.Text ==
					tostring(
						data
						or "Something went wrong"
					) then

					title.Text =
						"Create Party"
				end
			end)

		elseif action == "Hide" then
			hide()
		end
	end
)

RunService.RenderStepped:Connect(function()
	if expiresAt <= 0
		or not expireBar.Visible then

		return
	end

	local remaining =
		math.max(
			expiresAt
			- workspace:GetServerTimeNow(),
			0
		)

	local duration =
		math.max(
			createDuration,
			1
		)

	percentage.Size =
		UDim2.new(
			math.clamp(
				remaining / duration,
				0,
				1
			),
			0,
			1,
			0
		)
end)

hide()
