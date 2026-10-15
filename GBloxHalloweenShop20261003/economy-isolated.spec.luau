local settingsAttributes={}
local settings={GetAttribute=function(_,name) return settingsAttributes[name] end}
local storage={FindFirstChild=function(_,name) return name=="GBloxHalloweenSettings" and settings or nil end}
local game={GetService=function(_,name) assert(name=="ReplicatedStorage"); return storage end}
local Rules=(function()
local Rules={}
Rules.Cooldown=20
Rules.Definitions={
 GravitySwitch={Name="Gravity Switch",Cooldown=20,Price=300000},
 PlatBeGone={Name="Plat Be Gone",Cooldown=30,Duration=3,Price=100000},
 Freeze={Name="Freeze",Cooldown=30,Duration=5,Price=200000},
 Antispike={Name="Antispike",Cooldown=45,Duration=7,Price=400000},
 Superspeed={Name="Superspeed",Cooldown=0,OncePerRound=true,Price=500000},
 Pumpkin={Name="Pumpkin",Cooldown=25,Duration=4,Price=150000,RechargePrice=15000,Seasonal=true},
 Web={Name="Web",Cooldown=30,Duration=5,Price=350000,RechargePrice=35000,Seasonal=true},
}
Rules.InitialUses=3
Rules.RechargeUses=1
Rules.UnlimitedFromUnix=1790812800
Rules.UnlimitedUntilUnix=1793491200
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local function finite(value)
 return typeof(value)=="number" and value==value and math.abs(value)<math.huge
end
local function setting(name,default)
 local settings=ReplicatedStorage:FindFirstChild("GBloxHalloweenSettings")
 local value=settings and settings:GetAttribute(name)
 return finite(value) and math.max(0,math.floor(value)) or default
end
function Rules.IsUnlimited(id,now)
 local definition=Rules.Definitions[id]
 if not definition or not definition.Seasonal then return false end
 now=finite(now) and now or os.time()
 return now>=setting("UnlimitedFromUnix",Rules.UnlimitedFromUnix)
  and now<setting("UnlimitedUntilUnix",Rules.UnlimitedUntilUnix)
end
function Rules.GetPurchase(id)
 local definition=Rules.Definitions[id]
 if not definition then return nil end
 local price=definition.Seasonal and setting(id.."Price",definition.Price) or definition.Price
 local recharge=definition.Seasonal and setting(id.."RechargePrice",definition.RechargePrice) or math.floor(price*.1)
 return {Price=price,RechargePrice=recharge,InitialUses=Rules.InitialUses,RechargeUses=Rules.RechargeUses}
end
function Rules.NormalizeAbilities(raw)
 local abilities=typeof(raw)=="table" and table.clone(raw) or {}
 for id in Rules.Definitions do
  local previous=typeof(abilities[id])=="table" and abilities[id] or {}
  local owned=previous.Owned==true
  abilities[id]={Owned=owned,Uses=owned and finite(previous.Uses) and math.max(0,math.floor(previous.Uses)) or 0}
 end
 return abilities
end
function Rules.Buy(profile,id,now)
 local purchase=Rules.GetPurchase(id)
 if not purchase then return false,"Unknown ability." end
 local a=profile.Abilities[id]
 local owned=typeof(a)=="table" and a.Owned==true
 if owned and Rules.IsUnlimited(id,now) then return false,"Unlimited Halloween uses are already included." end
 if owned and finite(a.Uses) and a.Uses>0 then return false,"You still have uses remaining." end
 local cost=owned and purchase.RechargePrice or purchase.Price
 if not finite(profile.Cash) or profile.Cash<cost then return false,"Not enough cash." end
 profile.Cash-=cost
 profile.Abilities[id]={Owned=true,Uses=owned and purchase.RechargeUses or purchase.InitialUses}
 local message=owned and "Refilled: 1 game." or Rules.IsUnlimited(id,now)
  and "Unlocked: unlimited Halloween uses; 3 games kept for afterwards." or "Unlocked: 3 games."
 return true,message
end
function Rules.Eligible(data)
 return data~=nil and data.status=="Running" and not data.recovering
  and data.root~=nil and data.root.Parent~=nil and not data.root.Anchored
  and data.humanoid~=nil and data.humanoid.Health>0
end
function Rules.Reserve(profile,matchId,id,now)
 local definition=Rules.Definitions[id]
 if not definition or not profile or profile.EquippedAbility~=id then return false,"Equip this ability in the lobby." end
 local a=typeof(profile.Abilities)=="table" and profile.Abilities[id]
 if typeof(a)~="table" or a.Owned~=true then return false,"You don't own this ability." end
 if Rules.IsUnlimited(id,now) then return true,false end
 local ticket=profile.AbilityGameTicket
 if typeof(ticket)=="table" and ticket.MatchId==matchId and ticket.AbilityId==id then return true,false end
 if not finite(a.Uses) or a.Uses<1 then return false,"Recharge this ability in the lobby." end
 a.Uses=math.max(0,math.floor(a.Uses)-1)
 profile.AbilityGameTicket={MatchId=matchId,AbilityId=id}
 return true,true
end
return Rules


end)()
local count=0
local function check(value,message) count+=1; assert(value,message) end
local function same(actual,expected,message) check(actual==expected,message.." expected "..tostring(expected)..", got "..tostring(actual)) end
local function profile(id,uses,cash)
 return {Cash=cash or 1000000,EquippedAbility=id,Abilities=Rules.NormalizeAbilities({[id]={Owned=true,Uses=uses or 0}})}
