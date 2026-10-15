local DRY_RUN = true
local EXPECTED = nil
local ui = game:GetService("StarterGui")
local shop = ui.PlaygroundShell.ShopPanel
local emotes = ui.PlaygroundEmoteWheel.Panel
local toys = ui.PlaygroundToyHotbar.Bar
local changes = {}
local function set(object, property, value)
    assert(object, "Missing authored UI element")
    table.insert(changes, {object, property, value, tostring(object[property])})
end
local function at(object, position, size, anchor)
    set(object, "Position", position)
    set(object, "Size", size)
    if anchor then set(object, "AnchorPoint", anchor) end
end
at(shop, UDim2.fromScale(.5,.5), UDim2.new(.96,0,1,-12), Vector2.new(.5,.5))
set(shop.SizeLimit, "MinSize", Vector2.new(280,260))
at(shop.Title, UDim2.fromOffset(14,8), UDim2.new(1,-180,0,36))
at(shop.Coins, UDim2.new(1,-158,0,12), UDim2.fromOffset(94,28))
at(shop.Close, UDim2.new(1,-56,0,8), UDim2.fromOffset(44,44))
at(shop.Categories, UDim2.fromOffset(12,54), UDim2.new(1,-24,0,48))
for _, button in ipairs(shop.Categories:GetChildren()) do
    if button:IsA("GuiButton") then
        set(button, "Size", UDim2.fromOffset(button.Name == "Emotes" and 104 or 90,44))
    end
end
at(shop.Cards, UDim2.fromOffset(12,106), UDim2.new(1,-24,1,-188))
set(shop.Cards.CardLayout, "CellSize", UDim2.fromOffset(200,228))
set(shop.Cards.CardLayout, "CellPadding", UDim2.fromOffset(10,10))
set(shop.Cards.CardLayout, "FillDirectionMaxCells", 0)
set(shop.Cards.CardLayout, "HorizontalAlignment", Enum.HorizontalAlignment.Center)
set(shop.Cards, "AutomaticCanvasSize", Enum.AutomaticSize.Y)
set(shop.Cards, "ScrollingDirection", Enum.ScrollingDirection.Y)
set(shop.Cards, "CanvasSize", UDim2.new())
set(shop.Cards, "ScrollBarThickness", 6)
local cards = {}
for _, card in ipairs(shop.Cards:GetChildren()) do
    if card:IsA("Frame") and card:FindFirstChild("Action") then table.insert(cards,card) end
