-- Cosmetic only: shared renderer handles cleanup and runs locally.
local Players=game:GetService("Players")
local Effects=require(game:GetService("ReplicatedStorage"):WaitForChild("GBloxTitleEffects"))
local bindings={}
local function bind(player)
 local connections={}
 local characterConnection
 local target
 local function refresh()
  local character=player.Character
  local gui=character and character:FindFirstChild("GBloxOverheadTitle")
  local label=gui and gui:FindFirstChild("Title")
  if target and target~=label then Effects.Detach(target) end
  target=label
  if label then Effects.Attach(label,player:GetAttribute("GBloxEquippedTitle")) end
 end
 local function characterAdded(character)
  if characterConnection then characterConnection:Disconnect() end
  if target then Effects.Detach(target) target=nil end
  characterConnection=character.DescendantAdded:Connect(function(item)
   if item.Name=="Title" or item.Name=="GBloxOverheadTitle" then refresh() end
  end)
  refresh()
 end
 table.insert(connections,player.CharacterAdded:Connect(characterAdded))
 table.insert(connections,player.CharacterRemoving:Connect(function()
  if characterConnection then characterConnection:Disconnect() characterConnection=nil end
  if target then Effects.Detach(target) target=nil end
 end))
 table.insert(connections,player:GetAttributeChangedSignal("GBloxEquippedTitle"):Connect(refresh))
 if player.Character then characterAdded(player.Character) end
 bindings[player]=function()
  for _,connection in connections do connection:Disconnect() end
  if characterConnection then characterConnection:Disconnect() end
  if target then Effects.Detach(target) end
 end
end
Players.PlayerAdded:Connect(bind)
Players.PlayerRemoving:Connect(function(player)
 if bindings[player] then bindings[player]() bindings[player]=nil end
end)
for _,player in Players:GetPlayers() do bind(player) end

