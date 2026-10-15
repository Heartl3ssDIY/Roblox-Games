assert(not game:GetService("RunService"):IsRunning(), "Edit mode only")
local gui = game.StarterGui:WaitForChild("PlaygroundAdminPanel")
local shop = game.StarterGui.PlaygroundShell.ShopPanel
local backup = game.ServerStorage:FindFirstChild("BatAdminBackup20261004")
if not backup then backup = Instance.new("Folder") backup.Name = "BatAdminBackup20261004" backup.Parent = game.ServerStorage end
if not backup:FindFirstChild("PlaygroundAdminPanel") then gui:Clone().Parent = backup end
local sourceButton = shop.Categories.All
local sourcePanel = shop.ReusableSkin
local ink = Color3.fromRGB(24, 30, 51)
local colors = { Gold = Color3.fromRGB(255, 211, 78), Blue = Color3.fromRGB(89, 193, 244), Green = Color3.fromRGB(130, 225, 180), Red = Color3.fromRGB(255, 153, 166), Cream = Color3.fromRGB(255, 255, 248) }
local function frame(parent, name, position, size, skinned)
	local value = Instance.new("Frame")
	value.Name = name
	value.Position = position
	value.Size = size
	value.BackgroundTransparency = 1
	value.BorderSizePixel = 0
	value.ZIndex = parent:IsA("GuiObject") and parent.ZIndex + 1 or 10
	value.Parent = parent
	if skinned then
		local skin = sourcePanel:Clone()
		skin.Name = "ReusableSkin"
		skin.Position = UDim2.fromScale(0, 0)
		skin.Size = UDim2.fromScale(1, 1)
		skin.ZIndex = value.ZIndex
		skin:SetAttribute("UISkinTargetPath", value:GetFullName())
		skin.Parent = value
		value:SetAttribute("UISkinManaged", true)
	end
	return value
end
local function styleText(value, maxSize)
	value.BackgroundTransparency = 1
	value.BorderSizePixel = 0
	value.Font = Enum.Font.FredokaOne
	value.TextColor3 = Color3.fromRGB(255, 249, 224)
	value.TextStrokeTransparency = 1
	value.TextScaled = true
	value.TextWrapped = true
	value.TextXAlignment = Enum.TextXAlignment.Center
	value.TextYAlignment = Enum.TextYAlignment.Center
	local limit = Instance.new("UITextSizeConstraint")
	limit.Name = "TextSizeLimit"
	limit.MinTextSize = 10
	limit.MaxTextSize = maxSize or 18
	limit.Parent = value
	local stroke = Instance.new("UIStroke")
	stroke.Name = "TextOutline"
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	stroke.Thickness = 0.085
	stroke.Color = ink
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = value
end
local function label(parent, name, text, position, size, maxSize)
	local value = Instance.new("TextLabel")
	value.Name = name
	value.Text = text
	value.Position = position
	value.Size = size
	value.ZIndex = parent.ZIndex + 2
	styleText(value, maxSize)
	value.Parent = parent
	return value
end
local function button(parent, name, text, position, size, color)
	local value = sourceButton:Clone()
	value.Name = name
	value.Position = position
	value.Size = size
	value.AnchorPoint = Vector2.zero
	value.ZIndex = parent.ZIndex + 2
	value.Visible = true
	value.Active = true
	value.Selectable = true
	value.Text = text
	value.BackgroundColor3 = colors[color or "Blue"]
	value:SetAttribute("ReadyColor", value.BackgroundColor3)
	value:SetAttribute("UISkinSelectionFromColour", false)
	value:SetAttribute("UISkinSelectionFromOutline", false)
	value.Parent = parent
	for _, child in ipairs(value:GetChildren()) do
		if child:IsA("UIPadding") or child.Name == "SelectionMark" then child:Destroy() end
	end
	local skin = value.ReusableSkin
	skin.Position = UDim2.fromScale(0, 0)
	skin.Size = UDim2.fromScale(1, 1)
	skin.ZIndex = value.ZIndex
	skin.Image = skin:GetAttribute((color or "Blue") .. "Image") or skin.Image
	skin:SetAttribute("DefaultImage", skin.Image)
	skin:SetAttribute("UISkinTargetPath", value:GetFullName())
	local caption = value.LiveCaption
	caption.Position = UDim2.new(0, 10, 0, 4)
	caption.Size = UDim2.new(1, -20, 1, -10)
	caption.AnchorPoint = Vector2.zero
	caption.Text = text
	caption.Visible = true
	caption.ZIndex = value.ZIndex + 2
	return value
