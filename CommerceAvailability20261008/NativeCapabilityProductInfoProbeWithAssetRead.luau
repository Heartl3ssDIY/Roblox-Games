local HttpService=game:GetService("HttpService")
local result={}
for _,target in {game.StarterGui.PlaygroundDonations.Controller,game.StarterGui.PlaygroundShell.CommerceController,game.ServerScriptService.PlaygroundCommerceService}do
 local module=Instance.new("ModuleScript")
 module.Name="CommerceReadProbe20261008"
 module.Sandboxed=true
 module.Capabilities=target.Capabilities:Add(SecurityCapabilities.new(Enum.SecurityCapability.RunServerScript,Enum.SecurityCapability.AssetRead))
 module.Source=[=[
 local MarketplaceService=game:GetService("MarketplaceService")
 local results={}
 for _,item in {{3717139873,Enum.InfoType.Product},{2016470307,Enum.InfoType.GamePass},{3717139252,Enum.InfoType.Product}}do
  local ok,value=pcall(function()return MarketplaceService:GetProductInfoAsync(item[1],item[2])end)
  results[tostring(item[1])]={ok=ok,value=value}
 end
 return results
 ]=]
 module.Parent=game.ServerStorage
 local ok,value=pcall(require,module)
 result[target:GetFullName()]={caps=tostring(module.Capabilities),ok=ok,value=value}
 module:Destroy()
end
return HttpService:JSONEncode(result)