end
local startAt,endAt=1790812800,1793491200
same(Rules.Definitions.Pumpkin.Cooldown,25,"Pumpkin cooldown")
same(Rules.Definitions.Pumpkin.Duration,4,"Pumpkin splat duration")
same(Rules.Definitions.Web.Cooldown,30,"Web cooldown")
same(Rules.Definitions.Web.Duration,5,"Web hold duration")
same(Rules.GetPurchase("Pumpkin").Price,150000,"Pumpkin initial cost")
same(Rules.GetPurchase("Pumpkin").RechargePrice,15000,"Pumpkin recharge")
same(Rules.GetPurchase("Web").Price,350000,"Web initial cost")
same(Rules.GetPurchase("Web").RechargePrice,35000,"Web recharge")
same(Rules.GetPurchase("Web").InitialUses,3,"Initial game uses")
same(Rules.GetPurchase("Web").RechargeUses,1,"Existing cash recharge game use")
same(Rules.GetPurchase("Kong"),nil,"Kong remains unavailable")
same(Rules.GetPurchase("Unknown"),nil,"Unknown item rejected")
local prices={GravitySwitch=300000,PlatBeGone=100000,Freeze=200000,Antispike=400000,Superspeed=500000}
for id,price in prices do
 same(Rules.GetPurchase(id).Price,price,"Existing ability initial price")
 same(Rules.GetPurchase(id).RechargePrice,price*.1,"Existing cash recharge unchanged")
 check(not Rules.IsUnlimited(id,startAt),"Existing abilities not seasonal")
