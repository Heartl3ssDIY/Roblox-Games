local p=game.Players.LocalPlayer
local Artwork=require(game:GetService("ReplicatedStorage"):WaitForChild("GBloxUIArtwork"))
local UIS=game:GetService("UserInputService")
local function character(c)
 local h=c:WaitForChild("Humanoid")
 h:SetStateEnabled(Enum.HumanoidStateType.Jumping,true)
 if h.UseJumpPower and h.JumpPower<=0 then h.JumpPower=50 end
 if not h.UseJumpPower and h.JumpHeight<=0 then h.JumpHeight=7.2 end
end
p.CharacterAdded:Connect(character) if p.Character then task.spawn(character,p.Character) end
-- Explicit touch jump remains available even if the stock touch controls hide it.
if UIS.TouchEnabled then
 local gui=Instance.new("ScreenGui") gui.Name="LobbyJumpUI" gui.ResetOnSpawn=false gui.ScreenInsets=Enum.ScreenInsets.DeviceSafeInsets gui.Parent=p:WaitForChild("PlayerGui")
 local b=Instance.new("TextButton") b.Name="Jump" b.AnchorPoint=Vector2.new(1,1) b.Position=UDim2.new(1,-20,1,-105) b.Size=UDim2.fromOffset(92,58) b.Text="JUMP" b.Font=Enum.Font.Arcade b.TextSize=12 b.TextColor3=Color3.new(1,1,1) b.BackgroundColor3=Color3.fromRGB(0,134,155) b.Parent=gui
 local corner=Instance.new("UICorner") corner.CornerRadius=UDim.new(1,0) corner.Parent=b
 Artwork.Button(b)
 b.Activated:Connect(function()
  if p:GetAttribute("OnTreadmill") then return end
  local h=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
  if h and h.Health>0 then h.Jump=true end
 end)
end
