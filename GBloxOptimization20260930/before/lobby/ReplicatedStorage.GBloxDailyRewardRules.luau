-- Server-owned calendar and rewards. No client timestamp, reward amount or day is accepted.
local Rules={}
Rules.Rewards={
 {Kind="Cash",Amount=5000,Label="5,000 Cash"},
 {Kind="Trophies",Amount=50,Label="50 Trophies"},
 {Kind="Pet",Id="Horse",Label="Horse"},
 {Kind="Cash",Amount=10000,Label="10,000 Cash"},
 {Kind="Recharge",Amount=1,Label="+1 equipped ability recharge"},
 {Kind="Cash",Amount=25000,Label="25,000 Cash"},
 {Kind="Pet",Id="Eagle",Label="Eagle"},
}
Rules.Abilities={GravitySwitch=true,PlatBeGone=true,Kong=true,Freeze=true,Antispike=true,Superspeed=true}
local function integer(v,default)
 return typeof(v)=="number" and v==v and math.abs(v)<math.huge and math.floor(v) or default
end
function Rules.ValidOffset(v)
 return typeof(v)=="number" and v==v and v>=-720 and v<=840 and v%15==0
end
function Rules.Sanitize(raw)
 raw=typeof(raw)=="table" and raw or {}
 return {
  Claimed=math.clamp(integer(raw.Claimed,0),0,7),
  LastClaimDay=integer(raw.LastClaimDay,-1),
  LastLoginDay=integer(raw.LastLoginDay,-1),
  OffsetMinutes=Rules.ValidOffset(raw.OffsetMinutes) and raw.OffsetMinutes or 0,
 }
end
function Rules.Day(timestamp,offset)
 return math.floor((timestamp+offset*60)/86400)
end
function Rules.Touch(raw,day,offset)
 local state=Rules.Sanitize(raw)
 if state.LastLoginDay>=0 and day>state.LastLoginDay+1 then state.Claimed=0 end
 if state.Claimed==7 and day>state.LastClaimDay then state.Claimed=0 end
 state.LastLoginDay=math.max(state.LastLoginDay,day)
 state.OffsetMinutes=offset
 return state
end
function Rules.Status(raw,timestamp,offset)
 local day=Rules.Day(timestamp,offset)
 local state=Rules.Touch(raw,day,offset)
 return {
  Claimed=state.Claimed,NextDay=math.min(state.Claimed+1,7),
  CanClaim=day>state.LastClaimDay and state.Claimed<7,
  NextReset=(day+1)*86400-offset*60,LocalDay=day,
 },state
end
function Rules.Apply(profile,timestamp,offset)
 local status,state=Rules.Status(profile.DailyRewards,timestamp,offset)
 profile.DailyRewards=state
 if not status.CanClaim then return false,"Today's reward is already claimed." end
 local reward=Rules.Rewards[status.NextDay]
 if reward.Kind=="Recharge" then
  local id=profile.EquippedAbility
  local ability=Rules.Abilities[id or ""] and profile.Abilities[id]
  if not ability or not ability.Owned then return false,"Equip an owned ability in Inventory, then claim Day 5." end
  ability.Uses=math.max(0,integer(ability.Uses,0))+1
 elseif reward.Kind=="Pet" then
  profile.Pets[reward.Id]=(profile.Pets[reward.Id] or 0)+1
 else
  profile[reward.Kind]=(profile[reward.Kind] or 0)+reward.Amount
  if reward.Kind=="Cash" then profile.TotalCashEarned=(profile.TotalCashEarned or 0)+reward.Amount end
 end
 -- Receipt and reward are changed together, before any yielding save.
 state.Claimed=status.NextDay
 state.LastClaimDay=status.LocalDay
 return true,reward.Label.." claimed!"
end
return Rules

