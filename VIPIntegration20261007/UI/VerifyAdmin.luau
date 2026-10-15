local module = game.ServerScriptService.PlaygroundAdminService:Clone()
module.Name = "VIPAdminVerification"
module.Parent = game.ServerStorage
local ok, result = pcall(function()
 local Admin = require(module)
 local count = 0
 local function check(condition, message) assert(condition, message) count += 1 end
 local function player(id, name)
  return {UserId=id,Name=name,DisplayName=name,GetAttribute=function(_,key) return key == "PCDataReady" and true or nil end}
 end
 local owner = player(1201803949,"SandboxxYY")
 local other = player(85498723,"OtherPlayer")
 local studio = player(-1,"Player1")
 local roster = {owner,other,studio}
 local players = {GetPlayers=function() return roster end,GetPlayerByUserId=function(_,id) for _,p in ipairs(roster) do if p.UserId == id then return p end end end}
 local calls = {}
 local failing = false
 local economy = {
  AdminLimits={coinsPerGrant=1000000,levelsPerGrant=100,maxLevel=1000},
  Status=function(_,target) return {ok=true,ready=true,entitlements={VIP=false,BetaTester=false}} end,
  AdminGrantEntitlement=function(_,target,kind)
   table.insert(calls,{target=target,kind=kind})
   if failing then error("simulated failure") end
   return true,"Granted " .. kind
  end,
 }
 local coordinator = {economy=economy,services={},ActiveGame=function() return nil end}
 local config = game.ServerStorage.PlaygroundAdminConfig
 check(config:GetAttribute("AdminUserId")==1201803949,"Wrong owner")
 local service = Admin.new(coordinator,config,true,players)
 for _,action in ipairs({"GrantVIP","GrantBetaTester"}) do
  for _,caller in ipairs({other,studio,player(0,"Unknown")}) do
   local response = service:Handle(caller,action,{targetUserId=owner.UserId})
   check(not response.ok and response.message=="Admin access required.","Non-owner allowed")
  end
 end
 check(#calls==0,"Unauthorized reached economy")
 for _,spec in ipairs({{owner,"GrantVIP","VIP"},{other,"GrantVIP","VIP"},{owner,"GrantBetaTester","BetaTester"},{other,"GrantBetaTester","BetaTester"}}) do
  service.lastRequest[owner]=nil
  local response=service:Handle(owner,spec[2],{targetUserId=spec[1].UserId})
  check(response.ok and calls[#calls].target==spec[1] and calls[#calls].kind==spec[3],"Wrong entitlement target")
  check(response.targetUserId==spec[1].UserId,"Wrong reply target")
 end
 local before=#calls
 for _,payload in ipairs({{}, {targetUserId=99999999},{targetUserId="1201803949"},{targetUserId=math.huge},{targetUserId=0},{targetUserId=0/0}}) do
  service.lastRequest[owner]=nil
  check(not service:Handle(owner,"GrantVIP",payload).ok,"Malformed target allowed")
 end
 check(#calls==before,"Bad target reached economy")
 service.lastRequest[owner]=nil
 failing=true
 local failed=service:Handle(owner,"GrantBetaTester",{targetUserId=other.UserId})
 check(not failed.ok and not service.busy,"Failure left service busy")
 check(failed.message=="That admin action could not finish. Try again.","Server error not shown safely")
 failing=false
 service.lastRequest[owner]=nil
 check(service:Handle(owner,"GrantVIP",{targetUserId=owner.UserId}).ok,"Failed to recover")
 check(not service:Handle(owner,"GrantVIP",{targetUserId=owner.UserId}).ok,"Throttle missing")
 return {checks=count,ownerId=owner.UserId,auth="Exact owner only",targeting="Self and selected online player",failureRecovery=true}
end)
module:Destroy()
assert(ok,result)
return result
