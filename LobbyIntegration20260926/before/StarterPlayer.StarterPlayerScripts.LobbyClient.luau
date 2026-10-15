local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local TweenService   = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ArenaTravelClient = require(ReplicatedStorage:WaitForChild("ArenaTravelClient"))

local player     = Players.LocalPlayer
local playerGui  = player:WaitForChild("PlayerGui")
local character  = player.Character or player.CharacterAdded:Wait()

player.CharacterAdded:Connect(function(c)
    character = c
end)

local mmz       = workspace:WaitForChild("Lobby_MainModeZone")
local spawnPart = mmz:WaitForChild("MainModeSpawn")
local ringOuter = mmz:WaitForChild("RingOuter")

local RING_RADIUS = 11

local C = {
    bg      = Color3.fromRGB(18, 12, 36),
    panel   = Color3.fromRGB(32, 20, 62),
    border  = Color3.fromRGB(148, 88, 255),
    accent  = Color3.fromRGB(180, 120, 255),
    btnBg   = Color3.fromRGB(50, 28, 98),
    btnHov  = Color3.fromRGB(78, 48, 145),
    btnTxt  = Color3.fromRGB(230, 210, 255),
    title   = Color3.fromRGB(220, 190, 255),
    sub     = Color3.fromRGB(155, 130, 195),
    close   = Color3.fromRGB(200, 70, 95),
    play    = Color3.fromRGB(90, 215, 130),
    playTxt = Color3.fromRGB(15, 55, 28),
    gold    = Color3.fromRGB(255, 210, 80),
    lock    = Color3.fromRGB(90, 80, 120),
    lockTxt = Color3.fromRGB(140, 120, 170),
    arena   = Color3.fromRGB(22, 14, 48),
    arenaBorder = Color3.fromRGB(255, 180, 50),
}

local function corner(p, r)
    Instance.new("UICorner", p).CornerRadius = UDim.new(0, r or 14)
end
local function stroke(p, col, thick)
    local s = Instance.new("UIStroke", p)
    s.Color = col or C.border; s.Thickness = thick or 2
end

local playGui = playerGui:WaitForChild("PlayButtonGui")
local playBtn = playGui:WaitForChild("PlayBtn")
playBtn.Activated:Connect(function()
    local success, message = ArenaTravelClient.toLobbyPortal()
    if not success then warn(message) end
end)

local ModePickerUI = require(ReplicatedStorage:WaitForChild("ModePickerUI"))
local modeGui = ModePickerUI.build(playerGui)
local mainBtn = modeGui.Panel.Content.Main

local ArenaSelectionUI = require(ReplicatedStorage:WaitForChild("ArenaSelectionUI"))
local arenaGui = ArenaSelectionUI.build(playerGui)
mainBtn.Activated:Connect(function()
    ArenaSelectionUI.open(playerGui)
end)

local onRing = false

RunService.Heartbeat:Connect(function()
    if player:GetAttribute("ActiveArena") then
        onRing = false
        modeGui.Enabled = false
        return
    end
    local c = player.Character; if not c then return end
    local hrp = c:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    local pos = hrp.Position
    local dist = Vector2.new(pos.X - ringOuter.Position.X, pos.Z - ringOuter.Position.Z).Magnitude
    local inside = dist <= RING_RADIUS + 1

    if inside and not onRing then
        onRing = true
        ModePickerUI.open()
    elseif not inside and onRing then
        onRing = false
        if modeGui.Enabled then
            ModePickerUI.close()
        end
    end
end)
