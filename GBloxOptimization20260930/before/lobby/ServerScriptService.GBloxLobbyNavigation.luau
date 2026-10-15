local Players = game:GetService("Players")
local remote = game.ReplicatedStorage:WaitForChild("GBloxLobbyNavigate")
local targets = workspace:WaitForChild("LobbyNavigationTargets")
local last = {}
remote.OnServerEvent:Connect(function(player, destination)
 if typeof(destination)~="string" or not ({Play=true,Eggs=true,Shops=true})[destination] then return end
 if not player:GetAttribute("GBloxLobbyReady") or player:GetAttribute("GBloxInParty") or player:GetAttribute("OnTreadmill") then return end
 if os.clock()-(last[player] or -math.huge)<1 then return end
 local character=player.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 local hum=character and character:FindFirstChildOfClass("Humanoid")
 local target=targets:FindFirstChild(destination)
 if not root or not hum or hum.Health<=0 or root.Anchored or hum.Sit or not target then return end
 last[player]=os.clock()
 local leg=character:FindFirstChild("Left Leg")
 local height=root.Size.Y/2+hum.HipHeight+(hum.RigType==Enum.HumanoidRigType.R6 and (leg and leg.Size.Y or 2) or 0)
 root.CFrame=target.CFrame+Vector3.new(0,height+.2,0)
 root.AssemblyLinearVelocity=Vector3.zero
 root.AssemblyAngularVelocity=Vector3.zero
end)
Players.PlayerRemoving:Connect(function(player) last[player]=nil end)

