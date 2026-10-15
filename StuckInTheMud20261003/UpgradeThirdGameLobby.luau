local lobby=workspace["Playground Lobby"]
local gui=game.StarterGui.PlaygroundShell
local vote=gui.VotePanel
local colors={BritishBulldog=Color3.fromRGB(42,160,255),TagYoureIt=Color3.fromRGB(255,130,181),StuckInTheMud=Color3.fromRGB(111,196,151)}
local function textLimit(label,minimum,maximum)
 local limit=label:FindFirstChildOfClass("UITextSizeConstraint")
 if not limit then limit=Instance.new("UITextSizeConstraint") limit.Name="TextSizeLimit" limit.Parent=label end
 limit.MinTextSize=minimum limit.MaxTextSize=maximum
 return limit
end
if not vote:FindFirstChild("StuckInTheMud") then
 local clone=vote.TagYoureIt:Clone()
 clone.Name="StuckInTheMud"
 clone.Text="STUCK IN\nTHE MUD"
 clone.BackgroundColor3=colors.StuckInTheMud
 clone.Parent=vote
 local label=vote.VotesTagYoureIt:Clone()
 label.Name="VotesStuckInTheMud"
 label.Text="0 votes"
 label.Parent=vote
 for index,id in ipairs({"BritishBulldog","TagYoureIt","StuckInTheMud"}) do
  vote[id].Position=UDim2.new(0.035+(index-1)*0.315,0,0.28,0)
  vote[id].Size=UDim2.fromScale(0.30,0.45)
  vote[id].TextWrapped=true
  vote["Votes"..id].Position=UDim2.new(0.035+(index-1)*0.315,0,0.77,0)
  vote["Votes"..id].Size=UDim2.fromScale(0.30,0.13)
 end
end
if not gui:FindFirstChild("CompactVotePanel") then
 local compactVote=vote:Clone()
 compactVote.Name="CompactVotePanel"
 compactVote.Position=UDim2.new(0.5,0,1,-74)
 compactVote.Size=UDim2.new(0.62,0,0,176)
 compactVote.SizeLimit.MinSize=Vector2.new(280,176)
 compactVote.SizeLimit.MaxSize=Vector2.new(660,176)
 compactVote.Visible=false
 for index,id in ipairs({"BritishBulldog","TagYoureIt","StuckInTheMud"}) do
  compactVote[id].Position=UDim2.new(0.035+(index-1)*0.315,0,0.28,0)
  compactVote[id].Size=UDim2.fromScale(0.28,0.42)
  compactVote["Votes"..id].Position=UDim2.new(0.035+(index-1)*0.315,0,0.73,0)
  compactVote["Votes"..id].Size=UDim2.fromScale(0.28,0.11)
 end
 compactVote.Message.Position=UDim2.new(0,10,0,150)
 compactVote.Message.Size=UDim2.new(1,-20,0,20)
 textLimit(compactVote.Message,9,11)
 compactVote.Parent=gui
 gui:SetAttribute("CompactVoteLayoutVersion",1)
end
local admin=game.StarterGui.PlaygroundAdminPanel.Panel.Body
local content=admin.Content
if not content:FindFirstChild("StuckInTheMud") then
 local clone=content.TagYoureIt:Clone()
 clone.Name="StuckInTheMud"
 clone.Position=UDim2.fromOffset(0,436)
 clone.Title.Text="STUCK IN THE MUD"
 clone.TagStart.Name="MudStart"
 clone.TagRunner.Name="MudShooter"
 clone.TagTagger.Name="MudMedic"
 clone.MudShooter.Text="SOLO MUD GUN"
 clone.MudMedic.Text="SOLO RESCUE"
 clone.Parent=content
 content.Size=UDim2.new(content.Size.X.Scale,content.Size.X.Offset,0,644)
 admin.CanvasSize=UDim2.fromOffset(0,652)
