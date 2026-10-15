return function(ui, guarded)
	local shell = ui.PlaygroundShell
	local timer = ui.PlaygroundIntermissionHUD
	local fishing = ui.PlaygroundFishingHUD
	if guarded then
		assert(not shell:FindFirstChild("CompactDock"), "Compact dock already exists")
		assert(not timer:FindFirstChild("Portrait"), "Portrait timer already exists")
		assert(not fishing:FindFirstChild("PortraitDock") and not fishing:FindFirstChild("RoundDock"), "Boost variants already exist")
		assert(shell.Wallet.Position == UDim2.new(0.9970695972442627,-18,0.8841145634651184,18), "Wallet layout changed")
		assert(shell.CompactLevelPanel.Size == UDim2.fromOffset(151,66), "Level layout changed")
	end
	local function at(object, position, size, anchor)
		object.Position, object.Size = position, size
		if anchor then object.AnchorPoint = anchor end
	end
	local function scale(object, phone, tablet)
		local value = object:FindFirstChild("ResponsiveHudScale")
		if not value then value = Instance.new("UIScale") value.Name = "ResponsiveHudScale" value.Parent = object end
		value.Scale = 1
		value:SetAttribute("PhoneScale", phone)
		value:SetAttribute("TabletScale", tablet)
		value:SetAttribute("DesktopScale", 1)
	end
	local function text(label, maximum)
		if not label or not label:IsA("TextLabel") then return end
		label.TextScaled = true
		local limit = label:FindFirstChildOfClass("UITextSizeConstraint")
		if not limit then limit = Instance.new("UITextSizeConstraint") limit.Parent = label end
		limit.MinTextSize, limit.MaxTextSize = 9, maximum
	end
	at(shell.Wallet, UDim2.new(1,-8,0,6), UDim2.fromOffset(190,56), Vector2.new(1,0))
	scale(shell.Wallet, .65, .75)
	at(shell.Wallet.CoinsCaption,UDim2.new(0,58,0,2),UDim2.new(1,-68,0,18),Vector2.zero)
	at(shell.Wallet.Coins,UDim2.new(0,58,0,20),UDim2.new(1,-68,0,30),Vector2.zero)
	text(shell.Wallet.CoinsCaption,14)
	local dock = shell.Dock:Clone()
	dock.Name, dock.Visible = "CompactDock", false
	at(dock, UDim2.new(.5,0,0,62), UDim2.fromOffset(238,44), Vector2.new(.5,0))
	local dockLimit = dock:FindFirstChild("DockSizeLimit")
	if dockLimit then dockLimit.MinSize = Vector2.new(238,44) dockLimit.MaxSize = Vector2.new(238,44) end
	for index, name in {"Shop","Pets","Toys"} do
		local button = dock[name]
		at(button, UDim2.fromOffset((index-1)*82,0), UDim2.fromOffset(74,44), Vector2.zero)
		for _, child in button:GetChildren() do
			if child:IsA("ImageLabel") then at(child, UDim2.fromScale(0,0), UDim2.fromScale(1,1), Vector2.zero) end
		end
		text(button:FindFirstChild("LiveCaption"),16)
	end
	dock.Parent = shell
	local level = shell.CompactLevelPanel
	at(level, UDim2.fromOffset(8,6), UDim2.fromOffset(144,48), Vector2.zero)
	at(level.FacePreview, UDim2.fromOffset(6,8), UDim2.fromOffset(32,32), Vector2.zero)
	at(level.Level, UDim2.fromOffset(44,4), UDim2.fromOffset(94,17), Vector2.zero)
	at(level.XP, UDim2.fromOffset(44,24), UDim2.fromOffset(94,11), Vector2.zero)
	at(level.XPTrack, UDim2.fromOffset(44,39), UDim2.fromOffset(94,4), Vector2.zero)
	level.NextLevel.Visible = false
	text(level.Level,15)
	text(level.XP,11)
	local portrait = timer.Compact:Clone()
	portrait.Name, portrait.Visible = "Portrait", false
	portrait.Parent = timer
	for _, card in {timer.Compact,portrait} do
		at(card, UDim2.new(.5,0,0,card == portrait and 166 or 6), UDim2.fromOffset(224,44), Vector2.new(.5,0))
		local limit = card:FindFirstChildOfClass("UISizeConstraint")
		if limit then limit.MinSize = Vector2.new(224,44) limit.MaxSize = Vector2.new(224,44) end
		at(card.Title, UDim2.new(.04,0,0,4), UDim2.new(.64,0,0,17), Vector2.zero)
		at(card.Timer, UDim2.new(.70,0,0,2), UDim2.new(.26,0,0,22), Vector2.zero)
		at(card.Detail, UDim2.new(.04,0,0,25), UDim2.new(.92,0,0,14), Vector2.zero)
		text(card.Title,15) text(card.Timer,21) text(card.Detail,11)
		for _, child in {card.Title,card.Timer} do
			local stroke = child:FindFirstChildOfClass("UIStroke")
			if stroke then stroke.Thickness = 1.1 end
		end
	end
	local portraitBoost = fishing.CompactDock:Clone()
	portraitBoost.Name, portraitBoost.Visible = "PortraitDock", false
	portraitBoost.Parent = fishing
	local roundBoost = fishing.CompactDock:Clone()
	roundBoost.Name, roundBoost.Visible = "RoundDock", false
	roundBoost.Parent = fishing
	for _, boost in {fishing.CompactDock,portraitBoost,roundBoost} do
		local position = boost == portraitBoost and UDim2.new(.5,0,0,214)
			or boost == roundBoost and UDim2.new(.5,0,0,142) or UDim2.new(1,-8,0,112)
		at(boost,position,UDim2.fromOffset(96,38),boost == fishing.CompactDock and Vector2.new(1,0) or Vector2.new(.5,0))
		boost.LayoutScale.Scale = 1
		local layout = boost:FindFirstChildOfClass("UIListLayout")
		if layout then layout.FillDirection = Enum.FillDirection.Vertical layout.Padding = UDim.new(0,2) end
		for index, name in {"Coins","XP"} do
			local row = boost[name]
			at(row,UDim2.fromOffset(0,(index-1)*20),UDim2.fromOffset(96,18),Vector2.zero)
			for _, child in row:GetChildren() do
				if child:IsA("ImageLabel") then
					at(child,UDim2.fromOffset(0,0),UDim2.fromOffset(18,18),Vector2.zero)
				elseif child:IsA("TextLabel") then
					at(child,UDim2.fromOffset(child.Name == "Timer" and 55 or 21,0),UDim2.fromOffset(child.Name == "Timer" and 40 or 32,18),Vector2.zero)
					text(child,11)
				end
			end
		end
	end
	scale(ui.BritishBulldogHUD.TopCard,.65,.8)
	scale(ui.TagHUD.Top,.65,.8)
	scale(ui.MudHUD.Main.Top,.65,.8)
	for _, top in {ui.BritishBulldogHUD.TopCard,ui.TagHUD.Top,ui.MudHUD.Main.Top} do
		for _, label in top:GetDescendants() do
			if label:IsA("TextLabel") then
				label.TextScaled = true
				local limit = label:FindFirstChildOfClass("UITextSizeConstraint")
				if limit then limit.MinTextSize = label.Name == "Timer" and 12 or 9 end
			end
		end
	end
	local teamCaption = ui.MudHUD.Main.Top.Team:FindFirstChild("LiveCaption")
	if teamCaption then
		at(teamCaption,UDim2.fromScale(.04,.04),UDim2.fromScale(.92,.92),Vector2.zero)
		text(teamCaption,14)
	end
	local phaseLabel = ui.BritishBulldogHUD.TopCard:FindFirstChild("PhaseLabel",true)
	if phaseLabel then phaseLabel.Size = UDim2.new(phaseLabel.Size.X.Scale,phaseLabel.Size.X.Offset,.18,0) end
	for _, name in {"CompactToggle","CompactSpectate","PortraitToggle","PortraitSpectate"} do
		text(ui.PlaygroundSessionControls[name]:FindFirstChild("Label"),11)
	end
	ui.MudHUD.Main.Top.Position = UDim2.new(.5,0,0,64)
	for _, button in {ui.BritishBulldogHUD.MobileSprint,ui.TagHUD.MobileSprint,ui.MudHUD.Main.MobileSprint} do
		button.Size = UDim2.fromOffset(100,44)
		text(button:FindFirstChild("LiveCaption"),15)
	end
	ui.PlaygroundBatControls.Swing.Size = UDim2.fromOffset(88,44)
	ui.PlaygroundPushControls.MobilePush.Size = UDim2.fromOffset(76,44)
	ui.MudHUD.Main.Controls.Fire.Size = UDim2.fromOffset(100,44)
	ui.MudHUD.Main.Controls.Mud.Size = UDim2.fromOffset(50,44)
	ui.MudHUD.Main.Controls.Heat.Size = UDim2.fromOffset(50,44)
	scale(ui.BritishBulldogHUD.MovementControls,.8,.9)
	scale(ui.TagHUD.SprintPanel,.8,.9)
	local bar = ui.PlaygroundToyHotbar.Bar
	at(bar,UDim2.new(.5,0,.57,0),UDim2.fromOffset(244,58),Vector2.new(.5,0))
	at(bar.Title,UDim2.fromOffset(0,0),UDim2.fromOffset(194,12),Vector2.zero)
	at(bar.Slots,UDim2.fromOffset(0,14),UDim2.fromOffset(194,44),Vector2.zero)
	at(bar.Use,UDim2.fromOffset(200,14),UDim2.fromOffset(44,44),Vector2.zero)
	bar.Title.Visible = false
	at(bar.Status,UDim2.fromOffset(0,0),UDim2.fromOffset(244,12),Vector2.zero)
	bar.Status.Visible = true
	text(bar.Status,11)
	for index = 1,4 do
		local slot = bar.Slots["Slot"..index]
		at(slot,UDim2.fromOffset((index-1)*50,0),UDim2.fromOffset(44,44),Vector2.zero)
		slot.ItemName.Visible = false
		for _, name in {"Thumbnail","Preview"} do
			local preview = slot:FindFirstChild(name)
			if preview then at(preview,UDim2.fromOffset(4,4),UDim2.fromOffset(36,36),Vector2.zero) end
		end
	end
	local vote = shell.CompactVotePanel
	at(vote,UDim2.fromScale(.5,.5),UDim2.new(.94,0,0,164),Vector2.new(.5,.5))
	return {compactDock=dock:GetFullName(),portraitTimer=portrait:GetFullName(),boostVariants={portraitBoost:GetFullName(),roundBoost:GetFullName()}}
end
