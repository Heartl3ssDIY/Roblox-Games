local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Data=require(script.Parent:WaitForChild("PlayerData"))
local Catalog=require(ReplicatedStorage:WaitForChild("GBloxPetCatalog"))

local remote=ReplicatedStorage:FindFirstChild("GBloxPetEquip") or Instance.new("RemoteFunction")
remote.Name="GBloxPetEquip"
remote.Parent=ReplicatedStorage

remote.OnServerInvoke=function(player,action,petId)
 if typeof(action)~="string" then return false,"Invalid pet action." end
 local profile=Data.Get(player)
 if not profile then return false,"Your inventory is still loading." end
 if action=="Unequip" then
  if Data.SetEquippedPet(player,"") then return true,"Pet unequipped." end
  return false,"Could not unequip that pet."
 end
 if action~="Equip" or typeof(petId)~="string" then return false,"Invalid pet action." end
 local pet=Catalog.GetPet(petId)
 if not pet or not profile.Pets or (profile.Pets[petId] or 0)<1 then
  return false,"You do not own that pet."
 end
 if Data.SetEquippedPet(player,petId) then return true,petId.." equipped." end
 return false,"Could not equip that pet."
end

