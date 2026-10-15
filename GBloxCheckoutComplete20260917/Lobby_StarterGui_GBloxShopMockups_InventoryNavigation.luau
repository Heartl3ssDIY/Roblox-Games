local g=script.Parent
local p=game.Players.LocalPlayer
local inventory=g.Canvas.Inventory
local pets=g.Canvas.Pets
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Catalog=require(ReplicatedStorage:WaitForChild("GBloxPetCatalog"))
local petRemote=ReplicatedStorage:WaitForChild("GBloxPetEquip")

local definitions={
 {"GravitySwitch","Gravity Switch","Instantly reverse every other active player's gravity. Normal flip controls still work. Cooldown: 20 seconds."},
 {"PlatBeGone","Plat Be Gone","Instantly remove one platform in the zone behind you for 3 seconds. 30-second cooldown."},
 {"Kong","Kong","Unavailable for now."},
 {"Freeze","Freeze","Instantly hold other active players in place for 5 seconds. Cooldown: 30 seconds."},
 {"Antispike","Antispike","Instantly disable red spikes for you only for 7 seconds. Cooldown: 45 seconds."},
 {"Superspeed","Superspeed","Instantly run at twice the speed pickup's boosted speed for 3 seconds (4x normal). Once per round; available again next round. No cooldown."},
}
local tab="Abilities"
local selectedAbility
local abilityEquipRemote=ReplicatedStorage:WaitForChild("GBloxAbilityEquip")
local abilityEquipBusy=false
local function abilityDetails(def)
 selectedAbility=def
 inventory.Details.Title.Text=def and def[2] or "ABILITIES"
 inventory.Details.Description.Text=def and def[3] or "No abilities owned yet.\n\nUnlock them in the abilities shop."
 inventory.Details.Uses.Text=def and (tostring(p:GetAttribute("AbilityUses_"..def[1]) or 0).." games left"..(p:GetAttribute("GBloxEquippedAbility")==def[1] and " - EQUIPPED" or "")) or ""
 inventory.Details.Equip.Text=def and def[1]=="Kong" and "UNAVAILABLE" or abilityEquipBusy and "PLEASE WAIT..." or (def and p:GetAttribute("GBloxEquippedAbility")==def[1]) and "UNEQUIP" or "EQUIP"
 inventory.Details.Equip.Active=def~=nil and def[1]~="Kong" and not abilityEquipBusy
end
local function refreshAbilities()
 local owned={}
 for _,d in definitions do if p:GetAttribute("AbilityOwned_"..d[1]) then table.insert(owned,d) end end
 for i=1,6 do
  local slot=inventory.Items["Slot"..i]
  local def=tab=="Abilities" and owned[i] or nil
  slot:SetAttribute("AbilityId",def and def[1] or nil)
  slot.Title.Text=def and def[2] or ""
  slot.Description.Text=def and def[3] or ""
 end
 if tab=="Abilities" then
  if selectedAbility and not p:GetAttribute("AbilityOwned_"..selectedAbility[1]) then selectedAbility=nil end
  abilityDetails(selectedAbility or owned[1])
 end
end
for _,button in inventory.Tabs:GetChildren() do
 if button:IsA("GuiButton") then
  button.Activated:Connect(function()
   tab=button.Name
   if tab=="Abilities" then refreshAbilities() else
    refreshAbilities()
    inventory.Details.Title.Text=tab=="VictoryEmotes" and "VICTORY EMOTES" or string.upper(tab)
    inventory.Details.Description.Text="Coming soon"
    inventory.Details.Uses.Text=""
    inventory.Details.Equip.Text="COMING SOON"
   end
  end)
 end
end
for i=1,6 do
 inventory.Items["Slot"..i].Activated:Connect(function()
  local id=inventory.Items["Slot"..i]:GetAttribute("AbilityId")
  if id then
   for _,d in definitions do if d[1]==id then abilityDetails(d) break end end
  elseif tab~="Abilities" then inventory.Details.Description.Text="Coming soon" end
 end)
end
inventory.Details.Equip.Activated:Connect(function()
 if tab~="Abilities" or not selectedAbility or selectedAbility[1]=="Kong" or abilityEquipBusy then return end
 abilityEquipBusy=true abilityDetails(selectedAbility)
 local ok,success,message=pcall(function() return abilityEquipRemote:InvokeServer(p:GetAttribute("GBloxEquippedAbility")==selectedAbility[1] and "" or selectedAbility[1]) end)
 abilityEquipBusy=false abilityDetails(selectedAbility)
 inventory.Details.Description.Text=ok and message or "Connection error. Try again."
end)
p:GetAttributeChangedSignal("GBloxEquippedAbility"):Connect(refreshAbilities)
for _,d in definitions do
 p:GetAttributeChangedSignal("AbilityOwned_"..d[1]):Connect(refreshAbilities)
 p:GetAttributeChangedSignal("AbilityUses_"..d[1]):Connect(refreshAbilities)
