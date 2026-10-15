assert(not game:GetService("RunService"):IsRunning(), "Edit-only verification")
local fixtureName = "DonationPermissionsNativeProbe20261008"
assert(not game.ServerStorage:FindFirstChild(fixtureName), "Prior probe needs inspection")
local fixture = Instance.new("Folder")
fixture.Name, fixture.Parent = fixtureName, game.ServerStorage
local probeSource = [[
local market = game:GetService("MarketplaceService")
local result = {}
for _, name in { "PromptGamePassPurchaseFinished", "PromptProductPurchaseFinished" } do
 local ok, err = pcall(function()
  local connection = market[name]:Connect(function() end)
  connection:Disconnect()
 end)
 table.insert(result, { event = name, passed = ok, error = not ok and tostring(err) or nil })
end
return result
]]
local report = { probes = {}, purchasePrompted = false, playStarted = false, liveSourcesChanged = false }
local function makeProbe(original, name, parent, source, editServerExecutor)
 local module = Instance.new("ModuleScript")
 module.Name, module.Source = name, source
 module.Capabilities = original.Capabilities
 module.Sandboxed = original.Sandboxed
 if editServerExecutor then
  module.Capabilities = module.Capabilities:Add(SecurityCapabilities.new(Enum.SecurityCapability.RunServerScript))
 end
 module.Parent = parent
 return module
end
local function checkProbe(name, module, editServerExecutor)
 local ok, checks = pcall(require, module)
 assert(ok, name .. ": " .. tostring(checks))
 for _, check in checks do assert(check.passed, name .. " " .. check.event .. ": " .. tostring(check.error)) end
 table.insert(report.probes, { name = name, checks = checks, editOnlyRunServerScript = editServerExecutor == true })
end
local ok, err = xpcall(function()
 local bootstrap = makeProbe(game.ServerScriptService.PlaygroundBootstrap, "BootstrapProbe", fixture,
  'return require(script:WaitForChild("CommerceProbe"))', false)
 makeProbe(game.ServerScriptService.PlaygroundCommerceService, "CommerceProbe", bootstrap, probeSource, false)
 checkProbe("Bootstrap to Commerce sandbox chain", bootstrap, false)
 for _, entry in {
  { game.StarterGui.PlaygroundShell.CommerceController, "Shop client native events" },
  { game.StarterGui.PlaygroundDonations.Controller, "Donation client native events" },
 } do
  local controller = entry[1]
  assert(tostring(controller.Capabilities):find("PromptExternalPurchase", 1, true), controller:GetFullName() .. " missing permission")
  local module = makeProbe(controller, controller.Parent.Name .. "Probe", fixture, probeSource, true)
  checkProbe(entry[2], module, true)
 end
 report.passed = true
 report.eventChecks = #report.probes * 2
end, debug.traceback)
fixture:Destroy()
if not ok then error(err) end
return report

