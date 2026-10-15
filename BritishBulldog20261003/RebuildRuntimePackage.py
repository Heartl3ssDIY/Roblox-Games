from pathlib import Path
import hashlib
import json
import shutil

ROOT = Path(r"C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\BritishBulldog20261003")
FILES = {
    "Rules": "BritishBulldogRules.lua",
    "Service": "BritishBulldogService.lua",
    "Bootstrap": "BritishBulldogBootstrap.server.lua",
    "Admin": "PlaygroundAdminService.lua",
    "Camera": "BritishBulldogCamera.client.luau",
    "HUDController": "BritishBulldogHUD.client.luau",
    "AdminController": "PlaygroundAdminPanel.client.luau",
    "BuildHUD": "BuildBritishBulldogHUD.luau",
    "BuildAdmin": "BuildPlaygroundAdminPanel.luau",
}
sources = {key: (ROOT / name).read_text(encoding="utf-8-sig") for key, name in FILES.items()}
source_blocks = []
for key, source in sources.items():
    if key.startswith("Build"):
        continue
    delimiter = "="
    while "]" + delimiter + "]" in source:
        delimiter += "="
    source_blocks.append('\t["' + key + '"] = [' + delimiter + '[' + source + ']' + delimiter + '],')

template = r'''local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Run InstallRuntime in Studio edit mode")

local sources = {
__SOURCES__
}

local baseCaps = SecurityCapabilities.new(
	Enum.SecurityCapability.RunServerScript,
	Enum.SecurityCapability.RunClientScript,
	Enum.SecurityCapability.AccessOutsideWrite,
	Enum.SecurityCapability.CreateInstances,
	Enum.SecurityCapability.Basic,
	Enum.SecurityCapability.Physics,
	Enum.SecurityCapability.UI,
	Enum.SecurityCapability.Players,
	Enum.SecurityCapability.AvatarBehavior,
	Enum.SecurityCapability.AvatarAppearance,
	Enum.SecurityCapability.Environment,
	Enum.SecurityCapability.LegacySound,
	Enum.SecurityCapability.Audio
)
local remoteCaps = SecurityCapabilities.new(Enum.SecurityCapability.RemoteEvent)
local adminClientAdditions = SecurityCapabilities.new(Enum.SecurityCapability.RemoteEvent, Enum.SecurityCapability.Input)
local installed = {}

local function install(className, name, source, parent, additions)
	local object = parent:FindFirstChild(name)
	if object then
		assert(object:IsA(className), name .. " has an unexpected class")
		assert(object.Sandboxed, name .. " must retain its existing sandbox")
		if additions and not object.Capabilities:Contains(additions) then
			object.Capabilities = object.Capabilities:Add(additions)
		end
		object.Source = source
	else
		object = Instance.new(className)
		object.Name = name
		object.Capabilities = additions and baseCaps:Add(additions) or baseCaps
		object.Sandboxed = true
		object.Source = source
		object.Parent = parent
	end
	table.insert(installed, object:GetFullName())
	return object
end

local serverScripts = game:GetService("ServerScriptService")
local serverStorage = game:GetService("ServerStorage")
local replicatedStorage = game:GetService("ReplicatedStorage")
local starterGui = game:GetService("StarterGui")
local starterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local arena = workspace:FindFirstChild("British Bulldog game")
assert(arena, "British Bulldog arena is missing")

local config = serverStorage:FindFirstChild("PlaygroundAdminConfig")
if config then
	assert(config:IsA("Folder"), "PlaygroundAdminConfig must be a Folder")
else
	config = Instance.new("Folder")
	config.Name = "PlaygroundAdminConfig"
	config:SetAttribute("AdminUserId", 1201803949)
	config:SetAttribute("ExtraAdminUserIds", "")
	config.Parent = serverStorage
end
if config:GetAttribute("AdminUserId") == nil then
	config:SetAttribute("AdminUserId", 1201803949)
end
if config:GetAttribute("ExtraAdminUserIds") == nil then
	config:SetAttribute("ExtraAdminUserIds", "")
end

local remote = replicatedStorage:FindFirstChild("PlaygroundAdminRequest")
if remote then
	assert(remote:IsA("RemoteFunction"), "PlaygroundAdminRequest must be a RemoteFunction")
	assert(remote.Sandboxed, "PlaygroundAdminRequest must retain its sandbox")
	assert(remote.Capabilities:Contains(remoteCaps) and remoteCaps:Contains(remote.Capabilities),
		"PlaygroundAdminRequest must have only its existing RemoteEvent capability")
else
	remote = Instance.new("RemoteFunction")
	remote.Name = "PlaygroundAdminRequest"
	remote.Capabilities = remoteCaps
	remote.Sandboxed = true
	remote.Parent = replicatedStorage
end

local function buildHUD()
__BUILD_HUD__
end
local function buildAdmin()
__BUILD_ADMIN__
end

if not starterGui:FindFirstChild("BritishBulldogHUD") then
	buildHUD()
end
if not starterGui:FindFirstChild("PlaygroundAdminPanel") then
	buildAdmin()
end
local hud = starterGui:FindFirstChild("BritishBulldogHUD")
local adminGui = starterGui:FindFirstChild("PlaygroundAdminPanel")
assert(hud and hud:IsA("ScreenGui"), "BritishBulldogHUD must be an editable ScreenGui")
assert(adminGui and adminGui:IsA("ScreenGui"), "PlaygroundAdminPanel must be an editable ScreenGui")
assert(adminGui:FindFirstChild("Panel") and adminGui.Panel:FindFirstChild("Body"),
	"PlaygroundAdminPanel needs the current authored scrolling layout")

install("ModuleScript", "BritishBulldogRules", sources.Rules, serverScripts)
install("ModuleScript", "BritishBulldogService", sources.Service, serverScripts)
install("ModuleScript", "PlaygroundAdminService", sources.Admin, serverScripts, remoteCaps)
install("LocalScript", "Controller", sources.HUDController, hud)
install("LocalScript", "Controller", sources.AdminController, adminGui, adminClientAdditions)
install("LocalScript", "BritishBulldogCamera", sources.Camera, starterPlayerScripts)
arena:SetAttribute("AutoStart", false)
install("Script", "BritishBulldogBootstrap", sources.Bootstrap, serverScripts, remoteCaps)

return {
	ScriptsInstalled = #installed,
	AdminGUI = adminGui:GetFullName(),
	AuthoredLayoutsPreserved = true,
	AutoStart = arena:GetAttribute("AutoStart"),
}
'''
# Builders are nested verbatim, avoiding loadstring or script assets.
result = template.replace("__SOURCES__", "\n".join(source_blocks))
result = result.replace("__BUILD_HUD__", sources["BuildHUD"]).replace("__BUILD_ADMIN__", sources["BuildAdmin"])
assert "CapabilityControl" not in result
for source in sources.values():
    assert source in result
installer = ROOT / "InstallRuntime.luau"
backup = ROOT / "InstallRuntime.before_admin.luau"
if installer.exists() and not backup.exists():
    shutil.copy2(installer, backup)
installer.write_text(result, encoding="utf-8", newline="\n")
manifest = {
    "installer": str(installer),
    "bytes": installer.stat().st_size,
    "sourceFiles": {
        key: {"file": FILES[key], "sha256": hashlib.sha256(source.encode("utf-8")).hexdigest()}
        for key, source in sources.items()
    },
    "scriptCount": 7,
    "newRemoteCapabilities": ["RemoteEvent"],
    "extraScriptCapabilities": {
        "BritishBulldogBootstrap": ["RemoteEvent"],
        "PlaygroundAdminService": ["RemoteEvent"],
        "PlaygroundAdminPanel.Controller": ["RemoteEvent", "Input"],
    },
    "existingLayoutsPreserved": True,
    "existingCapabilitiesPreservedWithRequiredAdditionsOnly": True,
    "studioExecutionPerformed": False,
}
(ROOT / "runtime-package-checks.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8", newline="\n")
print(json.dumps({"installerBytes": manifest["bytes"], "embeddedSources": len(sources), "scriptCount": 7, "verified": True}))

