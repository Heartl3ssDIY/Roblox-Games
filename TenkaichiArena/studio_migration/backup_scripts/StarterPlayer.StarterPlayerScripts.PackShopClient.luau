-- PackShopClient: pack-shop access.
-- (1) A top-bar "Packs" button (left of Play) that teleports to the pack ring.
-- (2) Walking into the ring opens the Pack Shop UI; leaving closes it.
-- Both the button and the UI hide while the player is in an arena match.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local PackShopUI = require(ReplicatedStorage:WaitForChild("PackShopUI"))
local PlayerData = require(ReplicatedStorage:WaitForChild("PlayerData"))

local C = { packBtn = Color3.fromRGB(220,160,50) }
local function mk(cls,props,parent) local o=Instance.new(cls); for k,v in pairs(props) do o[k]=v end; o.Parent=parent; return o end
local function corner(p,r) Instance.new("UICorner",p).CornerRadius=UDim.new(0,r or 12) end
local function stroke(p,c,t) local s=Instance.new("UIStroke",p); s.Color=c; s.Thickness=t or 2; s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; return s end

-- ── Top-bar "Packs" button (left of Play) ────────────────────────────────────
local btnGui = mk("ScreenGui", { Name="PacksButtonGui", ResetOnSpawn=false,
	IgnoreGuiInset=true, ZIndexBehavior=Enum.ZIndexBehavior.Sibling }, playerGui)
local packsBtn = mk("TextButton", {
	Name="PacksBtn", Size=UDim2.new(0,130,0,44), Position=UDim2.new(0.5,-210,0,14),
	BackgroundColor3=C.packBtn, BorderSizePixel=0, AutoButtonColor=false,
	Text="\xF0\x9F\x8E\x81  Packs", TextColor3=Color3.fromRGB(50,30,10),
	Font=Enum.Font.GothamBold, TextSize=18,
}, btnGui)
corner(packsBtn,22); stroke(packsBtn, Color3.fromRGB(180,120,40), 2)

-- Banked-pack count badge (top-right of the Packs button)
local packBadge = mk("TextLabel", {
	Name="PackBadge", Size=UDim2.new(0,22,0,22), Position=UDim2.new(1,-12,0,-8),
	BackgroundColor3=Color3.fromRGB(220,60,70), BorderSizePixel=0, Visible=false,
	Text="0", TextColor3=Color3.fromRGB(255,255,255), Font=Enum.Font.GothamBold,
	TextSize=12, ZIndex=5,
}, packsBtn)
corner(packBadge, 11)
local function totalPacks()
	local n = 0
	for _, c in pairs(PlayerData.allPackCounts()) do n += c end
	return n
end
local function refreshPackBadge()
	local n = totalPacks()
	packBadge.Visible = n > 0
	packBadge.Text = tostring(n)
end
refreshPackBadge()
PlayerData.Changed:Connect(refreshPackBadge)
packsBtn.MouseEnter:Connect(function()
	TweenService:Create(packsBtn, TweenInfo.new(0.12), { BackgroundColor3=Color3.fromRGB(245,185,75) }):Play()
end)
packsBtn.MouseLeave:Connect(function()
	TweenService:Create(packsBtn, TweenInfo.new(0.12), { BackgroundColor3=C.packBtn }):Play()
end)

local PACK_RING_POS = Vector3.new(0, 4, 50)
packsBtn.Activated:Connect(function()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then hrp.CFrame = CFrame.new(PACK_RING_POS) end
end)

-- ── Walk-in trigger + arena hiding ───────────────────────────────────────────
local trigger = workspace:WaitForChild("Lobby_PackShopZone"):WaitForChild("PackShopTrigger")
local RADIUS = 11
local inside = false

RunService.Heartbeat:Connect(function()
	local inMatch = player:GetAttribute("ActiveArena") ~= nil
	-- hide the Packs button in a match
	packsBtn.Visible = not inMatch

	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if inMatch or not hrp then
		if inside then inside = false; PackShopUI.close() end
		return
	end

	local d = (hrp.Position - trigger.Position).Magnitude
	if d <= RADIUS and not inside then
		inside = true
		PackShopUI.open(playerGui)
	elseif d > RADIUS and inside then
		inside = false
		PackShopUI.close()
	end
end)

