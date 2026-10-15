local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Install in Edit only")
local gui = game.StarterGui.PlaygroundShell
local shop = gui.ShopPanel
assert(not shop:FindFirstChild("BuyCoinsPanel"), "Commerce UI already installed")
local backup = Instance.new("Folder")
backup.Name = "CommerceUIBackup20261007"
backup.Parent = game.ServerStorage
gui.Controller:Clone().Parent = backup
local tab = shop.Categories.Emotes:Clone()
tab.Name = "BuyCoins"
tab.LayoutOrder = -1
tab.Size = UDim2.fromOffset(128, 44)
tab:SetAttribute("ShopCategory", "BuyCoins")
tab:SetAttribute("UISkinDynamic", false)
tab:SetAttribute("UISkinSelectionFromColour", false)
tab:SetAttribute("UISkinSelectionFromOutline", false)
tab.ReusableSkin.Image = shop.Categories.All.ReusableSkin.Image
tab.ReusableSkin:SetAttribute("DefaultImage", tab.ReusableSkin.Image)
tab.LiveCaption.Text = "BUY COINS"
tab.LiveCaption.TextSize = 18
tab.LiveCaption.TextScaled = true
tab.Text = "BUY COINS"
tab.Parent = shop.Categories

local function label(parent, name, text, position, size, fontSize)
 local object = shop.Title:Clone()
 object.Name = name
 object.Text = text
 object.Position = position
 object.Size = size
 object.AnchorPoint = Vector2.zero
 object.ZIndex = 27
 object.TextSize = fontSize
 object.TextScaled = true
 object.TextWrapped = true
 object.TextColor3 = Color3.fromRGB(255, 255, 242)
 object.BackgroundTransparency = 1
 object.TextXAlignment = Enum.TextXAlignment.Center
 object.TextYAlignment = Enum.TextYAlignment.Center
 object.TextStrokeTransparency = 1
 for _, child in object:GetChildren() do child:Destroy() end
 local stroke = Instance.new("UIStroke")
 stroke.Name = "TextOutline"
 stroke.Color = Color3.fromRGB(26, 32, 51)
 stroke.Thickness = 1.5
 stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
 stroke.LineJoinMode = Enum.LineJoinMode.Round
 stroke.Parent = object
 local limit = Instance.new("UITextSizeConstraint")
 limit.MinTextSize = 12
 limit.MaxTextSize = fontSize
 limit.Parent = object
 object.Parent = parent
 return object
end

local panel = Instance.new("Frame")
panel.Name = "BuyCoinsPanel"
panel.Position = UDim2.fromOffset(12, 106)
panel.Size = UDim2.new(1, -24, 1, -120)
panel.BackgroundTransparency = 1
panel.ZIndex = 25
panel.Visible = false
panel.Parent = shop
label(panel, "Heading", "COINS & PASSES", UDim2.fromOffset(4, 0), UDim2.new(1, -8, 0, 28), 23)
label(panel, "Intro", "Pick a pack, or unlock a permanent bonus.", UDim2.fromOffset(4, 30), UDim2.new(1, -8, 0, 30), 16)
local status = label(panel, "Status", "Purchases are coming soon.", UDim2.new(0, 4, 1, -28), UDim2.new(1, -8, 0, 28), 15)
local list = Instance.new("ScrollingFrame")
list.Name = "Offers"
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.Position = UDim2.fromOffset(0, 66)
list.Size = UDim2.new(1, 0, 1, -100)
list.CanvasSize = UDim2.fromOffset(0, 0)
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.ScrollingDirection = Enum.ScrollingDirection.Y
list.ScrollBarThickness = 6
list.ScrollBarImageColor3 = Color3.fromRGB(27, 45, 61)
list.ZIndex = 25
list.Parent = panel
local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 2)
padding.PaddingRight = UDim.new(0, 10)
padding.PaddingTop = UDim.new(0, 2)
padding.PaddingBottom = UDim.new(0, 8)
padding.Parent = list
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 10)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Parent = list

