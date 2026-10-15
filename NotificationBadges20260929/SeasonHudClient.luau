local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local sidebar = script.Parent:WaitForChild("Sidebar")
local seasonRank = sidebar:WaitForChild("SeasonRank")
local trophyCount = seasonRank:WaitForChild("TrophyCount")
local leagueIcon = seasonRank:WaitForChild("LeagueIcon")
local rankBadge = seasonRank:WaitForChild("Badge")
rankBadge.Visible = false
local portraitSlot = sidebar:WaitForChild("PlayerStats"):WaitForChild("PortraitSlot")
local thumbnail = portraitSlot:WaitForChild("AvatarThumbnail")
local viewport = portraitSlot:WaitForChild("AvatarViewport")
local world = viewport:WaitForChild("WorldModel")
local camera = Instance.new("Camera")
camera.Name = "PortraitCamera"
camera.Parent = viewport

local SeasonPassData = require(ReplicatedStorage:WaitForChild("SeasonPassData"))
local ProfileClientBridge = require(ReplicatedStorage:WaitForChild("ProfileClientBridge"))

local leagueImages = {
    Bronze = "rbxassetid://71220103095723",
    Silver = "rbxassetid://82737174213366",
    Gold = "rbxassetid://110275007352028",
    Platinum = "rbxassetid://78599681156713",
    Diamond = "rbxassetid://77131391309932",
}

local observedTrophies
local observedLeague

local function refreshRank()
    if not player:GetAttribute("ProfileClientReady") then return end
    local trophies = math.floor(SeasonPassData.trophies())
    trophyCount.Text = tostring(trophies)
    local league = ProfileClientBridge.league()
    if not leagueImages[league] then league = "Bronze" end
    leagueIcon.Image = leagueImages[league]
    seasonRank:SetAttribute("CurrentLeague", league)
    if observedTrophies ~= nil and (trophies ~= observedTrophies or league ~= observedLeague) then
        rankBadge.Visible = true
    end
    observedTrophies = trophies
    observedLeague = league
end

local function showCharacter(character)
    local head = character:WaitForChild("Head", 5)
    if not head or not character.Parent then return end
    local archivable = character.Archivable
    character.Archivable = true
    local copy = character:Clone()
    character.Archivable = archivable
    if not copy then return end
    for _, object in ipairs(copy:GetDescendants()) do
        if object:IsA("BaseScript") then
            object:Destroy()
        elseif object:IsA("BasePart") then
            object.Anchored = true
            object.CanCollide = false
        end
    end
    world:ClearAllChildren()
    copy.Parent = world
    copy:PivotTo(CFrame.new())
    local clonedHead = copy:FindFirstChild("Head", true)
    if not clonedHead then
        copy:Destroy()
        return
    end
    local focus = clonedHead.Position + clonedHead.CFrame.UpVector * 0.1
    camera.CFrame = CFrame.lookAt(focus + clonedHead.CFrame.LookVector * 3, focus)
    camera.FieldOfView = 35
    viewport.CurrentCamera = camera
    viewport.Visible = true
    thumbnail.Visible = false
end

task.spawn(function()
    local ok, image = pcall(function()
        return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
    end)
    if ok and image then thumbnail.Image = image end
end)

player.CharacterAdded:Connect(function(character)
    task.defer(showCharacter, character)
end)
player.CharacterAppearanceLoaded:Connect(function(character)
    task.defer(showCharacter, character)
end)
if player.Character then task.defer(showCharacter, player.Character) end

SeasonPassData.Changed:Connect(function()
    task.defer(refreshRank)
end)
player:GetAttributeChangedSignal("ProfileClientReady"):Connect(refreshRank)
seasonRank.Activated:Connect(function()
    rankBadge.Visible = false
end)
refreshRank()
