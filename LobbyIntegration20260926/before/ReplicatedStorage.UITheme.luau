--!strict
-- UITheme: shared visual language for all screens. Dark base + chunky beveled
-- buttons, thick outlines, drop shadows, and bold outlined text (cartoon-punchy).

local TweenService = game:GetService("TweenService")

local T = {}

-- ── Palette ──────────────────────────────────────────────────────────────────
T.C = {
	bg      = Color3.fromRGB(26, 18, 50),    -- panel base (dark)
	bg2     = Color3.fromRGB(36, 24, 70),
	panel   = Color3.fromRGB(48, 32, 92),
	panel2  = Color3.fromRGB(62, 42, 118),
	outline = Color3.fromRGB(14, 9, 30),     -- the thick dark outline on everything
	border  = Color3.fromRGB(150, 100, 235),
	accent  = Color3.fromRGB(190, 130, 255),
	btnTxt  = Color3.fromRGB(245, 238, 255),
	sub     = Color3.fromRGB(176, 152, 215),
	txtOut  = Color3.fromRGB(20, 12, 40),     -- text outline color

	-- action colors with a darker "bevel" shade for the 3D edge
	green   = Color3.fromRGB(95, 220, 110),  greenDk  = Color3.fromRGB(50, 165, 70),
	gold    = Color3.fromRGB(255, 205, 60),  goldDk   = Color3.fromRGB(210, 150, 25),
	red     = Color3.fromRGB(245, 85, 95),   redDk    = Color3.fromRGB(185, 45, 60),
	blue    = Color3.fromRGB(85, 175, 255),  blueDk   = Color3.fromRGB(45, 120, 210),
	purple  = Color3.fromRGB(170, 110, 245), purpleDk = Color3.fromRGB(115, 65, 185),
	cellBg  = Color3.fromRGB(56, 38, 104),
	cellHov = Color3.fromRGB(78, 54, 142),
}

-- Rarity colors (main + dark bevel) used to tint units/cards everywhere.
T.RARITY = {
	Common    = { main = Color3.fromRGB(150, 165, 188), dark = Color3.fromRGB(92, 104, 124) },
	Rare      = { main = Color3.fromRGB(70, 165, 255),  dark = Color3.fromRGB(35, 100, 195) },
	Epic      = { main = Color3.fromRGB(200, 110, 255), dark = Color3.fromRGB(135, 55, 205) },
	Legendary = { main = Color3.fromRGB(255, 190, 60),  dark = Color3.fromRGB(215, 130, 20) },
}
function T.rarityColor(r) return (T.RARITY[r] or T.RARITY.Common).main end
function T.rarityDark(r) return (T.RARITY[r] or T.RARITY.Common).dark end

-- ── Builders ─────────────────────────────────────────────────────────────────
function T.mk(class, props, parent)
	local o = Instance.new(class)
	for k,v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end
function T.corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 14)
	c.Parent = p
	return c
end
-- Outline stroke (the thick dark border that defines the cartoon look).
function T.outline(p, thickness, color)
	local s = Instance.new("UIStroke")
	s.Color = color or T.C.outline
	s.Thickness = thickness or 3
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = p
	return s
end
-- Vertical gradient (lighter top -> darker bottom) for a glossy panel feel.
function T.gradient(p, topCol, botCol, rot)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(topCol, botCol)
	g.Rotation = rot or 90
	g.Parent = p
	return g
end
-- Soft drop shadow behind a frame.
function T.shadow(p, spread, transparency)
	spread = spread or 26
	local sh = Instance.new("ImageLabel")
	sh.Name = "Shadow"
	sh.BackgroundTransparency = 1
	sh.Image = "rbxassetid://5028857084"   -- soft circular/rounded shadow
	sh.ImageColor3 = Color3.fromRGB(0, 0, 0)
	sh.ImageTransparency = transparency or 0.45
	sh.ScaleType = Enum.ScaleType.Slice
	sh.SliceCenter = Rect.new(24, 24, 276, 276)
	sh.Size = UDim2.new(1, spread*2, 1, spread*2)
	sh.Position = UDim2.new(0, -spread, 0, -spread + 8)
	sh.ZIndex = (p.ZIndex or 1) - 1
	sh.Parent = p
	return sh
