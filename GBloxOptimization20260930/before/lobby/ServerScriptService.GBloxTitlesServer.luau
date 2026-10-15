-- Shared lobby/match overhead titles and server-validated equipment.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Data=require(game.ServerScriptService:WaitForChild("PlayerData"))
local remote=RS:FindFirstChild("GBloxTitleEquip") or Instance.new("RemoteFunction")
remote.Name="GBloxTitleEquip" remote.Parent=RS
local last,busy,connections={},{},{}
remote.OnServerInvoke=function(player,id)
 if typeof(id)~="string" or #id>64 then return false,"Invalid title." end
 if busy[player] or os.clock()-(last[player] or -math.huge)<.5 then return false,"Please wait a moment." end
 last[player]=os.clock() busy[player]=true
 local ok,success,message=pcall(Data.SetEquippedTitle,player,id)
 busy[player]=nil
 if not ok then warn("[Titles] Equip failed:",success) return false,"Couldn't equip your title. Please try again." end
 return success,message
end
local function update(player)
 local character=player.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 local humanoid=character and character:FindFirstChildOfClass("Humanoid")
 if not root or not humanoid then return end
 local gui=character:FindFirstChild("GBloxOverheadTitle")
 if not gui then
  gui=Instance.new("BillboardGui") gui.Name="GBloxOverheadTitle"
  gui.Size=UDim2.fromOffset(220,54)
  gui.Adornee=root gui.StudsOffsetWorldSpace=Vector3.new(0,4.2,0)
  gui.AlwaysOnTop=false gui.LightInfluence=0 gui.MaxDistance=160
  for i,name in {"Title","PlayerName"} do
   local label=Instance.new("TextLabel") label.Name=name
   label.BackgroundTransparency=1 label.Size=UDim2.new(1,0,.5,0)
   label.Position=UDim2.fromScale(0,(i-1)*.5)
   label.Font=Enum.Font.Arcade label.TextScaled=true label.RichText=false
   label.TextColor3=Color3.new(1,1,1) label.TextStrokeColor3=Color3.fromRGB(0,13,22)
   label.TextStrokeTransparency=.05
   local limit=Instance.new("UITextSizeConstraint") limit.MaxTextSize=i==1 and 18 or 16 limit.MinTextSize=8 limit.Parent=label
   label.Parent=gui
  end
  gui.Parent=character
 end
 humanoid.NameDisplayDistance=0
 gui.Enabled=player:GetAttribute("PlayerDataReady")==true
 gui.Title.Text=player:GetAttribute("GBloxTitleName") or ""
 gui.Title.TextColor3=player:GetAttribute("GBloxTitleColor") or Color3.new(1,1,1)
 gui.PlayerName.Text=player.DisplayName
end
local function added(player)
 if connections[player] then return end
 local list={} connections[player]=list
 for _,attr in {"GBloxTitleName","GBloxTitleColor","PlayerDataReady"} do
  table.insert(list,player:GetAttributeChangedSignal(attr):Connect(function() update(player) end))
 end
 table.insert(list,player.CharacterAdded:Connect(function(character)
  character:WaitForChild("HumanoidRootPart",10)
  character:WaitForChild("Humanoid",10)
  if player.Parent and player.Character==character then update(player) end
 end))
 update(player)
end
Players.PlayerAdded:Connect(added)
Players.PlayerRemoving:Connect(function(player)
 for _,c in connections[player] or {} do c:Disconnect() end
 connections[player]=nil last[player]=nil busy[player]=nil
end)
for _,player in Players:GetPlayers() do added(player) end

