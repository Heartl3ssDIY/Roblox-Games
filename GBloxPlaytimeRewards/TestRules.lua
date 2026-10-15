local Rules=require(game.ReplicatedStorage.GBloxPlaytimeRules)
local Http=game:GetService("HttpService")
local passed=0
local function check(value,label) assert(value,label) passed+=1 end
local function copy(t) return Http:JSONDecode(Http:JSONEncode(t)) end
local function profile()
 return {Cash=0,Trophies=0,TotalCashEarned=0,Pets={},EquippedAbility="Freeze",Abilities={Freeze={Owned=true,Uses=3}},PlaytimeRewards={Id="test",Started=1000,Claimed={}}}
end
for i,reward in Rules.Rewards do
 local p=profile()
 check(not Rules.Apply(p,1000+reward.Seconds-1,i),"early claim "..i)
 check(Rules.Apply(p,1000+reward.Seconds,i),"boundary claim "..i)
 local before=Http:JSONEncode(p)
 check(not Rules.Apply(p,1000+reward.Seconds,i),"duplicate rejected "..i)
 check(Http:JSONEncode(p)==before,"duplicate leaves balance unchanged "..i)
 if reward.Kind=="Cash" then check(p.Cash==reward.Amount and p.TotalCashEarned==reward.Amount,"cash exact "..i)
 elseif reward.Kind=="Trophies" then check(p.Trophies==reward.Amount,"trophies exact "..i)
 elseif reward.Kind=="Pet" then check(p.Pets.Horse==1,"horse exact "..i)
 else check(p.Abilities.Freeze.Uses==4,"equipped recharge "..i) end
end
local p=profile()
for _,bad in {0,13,1.5,"1",{},math.huge,0/0} do check(not Rules.Apply(p,10000,bad),"invalid index") end
p.EquippedAbility=""
check(not Rules.Apply(p,10000,8) and not p.PlaytimeRewards.Claimed["8"],"unequipped recharge stays claimable")
check(Rules.Apply(p,10000,9),"later cash not blocked by recharge")
p.EquippedAbility="Kong" p.Abilities.Kong={Owned=true,Uses=0}
check(not Rules.Apply(p,10000,8),"unavailable Kong cannot consume recharge")
p.EquippedAbility="Freeze"
check(Rules.Apply(p,10000,8),"recharge claim after equipping")
local full=profile()
for i=1,12 do check(Rules.Apply(full,10000,i),"whole track claim "..i) end
check(full.Cash==166000 and full.Trophies==35 and full.Pets.Horse==2 and full.Abilities.Freeze.Uses==5,"whole track totals")
check(not Rules.Apply(full,100000,1),"track does not loop")
local raw=copy(full.PlaytimeRewards)
raw.Handoff={Token="secret-test",From=74498603638770,To=106769122906103,Expires=10180}
local join={SourcePlaceId=74498603638770,SourceGameId=77,TeleportData={GBloxPlaytimeTickets={["123"]="secret-test"}}}
local arrival,resumed=Rules.Arrive(raw,10030,join,123,106769122906103,77,"new")
check(resumed and arrival.Started==1000 and arrival.Id=="test","internal handoff keeps start")
check(arrival.Claimed["1"] and arrival.Claimed["12"] and not arrival.Handoff,"internal handoff keeps receipts and consumes nonce")
check(Rules.Status(arrival,10040).Elapsed==9040,"travel time counted")
local function resetTest(old,data,user,place,universe,time,label)
 local a,valid=Rules.Arrive(old,time or 10030,data,user or 123,place or 106769122906103,universe or 77,"fresh")
 check(not valid and a.Id=="fresh" and a.Started==(time or 10030) and not a.Claimed["1"],label)
end
resetTest(arrival,join,nil,nil,nil,nil,"consumed nonce cannot replay")
resetTest(raw,{},nil,nil,nil,nil,"ordinary rejoin resets")
resetTest(raw,join,999,nil,nil,nil,"wrong player cannot resume")
resetTest(raw,join,nil,74498603638770,nil,nil,"wrong destination cannot resume")
resetTest(raw,join,nil,nil,88,nil,"different universe cannot resume")
resetTest(raw,join,nil,nil,nil,10181,"expired handoff resets")
local fake=copy(join) fake.TeleportData.GBloxPlaytimeTickets["123"]="forged"
resetTest(raw,fake,nil,nil,nil,nil,"forged nonce resets")
fake=copy(join) fake.SourcePlaceId=1
resetTest(raw,fake,nil,nil,nil,nil,"tutorial or other source excluded")
raw.Handoff.From=106769122906103 raw.Handoff.To=74498603638770
join.SourcePlaceId=106769122906103
local returned,valid=Rules.Arrive(raw,10040,join,123,74498603638770,77,"fresh")
check(valid and returned.Claimed["12"] and returned.Started==1000,"return lobby preserves track")
local transferring=profile() transferring.PlaytimeRewards.Handoff=raw.Handoff
check(not Rules.Apply(transferring,10000,1),"claims blocked during handoff")
local sanitized=Rules.Sanitize(raw)
sanitized.Claimed["1"]=false
check(raw.Claimed["1"]==true,"save snapshots do not share receipts")
return string.format("%d isolated rules checks passed; no real player profile or DataStore was modified.",passed)
