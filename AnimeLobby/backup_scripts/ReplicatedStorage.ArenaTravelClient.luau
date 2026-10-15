local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local player = Players.LocalPlayer
local travel = ReplicatedStorage:WaitForChild("ArenaEvents"):WaitForChild("TravelRequest")
local ArenaTravelClient = {}
local savedLighting
local controls

local function request(action)
	local ok, success, message = pcall(function()
		return travel:InvokeServer(action)
	end)
	if not ok then return false, "Travel is unavailable" end
	return success, message
end

local function setControls(enabled)
	if not controls then
		local module = player.PlayerScripts:FindFirstChild("PlayerModule")
		if module then controls = require(module):GetControls() end
	end
	if controls then
		if enabled then controls:Enable() else controls:Disable() end
	end
end

function ArenaTravelClient.enter()
	local success, message = request("Enter")
	if not success then return false, message end
	if not savedLighting then
		savedLighting = {}
		for _, key in ipairs({ "ClockTime", "Brightness", "Ambient", "OutdoorAmbient" }) do
			savedLighting[key] = Lighting[key]
		end
	end
	Lighting.ClockTime = 13.5
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(130, 140, 150)
	Lighting.OutdoorAmbient = Color3.fromRGB(165, 180, 195)
	setControls(false)
	return true
end

function ArenaTravelClient.restore()
	if savedLighting then
		for key, value in pairs(savedLighting) do Lighting[key] = value end
		savedLighting = nil
	end
	setControls(true)
end

function ArenaTravelClient.leave()
	local success, message = request("Leave")
	if success then ArenaTravelClient.restore() end
	return success, message
end

function ArenaTravelClient.toLobbyPortal()
	return request("LobbyPortal")
end

function ArenaTravelClient.toPackShop()
	return request("PackPortal")
end

return ArenaTravelClient


