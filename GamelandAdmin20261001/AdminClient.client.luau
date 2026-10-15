local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local gui = script.Parent
local panel = gui.Panel
local remote = game:GetService("ReplicatedStorage"):WaitForChild("GamelandAdmin"):WaitForChild("Request")
local selectedId
local scope = "Self"
local cards = {}
local games = {}
local busy = false
local messageUntil = 0
local colors = {ink = Color3.fromRGB(20, 29, 52), muted = Color3.fromRGB(99, 114, 137),
    cyan = Color3.fromRGB(87, 222, 223), white = Color3.new(1, 1, 1), blue = Color3.fromRGB(55, 133, 249)}

local function showMessage(message, ok)
    panel.Status.Text = message
    panel.Status.TextColor3 = ok and colors.muted or Color3.fromRGB(176, 46, 68)
    messageUntil = os.clock() + 5
end

local function updateSelection()
    for id, card in pairs(cards) do
        card.BackgroundColor3 = id == selectedId and Color3.fromRGB(211, 248, 248) or colors.white
        card.SelectedTag.Visible = id == selectedId
    end
    local entry = games[selectedId]
    panel.Description.Text = entry and entry.description or "No testable minigames are registered yet."
    panel.StartTest.Active = entry ~= nil and not busy
    panel.StopTest.Active = entry ~= nil and not busy
    panel.Visit.Active = entry ~= nil and not busy
end

local function render(data)
    local seen = {}
    for index, entry in ipairs(data.games or {}) do
        seen[entry.id] = true
        games[entry.id] = entry
        local card = cards[entry.id]
        if not card then
            card = gui.Templates.MinigameCard:Clone()
            card.Name = entry.id card.Visible = true card.Parent = panel.GameList
            card.Activated:Connect(function()
                selectedId = entry.id
                updateSelection()
            end)
            cards[entry.id] = card
        end
        card.LayoutOrder = index
        card.GameName.Text = entry.name
        card.Badge.Text = entry.badge
        card.GameStatus.Text = (entry.phase == "Active" and ("RUNNING  /  " .. entry.remaining .. " STILL IN"))
            or (entry.phase == "Preparing" and "GETTING READY") or "READY TO TEST"
    end
    for id, card in pairs(cards) do
        if not seen[id] then card:Destroy() cards[id] = nil games[id] = nil end
    end
    if not selectedId or not seen[selectedId] then selectedId = data.games and data.games[1] and data.games[1].id end
    panel.LobbyScope.Text = "All lobby players (" .. (data.readyPlayers or 0) .. ")"
    updateSelection()
end

local function request(action)
    if busy or not gui.Enabled then return end
    busy = true
    if action ~= "Catalog" then panel.Status.Text = "Working..." end
    local ok, result = pcall(function()
        return remote:InvokeServer({action = action, gameId = selectedId, scope = scope})
    end)
    busy = false
    if not ok or type(result) ~= "table" then
        showMessage("Could not reach the server. Try again.", false)
        return
    end
    if result.data then render(result.data) end
    if result.message and action ~= "Catalog" then showMessage(result.message, result.ok) end
    if action == "Catalog" and not result.ok then showMessage(result.message or "Admin access unavailable.", false) end
    if result.ok and (action == "Start" or action == "Visit") then
        panel.Visible = false gui.Shade.Visible = false
    end
    updateSelection()
end

local function setOpen(open)
    if not gui.Enabled then return end
    panel.Visible = open gui.Shade.Visible = open
    if open then task.spawn(request, "Catalog") end
end

local function permissionChanged()
    gui.Enabled = player:GetAttribute("GamelandAdmin") == true
    if not gui.Enabled then panel.Visible = false gui.Shade.Visible = false end
end
player:GetAttributeChangedSignal("GamelandAdmin"):Connect(permissionChanged)
permissionChanged()
gui.Open.Activated:Connect(function() setOpen(not panel.Visible) end)
gui.Shade.Activated:Connect(function() setOpen(false) end)
panel.Header.Close.Activated:Connect(function() setOpen(false) end)
UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.F4 then setOpen(not panel.Visible) end
end)
panel.SelfScope.Activated:Connect(function()
    scope = "Self" panel.SelfScope.BackgroundColor3 = colors.cyan panel.LobbyScope.BackgroundColor3 = colors.white
end)
panel.LobbyScope.Activated:Connect(function()
    scope = "Lobby" panel.LobbyScope.BackgroundColor3 = colors.cyan panel.SelfScope.BackgroundColor3 = colors.white
end)
panel.StartTest.Activated:Connect(function() request("Start") end)
panel.StopTest.Activated:Connect(function() request("Stop") end)
panel.Visit.Activated:Connect(function() request("Visit") end)
panel.Return.Activated:Connect(function() request("Lobby") end)

while gui.Parent do
    if gui.Enabled and panel.Visible then
        request("Catalog")
        if os.clock() > messageUntil then
            panel.Status.Text = scope == "Self" and "Only you will join the next test." or "All available lobby players will join the next test."
            panel.Status.TextColor3 = colors.muted
        end
    end
    task.wait(2)
end