end
-- Bold outlined text label (white text, thick dark stroke). Returns the label.
function T.label(props, parent)
	props.Font = props.Font or Enum.Font.FredokaOne
	props.TextColor3 = props.TextColor3 or Color3.fromRGB(255,255,255)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	local lbl = T.mk("TextLabel", props, parent)
	local s = Instance.new("UIStroke")
	s.Color = T.C.txtOut
	s.Thickness = props.TextSize and math.max(1.5, props.TextSize/12) or 2
	s.Parent = lbl
	return lbl
end

-- ── Chunky beveled button ────────────────────────────────────────────────────
-- A 3D-looking button: a darker "base" behind a lighter "top" that presses down
-- on click. color = main fill, darkColor = bevel. Returns the clickable button
-- (the top), with .Base accessible via :FindFirstChild if needed.
-- opts: { text, textSize, icon, font }
function T.button(parent, size, position, color, darkColor, opts)
	opts = opts or {}
	-- container holds the bevel base + the top button
	local holder = T.mk("Frame", {
		Name = opts.name or "Button", Size = size, Position = position,
		AnchorPoint = opts.anchor or Vector2.new(0,0),
		BackgroundTransparency = 1, ZIndex = opts.zindex or 2,
	}, parent)
	-- bevel base (darker, sits slightly lower)
	local base = T.mk("Frame", {
		Name = "Bevel", Size = UDim2.new(1,0,1,0), Position = UDim2.new(0,0,0,4),
		BackgroundColor3 = darkColor, BorderSizePixel = 0, ZIndex = (opts.zindex or 2),
	}, holder)
	T.corner(base, opts.radius or 14); T.outline(base, opts.outline or 3)
	-- top button
	local top = T.mk("TextButton", {
		Name = "Top", Size = UDim2.new(1,0,1,-4), Position = UDim2.new(0,0,0,0),
		BackgroundColor3 = color, BorderSizePixel = 0, AutoButtonColor = false,
		Text = "", ZIndex = (opts.zindex or 2) + 1,
	}, holder)
	T.corner(top, opts.radius or 14); T.outline(top, opts.outline or 3)
	T.gradient(top, Color3.new(
		math.min(1, color.R*1.12), math.min(1, color.G*1.12), math.min(1, color.B*1.12)), color, 90)
	-- label
	local txt = T.label({
		Name = "Label", Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1,
		Text = (opts.icon and (opts.icon.."  ") or "")..(opts.text or ""),
		TextColor3 = opts.textColor or Color3.fromRGB(255,255,255),
		Font = opts.font or Enum.Font.FredokaOne, TextSize = opts.textSize or 18,
		ZIndex = (opts.zindex or 2) + 2,
	}, top)
	-- press animation: top sinks onto the base
	local pressed = false
	top.MouseButton1Down:Connect(function()
		pressed = true
		TweenService:Create(top, TweenInfo.new(0.05), { Position = UDim2.new(0,0,0,4) }):Play()
	end)
	local function release()
		if pressed then
			pressed = false
			TweenService:Create(top, TweenInfo.new(0.08, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Position = UDim2.new(0,0,0,0) }):Play()
		end
	end
	top.MouseButton1Up:Connect(release)
	top.MouseLeave:Connect(release)
	-- light hover brighten
	top.MouseEnter:Connect(function()
		TweenService:Create(top, TweenInfo.new(0.1), { BackgroundColor3 = Color3.new(
			math.min(1, color.R*1.1), math.min(1, color.G*1.1), math.min(1, color.B*1.1)) }):Play()
	end)
	top.MouseLeave:Connect(function()
		TweenService:Create(top, TweenInfo.new(0.1), { BackgroundColor3 = color }):Play()
	end)
	return top, holder, txt
end

-- A panel: dark rounded frame with thick outline + drop shadow + glossy gradient.
function T.panel(parent, props)
	props = props or {}
	local p = T.mk("Frame", {
		Name = props.Name or "Panel", Size = props.Size or UDim2.new(0,400,0,300),
		Position = props.Position or UDim2.new(0.5,0,0.5,0),
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5,0.5),
		BackgroundColor3 = props.color or T.C.bg, BorderSizePixel = 0,
		ZIndex = props.ZIndex or 2, Visible = props.Visible ~= false,
	}, parent)
	T.corner(p, props.radius or 22)
	T.outline(p, props.outline or 4)
	T.gradient(p, props.gradTop or T.C.bg2, props.gradBot or T.C.bg, 90)
	if props.shadow ~= false then T.shadow(p, props.shadowSpread or 34, 0.35) end
	return p
end

return T
