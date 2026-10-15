local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Run=game:GetService("RunService")
local Renderer=require(RS:WaitForChild("GBloxRaceVFXRenderer"))
local remote=RS:WaitForChild("GBloxRaceVFX")
local folder=Instance.new("Folder") folder.Name="GBloxLocalRaceVFX" folder.Parent=workspace
local active={} local fades={} local lastId=0
local function restore(player)
 local f=fades[player] if not f then return end
 fades[player]=nil
 for _,entry in f.parts do
  if entry.part.Parent then entry.part[entry.property]=entry.original end
 end
 for _,entry in f.labels do if entry.gui.Parent then entry.gui.Enabled=entry.enabled end end
end
local function beginFade(player,packet)
 if not packet.Terminal then return end
 local char=packet.Character
 if not player or not char or player.Character~=char then return end
 restore(player)
 local f={character=char,version=packet.CourseVersion,origin=packet.Origin.Position,started=os.clock(),
  status=packet.Kind=="GreenFinish" and "Finished" or "Out",duration=packet.Kind=="GreenFinish" and .7 or .18,parts={},labels={}}
 for _,object in char:GetDescendants() do
  if object:IsA("BasePart") then
   table.insert(f.parts,{part=object,property="LocalTransparencyModifier",original=object.LocalTransparencyModifier})
  elseif object:IsA("Decal") or object:IsA("Texture") then
   table.insert(f.parts,{part=object,property="Transparency",original=object.Transparency})
  elseif object:IsA("BillboardGui") then
   table.insert(f.labels,{gui=object,enabled=object.Enabled}) object.Enabled=false
  end
 end
 fades[player]=f
end
remote.OnClientEvent:Connect(function(packet)
 if type(packet)~="table" or not Renderer.Duration[packet.Kind] or typeof(packet.Origin)~="CFrame"
  or type(packet.Id)~="number" or packet.Id<=lastId or type(packet.At)~="number" then return end
 lastId=packet.Id
 local age=workspace:GetServerTimeNow()-packet.At
 if age>2 or age< -1 then return end
 local camera=workspace.CurrentCamera
 if camera and (camera.CFrame.Position-packet.Origin.Position).Magnitude>350 then return end
 local owner=Players:GetPlayerByUserId(packet.UserId)
 if owner and owner:GetAttribute("RunnerCourseVersion")~=packet.CourseVersion then return end
 local ok,result=pcall(Renderer.Create,packet,folder)
 if not ok or not result then warn("[RaceVFX] Could not create effect",result) return end
 if #active>=12 then active[1].handle:Destroy() table.remove(active,1) end
 table.insert(active,{handle=result,started=os.clock()})
 task.defer(function() result:Burst() end)
 beginFade(owner,packet)
end)
local budget=0
Run.Heartbeat:Connect(function(dt)
 budget+=dt if budget<1/30 then return end budget=0
 local now=os.clock()
 for i=#active,1,-1 do
  local effect=active[i]
  if not effect.handle:Update(now-effect.started) then effect.handle:Destroy() table.remove(active,i) end
 end
 for player,f in fades do
  local root=f.character:FindFirstChild("HumanoidRootPart")
  local status=player:GetAttribute("RunnerStatus")
  local invalid=not player.Parent or player.Character~=f.character or not f.character.Parent
   or player:GetAttribute("RunnerCourseVersion")~=f.version or player:GetAttribute("GBloxPodiumActive")
   or not root or (root.Position-f.origin).Magnitude>12
  -- Give replicated status a brief moment to arrive, but never hide an active runner.
  if not invalid and status~=f.status then
   invalid=now-f.started>.2 or status~="Running"
  end
  if invalid then restore(player)
  elseif status==f.status then
   local alpha=math.clamp((now-f.started)/f.duration,0,1)
   for _,entry in f.parts do if entry.part.Parent then entry.part[entry.property]=entry.original+(1-entry.original)*alpha end end
  end
 end
end)
Players.PlayerRemoving:Connect(restore)
script.Destroying:Connect(function()
 for player in fades do restore(player) end
 folder:Destroy()
end)

