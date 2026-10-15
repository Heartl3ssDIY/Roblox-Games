local starter = game:GetService("StarterGui")
local HttpService = game:GetService("HttpService")
local source = Instance.new("Folder")
source.Name = "PhoneHudQASource"
for _, gui in starter:GetChildren() do
    if gui:IsA("ScreenGui") then
        local clone = gui:Clone()
        for _, descendant in clone:GetDescendants() do
            if descendant:IsA("LuaSourceContainer") then descendant:Destroy() end
        end
        clone.Parent = source
    end
end

if not source.PlaygroundShell:FindFirstChild("CompactDock") then
(function()
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
	local phaseLabel = ui.BritishBulldogHUD.TopCard:FindFirstChild("PhaseLabel")
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

end)()(source,true)
end

local part = Instance.new("Part")
part.Name = "PhoneHudNativeQA20261009"
part.Size = Vector3.new(85.2, 39.3, 1)
part.CFrame = CFrame.new(0, -20000, 0)
part.Anchored = true
part.CanCollide = false
part.CanTouch = false
part.CanQuery = false
part.Transparency = 1
part.Parent = workspace

local viewports = {
    {name="phone_landscape_reference", width=852, height=393, left=44, top=24, right=44, bottom=21},
    {name="phone_landscape_small", width=568, height=320, left=0, top=0, right=0, bottom=0},
    {name="phone_landscape_standard", width=667, height=375, left=0, top=0, right=0, bottom=0},
    {name="phone_landscape_notch", width=844, height=390, left=44, top=0, right=44, bottom=21},
    {name="phone_portrait_small", width=320, height=568, left=0, top=20, right=0, bottom=0},
    {name="phone_portrait_standard", width=375, height=667, left=0, top=20, right=0, bottom=0},
    {name="phone_portrait_notch", width=390, height=844, left=0, top=44, right=0, bottom=34},
    {name="ipad_portrait", width=768, height=1024, left=0, top=24, right=0, bottom=20},
    {name="ipad_landscape", width=1024, height=768, left=0, top=24, right=0, bottom=20},
    {name="laptop", width=1365, height=768, left=0, top=0, right=0, bottom=0, keyboard=true},
    {name="desktop", width=1920, height=1080, left=0, top=0, right=0, bottom=0, keyboard=true},
}

local function resolve(parent, path)
    for name in path:gmatch("[^.]+") do
        parent = parent and parent:FindFirstChild(name)
    end
    return parent
end

local function visible(parent, path, value)
    local object = resolve(parent, path)
    if object and object:IsA("GuiObject") then object.Visible = value end
end

local function rectangle(object)
    local p, s = object.AbsolutePosition, object.AbsoluteSize
    return {x=p.X, y=p.Y, width=s.X, height=s.Y}
end

local function overlap(a, b)
    local width = math.min(a.x+a.width, b.x+b.width) - math.max(a.x,b.x)
    local height = math.min(a.y+a.height, b.y+b.height) - math.max(a.y,b.y)
    return width > 0.5 and height > 0.5, math.max(0,width)*math.max(0,height)
end

local function shown(object)
    while object do
        if object:IsA("GuiObject") and not object.Visible then return false end
        object = object.Parent
    end
    return true
end

local function profile(viewport)
    local shortest = math.min(viewport.width, viewport.height)
    if viewport.width <= 900 or shortest <= 600 then return "PhoneScale" end
    if shortest <= 1024 and math.max(viewport.width, viewport.height) <= 1400 then return "TabletScale" end
    return "DesktopScale"
end

