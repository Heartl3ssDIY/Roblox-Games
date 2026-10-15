local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local gui=script.Parent
local shop=gui:WaitForChild("ShopPanel")
local vote=gui:WaitForChild("VotePanel")
local compactVote=gui:WaitForChild("CompactVotePanel")
local votePanels={vote,compactVote}
local wallet=gui:WaitForChild("Wallet")
local dock=gui:WaitForChild("Dock")
local toast=gui:WaitForChild("RewardToast")
local catalogObject=ReplicatedStorage:WaitForChild("PlaygroundCatalog",10)
if not catalogObject then warn("Playground catalog is unavailable") return end
local catalog=require(catalogObject)
local ink=Color3.fromRGB(27,45,61)
local white=Color3.fromRGB(255,255,248)
local gold=Color3.fromRGB(255,211,78)
local blue=Color3.fromRGB(89,193,244)
local pink=Color3.fromRGB(255,153,166)
local mint=Color3.fromRGB(130,225,180)
local muted=Color3.fromRGB(220,225,215)
local data={coins=player:GetAttribute("PCCoins") or 0,ready=player:GetAttribute("PCDataReady")==true,owned={},equipped={}}
local category="All"
local busy=false
local voteBusy=false
local toastToken=0
local cards={}
local blankCards={}
local previews={}
local lastReward=player:GetAttribute("PCRewardAt")
local wasInsideShop=false
local state=nil
local stateConnection=nil

local function showToast(message,duration)
 toastToken+=1
 local token=toastToken
 toast.Message.Text=tostring(message)
 toast.Visible=true
 task.delay(duration or 3.2,function()
  if token==toastToken and toast.Parent then toast.Visible=false end
 end)
end
local function refreshWallet()
 local coins=data.ready and tostring(data.coins or 0) or "..."
 wallet.Coins.Text=coins
 wallet.Wins.Text=tostring(player:GetAttribute("PCWins") or 0).." wins"
 shop.Coins.Text=coins.." coins"
end
local function blankCard(card)
 for _,name in ipairs({"Name","Price","Category","Action","Try"}) do
  local label=card:FindFirstChild(name)
  if label and (label:IsA("TextLabel") or label:IsA("TextButton") or label:IsA("TextBox")) then label.Text="" end
 end
 for _,name in ipairs({"Action","Try"}) do
  local button=card:FindFirstChild(name)
  if button and button:IsA("GuiButton") then
   button.Active=false
   button.Selectable=false
   button.AutoButtonColor=false
   button.Visible=false
  end
 end
 card.Visible=true
end
local function refreshCards()
 refreshWallet()
 for _,card in ipairs(blankCards) do blankCard(card) end
 for _,item in ipairs(catalog.Items) do
  local card=cards[item.id]
  if card then
   local owned=data.owned[item.id]==true
   local equipped=data.equipped[item.slot]==item.id
   card.Visible=category=="All" or item.category==category
   card.Action.Visible=true
   card.Price.Text=item.available==false and "Coming later" or owned and (equipped and "Equipped" or "Owned") or tostring(item.price).." coins"
   card.Action.Text=item.available==false and "COMING SOON" or not data.ready and "LOADING" or equipped and "UNEQUIP" or owned and "EQUIP" or "BUY"
   card.Action.BackgroundColor3=(item.available==false or not data.ready) and muted or equipped and mint or owned and blue or gold
   card.Action.Active=not busy and data.ready and item.available~=false
   card.Action.Selectable=card.Action.Active
   card.Try.Visible=owned and (item.category=="Emotes" or item.category=="Emojis")
   card.Try.Active=not busy and data.ready
   card.Try.Selectable=card.Try.Active
   card.Outline.Color=equipped and gold or ink
  end
 end
 for _,button in ipairs(shop.Categories:GetChildren()) do
  if button:IsA("TextButton") then button.BackgroundColor3=button.Name==category and gold or white end
 end
end
local function applyReply(reply)
 if typeof(reply)~="table" then return end
 if typeof(reply.coins)=="number" then data.coins=reply.coins end
 if typeof(reply.ready)=="boolean" then data.ready=reply.ready or player:GetAttribute("PCDataReady")==true end
 if typeof(reply.owned)=="table" then data.owned=reply.owned end
 if typeof(reply.equipped)=="table" then data.equipped=reply.equipped end
 refreshCards()
end
local function playEmote(name)
 if typeof(name)~="string" then return end
 local character=player.Character
 local humanoid=character and character:FindFirstChildOfClass("Humanoid")
 if not humanoid then return end
 local ok,played=pcall(function() return humanoid:PlayEmote(name) end)
 if not ok or not played then showToast("Your avatar could not play that emote.") end
