--!strict
-- PackShopUI: the packs-only shop, opened by walking into the pack ring.
-- Shows unit packs (Silver/Gold/Diamond, gems) + 2 daily Common Bit Packs (Robux).
-- Gem packs deduct gems (pull logic / drop rates come later). Robux = stub.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ShopConfig = require(ReplicatedStorage:WaitForChild("ShopConfig"))
local PlayerData = require(ReplicatedStorage:WaitForChild("PlayerData"))
local PackOpening = require(ReplicatedStorage:WaitForChild("PackOpening"))
local PackReveal = require(ReplicatedStorage:WaitForChild("PackReveal"))

local C = {
	bg     = Color3.fromRGB(18, 12, 36),
	panel  = Color3.fromRGB(32, 20, 62),
	border = Color3.fromRGB(148, 88, 255),
	btnBg  = Color3.fromRGB(50, 28, 98),
	btnHov = Color3.fromRGB(78, 48, 145),
	btnTxt = Color3.fromRGB(230, 210, 255),
	sub    = Color3.fromRGB(155, 130, 195),
	gold   = Color3.fromRGB(255, 210, 80),
	gem    = Color3.fromRGB(110, 220, 255),
	robux  = Color3.fromRGB(90, 215, 130),
	close  = Color3.fromRGB(200, 70, 95),
}
local function mk(class, props, parent)
	local o = Instance.new(class)
	for k,v in pairs(props) do o[k]=v end
	o.Parent = parent
	return o
end
local function corner(p,r) Instance.new("UICorner", p).CornerRadius = UDim.new(0, r or 12) end
local function stroke(p,col,th)
	local s = Instance.new("UIStroke", p); s.Color=col; s.Thickness=th or 2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; return s
end

local PackShopUI = {}
local gui = nil   -- the ScreenGui, built once