local function configure(clones, viewport, scenario)
    local compact = viewport.width < 980 or viewport.height < 450
    local intermissionCompact = viewport.width < 900 or viewport.height < 600
    local inRound = scenario:sub(1,5) ~= "lobby"
    local hasBoosts = scenario:find("boosts",1,true) ~= nil
    local hasToys = scenario:find("toys",1,true) ~= nil
    for _, gui in clones:GetChildren() do
        for _, object in gui:GetDescendants() do
            if object:IsA("UIScale") and object.Name == "ResponsiveHudScale" then
                object.Scale = math.clamp(object:GetAttribute(profile(viewport)) or 1, 0.35, 1)
            end
        end
    end
    visible(clones, "PlaygroundShell.Dock", not inRound)
    visible(clones, "PlaygroundShell.Wallet", not inRound)
    visible(clones, "PlaygroundShell.LevelPanel", not (compact and inRound))
    visible(clones, "PlaygroundShell.CompactLevelPanel", compact and inRound)
    visible(clones, "PlaygroundEmoteWheel.Toggle", not inRound)
    visible(clones, "PlaygroundSessionControls.Toggle", not inRound)
    visible(clones, "PlaygroundSessionControls.Spectate", not inRound)
    visible(clones, "PlaygroundSessionControls.RoundToggle", inRound)
    visible(clones, "PlaygroundIntermissionHUD.Desktop", not inRound and not intermissionCompact)
    visible(clones, "PlaygroundIntermissionHUD.Compact", not inRound and intermissionCompact)
    visible(clones, "PlaygroundFishingHUD.DesktopDock", not compact and hasBoosts)
    visible(clones, "PlaygroundFishingHUD.CompactDock", compact and hasBoosts)
    for _, dockName in {"DesktopDock", "CompactDock"} do
        for _, boost in {"Coins", "XP"} do visible(clones, "PlaygroundFishingHUD."..dockName.."."..boost, hasBoosts) end
    end
    visible(clones, "PlaygroundToyHotbar.Bar", hasToys)
    visible(clones, "BritishBulldogHUD.TopCard", scenario=="bulldog")
    visible(clones, "BritishBulldogHUD.MobileSprint", scenario=="bulldog")
    visible(clones, "BritishBulldogHUD.MovementControls", scenario=="bulldog")
    visible(clones, "BritishBulldogHUD.MovementControls.Sprint", false)
    visible(clones, "TagHUD.Top", scenario=="tag")
    visible(clones, "TagHUD.MobileSprint", scenario=="tag")
    visible(clones, "TagHUD.SprintPanel", scenario=="tag")
    visible(clones, "TagHUD.SprintPanel.Sprint", false)
    visible(clones, "MudHUD.Main", scenario=="mud")
    visible(clones, "MudHUD.Main.Controls", scenario=="mud")
    visible(clones, "MudHUD.Main.MobileSprint", scenario=="mud")
    visible(clones, "MudHUD.Main.Controls.Sprint", false)
    visible(clones, "PlaygroundBatControls.Swing", scenario=="bulldog" or scenario=="tag")
    visible(clones, "PlaygroundPushControls.MobilePush", scenario=="bulldog" or scenario=="tag")
    -- Candidate visibility selection is inserted here, after the baseline selection.
    local short = math.min(viewport.width,viewport.height)
    local compact = viewport.width<=900 or short<=600 or (short<=1024 and math.max(viewport.width,viewport.height)<=1400)
    local portrait = compact and viewport.height>viewport.width
    visible(clones,"PlaygroundShell.LevelPanel",not compact)
    visible(clones,"PlaygroundShell.CompactLevelPanel",compact and not inRound)
    visible(clones,"PlaygroundShell.Dock",not compact and not inRound)
    visible(clones,"PlaygroundShell.CompactDock",compact and not inRound)
    visible(clones,"PlaygroundSessionControls.Toggle",not compact and not inRound)
    visible(clones,"PlaygroundSessionControls.Spectate",not compact and not inRound)
    visible(clones,"PlaygroundSessionControls.CompactToggle",compact and not portrait and not inRound)
    visible(clones,"PlaygroundSessionControls.CompactSpectate",compact and not portrait and not inRound)
    visible(clones,"PlaygroundSessionControls.PortraitToggle",portrait and not inRound)
    visible(clones,"PlaygroundSessionControls.PortraitSpectate",portrait and not inRound)
    visible(clones,"PlaygroundSessionControls.RoundToggle",not compact and inRound)
    visible(clones,"PlaygroundSessionControls.CompactRoundToggle",compact and not portrait and inRound)
    visible(clones,"PlaygroundSessionControls.PortraitRoundToggle",portrait and inRound)
    visible(clones,"BritishBulldogHUD.MovementControls.Meter",not compact)
    visible(clones,"TagHUD.SprintPanel.Meter",not compact)
    visible(clones,"PlaygroundEmoteWheel.Toggle",not compact and not inRound)
    visible(clones,"PlaygroundEmoteWheel.CompactEmoteToggle",compact and not portrait and not inRound)
    visible(clones,"PlaygroundEmoteWheel.PortraitEmoteToggle",portrait and not inRound)
    visible(clones,"PlaygroundIntermissionHUD.Desktop",not compact and not inRound)
    visible(clones,"PlaygroundIntermissionHUD.Compact",compact and not portrait and not inRound)
    visible(clones,"PlaygroundIntermissionHUD.Portrait",portrait and not inRound)
    visible(clones,"PlaygroundFishingHUD.DesktopDock",not compact and hasBoosts)
    visible(clones,"PlaygroundFishingHUD.CompactDock",compact and not portrait and hasBoosts)
    visible(clones,"PlaygroundFishingHUD.PortraitDock",portrait and hasBoosts)
    visible(clones,"PlaygroundFishingHUD.RoundDock",compact and inRound)
    for _,dockName in {"DesktopDock","CompactDock","PortraitDock","RoundDock"} do
        for _,boost in {"Coins","XP"} do visible(clones,"PlaygroundFishingHUD."..dockName.."."..boost,hasBoosts or inRound) end
    end
    local wallet=resolve(clones,"PlaygroundShell.Wallet.Coins")
    if wallet then wallet.Text="100,000" end
    local level=resolve(clones,"PlaygroundShell.CompactLevelPanel")
    if level then
        level.Level.Text="LV 500"
        level.NextLevel.Text="NEXT: LV 501"
        level.XP.Text="99,999 / 100,000 XP"
    end
    for _,cardName in {"Compact","Portrait"} do
        local card=resolve(clones,"PlaygroundIntermissionHUD."..cardName)
        if card then card.Title.Text="WAITING" card.Timer.Text="" card.Detail.Text="Players ready: 1 / 2" end
    end

