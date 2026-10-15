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
    -- __CANDIDATE_PROFILE__
end

local relevant = {
    "PlaygroundShell.Dock", "PlaygroundShell.Wallet", "PlaygroundShell.LevelPanel", "PlaygroundShell.CompactLevelPanel",
    "PlaygroundEmoteWheel.Toggle", "PlaygroundSessionControls.Toggle", "PlaygroundSessionControls.Spectate", "PlaygroundSessionControls.RoundToggle",
    "PlaygroundIntermissionHUD.Desktop", "PlaygroundIntermissionHUD.Compact", "PlaygroundFishingHUD.DesktopDock", "PlaygroundFishingHUD.CompactDock",
    "PlaygroundToyHotbar.Bar", "BritishBulldogHUD.TopCard", "BritishBulldogHUD.MobileSprint", "BritishBulldogHUD.MovementControls.Meter", "BritishBulldogHUD.CompactDeparture",
    "TagHUD.Top", "TagHUD.MobileSprint", "TagHUD.SprintPanel.Meter", "MudHUD.Main.Top", "MudHUD.Main.MobileSprint", "MudHUD.Main.Controls.Fire", "MudHUD.Main.Controls.Mud", "MudHUD.Main.Controls.Heat",
    "PlaygroundBatControls.Swing", "PlaygroundPushControls.MobilePush",
    -- __CANDIDATE_ROOTS__
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
