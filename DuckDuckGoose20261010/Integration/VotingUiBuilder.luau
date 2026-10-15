local Builder = {}
local ids = { "BritishBulldog", "TagYoureIt", "StuckInTheMud", "HideAndSeek", "DuckDuckGoose" }
local navy = Color3.fromRGB(24,35,62)
local gold = Color3.fromRGB(246,189,62)

function Builder.Fallback(button)
	local old = button:FindFirstChild("ArtFallback")
	if old then old:Destroy() end
	for _, child in button:GetChildren() do if child:IsA("UIStroke") then child.Enabled=false end end
	local back = Instance.new("Frame")
	back.Name,back.Size,back.Position = "ArtFallback",UDim2.fromScale(1,1),UDim2.fromScale(0,0)
	back.BackgroundColor3,back.BorderSizePixel,back.ZIndex = navy,0,8
	back.Active,back.Selectable,back.Visible = false,false,not button.ReusableSkin.IsLoaded
	local corner=Instance.new("UICorner")corner.CornerRadius,corner.Parent=UDim.new(0,10),back
	local border=Instance.new("UIStroke")border.Color,border.Thickness,border.Parent=Color3.fromRGB(255,249,224),1.5,back
	local face=Instance.new("Frame")
	face.Name,face.Position,face.Size="Face",UDim2.fromOffset(3,3),UDim2.new(1,-6,1,-8)
	face.BackgroundColor3,face.BorderSizePixel,face.ZIndex=button.BackgroundColor3,0,8
	face.Active,face.Selectable,face.Parent=false,false,back
	local innerCorner=Instance.new("UICorner")innerCorner.CornerRadius,innerCorner.Parent=UDim.new(0,7),face
	local innerBorder=Instance.new("UIStroke")innerBorder.Color,innerBorder.Thickness,innerBorder.Parent=Color3.fromRGB(255,249,224),1.2,face
	local gradient=Instance.new("UIGradient")
	gradient.Color,gradient.Rotation,gradient.Parent=ColorSequence.new(Color3.fromRGB(255,255,255),Color3.fromRGB(195,195,195)),90,face
	back.Parent=button
	return back
end

function Builder.Hint(hint)
	for _, child in hint:GetDescendants() do if child:IsA("UIStroke") or child:IsA("UITextSizeConstraint") then child:Destroy() end end
	hint.Text,hint.TextColor3,hint.TextStrokeTransparency="SWIPE OR SCROLL FOR ALL 5 GAMES",navy,1
	hint.Font,hint.ZIndex=Enum.Font.GothamMedium,13
	hint.TextTruncate,hint.TextWrapped,hint.TextScaled=Enum.TextTruncate.None,false,false
	hint.TextSize=13
end

local function readable(label, maximum)
	label.TextTruncate = Enum.TextTruncate.None
	label.TextWrapped = true
	local limit = label:FindFirstChildOfClass("UITextSizeConstraint")
	if not limit then limit = Instance.new("UITextSizeConstraint") limit.Parent = label end
	limit.MinTextSize, limit.MaxTextSize = 10,maximum
	label.TextScaled = true
end