end
refreshAbilities()

local petOrder={
 "Horse","Bloodhound","Hare","Lion","Cheetah",
 "Ostrich","Hummingbird","Bat","Eagle","Falcon",
 "Orca","Swordfish","Shark","Alien",
}
local petImages=Catalog.PetImages
local orderIndex={}
for index,id in petOrder do orderIndex[id]=index end
local selectedPet
local cards={}
local busy=false
local folderConnections={}

local function clearFolderConnections()
 for _,connection in folderConnections do connection:Disconnect() end
 table.clear(folderConnections)
end

local function ownedCount(id)
 local folder=p:FindFirstChild("GBloxPets")
 local value=folder and folder:FindFirstChild(id)
 return value and value:IsA("IntValue") and value.Value or 0
end

local function setButtonState(button,enabled)
 button.Active=enabled and not busy
 button.AutoButtonColor=enabled and not busy
 button.ImageColor3=enabled and not busy and Color3.new(1,1,1) or Color3.fromRGB(105,125,132)
end

local refreshPets
local function showPet(id)
 selectedPet=id
 local pet,eggName
 if id then pet,eggName=Catalog.GetPet(id) end
 if not pet then
  pets.Details.Title.Text="SELECT A PET"
  pets.Details.Picture.Image=""
  pets.Details.Description.Text="Choose a pet from your inventory."
  pets.Details.Quantity.Text=""
 else
  pets.Details.Title.Text=string.upper(id)
  pets.Details.Picture.Image=petImages[id] or ""
  pets.Details.Description.Text=string.format("×%g CASH     ×%g TROPHIES",pet.CashMultiplier,pet.TrophyMultiplier)
  pets.Details.Quantity.Text=string.format("OWNED: ×%d     %s EGG • %g%%",ownedCount(id),string.upper(eggName),pet.Chance)
 end
 local equipped=p:GetAttribute("GBloxEquippedPet")
 local second=p:GetAttribute("GBloxEquippedPet2")
 local used=(equipped and 1 or 0)+(second and 1 or 0)
 local copies=(equipped==id and 1 or 0)+(second==id and 1 or 0)
 local slots=p:GetAttribute("GBloxPetSlots") or 1
 setButtonState(pets.Details.Equip,id~=nil and (slots==1 and equipped~=id or used<slots and ownedCount(id)>copies))
 setButtonState(pets.Details.Unequip,id~=nil and copies>0)
 for petId,card in cards do
  local selected=petId==id
  local isEquipped=petId==equipped or petId==second
  card.ImageColor3=selected and Color3.fromRGB(190,255,255) or Color3.new(1,1,1)
  card.Equipped.Visible=isEquipped
  card.Selection.Visible=selected
 end
end

