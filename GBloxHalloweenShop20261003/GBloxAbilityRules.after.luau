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