end

local relevant = {
    "PlaygroundShell.Dock", "PlaygroundShell.Wallet", "PlaygroundShell.LevelPanel", "PlaygroundShell.CompactLevelPanel",
    "PlaygroundEmoteWheel.Toggle", "PlaygroundSessionControls.Toggle", "PlaygroundSessionControls.Spectate", "PlaygroundSessionControls.RoundToggle",
    "PlaygroundIntermissionHUD.Desktop", "PlaygroundIntermissionHUD.Compact", "PlaygroundFishingHUD.DesktopDock", "PlaygroundFishingHUD.CompactDock",
    "PlaygroundToyHotbar.Bar", "BritishBulldogHUD.TopCard", "BritishBulldogHUD.MobileSprint", "BritishBulldogHUD.MovementControls.Meter", "BritishBulldogHUD.CompactDeparture",
    "TagHUD.Top", "TagHUD.MobileSprint", "TagHUD.SprintPanel.Meter", "MudHUD.Main.Top", "MudHUD.Main.MobileSprint", "MudHUD.Main.Controls.Fire", "MudHUD.Main.Controls.Mud", "MudHUD.Main.Controls.Heat",
    "PlaygroundBatControls.Swing", "PlaygroundPushControls.MobilePush",
    "PlaygroundShell.CompactDock",
    "PlaygroundSessionControls.CompactToggle",
    "PlaygroundSessionControls.CompactSpectate",
    "PlaygroundSessionControls.PortraitToggle",
    "PlaygroundSessionControls.PortraitSpectate",
    "PlaygroundSessionControls.CompactRoundToggle",
    "PlaygroundSessionControls.PortraitRoundToggle",
    "PlaygroundEmoteWheel.CompactEmoteToggle",
    "PlaygroundEmoteWheel.PortraitEmoteToggle",
    "PlaygroundIntermissionHUD.Portrait",
    "PlaygroundFishingHUD.PortraitDock",
    "PlaygroundFishingHUD.RoundDock",
}

