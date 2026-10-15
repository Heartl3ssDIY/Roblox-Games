local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local StarterGui = game:GetService("StarterGui")

local Config = require(ReplicatedStorage:WaitForChild("LobbyConfig"))
local ArenaCatalog = require(ReplicatedStorage:WaitForChild("ArenaCatalog"))
local PlayerData = require(ReplicatedStorage:WaitForChild("PlayerData"))
local ArenaSelectionUI = require(ReplicatedStorage:WaitForChild("ArenaSelectionUI"))
local ArenaTravelClient = require(ReplicatedStorage:WaitForChild("ArenaTravelClient"))
local ModePickerUI = require(ReplicatedStorage:WaitForChild("ModePickerUI"))
local PackShopUI = require(ReplicatedStorage:WaitForChild("PackShopUI"))
local PackReveal = require(ReplicatedStorage:WaitForChild("PackReveal"))
local FishingUI = require(ReplicatedStorage:WaitForChild("FishingUI"))
local UnitsUI = require(ReplicatedStorage:WaitForChild("UnitsUI"))
local LevelPassUI = require(ReplicatedStorage:WaitForChild("LevelPassUI"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local lobby = workspace:WaitForChild(Config.RootName or "Lobby_MainModeZone")
local travelGui = playerGui:WaitForChild("LobbyTravelGui")
local travelPanel = travelGui:WaitForChild("Panel")
local travelButtons = travelPanel:WaitForChild("Destinations")
local travelClose = travelPanel:WaitForChild("Close")
local travelConnections = {}
travelGui.Enabled = false
local promptDistance = math.max(0, tonumber(Config.PromptDistance) or 10)
local promptCooldown = math.max(0, tonumber(Config.PromptCooldown) or .4)
local lastPrompt = -math.huge
local lastTravel = -math.huge
local busy = false

local function attribute(prompt, name)
    local current = prompt
    while current and current ~= lobby do
        local value = current:GetAttribute(name)
        if value ~= nil then return value end
        current = current.Parent
    end
    return nil
end

local arenaPrompts = {}

local function refreshArenaPrompt(prompt)
    if not prompt:IsDescendantOf(lobby) or attribute(prompt, "LobbyAction") ~= "Arena" or attribute(prompt, "FreePlay") == false then return end
    local arena = ArenaCatalog.find(attribute(prompt, "ArenaKey"))
    prompt.ActionText = arena and PlayerData.isArenaCompleted(arena.key) and "Open Free Play" or "Locked"
end

local function trackPrompt(instance)
    if not instance:IsA("ProximityPrompt") then return end
    arenaPrompts[instance] = true
    refreshArenaPrompt(instance)
end

for _, descendant in ipairs(lobby:GetDescendants()) do trackPrompt(descendant) end
table.insert(travelConnections, lobby.DescendantAdded:Connect(trackPrompt))
table.insert(travelConnections, lobby.DescendantRemoving:Connect(function(instance)
    arenaPrompts[instance] = nil
end))
table.insert(travelConnections, PlayerData.Changed:Connect(function()
    for prompt in pairs(arenaPrompts) do refreshArenaPrompt(prompt) end
end))

local function notification(title, message)
    pcall(function()
        StarterGui:SetCore("SendNotification", {Title = title, Text = message, Duration = 5})
    end)
end

local function position(prompt)
    local parent = prompt.Parent
    if not parent then return nil end
    if parent:IsA("Attachment") then return parent.WorldPosition end
    if parent:IsA("BasePart") then return parent.Position end
    if parent:IsA("Model") then return parent:GetPivot().Position end
    return nil
end

local function allowed(prompt, triggeringPlayer)
    if triggeringPlayer and triggeringPlayer ~= player then return false end
    if not lobby:IsDescendantOf(workspace) or not prompt:IsA("ProximityPrompt") or not prompt.Enabled or not prompt:IsDescendantOf(lobby) then return false end
    if player:GetAttribute("ActiveArena") ~= nil or ArenaSelectionUI.isBusy() or PackReveal.isOpen() then return false end
    local character = player.Character
    if not character or not character:IsDescendantOf(workspace) then return false end
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then return false end
    local target = position(prompt)
    if not target then return false end
    local distance = math.min(promptDistance, prompt.MaxActivationDistance)
    return (root.Position - target).Magnitude <= distance + 1
end

local function closeOtherPanels(action)
    if action ~= "Fishing" then FishingUI.close() end
    if action ~= "TravelMenu" then travelGui.Enabled = false end
    if action ~= "Story" then ModePickerUI.close() end
    if action ~= "Arena" then ArenaSelectionUI.close() end
    if action ~= "Summon" then PackShopUI.close() end
    if action ~= "Units" then UnitsUI.close() end
    if action ~= "BattlePass" then LevelPassUI.close() end
    if action ~= "Shop" then
        local shopGui = playerGui:FindFirstChild("ShopGui")
        if shopGui then shopGui.Enabled = false end
    end
end

local function dispatch(prompt)
    local action = attribute(prompt, "LobbyAction")
    if action == "Arena" then
        local arena = ArenaCatalog.find(attribute(prompt, "ArenaKey"))
        if not arena then return false, "That arena is unavailable." end
        local index
        for current = 1, ArenaCatalog.count() do
            if ArenaCatalog.get(current).key == arena.key then index = current; break end
        end
        if not index then return false, "That arena is unavailable." end
        local success, message = ArenaSelectionUI.open(playerGui, index, attribute(prompt, "FreePlay") ~= false)
        if not success then return false, message end
        closeOtherPanels("Arena")
    elseif action == "Story" then
        ModePickerUI.build(playerGui)
        closeOtherPanels("Story")
        ModePickerUI.open()
    elseif action == "Summon" then
        closeOtherPanels("Summon")
        PackShopUI.open(playerGui)
    elseif action == "Shop" then
        local shopGui = playerGui:FindFirstChild("ShopGui")
        if not shopGui or not shopGui:IsA("ScreenGui") then return false, "The shop is unavailable." end
        closeOtherPanels("Shop")
        shopGui.Enabled = true
    elseif action == "Units" then
        closeOtherPanels("Units")
        UnitsUI.open(playerGui)
    elseif action == "BattlePass" then
        closeOtherPanels("BattlePass")
        LevelPassUI.open(playerGui)
    elseif action == "Fishing" then
        closeOtherPanels("Fishing")
        FishingUI.open(playerGui)
    elseif action == "Notice" then
        local title = attribute(prompt, "NoticeTitle")
        local message = attribute(prompt, "NoticeText")
        if type(message) ~= "string" or message == "" then return false, "This destination is not available yet." end
        notification(type(title) == "string" and title ~= "" and title or "Anime Combat Units", message)
    elseif action == "TravelMenu" then
        closeOtherPanels("TravelMenu")
        travelGui.Enabled = true
    elseif action == "Travel" then
        local destination = attribute(prompt, "Destination")
        if type(destination) ~= "string" or destination == "" then return false, "That destination is unavailable." end
        local success, message = ArenaTravelClient.toDestination(destination)
        if not success then return false, message or "Travel is unavailable." end
        closeOtherPanels("Travel")
    else
        return false, "This destination is not available yet."
    end
    return true
end

local connection = ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeringPlayer)
    if busy or os.clock() - lastPrompt < promptCooldown or not allowed(prompt, triggeringPlayer) then return end
    lastPrompt = os.clock()
    busy = true
    local ok, success, message = pcall(dispatch, prompt)
    busy = false
    if not ok then
        warn("Lobby destination could not open: " .. tostring(success))
        notification("Anime Combat Units", "This destination is temporarily unavailable.")
    elseif not success then
        notification("Anime Combat Units", message or "This destination is unavailable.")
    end
end)

