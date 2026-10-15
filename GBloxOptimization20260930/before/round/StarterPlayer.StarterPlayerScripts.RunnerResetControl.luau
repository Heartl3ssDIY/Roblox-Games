-- Disable manual Roblox-menu Reset; never change automatic death recovery or Second Life.
local player=game.Players.LocalPlayer
local StarterGui=game:GetService("StarterGui")
local Policy=require(game.ReplicatedStorage:WaitForChild("RunnerResetPolicy"))
local revision=0
local function update()
 revision+=1
 local token=revision
 local allowed=Policy.Allow(workspace:GetAttribute("RunnerRoundPhase"),player:GetAttribute("RunnerStatus"),player:GetAttribute("GBloxPodiumActive"))
 task.spawn(function()
  for attempt=1,60 do
   if token~=revision then return end
   local ok=pcall(function() StarterGui:SetCore("ResetButtonCallback",allowed) end)
   if ok then player:SetAttribute("RunnerManualResetDisabled",not allowed) return end
   task.wait(.25)
  end
  warn("[RunnerReset] Roblox reset menu was not ready.")
 end)
end
workspace:GetAttributeChangedSignal("RunnerRoundPhase"):Connect(update)
player:GetAttributeChangedSignal("RunnerStatus"):Connect(update)
player:GetAttributeChangedSignal("GBloxPodiumActive"):Connect(update)
player.CharacterAdded:Connect(update)
update()