end
local function request(action,id,quiet)
 if busy then return end
 local remote=ReplicatedStorage:FindFirstChild("PlaygroundShopRequest")
 if not remote or not remote:IsA("RemoteFunction") then
  if not quiet then
   shop.Status.Text="The shop is getting ready. Try again in a moment."
   if not shop.Visible then showToast("The shop is getting ready.") end
  end
  return
 end
 busy=true
 refreshCards()
 task.spawn(function()
  local ok,reply=pcall(function() return remote:InvokeServer(action,id) end)
  busy=false
  if ok and typeof(reply)=="table" then
   applyReply(reply)
   if not quiet or not reply.ok then shop.Status.Text=tostring(reply.message or (reply.ok and "All set!" or "Try again in a moment.")) end
   if not reply.ok and not shop.Visible and not quiet then showToast(reply.message or "Try again in a moment.") end
   if reply.ok and reply.emote then playEmote(reply.emote) end
  else
   refreshCards()
   if not quiet then
    shop.Status.Text="That did not go through. Try again in a moment."
    if not shop.Visible then showToast("Try again in a moment.") end
   end
  end
 end)
end
local function setShop(visible)
 shop.Visible=visible
 gui.Backdrop.Visible=visible
 if visible then
  shop.Status.Text=#catalog.Items==0 and "Items are being added." or data.ready and "Pick a little something for your next round." or "Your coins are loading..."
  request("GetStatus",nil,true)
 end
end
local function setCategory(value)
 category=value
 refreshCards()
end
for _,card in ipairs(shop.Cards:GetChildren()) do
 if card:IsA("Frame") then
  local id=card:GetAttribute("CatalogId")
  local item=typeof(id)=="string" and catalog.ById[id]
  if item then
   cards[id]=card
   local model=card.Preview.World:FindFirstChild("ItemModel")
   if model then table.insert(previews,{model=model,pivot=model:GetPivot()}) end
   card.Action.Activated:Connect(function()
    if busy or not data.ready or item.available==false then return end
    if data.equipped[item.slot]==id then request("Unequip",item.slot)
    elseif data.owned[id] then request("Equip",id)
    else request("Buy",id) end
   end)
   card.Try.Activated:Connect(function()
    if item.category=="Emotes" then request("UseEmote",id)
    elseif item.category=="Emojis" then request("UseEmoji",id) end
   end)
  else
   table.insert(blankCards,card)
   blankCard(card)
  end
 end
end
for _,button in ipairs(shop.Categories:GetChildren()) do
 if button:IsA("TextButton") then button.Activated:Connect(function() setCategory(button.Name) end) end
end
dock.Shop.Activated:Connect(function() setShop(not shop.Visible) end)
shop.Close.Activated:Connect(function() setShop(false) end)
gui.Backdrop.Activated:Connect(function() setShop(false) end)
dock.Emote.Activated:Connect(function()
 local id=data.equipped.Emote
 local item=id and catalog.ById[id]
 if item and item.slot=="Emote" and item.available~=false then request("UseEmote",id)
 else
  setCategory("Emotes")
  setShop(true)
  if #catalog.Items>0 then shop.Status.Text="Equip an emote, then use it here." end
 end
end)
dock.Emoji.Activated:Connect(function()
 local id=data.equipped.Emoji
 local item=id and catalog.ById[id]
 if item and item.slot=="Emoji" and item.available~=false then request("UseEmoji",id)
 else
  setCategory("Emojis")
  setShop(true)
  if #catalog.Items>0 then shop.Status.Text="Equip an emoji, then use it here." end
 end
end)
for _,attribute in ipairs({"PCCoins","PCWins","PCDataReady"}) do
 player:GetAttributeChangedSignal(attribute):Connect(function()
  local wasReady=data.ready
  data.coins=player:GetAttribute("PCCoins") or data.coins
  data.ready=player:GetAttribute("PCDataReady")==true
  refreshCards()
  if data.ready and not wasReady then request("GetStatus",nil,true) end
 end)
end
player:GetAttributeChangedSignal("PCRewardAt"):Connect(function()
 local now=player:GetAttribute("PCRewardAt")
 if now and now~=lastReward then
  lastReward=now
  local message=player:GetAttribute("PCRewardText")
  if typeof(message)=="string" and message~="" then showToast(message,4) end
 end
end)
local function insideZone(zone,root)
 if not zone or not zone:IsA("BasePart") or not root then return false end
 local point=zone.CFrame:PointToObjectSpace(root.Position)
 return math.abs(point.X)<=zone.Size.X/2 and math.abs(point.Y)<=zone.Size.Y/2 and math.abs(point.Z)<=zone.Size.Z/2
end
local function votesText(count)
 return tostring(count)..(count==1 and " vote" or " votes")
