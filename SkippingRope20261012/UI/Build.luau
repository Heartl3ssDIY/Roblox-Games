assert(not game:GetService("RunService"):IsRunning(), "Edit only")
assert(not game.StarterGui:FindFirstChild("SkippingRopeHUD"), "HUD already installed")
local source = game.StarterGui.DuckDuckGooseHUD
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "SkippingRopeHUD", false, source.DisplayOrder
gui.ScreenInsets, gui.ZIndexBehavior = source.ScreenInsets, source.ZIndexBehavior
gui.ClipToDeviceSafeArea = source.ClipToDeviceSafeArea
gui:SetAttribute("GameId", "SkippingRope")
gui:SetAttribute("EditableGameHUD", true)
gui:SetAttribute("UIAuthoringVersion", "20261012")
local navy, cream = Color3.fromRGB(24, 35, 62), Color3.fromRGB(255, 249, 226)
local function label(parent, name, text, position, size, minimum, maximum)
	local l = Instance.new("TextLabel")
	l.Name, l.Text, l.Position, l.Size = name, text, position, size
	l.BackgroundTransparency, l.BorderSizePixel = 1, 0
	l.TextColor3, l.Font, l.TextScaled, l.TextWrapped = navy, Enum.Font.GothamBold, true, true
	l.ZIndex = parent.ZIndex + 1
	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize, limit.MaxTextSize, limit.Parent = minimum, maximum, l
	l.Parent = parent
	return l
end
local function panel(name, size, position, anchor)
	local p = Instance.new("Frame")
	p.Name, p.Size, p.Position, p.AnchorPoint = name, size, position, anchor
	p.BackgroundColor3, p.BorderSizePixel, p.ZIndex, p.Visible = cream, 0, 20, false
	local c = Instance.new("UICorner") c.CornerRadius, c.Parent = UDim.new(0, 13), p
	local s = Instance.new("UIStroke") s.Color, s.Thickness, s.Parent = navy, 2, p
	p.Parent = gui
	return p
end
local function button(parent, name, text, position, anchor)
	local b = Instance.new("TextButton")
	b.Name, b.Text, b.Size, b.Position, b.AnchorPoint = name, "", UDim2.fromOffset(100, 44), position, anchor
	b.BackgroundColor3, b.BorderSizePixel, b.ZIndex = Color3.fromRGB(255, 213, 94), 0, 25
	local c = Instance.new("UICorner") c.CornerRadius, c.Parent = UDim.new(0, 11), b
	local s = Instance.new("UIStroke") s.Color, s.Thickness, s.Parent = navy, 2, b
	label(b, "Caption", text, UDim2.fromOffset(5, 3), UDim2.new(1, -10, 1, -6), 11, 17)
	b.Parent = parent
	return b
end
for _, spec in ipairs({{"Desktop",340,104,360,224},{"Compact",260,82,290,224},{"Portrait",240,88,272,244}}) do
	local name, width, height, cardWidth, cardHeight = table.unpack(spec)
	local header = source[name .. "Header"]:Clone()
	header.Size = UDim2.fromOffset(width, height)
	header.Title.Text, header.Timer.Text, header.Role.Text = "SKIPPING ROPE", "2:00", "ROPE 1"
	header.Role.Position, header.Role.Size = UDim2.fromScale(0.045,0.34), UDim2.fromScale(0.24,0.18)
	header.Counts.Position, header.Counts.Size = UDim2.fromScale(0.32,0.34), UDim2.fromScale(0.63,0.18)
	header.Counts.Text = "2 hits left  |  24 still in"
	header.Hint.Position, header.Hint.Size = UDim2.fromScale(0.04,0.73), UDim2.fromScale(0.92,0.18)
	header.Hint.Text = "Jump over the rope. Two hits and you're out!"
	label(header, "Speed", "SPEED 1.00x", UDim2.fromScale(0.04,0.53), UDim2.fromScale(0.92,0.15), 8, name=="Desktop" and 12 or 10)
	header.Visible, header.Parent = false, gui
	local card = panel(name .. "Rules", UDim2.fromOffset(cardWidth,cardHeight), UDim2.fromScale(0.5,0.48), Vector2.new(0.5,0.5))
	label(card,"Title","JUMP TO SURVIVE",UDim2.fromOffset(14,10),UDim2.new(1,-28,0,25),15,22)
	local lines = {"Stay on your numbered spot and jump over the rope.","First hit: half health. Second hit: you're OUT.","The rope gets 5% faster every 10 seconds.","Survive for TWO MINUTES to win!"}
	local lineHeight = (cardHeight-97)/4
	for index,text in ipairs(lines) do
		local row = label(card,"Rule"..index,text,UDim2.fromOffset(14,40+(index-1)*lineHeight),UDim2.new(1,-28,0,lineHeight-3),11,15)
		row.TextXAlignment = Enum.TextXAlignment.Left
	end
	button(card,"Close","GOT IT",UDim2.new(0.5,0,1,-8),Vector2.new(0.5,1))
end
local rules = button(gui,"RulesButton","RULES",UDim2.new(0.5,0,1,-14),Vector2.new(0.5,1))
rules.Size, rules.Visible = UDim2.fromOffset(64,44),false
for _,spec in ipairs({{"DesktopHitNotice",330,122},{"CompactHitNotice",270,104}}) do
	local p = panel(spec[1],UDim2.fromOffset(spec[2],38),UDim2.new(0.5,0,0,spec[3]),Vector2.new(0.5,0))
	local l=label(p,"Caption","ROPE HIT! ONE CHANCE LEFT",UDim2.fromOffset(8,5),UDim2.new(1,-16,1,-10),11,17)
	l.TextColor3=Color3.fromRGB(182,42,52)
end
gui.Parent = game.StarterGui
return {hud=gui:GetFullName(),layouts=3,mobileJump="Roblox jump button",authored=true}
