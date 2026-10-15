local gui = game.StarterGui.DuckDuckGooseHUD
assert(not game:GetService("RunService"):IsRunning(), "Edit only")
assert(not gui:FindFirstChild("Guidance"), "Guidance already installed")
local backup = Instance.new("Folder")
backup.Name, backup.Parent = "DuckDuckGooseGuidanceBackup20261012", game.ServerStorage
gui:Clone().Parent = backup
local arena = workspace["Duck Duck Goose"]
local track = arena.Grounds.CircularRunningTrack
track.TrackDirections:Clone().Parent = backup
backup:SetAttribute("CountdownSeconds", arena:GetAttribute("CountdownSeconds"))
arena:SetAttribute("CountdownSeconds", 8)
local navy, cream = Color3.fromRGB(24, 35, 62), Color3.fromRGB(255, 249, 226)
local function label(parent, name, text, position, size, minSize, maxSize)
	local l = Instance.new("TextLabel")
	l.Name, l.Text, l.Position, l.Size = name, text, position, size
	l.BackgroundTransparency, l.BorderSizePixel = 1, 0
	l.TextColor3, l.Font, l.TextScaled, l.TextWrapped = navy, Enum.Font.GothamBold, true, true
	l.ZIndex = parent.ZIndex + 1
	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize, limit.MaxTextSize, limit.Parent = minSize, maxSize, l
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
local function button(parent, name, text, size, position, anchor)
	local b = Instance.new("TextButton")
	b.Name, b.Text, b.Size, b.Position, b.AnchorPoint = name, "", size, position, anchor
	b.BackgroundColor3, b.BorderSizePixel, b.ZIndex = Color3.fromRGB(255, 213, 94), 0, parent:IsA("GuiObject") and parent.ZIndex + 2 or 20
	local corner = Instance.new("UICorner") corner.CornerRadius, corner.Parent = UDim.new(0, 11), b
	local stroke = Instance.new("UIStroke") stroke.Color, stroke.Thickness, stroke.Parent = navy, 2, b
	label(b, "Caption", text, UDim2.fromOffset(5, 3), UDim2.new(1, -10, 1, -6), 11, 17)
	b.Parent = parent
	return b
end
local lines = {
	"1  PICKER: choose a duck to call GOOSE!",
	"2  RUNNER: follow arrows for ONE LAP, then sit in the gold chair.",
	"3  GOOSE: chase the arrows. Keep running and swing to tag.",
	"4  TAGGED = OUT. Watch outside. At 3:00, picker/runner loses.",
}
for _, spec in ipairs({{"Desktop", 360, 232, 112, 330}, {"Compact", 290, 218, 86, 278}, {"Portrait", 272, 244, 90, 264}}) do
	local prefix, width, height, noticeY, noticeWidth = table.unpack(spec)
	local card = panel(prefix .. "Rules", UDim2.fromOffset(width, height), UDim2.fromScale(0.5, 0.48), Vector2.new(0.5, 0.5))
	label(card, "Title", "HOW TO PLAY", UDim2.fromOffset(14, 10), UDim2.new(1, -28, 0, 25), 15, 22)
	local lineHeight = (height - 97) / 4
	for index, text in ipairs(lines) do
		local l = label(card, "Rule" .. index, text, UDim2.fromOffset(14, 40 + (index - 1) * lineHeight), UDim2.new(1, -28, 0, lineHeight - 3), 11, 15)
		l.TextXAlignment = Enum.TextXAlignment.Left
	end
	button(card, "Close", "GOT IT", UDim2.fromOffset(104, 44), UDim2.new(0.5, 0, 1, -8), Vector2.new(0.5, 1))
	local notice = panel(prefix .. "Notice", UDim2.fromOffset(noticeWidth, 38), UDim2.new(0.5, 0, 0, noticeY), Vector2.new(0.5, 0))
	label(notice, "Caption", "FOLLOW THE GLOWING ARROWS", UDim2.fromOffset(8, 5), UDim2.new(1, -16, 1, -10), 12, 17)
