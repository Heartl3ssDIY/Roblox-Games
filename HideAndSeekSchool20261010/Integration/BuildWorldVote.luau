local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
assert(not RunService:IsRunning(), "Stop Play before editing voting stands.")
assert(game.PlaceId == 95034648955135, "Wrong experience.")
local lobby = workspace["Playground Lobby"]
local alcove, choices = lobby.VotingAlcove, lobby.Gameplay.VoteChoices
assert(not choices:FindFirstChild("HideAndSeek") and not alcove:FindFirstChild("HideAndSeekStand"), "School voting stand already exists.")
assert(not ServerStorage:FindFirstChild("HideAndSeekVoteBackup20261010"), "Voting backup already exists.")
local backup = Instance.new("Folder")
backup.Name, backup.Parent = "HideAndSeekVoteBackup20261010", ServerStorage
for _, id in { "BritishBulldog", "TagYoureIt", "StuckInTheMud" } do
	local stand = alcove[id.."Stand"]:Clone()
	stand.Parent = backup
	local trigger = choices[id]:Clone()
	trigger.Name, trigger.Parent = "Trigger"..id, backup
end
local school = alcove.TagYoureItStand:Clone()
school.Name = "HideAndSeekStand"
local purple = Color3.fromRGB(173,132,238)
for _, child in school:GetDescendants() do
	if child:IsA("BasePart") then
		child.Anchored, child.Locked = true, true
		if child.Name == "ChoicePad" or child.Name == "ChoiceCardFace" or child.Name == "ArchTop" then child.Color = purple end
	elseif child:IsA("Highlight") then child.Adornee = school
	elseif child:IsA("TextLabel") then child.Text = "Hide & Seek"
	elseif child:IsA("ImageLabel") and child.Name == "ReusableSkin" then
		child.Image = "rbxassetid://109174047078490"
		child:SetAttribute("DefaultImage",child.Image)
	end
end
school.Parent = alcove
local trigger = choices.TagYoureIt:Clone()
trigger.Name = "HideAndSeek"
trigger:SetAttribute("GameId","HideAndSeek")
trigger:SetAttribute("DisplayName","Hide & Seek")
trigger:SetAttribute("Available",true)
trigger.Parent = choices
local ids = { "BritishBulldog", "TagYoureIt", "StuckInTheMud", "HideAndSeek" }
for index, id in ids do
	local stand = alcove[id.."Stand"]
	local pad = stand.ChoicePad
	local delta = Vector3.new(64+16*(index-1)-pad.Position.X,0,0)
	stand:PivotTo(stand:GetPivot()+delta)
	choices[id].CFrame += delta
end
lobby.Gameplay.VoteZone:SetAttribute("AvailableGames",table.concat(ids,","))
return { choices = #ids, schoolPad = trigger.Position, insideExistingAlcove = true }
