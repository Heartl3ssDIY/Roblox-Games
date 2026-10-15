local original=game.ServerScriptService.PlaygroundCommerceService
local fixture=original:Clone()
fixture.Name="DonationCapabilityProbe20261008"
fixture.Source=[[
local market=game:GetService("MarketplaceService")
local checks={}
for _,name in {"PromptGamePassPurchaseFinished","PromptProductPurchaseFinished"}do
 local ok,err=pcall(function()
  local connection=market[name]:Connect(function()end)
  connection:Disconnect()
 end)
 table.insert(checks,{event=name,ok=ok,error=not ok and tostring(err) or nil})
end
return checks
]]
fixture.Parent=game.ServerStorage
local ok,result=pcall(require,fixture)
fixture:Destroy()
if not ok then return tostring(result)end
return game:GetService("HttpService"):JSONEncode(result)
