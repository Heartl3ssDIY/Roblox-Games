local Rules={}
Rules.Cooldown=20 -- Backward-compatible Gravity Switch default.
Rules.Definitions={GravitySwitch={Name="Gravity Switch",Cooldown=20},PlatBeGone={Name="Plat Be Gone",Cooldown=30,Duration=3},
 Freeze={Name="Freeze",Cooldown=30,Duration=5},
 Antispike={Name="Antispike",Cooldown=45,Duration=7},
 Superspeed={Name="Superspeed",Cooldown=0,OncePerRound=true}}
Rules.InitialUses=3
function Rules.Eligible(data)
 return data~=nil and data.status=="Running" and not data.recovering
  and data.root~=nil and data.root.Parent~=nil and not data.root.Anchored
  and data.humanoid~=nil and data.humanoid.Health>0
end
function Rules.Reserve(profile,matchId,id)
 local definition=Rules.Definitions[id]
 if not definition or profile.EquippedAbility~=id then return false,"Equip this ability in the lobby." end
 local a=profile.Abilities[id]
 if not a or a.Owned~=true then return false,"You don't own this ability." end
 local ticket=profile.AbilityGameTicket
 if typeof(ticket)=="table" and ticket.MatchId==matchId and ticket.AbilityId==id then return true,false end
 if typeof(a.Uses)~="number" or a.Uses<1 then return false,"Recharge this ability in the lobby." end
 -- Reserve one game use on first activation. The paid ticket permits unlimited
 -- activations in this same full match, still subject to its own cooldown.
 a.Uses=math.max(0,math.floor(a.Uses)-1)
 profile.AbilityGameTicket={MatchId=matchId,AbilityId=id}
 return true,true
end
return Rules

