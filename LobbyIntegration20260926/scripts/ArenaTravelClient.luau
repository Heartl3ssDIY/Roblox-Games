local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local player = Players.LocalPlayer
local travel = ReplicatedStorage:WaitForChild("ArenaEvents"):WaitForChild("TravelRequest")
local ArenaCatalog = require(ReplicatedStorage:WaitForChild("ArenaCatalog"))
local PlayerData = require(ReplicatedStorage:WaitForChild("PlayerData"))
local ArenaTravelClient = {}
local savedLighting
local controls

local function request(action, destination)
	local ok, success, message = pcall(function()
		return travel:InvokeServer(action, destination)
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

local function enterArena(action, arenaName)
	local success, message = request(action, arenaName)
	if not success then return false, message end
	if not savedLighting then
		savedLighting = {}
		for _, key in ipairs({ "ClockTime", "Brightness", "Ambient", "OutdoorAmbient", "ExposureCompensation" }) do
			savedLighting[key] = Lighting[key]
		end
	end
	Lighting.ClockTime = 13.5
	Lighting.Brightness = 1.9
	Lighting.ExposureCompensation = -0.25
	Lighting.Ambient = Color3.fromRGB(108, 119, 132)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 153, 167)
	setControls(action == "Visit")
	return true
end

function ArenaTravelClient.enter(arenaName)
    return enterArena("Enter", arenaName)
end

function ArenaTravelClient.visit(arenaName)
    local arena = ArenaCatalog.find(arenaName)
    if not arena or not PlayerData.isArenaCompleted(arena.key) then
        return false, "Complete this arena in Story Mode to unlock free play."
    end
    return enterArena("Visit", arena.modelName)
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

function ArenaTravelClient.toDestination(destination)
	return request("Destination", destination)
end

return ArenaTravelClient

