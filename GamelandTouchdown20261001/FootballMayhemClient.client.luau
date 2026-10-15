local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local assets = ReplicatedStorage:WaitForChild("FootballMayhem")
local presentation = require(assets:WaitForChild("Presentation"))
local whistle = assets:WaitForChild("Sounds"):WaitForChild("RoundStartWhistle")
task.spawn(function()
    pcall(function() game:GetService("ContentProvider"):PreloadAsync({whistle}) end)
end)
local arena
local painted = {}
local savedLighting
local savedEffects = {}
local localEffects = {}
local lobbyHUDWasEnabled
local properties = {"ClockTime", "Brightness", "Ambient", "OutdoorAmbient", "ExposureCompensation", "FogStart", "FogEnd", "FogColor"}


local progressWall
local function clearProgressWall()
    if progressWall then progressWall:Destroy() progressWall = nil end
end

local function updateProgressWall()
    local progress = player:GetAttribute("FootballMayhemRowsCompleted") or 0
    if player:GetAttribute("CurrentMinigame") ~= "FootballMayhem"
        or player:GetAttribute("FootballMayhemStatus") ~= "Active" or progress < 1 then
        clearProgressWall()
        return
    end
    if not progressWall then
        progressWall = Instance.new("Part")
        progressWall.Name = "PersonalFootballProgressWall"
        progressWall.Anchored = true
        progressWall.Transparency = 1
        progressWall.CanCollide = true
        progressWall.CanTouch = false
        progressWall.CanQuery = false
        progressWall.Size = Vector3.new(104, 50, 1)
        progressWall.Parent = workspace
    end
    local depth = 1 + (progress - 1) * 22 - 4
    progressWall.CFrame = assets.ArenaOrigin.Value * CFrame.new(0, 23, 110 - depth)
end

for _, attribute in ipairs({"CurrentMinigame", "FootballMayhemStatus", "FootballMayhemRowsCompleted"}) do
    player:GetAttributeChangedSignal(attribute):Connect(updateProgressWall)
end
player.CharacterRemoving:Connect(clearProgressWall)
script.Destroying:Connect(clearProgressWall)
updateProgressWall()

local function restoreTiles()
    presentation.ClearReveals()
    for tile, color in pairs(painted) do if tile.Parent then tile.Color = color end end
    table.clear(painted)
end

local function paint(row, lane, color)
    arena = arena or workspace:FindFirstChild("Oni's Work") and workspace["Oni's Work"]:FindFirstChild("FootballMayhem")
    local rows = arena and arena:FindFirstChild("Rows")
    local rowModel = rows and rows:FindFirstChild(string.format("Row%02d", row))
    local tile = rowModel and rowModel:FindFirstChild("Choice" .. lane)
    if tile then
        if not painted[tile] then painted[tile] = tile.Color end
        tile.Color = color
    end
end

local function enterLighting()
    if savedLighting then return end
    savedLighting = {}
    for _, property in ipairs(properties) do savedLighting[property] = Lighting[property] end
    for _, effect in ipairs(Lighting:GetChildren()) do
        if effect:IsA("Sky") or effect:IsA("Atmosphere") or effect:IsA("PostEffect") then
            table.insert(savedEffects, effect)
            effect.Parent = nil
        end
    end
    for _, effect in ipairs(assets.Environment:GetChildren()) do
        local copy = effect:Clone() copy.Parent = Lighting table.insert(localEffects, copy)
    end
    Lighting.ClockTime = 13.5
    Lighting.Brightness = 2.5
    Lighting.Ambient = Color3.fromRGB(155, 165, 180)
    Lighting.OutdoorAmbient = Color3.fromRGB(170, 183, 201)
    Lighting.ExposureCompensation = 0.15
    Lighting.FogStart = 700
    Lighting.FogEnd = 1800
    Lighting.FogColor = Color3.fromRGB(166, 220, 255)
end

local function exitLighting()
    if not savedLighting then return end
    for _, effect in ipairs(localEffects) do effect:Destroy() end
    table.clear(localEffects)
    for _, effect in ipairs(savedEffects) do effect.Parent = Lighting end
    table.clear(savedEffects)
    for property, value in pairs(savedLighting) do Lighting[property] = value end
    savedLighting = nil
end

assets.Feedback.OnClientEvent:Connect(function(data)
    if type(data) ~= "table" then return end
    if data.kind == "Preparing" then restoreTiles() end
    if data.kind == "Active" then
        local sound = whistle:Clone()
        sound.Parent = game:GetService("SoundService")
        sound:Play()
        game:GetService("Debris"):AddItem(sound, 5)
    end
    if data.kind == "Reveal" then
        paint(data.row, data.dangerLane, Color3.fromRGB(255, 103, 83))
        presentation.Reveal(data.row, data.lane, data.dangerLane)
    end
    if data.kind == "Safe" then
        paint(data.row, data.lane, Color3.fromRGB(133, 255, 86))
    elseif data.kind == "Eliminated" and data.row and data.lane then
        paint(data.row, data.lane, Color3.fromRGB(255, 86, 103))
    end
end)

assets.Effects.OnClientEvent:Connect(function(kind, userId, duration)
    if kind == "Stun" then presentation.Stun(userId, duration)
    elseif kind == "ClearStun" then presentation.ClearStun(userId) end
end)

while script.Parent do
    local current = player:GetAttribute("CurrentMinigame")
    local inGame = current == "FootballMayhem" or current == "FootballMayhemPreview"
    local pg = player:FindFirstChild("PlayerGui")
    local lobby = pg and pg:FindFirstChild("GamelandLobbyHUD")
    if lobby then
        if inGame then
            if lobbyHUDWasEnabled == nil then lobbyHUDWasEnabled = lobby.Enabled end
            lobby.Enabled = false
        elseif lobbyHUDWasEnabled ~= nil then
            lobby.Enabled = lobbyHUDWasEnabled lobbyHUDWasEnabled = nil
        end
    end
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local inside = false
    if root then
        local p = assets.ArenaOrigin.Value:PointToObjectSpace(root.Position)
        inside = math.abs(p.X) < 85 and math.abs(p.Z) < 165 and p.Y > -15 and p.Y < 100
    end
    if inside then enterLighting() else
        exitLighting()
        if next(painted) then restoreTiles() end
    end
    task.wait(0.1)
end
exitLighting()
