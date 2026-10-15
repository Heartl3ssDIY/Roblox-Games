assert(not game:GetService("RunService"):IsRunning(), "Edit only")
local checks = 0
local function check(value, name) assert(value, name) checks += 1 end
local fixture = Instance.new("Folder")
fixture.Name, fixture.Parent = "SkippingRopeSoloAdminFixture", workspace
local moduleFolder = Instance.new("Folder")
moduleFolder.Name, moduleFolder.Parent = "SkippingRopeSoloAdminModules", game.ServerStorage
local now, roster = 100, {}
local function signal()
 return { Connect = function() return { Disconnect = function() end } end }
end
local players = { PlayerAdded = signal(), PlayerRemoving = signal() }
function players:GetPlayers() return roster end
function players:GetPlayerByUserId(id) for _, p in ipairs(roster) do if p.UserId == id then return p end end end
local env = { game = { GetService = function(_, name) return name == "Players" and players or game:GetService(name) end },
 workspace = { GetServerTimeNow = function() return now end } }
local function loadFresh(name)
 local m = game.ServerScriptService[name]:Clone()
 m.Name = "Fixture" .. name
 m.Source = "return function(env)\nlocal game=env.game\nlocal workspace=env.workspace\n" .. m.Source .. "\nend"
 m.Parent = moduleFolder
 return require(m)(env)
