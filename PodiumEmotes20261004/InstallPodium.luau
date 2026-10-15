assert(not game:GetService("RunService"):IsRunning(), "Install in Edit mode")
local lobby = workspace:WaitForChild("Playground Lobby")
local StarterGui = game:GetService("StarterGui")
local storage = game:GetService("ServerStorage")
local backup = storage:FindFirstChild("PodiumEmotesBackup20261004")
if not backup then backup = Instance.new("Folder") backup.Name = "PodiumEmotesBackup20261004" backup.Parent = storage end
local old = lobby:FindFirstChild("WinnerPodium")
if old then
 assert(old:GetAttribute("PodiumVersion") == 1, "Inspect the existing podium before replacing")
 if not backup:FindFirstChild("PreviousPodium") then local saved = old:Clone() saved.Name = "PreviousPodium" saved.Parent = backup end
 old:Destroy()
end
local model = Instance.new("Model")
model.Name = "WinnerPodium"
model:SetAttribute("PodiumVersion", 1)
model.Parent = lobby
local ink = Color3.fromRGB(27, 42, 65)
local cream = Color3.fromRGB(255, 249, 224)
local gold = Color3.fromRGB(255, 205, 57)
local silver = Color3.fromRGB(185, 205, 226)
local bronze = Color3.fromRGB(195, 132, 78)
local blue = Color3.fromRGB(42, 177, 232)
local center = Vector3.new(22, 0, -82)
local function part(name, size, position, color, parent, collidable, studs)
 local p = Instance.new("Part")
 p.Name = name p.Size = size p.CFrame = CFrame.new(center + position)
 p.Material = Enum.Material.SmoothPlastic
 p.MaterialVariant = studs and "PlaygroundRetroStuds" or ""
 p.Color = color p.Anchored = true p.Locked = true
 p.CanCollide = collidable == true p.CanTouch = false p.CanQuery = true
 p.TopSurface = Enum.SurfaceType.Smooth p.BottomSurface = Enum.SurfaceType.Smooth
 p.Parent = parent or model
 return p
end
part("StageInk", Vector3.new(27, 0.38, 12), Vector3.new(0, 4.21, 0), ink, model, false)
part("Stage", Vector3.new(26.4, 0.4, 11.4), Vector3.new(0, 4.6, 0), cream, model, true, true)
part("FrontStepInk", Vector3.new(21, 0.28, 2.3), Vector3.new(0, 4.16, 6.1), ink, model, false)
part("FrontStep", Vector3.new(20.6, 0.22, 2.0), Vector3.new(0, 4.38, 6.1), blue, model, true, true)
for _, side in ipairs({-1, 1}) do
 part("HeaderPost"..side, Vector3.new(0.45, 15.4, 0.55), Vector3.new(side*12.3, 12.45, -4.35), ink)
 part("HeaderPostInset"..side, Vector3.new(0.17, 14.8, 0.14), Vector3.new(side*12.3, 12.45, -4.02), blue)
end
part("HeaderInk", Vector3.new(26, 4.3, 0.65), Vector3.new(0, 19.65, -4.35), ink)
part("HeaderRim", Vector3.new(25.6, 3.9, 0.22), Vector3.new(0, 19.65, -3.94), gold)
local headerFace = part("HeaderFace", Vector3.new(25.15, 3.45, 0.08), Vector3.new(0, 19.65, -3.77), cream)
headerFace.CFrame *= CFrame.Angles(0, math.pi, 0)
part("HeaderTopLip", Vector3.new(26.6, 0.35, 1.0), Vector3.new(0, 21.97, -4.22), blue, model, false, true)
local currentGui = StarterGui:FindFirstChild("PlaygroundPodium")
if currentGui then
 assert(currentGui:GetAttribute("PodiumVersion")==1, "Inspect existing podium UI")
 if not backup:FindFirstChild("PreviousPodiumGui")then local saved=currentGui:Clone() saved.Name="PreviousPodiumGui" saved.Parent=backup end
 currentGui:Destroy()
end
local gui = Instance.new("ScreenGui")
gui.Name = "PlaygroundPodium" gui.ResetOnSpawn = false gui.Enabled = true
gui:SetAttribute("PodiumVersion",1)
gui:SetAttribute("PodiumAnimationId","")
gui.Parent = StarterGui
local function surface(name, adornee, size)
 local s = Instance.new("SurfaceGui")
 s.Name=name s.Adornee=adornee s.Face=Enum.NormalId.Front
 s.CanvasSize=size s.SizingMode=Enum.SurfaceGuiSizingMode.FixedSize
 s.LightInfluence=0 s.AlwaysOnTop=false s.MaxDistance=160 s.ResetOnSpawn=false
 s.ZIndexBehavior=Enum.ZIndexBehavior.Sibling s.Parent=gui
 return s
