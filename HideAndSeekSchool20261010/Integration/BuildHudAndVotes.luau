local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
assert(not game:GetService("RunService"):IsRunning(), "Stop Play before installing Hide and Seek UI.")
assert(game.PlaceId == 95034648955135, "Wrong experience.")
assert(not StarterGui:FindFirstChild("HideAndSeekHUD"), "Hide and Seek HUD already exists.")
local shell = StarterGui.PlaygroundShell
local backup = Instance.new("Folder")
backup.Name = "HideAndSeekUiBackup20261010"
assert(not ServerStorage:FindFirstChild(backup.Name), "UI backup already exists.")
backup.Parent = ServerStorage
for _, object in { shell.VotePanel, shell.CompactVotePanel, StarterGui.PlaygroundAdminPanel.AdminHub.Pages.Rounds } do
	local saved = object:Clone()
	saved.Parent = backup
end
local navy = Color3.fromRGB(24,35,62)
local cream = Color3.fromRGB(255,249,224)
local function caption(parent, name, text, position, size, maxSize, color, stroke)
	local label = Instance.new("TextLabel")
	label.Name, label.BackgroundTransparency, label.Text = name, 1, text
	label.Position, label.Size = position, size
	label.Font, label.TextScaled, label.TextColor3 = Enum.Font.FredokaOne, true, color or navy
	label.TextWrapped, label.ZIndex, label.TextTruncate = true, 5, Enum.TextTruncate.None
	label.TextScaled = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize, limit.MaxTextSize, limit.Parent = 8, maxSize, label
	if stroke then
		local outline = Instance.new("UIStroke")
		outline.Color, outline.Thickness, outline.Parent = navy, 1.2, label
	end
	label.Parent = parent
	return label
end
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.IgnoreGuiInset = "HideAndSeekHUD", false, false
gui.DisplayOrder, gui.ZIndexBehavior = 25, Enum.ZIndexBehavior.Sibling
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.ClipToDeviceSafeArea = false
gui:SetAttribute("EditableGameHUD", true)
gui:SetAttribute("GameId", "HideAndSeek")
local function header(name, width, height, maxTitle, maxHint)
	local root = Instance.new("Frame")
	root.Name, root.BackgroundTransparency, root.Visible = name, 1, false
	root.AnchorPoint, root.Position, root.Size = Vector2.new(.5,0), UDim2.new(.5,0,0,8), UDim2.fromOffset(width,height)
	local fallback = Instance.new("Frame")
	fallback.Name, fallback.Size, fallback.BackgroundColor3 = "Fallback", UDim2.fromScale(1,1), cream
	fallback.BorderSizePixel, fallback.ZIndex = 0, 1
	local corner = Instance.new("UICorner")
	corner.CornerRadius, corner.Parent = UDim.new(0,12), fallback
	local outline = Instance.new("UIStroke")
	outline.Color, outline.Thickness, outline.Parent = navy, 2, fallback
	fallback.Parent = root
	local skin = shell.Wallet.ReusableSkin:Clone()
	skin.Name, skin.AnchorPoint, skin.Position, skin.Size = "ReusableSkin", Vector2.zero, UDim2.fromScale(0,0), UDim2.fromScale(1,1)
	skin.ZIndex, skin.Parent = 2, root
	caption(root,"Title","HIDE & SEEK",UDim2.fromScale(.045,.06),UDim2.fromScale(.66,.26),maxTitle,cream,true)
	caption(root,"Timer","3:00",UDim2.fromScale(.72,.04),UDim2.fromScale(.24,.32),maxTitle+5,Color3.fromRGB(255,211,78),true)
	caption(root,"Role","HIDER",UDim2.fromScale(.045,.37),UDim2.fromScale(.24,.21),maxHint,Color3.fromRGB(68,163,245))
	caption(root,"Counts","15 hiders • 1 seeker",UDim2.fromScale(.32,.37),UDim2.fromScale(.63,.21),maxHint)
	caption(root,"Hint","Hide before the seeker is released",UDim2.fromScale(.04,.65),UDim2.fromScale(.92,.21),maxHint)
	root.Parent = gui