end
local service, equipment
local ok, result = xpcall(function()
 local Rope, Coordinator, Equipment, Economy, Admin = loadFresh("SkippingRopeService"), loadFresh("PlaygroundCoordinator"), loadFresh("PlaygroundEquipmentService"), loadFresh("PlaygroundEconomyService"), loadFresh("PlaygroundAdminService")
 local arena = Instance.new("Folder")
 arena.Name, arena.Parent = "Arena", fixture
 local gameplay = workspace["Skipping Rope"].Gameplay:Clone()
 gameplay.Parent = arena
 for _, part in ipairs(gameplay:GetDescendants()) do
  if part:IsA("BasePart") then part.CFrame += Vector3.new(0, 1000, -30000) part.CanCollide, part.CanTouch, part.CanQuery = false, false, false end
 end
 local state = Instance.new("Folder") state.Parent = fixture
 local lobbySpawn = Instance.new("Part") lobbySpawn.Anchored = true lobbySpawn.CFrame = CFrame.new(-30000, 1000, -30000) lobbySpawn.Parent = fixture
 service = Rope.new(arena, state)
 service.lobbySpawn = lobbySpawn
 service.running = true
 service:_phase("Waiting")
 local prepared, cancelled = 0, 0
 local toys = { CanHold = function() return true end, CancelAction = function() cancelled += 1 end, ClearPlayer = function() prepared += 1 end }
 equipment = setmetatable({ records = {}, running = false, toys = toys }, Equipment)
 local profiles = {}
 for index = 1, 4 do
  local p = { UserId = 992000 + index, Name = "Fixture" .. index, DisplayName = "Fixture " .. index, Parent = players,
   CharacterAdded = signal(), CharacterRemoving = signal(), attributes = { PCDataReady = true } }
  function p:GetAttribute(name) return self.attributes[name] end
  function p:SetAttribute(name, value) self.attributes[name] = value end
  function p:FindFirstChildOfClass(name) return name == "Backpack" and self.backpack or nil end
  function p:FindFirstChild(name) return name == "StarterGear" and self.starterGear or nil end
  local character = Instance.new("Model") character.Name, character.Parent = p.Name, fixture
  local root = Instance.new("Part") root.Name, root.Size, root.Anchored, root.CanCollide = "HumanoidRootPart", Vector3.new(2,2,1), true, false root.Parent = character
  local head = Instance.new("Part") head.Name, head.Size, head.Anchored, head.CanCollide = "Head", Vector3.new(2,1,1), true, false head.Position = Vector3.new(0,2,0) head.Parent = character
  local humanoid = Instance.new("Humanoid") humanoid.RequiresNeck, humanoid.BreakJointsOnDeath = false, false humanoid.Parent = character
  p.Character = character
  p.backpack, p.starterGear = Instance.new("Folder"), Instance.new("Folder") p.backpack.Parent, p.starterGear.Parent = fixture, fixture
  for _, container in ipairs({character, p.backpack, p.starterGear}) do
   local tool = Instance.new("Tool") tool.Name = "FixtureToy" tool:SetAttribute("PCToy", true) tool.Parent = container
  end
  local accessory = Instance.new("Accessory") accessory.Name, accessory.Parent = "KeepAvatarAccessory", character
  local audio = Instance.new("AudioEmitter") audio.Parent = character
  table.insert(roster, p)
  local record = {player=p, connections={}, characterConnections={}, ready=false, inRound=false, participating=false}
  service.records[p] = record service:_bindCharacter(record, character)
  equipment.records[p] = { player=p, character=character, gearConnections={}, prepareSerial=0 }
  profiles[p.UserId] = {ready=true, data={Coins=0, XP=0, Wins=0, GameWins={SkippingRope=0}}}
 end
 local economy = setmetatable({awarded={}}, Economy)
 function economy:_profileByUserId(id) return profiles[id] end
 function economy:_setting(_, fallback) return fallback end
 function economy:_earnedCoins(_, amount) return amount end
 function economy:_earnedXP(_, amount) return amount end
 function economy:_touch() end
 function economy:_publishReward() end
 local c = setmetatable({services={SkippingRope=service}, lobby={Gameplay={FindFirstChild=function()return nil end}}, state=Instance.new("Folder"),
  votes={}, lastVote={}, spectators={}, lastSessionRequest={}, lastSpectateStamp={}, lastSpectateRequest={}, autoEnabled=true, votingEndsAt=0, startRetryAt=0, random=Random.new(1), economy=economy}, Coordinator)
 c.state.Parent = fixture
 local original = service._begin
 service._begin = function(instance, selected, ...)
  equipment:PrepareRound(selected)
  return original(instance, selected, ...)
 end
 local config = Instance.new("Folder") config:SetAttribute("AdminUserId", roster[1].UserId) config.Parent = fixture
 local admin = Admin.new(c, config, true, players)
 -- Status uses profile UI fields unrelated to this integration fixture.
 admin.Status = function(_, _, accepted, message) return {ok=accepted, message=message} end
 local denied = admin:Handle(roster[2], "SKSolo")
 check(not denied.ok and not service.active, "Non-admin cannot start solo practice")
 local started = admin:Handle(roster[1], "SKSolo")
 check(started.ok and service.phase=="Countdown" and service.mode=="Practice", "Owner solo admin command routes through actual coordinator")
 check(state:GetAttribute("ParticipantCount")==1 and roster[1]:GetAttribute("SKParticipating")==true, "Only requesting owner joins solo")
 check(not roster[2]:GetAttribute("SKParticipating") and not roster[3]:GetAttribute("SKParticipating"), "Other ready players stay in lobby")
 check(prepared==1 and cancelled==1, "Bootstrap wrapper clears only solo participant toys")
 local p=roster[1]
 check(not p.Character:FindFirstChildOfClass("Tool") and #p.backpack:GetChildren()==0 and #p.starterGear:GetChildren()==0, "Solo duplicate toy containers cleared")
 check(p.Character:FindFirstChild("KeepAvatarAccessory")~=nil and p.Character:FindFirstChildOfClass("AudioEmitter")~=nil, "Solo preserves avatar appearance and audio")
 check(not equipment:_toyAllowed(equipment.records[p]), "Toys blocked while practicing")
 now=service.countdownEndsAt service:_tick()
 check(service.phase=="Playing" and service.endsAt-now==120, "Solo countdown enters full 120-second game with one player")
 now=service.endsAt service:_tick()
 c:_rewardSkippingRope()
 check(service.phase=="Results" and p:GetAttribute("SKResult")=="Won" and state:GetAttribute("LastResultPractice")==true, "Solo success produces practice result")
 for _, player in ipairs(roster) do
  local data=profiles[player.UserId].data
  check(data.Coins==0 and data.XP==0 and data.Wins==0 and data.GameWins.SkippingRope==0, "Actual economy gives no coins XP or wins for solo")
 end
 c:_rewardSkippingRope()
 check(profiles[p.UserId].data.Coins==0, "Repeated practice result never grants rewards")
 now=service.resultsEndsAt service:_tick()
 check(not service.active and not p:GetAttribute("SKParticipating"), "Solo cleanup clears participation")
 admin.lastRequest[p]=nil
 local again=admin:Handle(p,"SKSolo")
 check(again.ok and service.mode=="Practice", "Owner can start another solo after cleanup")
 now=service.countdownEndsAt service:_tick()
 service:_hit(service.records[p],10,now+1)
 service:_hit(service.records[p],11,now+2)
 service:_tick()
 c:_rewardSkippingRope()
 check(service.phase=="Results" and p:GetAttribute("SKEliminated") and state:GetAttribute("LastResultPractice"), "Solo two-hit elimination also excludes rewards")
 check(profiles[p.UserId].data.Coins==0 and profiles[p.UserId].data.XP==0 and profiles[p.UserId].data.Wins==0, "Failed solo grants no participation reward")
 admin.lastRequest[p]=nil
 local stopped=admin:Handle(p,"StopRound")
 check(stopped.ok and not service.active, "Admin can stop solo practice safely")
 return {passed=true,checks=checks,scope="Actual SKSolo owner/unauthorized admin dispatch through coordinator, equipment, countdown, results, and economy"}

end, debug.traceback)
pcall(function()if service then service:Stop() end end)
if equipment then equipment.running=false for _,r in pairs(equipment.records) do r.closed=true end end
fixture:Destroy() moduleFolder:Destroy()
assert(ok,result)
return result