local function makeCard(id,count)
 local card=Instance.new("ImageButton")
 card.Name=id card.LayoutOrder=orderIndex[id] or 999
 card.BackgroundTransparency=1 card.Image="rbxassetid://116603689368321"
 card.ScaleType=Enum.ScaleType.Stretch card.AutoButtonColor=true card.Parent=pets.Items
 local picture=Instance.new("ImageLabel")
 picture.Name="Picture" picture.Position=UDim2.fromScale(.08,.05) picture.Size=UDim2.fromScale(.84,.68)
 picture.BackgroundTransparency=1 picture.Image=petImages[id] or "" picture.ScaleType=Enum.ScaleType.Fit picture.Parent=card
 local title=Instance.new("TextLabel")
 title.Name="Title" title.Position=UDim2.fromScale(.04,.72) title.Size=UDim2.fromScale(.92,.17)
 title.BackgroundTransparency=1 title.Text=string.upper(id) title.TextColor3=Color3.new(1,1,1)
 title.TextStrokeColor3=Color3.fromRGB(0,15,24) title.TextStrokeTransparency=0
 title.TextScaled=true title.Font=Enum.Font.Arcade title.Parent=card
 local titleLimit=Instance.new("UITextSizeConstraint") titleLimit.MinTextSize=8 titleLimit.MaxTextSize=19 titleLimit.Parent=title
 local quantity=Instance.new("TextLabel")
 quantity.Name="Quantity" quantity.AnchorPoint=Vector2.new(1,0) quantity.Position=UDim2.fromScale(.94,.04)
 quantity.Size=UDim2.fromScale(.38,.16) quantity.BackgroundColor3=Color3.fromRGB(5,28,42)
 quantity.BackgroundTransparency=.12 quantity.Text="×"..count quantity.TextColor3=Color3.new(1,1,1)
 quantity.TextStrokeTransparency=.4 quantity.TextScaled=true quantity.Font=Enum.Font.Arcade quantity.ZIndex=3 quantity.Parent=card
 local qc=Instance.new("UICorner") qc.CornerRadius=UDim.new(.3,0) qc.Parent=quantity
 local equipped=Instance.new("TextLabel")
 equipped.Name="Equipped" equipped.Position=UDim2.fromScale(.12,.89) equipped.Size=UDim2.fromScale(.76,.09)
 equipped.BackgroundTransparency=1 equipped.Text="EQUIPPED" equipped.TextColor3=Color3.fromRGB(67,255,157)
 equipped.TextStrokeTransparency=0 equipped.TextScaled=true equipped.Font=Enum.Font.Arcade equipped.Visible=false equipped.Parent=card
 local selection=Instance.new("Frame")
 selection.Name="Selection" selection.Size=UDim2.fromScale(1,1) selection.BackgroundTransparency=1 selection.Visible=false selection.ZIndex=4 selection.Parent=card
 local stroke=Instance.new("UIStroke") stroke.Color=Color3.fromRGB(255,238,78) stroke.Thickness=4 stroke.Parent=selection
 local sc=Instance.new("UICorner") sc.CornerRadius=UDim.new(.1,0) sc.Parent=selection
 card.Activated:Connect(function() showPet(id) end)
 cards[id]=card
end

refreshPets=function()
 for _,card in pets.Items:GetChildren() do if card:IsA("GuiButton") then card:Destroy() end end
 table.clear(cards)
 local total,first=0,nil
 for _,id in petOrder do
  local count=ownedCount(id)
  if count>0 then
   total+=count
   first=first or id
   makeCard(id,count)
  end
 end
 pets.Empty.Visible=total==0
 local equipped=p:GetAttribute("GBloxEquippedPet")
 local used=(equipped and 1 or 0)+(p:GetAttribute("GBloxEquippedPet2") and 1 or 0)
 pets.EquippedCount.Text=used.." / "..(p:GetAttribute("GBloxPetSlots") or 1).." EQUIPPED"
 pets.OwnedCount.Text=total.." PET"..(total==1 and "" or "S")
 if not selectedPet or ownedCount(selectedPet)<1 then selectedPet=first end
 showPet(selectedPet)
end

local function bindPetFolder(folder)
 clearFolderConnections()
 if not folder then refreshPets() return end
 table.insert(folderConnections,folder.ChildAdded:Connect(function(child)
  if child:IsA("IntValue") then
   table.insert(folderConnections,child:GetPropertyChangedSignal("Value"):Connect(refreshPets))
   refreshPets()
  end
 end))
 table.insert(folderConnections,folder.ChildRemoved:Connect(refreshPets))
 for _,child in folder:GetChildren() do
  if child:IsA("IntValue") then table.insert(folderConnections,child:GetPropertyChangedSignal("Value"):Connect(refreshPets)) end
 end
 refreshPets()
end

pets.Details.Equip.Activated:Connect(function()
 if busy or not selectedPet then return end
 busy=true showPet(selectedPet)
 local ok,success,message=pcall(function() return petRemote:InvokeServer("Equip",selectedPet) end)
 pets.Details.Status.Text=ok and message or "Connection error. Try again."
 busy=false refreshPets()
end)
pets.Details.Unequip.Activated:Connect(function()
 if busy or not selectedPet then return end
 busy=true showPet(selectedPet)
 local ok,success,message=pcall(function() return petRemote:InvokeServer("Unequip",selectedPet) end)
 pets.Details.Status.Text=ok and message or "Connection error. Try again."
 busy=false refreshPets()
end)
p:GetAttributeChangedSignal("GBloxEquippedPet"):Connect(refreshPets)
p:GetAttributeChangedSignal("GBloxEquippedPet2"):Connect(refreshPets)
p:GetAttributeChangedSignal("GBloxPetSlots"):Connect(refreshPets)
p.ChildAdded:Connect(function(child) if child.Name=="GBloxPets" then bindPetFolder(child) end end)
bindPetFolder(p:FindFirstChild("GBloxPets"))

