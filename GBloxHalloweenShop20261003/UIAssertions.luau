local assertions=0
local function check(ok,message) assertions+=1 assert(ok,message) end
local attrs={}
local p={GetAttribute=function(_,name) return attrs[name] end}
local Color3={new=function(...) return {...} end,fromRGB=function(...) return {...} end}
local UDim2={new=function(...) return {...} end,fromOffset=function(...) return {...} end}
local function node(name)
 local object={Name=name,children={}}
 function object:FindFirstChild(child) return self.children[child] or self[child] end
 function object:IsA(class) return self.ClassName==class end
 function object:GetAttribute(key) return self.attrs and self.attrs[key] end
 function object:SetAttribute(key,value) self.attrs=self.attrs or {} self.attrs[key]=value end
 function object:Destroy() if self.Parent then self.Parent.children[self.Name]=nil end end
 function object:Clone()
  local clone=node(self.Name) clone.attrs=table.clone(self.attrs or {}) clone.ClassName=self.ClassName
  for _,child in self.children do local copy=child:Clone() copy.Parent=clone end
  return clone
 end
 return setmetatable(object,{__newindex=function(self,key,value)
  rawset(self,key,value)
  if key=="Parent" and value then value.children[self.Name]=self end
 end})
end
local abilitySlots={}
for i=1,8 do
 local slot=node("Slot"..i)
 slot.Title={} slot.Description={Visible=true} slot.AbilityStatus={Visible=false}
 table.insert(abilitySlots,slot)
end
local previewTemplates=node("Templates")
for _,id in {"Pumpkin","Web"} do
 local preview=node(id) preview.ClassName="ViewportFrame" preview:SetAttribute("AbilityId",id) previewTemplates.children[id]=preview
 local camera=node("PreviewCamera") camera.Parent=preview preview.CurrentCamera=camera
end
check(previewTemplates.children.Pumpkin:Clone().CurrentCamera==nil,"clone mock reproduces nonpersistent CurrentCamera")
local card=node("ShopCard")
local shopPreview=previewTemplates.children.Pumpkin:Clone() shopPreview.Name="AbilityPreview" shopPreview.Parent=card
local preview=card:FindFirstChild("AbilityPreview")
if preview and preview:IsA("ViewportFrame") then preview.CurrentCamera=preview:FindFirstChild("PreviewCamera") end
check(shopPreview.CurrentCamera==shopPreview:FindFirstChild("PreviewCamera"),"client startup rebinds the PlayerGui shop viewport camera")
local definitions={}
for _,id in {"GravitySwitch","PlatBeGone","Kong","Freeze","Antispike","Superspeed","Pumpkin","Web"} do
 table.insert(definitions,{id,id,id.." description"})
end
local inventory={Details={Title={},Description={},Uses={},Equip={}}}
local selectedAbility local abilityEquipBusy=false local tab="Abilities"
local function clearAbilityPreview(slot)
 local preview=slot:FindFirstChild("AbilityPreview")
 if preview then preview:Destroy() end
 slot.Description.Visible=true
 local status=slot:FindFirstChild("AbilityStatus")
 if status then status.Visible=false end
end
local function setAbilityPreview(slot,id)
 local preview=slot:FindFirstChild("AbilityPreview")
 if preview and preview:GetAttribute("AbilityId")==id then return end
 clearAbilityPreview(slot)
 local template=id and previewTemplates:FindFirstChild(id)
 if template then
  preview=template:Clone()
  preview.Name="AbilityPreview"
  preview.CurrentCamera=preview:FindFirstChild("PreviewCamera")
  preview.Visible=true
  preview.Parent=slot
 end
end
local function restoreAbilitySlots()
 for _,slot in abilitySlots do slot.Visible=true clearAbilityPreview(slot) end
end

local function abilityDetails(def)
 selectedAbility=def
 inventory.Details.Title.TextColor3=Color3.new(1,1,1)
 inventory.Details.Title.Text=def and def[2] or "ABILITIES"
 inventory.Details.Description.Text=def and def[3] or "No abilities owned yet.\n\nUnlock them in the abilities shop."
 local unlimited=def and p:GetAttribute("AbilityUnlimited_"..def[1])==true
 inventory.Details.Uses.Text=def and ((unlimited and "UNLIMITED • HALLOWEEN" or (tostring(p:GetAttribute("AbilityUses_"..def[1]) or 0).." games left"))..(p:GetAttribute("GBloxEquippedAbility")==def[1] and " - EQUIPPED" or "")) or ""
 inventory.Details.Equip.Text=def and def[1]=="Kong" and "UNAVAILABLE" or abilityEquipBusy and "PLEASE WAIT..." or (def and p:GetAttribute("GBloxEquippedAbility")==def[1]) and "UNEQUIP" or "EQUIP"
 inventory.Details.Equip.Active=def~=nil and def[1]~="Kong" and not abilityEquipBusy
