local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local PackShopUI = require(ReplicatedStorage:WaitForChild("PackShopUI"))
local PlayerData = require(ReplicatedStorage:WaitForChild("PlayerData"))
local ArenaTravelClient = require(ReplicatedStorage:WaitForChild("ArenaTravelClient"))

local btnGui = playerGui:WaitForChild("PacksButtonGui")
local packsBtn = btnGui:WaitForChild("PacksBtn")
local packBadge = packsBtn:WaitForChild("PackBadge")
local function totalPacks()
	local n = 0
	for _, c in pairs(PlayerData.allPackCounts()) do n += c end
	return n
end
local function refreshPackBadge()
	local n = totalPacks()
	packBadge.Visible = n > 0
	packBadge.Text = tostring(n)
end
refreshPackBadge()
PlayerData.Changed:Connect(refreshPackBadge)
packsBtn.Activated:Connect(function()
	local success, message = ArenaTravelClient.toPackShop()
	if not success then warn(message) end
end)

local lobby = workspace:WaitForChild("Lobby_MainModeZone")
local zone = lobby:WaitForChild("Lobby_PackShopZone")
local trigger = zone:WaitForChild("PackShopTrigger")
local RADIUS = 11
local inside = false

RunService.Heartbeat:Connect(function()
	local inMatch = player:GetAttribute("ActiveArena") ~= nil

	packsBtn.Visible = not inMatch

	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if inMatch or not hrp then
		if inside then inside = false; PackShopUI.close() end
		return
	end

	local d = (hrp.Position - trigger.Position).Magnitude
	if d <= RADIUS and not inside then
		inside = true
		PackShopUI.open(playerGui)
	elseif d > RADIUS and inside then
		inside = false
		PackShopUI.close()
	end
end)
