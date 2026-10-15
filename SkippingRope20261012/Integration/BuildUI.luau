assert(not game:GetService("RunService"):IsRunning(), "Edit only")
local backup = assert(game.ServerStorage:FindFirstChild("SkippingRopeIntegrationBackup20261012"))
local gui = game.StarterGui
local rounds = gui.PlaygroundAdminPanel.AdminHub.Pages.Rounds
assert(not rounds:FindFirstChild("SkippingRope"), "Admin row already exists")
local oldRounds = rounds:Clone()
oldRounds.Name = "BeforeAdminRounds"
oldRounds.Parent = backup
local row = rounds.DuckDuckGoose:Clone()
row.Name, row.LayoutOrder = "SkippingRope", 6
row.Title.Text = "SKIPPING ROPE"
row.Status.Text = "Ready • 2–24 players"
row.DGStart.Name = "SKStart"
row.SKStart.LiveCaption.Text = "START SKIPPING ROUND"
row.Parent = rounds
rounds.RoundSettings.LayoutOrder = 7
for _, panelName in ipairs({"VotePanel", "CompactVotePanel"}) do
 local panel = gui.PlaygroundShell[panelName]
 assert(not panel.Choices:FindFirstChild("SkippingRope"), "Vote card already exists")
 local old = panel:Clone()
 old.Name = "Before" .. panelName
 old.Parent = backup
 local template = panel.Choices.DuckDuckGoose
 local card = template:Clone()
 card.Name, card.LayoutOrder = "SkippingRope", 6
 card.Position = template.Position + UDim2.fromOffset(template.Size.X.Offset + 8, 0)
 card.Button.LiveCaption.Text = "SKIPPING\nROPE"
 card.Button.BackgroundColor3 = Color3.fromRGB(88, 196, 171)
 card.Button:SetAttribute("UISkinAssetKey", "PNG/07-Resizable-Skins/green-normal.png")
 local skin = card.Button:FindFirstChild("ReusableSkin")
 if skin then
  skin.Image = "https://www.roblox.com/asset/?id=78972575698291&version=1"
  skin:SetAttribute("DefaultImage", skin.Image)
  skin:SetAttribute("AssetKey", "PNG/07-Resizable-Skins/green-normal.png")
 end
 card.Parent = panel.Choices
 panel.Choices.CanvasSize = UDim2.fromOffset(card.Position.X.Offset + card.Size.X.Offset, 82)
 panel.ScrollHint.Text = "SWIPE OR SCROLL FOR ALL 6 GAMES"
end
local lobby = workspace["Playground Lobby"]
local alcove, choices = lobby.VotingAlcove, lobby.Gameplay.VoteChoices
local oldChoices = choices:Clone()
oldChoices.Name, oldChoices.Parent = "BeforeVoteChoices", backup
local oldStands = Instance.new("Folder")
oldStands.Name, oldStands.Parent = "BeforeVotingStands", backup
for _, object in ipairs(alcove:GetChildren()) do
 if object:IsA("Model") and string.sub(object.Name, -5) == "Stand" then object:Clone().Parent = oldStands end
end
assert(not alcove:FindFirstChild("SkippingRopeStand"), "Voting stand already exists")
local stand = alcove.DuckDuckGooseStand:Clone()
stand.Name = "SkippingRopeStand"
for _, object in ipairs(stand:GetDescendants()) do
 if object:IsA("TextLabel") then object.Text = "Skipping\nRope" end
 if object:GetAttribute("GameId") ~= nil then object:SetAttribute("GameId", "SkippingRope") end
end
stand.Parent = alcove
local trigger = choices.DuckDuckGoose:Clone()
trigger.Name = "SkippingRope"
trigger:SetAttribute("GameId", "SkippingRope")
trigger:SetAttribute("DisplayName", "Skipping Rope")
trigger:SetAttribute("Available", true)
trigger.Parent = choices
local ids = {"BritishBulldog", "TagYoureIt", "StuckInTheMud", "HideAndSeek", "DuckDuckGoose", "SkippingRope"}
for index, id in ipairs(ids) do
 local model = alcove[id .. "Stand"]
 local oldBox = model:GetBoundingBox()
 local column, rowIndex = (index - 1) % 3, math.floor((index - 1) / 3)
 local desired = Vector3.new(72 + column * 16, oldBox.Position.Y, -94 + rowIndex * 22)
 local delta = desired - oldBox.Position
 model:PivotTo(model:GetPivot() + delta)
 choices[id].CFrame += delta
end
return {adminRow = row:GetFullName(), votingCards = 2, worldStands = 6, authoredLayout = true}