end
local function input(parent, name, placeholder, text, position, size)
	local host = frame(parent, name, position, size, false)
	local skin = sourceButton.ReusableSkin:Clone()
	skin.Name = "ReusableSkin"
	skin.Image = skin:GetAttribute("CreamImage")
	skin:SetAttribute("DefaultImage", skin.Image)
	skin.Size = UDim2.fromScale(1, 1)
	skin.Position = UDim2.fromScale(0, 0)
	skin.ZIndex = host.ZIndex
	skin.Parent = host
	local value = Instance.new("TextBox")
	value.Name = "Value"
	value.Position = UDim2.fromOffset(12, 6)
	value.Size = UDim2.new(1, -24, 1, -12)
	value.PlaceholderText = placeholder
	value.PlaceholderColor3 = Color3.fromRGB(206, 215, 225)
	value.Text = text
	value.ClearTextOnFocus = false
	value.MultiLine = false
	value.ZIndex = host.ZIndex + 2
	styleText(value, 18)
	value.Parent = host
	return host
end
local function scroll(parent, name, position, size)
	local value = Instance.new("ScrollingFrame")
	value.Name = name
	value.Position = position
	value.Size = size
	value.BackgroundTransparency = 1
	value.BorderSizePixel = 0
	value.ScrollBarThickness = 5
	value.ScrollBarImageColor3 = ink
	value.ScrollingDirection = Enum.ScrollingDirection.Y
	value.AutomaticCanvasSize = Enum.AutomaticSize.Y
	value.CanvasSize = UDim2.fromOffset(0, 0)
	value.ZIndex = parent.ZIndex + 1
	value.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = value
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 4)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = value
	return value
end
local old = gui:FindFirstChild("AdminHub")
if old then old:Destroy() end
local hub = frame(gui, "AdminHub", UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.94, 0.92), true)
hub.AnchorPoint = Vector2.new(0.5, 0.5)
hub.Visible = false
local sizeLimit = Instance.new("UISizeConstraint")
sizeLimit.MinSize = Vector2.new(300, 300)
sizeLimit.MaxSize = Vector2.new(1040, 760)
sizeLimit.Parent = hub
label(hub, "Title", "PLAYGROUND ADMIN", UDim2.fromOffset(16, 12), UDim2.new(1, -78, 0, 34), 26)
button(hub, "Close", "X", UDim2.new(1, -54, 0, 10), UDim2.fromOffset(40, 40), "Red")
local target = frame(hub, "Target", UDim2.fromOffset(14, 56), UDim2.new(1, -28, 0, 76), false)
label(target, "Heading", "REWARD RECIPIENT", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 18), 14)
button(target, "Previous", "<", UDim2.fromOffset(0, 23), UDim2.fromOffset(36, 36), "Blue")
label(target, "PlayerName", "Self (selected when you join)", UDim2.fromOffset(42, 21), UDim2.new(1, -166, 0, 23), 18)
label(target, "PlayerStats", "Choose a player with the arrows", UDim2.fromOffset(42, 46), UDim2.new(1, -166, 0, 21), 13)
button(target, "Next", ">", UDim2.new(1, -116, 0, 23), UDim2.fromOffset(36, 36), "Blue")
button(target, "Self", "SELF", UDim2.new(1, -74, 0, 23), UDim2.fromOffset(74, 36), "Gold")
local tabs = frame(hub, "Tabs", UDim2.fromOffset(14, 138), UDim2.new(1, -28, 0, 40), false)
button(tabs, "Rounds", "ROUNDS", UDim2.fromOffset(0, 0), UDim2.new(1/3, -5, 1, 0), "Gold")
button(tabs, "Items", "ITEMS", UDim2.new(1/3, 2, 0, 0), UDim2.new(1/3, -5, 1, 0), "Blue")
button(tabs, "Rewards", "COINS & LEVELS", UDim2.new(2/3, 4, 0, 0), UDim2.new(1/3, -4, 1, 0), "Blue")
local pages = frame(hub, "Pages", UDim2.fromOffset(14, 188), UDim2.new(1, -28, 1, -232), false)
local rounds = scroll(pages, "Rounds", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1))
local sourceContent = gui.Panel.Body.Content
for index, id in ipairs({ "BritishBulldog", "TagYoureIt", "StuckInTheMud" }) do
	local row = frame(rounds, id, UDim2.fromScale(0, 0), UDim2.new(1, -8, 0, 218), true)
	row.LayoutOrder = index
	label(row, "Title", sourceContent[id].Title.Text, UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 27), 22)
	label(row, "Status", "Ready", UDim2.fromOffset(12, 37), UDim2.new(1, -24, 0, 22), 15)
	local controls = { BritishBulldog = { "BBStart", "BBRunner", "BBBulldog" }, TagYoureIt = { "TagStart", "TagRunner", "TagTagger" }, StuckInTheMud = { "MudStart", "MudShooter", "MudMedic" } }
	for j, name in ipairs(controls[id]) do button(row, name, sourceContent[id][name].Text, UDim2.fromOffset(12, 66 + (j-1)*48), UDim2.new(1, -24, 0, 42), ({ "Gold", "Blue", "Red" })[j]) end
