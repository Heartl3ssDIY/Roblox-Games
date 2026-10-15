assert(not game:GetService("RunService"):IsRunning(), "Edit only")
local storage = game:GetService("ServerStorage")
local existing = storage:FindFirstChild("BackgroundFallbackCapabilityFixture")
assert(not existing, "Existing fixture must be inspected")
local fixture = Instance.new("ScreenGui")
fixture.Name = "BackgroundFallbackCapabilityFixture"
fixture.Parent = storage
local report = { checks = {}, errors = {} }
local function check(name, value)
	table.insert(report.checks, { name = name, passed = value == true })
	assert(value, name)
end
local ok, err = xpcall(function()
	local shell = game.StarterGui.PlaygroundShell
	local prototype = shell.BackgroundFallbackController
	local module = Instance.new("ModuleScript")
	module.Name = "NativeCapabilityProbe"
	module.Sandboxed = prototype.Sandboxed
	module.Capabilities = prototype.Capabilities
	module.Source = prototype.Source .. "\nreturn true"
	local loadedSource = game.StarterGui.BritishBulldogHUD.TopCard.Panel.BulldogChip
	local failedSource = shell.Wallet
	local loaded = loadedSource:Clone()
	loaded.Name = "LoadedCard"
	loaded.Parent = fixture
	local failed = failedSource:Clone()
	failed.Name = "FailedCard"
	failed.Parent = fixture
	for _, object in ipairs(fixture:GetDescendants()) do if object:IsA("BaseScript") then object:Destroy() end end
	local loadedImage = loaded.ReusableSkin
	local failedImage = failed.ReusableSkin
	local loadedFallback = loaded.ReusableSkinFallback
	local failedFallback = failed.ReusableSkinFallback
	check("Existing loaded source PNG", loadedSource.ReusableSkin.IsLoaded)
	check("Existing failed source PNG", not failedSource.ReusableSkin.IsLoaded)
	module.Parent = fixture
	report.capabilities = tostring(module.Capabilities)
	report.sandboxed = module.Sandboxed
	check("Exact existing permissions", module.Capabilities == prototype.Capabilities and module.Sandboxed == prototype.Sandboxed)
	local positions = { loadedFallback.Position, loadedFallback.Size, loadedFallback.AnchorPoint, failedFallback.Position, failedFallback.Size, failedFallback.AnchorPoint }
	check("Module initializes inside native sandbox", require(module) == true)
	task.wait(0.15)
	report.loadedClone = loadedImage.IsLoaded
	report.failedClone = failedImage.IsLoaded
	check("Failed PNG fallback visible", failedFallback.Visible == (failedImage.Visible and not failedImage.IsLoaded))
	check("Loaded clone follows native IsLoaded", loadedFallback.Visible == (loadedImage.Visible and not loadedImage.IsLoaded))
	failedImage.ImageTransparency = 1
	task.wait()
	check("Transparent image hides fallback", not failedFallback.Visible)
	failedImage.ImageTransparency = 0.25
	task.wait()
	check("Native alpha binding", failedFallback.BackgroundTransparency == 0.25 and failedFallback.Edge.Face.BackgroundTransparency == 0.25)
	failedImage.Visible = false
	task.wait()
	check("Native visibility binding", not failedFallback.Visible)
	failedImage.Visible = true
	failedImage.ImageColor3 = Color3.new(0.5, 0.5, 0.5)
	task.wait()
	check("Native tint binding", math.abs(failedFallback.BackgroundColor3.R - 31 / 255 * 0.5) < 0.00001)
	failedImage.Image = loadedSource.ReusableSkin.Image
	task.wait(0.2)
	report.replacementLoaded = failedImage.IsLoaded
	check("Replacement image obeys native load state", failedFallback.Visible == (failedImage.Visible and not failedImage.IsLoaded))
	check("Geometry remains authored", loadedFallback.Position == positions[1] and loadedFallback.Size == positions[2] and loadedFallback.AnchorPoint == positions[3] and failedFallback.Position == positions[4] and failedFallback.Size == positions[5] and failedFallback.AnchorPoint == positions[6])
	module:Destroy()
	task.wait()
	check("Native cleanup hides fallback", not failedFallback.Visible and not loadedFallback.Visible)
end, debug.traceback)
if not ok then table.insert(report.errors, tostring(err)) end
fixture:Destroy()
report.cleaned = storage:FindFirstChild("BackgroundFallbackCapabilityFixture") == nil
report.passed = ok
return game:GetService("HttpService"):JSONEncode(report)
