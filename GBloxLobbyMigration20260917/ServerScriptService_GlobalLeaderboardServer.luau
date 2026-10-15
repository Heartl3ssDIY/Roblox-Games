local Players = game:GetService("Players")

local PlayerData = require(
	game.ServerScriptService:WaitForChild(
		"PlayerData"
	)
)

local display = workspace:WaitForChild("LeaderboardDisplay")

local boards = display
local podiums = display
local nameCache = {}

local boardConfigs = {
	{
		Model = boards:WaitForChild("WinsBoard"),
		Store = PlayerData.OrderedStores.Wins,
		Ascending = false,
		Format = function(value)
			return tostring(math.floor(value)) .. " wins"
		end,
		Podium = podiums:WaitForChild(
			"WinsChampion"
		),
		Label = "MOST WINS",
	},
	{
		Model = boards:WaitForChild("CashBoard"),
		Store = PlayerData.OrderedStores.TotalCash,
		Ascending = false,
		Format = function(value)
			return "$"
				.. tostring(
					math.floor(value)
				)
		end,
	},
	{
		Model = boards:WaitForChild("FastestBoard"),
		Store = PlayerData.OrderedStores.FastestTime,
		Ascending = true,
		Format = function(value)
			return string.format(
				"%.2fs",
				value / 1000
			)
		end,
		Podium = podiums:WaitForChild(
			"FastestChampion"
		),
		Label = "FASTEST 5-ROUND TIME",
	},
}

local function playerName(userId)
	if nameCache[userId] then
		return nameCache[userId]
	end

	local success, result = pcall(
		Players.GetNameFromUserIdAsync,
		Players,
		userId
	)

	local name =
		success and result
		or "Player " .. tostring(userId)

	nameCache[userId] = name
	return name
end

local function setRow(row, rank, name, value)
	row.Rank.Text = tostring(rank)
	row.Player.Text = name
	row.Value.Text = value
end

local function readBoard(config)
	local entries
	local success, message = pcall(function()
		local pages =
			config.Store:GetSortedAsync(
				config.Ascending,
				10
			)

		entries = pages:GetCurrentPage()
	end)

	if not success then
		warn(
			"[Leaderboards] Could not refresh",
			config.Model.Name,
			message
		)

		return nil, message
	end

	return entries
end

local function clearAvatar(podium)
	local old =
		podium:FindFirstChild(
			"ChampionAvatar"
		)

	if old then
		old:Destroy()
	end
end

local function updateChampion(
	podium,
	userId,
	name,
	value,
	labelText
)
	local label =
		podium.SignAnchor.ChampionGui.ChampionLabel

	if not userId then
		clearAvatar(podium)
		podium:SetAttribute("ChampionUserId", 0)
		label.Text =
			"#1 "
			.. labelText
			.. string.char(10)
			.. "No champion yet"

		return
	end

	label.Text =
		"#1 "
		.. labelText
		.. string.char(10)
		.. name
		.. "  "
		.. value

	if podium:GetAttribute("ChampionUserId")
		== userId then

		return
	end

	clearAvatar(podium)

	local success, avatar = pcall(function()
		local description =
			Players:GetHumanoidDescriptionFromUserId(
				userId
			)

		return Players:CreateHumanoidModelFromDescription(
			description,
			Enum.HumanoidRigType.R15
		)
	end)

	if not success or not avatar then
		warn(
			"[Leaderboards] Could not display champion",
			userId,
			avatar
		)

		return
	end

	avatar.Name = "ChampionAvatar"

	for _, object in ipairs(
		avatar:GetDescendants()
	) do
		if object:IsA("BasePart") then
			object.Anchored = true
			object.CanCollide = false
			object.CanTouch = false
			object.CanQuery = false
		elseif object:IsA("Script")
			or object:IsA("LocalScript") then

			object:Destroy()
		end
	end

	local humanoid =
		avatar:FindFirstChildOfClass(
			"Humanoid"
		)

	if humanoid then
		humanoid.DisplayDistanceType =
			Enum.HumanoidDisplayDistanceType.None
	end

	avatar.Parent = podium

	local anchor = podium.AvatarAnchor
	avatar:PivotTo(
		CFrame.lookAt(
			anchor.Position,
			anchor.Position
				- anchor.CFrame.RightVector
		)
	)

	local highlight = Instance.new("Highlight")
	highlight.Name = "ChampionOutline"
	highlight.FillTransparency = 1
	highlight.OutlineColor =
		podium.UpperStep.Color
	highlight.OutlineTransparency = 0
	highlight.Parent = avatar

	podium:SetAttribute(
		"ChampionUserId",
		userId
	)
end

local function refreshBoard(config)
	local rows =
		config.Model.Screen.BoardGui.Background.Rows

	local entries, message = readBoard(config)

	if not entries then
		for rank = 1, 10 do
			local row =
				rows:FindFirstChild(
					"Row" .. rank
				)

			if row then
				setRow(
					row,
					rank,
					rank == 1
						and "Rankings unavailable"
						or "",
					""
				)
			end
		end

		return
	end

	for rank = 1, 10 do
		local row =
			rows:FindFirstChild(
				"Row" .. rank
			)

		local entry = entries[rank]

		if row and entry then
			local userId =
				tonumber(entry.key)

			local name =
				userId
				and playerName(userId)
				or "Unknown"

			setRow(
				row,
				rank,
				name,
				config.Format(entry.value)
			)
		elseif row then
			setRow(
				row,
				rank,
				"No record yet",
				"--"
			)
		end
	end

	if config.Podium then
		local top = entries[1]
		local userId =
			top and tonumber(top.key)

		updateChampion(
			config.Podium,
			userId,
			userId and playerName(userId),
			top and config.Format(top.value),
			config.Label
		)
	end
end

local function refreshAll()
	for _, config in ipairs(boardConfigs) do
		refreshBoard(config)
	end
end

task.delay(3, refreshAll)

while task.wait(60) do
	refreshAll()
end
