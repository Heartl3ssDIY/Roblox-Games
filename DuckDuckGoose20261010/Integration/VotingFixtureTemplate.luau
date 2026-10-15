assert(not game:GetService("RunService"):IsRunning(),"Edit mode required")
local storage=game:GetService("ServerStorage")
local fixture=Instance.new("Folder")fixture.Name,fixture.Parent="DuckDuckGooseVotingFixture",storage
local checks=0
local function check(value,message)checks+=1 assert(value,message)end
local builder=(function()
UI_BUILDER
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
WORLD_BUILDER
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
