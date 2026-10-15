local Catalog=require(game.ReplicatedStorage:WaitForChild("GBloxPetCatalog"))
local M={}
function M.Slots(p)
 return p.CashPasses and p.CashPasses["1982264711"]==true and 2 or 1
end
function M.Selected(p)
 local raw=type(p.EquippedPets)=="table" and table.clone(p.EquippedPets) or {}
 if type(p.EquippedPet)=="string" and p.EquippedPet~="" then raw[1]=p.EquippedPet end
 local selected,counts={},{}
 for _,id in ipairs(raw) do
  if type(id)=="string" and Catalog.GetPet(id) and (p.Pets[id] or 0)>(counts[id] or 0) then
   table.insert(selected,id) counts[id]=(counts[id] or 0)+1
   if #selected>=M.Slots(p) then break end
  end
 end
 return selected
end
function M.Write(p,selected)
 p.EquippedPets=selected p.EquippedPet=selected[1] or ""
end
function M.Equip(p,id)
 if type(id)~="string" or not Catalog.GetPet(id) or (p.Pets[id] or 0)<1 then return false,"You do not own that pet." end
 local selected=M.Selected(p)
 if M.Slots(p)==1 then M.Write(p,{id}) return true,id.." equipped." end
 if #selected>=M.Slots(p) then return false,"Both slots are full. Unequip a pet first." end
 local count=0 for _,v in selected do if v==id then count+=1 end end
 if count>=(p.Pets[id] or 0) then return false,"That pet is already equipped." end
 table.insert(selected,id) M.Write(p,selected) return true,id.." equipped."
end
function M.Unequip(p,id)
 local selected=M.Selected(p)
 if not id or id=="" then table.clear(selected)
 else for i=#selected,1,-1 do if selected[i]==id then table.remove(selected,i) break end end end
 M.Write(p,selected) return true,"Pet unequipped."
end
function M.Multipliers(p)
 local cash,trophies=1,1
 for _,id in M.Selected(p) do local pet=Catalog.GetPet(id) cash+=pet.CashMultiplier-1 trophies+=pet.TrophyMultiplier-1 end
 return cash,trophies
end
return M

