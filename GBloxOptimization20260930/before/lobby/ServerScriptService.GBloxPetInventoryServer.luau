local Data=require(script.Parent:WaitForChild("PlayerData"))
local RS=game:GetService("ReplicatedStorage")
local remote=RS:FindFirstChild("GBloxPetEquip") or Instance.new("RemoteFunction")
remote.Name="GBloxPetEquip" remote.Parent=RS
local last={}
remote.OnServerInvoke=function(player,action,id)
 if os.clock()-(last[player] or -10)<.2 then return false,"Please wait a moment." end
 last[player]=os.clock()
 if type(id)~="string" or #id>64 then return false,"Select a pet." end
 if action=="Unequip" then return Data.UnequipPet(player,id) end
 if action=="Equip" then return Data.SetEquippedPet(player,id) end
 return false,"Invalid pet action."
end
game.Players.PlayerRemoving:Connect(function(player) last[player]=nil end)

