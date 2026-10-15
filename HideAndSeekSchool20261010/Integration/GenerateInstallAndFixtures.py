from pathlib import Path
import json

root = Path(__file__).parent
controller = (root / 'HideAndSeekHudController.luau').read_text(encoding='utf-8')
build = (root / 'BuildHudAndVotes.luau').read_text(encoding='utf-8')
install = '''assert(not game:GetService("RunService"):IsRunning(), "Stop Play before installing school HUD behavior.")
local gui = game:GetService("StarterGui"):WaitForChild("HideAndSeekHUD")
assert(not gui:FindFirstChild("Controller"), "HUD behavior already installed.")
local controller = Instance.new("LocalScript")
controller.Name = "Controller"
controller.Capabilities = SecurityCapabilities.new(
 Enum.SecurityCapability.RunClientScript, Enum.SecurityCapability.AccessOutsideWrite,
 Enum.SecurityCapability.Basic, Enum.SecurityCapability.Physics, Enum.SecurityCapability.UI,
 Enum.SecurityCapability.Input, Enum.SecurityCapability.RemoteEvent, Enum.SecurityCapability.Players,
 Enum.SecurityCapability.AvatarBehavior
)
controller.Source = [==[SOURCE]==]
controller.Parent = gui
return { controller = controller:GetFullName(), authoredLayoutsPreserved = true }
'''.replace('SOURCE', controller)
(root / 'InstallHudController.luau').write_text(install, encoding='utf-8')

