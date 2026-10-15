local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local UserInputService=game:GetService("UserInputService")

local ADMIN_USER_ID=1201803949
local player=Players.LocalPlayer
local gui=script.Parent

if player.UserId~=ADMIN_USER_ID then
 gui.Enabled=false
 return
end

local remote=ReplicatedStorage:WaitForChild("GBloxAdminRequest")
local Catalog=require(ReplicatedStorage:WaitForChild("GBloxPetCatalog"))

local toggle=gui:WaitForChild("AdminToggle")
local panel=gui:WaitForChild("Panel")
local close=panel:WaitForChild("Close")
local balances=panel:WaitForChild("Balances")
local equipped=panel:WaitForChild("Equipped")
local amountBox=panel:WaitForChild("Amount")
local targetBox=panel:WaitForChild("TargetPlayer")
local status=panel:WaitForChild("Status")
local cash10=panel:WaitForChild("Cash10K")
local cash100=panel:WaitForChild("Cash100K")
local trophy1=panel:WaitForChild("Trophy1K")
local trophy10=panel:WaitForChild("Trophy10K")
local customCash=panel:WaitForChild("CustomCash")
local customTrophy=panel:WaitForChild("CustomTrophy")
local testCash=panel:WaitForChild("TestCashMultiplier")
local giveTarget=panel:WaitForChild("GiveTargetTrophies")
local takeTarget=panel:WaitForChild("TakeTargetTrophies")
local giveCash=panel:WaitForChild("GiveTargetCash")
local panelScale=panel:WaitForChild("ResponsiveScale")
local viewportConnection
local function resizePanel()
 local camera=workspace.CurrentCamera
 local viewport=camera and camera.ViewportSize or Vector2.new(1280,720)
 local top=panel.Position.Y.Scale*viewport.Y+panel.Position.Y.Offset
 panelScale.Scale=math.clamp(math.min((viewport.Y-top-16)/panel.Size.Y.Offset,(viewport.X-48)/panel.Size.X.Offset),.15,1)
end
local function bindCamera()
 if viewportConnection then viewportConnection:Disconnect() end
 local camera=workspace.CurrentCamera
 if camera then viewportConnection=camera:GetPropertyChangedSignal("ViewportSize"):Connect(resizePanel) end
 resizePanel()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
bindCamera()

local function formatNumber(value)
 local text=tostring(math.floor(tonumber(value) or 0))
 repeat
  local changed
  text,changed=string.gsub(text,"^(-?%d+)(%d%d%d)","%1,%2")
 until changed==0
 return text
end

local function refresh()
 local cash=player:GetAttribute("Cash") or 0
 local trophies=player:GetAttribute("Trophies") or 0
 balances.Text="CASH  $"..formatNumber(cash).."\nTROPHIES  "..formatNumber(trophies)
 local petId=player:GetAttribute("GBloxEquippedPet")
 local pet=petId and Catalog.GetPet(petId)
 if pet then
  equipped.Text=string.format("EQUIPPED: %s   ×%g CASH   ×%g TROPHIES",string.upper(petId),pet.CashMultiplier,pet.TrophyMultiplier)
 else
  equipped.Text="EQUIPPED: NONE   ×1 CASH   ×1 TROPHIES"
 end
end

local function customAmount()
 local cleaned=string.gsub(amountBox.Text,"[^%d]","")
 return math.clamp(tonumber(cleaned) or 0,1,1000000)
end

local requestPending=false
local function grant(currency,amount,target)
 if requestPending then return end
 requestPending=true
 status.Text="Sending secure grant..."
 status.TextColor3=Color3.fromRGB(255,226,92)
 remote:FireServer(currency,amount,target)
end

cash10.Activated:Connect(function() grant("Cash",10000) end)
cash100.Activated:Connect(function() grant("Cash",100000) end)
trophy1.Activated:Connect(function() grant("Trophies",1000) end)
trophy10.Activated:Connect(function() grant("Trophies",10000) end)
customCash.Activated:Connect(function() grant("Cash",customAmount()) end)
customTrophy.Activated:Connect(function() grant("Trophies",customAmount()) end)
testCash.Activated:Connect(function() grant("EarnedCash",100) end)
giveTarget.Activated:Connect(function() grant("AdjustTrophies",customAmount(),targetBox.Text) end)
takeTarget.Activated:Connect(function() grant("AdjustTrophies",-customAmount(),targetBox.Text) end)

giveCash.Activated:Connect(function()
 local cleaned=string.gsub(amountBox.Text,"[, %s]","")
 local amount=tonumber(cleaned)
 if not string.match(cleaned,"^%d+$") or not amount or amount<1 or amount>1000000 then
  status.Text="Enter a whole cash amount from 1 to 1,000,000."
  status.TextColor3=Color3.fromRGB(255,103,124)
  return
 end
 grant("GiveTargetCash",amount,targetBox.Text)
end)

local function setOpen(open)
 panel.Visible=open
 toggle.Text=open and "CLOSE  [F2]" or "ADMIN  [F2]"
end

toggle.Activated:Connect(function() setOpen(not panel.Visible) end)
close.Activated:Connect(function() setOpen(false) end)
UserInputService.InputBegan:Connect(function(input,processed)
 if not processed and input.KeyCode==Enum.KeyCode.F2 then setOpen(not panel.Visible) end
end)

remote.OnClientEvent:Connect(function(payload)
 if typeof(payload)~="table" then return end
 task.delay(.2,function() requestPending=false end)
 status.Text=payload.Message or (payload.Ok and "Grant complete." or "Grant failed.")
 status.TextColor3=payload.Ok and Color3.fromRGB(99,255,174) or Color3.fromRGB(255,103,124)
 refresh()
end)

player:GetAttributeChangedSignal("Cash"):Connect(refresh)
player:GetAttributeChangedSignal("Trophies"):Connect(refresh)
player:GetAttributeChangedSignal("GBloxEquippedPet"):Connect(refresh)
refresh()

