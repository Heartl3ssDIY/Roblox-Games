assert(not game:GetService("RunService"):IsRunning(),"Edit mode required")
local fixture=Instance.new("Folder")fixture.Name,fixture.Parent="DuckDuckGooseVoteBehaviorFixture",game:GetService("ServerStorage")
local module=Instance.new("ModuleScript")
local original=game:GetService("StarterGui").PlaygroundShell.Controller
module.Name,module.Source,module.Capabilities,module.Sandboxed,module.Parent="VoteRefreshFactory",[==[return function(state,player,votePanels,workspace)
local blue,pink,mint,gold=Color3.fromRGB(89,193,244),Color3.fromRGB(242,139,164),Color3.fromRGB(139,220,179),Color3.fromRGB(251,208,91)
local voteBusy=false
local function votesText(count)
 return tostring(count)..(count==1 and " vote" or " votes")
end
local lastDisplayedVote = {}
local function refreshVotes()
 local phase=state and state:GetAttribute("Phase") or "Waiting"
 local voting=phase=="Voting"
 local chosen=player:GetAttribute("PCVote")
 for _,vote in ipairs(votePanels) do
 vote.Title.Text=voting and "PICK THE NEXT ROUND" or "NEXT ROUND"
 local ending=state and state:GetAttribute("VotingEndsAt") or 0
 vote.Timer.Text=voting and tostring(math.max(0,math.ceil(ending-workspace:GetServerTimeNow()))).."s" or phase=="Playing" and "PLAYING" or phase=="Paused" and "PAUSED" or "WAITING"
 for _, id in ipairs({ "BritishBulldog", "TagYoureIt", "StuckInTheMud", "HideAndSeek", "DuckDuckGoose" }) do
  local card = vote.Choices[id]
  local button, counter = card.Button, card.VoteCount
  local available = state and state:GetAttribute("Available" .. id) ~= false
  local color = ({ BritishBulldog = blue, TagYoureIt = pink, StuckInTheMud = mint, HideAndSeek = Color3.fromRGB(188,143,245), DuckDuckGoose = Color3.fromRGB(246,189,62) })[id]
  counter.Text = votesText(state and state:GetAttribute("Votes" .. id) or 0)
  button.BackgroundColor3 = chosen == id and gold or color
  button.Active = voting and not voteBusy and available == true
  button.Selectable = button.Active
  local selection = button:FindFirstChild("SelectionMark")
  if selection then selection.Visible = chosen == id end
  if not available then
   button.BackgroundColor3 = Color3.fromRGB(162,169,184)
   local minimum = state and state:GetAttribute("Minimum" .. id) or 2
   counter.Text = (state and state:GetAttribute("ReadyPlayerCount") or 0) < minimum and "Needs " .. tostring(minimum) .. " players" or "Unavailable"
  end
  local fallback = button:FindFirstChild("ArtFallback")
  if fallback then
   fallback.Visible = not button.ReusableSkin.IsLoaded
   fallback.Face.BackgroundColor3 = button.BackgroundColor3
  end
 end
 if chosen and chosen ~= "" and chosen ~= lastDisplayedVote[vote] then
  local card = vote.Choices:FindFirstChild(chosen)
  if card then
   local left = card.Position.X.Offset
   local right = left + card.Size.X.Offset
   local current = vote.Choices.CanvasPosition.X
   local width = vote.Choices.AbsoluteSize.X
   local maximum = math.max(0, vote.Choices.AbsoluteCanvasSize.X - width)
   if left < current then current = left elseif right > current + width then current = right - width end
   vote.Choices.CanvasPosition = Vector2.new(math.clamp(current, 0, maximum), 0)
   lastDisplayedVote[vote] = chosen
  end
 end
 if not voteBusy then
  vote.Message.Text=voting and (chosen and chosen~="" and "Your vote is saved. You can change it." or "Step onto a card to vote, or tap it here.") or phase=="Playing" and "Another round is underway." or phase=="Paused" and "The next round is paused." or "Voting opens when the next round is ready."
 end
 end
end

return refreshVotes
end]==],original.Capabilities,original.Sandboxed,fixture
local attrs=Instance.new("Folder")attrs.Parent=fixture
local player={}
function player:GetAttribute(name)return attrs:GetAttribute(name)end
local state=Instance.new("Folder")state.Parent=fixture
state:SetAttribute("Phase","Voting")state:SetAttribute("ReadyPlayerCount",2)state:SetAttribute("VotingEndsAt",135)
local ids={"BritishBulldog","TagYoureIt","StuckInTheMud","HideAndSeek","DuckDuckGoose"}
local choices={AbsoluteSize=Vector2.new(300,82),AbsoluteCanvasSize=Vector2.new(672,82),CanvasPosition=Vector2.new(0,0)}
function choices:FindFirstChild(name)return self[name]end
for index,id in ids do
 local art={Visible=false,Face={BackgroundColor3=Color3.new()}}
 local mark={Visible=false}
 local button={ReusableSkin={IsLoaded=id=="HideAndSeek"},BackgroundColor3=Color3.new()}
 function button:FindFirstChild(name)if name=="ArtFallback"then return art elseif name=="SelectionMark"then return mark end end
 choices[id]={Position=UDim2.fromOffset((index-1)*136,0),Size=UDim2.fromOffset(128,73),Button=button,VoteCount={Text=""},Art=art,Mark=mark}
end
local panel={Title={},Timer={},Message={},Choices=choices}
local world={}function world:GetServerTimeNow()return 100 end
local refresh=require(module)(state,player,{panel},world)
local checks=0 local function check(v,message)checks+=1 assert(v,message)end
attrs:SetAttribute("PCVote","DuckDuckGoose")refresh()
check(choices.DuckDuckGoose.Art.Visible,"Unavailable DG image uses fallback")
check(not choices.HideAndSeek.Art.Visible,"Loaded HS image retains original PNG")
check(choices.DuckDuckGoose.Mark.Visible,"Selection mark uses chosen card")
check(choices.DuckDuckGoose.Art.Face.BackgroundColor3==choices.DuckDuckGoose.Button.BackgroundColor3,"Fallback follows selected colour")
check(choices.CanvasPosition.X==372,"Chosen last card scrolls completely into view")
choices.DuckDuckGoose.Button.ReusableSkin.IsLoaded=true refresh()
check(not choices.DuckDuckGoose.Art.Visible,"Fallback disappears when image loads")
choices.DuckDuckGoose.Button.ReusableSkin.IsLoaded=false
state:SetAttribute("AvailableDuckDuckGoose",false)state:SetAttribute("MinimumDuckDuckGoose",4)refresh()
check(choices.DuckDuckGoose.VoteCount.Text=="Needs 4 players","Unavailable card explains player requirement")
check(not choices.DuckDuckGoose.Button.Active,"Unavailable card cannot vote")
check(choices.DuckDuckGoose.Art.Face.BackgroundColor3==Color3.fromRGB(162,169,184),"Unavailable fallback follows muted colour")
choices.CanvasPosition=Vector2.new(0,0)refresh()
check(choices.CanvasPosition.X==0,"User may manually browse after selection")
attrs:SetAttribute("PCVote","HideAndSeek")refresh()
check(choices.CanvasPosition.X==236,"Changed selection auto-scrolls to its own card")
check(choices.HideAndSeek.Position==UDim2.fromOffset(408,0) and choices.HideAndSeek.Size==UDim2.fromOffset(128,73),"Runtime never changes authored card geometry")
fixture:Destroy()
return {passed=true,checks=checks,fallbackBehaviorTested=true,selectedScrollingTested=true,playStarted=false}