function Builder.Panel(panel)
	assert(not panel:FindFirstChild("Choices"), "Voting row already exists")
	local compact = panel.Name == "CompactVotePanel"
	local width, gap = compact and 128 or 154, 8
	local buttons, counters = {},{}
	for _, id in ids do
		local sourceId = id == "DuckDuckGoose" and "HideAndSeek" or id
		buttons[id], counters[id] = panel[sourceId]:Clone(),panel["Votes"..sourceId]:Clone()
	end
	for _, id in ids do
		local button, counter = panel:FindFirstChild(id),panel:FindFirstChild("Votes"..id)
		if button then button:Destroy() end
		if counter then counter:Destroy() end
	end
	panel.Size = UDim2.new(compact and .94 or .62,0,0,166)
	panel.Title.Position, panel.Title.Size = UDim2.new(0,14,0,9),UDim2.new(1,-112,0,25)
	panel.Timer.Position, panel.Timer.Size = UDim2.new(1,-88,0,10),UDim2.fromOffset(72,24)
	panel.Message.Position, panel.Message.Size = UDim2.new(0,14,1,-29),UDim2.new(1,-28,0,17)
	readable(panel.Title,22)
	readable(panel.Timer,22)
	readable(panel.Message,13)
	local choices = Instance.new("ScrollingFrame")
	choices.Name, choices.BackgroundTransparency, choices.BorderSizePixel = "Choices",1,0
	choices.Position, choices.Size = UDim2.fromOffset(14,39),UDim2.new(1,-28,0,82)
	choices.CanvasSize, choices.ScrollingDirection = UDim2.fromOffset(#ids*(width+gap)-gap,82),Enum.ScrollingDirection.X
	choices.AutomaticCanvasSize, choices.ScrollBarThickness = Enum.AutomaticSize.None,6
	choices.ScrollBarImageColor3, choices.ElasticBehavior = navy,Enum.ElasticBehavior.WhenScrollable
	choices.ClipsDescendants, choices.Selectable, choices.Parent = true,false,panel
	choices.ZIndex = 9
	local hint = panel.Message:Clone()
	hint.Name, hint.Text, hint.TextColor3 = "ScrollHint","SWIPE OR SCROLL FOR ALL 5 GAMES",navy
	hint.Position, hint.Size = UDim2.fromOffset(14,124),UDim2.new(1,-28,0,16)
	Builder.Hint(hint)
	hint.Parent = panel
	for index,id in ids do
		local card = Instance.new("Frame")
		card.Name, card.BackgroundTransparency, card.BorderSizePixel = id,1,0
		card.Position, card.Size, card.LayoutOrder = UDim2.fromOffset((index-1)*(width+gap),0),UDim2.fromOffset(width,73),index
		card.Parent = choices
		card.ZIndex = 9
		local button, counter = buttons[id],counters[id]
		button.Name, button.Position, button.Size = "Button",UDim2.fromOffset(0,0),UDim2.fromOffset(width,48)
		button.Text, button.TextTransparency = "",1
		button.Parent = card
		if id == "DuckDuckGoose" then
			button.BackgroundColor3 = gold
			button:SetAttribute("UISkinAssetKey","PNG/07-Resizable-Skins/gold-normal.png")
			button.LiveCaption.Text = "DUCK DUCK\nGOOSE"
			button.ReusableSkin.Image = "rbxassetid://84589903135132"
			button.ReusableSkin:SetAttribute("DefaultImage",button.ReusableSkin.Image)
		end
		button.ReusableSkin.ScaleType, button.ReusableSkin.SliceCenter = Enum.ScaleType.Slice,Rect.new(88,88,424,232)
		Builder.Fallback(button)
		readable(button.LiveCaption,compact and 16 or 19)
		counter.Name, counter.Position, counter.Size = "VoteCount",UDim2.fromOffset(0,51),UDim2.fromOffset(width,19)
		counter.Text, counter.Parent = "0 votes",card
		readable(counter,14)
	end
	for index,id in ids do
		local button = choices[id].Button
		button.NextSelectionLeft = choices[ids[math.max(1,index-1)]].Button
		button.NextSelectionRight = choices[ids[math.min(#ids,index+1)]].Button
	end
	panel:SetAttribute("DuckDuckGooseVoting20261010",true)
	return panel
end

function Builder.Admin(rounds)
	assert(not rounds:FindFirstChild("DuckDuckGoose"), "Admin card already exists")
	local card = rounds.HideAndSeek:Clone()
	card.Name, card.LayoutOrder = "DuckDuckGoose",5
	card.Title.Text, card.Status.Text = "DUCK DUCK GOOSE","Ready • 2–16 players"
	card.HSStart.Name = "DGStart"
	card.DGStart.Text, card.DGStart.LiveCaption.Text = "","START GOOSE ROUND"
	readable(card.Title,26)
	readable(card.Status,18)
	readable(card.DGStart.LiveCaption,22)
	card.Parent = rounds
	rounds.RoundSettings.LayoutOrder = 6
	return card
end

return Builder
