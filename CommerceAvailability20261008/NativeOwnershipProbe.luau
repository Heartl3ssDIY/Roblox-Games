local out={}
local HttpService=game:GetService("HttpService")
for _,addAssetRead in {false,true}do
 local folder=Instance.new("Folder");folder.Name="CommerceOwnershipProbe20261008";folder.Parent=game.ServerStorage
 local bootstrap=Instance.new("ModuleScript")
 bootstrap.Name="Launcher"
 bootstrap.Sandboxed=true;bootstrap.Capabilities=game.ServerScriptService.PlaygroundBootstrap.Capabilities
 local service=Instance.new("ModuleScript");service.Name="Service"
 service.Sandboxed=true;service.Capabilities=game.ServerScriptService.PlaygroundCommerceService.Capabilities
 if addAssetRead then
  local cap=SecurityCapabilities.new(Enum.SecurityCapability.AssetRead)
  bootstrap.Capabilities=bootstrap.Capabilities:Add(cap)
  service.Capabilities=service.Capabilities:Add(cap)
 end
 service.Source=[=[
 local ms=game:GetService("MarketplaceService")
 local ok,value=pcall(function()return ms:UserOwnsGamePassAsync(1201803949,2016470307)end)
 return {ok=ok,value=value}
 ]=]
 bootstrap.Source="return require(script.Parent.Service)"
 bootstrap.Parent=folder;service.Parent=folder
 local ok,value=pcall(require,bootstrap)
 out[tostring(addAssetRead)]={ok=ok,value=value}
 folder:Destroy()
end
return HttpService:JSONEncode(out)