coord = (root / 'After' / 'ServerScriptService.PlaygroundCoordinator.luau').read_text(encoding='utf-8')
gui_builder = build[build.index('local navy ='):build.index('gui.Parent = StarterGui')]
gui_builder += 'gui.Parent = fixture\n'
fixture = '''assert(not game:GetService("RunService"):IsRunning(), "Native fixtures require Edit mode.")
local checks = 0
local function check(value,message)
 assert(value,message)
 checks += 1
end
local storage = game:GetService("ServerStorage")
local fixture = Instance.new("Folder")
fixture.Name = "HideAndSeekIntegrationFixture"
fixture.Parent = storage
local function signal()
 local event = Instance.new("BindableEvent")
 event.Parent = fixture
 return event
end
local function moduleFrom(source,capabilities)
 local module = Instance.new("ModuleScript")
 module.Name, module.Source, module.Capabilities, module.Parent = "FixtureModule",source,capabilities,fixture
 return require(module)
end
local coordinatorFactory = moduleFrom([==[return function(game, workspace)
COORDINATOR
end]==],game:GetService("ServerScriptService").PlaygroundCoordinator.Capabilities)
local players = {}
local roster = {}
function players:GetPlayers() return roster end
function players:GetPlayerByUserId(id) for _,p in roster do if p.UserId == id then return p end end end
local function makePlayer(id,ready)
 local attrs = Instance.new("Folder") attrs.Parent = fixture
 local character = Instance.new("Model") character.Parent = fixture
 local humanoid = Instance.new("Humanoid") humanoid.Parent = character
 local root = Instance.new("Part") root.Name,root.Position,root.Parent = "HumanoidRootPart",Vector3.new(0,0,0),character
 local p = { UserId = id, Name = "Fixture"..id, Parent = players, Character = character }
 function p:GetAttribute(name) return attrs:GetAttribute(name) end
 function p:SetAttribute(name,value) attrs:SetAttribute(name,value) end
 function p:GetAttributeChangedSignal(name) return attrs:GetAttributeChangedSignal(name) end
 function p:RemoveReplicationFocus() end
 function p:AddReplicationFocus() end
 p:SetAttribute("PCDataReady",ready)
 table.insert(roster,p)
 return p
end
local a,b,observer = makePlayer(1,true),makePlayer(2,true),makePlayer(3,false)
local state = Instance.new("Folder") state.Parent = fixture
local replicated = {}
function replicated:WaitForChild(name) assert(name=="PlaygroundState") return state end
local mockGame = {}
function mockGame:GetService(name) return ({Players=players,ReplicatedStorage=replicated,RunService={}})[name] end
local mockWorkspace = {}
function mockWorkspace:GetServerTimeNow() return 100 end
local Coordinator = coordinatorFactory(mockGame,mockWorkspace)
local lobby = { Gameplay = { VoteZone = {CFrame=CFrame.new(),Size=Vector3.new(100,100,100)} } }
function lobby.Gameplay:FindFirstChild() return nil end
local services = {}
for _,id in {"BritishBulldog","TagYoureIt","StuckInTheMud","HideAndSeek"}do
 local service = {active=false,running=true,state=Instance.new("Folder"),arena=Instance.new("Folder")}
 service.state.Parent,service.arena.Parent = fixture,fixture
 service.arena:SetAttribute("MinimumPlayers",2)
 function service:StartRound(selected)
  self.selected,self.active = selected,true
  self.state:SetAttribute("Phase","Seeking")
  if id=="HideAndSeek" then for _,p in selected do p:SetAttribute("HSParticipating",true) end end
  return true
 end
 function service:StopRound() self.active=false for _,p in roster do p:SetAttribute("HSParticipating",false) end end
 services[id] = service
end
local rewards = {}
local economy = {}
function economy:AwardRound(...) table.insert(rewards,{...}) end
local coordinator = Coordinator.new(services,lobby,economy)
check(#coordinator:_readyPlayers()==2,"Data-ready players remain the only round candidates")
check(coordinator:MinimumPlayers("HideAndSeek")==2,"School minimum is two")
check(coordinator:GameAvailable("HideAndSeek",2),"School is available with two ready players")
check(not coordinator:GameAvailable("HideAndSeek",1),"One player cannot start school")
coordinator:_availability(2)
check(state:GetAttribute("AvailableHideAndSeek")==true,"School availability reaches voting UI")
coordinator:_step(100)
check(state:GetAttribute("Phase")=="Voting","35-second vote phase starts")
check(state:GetAttribute("VotingEndsAt")==135,"Existing 35-second intermission is preserved")
check(coordinator:Vote(a,"HideAndSeek").ok,"School can receive a vote")
check(coordinator:Vote(b,"HideAndSeek").ok,"Both players can vote for school")
check(state:GetAttribute("VotesHideAndSeek")==2,"School vote count is published")
check(coordinator:_chooseGame()=="HideAndSeek","School wins the vote")
coordinator:_step(134)
check(not services.HideAndSeek.active,"School does not start early")
coordinator:_step(135)
check(services.HideAndSeek.active,"School starts after intermission")
check(coordinator:ActiveGame()=="HideAndSeek","Coordinator recognizes the fourth game")
check(state:GetAttribute("GameTitle")=="Hide and Seek","Shared current-game title is updated")
check(#services.HideAndSeek.selected==2,"Ready-player array reaches the service")
check(coordinator:_participating(a),"School participation gates all coordinator actions")
check(#coordinator:_readyPlayers()==0,"School players cannot enter another round")
a:SetAttribute("PCAFKRequested",true)
coordinator:_syncAFK(a)
check(a:GetAttribute("PCAFKQueued")==true and a:GetAttribute("PCAFK")==false,"AFK queues until the school round ends")
local target, root = coordinator:_spectateTarget(observer,a.UserId)
check(target==a and root==a.Character.HumanoidRootPart,"Lobby spectator can target a school participant")
check(coordinator:_spectateTarget(a,b.UserId)==nil,"Active school players cannot spectate")
check(not coordinator:Vote(a,"HideAndSeek").ok,"School participants cannot vote in their round")
services.HideAndSeek.state:SetAttribute("LastResultWinnerIds","1")
services.HideAndSeek.state:SetAttribute("LastResultParticipantIds","1,2")
services.HideAndSeek.state:SetAttribute("LastResultRound",7)
coordinator:_rewardHideAndSeek()
check(#rewards==1 and rewards[1][1]=="HS:7","School results use their own receipt key")
check(rewards[1][2][1]==1 and rewards[1][4][2]==2,"Winner and participant lists reach the economy")
check(rewards[1][5].gameId=="HideAndSeek","School rewards are counted under the fourth game")
coordinator:StopGame()
check(not services.HideAndSeek.active,"Stop round handles school")
check(state:GetAttribute("Phase")=="Paused","Explicit admin stop still pauses automatic rounds")
check(not coordinator:_participating(a),"School cleanup returns players to the lobby")
coordinator:SetAutoEnabled(true)
a:SetAttribute("PCAFKRequested",false)
local ok,reason = coordinator:StartGame("HideAndSeek",a,"Seeker",false)
check(not ok and reason=="This game requires a normal round.","Unsupported practice request fails safely")
local StarterGui = game:GetService("StarterGui")
local shell = StarterGui.PlaygroundShell
GUIBUILDER
local player = a
player.PlayerGui = fixture
player:SetAttribute("HSParticipating",false)
player:SetAttribute("HSRole","Hider")
player:SetAttribute("HSStamina",10)
player:SetAttribute("HSMaxStamina",10)
local hsState = Instance.new("Folder") hsState.Name,hsState.Parent = "MockState",fixture
local heartbeat = signal()
local released,focused = signal(),signal()
local inputEnded = signal()
local charRemoving = signal()
player.CharacterRemoving = charRemoving.Event
local actions = {}
local context = {}
function context:BindAction(name,callback) actions[name]=callback end
function context:UnbindAction(name) actions[name]=nil end
local input = { TouchEnabled=true,WindowFocusReleased=released.Event,WindowFocused=focused.Event,InputEnded=inputEnded.Event }
function input:GetFocusedTextBox() return nil end
local requests,exits = {},{}
local sprintRemote = {} function sprintRemote:FireServer(value)table.insert(requests,value)end
local actionRemote = {} function actionRemote:FireServer(value)table.insert(exits,value)end
local rs = {}
function rs:WaitForChild(name) return ({HideAndSeekState=hsState,HideAndSeekSprintRequest=sprintRemote,HideAndSeekActionRequest=actionRemote})[name] end
function rs:FindFirstChild(name) if name=="PlaygroundState"then return state end end
local uiGame = {}
function uiGame:GetService(name) return ({Players={LocalPlayer=player},ReplicatedStorage=rs,UserInputService=input,ContextActionService=context,GuiService={MenuIsOpen=false},RunService={Heartbeat=heartbeat.Event}})[name] end
local now = 100
local camera = {ViewportSize=Vector2.new(852,393)}
local uiWorkspace = {CurrentCamera=camera}
function uiWorkspace:GetServerTimeNow()return now end
local destroyed=signal()
local scriptMock={Parent=gui,Destroying=destroyed.Event}
local hudFactory = moduleFrom([==[return function(game,workspace,script)
HUDCONTROLLER
end]==],SecurityCapabilities.new(Enum.SecurityCapability.RunServerScript,Enum.SecurityCapability.AccessOutsideWrite,Enum.SecurityCapability.CreateInstances,Enum.SecurityCapability.Basic,Enum.SecurityCapability.Physics,Enum.SecurityCapability.UI,Enum.SecurityCapability.Input,Enum.SecurityCapability.RemoteEvent,Enum.SecurityCapability.Players,Enum.SecurityCapability.AvatarBehavior))
hudFactory(uiGame,uiWorkspace,scriptMock)
local function refresh()heartbeat:Fire(.2)task.wait()end
check(not gui.CompactHeader.Visible and not gui.MobileSprint.Visible,"School HUD stays out of the lobby")
hsState:SetAttribute("Phase","Hiding")
hsState:SetAttribute("HidingEndsAt",120)
hsState:SetAttribute("EndsAt",120)
hsState:SetAttribute("HiderCount",15)
hsState:SetAttribute("SeekerCount",1)
player:SetAttribute("HSParticipating",true)
refresh()
check(gui.CompactHeader.Visible and not gui.DesktopHeader.Visible,"Landscape phone receives compact header")
check(gui.CompactHeader.Timer.Text=="0:20","20-second hiding timer is displayed")
check(gui.CompactHeader.Counts.Text=="15 hiders • 1 seeker","Counts use singular and plural correctly")
check(gui.MobileSprint.Visible and not gui.DesktopSprint.Visible,"Phone uses the small right sprint button")
check(gui.MobileSprint.AnchorPoint==Vector2.new(1,1) and gui.MobileSprint.Position.X.Scale==1,"Phone sprint remains anchored on the right")
check(gui.MobileSprint.Size.X.Offset==100 and gui.MobileSprint.Size.Y.Offset==44,"Phone sprint preserves a practical touch target")
actions.HideAndSeekSprint(nil,Enum.UserInputState.Begin,{KeyCode=Enum.KeyCode.LeftShift})
check(requests[#requests]==true,"Keyboard sprint requests the server action")
actions.HideAndSeekSprint(nil,Enum.UserInputState.End,{KeyCode=Enum.KeyCode.LeftShift})
check(requests[#requests]==false,"Release stops sprinting")
player:SetAttribute("HSRole","Seeker")refresh()
check(not gui.MobileSprint.Active,"Seeker waits during the hiding period")
check(gui.SeekerBlindfold.Visible and gui.SeekerBlindfold.WaitingCard.Countdown.Text=="0:20","Seeker cannot watch hiders find their spots")
local session = Instance.new("Folder") session.Name,session.Parent = "PlaygroundSessionControls",fixture
session:SetAttribute("UIHidden",true)refresh()
check(gui.SeekerBlindfold.Visible,"Hide UI cannot remove the seeker blindfold")
session:SetAttribute("UIHidden",false)session:SetAttribute("SessionMenuOpen",true)refresh()
check(gui.SeekerBlindfold.Visible,"Settings cannot remove the seeker blindfold")
check(gui.SeekerBlindfold.Position==UDim2.fromOffset(-256,-256) and gui.SeekerBlindfold.Size==UDim2.new(1,512,1,512),"Blindfold covers all safe-area edges")
session:SetAttribute("SessionMenuOpen",false)refresh()
hsState:SetAttribute("Phase","Seeking") hsState:SetAttribute("EndsAt",280)refresh()
check(not gui.SeekerBlindfold.Visible,"Seeker view returns when searching starts")
check(gui.CompactHeader.Timer.Text=="3:00" and gui.MobileSprint.Active,"Three-minute search enables seeker sprint")
player:SetAttribute("HSHiding",true)refresh()
check(gui.LeaveLocker.Visible and not gui.MobileSprint.Active,"Locker hiding supplies a reliable exit button")
check(gui.LeaveLocker.Caption.Text=="LEAVE","Locker button displays the correct action")
actions.HideAndSeekLeaveLocker(nil,Enum.UserInputState.Begin)
check(exits[#exits]=="LeaveLocker","Exit action does not target other players")
player:SetAttribute("HSHiding",false)refresh()
camera.ViewportSize=Vector2.new(390,844)refresh()
check(gui.PortraitHeader.Visible and not gui.CompactHeader.Visible,"Portrait phone selects its authored header")
camera.ViewportSize=Vector2.new(1024,768)refresh()
check(gui.CompactHeader.Visible,"Tablet uses compact authored header")
camera.ViewportSize=Vector2.new(1920,1080)input.TouchEnabled=false refresh()
check(gui.DesktopHeader.Visible and gui.DesktopSprint.Visible,"Desktop selects desktop header and controls")
check(gui.DesktopHeader.Size==UDim2.fromOffset(340,94),"Runtime keeps the authored desktop geometry")
hsState:SetAttribute("Phase","Results")hsState:SetAttribute("WinnersText","Hiders win!")refresh()
check(not gui.MobileSprint.Visible and not gui.DesktopSprint.Visible,"Controls disappear during results")
check(gui.DesktopHeader.Hint.Text=="Hiders win!","Result message replaces instructions")
for _,viewport in {Vector2.new(568,320),Vector2.new(667,375),Vector2.new(852,393),Vector2.new(390,844),Vector2.new(375,667),Vector2.new(768,1024),Vector2.new(1024,768)}do
 local header = viewport.Y>viewport.X and gui.PortraitHeader or gui.CompactHeader
 check(header.Size.X.Offset<viewport.X-24 and header.Size.Y.Offset<viewport.Y*.25,"Header remains small and unclipped: "..tostring(viewport))
 local sprint = gui.MobileSprint
 local left=viewport.X+sprint.Position.X.Offset-sprint.Size.X.Offset
 local top=viewport.Y+sprint.Position.Y.Offset-sprint.Size.Y.Offset
 check(left>viewport.X*.5 and top>100,"Mobile sprint keeps the joystick and header clear: "..tostring(viewport))
end
destroyed:Fire()task.wait()
check(actions.HideAndSeekSprint==nil and actions.HideAndSeekLeaveLocker==nil,"Destroyed HUD removes its input bindings")
fixture:Destroy()
return {checks=checks,passed=true,livePlayersUnaffected=true,playStarted=false}
'''
fixture = fixture.replace('COORDINATOR',coord).replace('GUIBUILDER',gui_builder).replace('HUDCONTROLLER',controller)
(root / 'NativeIntegrationFixture.luau').write_text(fixture,encoding='utf-8')
print(json.dumps({'installer':len(install),'fixture':len(fixture)}))