end
header("DesktopHeader",340,94,22,14)
header("CompactHeader",260,70,18,11)
header("PortraitHeader",240,74,17,10)
local blindfold = Instance.new("Frame")
blindfold.Name, blindfold.Size, blindfold.BackgroundColor3 = "SeekerBlindfold", UDim2.fromScale(1,1), navy
blindfold.Position, blindfold.Size = UDim2.fromOffset(-256,-256), UDim2.new(1,512,1,512)
blindfold.BorderSizePixel, blindfold.ZIndex, blindfold.Visible = 0, 100, false
local waitCard = Instance.new("Frame")
waitCard.Name, waitCard.AnchorPoint, waitCard.Position = "WaitingCard", Vector2.new(.5,.5), UDim2.fromScale(.5,.5)
waitCard.Size, waitCard.BackgroundColor3, waitCard.BorderSizePixel, waitCard.ZIndex = UDim2.fromOffset(280,150), cream, 0, 101
local waitLimit = Instance.new("UISizeConstraint")
waitLimit.MaxSize, waitLimit.Parent = Vector2.new(420,150), waitCard
local waitCorner = Instance.new("UICorner")
waitCorner.CornerRadius, waitCorner.Parent = UDim.new(0,18), waitCard
local waitTitle = caption(waitCard,"Title","EVERYONE IS HIDING",UDim2.fromScale(.06,.10),UDim2.fromScale(.88,.22),24,navy)
waitTitle.ZIndex = 110
local waitTimer = caption(waitCard,"Countdown","0:20",UDim2.fromScale(.15,.37),UDim2.fromScale(.70,.35),42,Color3.fromRGB(245,83,117),true)
waitTimer.ZIndex = 110
local waitHint = caption(waitCard,"Hint","The search begins when this timer ends",UDim2.fromScale(.06,.79),UDim2.fromScale(.88,.11),13,navy)
waitHint.ZIndex = 110
waitCard.Parent, blindfold.Parent = blindfold, gui
local function sprint(name, position, size, touch)
	local button = StarterGui.TagHUD.MobileSprint:Clone()
	button.Name, button.Position, button.Size, button.AnchorPoint = name, position, size, Vector2.new(.5,1)
	if touch then button.AnchorPoint = Vector2.new(1,1) end
	button.Visible, button.Active = false, false
	for _, child in button:GetChildren() do
		if child:IsA("GuiObject") and child.Name ~= "ReusableSkin" and child.Name ~= "ArtFallback" and child.Name ~= "Fallback" then child:Destroy() end
	end
	button.Text = ""
	caption(button,"LiveCaption","SPRINT",UDim2.fromScale(.08,.08),UDim2.fromScale(.84,.48),touch and 18 or 20,cream,true)
	caption(button,"StaminaText",touch and "10.0 / 10" or "SHIFT / L3",UDim2.fromScale(.08,.56),UDim2.fromScale(.84,.20),9,cream,true)
	local track = Instance.new("Frame")
	track.Name, track.Position, track.Size = "StaminaTrack", UDim2.fromScale(.12,.82), UDim2.fromScale(.76,.07)
	track.BorderSizePixel, track.BackgroundColor3, track.ZIndex = 0, navy, 6
	local fill = Instance.new("Frame")
	fill.Name, fill.Size, fill.BackgroundColor3 = "StaminaFill", UDim2.fromScale(1,1), Color3.fromRGB(137,241,238)
	fill.BorderSizePixel, fill.ZIndex, fill.Parent = 0, 7, track
	track.Parent, button.Parent = button, gui
