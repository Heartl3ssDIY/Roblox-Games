local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local entries = HttpService:JSONDecode("[{\"key\":\"Tenkaichi\",\"displayName\":\"Tenkaichi\",\"modelName\":\"Arena_Tenkaichi\",\"description\":\"Fight beneath tropical skies at the Tenkaichi martial arts tournament. Draft your team and take the ring.\",\"playable\":true,\"number\":1,\"importModelName\":\"Arena_Tenkaichi\",\"teleportReady\":true},{\"key\":\"ChuninExamHall\",\"displayName\":\"Chūnin Exam Hall\",\"modelName\":\"Arena_ChuninExamHall\",\"collisionModelName\":\"Chunin_Hall_Collision\",\"description\":\"Fight in the enclosed examination hall beneath its towering balconies.\",\"number\":2,\"playable\":false,\"importModelName\":\"Chunin_Exam_Hall_Roblox\",\"teleportReady\":true},{\"key\":\"Loguetown\",\"displayName\":\"Loguetown\",\"modelName\":\"Arena_Loguetown\",\"collisionModelName\":\"Loguetown_Arena_Collision\",\"description\":\"Battle in Loguetown's open town square beneath the execution platform.\",\"number\":3,\"playable\":false,\"importModelName\":\"Loguetown_Arena_Roblox\",\"teleportReady\":true},{\"key\":\"JujutsuHigh\",\"displayName\":\"Jujutsu High\",\"modelName\":\"Arena_JujutsuHigh\",\"collisionModelName\":\"Jujutsu_High_Collision\",\"description\":\"Train in the open courtyard surrounded by tiled halls, a pagoda and trees.\",\"number\":4,\"playable\":false,\"importModelName\":\"Jujutsu_High_Roblox\",\"teleportReady\":true},{\"key\":\"Fujikasane\",\"displayName\":\"Mount Fujikasane\",\"modelName\":\"Arena_Fujikasane\",\"collisionModelName\":\"Fujikasane_Arena_Collision\",\"description\":\"Face your opponent between the red pillars beneath purple wisteria.\",\"number\":5,\"playable\":false,\"importModelName\":\"Fujikasane_Arena_Roblox\",\"teleportReady\":true},{\"key\":\"HeavensArena\",\"displayName\":\"Heavens Arena\",\"modelName\":\"Arena_HeavensArena\",\"collisionModelName\":\"Heavens_Arena_Collision\",\"description\":\"Step onto the fighting floor surrounded by the stadium stands.\",\"number\":6,\"playable\":false,\"importModelName\":\"Heavens_Arena_Roblox\",\"teleportReady\":true},{\"key\":\"HyperbolicTimeChamber\",\"displayName\":\"Hyperbolic Time Chamber\",\"modelName\":\"Arena_HyperbolicTimeChamber\",\"collisionModelName\":\"Hyperbolic_Time_Chamber_Collision\",\"description\":\"Battle across the white expanse in front of the chamber's golden hall.\",\"number\":7,\"playable\":false,\"importModelName\":\"Hyperbolic_Time_Chamber_Roblox\",\"teleportReady\":true},{\"key\":\"Wano\",\"displayName\":\"Wano\",\"modelName\":\"Arena_Wano\",\"collisionModelName\":\"Wano_Flower_Capital_Collision\",\"description\":\"Fight along the Flower Capital street beneath the castle and cherry blossoms.\",\"number\":8,\"playable\":false,\"importModelName\":\"Wano_Flower_Capital_Roblox\",\"teleportReady\":true},{\"key\":\"Marineford\",\"displayName\":\"Marineford\",\"modelName\":\"Arena_Marineford\",\"collisionModelName\":\"Marineford_Frozen_Bay_Collision\",\"description\":\"Take the frozen bay, framed by Marineford's fortress and harbour walls.\",\"number\":9,\"playable\":false,\"importModelName\":\"Marineford_Frozen_Bay_Roblox\",\"teleportReady\":true}]")
for _,entry in ipairs(entries) do
    assert(workspace:FindFirstChild(entry.importModelName), "Missing visual "..entry.importModelName)
    if entry.collisionModelName then assert(workspace:FindFirstChild(entry.collisionModelName), "Missing collision "..entry.collisionModelName) end
    if entry.number > 1 then assert(not workspace:FindFirstChild(entry.modelName), "Arena already configured: "..entry.modelName) end
end
local backup = Instance.new("Folder")
backup.Name = "BeforeArenaTeleports_"..os.date("!%Y%m%d_%H%M%S")
backup.Parent = ServerStorage
local scriptsBackup = Instance.new("Folder");scriptsBackup.Name="Scripts";scriptsBackup.Parent=backup
for _,scriptObject in ipairs({ReplicatedStorage.ArenaConfig,ReplicatedStorage.ArenaSelectionUI,ReplicatedStorage.ArenaTravelClient,game.ServerScriptService.ArenaTravelService}) do
    scriptObject:Clone().Parent=scriptsBackup
