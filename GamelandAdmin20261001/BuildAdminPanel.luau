local StarterGui = game:GetService("StarterGui")
assert(not StarterGui:FindFirstChild("GamelandAdminPanel"), "Admin panel already exists")
local colors = {ink = Color3.fromRGB(20, 29, 52), blue = Color3.fromRGB(55, 133, 249),
    paper = Color3.fromRGB(245, 248, 255), muted = Color3.fromRGB(99, 114, 137),
    cyan = Color3.fromRGB(87, 222, 223), yellow = Color3.fromRGB(255, 211, 93), red = Color3.fromRGB(255, 115, 128)}
local gui = Instance.new("ScreenGui")
gui.Name = "GamelandAdminPanel" gui.ResetOnSpawn = false gui.Enabled = false gui.DisplayOrder = 100
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling gui.Parent = StarterGui
local function round(object, radius)
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, radius) c.Parent = object
end
local function stroke(object, color, width)
    local s = Instance.new("UIStroke") s.Color = color s.Thickness = width s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border s.Parent = object
end
local function label(parent, name, words, position, size, color, maxSize)
    local l = Instance.new("TextLabel") l.Name = name l.Text = words l.Position = position l.Size = size
    l.BackgroundTransparency = 1 l.TextColor3 = color or colors.ink l.Font = Enum.Font.FredokaOne
    l.TextScaled = true l.TextWrapped = true l.TextXAlignment = Enum.TextXAlignment.Left l.Parent = parent
    local limit = Instance.new("UITextSizeConstraint") limit.MinTextSize = 10 limit.MaxTextSize = maxSize or 18 limit.Parent = l
    return l
end
local function button(parent, name, words, position, size, color)
    local b = Instance.new("TextButton") b.Name = name b.Text = words b.Position = position b.Size = size
    b.BackgroundColor3 = color b.TextColor3 = colors.ink b.Font = Enum.Font.FredokaOne b.TextScaled = true
    b.AutoButtonColor = true b.Parent = parent round(b, 10) stroke(b, colors.ink, 2)
    local p = Instance.new("UIPadding") p.PaddingLeft = UDim.new(0, 8) p.PaddingRight = UDim.new(0, 8) p.Parent = b
    local t = Instance.new("UITextSizeConstraint") t.MinTextSize = 10 t.MaxTextSize = 18 t.Parent = b
    return b
