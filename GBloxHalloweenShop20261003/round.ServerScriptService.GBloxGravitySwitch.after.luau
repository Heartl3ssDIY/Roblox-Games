local Rules=require(game.ReplicatedStorage:WaitForChild("GBloxAbilityRules"))
local Platforms=require(script.Parent:WaitForChild("GBloxPlatBeGone"))
local Effects=require(script.Parent:WaitForChild("GBloxAbilityEffects"))
local Service={}
function Service.new(context)
 local cooldowns={}
 local roundUses={}
 local effects=Effects.new(context)
 local self={}
 function self.Activate(player)
  local now=context.Now()
  local actor=context.Runners[player]
  if context.Phase()~="Running" or not Rules.Eligible(actor) then return false,"Use your ability while racing." end
  local id=player:GetAttribute("GBloxEquippedAbility")
  local definition=Rules.Definitions[id]
  if not definition then return false,"Equip an available ability in the lobby." end
  if now<(cooldowns[player] or 0) then return false,definition.Name.." is cooling down.",cooldowns[player] end
  if definition.OncePerRound and roundUses[player]==context.RoundKey() then return false,"Already used this round." end
  if id=="Pumpkin" or id=="Web" then
   if not context.SeasonalActivate then return false,"Ability is not ready." end
   local ok,message,untilTime=context.SeasonalActivate(player,id)
   if not ok then return false,message,untilTime end
   cooldowns[player]=untilTime or now+definition.Cooldown
   player:SetAttribute("GBloxAbilityCooldownUntil",cooldowns[player])
   if context.OnUsed then context.OnUsed(player) end
   context.Announce(player.DisplayName.." used "..definition.Name.."!")
   return true,message,cooldowns[player]
  end
  local targets={}
  local platform
  if id=="GravitySwitch" or id=="Freeze" then
   for other,data in context.Runners do
    if other~=player and Rules.Eligible(data) then table.insert(targets,other) end
   end
   if #targets==0 and not context.Practice then return false,"No other active racers to affect." end
  elseif id=="PlatBeGone" then
   platform=Platforms.Find(context.Course(),actor.root.Position)
   if not platform then return false,"No available platform in the zone behind you." end
  end
  -- Reserve and apply without yielding, so racing requests cannot double-spend.
  local ok,message=context.Reserve(player,id)
  if not ok then return false,message end
  cooldowns[player]=now+definition.Cooldown
  player:SetAttribute("GBloxAbilityCooldownUntil",cooldowns[player])
  player:SetAttribute("GBloxAbilityActiveThisGame",true)
  if id=="PlatBeGone" then Platforms.Hide(platform,3)
  elseif id=="GravitySwitch" then for _,other in targets do context.Flip(other) end
  elseif id=="Freeze" then for _,other in targets do effects.Freeze(other,5) end
  elseif id=="Antispike" then effects.Antispike(player,7)
  elseif id=="Superspeed" then
   roundUses[player]=context.RoundKey()
   player:SetAttribute("GBloxAbilityUsedRound",context.RoundKey())
   effects.Superspeed(player,context.BoostSeconds)
  end
  if context.OnUsed then context.OnUsed(player) end
  context.Announce(player.DisplayName.." used "..definition.Name)
  return true,definition.Name.." used!",cooldowns[player]
 end
 function self.FreezeSeasonal(player,seconds) return effects.FreezeSeasonal(player,seconds) end
 function self.ClearSeasonalFreeze(player) effects.ClearSeasonalFreeze(player) end
 function self.Step() effects.Step() end
 function self.Remove(player) cooldowns[player]=nil roundUses[player]=nil effects.Remove(player) end
 return self
end
return Service



