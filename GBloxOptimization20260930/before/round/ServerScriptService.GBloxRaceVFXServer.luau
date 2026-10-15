-- Server-only cosmetic notifications. No client can request or award a finish/death.
local RS=game:GetService("ReplicatedStorage")
local remote=RS:FindFirstChild("GBloxRaceVFX") or Instance.new("RemoteEvent")
remote.Name="GBloxRaceVFX" remote.Parent=RS
local V={}
local serial=0
function V.Emit(player,data,kind,courseVersion,terminal)
 if kind~="DefaultDeath" and kind~="GreenFinish" then return false end
 if not player or not data or not data.root or not data.root.Parent then return false end
 local position=data.root.Position
 if position.X~=position.X or position.Magnitude==math.huge then return false end
 serial+=1
 remote:FireAllClients({
  Id=serial,Seed=serial,Kind=kind,UserId=player.UserId,
  Character=data.character,Origin=data.root.CFrame,CourseVersion=courseVersion,
  At=workspace:GetServerTimeNow(),Terminal=terminal==true,
 })
 return true
end
return V

