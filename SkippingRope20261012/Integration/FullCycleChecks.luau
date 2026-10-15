assert(not game:GetService("RunService"):IsRunning(), "Edit only")
local checks = 0
local function check(value, name) assert(value, name) checks += 1 end
local fixture = Instance.new("Folder")
fixture.Name, fixture.Parent = "SkippingRopeFullCycleFixture", workspace
local moduleFolder = Instance.new("Folder")
moduleFolder.Name, moduleFolder.Parent = "SkippingRopeFullCycleModules", game.ServerStorage
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
 local started = admin:Handle(roster[1], "SKStart")
 check(started.ok and service.phase=="Countdown", "Admin dispatch starts actual rope service")
 check(prepared==4 and cancelled==4, "Bootstrap wrapper clears toys for each actual participant")
 for _, p in ipairs(roster) do
  check(not p.Character:FindFirstChildOfClass("Tool") and #p.backpack:GetChildren()==0 and #p.starterGear:GetChildren()==0, "All duplicate toy containers cleared")
  check(p.Character:FindFirstChild("KeepAvatarAccessory")~=nil, "Avatar accessories remain")
  check(not equipment:_toyAllowed(equipment.records[p]), "Toys blocked while jumping")
 end
 now=service.countdownEndsAt service:_tick()
 check(service.phase=="Playing" and service.endsAt-now==120, "Actual countdown enters 120-second game")
 local loser=roster[1]
 service:_hit(service.records[loser], 10, now+1)
 service:_hit(service.records[loser], 11, now+2)
 check(loser:GetAttribute("SKEliminated")==true and not loser:GetAttribute("SKParticipating"), "Real second hit enters spectator role")
 check(c:_participating(loser) and not equipment:_toyAllowed(equipment.records[loser]), "Eliminated players remain excluded from lobby gear and queue")
 now=service.endsAt service:_tick()
 c:_rewardSkippingRope()
 check(service.phase=="Results", "Actual clock finishes into Results")
 check(profiles[loser.UserId].data.Wins==0 and profiles[loser.UserId].data.Coins==50, "Out player earns participation only")
 for index=2,4 do check(profiles[roster[index].UserId].data.Wins==1 and profiles[roster[index].UserId].data.GameWins.SkippingRope==1 and profiles[roster[index].UserId].data.Coins==150, "Survivor receives game-specific win and reward") end
 c:_rewardSkippingRope()
 check(profiles[roster[2].UserId].data.Coins==150, "Repeated completion signal cannot duplicate actual awards")
 now=service.resultsEndsAt service:_tick()
 check(not service.active and not loser:GetAttribute("SKEliminated"), "Actual cleanup clears all round membership")
 c:_step(now)
 check(c.state:GetAttribute("Phase")=="Voting" and c.votingEndsAt==now+35, "Real completion returns to 35-second intermission")
 now=c.votingEndsAt c:_step(now)
 check(service.active and service.roundNumber==2, "Automatic next round enters same rope service")
 admin.lastRequest[roster[1]]=nil
 local stopped=admin:Handle(roster[1],"StopRound")
 check(stopped.ok and not service.active and state:GetAttribute("LastResultPractice"), "Admin stop cancels actual active game safely")
 check(profiles[roster[2].UserId].data.Coins==150, "Cancelled second game gives no extra reward")
 return {passed=true,checks=checks,scope="Live cloned service/coordinator/equipment/admin/economy through countdown, result, cleanup and next automatic round"}
end, debug.traceback)
pcall(function()if service then service:Stop() end end)
if equipment then equipment.running=false for _,r in pairs(equipment.records) do r.closed=true end end
fixture:Destroy() moduleFolder:Destroy()
assert(ok,result)
return result
