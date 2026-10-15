-- Cosmetic only: the server independently rejects spike damage for this player.
local p=game.Players.LocalPlayer
local parts={}
local hidden=false
local function isSpike(part)
 local v=part.Parent
 while v and v~=workspace do
  if v.Name=="Red_Spiked_Wheel" then return true end
  v=v.Parent
 end
 return false
end
local function update()
 local enabled=(p:GetAttribute("GBloxAntispikeUntil") or 0)>workspace:GetServerTimeNow() and p:GetAttribute("RunnerStatus")=="Running"
 if enabled~=hidden then
  hidden=enabled
  if enabled then
   for _,v in workspace:GetDescendants() do
    if v:IsA("BasePart") and isSpike(v) then parts[v]=v.LocalTransparencyModifier v.LocalTransparencyModifier=1 end
   end
  else
   for v,original in parts do if v.Parent then v.LocalTransparencyModifier=original end end
   table.clear(parts)
  end
 end
end
workspace.DescendantAdded:Connect(function(v)
 if hidden and v:IsA("BasePart") and isSpike(v) then parts[v]=v.LocalTransparencyModifier v.LocalTransparencyModifier=1 end
end)
p:GetAttributeChangedSignal("GBloxAntispikeUntil"):Connect(update)
p:GetAttributeChangedSignal("RunnerStatus"):Connect(update)
local elapsed=0
game:GetService("RunService").Heartbeat:Connect(function(dt) elapsed+=dt if elapsed>.1 then elapsed=0 update() end end)