end
local desktop = button(gui, "DesktopRulesButton", "RULES", UDim2.fromOffset(64, 44), UDim2.new(0.5, -120, 1, -18), Vector2.new(0.5, 1))
local touch = button(gui, "TouchRulesButton", "RULES", UDim2.fromOffset(64, 44), UDim2.new(0.5, 0, 1, -14), Vector2.new(0.5, 1))
desktop.Visible, touch.Visible = false, false
local templates = Instance.new("Folder") templates.Name, templates.Parent = "GuidanceTemplates", gui
local world = Instance.new("BillboardGui")
world.Name, world.Size, world.StudsOffsetWorldSpace = "WorldNotice", UDim2.fromOffset(180, 40), Vector3.new(0, 4, 0)
world.AlwaysOnTop, world.MaxDistance, world.Enabled = true, 150, false
local caption = Instance.new("TextLabel")
caption.Name, caption.Size, caption.BackgroundColor3 = "Caption", UDim2.fromScale(1, 1), cream
caption.TextColor3, caption.Text, caption.Font = navy, "ONE LAP, THEN THIS CHAIR", Enum.Font.GothamBold
caption.BorderSizePixel, caption.TextScaled, caption.TextWrapped = 0, true, true
local corner = Instance.new("UICorner") corner.CornerRadius, corner.Parent = UDim.new(0, 10), caption
local stroke = Instance.new("UIStroke") stroke.ApplyStrokeMode, stroke.Color, stroke.Thickness, stroke.Parent = Enum.ApplyStrokeMode.Border, navy, 2, caption
local padding = Instance.new("UIPadding") padding.PaddingLeft, padding.PaddingRight, padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6), UDim.new(0, 4), UDim.new(0, 4) padding.Parent = caption
local textSize = Instance.new("UITextSizeConstraint") textSize.MinTextSize, textSize.MaxTextSize, textSize.Parent = 11, 15, caption
caption.Parent, world.Parent = world, templates
local origin = arena.Gameplay.CircleCenter.CFrame
local surface = track.StuddedTanTrack
local top = origin:PointToObjectSpace(surface.Position).Y + surface.Size.X / 2
local old = track.TrackDirections
old.Parent = nil
local directions = Instance.new("Model")
directions.Name = "TrackDirections"
directions:SetAttribute("DGPaintedDirections", true)
directions:SetAttribute("DGGuidanceVersion", "20261012")
for index = 1, 24 do
	local angle = (index - 1) * math.pi * 2 / 24
	local radial, forward = Vector3.new(math.sin(angle), 0, -math.cos(angle)), Vector3.new(math.cos(angle), 0, math.sin(angle))
	local arrow = Instance.new("Model") arrow.Name = string.format("Chevron%02d", index)
	arrow:SetAttribute("ClockwiseAngle", angle)
	for _, side in ipairs({-1, 1}) do
		local tip = radial * 30.5 + forward * 1.15 + radial * (side * 0.15) + Vector3.new(0, top + 0.06, 0)
		local tail = radial * 30.5 - forward * 1.15 + radial * (side * 1.65) + Vector3.new(0, top + 0.06, 0)
		local arm = tip - tail
		local part = Instance.new("Part")
		part.Name, part.Size = side == -1 and "InnerArm" or "OuterArm", Vector3.new(arm.Magnitude, 0.05, 0.55)
		part.CFrame = CFrame.fromMatrix(origin:PointToWorldSpace((tip + tail) / 2), origin:VectorToWorldSpace(arm.Unit), origin.UpVector)
		part.Color, part.Material = Color3.fromRGB(250, 225, 131), Enum.Material.SmoothPlastic
		part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
		part:SetAttribute("DGDuckMap", true) part:SetAttribute("DGDecorative", true)
		part.Parent = arrow
	end
	arrow.Parent = directions
end
directions.Parent = track
old:Destroy()
gui:SetAttribute("DGGuidanceVersion", "20261012")
return {arrows = 24, rulesLayouts = 3, rulesButton = true, editable = true}
