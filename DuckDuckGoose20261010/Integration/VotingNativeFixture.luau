assert(not game:GetService("RunService"):IsRunning(),"Edit mode required")
local storage=game:GetService("ServerStorage")
local fixture=Instance.new("Folder")fixture.Name,fixture.Parent="DuckDuckGooseVotingFixture",storage
local checks=0
local function check(value,message)checks+=1 assert(value,message)end
local builder=(function()
local Builder = {}
local ids = { "BritishBulldog", "TagYoureIt", "StuckInTheMud", "HideAndSeek", "DuckDuckGoose" }
local navy = Color3.fromRGB(24,35,62)
local gold = Color3.fromRGB(246,189,62)

function Builder.Fallback(button)
	local old = button:FindFirstChild("ArtFallback")
	if old then old:Destroy() end
	for _, child in button:GetChildren() do if child:IsA("UIStroke") then child.Enabled=false end end
	local back = Instance.new("Frame")
	back.Name,back.Size,back.Position = "ArtFallback",UDim2.fromScale(1,1),UDim2.fromScale(0,0)
	back.BackgroundColor3,back.BorderSizePixel,back.ZIndex = navy,0,8
	back.Active,back.Selectable,back.Visible = false,false,not button.ReusableSkin.IsLoaded
	local corner=Instance.new("UICorner")corner.CornerRadius,corner.Parent=UDim.new(0,10),back
	local border=Instance.new("UIStroke")border.Color,border.Thickness,border.Parent=Color3.fromRGB(255,249,224),1.5,back
	local face=Instance.new("Frame")
	face.Name,face.Position,face.Size="Face",UDim2.fromOffset(3,3),UDim2.new(1,-6,1,-8)
	face.BackgroundColor3,face.BorderSizePixel,face.ZIndex=button.BackgroundColor3,0,8
	face.Active,face.Selectable,face.Parent=false,false,back
	local innerCorner=Instance.new("UICorner")innerCorner.CornerRadius,innerCorner.Parent=UDim.new(0,7),face
	local innerBorder=Instance.new("UIStroke")innerBorder.Color,innerBorder.Thickness,innerBorder.Parent=Color3.fromRGB(255,249,224),1.2,face
	local gradient=Instance.new("UIGradient")
	gradient.Color,gradient.Rotation,gradient.Parent=ColorSequence.new(Color3.fromRGB(255,255,255),Color3.fromRGB(195,195,195)),90,face
	back.Parent=button
	return back
end

function Builder.Hint(hint)
	for _, child in hint:GetDescendants() do if child:IsA("UIStroke") or child:IsA("UITextSizeConstraint") then child:Destroy() end end
	hint.Text,hint.TextColor3,hint.TextStrokeTransparency="SWIPE OR SCROLL FOR ALL 5 GAMES",navy,1
	hint.Font,hint.ZIndex=Enum.Font.GothamMedium,13
	hint.TextTruncate,hint.TextWrapped,hint.TextScaled=Enum.TextTruncate.None,false,false
	hint.TextSize=13
end

local function readable(label, maximum)
	label.TextTruncate = Enum.TextTruncate.None
	label.TextWrapped = true
	local limit = label:FindFirstChildOfClass("UITextSizeConstraint")
	if not limit then limit = Instance.new("UITextSizeConstraint") limit.Parent = label end
	limit.MinTextSize, limit.MaxTextSize = 10,maximum
	label.TextScaled = true
end

function Builder.Panel(panel)
	assert(not panel:FindFirstChild("Choices"), "Voting row already exists")
	local compact = panel.Name == "CompactVotePanel"
	local width, gap = compact and 128 or 154, 8
	local buttons, counters = {},{}
	for _, id in ids do
		local sourceId = id == "DuckDuckGoose" and "HideAndSeek" or id
		buttons[id], counters[id] = panel[sourceId]:Clone(),panel["Votes"..sourceId]:Clone()
	end
	for _, id in ids do
		local button, counter = panel:FindFirstChild(id),panel:FindFirstChild("Votes"..id)
		if button then button:Destroy() end
		if counter then counter:Destroy() end
	end
	panel.Size = UDim2.new(compact and .94 or .62,0,0,166)
	panel.Title.Position, panel.Title.Size = UDim2.new(0,14,0,9),UDim2.new(1,-112,0,25)
	panel.Timer.Position, panel.Timer.Size = UDim2.new(1,-88,0,10),UDim2.fromOffset(72,24)
	panel.Message.Position, panel.Message.Size = UDim2.new(0,14,1,-23),UDim2.new(1,-28,0,17)
	readable(panel.Title,22)
	readable(panel.Timer,22)
	readable(panel.Message,13)
	local choices = Instance.new("ScrollingFrame")
	choices.Name, choices.BackgroundTransparency, choices.BorderSizePixel = "Choices",1,0
	choices.Position, choices.Size = UDim2.fromOffset(14,39),UDim2.new(1,-28,0,82)
	choices.CanvasSize, choices.ScrollingDirection = UDim2.fromOffset(#ids*(width+gap)-gap,82),Enum.ScrollingDirection.X
	choices.AutomaticCanvasSize, choices.ScrollBarThickness = Enum.AutomaticSize.None,6
	choices.ScrollBarImageColor3, choices.ElasticBehavior = navy,Enum.ElasticBehavior.WhenScrollable
	choices.ClipsDescendants, choices.Selectable, choices.Parent = true,false,panel
	choices.ZIndex = 9
	local hint = panel.Message:Clone()
	hint.Name, hint.Text, hint.TextColor3 = "ScrollHint","SWIPE OR SCROLL FOR ALL 5 GAMES",navy
	hint.Position, hint.Size = UDim2.fromOffset(14,124),UDim2.new(1,-28,0,16)
	Builder.Hint(hint)
	hint.Parent = panel
	for index,id in ids do
		local card = Instance.new("Frame")
		card.Name, card.BackgroundTransparency, card.BorderSizePixel = id,1,0
		card.Position, card.Size, card.LayoutOrder = UDim2.fromOffset((index-1)*(width+gap),0),UDim2.fromOffset(width,73),index
		card.Parent = choices
		card.ZIndex = 9
		local button, counter = buttons[id],counters[id]
		button.Name, button.Position, button.Size = "Button",UDim2.fromOffset(0,0),UDim2.fromOffset(width,48)
		button.Text, button.TextTransparency = "",1
		button.Parent = card
		if id == "DuckDuckGoose" then
			button.BackgroundColor3 = gold
			button.LiveCaption.Text = "DUCK DUCK\nGOOSE"
			button.ReusableSkin.Image = "rbxassetid://84589903135132"
			button.ReusableSkin:SetAttribute("DefaultImage",button.ReusableSkin.Image)
		end
		button.ReusableSkin.ScaleType, button.ReusableSkin.SliceCenter = Enum.ScaleType.Slice,Rect.new(88,88,424,232)
		Builder.Fallback(button)
		readable(button.LiveCaption,compact and 16 or 19)
		counter.Name, counter.Position, counter.Size = "VoteCount",UDim2.fromOffset(0,51),UDim2.fromOffset(width,19)
		counter.Text, counter.Parent = "0 votes",card
		readable(counter,14)
	end
	for index,id in ids do
		local button = choices[id].Button
		button.NextSelectionLeft = choices[ids[math.max(1,index-1)]].Button
		button.NextSelectionRight = choices[ids[math.min(#ids,index+1)]].Button
	end
	panel:SetAttribute("DuckDuckGooseVoting20261010",true)
	return panel
end

function Builder.Admin(rounds)
	assert(not rounds:FindFirstChild("DuckDuckGoose"), "Admin card already exists")
	local card = rounds.HideAndSeek:Clone()
	card.Name, card.LayoutOrder = "DuckDuckGoose",5
	card.Title.Text, card.Status.Text = "DUCK DUCK GOOSE","Ready • 2–16 players"
	card.HSStart.Name = "DGStart"
	card.DGStart.Text, card.DGStart.LiveCaption.Text = "","START GOOSE ROUND"
	readable(card.Title,26)
	readable(card.Status,18)
	readable(card.DGStart.LiveCaption,22)
	card.Parent = rounds
	rounds.RoundSettings.LayoutOrder = 6
	return card
end

return Builder

end)()
local shell=game:GetService("StarterGui").PlaygroundShell
local uiBackup=storage:FindFirstChild("DuckDuckGooseUiBackup20261010")
local ids={"BritishBulldog","TagYoureIt","StuckInTheMud","HideAndSeek","DuckDuckGoose"}
for _,name in {"VotePanel","CompactVotePanel"}do
 local panel=(uiBackup and uiBackup[name] or shell[name]):Clone()panel.Parent=fixture
 builder.Panel(panel)
 check(panel.Size.Y.Offset==166,"Voting panel remains compact")
 check(panel.Choices:IsA("ScrollingFrame") and panel.Choices.ScrollingDirection==Enum.ScrollingDirection.X,"Five cards use horizontal scrolling")
 check(panel.Choices.ScrollBarThickness>=6 and panel.ScrollHint.Visible,"Scroll affordance is visible")
 check(panel.Choices.ZIndex>panel.ReusableSkin.ZIndex,"Cards container renders above panel skin")
 check(panel.ScrollHint.ZIndex>panel.ReusableSkin.ZIndex and panel.ScrollHint.TextStrokeTransparency==1,"Scroll hint is legible above skin")
 check(not panel.ScrollHint.TextScaled and panel.ScrollHint.TextSize==13 and panel.ScrollHint.Font==Enum.Font.GothamMedium,"Hint uses plain readable text")
 check(not panel.ScrollHint:FindFirstChildWhichIsA("UIStroke",true),"Hint has no cloned stroke")
 local last=0
 for index,id in ids do
  local card=panel.Choices[id]
  check(card.Button:IsA("TextButton") and card.VoteCount:IsA("TextLabel"),"Editable card contains button and counter")
  check(card.Button.Size.Y.Offset>=44,"Card offers a practical touch target")
  check(card.Position.X.Offset>=last,"Cards do not overlap")
  last=card.Position.X.Offset+card.Size.X.Offset
  check(card.Button.LiveCaption.TextScaled and card.Button.LiveCaption.TextWrapped,"Card captions remain scaled and wrapped")
  check(card.VoteCount.TextScaled and card.VoteCount.TextWrapped,"Counts remain readable")
  check(card.Button.Text=="","Button has one visible caption")
  check(card.ZIndex>panel.ReusableSkin.ZIndex,"Card renders above background skin")
  check(card.Button.ArtFallback.Face~=nil and card.Button.ArtFallback.ZIndex<card.Button.LiveCaption.ZIndex,"Unavailable images have a fallback below caption")
  check(card.Button.ArtFallback.Visible==not card.Button.ReusableSkin.IsLoaded,"Fallback visibility matches image availability")
 end
 check(last==panel.Choices.CanvasSize.X.Offset,"Canvas includes all five complete cards")
 check(panel.Message.TextScaled and panel.Title.TextScaled and panel.Timer.TextScaled,"Header and message keep text scaling")
 if name=="CompactVotePanel"then
  for _,viewport in {Vector2.new(568,320),Vector2.new(667,375),Vector2.new(852,393),Vector2.new(390,844),Vector2.new(768,1024),Vector2.new(1024,768)}do
   local width=viewport.X*panel.Size.X.Scale+panel.Size.X.Offset
   check(width<viewport.X and panel.Size.Y.Offset<viewport.Y*.55,"Compact panel stays within device viewport")
  end
 end
end
local rounds=(uiBackup and uiBackup.Rounds or game:GetService("StarterGui").PlaygroundAdminPanel.AdminHub.Pages.Rounds):Clone()rounds.Parent=fixture
builder.Admin(rounds)
check(rounds.DuckDuckGoose.DGStart~=nil,"Owner admin gets fifth start control")
check(rounds.RoundSettings.LayoutOrder==6,"Admin cards retain stable order")
local sourceLobby=workspace["Playground Lobby"]
local model=Instance.new("Model")model.Name,model.Parent="MockLobby",fixture
local worldBackup=storage:FindFirstChild("DuckDuckGooseWorldVoteBackup20261010")
local sourceAlcove=worldBackup and worldBackup.VotingAlcove or sourceLobby.VotingAlcove
sourceAlcove:Clone().Parent=model
local gameplay=Instance.new("Folder")gameplay.Name,gameplay.Parent="Gameplay",model
local sourceChoices=worldBackup and worldBackup.VoteChoices or sourceLobby.Gameplay.VoteChoices
local sourceZone=worldBackup and worldBackup.VoteZone or sourceLobby.Gameplay.VoteZone
sourceChoices:Clone().Parent=gameplay
sourceZone:Clone().Parent=gameplay
local mockGame={PlaceId=game.PlaceId}
function mockGame:GetService(name)if name=="RunService"then return {IsRunning=function()return false end}end if name=="ServerStorage"then return fixture end end
local worldFactory=function(game,workspace)
assert(not game:GetService("RunService"):IsRunning(), "Stop Play before editing voting stands.")
assert(game.PlaceId == 95034648955135, "Wrong experience.")
local lobby = workspace["Playground Lobby"]
local alcove, choices = lobby.VotingAlcove,lobby.Gameplay.VoteChoices
if choices:FindFirstChild("DuckDuckGoose") then return {alreadyInstalled=true} end
assert(not alcove:FindFirstChild("DuckDuckGooseStand"), "Partial fifth voting stand installation")
local storage = game:GetService("ServerStorage")
local backup = Instance.new("Folder")
backup.Name, backup.Parent = "DuckDuckGooseWorldVoteBackup20261010",storage
for _, object in {alcove,choices,lobby.Gameplay.VoteZone} do object:Clone().Parent = backup end
local stand = alcove.HideAndSeekStand:Clone()
stand.Name = "DuckDuckGooseStand"
for _, item in stand:GetDescendants() do
	if item:IsA("BasePart") then
		item.Anchored,item.Locked = true,true
		if item.Name == "ChoicePad" or item.Name == "ChoiceCardFace" or item.Name == "ArchTop" then item.Color = Color3.fromRGB(246,189,62) end
	elseif item:IsA("Highlight") then item.Adornee = stand
	elseif item:IsA("TextLabel") then
		item.Text = "Duck Duck\nGoose"
		item.TextTruncate,item.TextWrapped = Enum.TextTruncate.None,true
		item.TextScaled = true
	elseif item:IsA("ImageLabel") and item.Name == "ReusableSkin" then
		item.Image = "rbxassetid://84589903135132"
		item:SetAttribute("DefaultImage",item.Image)
	end
end
stand.Parent = alcove
local trigger = choices.HideAndSeek:Clone()
trigger.Name = "DuckDuckGoose"
trigger:SetAttribute("GameId","DuckDuckGoose")
trigger:SetAttribute("DisplayName","Duck Duck Goose")
trigger:SetAttribute("Available",true)
trigger.Parent = choices
local ids = {"BritishBulldog","TagYoureIt","StuckInTheMud","HideAndSeek","DuckDuckGoose"}
for index,id in ids do
	local model = alcove[id.."Stand"]
	local _,bounds = model:GetBoundingBox()
	model:ScaleTo(model:GetScale()*11.9/bounds.X)
	local pad = model.ChoicePad
	local target = Vector3.new(62.8+12.6*(index-1),4.6832,-84)
	model:PivotTo(model:GetPivot()+(target-pad.Position))
	choices[id].CFrame = pad.CFrame + Vector3.new(0,3,0)
	choices[id].Size = Vector3.new(pad.Size.X,6,pad.Size.Z)
	choices[id].CanCollide,choices[id].CanTouch,choices[id].CanQuery = false,false,false
	choices[id].Transparency = 1
end
lobby.Gameplay.VoteZone:SetAttribute("AvailableGames",table.concat(ids,","))
return {choices=#ids,standWidth=11.9,padsFitExistingAlcove=true}

end
local result=worldFactory(mockGame,{["Playground Lobby"]=model})
check(result.choices==5,"Fifth world voting stand is built")
local zone=gameplay.VoteZone
local previousRight=-math.huge
for _,id in ids do
 local stand=model.VotingAlcove[id.."Stand"]
 local cf,size=stand:GetBoundingBox()
 check(math.abs(size.X-11.9)<.02,"Stand width fits new five-card row")
 check(cf.X-size.X/2>previousRight,"Voting stands do not overlap")
 previousRight=cf.X+size.X/2
 local trigger=gameplay.VoteChoices[id]
 local localPoint=zone.CFrame:PointToObjectSpace(trigger.Position)
 check(math.abs(localPoint.X)+trigger.Size.X/2<=zone.Size.X/2+.01,"Voting trigger stays within alcove width")
 check(math.abs(localPoint.Z)+trigger.Size.Z/2<=zone.Size.Z/2+.01,"Voting trigger stays within alcove depth")
 check(math.abs(localPoint.Y)+trigger.Size.Y/2<=zone.Size.Y/2+.01,"Voting trigger stays within alcove height")
 check(trigger:GetAttribute("GameId")==id and not trigger.CanCollide and not trigger.CanQuery,"Voting trigger routes safely")
end
check(gameplay.VoteChoices.DuckDuckGoose:GetAttribute("DisplayName")=="Duck Duck Goose","World vote name is correct")
check(worldFactory(mockGame,{["Playground Lobby"]=model}).alreadyInstalled,"World builder is idempotent")
fixture:Destroy()
return {passed=true,checks=checks,editableMobileCards=true,liveLayoutsUnaffected=true,playStarted=false}