local offers = {
 {"Coin5000", "5,000 COINS", "Spend on pets, bats and toys.", 49},
 {"Coin10000", "10,000 COINS", "Spend on pets, bats and toys.", 99},
 {"Coin25000", "25,000 COINS", "Spend on pets, bats and toys.", 249},
 {"Coin50000", "50,000 COINS", "Spend on pets, bats and toys.", 499},
 {"Coin100000", "100,000 COINS", "Spend on pets, bats and toys.", 999},
 {"VIP", "VIP", "3× earned coins\n2× XP + VIP tag", 499},
 {"DoubleCoins", "2× COINS", "Double your earned coins.", 250},
 {"DoubleXP", "2× XP", "Double your earned XP.", 199},
}
local function makeCard(spec, index)
 local card = Instance.new("Frame")
 card.Name = spec[1]
 card.BackgroundTransparency = 1
 card.Size = UDim2.new(1, 0, 0, 132)
 card.LayoutOrder = index
 card.ZIndex = 25
 local limit = Instance.new("UISizeConstraint")
 limit.MaxSize = Vector2.new(760, 132)
 limit.Parent = card
 local skin = shop.ReusableSkin:Clone()
 skin.Name = "ReusableSkin"
 skin.ZIndex = 25
 skin.Parent = card
 local icon = Instance.new("ImageLabel")
 icon.Name = "CoinIcon"
 icon.BackgroundTransparency = 1
 icon.Image = "rbxassetid://116272100820962"
 icon.ScaleType = Enum.ScaleType.Fit
 icon.Position = UDim2.fromOffset(12, 8)
 icon.Size = UDim2.fromOffset(30, 30)
 icon.ZIndex = 27
 icon.Visible = index <= 5 or spec[1] == "DoubleCoins"
 icon.Parent = card
 label(card, "Title", spec[2], UDim2.fromOffset(44, 8), UDim2.new(1, -56, 0, 28), 25)
 label(card, "Description", spec[3], UDim2.fromOffset(12, 42), UDim2.new(1, -150, 0, 44), 16)
 local action = shop.Cards.Slot01.Action:Clone()
 action.Name = "Buy"
 action.Position = UDim2.new(1, -126, 0, 42)
 action.Size = UDim2.fromOffset(114, 44)
 action.ZIndex = 27
 action.Text = tostring(spec[4]) .. " ROBUX"
 action.Active = false
 action.Selectable = false
 action.BackgroundTransparency = 1
 action:SetAttribute("UISkinDynamic", false)
 action:SetAttribute("UISkinSelectionFromColour", false)
 action:SetAttribute("UISkinSelectionFromOutline", false)
 action.LiveCaption.Text = action.Text
 action.LiveCaption.AnchorPoint = Vector2.new(0.5, 0.5)
 action.LiveCaption.Position = UDim2.fromScale(0.5, 0.5)
 action.LiveCaption.Size = UDim2.new(1, -12, 1, -10)
 action.LiveCaption.TextScaled = true
 action.LiveCaption.TextSize = 18
 for _, obj in action:GetDescendants() do if obj:IsA("GuiObject") then obj.ZIndex = obj.Name == "ReusableSkin" and 27 or 28 end end
 action.Parent = card
 label(card, "Availability", "COMING SOON", UDim2.fromOffset(12, 96), UDim2.new(1, -24, 0, 22), 15)
 card.Parent = list
 return card
end
for index, spec in offers do makeCard(spec, index) end
local templateFolder = Instance.new("Folder")
templateFolder.Name = "Templates"
templateFolder.Parent = panel
local template = list.Coin5000:Clone()
template.Name = "OfferCard"
template.Visible = false
template.Parent = templateFolder
return "Created Buy Coins tab and 8 editable offer cards"