end
local function refreshVotes()
 local phase=state and state:GetAttribute("Phase") or "Waiting"
 local voting=phase=="Voting"
 local chosen=player:GetAttribute("PCVote")
 for _,vote in ipairs(votePanels) do
 vote.Title.Text=voting and "PICK THE NEXT ROUND" or "NEXT ROUND"
 local ending=state and state:GetAttribute("VotingEndsAt") or 0
 vote.Timer.Text=voting and tostring(math.max(0,math.ceil(ending-workspace:GetServerTimeNow()))).."s" or phase=="Playing" and "PLAYING" or phase=="Paused" and "PAUSED" or "WAITING"
 vote.VotesBritishBulldog.Text=votesText(state and state:GetAttribute("VotesBritishBulldog") or 0)
 vote.VotesTagYoureIt.Text=votesText(state and state:GetAttribute("VotesTagYoureIt") or 0)
 vote.VotesStuckInTheMud.Text=votesText(state and state:GetAttribute("VotesStuckInTheMud") or 0)
 vote.BritishBulldog.BackgroundColor3=chosen=="BritishBulldog" and gold or blue
 vote.TagYoureIt.BackgroundColor3=chosen=="TagYoureIt" and gold or pink
 vote.StuckInTheMud.BackgroundColor3=chosen=="StuckInTheMud" and gold or mint
 vote.BritishBulldog.Active=voting and not voteBusy
 vote.TagYoureIt.Active=voting and not voteBusy
 local mudAvailable=state and state:GetAttribute("AvailableStuckInTheMud")~=false
 vote.StuckInTheMud.Active=voting and not voteBusy and mudAvailable
 if not mudAvailable then
  vote.StuckInTheMud.BackgroundColor3=Color3.fromRGB(162,169,184)
  local minimum=state:GetAttribute("MinimumStuckInTheMud") or 4
  vote.VotesStuckInTheMud.Text=(state:GetAttribute("ReadyPlayerCount") or 0)<minimum and "Needs "..tostring(minimum).." players" or "Unavailable"
 end
 vote.StuckInTheMud.Selectable=vote.StuckInTheMud.Active
 vote.BritishBulldog.Selectable=vote.BritishBulldog.Active
 vote.TagYoureIt.Selectable=vote.TagYoureIt.Active
 if not voteBusy then
  vote.Message.Text=voting and (chosen and chosen~="" and "Your vote is saved. You can change it." or "Step onto a card to vote, or tap it here.") or phase=="Playing" and "Another round is underway." or phase=="Paused" and "The next round is paused." or "Voting opens when the next round is ready."
 end
 end
end
local function bindState(object)
 if not object or object==state then return end
 if stateConnection then stateConnection:Disconnect() end
 state=object
 stateConnection=state.AttributeChanged:Connect(refreshVotes)
 refreshVotes()
end
bindState(ReplicatedStorage:FindFirstChild("PlaygroundState"))
ReplicatedStorage.ChildAdded:Connect(function(child) if child.Name=="PlaygroundState" then bindState(child) end end)
player:GetAttributeChangedSignal("PCVote"):Connect(refreshVotes)
local function castVote(id)
 if voteBusy or not state or state:GetAttribute("Phase")~="Voting" then return end
 local remote=ReplicatedStorage:FindFirstChild("PlaygroundVoteRequest")
 if not remote or not remote:IsA("RemoteFunction") then return end
 voteBusy=true
 refreshVotes()
 task.spawn(function()
  local ok,reply=pcall(function() return remote:InvokeServer(id) end)
  voteBusy=false
  refreshVotes()
  if not ok then
   for _,panel in ipairs(votePanels) do panel.Message.Text="That vote did not go through. Try again." end
  elseif typeof(reply)=="table" and reply.ok==false then
   for _,panel in ipairs(votePanels) do panel.Message.Text=tostring(reply.message or "Step into the voting area first.") end
  end
 end)
end
for _,panel in ipairs(votePanels) do
 for _,id in ipairs({"BritishBulldog","TagYoureIt","StuckInTheMud"}) do panel[id].Activated:Connect(function() castVote(id) end) end
end
player.CharacterAdded:Connect(function() wasInsideShop=false end)
local elapsed=0
local previewTime=0
RunService.Heartbeat:Connect(function(delta)
 elapsed+=delta
 previewTime+=delta
 if elapsed<0.15 then return end
 elapsed=0
 local character=player.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 local lobby=workspace:FindFirstChild("Playground Lobby")
 local gameplay=lobby and lobby:FindFirstChild("Gameplay")
 local participating=player:GetAttribute("BBParticipating")==true or (player:GetAttribute("TGParticipating")==true or player:GetAttribute("MDParticipating")==true)
 wallet.Visible=not participating
 dock.Visible=not participating
 if participating and shop.Visible then setShop(false) end
 local shopZone=gameplay and gameplay:FindFirstChild("ShopZone")
 local voteZone=gameplay and gameplay:FindFirstChild("VoteZone")
 local inShop=insideZone(shopZone,root)
 if inShop and not wasInsideShop and not participating then setShop(true) end
 wasInsideShop=inShop
 local showVote=not participating and insideZone(voteZone,root) and not shop.Visible
 local camera=workspace.CurrentCamera
 local useCompactVote=camera and (camera.ViewportSize.X<980 or camera.ViewportSize.Y<450) or false
 vote.Visible=showVote and not useCompactVote
 compactVote.Visible=showVote and useCompactVote
 if showVote then refreshVotes() end
 if shop.Visible then
  local rotation=math.sin(previewTime*0.45)*0.30
  for _,preview in ipairs(previews) do
   if preview.model.Parent then preview.model:PivotTo(preview.pivot*CFrame.Angles(0,rotation,0)) end
  end
 end
end)
refreshCards()
refreshVotes()
request("GetStatus",nil,true)


