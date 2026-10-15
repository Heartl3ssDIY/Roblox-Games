assert(not game:GetService("RunService"):IsRunning(), "Edit-only verification.")
local out = {offers = {}, ownership = {}}
local folder = Instance.new("Folder")
folder.Name = "CommerceAvailabilityVerification20261008"
folder.Parent = game.ServerStorage
local ok, problem = pcall(function()
 for _, check in {
  {controller = game.StarterGui.PlaygroundShell.CommerceController, config = "PlaygroundCommerce"},
  {controller = game.StarterGui.PlaygroundDonations.Controller, config = "PlaygroundDonationProducts"}
 } do
  local probe = Instance.new("ModuleScript")
  probe.Name = check.config
  probe.Sandboxed = true
  probe.Capabilities = check.controller.Capabilities:Add(SecurityCapabilities.new(Enum.SecurityCapability.RunServerScript))
  probe.Source = [=[
   local MarketplaceService = game:GetService("MarketplaceService")
   local config = game:GetService("ReplicatedStorage"):FindFirstChild(script.Name)
   local offers = {}
   for _, entry in config:GetChildren() do
    if entry:IsA("IntValue") then
     local kind = entry:GetAttribute("Kind") == "GamePass" and Enum.InfoType.GamePass or Enum.InfoType.Product
     local ok, info = pcall(function() return MarketplaceService:GetProductInfoAsync(entry.Value, kind) end)
     local valid = ok and type(info) == "table" and info.IsForSale ~= false and type(info.PriceInRobux) == "number" and info.PriceInRobux >= 1
     offers[#offers + 1] = {name = entry.Name, id = entry.Value, ok = ok, valid = valid,
      isForSale = ok and info.IsForSale, price = ok and info.PriceInRobux,
      basePrice = ok and info.UserBasePriceInRobux, universe = ok and info.UniverseId,
      error = not ok and tostring(info) or nil}
    end
   end
   return offers
  ]=]
  probe.Parent = folder
  for _, offer in require(probe) do out.offers[#out.offers + 1] = offer end
  probe:Destroy()
 end
 local launcher = Instance.new("ModuleScript")
 launcher.Name = "Launcher"
 launcher.Sandboxed = true
 launcher.Capabilities = game.ServerScriptService.PlaygroundBootstrap.Capabilities
 launcher.Source = "return require(script.Parent.Service)"
 local service = Instance.new("ModuleScript")
 service.Name = "Service"
 service.Sandboxed = true
 service.Capabilities = game.ServerScriptService.PlaygroundCommerceService.Capabilities
 service.Source = [=[
  local MarketplaceService = game:GetService("MarketplaceService")
  local result = {}
  for _, id in {2016470307, 2013962477, 2014580485} do
   local ok, owned = pcall(function() return MarketplaceService:UserOwnsGamePassAsync(1201803949, id) end)
   result[#result + 1] = {id = id, ok = ok, owned = ok and owned, error = not ok and tostring(owned) or nil}
  end
  return result
 ]=]
 launcher.Parent = folder
 service.Parent = folder
 out.ownership = require(launcher)
end)
folder:Destroy()
assert(ok, problem)
assert(#out.offers == 12, "Expected nine products and three passes.")
for _, offer in out.offers do assert(offer.valid, offer.name .. ": " .. tostring(offer.error)) end
for _, result in out.ownership do assert(result.ok, tostring(result.error)) end
return game:GetService("HttpService"):JSONEncode(out)
