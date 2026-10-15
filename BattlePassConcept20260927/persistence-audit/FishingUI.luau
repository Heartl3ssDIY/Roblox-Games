local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PlayerData = require(ReplicatedStorage:WaitForChild("PlayerData"))
local request = ReplicatedStorage:WaitForChild("ArenaEvents"):WaitForChild("FishingRequest")
local player = Players.LocalPlayer

local FishingUI = {}
local gui, panel, renderConnection
local cast
local busy = false
local creditedClaims = {}
local openSerial = 0

local function meterPosition(now, round)
    local phase = ((now - round.startedAt) / round.period + round.offset) % 2
    return phase <= 1 and phase or 2 - phase
end

local function invoke(action, token)
    local ok, response = pcall(function()
        return request:InvokeServer(action, token)
    end)
    if not ok or type(response) ~= "table" then
        return { ok = false, message = "Fishing is temporarily unavailable." }
    end
    return response
end

local function refresh()
    panel.Cast.Interactable = not busy and cast == nil
    panel.Reel.Interactable = not busy and cast ~= nil
end

function FishingUI.close()
    if not gui then return end
    openSerial += 1
    gui.Enabled = false
    if cast then
        local token = cast.token
        cast = nil
        task.spawn(function() invoke("Cancel", token) end)
    end
    refresh()
end

local function start()
    if busy or cast then return end
    busy = true
    refresh()
    local serial = openSerial
    local response = invoke("Start")
    busy = false
    if serial ~= openSerial or not gui.Enabled then
        if response.ok and response.token then
            task.spawn(function() invoke("Cancel", response.token) end)
        end
        refresh()
        return
    end
    if response.ok then
        cast = response
        panel.ProgressTrack.CatchBand.Position =
            UDim2.fromScale((response.targetMin + response.targetMax) / 2, 0.5)
        panel.ProgressTrack.CatchBand.Size =
            UDim2.fromScale(response.targetMax - response.targetMin, 1)
        panel.Status.Text = "Tap REEL while the marker is inside the catch band!"
    else
        panel.Status.Text = response.message or "Unable to cast."
    end
    refresh()
end

local function reel()
    if busy or not cast then return end
    busy = true
    local token = cast.token
    cast = nil
    refresh()
    local response = invoke("Reel", token)
    busy = false
    if response.ok and response.caught then
        if type(response.claimId) == "string" and not creditedClaims[response.claimId] then
            creditedClaims[response.claimId] = true
            PlayerData.addPack(response.packId, 1)
        end
        panel.Status.Text = response.message or "Common Pack earned for this session."
    else
        panel.Status.Text = response.message or "The fish got away."
    end
    refresh()
end

function FishingUI.build(playerGui)
    if gui then return gui end
    gui = playerGui:WaitForChild("FishingGui")
    panel = gui:WaitForChild("Panel")
    panel.Cast.Activated:Connect(start)
    panel.Reel.Activated:Connect(reel)
    panel.Close.Activated:Connect(FishingUI.close)
    renderConnection = RunService.RenderStepped:Connect(function()
        if not gui.Enabled or not cast then return end
        local position = meterPosition(workspace:GetServerTimeNow(), cast)
        panel.ProgressTrack.Cursor.Position = UDim2.fromScale(position, 0.5)
    end)
    gui.Destroying:Connect(function()
        if renderConnection then renderConnection:Disconnect() end
        cast = nil
        gui = nil
        panel = nil
    end)
    gui.Enabled = false
    refresh()
    return gui
end

function FishingUI.open(playerGui)
    FishingUI.build(playerGui or player:WaitForChild("PlayerGui"))
    openSerial += 1
    panel.Status.Text = "Cast your line, then reel inside the catch band."
    gui.Enabled = true
    return true
end

return FishingUI


