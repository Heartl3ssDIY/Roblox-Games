assert(not game:GetService("RunService"):IsRunning())
local gui=assert(game:GetService("StarterGui"):FindFirstChild("HideAndSeekHUD"))
local backup=game:GetService("ServerStorage").SchoolBeforePolish20261010
if not backup:FindFirstChild("HideAndSeekHUD") then gui:Clone().Parent=backup end
local changed=0
for _,label in gui:GetDescendants() do if label:IsA("TextLabel") or label:IsA("TextButton") then
label.TextTruncate=Enum.TextTruncate.None label.TextWrapped=true label.TextScaled=true changed+=1 end end
return {labels=changed}
