assert(not game:GetService("RunService"):IsRunning(), "Keep Play stopped")
local fixture=Instance.new("Folder") fixture.Name="_CoinPopupCheck" fixture.Parent=game.ServerStorage
local report={playStarted=false,checks={}}
local popup
local ok,err=xpcall(function()
 local controller=game.StarterGui.PlaygroundShell.Controller:Clone() controller.Enabled=false controller.Parent=fixture
 local helper=Instance.new("ModuleScript") helper.Name="PopupFunctions"
 helper.Source=[====[local TweenService=game:GetService("TweenService")
local gui=game.StarterGui.PlaygroundShell
local coinPopups={}
local function clearCoinPopup(popup)
	local record = coinPopups[popup]
	if not record then return end
	coinPopups[popup] = nil
	if record.completed then record.completed:Disconnect() end
	for _, tween in ipairs(record.tweens) do tween:Cancel() end
	popup:Destroy()
end

local function showCoinPickup(amount, position)
	if typeof(amount) ~= "number" or amount ~= amount or amount <= 0 or amount % 1 ~= 0 or typeof(position) ~= "Vector3" then return end
	local templates = gui:FindFirstChild("Templates")
	local template = templates and templates:FindFirstChild("CoinPickupPopup")
	local lobby = workspace:FindFirstChild("Playground Lobby")
	local gameplay = lobby and lobby:FindFirstChild("Gameplay")
	local markers = gameplay and gameplay:FindFirstChild("CoinSpawns")
	if not template or not template:IsA("BillboardGui") or not markers then return end
	local anchor, distance = nil, 8
	for _, marker in ipairs(markers:GetChildren()) do
		if marker:IsA("BasePart") then
			local gap = (marker.Position - position).Magnitude
			if gap < distance then anchor, distance = marker, gap end
		end
	end
	if not anchor then return end
	local popup = template:Clone()
	popup.Name = "CoinPickup"
	local label = popup:FindFirstChild("Amount")
	if not label or not label:IsA("TextLabel") then popup:Destroy() return end
	label.Text = "+" .. tostring(amount)
	popup.Adornee = anchor
	popup.StudsOffsetWorldSpace += position - anchor.Position
	popup.Enabled = true
	popup.Parent = gui
	local lift = TweenService:Create(popup, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffsetWorldSpace = popup.StudsOffsetWorldSpace + Vector3.new(0, 1.8, 0) })
	local fade = TweenService:Create(label, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.35), { TextTransparency = 1 })
	local record = { tweens = { lift, fade } }
	coinPopups[popup] = record
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then table.insert(record.tweens, TweenService:Create(stroke, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.35), { Transparency = 1 })) end
	record.completed = fade.Completed:Connect(function() clearCoinPopup(popup) end)
	for _, tween in ipairs(record.tweens) do tween:Play() end
	return popup
end


return {show=showCoinPickup,clear=clearCoinPopup,count=function()local count=0 for _ in pairs(coinPopups)do count+=1 end return count end}
]====]
 helper.Parent=controller
 local api=require(helper)
 local marker=workspace["Playground Lobby"].Gameplay.CoinSpawns.Coin01
 local template=game.StarterGui.PlaygroundShell.Templates.CoinPickupPopup
 local size,offset=template.Size,template.StudsOffsetWorldSpace
 popup=assert(api.show(5,marker.Position+Vector3.new(0,.15,0)))
 assert(popup.Amount.Text=="+5" and popup.Adornee==marker and popup.Enabled)
 assert(popup.Amount.BackgroundTransparency==1 and #popup:GetChildren()==1)
 table.insert(report.checks,"Minimal +5 appears at the source coin with no bar")
 local start=popup.StudsOffsetWorldSpace
 task.wait(.2)
 assert(popup.Parent and popup.StudsOffsetWorldSpace.Y>start.Y)
 table.insert(report.checks,"Real TweenService moves the amount upward")
 task.wait(1)
 assert(popup.Parent==nil and api.count()==0)
 table.insert(report.checks,"Popup fades and destroys itself after 0.9 seconds")
 assert(template.Size==size and template.StudsOffsetWorldSpace==offset and not template.Enabled and template.Amount.TextTransparency==0)
 table.insert(report.checks,"Authored template stays unchanged")
 assert(api.show(0,marker.Position)==nil and api.show(5,Vector3.new(90000,90000,90000))==nil)
 table.insert(report.checks,"Invalid or missing pickup locations create nothing")
 popup=api.show(5,marker.Position) api.clear(popup)
 assert(not popup.Parent and api.count()==0)
 table.insert(report.checks,"Cleanup cancels an active popup safely")
end,debug.traceback)
if popup and popup.Parent then popup:Destroy()end
fixture:Destroy()
report.passed=ok report.error=not ok and err or nil
return report
