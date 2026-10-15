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
 {"Pumpkin","Pumpkin","Throw a pumpkin at a racer ahead of you. Its orange splat lasts 4 seconds. Cooldown: 25 seconds."},
 {"Web","Web","Place a web that traps other racers for 5 seconds. It can catch multiple opponents and never traps you. Cooldown: 30 seconds."},
}
local abilitySlots={}
for _,slot in inventory.Items:GetChildren() do
 if slot:IsA("GuiButton") and slot.Name:match("^Slot%d+$") then table.insert(abilitySlots,slot) end
end
table.sort(abilitySlots,function(a,b) return tonumber(a.Name:match("%d+"))<tonumber(b.Name:match("%d+")) end)
local previewTemplates=g:WaitForChild("AbilityPreviewTemplates")
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
local Titles=require(ReplicatedStorage:WaitForChild("GBloxTitleRules"))
local TitleEffects=require(ReplicatedStorage:WaitForChild("GBloxTitleEffects"))
local titleRemote=ReplicatedStorage:WaitForChild("GBloxTitleEquip")
local titleCards={}
local selectedTitle
local titleBusy=false
local tab="Abilities"
local function formatWins(n)
 return tostring(math.floor(n)):reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^,","")
end
local function titleState()
 return {HighestWins=p:GetAttribute("GBloxTitleHighestWins") or 0,BetaTester=p:GetAttribute("GBloxBetaTester")==true}
end
local function titleDetails(def)
 selectedTitle=def
 local unlocked=def and Titles.Unlocked(titleState(),def.Id)
 local equipped=def and p:GetAttribute("GBloxEquippedTitle")==def.Id
 inventory.Details.Title.Text=def and def.Name or "TITLES"
 inventory.Details.Title.TextColor3=def and def.Color or Color3.new(1,1,1)
 TitleEffects.Attach(inventory.Details.Title,unlocked and def.Id or "")
 inventory.Details.Description.Text=def and (def.Beta
  and "Exclusive to players who joined by 21 September 2026 (UK time). Once earned, yours forever."
  or ("Win "..formatWins(def.Wins).." full five-round games to unlock this title. Earlier titles stay available to equip.")) or "Choose a title."
 inventory.Details.Uses.Text=not def and "" or unlocked and (equipped and "EQUIPPED" or "UNLOCKED")
  or def.Beta and "BETA EXCLUSIVE" or (formatWins(math.min(titleState().HighestWins,def.Wins)).." / "..formatWins(def.Wins).." WINS")
 inventory.Details.Equip.Text=titleBusy and "PLEASE WAIT..." or not unlocked and "LOCKED" or equipped and "UNEQUIP" or "EQUIP"
 inventory.Details.Equip.Active=unlocked==true and not titleBusy
end
local function clearTitleCards()
 TitleEffects.Detach(inventory.Details.Title)
 for _,card in titleCards do card:Destroy() end table.clear(titleCards)
 restoreAbilitySlots()
 inventory.Details.Title.TextColor3=Color3.new(1,1,1)
end
local function refreshTitles()
 if tab~="Titles" then return end
 for _,slot in abilitySlots do slot.Visible=false end
 for _,card in titleCards do card:Destroy() end table.clear(titleCards)
 for index,def in Titles.List do
  local card=inventory.Items.Slot1:Clone()
  card.Name="TitleCard_"..def.Id card.LayoutOrder=index card.Visible=true
  card:SetAttribute("AbilityId",nil)
  local unlocked=Titles.Unlocked(titleState(),def.Id)
  local equipped=p:GetAttribute("GBloxEquippedTitle")==def.Id
  card.Title.Text=def.Name card.Title.TextColor3=unlocked and def.Color or Color3.fromRGB(160,180,191)
  card.Description.Text=equipped and "EQUIPPED" or unlocked and "UNLOCKED"
   or def.Beta and "BETA EXCLUSIVE" or (formatWins(def.Wins).." WINS")
  card.ImageColor3=unlocked and Color3.new(1,1,1) or Color3.fromRGB(115,133,145)
  card.Title.TextWrapped=true card.Description.TextWrapped=true
  card.Parent=inventory.Items
  TitleEffects.Attach(card.Title,unlocked and def.Id or "")
  card.Activated:Connect(function() titleDetails(def) end)
  table.insert(titleCards,card)
 end
 titleDetails(selectedTitle or Titles.ById[p:GetAttribute("GBloxEquippedTitle")] or Titles.List[1])
end
inventory.Items.AutomaticCanvasSize=Enum.AutomaticSize.Y
for _,attr in {"GBloxTitleHighestWins","GBloxBetaTester","GBloxEquippedTitle"} do
 p:GetAttributeChangedSignal(attr):Connect(refreshTitles)
