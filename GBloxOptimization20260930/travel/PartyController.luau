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

-- Supplied Teleporting UI artwork; all queue state/timing stays server-driven.
local waitingPanel=Instance.new("ImageLabel")
waitingPanel.Name="WaitingPanel" waitingPanel.AnchorPoint=Vector2.new(.5,1)
waitingPanel.Position=UDim2.fromScale(.5,.83) waitingPanel.Size=UDim2.fromScale(.9,.2)
waitingPanel.BackgroundTransparency=1 waitingPanel.BorderSizePixel=0
waitingPanel.Image="rbxassetid://107928590559526"
waitingPanel.ScaleType=Enum.ScaleType.Stretch waitingPanel.ZIndex=8
waitingPanel.Visible=false waitingPanel.Parent=inParty
local panelSize=Instance.new("UISizeConstraint")
panelSize.MaxSize=Vector2.new(430,130) panelSize.Parent=waitingPanel
local panelAspect=Instance.new("UIAspectRatioConstraint")
panelAspect.AspectRatio=430/130 panelAspect.DominantAxis=Enum.DominantAxis.Width panelAspect.Parent=waitingPanel
local waitingLabel=Instance.new("TextLabel")
waitingLabel.Name="WaitingStatus" waitingLabel.AnchorPoint=Vector2.new(.5,.5)
waitingLabel.Position=UDim2.fromScale(.5,.47) waitingLabel.Size=UDim2.fromScale(.9,.73)
waitingLabel.BackgroundTransparency=1 waitingLabel.TextColor3=Color3.new(0,0,0)
waitingLabel.TextStrokeColor3=Color3.new(1,1,1) waitingLabel.TextStrokeTransparency=.6
waitingLabel.Font=Enum.Font.Arcade waitingLabel.TextScaled=true waitingLabel.TextWrapped=true
waitingLabel.ZIndex=9 waitingLabel.Text="" waitingLabel.Parent=waitingPanel
local textLimit=Instance.new("UITextSizeConstraint")
textLimit.MaxTextSize=22 textLimit.MinTextSize=12 textLimit.Parent=waitingLabel
task.spawn(function()
 pcall(function() game:GetService("ContentProvider"):PreloadAsync({waitingPanel}) end)
end)
local lowestPlayers = 2
local selectedPlayers = lowestPlayers
local selectedBots = 0
local currentPlayers = 1
local highestPlayers = 6
local expiresAt = 0
local createDuration = 20
local isLeader = false
local statusVersion = 0

local function showCreate(visible)
	background.Visible = visible
	expireBar.Visible = visible
end

local function hide()
 statusVersion += 1
	showCreate(false)
 waitingPanel.Visible=false
	leaveButton.Visible = false
	ui.Enabled = false
	expiresAt = 0
end

local function refreshCounts()
		selectedPlayers =
		math.clamp(
			selectedPlayers,
			math.max(
				currentPlayers,
				lowestPlayers
			),
			highestPlayers
		)

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
			math.max(
				currentPlayers,
				lowestPlayers
			)
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
            statusVersion += 1
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
            statusVersion += 1
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
 waitingPanel.Visible=data.State=="Waiting" or data.State=="Teleporting"
 waitingLabel.Text=data.State=="Teleporting" and "Teleporting..." or ("Waiting for players: "..tostring(currentPlayers).."/"..tostring(selectedPlayers).."\n"..(data.TimeLeft and ("Starting in "..tostring(data.TimeLeft).." seconds") or "Gathering players..."))
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

        elseif action == "TravelStatus" then
            statusVersion += 1
            ui.Enabled = true
            showCreate(false)
            waitingPanel.Visible = true
            waitingLabel.Text = tostring(data or "Reconnecting...")
            leaveButton.Visible = false
        elseif action == "Error" then
            statusVersion += 1
            local version = statusVersion
            ui.Enabled = true
            showCreate(false)
            waitingPanel.Visible = true
            waitingLabel.Text = tostring(data or "Something went wrong. Please try again.")
            leaveButton.Visible = false
            task.delay(8, function()
                if version == statusVersion then hide() end
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