end
local adminGui=game.StarterGui.PlaygroundAdminPanel
if not adminGui:FindFirstChild("CompactPanel") then
 local originalPanel=adminGui.Panel
 local compact=Instance.new("Frame")
 compact.Name="CompactPanel"
 compact.Position=UDim2.new(0.012,0,0,64)
 compact.Size=UDim2.new(0.29,0,1,-82)
 compact.BackgroundColor3=originalPanel.BackgroundColor3
 compact.BorderSizePixel=0
 compact.Active=true
 compact.Visible=false
 compact.Parent=adminGui
 for _,name in ipairs({"Corner","Stroke"}) do
  local source=originalPanel:FindFirstChild(name)
  if source then source:Clone().Parent=compact end
 end
 local limit=Instance.new("UISizeConstraint")
 limit.Name="SizeLimit"
 limit.MinSize=Vector2.new(300,0)
 limit.MaxSize=Vector2.new(390,650)
 limit.Parent=compact
 local title=originalPanel.Title:Clone()
 title.Position=UDim2.fromOffset(12,10)
 title.Size=UDim2.new(1,-76,0,38)
 title.Parent=compact
 textLimit(title,10,23)
 local close=originalPanel.Close:Clone()
 close.Position=UDim2.new(1,-54,0,8)
 close.Size=UDim2.fromOffset(44,44)
 close.Parent=compact
 local scroll=Instance.new("ScrollingFrame")
 scroll.Name="Body"
 scroll.Position=UDim2.fromOffset(10,58)
 scroll.Size=UDim2.new(1,-20,1,-68)
 scroll.BackgroundTransparency=1
 scroll.BorderSizePixel=0
 scroll.Active=true
 scroll.CanvasSize=UDim2.fromOffset(0,936)
 scroll.AutomaticCanvasSize=Enum.AutomaticSize.None
 scroll.ScrollingDirection=Enum.ScrollingDirection.Y
 scroll.ScrollBarThickness=4
 scroll.ScrollBarImageColor3=Color3.fromRGB(24,35,62)
 scroll.ClipsDescendants=true
 scroll.Parent=compact
 local compactContent=Instance.new("Frame")
 compactContent.Name="Content"
 compactContent.Position=UDim2.fromOffset(4,4)
 compactContent.Size=UDim2.new(1,-12,0,924)
 compactContent.BackgroundTransparency=1
 compactContent.Parent=scroll
 for index,id in ipairs({"BritishBulldog","TagYoureIt","StuckInTheMud"}) do
  local card=content[id]:Clone()
  card.Position=UDim2.fromOffset(0,(index-1)*252)
  card.Size=UDim2.new(1,0,0,238)
  card.Title.Position=UDim2.fromOffset(10,6)
  card.Title.Size=UDim2.new(1,-20,0,32)
  textLimit(card.Title,10,24)
  card.Status.Position=UDim2.fromOffset(10,42)
  card.Status.Size=UDim2.new(1,-20,0,24)
  local buttons={}
  for _,object in ipairs(card:GetChildren()) do if object:IsA("TextButton") then table.insert(buttons,object) end end
  table.sort(buttons,function(a,b)
   if a.Position.Y.Scale~=b.Position.Y.Scale then return a.Position.Y.Scale<b.Position.Y.Scale end
   return a.Position.Y.Offset<b.Position.Y.Offset
  end)
  for buttonIndex,button in ipairs(buttons) do
   button.Position=UDim2.fromOffset(10,75+(buttonIndex-1)*55)
   button.Size=UDim2.new(1,-20,0,48)
  end
  card.Parent=compactContent
 end
 for index,name in ipairs({"StopRound","ToggleAutomatic"}) do
  local button=originalPanel[name]:Clone()
  button.Position=UDim2.fromOffset(10,756+(index-1)*60)
  button.Size=UDim2.new(1,-20,0,48)
  button.Parent=compactContent
 end
 local message=originalPanel.Message:Clone()
 message.Position=UDim2.fromOffset(10,876)
 message.Size=UDim2.new(1,-20,0,42)
 message.Parent=compactContent
 local toggle=adminGui.Toggle:Clone()
 toggle.Name="CompactToggle"
 toggle.Position=UDim2.new(0.012,0,0,8)
 toggle.Size=UDim2.fromOffset(112,44)
 toggle.Visible=false
 toggle.Parent=adminGui
 adminGui:SetAttribute("CompactLayoutVersion",1)
end
local voting=lobby.VotingAlcove
local gameplay=lobby.Gameplay
if not gameplay.VoteChoices:FindFirstChild("StuckInTheMud") then
 local backup=game.ServerStorage.PlaygroundBeforeMud20261003
 if not backup:FindFirstChild("LobbyVotingBeforeMud") then
  local copy=voting:Clone() copy.Name="LobbyVotingBeforeMud" copy.Parent=backup
  copy=gameplay.VoteChoices:Clone() copy.Name="VoteChoicesBeforeMud" copy.Parent=backup
 end
 for index,id in ipairs({"BritishBulldog","TagYoureIt"}) do
  local stand=voting:FindFirstChild(id.."Stand")
  if stand then
   stand:ScaleTo(stand:GetScale()*0.76)
   local pad=stand:FindFirstChild("ChoicePad")
   local translation=Vector3.new(index==1 and 62 or 88,4.82-pad.Size.Y/2,-84)-pad.Position
   stand:PivotTo(stand:GetPivot()+translation)
  end
 end
 local original=voting:FindFirstChild("BritishBulldogStand")
 if original then
  local stand=original:Clone()
  stand.Name="StuckInTheMudStand"
  stand:PivotTo(stand:GetPivot()+Vector3.new(52,0,0))
  stand.ChoicePad.Color=colors.StuckInTheMud
  stand.ChoiceCardFace.Color=colors.StuckInTheMud
  local face=stand.ChoiceCardFace:FindFirstChild("GameName")
  if face then face.Label.Text="Stuck in the Mud" end
  stand.Parent=voting
 end
 for index,id in ipairs({"BritishBulldog","TagYoureIt","StuckInTheMud"}) do
  local pad=gameplay.VoteChoices:FindFirstChild(id)
  if not pad then pad=gameplay.VoteChoices.BritishBulldog:Clone() pad.Name=id pad.Parent=gameplay.VoteChoices end
  pad.Position=Vector3.new(62+(index-1)*26,8.6,-84)
  pad.Size=Vector3.new(20,8,23)
  pad:SetAttribute("GameId",id)
  pad:SetAttribute("Available",true)
  if id=="StuckInTheMud" then pad:SetAttribute("DisplayName","Stuck in the Mud") end
 end
end
gameplay.VoteZone:SetAttribute("AvailableGames","BritishBulldog,TagYoureIt,StuckInTheMud")
gui:SetAttribute("ThirdGameVersion",2)
return {thirdGameVote=true,adminCard=true,compactAdmin=true,compactVoting=true}
