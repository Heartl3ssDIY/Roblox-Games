local g=script.Parent local p=game.Players.LocalPlayer
local RS=game:GetService("ReplicatedStorage")
local C=require(RS:WaitForChild("GBloxEmoteCatalog"))
local remote=RS:WaitForChild("GBloxEmoteRequest")
local shop=g.Canvas.Shop local list=shop.Emotes
local cards={} local busy=false
local function label(parent,text,pos,size,max)
 local l=Instance.new("TextLabel") l.BackgroundTransparency=1 l.Position=pos l.Size=size
 l.Text=text l.TextWrapped=true l.TextScaled=true l.RichText=false l.Font=Enum.Font.Arcade
 l.TextColor3=Color3.new(1,1,1) l.TextStrokeTransparency=0 l.Parent=parent
 local limit=Instance.new("UITextSizeConstraint") limit.MinTextSize=8 limit.MaxTextSize=max limit.Parent=l
 return l
end
local function refresh()
 for id,card in cards do
  local owned=p:GetAttribute("GBloxEmoteOwned_"..id)==true
  card.caption.Text=owned and "OWNED" or busy and "PLEASE WAIT..." or "30 TROPHIES"
  card.button.Active=not owned and not busy and p:GetAttribute("PlayerDataReady")==true
  card.button.Selectable=card.button.Active
  card.button.ImageColor3=owned and Color3.fromRGB(119,231,167) or Color3.new(1,1,1)
 end
end
for index,e in C.List do
 local c=Instance.new("ImageLabel") c.Name="Emote_"..e.Id c.LayoutOrder=index
 c.BackgroundTransparency=1 c.Image="rbxassetid://119353987494774" c.Parent=list
 label(c,e.Name,UDim2.fromScale(.06,.05),UDim2.fromScale(.88,.23),19)
 local pic=Instance.new("ImageLabel") pic.BackgroundTransparency=1
 pic.Position=UDim2.fromScale(.05,.29) pic.Size=UDim2.fromScale(.32,.42)
 pic.Image="rbxthumb://type=Asset&id="..e.Id.."&w=150&h=150" pic.ScaleType=Enum.ScaleType.Fit pic.Parent=c
 label(c,"PODIUM EMOTE\nG-Blox unlock only",UDim2.fromScale(.40,.30),UDim2.fromScale(.54,.36),14)
 local b=Instance.new("ImageButton") b.Name="Buy" b.BackgroundTransparency=1
 b.Image="rbxassetid://120915846902729" b.Position=UDim2.fromScale(.12,.75) b.Size=UDim2.fromScale(.76,.19)
 b.Parent=c b.AutoButtonColor=true
 local caption=label(b,"30 TROPHIES",UDim2.fromScale(.04,.08),UDim2.fromScale(.92,.84),18)
 cards[e.Id]={button=b,caption=caption}
 b.Activated:Connect(function()
  if busy or not b.Active then return end
  busy=true refresh()
  shop.MockupNotice.Visible=true shop.MockupNotice.Text="Checking emote availability..."
  local ok,success,message=pcall(function() return remote:InvokeServer("Buy",e.Id) end)
  busy=false refresh()
  shop.MockupNotice.Text=ok and (message or "Please try again.") or "Connection error. Check your inventory before retrying."
 end)
end
p:GetAttributeChangedSignal("GBloxEmotesRevision"):Connect(refresh)
p:GetAttributeChangedSignal("PlayerDataReady"):Connect(refresh)
list:GetPropertyChangedSignal("Visible"):Connect(function()
 if list.Visible then shop.MockupNotice.Text="30 trophies each • permanent G-Blox unlock • equip up to 8 in Inventory" end
end)
refresh()