end
local function refreshAbilities()
 local owned={}
 for _,d in definitions do if p:GetAttribute("AbilityOwned_"..d[1]) then table.insert(owned,d) end end
 for i,slot in abilitySlots do
  local def=tab=="Abilities" and owned[i] or nil
  local id=def and def[1]
  slot:SetAttribute("AbilityId",id)
  slot.Title.Text=def and def[2] or ""
  slot.Description.Text=def and def[3] or ""
  setAbilityPreview(slot,id)
  if id=="Pumpkin" or id=="Web" then
   slot.Description.Visible=false
   slot.AbilityStatus.Visible=true
   slot.AbilityStatus.Text=p:GetAttribute("AbilityUnlimited_"..id)==true and "UNLIMITED • HALLOWEEN"
    or tostring(p:GetAttribute("AbilityUses_"..id) or 0).." games left"
  end
  if tab=="Abilities" then slot.Visible=def~=nil end
 end
 if tab=="Abilities" then
  if selectedAbility and not p:GetAttribute("AbilityOwned_"..selectedAbility[1]) then selectedAbility=nil end
  abilityDetails(selectedAbility or owned[1])
 end
end

refreshAbilities()
check(inventory.Details.Title.Text=="ABILITIES","empty details")
check(inventory.Details.Equip.Active==false,"empty equip is disabled")
for _,d in definitions do if d[1]~="Kong" then attrs["AbilityOwned_"..d[1]]=true attrs["AbilityUses_"..d[1]]=3 end end
attrs.AbilityUnlimited_Pumpkin=true attrs.AbilityUnlimited_Web=true
refreshAbilities()
check(abilitySlots[6]:GetAttribute("AbilityId")=="Pumpkin","pumpkin is retained beyond old five abilities")
check(abilitySlots[7]:GetAttribute("AbilityId")=="Web","web is retained beyond old six slots")
check(abilitySlots[8].Visible==false,"unused slot is hidden")
check(abilitySlots[6].AbilityStatus.Text=="UNLIMITED • HALLOWEEN","seasonal inventory status")
check(abilitySlots[6].Description.Visible==false,"description does not overlap new artwork")
check(abilitySlots[6]:FindFirstChild("AbilityPreview")~=nil,"pumpkin viewport created")
local first=abilitySlots[6]:FindFirstChild("AbilityPreview")
check(first.CurrentCamera==first:FindFirstChild("PreviewCamera"),"cloned inventory preview rebinds its camera")
check(first.CurrentCamera~=previewTemplates.children.Pumpkin.CurrentCamera,"inventory camera belongs to cloned viewport, not source template")
refreshAbilities()
check(abilitySlots[6]:FindFirstChild("AbilityPreview")==first,"unchanged avatar preview is cached")
abilityDetails(definitions[7])
check(inventory.Details.Uses.Text=="UNLIMITED • HALLOWEEN","details unlimited status")
attrs.GBloxEquippedAbility="Pumpkin"
abilityDetails(definitions[7])
check(inventory.Details.Equip.Text=="UNEQUIP","seasonal owned ability uses existing equip")
check(inventory.Details.Uses.Text:find("EQUIPPED",1,true)~=nil,"details show equipped")
attrs.AbilityUnlimited_Pumpkin=false attrs.AbilityUses_Pumpkin=0
refreshAbilities()
check(abilitySlots[6].AbilityStatus.Text=="0 games left","post-event recharge state")
attrs.AbilityOwned_Kong=true
refreshAbilities()
check(abilitySlots[8]:GetAttribute("AbilityId")=="Web","all eight owned slots fit")
abilityDetails(definitions[3])
check(inventory.Details.Equip.Active==false,"legacy Kong remains unavailable")
restoreAbilitySlots()
check(abilitySlots[7]:FindFirstChild("AbilityPreview")==nil,"other inventory tabs do not inherit seasonal preview")
check(abilitySlots[7].Description.Visible==true and abilitySlots[7].AbilityStatus.Visible==false,"other tabs restore original label")
local AbilityRules={GetPurchase=function(id)
 if id=="Pumpkin" then return {Price=150000,RechargePrice=15000} end
 if id=="Web" then return {Price=350000,RechargePrice=35000} end
 return {Price=300000,RechargePrice=30000}
end}
local function formatPrice(amount)
 return tostring(math.floor(amount)):reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^,","")