end
table.sort(cards,function(a,b) return a.Name < b.Name end)
assert(#cards == 12, "Unexpected authored shop card count")
for _, card in ipairs(cards) do
    set(card, "Size", UDim2.fromOffset(200,228))
    at(card:FindFirstChild("Name"), UDim2.fromOffset(8,7), UDim2.new(1,-16,0,29))
    for _, name in ipairs({"Preview", "PreviewReusableSkin", "Thumbnail", "ThumbnailStatus"}) do
        local element = card:FindFirstChild(name)
        if element then at(element, UDim2.fromOffset(8,41), UDim2.new(1,-16,0,90)) end
    end
    at(card.Price, UDim2.fromOffset(8,136), UDim2.new(1,-16,0,20))
    at(card.Category, UDim2.fromOffset(8,157), UDim2.new(1,-16,0,14))
    at(card.Action, UDim2.fromOffset(8,176), UDim2.new(1,-76,0,44))
    at(card.Try, UDim2.new(1,-60,0,176), UDim2.fromOffset(52,44))
end
at(shop.Pager, UDim2.new(.5,0,1,-74), UDim2.fromOffset(252,44), Vector2.new(.5,0))
at(shop.Pager.Previous, UDim2.new(), UDim2.fromOffset(80,44))
at(shop.Pager.PageLabel, UDim2.fromOffset(84,0), UDim2.fromOffset(84,44))
at(shop.Pager.Next, UDim2.fromOffset(172,0), UDim2.fromOffset(80,44))
at(shop.Status, UDim2.new(0,14,1,-25), UDim2.new(1,-28,0,20))
at(shop.EmoteEmptyState, UDim2.fromOffset(12,106), UDim2.new(1,-24,1,-188))

at(emotes, UDim2.fromScale(.5,.5), UDim2.new(.94,0,1,-12), Vector2.new(.5,.5))
set(emotes.SizeLimit, "MinSize", Vector2.new(280,300))
at(emotes.Title, UDim2.fromOffset(14,10), UDim2.new(1,-76,0,32))
at(emotes.Close, UDim2.new(1,-56,0,8), UDim2.fromOffset(44,44))
at(emotes.Wheel, UDim2.new(.5,0,0,56), UDim2.new(.94,0,1,-166), Vector2.new(.5,0))
at(emotes.Hint, UDim2.new(0,14,1,-86), UDim2.new(1,-100,0,24), Vector2.zero)
at(emotes.StopButton, UDim2.new(.5,0,.5,-27), UDim2.fromOffset(70,44), Vector2.new(.5,.5))
at(emotes.Status, UDim2.new(0,14,1,-110), UDim2.new(1,-28,0,22))
at(emotes.PageLabel, UDim2.new(1,-80,1,-84), UDim2.fromOffset(66,20), Vector2.zero)
at(emotes.Previous, UDim2.new(0,14,1,-58), UDim2.fromOffset(44,44))
at(emotes.Next, UDim2.new(1,-58,1,-58), UDim2.fromOffset(44,44))
at(emotes.ShopButton, UDim2.new(.5,0,1,-58), UDim2.new(1,-140,0,44), Vector2.new(.5,0))

at(toys, UDim2.new(1,-12,1,-152), UDim2.fromOffset(252,134), Vector2.new(1,1))
at(toys.Title, UDim2.new(), UDim2.new(1,0,0,18))
at(toys.Slots, UDim2.fromOffset(0,20), UDim2.new(1,0,0,66))
at(toys.Status, UDim2.fromOffset(0,90), UDim2.new(1,-86,0,44))
at(toys.Use, UDim2.new(1,-80,0,90), UDim2.fromOffset(80,44))
for index = 1,4 do
    local slot = toys.Slots:FindFirstChild("Slot" .. index)
    at(slot, UDim2.fromOffset((index-1)*64,0), UDim2.fromOffset(60,66))
    at(slot.ItemName, UDim2.fromOffset(4,48), UDim2.new(1,-8,0,16))
    for _, name in ipairs({"Thumbnail", "Preview"}) do
        at(slot:FindFirstChild(name), UDim2.fromOffset(5,11), UDim2.new(1,-10,0,36))
    end
    at(slot:FindFirstChild("Selected"), UDim2.new(1,-36,0,3), UDim2.fromOffset(32,12))
end

local before = {}
for _, change in ipairs(changes) do
    local key = change[1]:GetFullName() .. ":" .. change[2]
    assert(before[key] == nil, "Duplicate layout assignment: " .. key)
    before[key] = change[4]
end
local aspect = emotes:FindFirstChild("PanelAspect")
assert(aspect and aspect:IsA("UIAspectRatioConstraint"), "Missing original panel aspect")
before[aspect:GetFullName() .. ":AspectRatio"] = tostring(aspect.AspectRatio)
if DRY_RUN then return game.HttpService:JSONEncode(before) end
assert(EXPECTED, "Expected layout snapshot missing")
for key, value in pairs(before) do assert(EXPECTED[key] == value, "Layout changed: " .. key) end
for key in pairs(EXPECTED) do assert(before[key] ~= nil, "Layout missing: " .. key) end
local backup = Instance.new("Folder")
backup.Name = "MobileFinishBackup20261007"
assert(not game.ServerStorage:FindFirstChild(backup.Name), "Mobile layout backup exists")
backup.Parent = game.ServerStorage
for _, object in ipairs({shop,emotes,toys}) do
    local copy = object:Clone()
    copy.Name = object.Parent.Name .. "_" .. object.Name
    copy.Parent = backup
end
for _, change in ipairs(changes) do change[1][change[2]] = change[3] end
for _, change in ipairs(changes) do assert(change[1][change[2]] == change[3], "Layout readback failed") end
return game.HttpService:JSONEncode({applied=true, authoredPropertyChanges=#changes, cards=#cards, runtimeLayoutWrites=0})
