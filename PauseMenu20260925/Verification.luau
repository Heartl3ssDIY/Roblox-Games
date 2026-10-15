local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local player=Players.LocalPlayer
local pg=player:WaitForChild("PlayerGui")
local menu=require(RS.PauseMenu)
local clock=require(RS.MatchClock)
local settings=require(RS.MatchSettings)
local data=require(RS.PlayerData)
local function untilTrue(fn,limit)
 local deadline=os.clock()+limit
 repeat if fn() then return end task.wait(.05) until os.clock()>deadline
 error("Pause check timed out")
end
task.wait(3)
for _=1,4 do data.recordResult("Tenkaichi",true) end
local coins,gems=data.coins(),data.gems()
RS.ArenaEvents.EnterArena:Fire("Arena_Tenkaichi",false)
untilTrue(function() return pg.ArenaHUD.OptionRegion.Visible end,15)
assert(menu.open())
local timer=pg.ArenaHUD.OptionRegion.Timer.Text
local time=clock.now()
task.wait(1.2)
assert(clock.now()==time,"Pause clock advanced")
assert(pg.ArenaHUD.OptionRegion.Timer.Text==timer,"Draft timer advanced")
assert(player:GetAttribute("MatchPhase")=="Draft")
menu.settings()
assert(pg.ArenaHUD.PauseOverlay.Panel.Settings.Visible)
settings.setSounds(false)
for _,s in ipairs(game.SoundService.PackShopSounds:GetChildren()) do assert(s.Volume==0) end
settings.setSounds(true)
assert(game.SoundService.PackShopSounds.Click.Volume>0)
settings.setEffects(false);assert(not settings.effectsEnabled())
settings.setEffects(true)
menu.resume()
assert(not clock.isPaused())
task.wait(.1)
assert(clock.now()>time)
assert(menu.open())
menu.requestQuit()
assert(pg.ArenaHUD.PauseOverlay.Panel.Confirm.Visible)
menu.resume()
assert(data.arenaProgress("Tenkaichi").progressWins==4,"Cancel changed progress")
RS.ArenaEvents.LeaveArena:Fire()
task.wait(.1)
assert(clock.isPaused() and pg.ArenaHUD.Enabled,"Leave bypassed pause")
print("PAUSE_DRAFT_PASS: timers frozen, resume works, settings work, quit cancelled, direct lobby exit guarded")
local hook=Instance.new("BindableEvent")
hook.Name="PauseMenuCheck";hook.Parent=pg
hook.Event:Connect(function(action)
 if action=="forfeit" then
  menu.requestQuit()
  assert(menu.confirmQuit(),"Forfeit failed")
  assert(not menu.confirmQuit(),"Forfeit duplicated")
  assert(data.arenaProgress("Tenkaichi").progressWins==3)
  assert(data.arenaProgress("Tenkaichi").claimed[40])
  assert(data.coins()==coins and data.gems()==gems)
  assert(not pg.ArenaHUD.Enabled and not clock.isPaused())
  print("PAUSE_FORFEIT_PASS: one loss only, no rewards, earned milestone kept, lobby restored")
  RS.ArenaEvents.EnterArena:Fire("Arena_Tenkaichi",true)
  untilTrue(function() return player:GetAttribute("MatchPhase")=="Combat" end,30)
  assert(menu.open())
  local arena=workspace.Arena_Tenkaichi
  local attacks=arena:GetAttribute("CombatAttacks")
  local before={}
  for _,model in ipairs(arena.DeployedUnits:GetChildren()) do
   before[model]={health=model:GetAttribute("Health"),pivot=model:GetPivot()}
  end
  local combatTime=clock.now()
  task.wait(1.5)
  assert(clock.now()==combatTime)
  assert(arena:GetAttribute("CombatAttacks")==attacks)
  for model,v in pairs(before) do
   assert(model.Parent and model:GetAttribute("Health")==v.health and model:GetPivot()==v.pivot,"Combat continued while paused")
  end
  assert(player:GetAttribute("MatchPhase")=="Combat")
  menu.resume()
  untilTrue(function()
   return arena:GetAttribute("CombatAttacks")~=attacks or player:GetAttribute("MatchPhase")~="Combat"
  end,10)
  print("PAUSE_COMBAT_PASS: AI, health, movement and clock frozen; combat resumes")
  if menu.open() then
   menu.requestQuit();assert(menu.confirmQuit())
   assert(data.arenaProgress("Tenkaichi").progressWins==3,"Practice exit charged a loss")
   print("PAUSE_PRACTICE_PASS: practice exit has no progress penalty")
  end
 elseif action=="settings" then menu.settings()
 elseif action=="resume" then menu.resume()
 elseif action=="open" then menu.open()
 elseif action=="confirm" then menu.requestQuit()
 end
end)
