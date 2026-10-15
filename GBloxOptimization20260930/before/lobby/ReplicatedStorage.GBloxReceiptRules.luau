local Catalog=require(game.ReplicatedStorage:WaitForChild("GBloxPurchaseCatalog"))
local Pets=require(game.ReplicatedStorage:WaitForChild("GBloxPetCatalog"))
local M={}
function M.Apply(profile,receipt,roll)
 local item=Catalog.Products[receipt.ProductId]
 local id=receipt.PurchaseId
 if not item or type(id)~="string" or #id==0 or #id>128 then return false end
 profile.ProductReceipts=profile.ProductReceipts or {}
 if profile.ProductReceipts[id] then return true,false,profile.ProductReceipts[id] end
 local pet
 if item.Kind=="Egg" then
  local egg=Pets.Eggs[item.Egg]
  if not egg or type(roll)~="number" or roll<0 or roll>=100 then return false end
  local total=0
  for _,candidate in egg.Pets do total+=candidate.Chance if roll<total then pet=candidate break end end
  if not pet then return false end
 end
 -- No yields between the reward and its receipt marker. Save both together.
 if item.Kind=="Cash" then
  profile.Cash+=item.Amount profile.TotalCashEarned+=item.Amount
 elseif item.Kind=="Trophies" then profile.Trophies+=item.Amount
 elseif item.Kind=="Ability" then
  local a=profile.Abilities[item.Ability] or {Owned=true,Uses=0}
  a.Owned=true a.Uses=math.max(0,tonumber(a.Uses) or 0)+item.Amount
  profile.Abilities[item.Ability]=a
 elseif pet then
  profile.Pets[pet.Id]=(profile.Pets[pet.Id] or 0)+1
 else return false end
 local marker={ProductId=receipt.ProductId,At=os.time(),Pet=pet and pet.Id}
 profile.ProductReceipts[id]=marker
 return true,true,marker
end
return M

