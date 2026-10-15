return function(Service)
 local requested={}
 local service=setmetatable({identities={},resolveEmote=function(id) table.insert(requested,id) return {emoteId="E01",emoteAnimationId="rbxassetid://93650537970037",emoteRigType="R15"} end},{__index=Service})
 function service:_level(_)return 7 end
 local entries={{userId=1,value=100},{userId=2,value=90},{userId=3,value=80},{userId=4,value=70}}
 local results=service:_displayEntries(entries,"XP")
 assert(#requested==3 and #results==4)
 for i=1,3 do assert(results[i].emoteId=="E01" and results[i].value=="LV 7" and results[i].emoteRigType=="R15") end
 assert(results[4].emoteId==nil)
 service.resolveEmote=function()error("Unavailable")end
 results=service:_displayEntries(entries,"Wins")
 assert(#results==4 and results[1].value=="100" and results[1].emoteId==nil)
 return {passed=6}
end