end
local EmoteCatalog=require(ReplicatedStorage:WaitForChild("GBloxEmoteCatalog"))
local emoteRemote=ReplicatedStorage:WaitForChild("GBloxEmoteRequest")
local emoteCards={} local selectedEmote local emoteBusy=false
local function emoteDetails(e)
 selectedEmote=e
 inventory.Details.Title.Text=e and e.Name or "VICTORY EMOTES"
 inventory.Details.Title.TextColor3=Color3.new(1,1,1)
 inventory.Details.Description.Text=e and "Equip this emote to use it on the podium and rankings. This unlock belongs to G-Blox only."
  or "No emotes owned yet. Find 30 emotes in Shop > Emotes, each costing 30 trophies."
 inventory.Details.Uses.Text=(p:GetAttribute("GBloxEmoteSlotsUsed") or 0).." / 8 EQUIPPED"
 local equipped=e and p:GetAttribute("GBloxEmoteEquipped_"..e.Id)
 inventory.Details.Equip.Text=emoteBusy and "PLEASE WAIT..." or not e and "VISIT SHOP" or equipped and "UNEQUIP" or "EQUIP"
 inventory.Details.Equip.Active=e~=nil and not emoteBusy
end
local function clearEmoteCards()
 for _,c in emoteCards do c:Destroy() end table.clear(emoteCards)
 restoreAbilitySlots()
end
local function refreshEmotes()
 if tab~="VictoryEmotes" then return end
 clearEmoteCards()
 for _,slot in abilitySlots do slot.Visible=false end
 local first
 for index,e in EmoteCatalog.List do
  if p:GetAttribute("GBloxEmoteOwned_"..e.Id) then
   first=first or e
   local c=inventory.Items.Slot1:Clone() c.Name="Emote_"..e.Id c.Visible=true c.LayoutOrder=index
   c:SetAttribute("AbilityId",nil)
   c.Title.Text=e.Name c.Title.TextWrapped=true c.Title.TextColor3=Color3.new(1,1,1)
   c.Description.Text=p:GetAttribute("GBloxEmoteEquipped_"..e.Id) and "EQUIPPED" or "OWNED"
   c.Parent=inventory.Items c.Activated:Connect(function() emoteDetails(e) end)
   table.insert(emoteCards,c)
  end
 end
 if selectedEmote and not p:GetAttribute("GBloxEmoteOwned_"..selectedEmote.Id) then selectedEmote=nil end
 emoteDetails(selectedEmote or first)
end
p:GetAttributeChangedSignal("GBloxEmotesRevision"):Connect(refreshEmotes)

local selectedAbility
local abilityEquipRemote=ReplicatedStorage:WaitForChild("GBloxAbilityEquip")
local abilityEquipBusy=false
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
for _,button in inventory.Tabs:GetChildren() do
 if button:IsA("GuiButton") then
  button.Activated:Connect(function()
   tab=button.Name
   clearEmoteCards()
   if tab=="VictoryEmotes" then clearTitleCards() refreshEmotes() return end
   if tab=="Titles" then refreshTitles() return end
   clearTitleCards()
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
for _,slot in abilitySlots do
 slot.Activated:Connect(function()
  local id=slot:GetAttribute("AbilityId")
  if id then
   for _,d in definitions do if d[1]==id then abilityDetails(d) break end end
  elseif tab~="Abilities" then inventory.Details.Description.Text="Coming soon" end
 end)
end
inventory.Details.Equip.Activated:Connect(function()
 if tab=="VictoryEmotes" then
  if not selectedEmote or emoteBusy then return end
  local e=selectedEmote
  emoteBusy=true emoteDetails(e)
  local action=p:GetAttribute("GBloxEmoteEquipped_"..e.Id) and "Unequip" or "Equip"
  local ok,success,message=pcall(function() return emoteRemote:InvokeServer(action,e.Id) end)
  emoteBusy=false
  if tab=="VictoryEmotes" then refreshEmotes() inventory.Details.Description.Text=ok and (message or "Please try again.") or "Connection error. Try again." end
  return
 end
 if tab=="Titles" then
  if titleBusy or not selectedTitle or not Titles.Unlocked(titleState(),selectedTitle.Id) then return end
  local def=selectedTitle
  titleBusy=true titleDetails(def)
  local requested=p:GetAttribute("GBloxEquippedTitle")==def.Id and "" or def.Id
  local ok,success,message=pcall(function() return titleRemote:InvokeServer(requested) end)
  titleBusy=false
  if tab=="Titles" then
   refreshTitles()
   inventory.Details.Description.Text=ok and (message or "Please try again.") or "Connection error. Try again."
  end
  return
 end
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
 p:GetAttributeChangedSignal("AbilityUnlimited_"..d[1]):Connect(refreshAbilities)
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



