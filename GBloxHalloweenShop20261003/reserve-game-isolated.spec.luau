local currentAt=1790812800
local os={time=function() return currentAt end}
local settingsAttributes={}
local settings={GetAttribute=function(_,name) return settingsAttributes[name] end}
local storage={FindFirstChild=function(_,name) return name=="GBloxHalloweenSettings" and settings or nil end}
local game={GetService=function(_,name) assert(name=="ReplicatedStorage"); return storage end}
local AbilityRules=(function()
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
local profiles={}
local saved,synced=0,0
local task={spawn=function(fn,player) fn(player) end}
local PlayerData={Save=function() saved+=1 end}
local function sync() synced+=1 end
function PlayerData.ReserveAbilityGame(player,matchId,id)
 local p=profiles[player]
 if not p or (not p.CanSave and not p.StudioTemporary) then return false,"Your save isn't ready." end
 if p.CanSave and os.time()>=(p.LeaseUntil or 0) then return false,"Your save is reconnecting." end
 local ok,newTicket=AbilityRules.Reserve(p,matchId,id,os.time())
 local ticket=p.AbilityGameTicket
 player:SetAttribute("GBloxAbilityActiveThisGame",ok==true and typeof(ticket)=="table"
  and ticket.MatchId==matchId and ticket.AbilityId==id)
 if typeof(id)=="string" and AbilityRules.Definitions[id] then
  player:SetAttribute("AbilityUnlimited_"..id,p.Abilities[id]~=nil and p.Abilities[id].Owned==true and AbilityRules.IsUnlimited(id))
 end
 if not ok then return false,newTicket end
 if newTicket then
  sync(player)
  -- Mutate the profile before yielding: quit/release/autosave includes this ticket.
  -- No extra deduction happens at round changes, finishing, or disconnect.
  if p.CanSave then task.spawn(PlayerData.Save,player) end
 end
 return true
end

local count=0
local function check(value,message) count+=1; assert(value,message) end
local function setup(id,uses,ticket)
 local attributes={GBloxAbilityActiveThisGame=true}
 local player={Parent=true,SetAttribute=function(_,name,value) attributes[name]=value end}
 local p={CanSave=true,LeaseUntil=1793492200,EquippedAbility=id,Abilities=AbilityRules.NormalizeAbilities({[id]={Owned=true,Uses=uses}}),AbilityGameTicket=ticket}
 profiles[player]=p
 return player,p,attributes
end
local startAt,endAt=1790812800,1793491200
for _,id in {"Pumpkin","Web"} do
 currentAt=startAt
 local player,p,attrs=setup(id,0)
 check(PlayerData.ReserveAbilityGame(player,"free",id),"Free seasonal activation allowed")
 check(attrs.AbilityUnlimited_Pumpkin==true or attrs.AbilityUnlimited_Web==true,"Owned seasonal attr set")
 check(attrs.GBloxAbilityActiveThisGame==false,"Free seasonal activation never marks paid ticket")
 check(p.AbilityGameTicket==nil,"No persistent free ticket")
 check(p.Abilities[id].Uses==0,"No stored charges consumed")
 currentAt=endAt
 check(not PlayerData.ReserveAbilityGame(player,"free",id),"Cutoff rejects empty unpaid match")
 check(attrs.GBloxAbilityActiveThisGame==false,"Cutoff keeps active game false")
 check(attrs["AbilityUnlimited_"..id]==false,"Cutoff removes unlimited attribute")

 currentAt=startAt
 player,p,attrs=setup(id,0,{MatchId="paid",AbilityId=id})
 check(PlayerData.ReserveAbilityGame(player,"paid",id),"Season can reuse an existing paid ticket")
 check(attrs.GBloxAbilityActiveThisGame==true,"Existing current paid ticket preserved")
 check(PlayerData.ReserveAbilityGame(player,"other",id),"Different free seasonal match allowed")
 check(attrs.GBloxAbilityActiveThisGame==false,"Old paid ticket not considered current match")

 currentAt=endAt
 player,p,attrs=setup(id,3)
 local beforeSaved=saved
 check(PlayerData.ReserveAbilityGame(player,"paid-new",id),"Paid activation allowed")
 check(attrs.GBloxAbilityActiveThisGame==true,"New paid ticket marks current game")
 check(p.Abilities[id].Uses==2,"Paid game reserves exactly one charge")
 check(saved==beforeSaved+1,"New paid ticket queued for save")
 check(PlayerData.ReserveAbilityGame(player,"paid-new",id),"Second activation reuses paid ticket")
 check(p.Abilities[id].Uses==2,"Repeated activation does not spend again")
 check(saved==beforeSaved+1,"Existing ticket does not queue redundant save")

 player,p,attrs=setup(id,0,{MatchId="match",AbilityId=id=="Pumpkin" and "Web" or "Pumpkin"})
 check(not PlayerData.ReserveAbilityGame(player,"match",id),"Wrong-ability paid ticket denied")
 check(attrs.GBloxAbilityActiveThisGame==false,"Wrong-ability ticket clears active attr")
end
currentAt=endAt
local player,p,attrs=setup("Freeze",1)
check(PlayerData.ReserveAbilityGame(player,"regular","Freeze"),"Regular ability still reserves paid game")
check(attrs.GBloxAbilityActiveThisGame==true,"Regular paid ticket active attribute preserved")
check(p.Abilities.Freeze.Uses==0,"Regular ability charges unchanged")
print("Current-match paid-ticket assertions passed: "..count)