end
button(gui, "Open", "ADMIN  [F4]", UDim2.new(1, -162, 0, 12), UDim2.fromOffset(146, 43), colors.yellow)
local shade = Instance.new("TextButton") shade.Name = "Shade" shade.Text = "" shade.Size = UDim2.fromScale(1, 1)
shade.BackgroundColor3 = Color3.fromRGB(9, 18, 36) shade.BackgroundTransparency = 0.45 shade.AutoButtonColor = false
shade.Visible = false shade.Parent = gui
local panel = Instance.new("Frame") panel.Name = "Panel" panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5) panel.Size = UDim2.fromScale(0.94, 0.86) panel.BackgroundColor3 = colors.paper
panel.Visible = false panel.Parent = gui round(panel, 18) stroke(panel, colors.ink, 3)
local limit = Instance.new("UISizeConstraint") limit.MaxSize = Vector2.new(680, 590) limit.Parent = panel
local header = Instance.new("Frame") header.Name = "Header" header.Size = UDim2.new(1, 0, 0.15, 0)
header.BackgroundColor3 = colors.blue header.Parent = panel round(header, 16)
label(header, "Title", "GAMELAND ADMIN", UDim2.fromScale(0.04, 0.12), UDim2.fromScale(0.78, 0.44), Color3.new(1, 1, 1), 29)
label(header, "Subtitle", "Pick a minigame. Jump in. Test it.", UDim2.fromScale(0.04, 0.59), UDim2.fromScale(0.8, 0.25), Color3.fromRGB(226, 243, 255), 15)
button(header, "Close", "X", UDim2.fromScale(0.9, 0.2), UDim2.fromScale(0.065, 0.48), colors.paper)
label(panel, "ListHeading", "MINIGAMES", UDim2.fromScale(0.04, 0.177), UDim2.fromScale(0.55, 0.035), colors.muted, 13)
local list = Instance.new("ScrollingFrame") list.Name = "GameList" list.Position = UDim2.fromScale(0.04, 0.222)
list.Size = UDim2.fromScale(0.92, 0.225) list.BackgroundColor3 = Color3.fromRGB(230, 237, 250)
list.BorderSizePixel = 0 list.ScrollBarThickness = 5 list.ScrollBarImageColor3 = colors.blue
list.CanvasSize = UDim2.fromScale(0, 0) list.AutomaticCanvasSize = Enum.AutomaticSize.Y list.Parent = panel round(list, 11)
local padding = Instance.new("UIPadding") padding.PaddingTop = UDim.new(0, 8) padding.PaddingBottom = UDim.new(0, 8)
padding.PaddingLeft = UDim.new(0, 8) padding.PaddingRight = UDim.new(0, 8) padding.Parent = list
local layout = Instance.new("UIListLayout") layout.Padding = UDim.new(0, 8) layout.SortOrder = Enum.SortOrder.LayoutOrder layout.Parent = list
local templates = Instance.new("Folder") templates.Name = "Templates" templates.Parent = gui
local card = button(templates, "MinigameCard", "", UDim2.fromOffset(0, 0), UDim2.new(1, -4, 0, 58), Color3.new(1, 1, 1))
card.Visible = false
local badge = label(card, "Badge", "FM", UDim2.fromScale(0.018, 0.14), UDim2.fromScale(0.09, 0.72), colors.ink, 22)
badge.BackgroundTransparency = 0 badge.BackgroundColor3 = colors.yellow badge.TextXAlignment = Enum.TextXAlignment.Center round(badge, 8)
label(card, "GameName", "Football Mayhem", UDim2.fromScale(0.135, 0.12), UDim2.fromScale(0.65, 0.43), colors.ink, 21)
label(card, "GameStatus", "READY TO TEST", UDim2.fromScale(0.135, 0.58), UDim2.fromScale(0.65, 0.28), colors.muted, 11)
local selected = label(card, "SelectedTag", "SELECTED", UDim2.fromScale(0.81, 0.3), UDim2.fromScale(0.17, 0.35), colors.blue, 12)
selected.TextXAlignment = Enum.TextXAlignment.Right
label(panel, "Description", "Choose a minigame above.", UDim2.fromScale(0.04, 0.462), UDim2.fromScale(0.92, 0.078), colors.muted, 15)
label(panel, "ScopeHeading", "WHO IS TESTING?", UDim2.fromScale(0.04, 0.553), UDim2.fromScale(0.53, 0.035), colors.muted, 13)
button(panel, "SelfScope", "Only me", UDim2.fromScale(0.04, 0.6), UDim2.fromScale(0.445, 0.073), colors.cyan)
button(panel, "LobbyScope", "All lobby players", UDim2.fromScale(0.515, 0.6), UDim2.fromScale(0.445, 0.073), Color3.new(1, 1, 1))
button(panel, "StartTest", "PLAY TEST", UDim2.fromScale(0.04, 0.694), UDim2.fromScale(0.59, 0.086), colors.yellow)
button(panel, "StopTest", "STOP TEST", UDim2.fromScale(0.65, 0.694), UDim2.fromScale(0.31, 0.086), colors.red)
button(panel, "Visit", "Visit arena", UDim2.fromScale(0.04, 0.803), UDim2.fromScale(0.445, 0.066), Color3.new(1, 1, 1))
button(panel, "Return", "Return to lobby", UDim2.fromScale(0.515, 0.803), UDim2.fromScale(0.445, 0.066), Color3.new(1, 1, 1))
label(panel, "Status", "Ready. Tests start when you choose Play Test.", UDim2.fromScale(0.04, 0.898), UDim2.fromScale(0.92, 0.066), colors.muted, 14)
return "Editable admin panel created in StarterGui"