end
sprint("DesktopSprint",UDim2.new(.5,0,1,-18),UDim2.fromOffset(152,48),false)
sprint("MobileSprint",UDim2.new(1,-18,1,-124),UDim2.fromOffset(100,44),true)
local exit = StarterGui.PlaygroundBatControls.Swing:Clone()
exit.Name, exit.Position, exit.Size = "LeaveLocker", UDim2.new(1,-24,1,-192), UDim2.fromOffset(100,44)
exit.Visible, exit.Active = false, true
local exitCaption = exit:FindFirstChild("Caption") or exit:FindFirstChild("LiveCaption") or exit:FindFirstChild("Label")
if exitCaption then exitCaption.Text = "LEAVE" end
if exit:FindFirstChild("Hint") then exit.Hint.Text = "E / Y" end
exit.Text, exit.TextTransparency = "LEAVE", 1
exit.Parent = gui
gui.Parent = StarterGui
for _, name in { "HideAndSeekActionRequest", "HideAndSeekSprintRequest" } do
	local existing = ReplicatedStorage:FindFirstChild(name)
	assert(not existing or existing:IsA("RemoteEvent"), "Invalid Hide and Seek remote.")
	if not existing then local remote = Instance.new("RemoteEvent") remote.Name, remote.Parent = name, ReplicatedStorage end
end
if not ReplicatedStorage:FindFirstChild("HideAndSeekState") then
	local state = Instance.new("Folder")
	state.Name, state.Parent = "HideAndSeekState", ReplicatedStorage
	state:SetAttribute("Phase","Waiting")
	state:SetAttribute("HiderCount",0)
	state:SetAttribute("SeekerCount",0)
end
local ids = { "BritishBulldog", "TagYoureIt", "StuckInTheMud", "HideAndSeek" }
for _, panel in { shell.VotePanel, shell.CompactVotePanel } do
	local school = panel.TagYoureIt:Clone()
	school.Name, school.Text = "HideAndSeek", "HIDE &\nSEEK"
	school.LiveCaption.Text = school.Text
	school.BackgroundColor3 = Color3.fromRGB(188,143,245)
	school.ReusableSkin.Image = "rbxassetid://109174047078490"
	school:SetAttribute("UISkinAssetKey","PNG/07-Resizable-Skins/purple-normal.png")
	school.ReusableSkin:SetAttribute("DefaultImage",school.ReusableSkin.Image)
	school.Parent = panel
	local counter = panel.VotesTagYoureIt:Clone()
	counter.Name, counter.Text, counter.Parent = "VotesHideAndSeek", "0 votes", panel
	for index, id in ids do
		local column, row = (index-1)%2, math.floor((index-1)/2)
		panel[id].Position, panel[id].Size = UDim2.fromScale(.04+.48*column,.24+.32*row), UDim2.fromScale(.44,.23)
		panel["Votes"..id].Position, panel["Votes"..id].Size = UDim2.fromScale(.04+.48*column,.47+.32*row), UDim2.fromScale(.44,.07)
		local captionLimit = panel[id].LiveCaption:FindFirstChildOfClass("UITextSizeConstraint")
		if captionLimit then captionLimit.MinTextSize = 8 end
	end
	panel.Message.Position, panel.Message.Size = UDim2.fromScale(.04,.9), UDim2.fromScale(.92,.07)
	if panel.Name == "CompactVotePanel" then panel.Size = UDim2.new(.94,0,0,190) end
end
local rounds = StarterGui.PlaygroundAdminPanel.AdminHub.Pages.Rounds
local schoolAdmin = rounds.TagYoureIt:Clone()
schoolAdmin.Name, schoolAdmin.Size, schoolAdmin.LayoutOrder = "HideAndSeek", UDim2.new(1,-8,0,122), 4
schoolAdmin.Title.Text, schoolAdmin.Status.Text = "HIDE & SEEK", "Ready • 2–16 players"
schoolAdmin.TagRunner:Destroy()
schoolAdmin.TagTagger:Destroy()
schoolAdmin.TagStart.Name = "HSStart"
schoolAdmin.HSStart.Text, schoolAdmin.HSStart.LiveCaption.Text = "START SCHOOL ROUND", "START SCHOOL ROUND"
rounds.RoundSettings.LayoutOrder = 5
schoolAdmin.Parent = rounds
return { hud = gui:GetFullName(), votingChoices = 4, adminControl = "HSStart", editable = true }