local function buildGui(playerGui)
	gui = mk("ScreenGui", { Name = "PackShopGui", ResetOnSpawn = false,
		IgnoreGuiInset = true, Enabled = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, playerGui)

	local panel = mk("Frame", {
		Name = "Panel", Size = UDim2.new(0, 720, 0, 420),
		AnchorPoint = Vector2.new(0.5,0.5), Position = UDim2.new(0.5,0,0.5,0),
		BackgroundColor3 = C.bg, BorderSizePixel = 0,
	}, gui)
	corner(panel, 22); stroke(panel, C.border, 3)

	-- header
	mk("TextLabel", {
		Name = "Title", Size = UDim2.new(1,-120,0,50), Position = UDim2.new(0,24,0,12),
		BackgroundTransparency = 1, Text = "\xF0\x9F\x8E\x81  PACKS", TextColor3 = C.gold,
		Font = Enum.Font.GothamBold, TextSize = 26, TextXAlignment = Enum.TextXAlignment.Left,
	}, panel)
	local closeBtn = mk("TextButton", {
		Name = "Close", Size = UDim2.new(0,36,0,36), Position = UDim2.new(1,-48,0,16),
		BackgroundColor3 = C.close, BorderSizePixel = 0, Text = "\xE2\x9C\x95",
		TextColor3 = Color3.fromRGB(255,255,255), Font = Enum.Font.GothamBold, TextSize = 16,
	}, panel)
	corner(closeBtn, 18)
	closeBtn.Activated:Connect(function() gui.Enabled = false end)

	-- pack cards row (Silver/Gold/Diamond)
	local row = mk("Frame", {
		Name = "PackRow", Size = UDim2.new(1,-48,0,220), Position = UDim2.new(0,24,0,72),
		BackgroundTransparency = 1,
	}, panel)
	mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0,18) }, row)

	local function packCard(spec, order)
		local card = mk("Frame", {
			Name = "Pack_"..spec.id, Size = UDim2.new(0, 200, 1, 0),
			BackgroundColor3 = C.panel, BorderSizePixel = 0, LayoutOrder = order,
		}, row)
		corner(card, 16); stroke(card, spec.color, 3)
		mk("TextLabel", { Size = UDim2.new(1,0,0,40), Position = UDim2.new(0,0,0,16),
			BackgroundTransparency = 1, Text = spec.name, TextColor3 = spec.color,
			Font = Enum.Font.GothamBold, TextSize = 20 }, card)
		-- placeholder pack art block
		local art = mk("Frame", { Size = UDim2.new(0,120,0,90), Position = UDim2.new(0.5,-60,0,60),
			BackgroundColor3 = spec.color, BorderSizePixel = 0 }, card)
		corner(art, 12); art.BackgroundTransparency = 0.55
		mk("TextLabel", { Size=UDim2.new(1,0,1,0), BackgroundTransparency=1, Text="\xF0\x9F\x8E\x81",
			TextSize=44, Font=Enum.Font.GothamBold, TextColor3=spec.color }, art)
		-- buy button
		local buy = mk("TextButton", { Size = UDim2.new(1,-32,0,42), Position = UDim2.new(0,16,1,-54),
			BackgroundColor3 = C.btnBg, BorderSizePixel = 0, AutoButtonColor = false,
			Text = "\xF0\x9F\x92\x8E "..spec.cost, TextColor3 = C.gem,
			Font = Enum.Font.GothamBold, TextSize = 18 }, card)
		corner(buy, 12); stroke(buy, spec.color, 1)
		buy.MouseEnter:Connect(function() buy.BackgroundColor3 = C.btnHov end)
		buy.MouseLeave:Connect(function() buy.BackgroundColor3 = C.btnBg end)
		buy.Activated:Connect(function()
			-- Diamond rates aren't defined yet — guard against opening it.
			if not PackOpening.PACKS[spec.id] then
				local orig = buy.BackgroundColor3
				buy.BackgroundColor3 = Color3.fromRGB(120,90,40)
				buy.Text = "Coming soon"
				task.delay(0.8, function() buy.BackgroundColor3 = orig; buy.Text = "\xF0\x9F\x92\x8E "..spec.cost end)
				return
			end
			if PlayerData.spendGems(spec.cost) then
				-- Open instantly: roll + grant, then play the reveal animation.
				local result = PackOpening.open(spec.id)
				local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
				if playerGui and result then
					gui.Enabled = false   -- hide the shop behind the reveal
					PackReveal.play(playerGui, result, function()
						if gui then gui.Enabled = true end   -- back to the shop after
					end)
				end
			else
				local orig = buy.BackgroundColor3
				buy.BackgroundColor3 = Color3.fromRGB(170,50,50)
				task.delay(0.5, function() buy.BackgroundColor3 = orig end)
			end
		end)
	end
	for i, spec in ipairs(ShopConfig.packs) do packCard(spec, i) end

	-- daily bit packs row
	local bitRow = mk("Frame", {
		Name = "BitRow", Size = UDim2.new(1,-48,0,80), Position = UDim2.new(0,24,1,-96),
		BackgroundTransparency = 1,
	}, panel)
	mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0,18) }, bitRow)
	for i, spec in ipairs(ShopConfig.bitPacks) do
		local cell = mk("Frame", { Size = UDim2.new(0,200,1,0), BackgroundColor3 = C.panel,
			BorderSizePixel = 0, LayoutOrder = i }, bitRow)
		corner(cell, 12); stroke(cell, C.border, 1)
		mk("TextLabel", { Size=UDim2.new(1,-12,0,24), Position=UDim2.new(0,12,0,8), BackgroundTransparency=1,
			Text=spec.name, TextColor3=C.btnTxt, Font=Enum.Font.GothamBold, TextSize=14,
			TextXAlignment=Enum.TextXAlignment.Left }, cell)
		local buy = mk("TextButton", { Size=UDim2.new(1,-24,0,34), Position=UDim2.new(0,12,1,-42),
			BackgroundColor3=C.btnBg, BorderSizePixel=0, AutoButtonColor=false,
			Text="\xF0\x9F\x92\xB0 "..spec.cost, TextColor3=C.robux, Font=Enum.Font.GothamBold, TextSize=15 }, cell)
		corner(buy, 10); stroke(buy, C.robux, 1)
		buy.Activated:Connect(function()
			if spec.daily and not ShopConfig.canClaim(spec.id) then return end
			print("[PackShop] (stub) buy "..spec.name.." for "..spec.cost.." Robux")
		end)
	end
end

function PackShopUI.open(playerGui)
	if not gui then buildGui(playerGui) end
	gui.Enabled = true
end
function PackShopUI.close()
	if gui then gui.Enabled = false end
end
function PackShopUI.isOpen()
	return gui ~= nil and gui.Enabled
end

return PackShopUI