local function menuTravel(button)
    if busy or os.clock() - lastTravel < promptCooldown then return end
    if player:GetAttribute("ActiveArena") ~= nil or ArenaSelectionUI.isBusy() or PackReveal.isOpen() then return end
    if not travelGui.Enabled or not button:IsDescendantOf(travelButtons) then return end
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not character or not character:IsDescendantOf(workspace) or not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then return end
    local destination = button:GetAttribute("Destination")
    if type(destination) ~= "string" or destination == "" then
        notification("Travel", "That destination is unavailable.")
        return
    end
    busy = true
    lastTravel = os.clock()
    local ok, success, message = pcall(ArenaTravelClient.toDestination, destination)
    busy = false
    if ok and success then
        travelGui.Enabled = false
    else
        notification("Travel", ok and message or "Travel is temporarily unavailable.")
    end
end

table.insert(travelConnections, travelClose.Activated:Connect(function()
    travelGui.Enabled = false
end))
for _, button in ipairs(travelButtons:GetChildren()) do
    if button:IsA("GuiButton") then
        table.insert(travelConnections, button.Activated:Connect(function() menuTravel(button) end))
    end
end
table.insert(travelConnections, player:GetAttributeChangedSignal("ActiveArena"):Connect(function()
    if player:GetAttribute("ActiveArena") ~= nil then
        travelGui.Enabled = false
        FishingUI.close()
    end
end))
table.insert(travelConnections, player.CharacterRemoving:Connect(function()
    travelGui.Enabled = false
    FishingUI.close()
end))

script.Destroying:Connect(function()
    connection:Disconnect()
    for _, item in ipairs(travelConnections) do item:Disconnect() end
end)