end
game.StarterGui.ArenaSelectGui:Clone().Parent=backup
local modelsBackup=Instance.new("Folder");modelsBackup.Name="Models";modelsBackup.Parent=backup
for _,entry in ipairs(entries) do
    workspace[entry.importModelName]:Clone().Parent=modelsBackup
    if entry.collisionModelName then workspace[entry.collisionModelName]:Clone().Parent=modelsBackup end
end
game:GetService("ChangeHistoryService"):SetWaypoint("Before arena teleport setup")
local offsets={ChuninExamHall=Vector3.new(0,.2,-20),Loguetown=Vector3.new(0,.12,0),JujutsuHigh=Vector3.new(0,.05,0),Fujikasane=Vector3.new(0,.06,0),HeavensArena=Vector3.new(0,1.795,0),HyperbolicTimeChamber=Vector3.new(0,0,0),Wano=Vector3.new(0,.035,0),Marineford=Vector3.new(0,.065,0)}
local function marker(parent,name,cf)
    local p=Instance.new("Part");p.Name=name;p.Size=Vector3.one;p.CFrame=cf;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Transparency=1;p.Parent=parent
    return p
end
local aligned={}
for _,entry in ipairs(entries) do
    local visual=workspace[entry.importModelName]
    local root
    if entry.number==1 then root=visual
    else
        local collision=workspace[entry.collisionModelName]
        local sourcePivot=visual:GetPivot()
        local oldCollisionPivot=collision:GetPivot()
        collision:PivotTo(sourcePivot)
        if (oldCollisionPivot.Position-sourcePivot.Position).Magnitude>.01 then table.insert(aligned,entry.displayName) end
        root=Instance.new("Model");root.Name=entry.modelName;root.WorldPivot=sourcePivot;root.Parent=workspace
        visual:SetAttribute("SourceImportName",visual.Name);visual.Name="Environment";visual.Parent=root
        collision:SetAttribute("SourceImportName",collision.Name);collision.Name="Collision";collision.Parent=root
        for _,p in visual:GetDescendants() do if p:IsA("BasePart") then p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;if p:IsA("MeshPart") then p.DoubleSided=true end end end
        for _,p in collision:GetDescendants() do
            if p:IsA("BasePart") then
                p.Anchored=true;p.Transparency=1;p.CanCollide=true;p.CanTouch=true;p.CanQuery=true
                if p:IsA("MeshPart") then p.CollisionFidelity=Enum.CollisionFidelity.Hull end
            end
        end
        if entry.key=="HyperbolicTimeChamber" then
            local old=collision.COL_White_Training_Floor
            local floor=Instance.new("Part");floor.Name=old.Name;floor.Size=Vector3.new(2000,1,2000);floor.CFrame=sourcePivot*CFrame.new(0,-.5,30);floor.Anchored=true;floor.Transparency=1;floor.CanCollide=true;floor.Parent=collision
            old:Destroy()
        end
        local originCF=sourcePivot*CFrame.new(offsets[entry.key])
        local origin=marker(root,"BattleOrigin",originCF)
        origin:SetAttribute("HalfWidth",29);origin:SetAttribute("HalfDepth",29)
        root.PrimaryPart=origin
        marker(root,"CameraFocus",originCF*CFrame.new(0,0,5))
        local deploy=Instance.new("Folder");deploy.Name="DeploymentMarkers";deploy.Parent=root
        marker(deploy,"Team_Player",originCF*CFrame.new(0,0,-13));marker(deploy,"Team_Opponent",originCF*CFrame.new(0,0,13))
        local sidelines=Instance.new("Folder");sidelines.Name="Sidelines";sidelines.Parent=root
        local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={collision};params.RespectCanCollide=true
        local positions=entry.key=="ChuninExamHall" and {Vector3.new(35,0,-10),Vector3.new(-35,0,10)} or {Vector3.new(36,0,-32),Vector3.new(-36,0,32)}
        for i,offset in ipairs(positions) do
            local position=originCF:PointToWorldSpace(offset)
            local hit=workspace:Raycast(position+Vector3.new(0,180,0),Vector3.new(0,-360,0),params)
            assert(hit,"No safe sideline floor: "..entry.displayName)
            position=Vector3.new(position.X,hit.Position.Y+.08,position.Z)
            local target=Vector3.new(originCF.X,position.Y,originCF.Z)
            marker(sidelines,i==1 and "Spawn_Player" or "Spawn_Opponent",CFrame.lookAt(position,target))
        end
    end
    root:SetAttribute("ArenaNumber",entry.number);root:SetAttribute("DisplayName",entry.displayName);root:SetAttribute("ProgressionKey",entry.key)
    root:SetAttribute("TeleportReady",true);root:SetAttribute("MatchReady",entry.number==1)
    root:SetAttribute("SetupVersion",1)
end
return HttpService:JSONEncode({backup=backup:GetFullName(),aligned=aligned,configured=#entries})