end
check(not Rules.IsUnlimited("Pumpkin",startAt-1),"Not unlimited before window")
check(Rules.IsUnlimited("Pumpkin",startAt),"Start inclusive")
check(Rules.IsUnlimited("Web",endAt-1),"End last second included")
check(not Rules.IsUnlimited("Web",endAt),"End exclusive")
check(not Rules.IsUnlimited("Web",endAt+1),"No unlimited after cutoff")
check(not Rules.IsUnlimited("Unknown",startAt),"Unknown not unlimited")
local legacy={Cash=9901,Abilities={Freeze={Owned=true,Uses=2},Kong={Owned=true,Uses=4},Pumpkin={Owned=true,Uses=2.7}}}
local normalized=Rules.NormalizeAbilities(legacy.Abilities)
same(legacy.Cash,9901,"Migration preserves cash")
same(normalized.Freeze.Uses,2,"Migration preserves existing uses")
check(normalized.Freeze.Owned,"Migration preserves ownership")
same(normalized.Kong.Uses,4,"Unrelated unavailable inventory preserved")
same(normalized.Pumpkin.Uses,2,"New ability uses normalize")
check(not normalized.Web.Owned,"No free Web migration")
same(normalized.Web.Uses,0,"Unowned has no charges")
normalized.Freeze.Uses=1
same(legacy.Abilities.Freeze.Uses,2,"Normalization doesn't mutate old entry")
local malformed=Rules.NormalizeAbilities({Pumpkin={Owned=true,Uses=0/0},Web={Owned=false,Uses=9000}})
same(malformed.Pumpkin.Uses,0,"NaN charge rejected")
same(malformed.Web.Uses,0,"Unowned charge removed")
same(Rules.NormalizeAbilities(false).Pumpkin.Uses,0,"Non-table old profile accepted")
for _,id in {"Pumpkin","Web"} do
 local p=profile(id,0)
 local beforeCash=p.Cash
 local bought,msg=Rules.Buy(p,id,startAt)
 check(not bought,"No redundant seasonal recharge")
 same(p.Cash,beforeCash,"Redundant recharge doesn't charge")
 same(p.Abilities[id].Uses,0,"Redundant recharge doesn't modify charges")
 p=profile(id,0); p.Abilities[id].Owned=false
 bought,msg=Rules.Buy(p,id,startAt)
 check(bought,"Seasonal purchase succeeds")
 same(p.Cash,1000000-Rules.GetPurchase(id).Price,"Authoritative purchase cost deducted once")
 same(p.Abilities[id].Uses,3,"Purchase stores post-season game uses")
 check(p.Abilities[id].Owned,"Purchase grants ownership")
 check(msg:find("unlimited",1,true)~=nil,"Purchase explains unlimited")
 local before=p.Cash
 bought=Rules.Buy(p,id,startAt+1)
 check(not bought,"Cannot buy seasonal item twice")
 same(p.Cash,before,"Duplicate purchase does not deduct")
 for n=1,20 do
  local ok,new=Rules.Reserve(p,"free-"..n,id,endAt-1)
  check(ok,"Owned equipped seasonal ability allowed")
  check(not new,"Seasonal activation creates no paid ticket")
 end
 same(p.Abilities[id].Uses,3,"Seasonal matches don't consume uses")
 same(p.AbilityGameTicket,nil,"Seasonal activation doesn't create persistent free ticket")
 local ok,new=Rules.Reserve(p,"free-20",id,endAt)
 check(ok and new,"Same free match crosses boundary and now reserves game")
 same(p.Abilities[id].Uses,2,"Exactly one use consumed at cutoff")
 ok,new=Rules.Reserve(p,"free-20",id,endAt+1)
 check(ok and not new,"Same match doesn't consume twice")
 same(p.Abilities[id].Uses,2,"Ticket protects repeated activation")
 ok,new=Rules.Reserve(p,"paid-21",id,endAt+2)
 check(ok and new,"Next match consumes new game charge")
 same(p.Abilities[id].Uses,1,"Next match decrements once")
 Rules.Reserve(p,"paid-22",id,endAt+3)
 same(p.Abilities[id].Uses,0,"Three stored games available")
 ok=Rules.Reserve(p,"paid-23",id,endAt+4)
 check(not ok,"No post-season use without cash recharge")
 before=p.Cash
 bought=Rules.Buy(p,id,endAt+5)
 check(bought,"Post-season recharge succeeds")
 same(p.Cash,before-Rules.GetPurchase(id).RechargePrice,"Recharge costs 10%")
 same(p.Abilities[id].Uses,1,"Cash recharge grants existing one-game amount")
 bought=Rules.Buy(p,id,endAt+6)
 check(not bought,"Unused recharge cannot be repurchased")
end
local p=profile("Pumpkin",0)
p.Abilities.Pumpkin.Owned=false
check(not Rules.Reserve(p,"match","Pumpkin",startAt),"Season window doesn't bypass ownership")
p=profile("Pumpkin",3)
p.EquippedAbility="Web"
check(not Rules.Reserve(p,"match","Pumpkin",startAt),"Season window doesn't bypass equipped slot")
check(not Rules.Reserve(nil,"match","Pumpkin",startAt),"Missing profile rejected")
p=profile("Pumpkin",0)
local before=p.Cash
check(not Rules.Buy(p,"bad",endAt),"Unknown purchase rejected")
same(p.Cash,before,"Unknown purchase preserves cash")
p=profile("Pumpkin",0,149999)
p.Abilities.Pumpkin.Owned=false
check(not Rules.Buy(p,"Pumpkin",startAt),"Insufficient purchase funds rejected")
same(p.Cash,149999,"Insufficient purchase preserves cash")
settingsAttributes.PumpkinPrice=180000
settingsAttributes.PumpkinRechargePrice=18000
same(Rules.GetPurchase("Pumpkin").Price,180000,"Config purchase price used")
same(Rules.GetPurchase("Pumpkin").RechargePrice,18000,"Config recharge price used")
settingsAttributes.PumpkinPrice=0/0
same(Rules.GetPurchase("Pumpkin").Price,150000,"Invalid config falls back")
settingsAttributes.UnlimitedFromUnix=startAt+10
settingsAttributes.UnlimitedUntilUnix=startAt+20
check(not Rules.IsUnlimited("Web",startAt+9),"Configured start respected")
check(Rules.IsUnlimited("Web",startAt+10),"Configured start inclusive")
check(not Rules.IsUnlimited("Web",startAt+20),"Configured end exclusive")
local actor={status="Running",root={Parent=true,Anchored=false},humanoid={Health=100}}
check(Rules.Eligible(actor),"Live race actor eligible")
actor.recovering=true
check(not Rules.Eligible(actor),"Recovering actor not eligible")
print("Halloween economy assertions passed: "..count)