end
local function label(parent,name,text,pos,size,maximum,color)
 local t=Instance.new("TextLabel")
 t.Name=name t.Text=text t.BackgroundTransparency=1 t.BorderSizePixel=0
 t.Position=pos t.Size=size t.Font=Enum.Font.FredokaOne
 t.TextColor3=color or cream t.TextWrapped=false t.TextScaled=true
 t.TextXAlignment=Enum.TextXAlignment.Center t.TextYAlignment=Enum.TextYAlignment.Center
 t.TextTruncate=Enum.TextTruncate.AtEnd t.ZIndex=5
 local constraint=Instance.new("UITextSizeConstraint")
 constraint.MinTextSize=10 constraint.MaxTextSize=maximum constraint.Parent=t
 local stroke=Instance.new("UIStroke")
 stroke.Name="TextOutline" stroke.Color=ink stroke.Thickness=2.5
 stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual
 stroke.BorderStrokePosition=Enum.BorderStrokePosition.Outer
 stroke.LineJoinMode=Enum.LineJoinMode.Round stroke.Parent=t
 t.Parent=parent return t
end
local header=surface("Header",headerFace,Vector2.new(1100,152))
label(header,"Title","PLAYGROUND CHAMPIONS",UDim2.fromScale(.04,.05),UDim2.fromScale(.92,.43),58,gold)
label(header,"Subtitle","MOST WINS · GLOBAL",UDim2.fromScale(.08,.51),UDim2.fromScale(.84,.23),30)
label(header,"Hint","CHOOSE A LEADERBOARD TAB TO CHANGE THE PODIUM",UDim2.fromScale(.05,.78),UDim2.fromScale(.90,.15),17)
local specs = {
 {rank=1,x=0,height=4.6,color=gold},
 {rank=2,x=-8.25,height=3.35,color=silver},
 {rank=3,x=8.25,height=2.55,color=bronze},
}
for _, spec in ipairs(specs)do
 local rank = Instance.new("Model") rank.Name="Rank"..spec.rank rank.Parent=model
 local bottom=4.8 local top=bottom+spec.height
 part("BlockInk",Vector3.new(7.7,spec.height,7.8),Vector3.new(spec.x,bottom+spec.height/2,0),ink,rank,false)
 part("Block",Vector3.new(7.3,spec.height-.24,7.4),Vector3.new(spec.x,bottom+spec.height/2+.02,0),spec.color,rank,true,true)
 part("FootTrim",Vector3.new(7.65,.24,7.75),Vector3.new(spec.x,bottom+.12,0),ink,rank,false)
 part("CapInk",Vector3.new(8.0,.22,8),Vector3.new(spec.x,top+.04,0),ink,rank,false)
 local topPart=part("Top",Vector3.new(7.65,.22,7.65),Vector3.new(spec.x,top+.24,0),spec.color:Lerp(cream,.32),rank,true,true)
 local attachment=Instance.new("Attachment") attachment.Name="StandingPoint"
 attachment.Position=Vector3.new(0,.11,0) attachment.Parent=topPart
 local plateHeight=math.min(2.55,spec.height-.45)
 part("PlateInk",Vector3.new(6.95,plateHeight+.15,.20),Vector3.new(spec.x,bottom+spec.height*.49,3.81),ink,rank)
 local plate=part("Face",Vector3.new(6.65,plateHeight-.05,.10),Vector3.new(spec.x,bottom+spec.height*.49,3.97),cream,rank)
 plate.CFrame*=CFrame.Angles(0,math.pi,0)
 local display=surface("Rank"..spec.rank,plate,Vector2.new(600,195))
 label(display,"RankNumber",tostring(spec.rank),UDim2.fromScale(.02,.08),UDim2.fromScale(.20,.82),104,spec.color)
 label(display,"NameLabel","WAITING FOR SCORES",UDim2.fromScale(.25,.10),UDim2.fromScale(.70,.30),44)
 label(display,"ScoreLabel","—",UDim2.fromScale(.25,.45),UDim2.fromScale(.70,.25),36,spec.color)
 label(display,"StatusLabel","GLOBAL",UDim2.fromScale(.25,.77),UDim2.fromScale(.70,.14),22)
 for _, dx in ipairs({-1,1})do
  part("CornerPin"..dx,Vector3.new(.16,.16,.10),Vector3.new(spec.x+dx*3.23,bottom+spec.height*.49+plateHeight*.37,4.04),spec.color,rank)
 end
end
local tree=lobby.Nature:FindFirstChild("Tree23")
if tree and not tree:GetAttribute("PodiumOriginalPivot")then
 tree:SetAttribute("PodiumOriginalPivot",tree:GetPivot())
 tree:PivotTo(tree:GetPivot()+Vector3.new(23,0,-8))
end
local boards=StarterGui:WaitForChild("PlaygroundLeaderboards")
boards:SetAttribute("PodiumBoard","MostWins")
boards:SetAttribute("PodiumScope","global")
boards:SetAttribute("PodiumSnapshot",nil)
local controller=game.StarterPlayer.StarterPlayerScripts.PlaygroundEmotes:Clone()
controller.Name="Controller" controller.Source="" controller.Disabled=true controller.Parent=gui
return {podium=model:GetFullName(),gui=gui:GetFullName(),treeRepositioned=tree~=nil,controller=controller:GetFullName()}