local records = {}
local ok, failure = pcall(function()
    for _, viewport in viewports do
        for _, scenario in viewport.keyboard and {"lobby", "lobby_boosts", "lobby_toys", "lobby_toys_boosts"} or {"lobby", "lobby_boosts", "lobby_toys", "lobby_toys_boosts", "bulldog", "tag", "mud"} do
            local clones = source:Clone()
            configure(clones, viewport, scenario)
            local surface = Instance.new("SurfaceGui")
            surface.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
            surface.CanvasSize = Vector2.new(viewport.width, viewport.height)
            surface.Parent = part
            local roots = Instance.new("Folder")
            roots.Name = "ClonedScreenGuiWrappers"
            roots.Parent = surface
            for _, gui in clones:GetChildren() do
                local wrapper = Instance.new("Frame")
                wrapper.Name = gui.Name
                wrapper.BackgroundTransparency = 1
                local hasInsets = gui.ScreenInsets ~= Enum.ScreenInsets.None
                local device = hasInsets and gui.ScreenInsets == Enum.ScreenInsets.DeviceSafeInsets
                local x = hasInsets and viewport.left or 0
                local y = hasInsets and viewport.top + (device and 0 or 58) or 0
                local right = hasInsets and viewport.right or 0
                local bottom = hasInsets and viewport.bottom or 0
                wrapper.Position = UDim2.fromOffset(x,y)
                wrapper.Size = UDim2.fromOffset(viewport.width-x-right, viewport.height-y-bottom)
                wrapper:SetAttribute("OriginalScreenInsets",tostring(gui.ScreenInsets))
                wrapper:SetAttribute("OriginalDisplayOrder",gui.DisplayOrder)
                wrapper.Parent = roots
                for _, child in gui:GetChildren() do child.Parent = wrapper end
                gui:Destroy()
            end
            clones:Destroy()
            task.wait(.03)
            local active = {}
            local failures, warnings, measurements = {}, {}, {}
            for _, path in relevant do
                local object = resolve(roots,path)
                if object and shown(object) then
                    local rect = rectangle(object)
                    active[#active+1]={path=path,object=object,rect=rect}
                    measurements[path]=rect
                    if rect.x < -0.5 or rect.y < -0.5 or rect.x+rect.width>viewport.width+0.5 or rect.y+rect.height>viewport.height+0.5 then
                        failures[#failures+1]="Offscreen: "..path
                    end
                    for _, text in object:GetDescendants() do
                        if text:IsA("TextLabel") and shown(text) and text.Text~="" and not text.TextFits then warnings[#warnings+1]="Text overflow: "..path.."/"..text.Name end
                        if text:IsA("GuiObject") and shown(text) and not text:IsA("ViewportFrame") then
                            local childRect=rectangle(text)
                            if childRect.x < -0.5 or childRect.y < -0.5 or childRect.x+childRect.width>viewport.width+0.5 or childRect.y+childRect.height>viewport.height+0.5 then
                                failures[#failures+1]="Descendant offscreen: "..path.."/"..text.Name
                            end
                            if path:find("FishingHUD",1,true) and (text.Name=="Coins" or text.Name=="XP") then
                                if childRect.x<rect.x-0.5 or childRect.y<rect.y-0.5 or childRect.x+childRect.width>rect.x+rect.width+0.5 or childRect.y+childRect.height>rect.y+rect.height+0.5 then
                                    failures[#failures+1]="Boost row escapes its dock: "..path.."/"..text.Name
                                end
                            end
                        end
                    end
                end
            end
            for a=1,#active do
                for b=a+1,#active do
                    local first, second = active[a],active[b]
                    if not first.object:IsDescendantOf(second.object) and not second.object:IsDescendantOf(first.object) then
                        local collides, area = overlap(first.rect,second.rect)
                        if collides then failures[#failures+1]=string.format("Overlap %.0fpx²: %s / %s",area,first.path,second.path) end
                    end
                end
            end
            local usableWidth = viewport.width - viewport.left - viewport.right
            local usableBottom = viewport.height - viewport.bottom
            local reserved = {
                {name="Roblox top bar", rect={x=viewport.left,y=viewport.top,width=math.min(280,usableWidth),height=58}},
            }
            if not viewport.keyboard then
                reserved[#reserved+1]={name="joystick", rect={x=viewport.left,y=usableBottom-120,width=120,height=120}}
                reserved[#reserved+1]={name="jump", rect={x=viewport.width-viewport.right-98,y=usableBottom-98,width=98,height=98}}
            end
            local area = 0
            for _, entry in active do
                area += entry.rect.width*entry.rect.height
                for _, zone in reserved do
                    if overlap(entry.rect,zone.rect) then failures[#failures+1]="Reserved control overlap: "..entry.path.." / "..zone.name end
                end
            end
            records[#records+1]={viewport=viewport.name,size={viewport.width,viewport.height},scenario=scenario,failures=failures,warnings=warnings,measurements=measurements,sceneOccupancy=area/(viewport.width*viewport.height)}
            surface:Destroy()
        end
    end
end)
source:Destroy()
part:Destroy()
assert(ok,failure)
return HttpService:JSONEncode({records=records,playStarted=false,productionChanged=false,insetsEmulated=true})