end
local roundFooter = frame(rounds, "RoundSettings", UDim2.fromScale(0, 0), UDim2.new(1, -8, 0, 146), true)
roundFooter.LayoutOrder = 4
button(roundFooter, "StopRound", "STOP / BACK TO LOBBY", UDim2.fromOffset(12, 10), UDim2.new(1, -24, 0, 42), "Red")
button(roundFooter, "ToggleAutomatic", "AUTO ROUNDS: ON", UDim2.fromOffset(12, 58), UDim2.new(1, -24, 0, 42), "Green")
label(roundFooter, "Hint", "Solo practice applies to you. Round controls affect the lobby.", UDim2.fromOffset(12, 108), UDim2.new(1, -24, 0, 28), 14)
local items = frame(pages, "Items", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), false)
items.Visible = false
input(items, "Search", "Search item name or ID...", "", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 40))
local filters = frame(items, "Filters", UDim2.fromOffset(0, 46), UDim2.new(1, 0, 0, 34), false)
for index, id in ipairs({ "All", "Bats", "Pets", "Toys" }) do button(filters, id, string.upper(id), UDim2.new((index-1)/5, 2, 0, 0), UDim2.new(0.2, -5, 1, 0), id == "All" and "Gold" or "Blue") end
button(filters, "ClearPreview", "HIDE BAT", UDim2.new(0.8, 2, 0, 0), UDim2.new(0.2, -5, 1, 0), "Cream")
local rows = scroll(items, "Rows", UDim2.fromOffset(0, 86), UDim2.new(1, 0, 1, -128))
for index = 1, 8 do
	local row = frame(rows, string.format("Slot%02d", index), UDim2.fromScale(0, 0), UDim2.new(1, -8, 0, 104), true)
	row.LayoutOrder = index
	label(row, "ItemName", "Item " .. index, UDim2.fromOffset(12, 7), UDim2.new(1, -24, 0, 25), 21)
	label(row, "Detail", "Bats · Starter reward", UDim2.fromOffset(12, 34), UDim2.new(1, -24, 0, 19), 14)
	button(row, "Grant", "GRANT", UDim2.fromOffset(12, 61), UDim2.new(0.5, -18, 0, 34), "Gold")
	button(row, "GrantEquip", "GRANT + EQUIP", UDim2.new(0.5, 6, 0, 61), UDim2.new(0.5, -18, 0, 34), "Green")
end
label(items, "Empty", "No matching items", UDim2.fromOffset(12, 100), UDim2.new(1, -24, 0, 40), 20).Visible = false
local pager = frame(items, "Pager", UDim2.new(0.5, -126, 1, -36), UDim2.fromOffset(252, 36), false)
button(pager, "Previous", "PREV", UDim2.fromOffset(0, 0), UDim2.fromOffset(76, 36), "Blue")
label(pager, "PageLabel", "1 / 7", UDim2.fromOffset(82, 0), UDim2.fromOffset(88, 36), 17)
button(pager, "Next", "NEXT", UDim2.fromOffset(176, 0), UDim2.fromOffset(76, 36), "Blue")
local rewards = scroll(pages, "Rewards", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1))
rewards.Visible = false
for index, spec in ipairs({ { "Coins", "ADD COINS", "150", "1 to 1,000,000 coins", "GrantCoins" }, { "Levels", "ADD LEVELS", "1", "1 to 100 levels; maximum level 1,000", "AddLevels" } }) do
	local card = frame(rewards, spec[1], UDim2.fromScale(0, 0), UDim2.new(1, -8, 0, 174), true)
	card.LayoutOrder = index
	label(card, "Title", spec[2], UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 27), 22)
	label(card, "Limit", spec[4], UDim2.fromOffset(12, 40), UDim2.new(1, -24, 0, 22), 14)
	input(card, "Amount", "Amount", spec[3], UDim2.fromOffset(12, 70), UDim2.new(1, -24, 0, 40))
	button(card, spec[5], spec[2] .. " TO SELECTED PLAYER", UDim2.fromOffset(12, 120), UDim2.new(1, -24, 0, 42), index == 1 and "Gold" or "Green")
end
label(hub, "Message", "Choose a tab. Rewards go to the selected player.", UDim2.new(0, 18, 1, -36), UDim2.new(1, -36, 0, 26), 15)
gui.Panel.Visible = false
gui.CompactPanel.Visible = false
gui.CompactToggle.Visible = false
gui.Toggle.Visible = true
gui:SetAttribute("AdminUIRevision", "20261004-CatalogRewards")
local catalog = require(game.ReplicatedStorage.PlaygroundCatalog)
for index = 1, 8 do
	local item = catalog.Items[index]
	local row = rows[string.format("Slot%02d", index)]
	row:SetAttribute("CatalogId", item.id)
	row.ItemName.Text = item.id .. " · " .. item.name
	row.Detail.Text = item.category .. " · " .. (item.unlock.kind == "Coins" and tostring(item.price) .. " coins" or item.unlock.kind == "Level" and "Level " .. item.unlock.amount or item.unlock.kind == "Wins" and item.unlock.amount .. " wins" or "Starter reward")
end
pcall(function() game:GetService("ContentProvider"):PreloadAsync({ hub }) end)
return { hub = hub:GetFullName(), slots = 8, catalogCount = #catalog.Items, tabs = { "Rounds", "Items", "Rewards" }, editable = true }
