local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local PackShopUI = require(ReplicatedStorage:WaitForChild("PackShopUI"))
local PlayerData = require(ReplicatedStorage:WaitForChild("PlayerData"))
local ArenaTravelClient = require(ReplicatedStorage:WaitForChild("ArenaTravelClient"))

local C = { packBtn = Color3.fromRGB(220,160,50) }
local function mk(cls,props,parent) local o=Instance.new(cls); for k,v in pairs(props) do o[k]=v end; o.Parent=parent; return o end
local function corner(p,r) Instance.new("UICorner",p).CornerRadius=UDim.new(0,r or 12) end
local function stroke(p,c,t) local s=Instance.new("UIStroke",p); s.Color=c; s.Thickness=t or 2; s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; return s end

local btnGui = mk("ScreenGui", { Name="PacksButtonGui", ResetOnSpawn=false,
	IgnoreGuiInset=true, ZIndexBehavior=Enum.ZIndexBehavior.Sibling }, playerGui)
local packsBtn = mk("TextButton", {
	Name="PacksBtn", Size=UDim2.new(0,130,0,44), Position=UDim2.new(0.5,-210,0,14),
	BackgroundColor3=C.packBtn, BorderSizePixel=0, AutoButtonColor=false,
	Text="\xF0\x9F\x8E\x81  Packs", TextColor3=Color3.fromRGB(50,30,10),
	Font=Enum.Font.GothamBold, TextSize=18,
}, btnGui)
corner(packsBtn,22); stroke(packsBtn, Color3.fromRGB(180,120,40), 2)

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

packsBtn.Activated:Connect(function()
	local success, message = ArenaTravelClient.toPackShop()
	if not success then warn(message) end
end)

local lobby = workspace:WaitForChild("Lobby_MainModeZone")
local zone = lobby:WaitForChild("Lobby_PackShopZone")
local trigger = zone:WaitForChild("PackShopTrigger")
local RADIUS = 11
local inside = false

RunService.Heartbeat:Connect(function()
	local inMatch = player:GetAttribute("ActiveArena") ~= nil

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
