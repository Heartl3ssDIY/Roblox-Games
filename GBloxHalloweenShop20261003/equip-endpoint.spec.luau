local checks=0
local function check(value,message) assert(value,message) checks+=1 end
local clock=1
local os={clock=function() return clock end}
local AbilityRules={Definitions={Pumpkin={},Web={},GravitySwitch={}}}
local busy,last={},{}
local calls=0
local Data={SetEquippedAbility=function(player,id) calls+=1 return true,"Equipped: "..id end}
local warn=function() end
local equip={}
equip.OnServerInvoke=function(player,id)
 if typeof(id)~="string" or (id~="" and not AbilityRules.Definitions[id]) then return false,"Unknown ability." end
 if id=="Kong" then return false,"Kong is unavailable for now." end
 if player:GetAttribute("GBloxLobbyReady")~=true or player:GetAttribute("GBloxInParty") then return false,"Equip abilities in the lobby before joining a party." end
 if busy[player] or os.clock()-(last[player] or -math.huge)<.35 then return false,"Please wait a moment." end
 last[player]=os.clock() busy[player]=true
 local ok,success,message=pcall(Data.SetEquippedAbility,player,id)
 busy[player]=nil
 if not ok then warn("[AbilityEquip]",success) return false,"Could not equip. Please try again." end
 return success,message
end
local player={attributes={GBloxLobbyReady=true}}
function player:GetAttribute(name) return self.attributes[name] end
for _,id in {"Pumpkin","Web","GravitySwitch",""} do
 clock+=1
 local ok,message=equip.OnServerInvoke(player,id)
 check(ok==true,"Known equip: "..id)
 check(message=="Equipped: "..id,"Equip result: "..id)
end
check(calls==4,"Data called for valid ids")
check(equip.OnServerInvoke(player,"Kong")==false,"Kong unavailable")
check(equip.OnServerInvoke(player,"Forged")==false,"Unknown id rejected")
check(equip.OnServerInvoke(player,{})==false,"Non-string rejected")
player.attributes.GBloxInParty=true clock+=1
check(equip.OnServerInvoke(player,"Pumpkin")==false,"Party lock preserved")
player.attributes.GBloxInParty=false player.attributes.GBloxLobbyReady=false clock+=1
check(equip.OnServerInvoke(player,"Web")==false,"Lobby lock preserved")
player.attributes.GBloxLobbyReady=true clock+=1
check(equip.OnServerInvoke(player,"Web")==true,"Web accepted")
check(equip.OnServerInvoke(player,"Pumpkin")==false,"Throttle preserved")
check(calls==5,"No rejected calls reached data")
print("Equip endpoint assertions passed: "..checks)