end
local function scenario(id,owned,uses,unlimited,busy,product)
 table.clear(attrs)
 attrs["AbilityOwned_"..id]=owned attrs["AbilityUses_"..id]=uses attrs["AbilityUnlimited_"..id]=unlimited attrs.PlayerDataReady=true
 local card=node("Card")
 card:SetAttribute("CashPrice",id=="Pumpkin" and 150000 or 350000)
 card:SetAttribute("PreservePurchaseLayout",true)
 card.RobuxRefill=node("RobuxRefill") card.RobuxRefill:SetAttribute("ProductId",product)
 card.AbilityState={}
 local sentinelPos={} local sentinelSize={}
 local b={Label={},Position=sentinelPos,Size=sentinelSize}
  local function refresh()
   if id=="Kong" then
    b.Label.Text="UNAVAILABLE" b.Active=false b.ImageColor3=Color3.fromRGB(155,155,155)
    card.RobuxRefill.Visible=false
    return
   end
   local owned=p:GetAttribute("AbilityOwned_"..id)==true
   local unlimited=owned and p:GetAttribute("AbilityUnlimited_"..id)==true
   local uses=p:GetAttribute("AbilityUses_"..id) or 0
   local purchase=AbilityRules.GetPurchase(id)
   local basePrice=purchase and purchase.Price or card:GetAttribute("CashPrice")
   local cost=owned and (purchase and purchase.RechargePrice or basePrice*.1) or basePrice
   b.Label.Text=busy and "PLEASE WAIT..." or unlimited and "UNLIMITED • HALLOWEEN"
    or owned and uses>0 and (uses.." games left") or (formatPrice(cost).." CASH")
   if card:GetAttribute("PreservePurchaseLayout")~=true then
    b.Position=UDim2.new(owned and .74 or .5,0,1,-16)
    b.Size=UDim2.fromOffset(owned and 190 or 214,owned and 43 or 49)
   end
   b.Active=not busy and p:GetAttribute("PlayerDataReady")==true and not unlimited and (not owned or uses==0)
   b.ImageColor3=b.Active and Color3.new(1,1,1) or Color3.fromRGB(155,155,155)
   card.RobuxRefill.Visible=owned and not unlimited and card.RobuxRefill:GetAttribute("ProductId")~=nil
   local state=card:FindFirstChild("AbilityState")
   if state then
    local equipped=owned and p:GetAttribute("GBloxEquippedAbility")==id
    state.Text=equipped and "EQUIPPED" or owned and "OWNED • EQUIP IN INVENTORY" or "HALLOWEEN ABILITY"
   end
  end

 refresh()
 check(b.Position==sentinelPos and b.Size==sentinelSize,"authored new purchase layout preserved")
 return b,card
end
local b,c=scenario("Pumpkin",false,0,true,false,nil)
check(b.Active==true and b.Label.Text=="150,000 CASH","unowned pumpkin costs cash even during event")
check(c.RobuxRefill.Visible==false,"no fake Robux refill for new pumpkin")
b,c=scenario("Pumpkin",true,0,true,false,nil)
check(b.Active==false and b.Label.Text=="UNLIMITED • HALLOWEEN","owned event ability cannot be charged for recharge")
b,c=scenario("Pumpkin",true,0,false,false,nil)
check(b.Active==true and b.Label.Text=="15,000 CASH","pumpkin post-event recharge price")
b,c=scenario("Web",false,0,false,false,nil)
check(b.Active==true and b.Label.Text=="350,000 CASH","web unlock price")
b,c=scenario("Web",true,0,false,false,nil)
check(b.Active==true and b.Label.Text=="35,000 CASH","web recharge price")
b,c=scenario("Web",true,1,false,false,nil)
check(b.Active==false and b.Label.Text=="1 games left","remaining game use prevents unnecessary recharge")
b,c=scenario("Pumpkin",false,0,false,true,nil)
check(b.Active==false and b.Label.Text=="PLEASE WAIT...","inflight cash purchase is protected")
print("Halloween shop UI assertions passed: "..assertions)

