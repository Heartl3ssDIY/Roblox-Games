return function(ui)
	local function place(item, position, size, anchor)
		item.Position, item.Size, item.AnchorPoint = position, size, anchor or Vector2.zero
	end
	local function limitText(item, maximum)
		item.TextScaled = true
		local limit = item:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
		limit.MinTextSize, limit.MaxTextSize, limit.Parent = 8, maximum, item
	end
	local shell, timer, session = ui.PlaygroundShell, ui.PlaygroundIntermissionHUD, ui.PlaygroundSessionControls
	place(shell.Wallet.CoinsCaption,UDim2.fromOffset(58,4),UDim2.new(1,-68,0,12))
	place(shell.Wallet.Coins,UDim2.fromOffset(58,18),UDim2.new(1,-68,0,28))
	limitText(shell.Wallet.CoinsCaption,12)
	local level = shell.CompactLevelPanel
	place(level, UDim2.fromOffset(8,6), UDim2.fromOffset(128,44))
	place(level.FacePreview, UDim2.fromOffset(6,7), UDim2.fromOffset(28,28))
	place(level.Level, UDim2.fromOffset(40,4), UDim2.fromOffset(82,15))
	place(level.XP, UDim2.fromOffset(40,20), UDim2.fromOffset(82,12))
	place(level.XPTrack, UDim2.fromOffset(40,34), UDim2.fromOffset(82,4))
	limitText(level.Level,14) limitText(level.XP,10)
	place(shell.CompactDock, UDim2.new(.5,0,1,-8), UDim2.fromOffset(238,44), Vector2.new(.5,1))
	local portraitDock = shell.CompactDock:Clone()
	portraitDock.Name, portraitDock.Visible = "PortraitDock", false
	portraitDock.Parent = shell
	place(portraitDock, UDim2.new(.5,0,1,-148), UDim2.fromOffset(238,44), Vector2.new(.5,1))
	for _, card in {timer.Compact,timer.Portrait} do
		place(card, UDim2.new(.5,0,0,card == timer.Portrait and 108 or 6), card == timer.Portrait and UDim2.fromOffset(224,44) or UDim2.new(1,-288,0,44), Vector2.new(.5,0))
		local limit = card:FindFirstChildOfClass("UISizeConstraint")
		limit.MinSize, limit.MaxSize = Vector2.new(160,44), Vector2.new(224,44)
		place(card.Title,UDim2.fromOffset(8,4),UDim2.new(.72,-12,0,16))
		place(card.Timer,UDim2.new(.72,0,0,3),UDim2.new(.28,-8,0,18))
		place(card.Detail,UDim2.fromOffset(8,22),UDim2.new(1,-16,0,13))
		limitText(card.Title,14) limitText(card.Timer,19) limitText(card.Detail,10)
		card.Detail.TextColor3 = Color3.fromRGB(29,34,53)
		card.Detail.TextYAlignment = Enum.TextYAlignment.Center
		card.Detail.ZIndex = 4
	end
	for _, name in {"CompactToggle","PortraitToggle"} do
		place(session[name],UDim2.fromOffset(8,56),UDim2.fromOffset(44,44))
	end
	for _, name in {"CompactSpectate","PortraitSpectate"} do
		place(session[name],UDim2.fromOffset(60,56),UDim2.fromOffset(44,44))
	end
	for _, name in {"CompactRoundToggle","PortraitRoundToggle"} do
		place(session[name],UDim2.fromOffset(8,6),UDim2.fromOffset(44,44))
	end
	for _, name in {"CompactEmoteToggle","PortraitEmoteToggle"} do
		place(ui.PlaygroundEmoteWheel[name],UDim2.new(1,-8,0,56),UDim2.fromOffset(80,44),Vector2.new(1,0))
	end
	place(session.Toggle,UDim2.new(1,-122,1,-18),UDim2.fromOffset(44,44),Vector2.new(1,1))
	place(session.Spectate,UDim2.new(1,-70,1,-18),UDim2.fromOffset(44,44),Vector2.new(1,1))
	local admin = session.Dock.Body.AFK:Clone()
	admin.Name, admin.Visible = "AdminAccess", false
	admin.Label.Text = "ADMIN PANEL"
	admin.Parent = session.Dock.Body
	place(admin,UDim2.new(0,14,0,320),UDim2.new(1,-28,0,46))
	session.Dock.Body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	session.Dock.Body.CanvasSize = UDim2.new()
	local bodyPadding = session.Dock.Body:FindFirstChildOfClass("UIPadding") or Instance.new("UIPadding")
	bodyPadding.PaddingBottom = UDim.new(0,12) bodyPadding.Parent = session.Dock.Body
	for _, item in {ui.PlaygroundFishingHUD.CompactDock,ui.PlaygroundFishingHUD.PortraitDock} do
		place(item,UDim2.new(1,-8,0,104),UDim2.fromOffset(96,38),Vector2.new(1,0))
	end
	place(ui.PlaygroundFishingHUD.PortraitDock,UDim2.new(.5,0,1,-202),UDim2.fromOffset(96,38),Vector2.new(.5,1))
	place(ui.PlaygroundFishingHUD.RoundDock,UDim2.new(0,8,0,92),UDim2.fromOffset(96,38))
	local bar = ui.PlaygroundToyHotbar.Bar
	place(bar,UDim2.new(.5,0,.57,0),UDim2.fromOffset(244,58),Vector2.new(.5,0))
	ui.PlaygroundToyHotbar.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	for _, name in {"BritishBulldogHUD","TagHUD","HideAndSeekHUD","DuckDuckGooseHUD"} do
		place(ui[name].MobileSprint,UDim2.new(1,-16,1,-138),UDim2.fromOffset(100,44),Vector2.new(1,1))
	end
	place(ui.MudHUD.Main.MobileSprint,UDim2.new(1,-16,1,-138),UDim2.fromOffset(100,44),Vector2.new(1,1))
	place(ui.PlaygroundBatControls.Swing,UDim2.new(1,-16,1,-188),UDim2.fromOffset(100,44),Vector2.new(1,1))
	place(ui.HideAndSeekHUD.LeaveLocker,UDim2.new(1,-16,1,-188),UDim2.fromOffset(100,44),Vector2.new(1,1))
	ui.HideAndSeekHUD.LeaveLocker.Caption.Text = "LEAVE"
	ui.HideAndSeekHUD.LeaveLocker.Text = "LEAVE"
	for _,name in {"DesktopSprint","MobileSprint"} do ui.HideAndSeekHUD[name].StaminaText.Text="25.0 / 25" end
	local function fallback(target, color)
		local skin = target:FindFirstChild("ReusableSkin")
		if not skin or target:FindFirstChild("ReusableSkinFallback") then return end
		local panel = Instance.new("Frame")
		panel.Name = "ReusableSkinFallback"
		panel:SetAttribute("BackgroundFallbackFor","ReusableSkin")
		panel:SetAttribute("FallbackFaceColor",color)
		panel.BackgroundColor3, panel.BorderSizePixel = Color3.fromRGB(31,38,60), 0
		panel.Position, panel.Size, panel.AnchorPoint = skin.Position, skin.Size, skin.AnchorPoint
		panel.ZIndex, panel.Visible = skin.ZIndex, not skin.IsLoaded
		local corner = Instance.new("UICorner") corner.CornerRadius=UDim.new(0,12) corner.Parent=panel
		local edge = Instance.new("Frame") edge.Name="Edge" edge.Position=UDim2.fromOffset(2,2) edge.Size=UDim2.new(1,-4,1,-7) edge.BorderSizePixel=0 edge.BackgroundColor3=Color3.fromRGB(255,249,224) edge.ZIndex=panel.ZIndex edge.Parent=panel
		local edgeCorner=corner:Clone() edgeCorner.Parent=edge
		local face=Instance.new("Frame") face.Name="Face" face.Position=UDim2.fromOffset(2,2) face.Size=UDim2.new(1,-4,1,-4) face.BorderSizePixel=0 face.BackgroundColor3=color face.ZIndex=panel.ZIndex face.Parent=edge
		local faceCorner=corner:Clone() faceCorner.Parent=face
		panel.Parent=target
	end
	fallback(shell.CompactLevelPanel,Color3.fromRGB(255,249,224))
	fallback(shell.Wallet,Color3.fromRGB(255,249,224))
	for _,dock in {shell.CompactDock,portraitDock} do
		for _,name in {"Shop","Pets","Toys"} do fallback(dock[name],name=="Toys" and Color3.fromRGB(176,188,206) or Color3.fromRGB(255,205,57)) end
	end
	for _, gui in ui:GetChildren() do if gui:IsA("ScreenGui") then gui:SetAttribute("MobilePlacementVersion","20261011") end end
	return {portraitDock=portraitDock.Name,adminInSettings=true}
end
