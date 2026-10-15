assert(not game:GetService("RunService"):IsRunning(), "Stop Play before editing voting stands.")
assert(game.PlaceId == 95034648955135, "Wrong experience.")
local lobby = workspace["Playground Lobby"]
local alcove, choices = lobby.VotingAlcove,lobby.Gameplay.VoteChoices
if choices:FindFirstChild("DuckDuckGoose") then return {alreadyInstalled=true} end
assert(not alcove:FindFirstChild("DuckDuckGooseStand"), "Partial fifth voting stand installation")
local storage = game:GetService("ServerStorage")
local backup = Instance.new("Folder")
backup.Name, backup.Parent = "DuckDuckGooseWorldVoteBackup20261010",storage
for _, object in {alcove,choices,lobby.Gameplay.VoteZone} do object:Clone().Parent = backup end
local stand = alcove.HideAndSeekStand:Clone()
stand.Name = "DuckDuckGooseStand"
for _, item in stand:GetDescendants() do
	if item:IsA("BasePart") then
		item.Anchored,item.Locked = true,true
		if item.Name == "ChoicePad" or item.Name == "ChoiceCardFace" or item.Name == "ArchTop" then item.Color = Color3.fromRGB(246,189,62) end
	elseif item:IsA("Highlight") then item.Adornee = stand
	elseif item:IsA("TextLabel") then
		item.Text = "Duck Duck\nGoose"
		item.TextTruncate,item.TextWrapped = Enum.TextTruncate.None,true
		item.TextScaled = true
	elseif item:IsA("ImageLabel") and item.Name == "ReusableSkin" then
		item.Image = "rbxassetid://84589903135132"
		item:SetAttribute("DefaultImage",item.Image)
	end
end
stand.Parent = alcove
local trigger = choices.HideAndSeek:Clone()
trigger.Name = "DuckDuckGoose"
trigger:SetAttribute("GameId","DuckDuckGoose")
trigger:SetAttribute("DisplayName","Duck Duck Goose")
trigger:SetAttribute("Available",true)
trigger.Parent = choices
local ids = {"BritishBulldog","TagYoureIt","StuckInTheMud","HideAndSeek","DuckDuckGoose"}
for index,id in ids do
	local model = alcove[id.."Stand"]
	local _,bounds = model:GetBoundingBox()
	model:ScaleTo(model:GetScale()*11.9/bounds.X)
	local pad = model.ChoicePad
	local target = Vector3.new(62.8+12.6*(index-1),4.6832,-84)
	model:PivotTo(model:GetPivot()+(target-pad.Position))
	choices[id].CFrame = pad.CFrame + Vector3.new(0,3,0)
	choices[id].Size = Vector3.new(pad.Size.X,6,pad.Size.Z)
	choices[id].CanCollide,choices[id].CanTouch,choices[id].CanQuery = false,false,false
	choices[id].Transparency = 1
end
lobby.Gameplay.VoteZone:SetAttribute("AvailableGames",table.concat(ids,","))
return {choices=#ids,standWidth=11.9,padsFitExistingAlcove=true}
