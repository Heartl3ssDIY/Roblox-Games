-- Server time and persisted receipts are authoritative. Teleports carry ONLY a nonce.
local Rules={}
Rules.Places={[74498603638770]=true,[106769122906103]=true}
Rules.Rewards={
 {Seconds=300,Kind="Cash",Amount=1000,Label="1,000 Cash"},
 {Seconds=600,Kind="Trophies",Amount=10,Label="10 Trophies"},
 {Seconds=900,Kind="Pet",Id="Horse",Label="Horse"},
 {Seconds=1500,Kind="Cash",Amount=5000,Label="5,000 Cash"},
 {Seconds=1800,Kind="Trophies",Amount=25,Label="25 Trophies"},
 {Seconds=2700,Kind="Pet",Id="Horse",Label="Horse"},
 {Seconds=3600,Kind="Cash",Amount=10000,Label="10,000 Cash"},
 {Seconds=4200,Kind="Recharge",Amount=1,Label="+1 equipped ability recharge"},
 {Seconds=4800,Kind="Cash",Amount=25000,Label="25,000 Cash"},
 {Seconds=5400,Kind="Cash",Amount=50000,Label="50,000 Cash"},
 {Seconds=6300,Kind="Recharge",Amount=1,Label="+1 equipped ability recharge"},
 {Seconds=7200,Kind="Cash",Amount=75000,Label="75,000 Cash"},
}
local abilities={GravitySwitch=true,PlatBeGone=true,Freeze=true,Antispike=true,Superspeed=true}
local function integer(v,default)
 return typeof(v)=="number" and v==v and math.abs(v)<math.huge and math.floor(v) or default
end
function Rules.Sanitize(raw)
 raw=typeof(raw)=="table" and raw or {}
 local s={Id=typeof(raw.Id)=="string" and raw.Id or "",Started=math.max(0,integer(raw.Started,0)),Claimed={}}
 for i=1,#Rules.Rewards do s.Claimed[tostring(i)]=typeof(raw.Claimed)=="table" and raw.Claimed[tostring(i)]==true or false end
 local h=raw.Handoff
 if typeof(h)=="table" and typeof(h.Token)=="string" then
  s.Handoff={Token=h.Token,From=integer(h.From,0),To=integer(h.To,0),Expires=integer(h.Expires,0)}
 end
 return s
end
function Rules.Arrive(raw,now,join,userId,placeId,gameId,newId)
 local s=Rules.Sanitize(raw)
 join=typeof(join)=="table" and join or {}
 local data=typeof(join.TeleportData)=="table" and join.TeleportData or {}
 local tokens=typeof(data.GBloxPlaytimeTickets)=="table" and data.GBloxPlaytimeTickets or {}
 local h=s.Handoff
 local valid=h and s.Id~="" and s.Started>0 and s.Started<=now
  and Rules.Places[placeId] and Rules.Places[join.SourcePlaceId]
  and join.SourceGameId==gameId and h.From==join.SourcePlaceId and h.To==placeId
  and now<=h.Expires and tokens[tostring(userId)]==h.Token
 if not valid then s={Id=newId,Started=now,Claimed={}} end
 -- Consumed in the same UpdateAsync that acquires the destination profile lease.
 s.Handoff=nil
 return s,valid==true
end
function Rules.Status(raw,now)
 local s=Rules.Sanitize(raw)
 return {Started=s.Started,Elapsed=math.max(0,now-s.Started),ServerNow=now,Claimed=s.Claimed,Transferring=s.Handoff~=nil}
end
function Rules.Apply(profile,now,index)
 if typeof(index)~="number" or index%1~=0 or not Rules.Rewards[index] then return false,"Unknown reward." end
 local s=Rules.Sanitize(profile.PlaytimeRewards)
 if s.Id=="" or s.Started<=0 then return false,"Your playtime is still loading." end
 if s.Handoff then return false,"Please finish travelling before claiming." end
 local key=tostring(index)
 if s.Claimed[key] then return false,"Already claimed this session." end
 local reward=Rules.Rewards[index]
 if now-s.Started<reward.Seconds then return false,"Keep playing to unlock this reward." end
 if reward.Kind=="Recharge" then
  local id=profile.EquippedAbility
  local ability=abilities[id or ""] and profile.Abilities[id]
  if not ability or ability.Owned~=true then return false,"Equip an owned ability in Inventory, then claim this recharge." end
  ability.Uses=math.max(0,integer(ability.Uses,0))+1
 elseif reward.Kind=="Pet" then
  profile.Pets[reward.Id]=(profile.Pets[reward.Id] or 0)+1
 else
  profile[reward.Kind]=(profile[reward.Kind] or 0)+reward.Amount
  if reward.Kind=="Cash" then profile.TotalCashEarned=(profile.TotalCashEarned or 0)+reward.Amount end
 end
 -- Receipt and reward are part of ONE profile, changed together before yielding.
 s.Claimed[key]=true profile.PlaytimeRewards=s
 return true,reward.Label.." claimed!"
end
return Rules
