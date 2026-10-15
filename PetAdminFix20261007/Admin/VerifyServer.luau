local module=game.ServerScriptService.PlaygroundAdminService:Clone()
module.Name="OwnerOnlyAdminFixture"; module.Parent=game.ServerScriptService
local ok,result=pcall(function()
 local Admin=require(module)
 local checks={}
 local function check(n,c) assert(c,n); table.insert(checks,n) end
 local values={AdminUserId=1201803949,ExtraAdminUserIds="999, -1, 168026080"}
 local config={GetAttribute=function(_,n)return values[n]end}
 local actions={"BBStart","BBRunner","BBBulldog","TagStart","TagRunner","TagTagger","MudStart","MudShooter","MudMedic","StopRound","ToggleAutomatic","GetStatus","GrantItem","GrantCoins","AddLevels"}
 for _,studio in ipairs({false,true}) do
  local admin=Admin.new({},config,studio)
  check("owner allowed studio="..tostring(studio),admin:IsAuthorized({UserId=1201803949}))
  for _,id in ipairs({999,123456,168026080,0,-1,-2,-3}) do
   local actor={UserId=id}
   check("deny id="..id.." studio="..tostring(studio),not admin:IsAuthorized(actor))
   for _,action in ipairs(actions) do
    local r=admin:Handle(actor,action,{targetUserId=1201803949,amount=100,itemId="anything",equip=true})
    check("deny "..action.." id="..id.." studio="..tostring(studio),r.ok==false and r.message=="Admin access required." and r.players==nil and r.target==nil)
   end
  end
 end
 local admin=Admin.new({},config,true)
 for _,id in ipairs({0,-1,"1201803949",math.huge}) do values.AdminUserId=id check("invalid configured owner fails closed "..tostring(id),not admin:IsAuthorized({UserId=1201803949})) end
 values.AdminUserId=nil check("missing configured owner fails closed",not admin:IsAuthorized({UserId=1201803949}))
 local gui=game.StarterGui.PlaygroundAdminPanel
 check("authored GUI disabled before replication",not gui.Enabled)
 for _,name in ipairs({"Toggle","AdminHub","Panel","CompactPanel","CompactToggle"}) do check(name.." hidden by default",not gui[name].Visible) end
 check("exact owner GUI identity",gui:GetAttribute("OwnerUserId")==1201803949)
 check("no runtime geometry overrides",not gui.Controller.Source:find("%.Position%s*=") and not gui.Controller.Source:find("%.Size%s*="))
 check("server remote guarded",game.ServerScriptService.PlaygroundAdminService.Source:find("return self:Handle(player, action, payload)",1,true)~=nil)
 check("legacy bootstrap disabled",game.ServerScriptService.BritishBulldogBootstrap.Disabled)
 return {passed=#checks,checks=checks}
end)
module:Destroy()
assert(ok,result)
return game.HttpService:JSONEncode(result)
