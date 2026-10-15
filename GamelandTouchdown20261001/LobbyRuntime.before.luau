-- Embedded automatically in InstallGamelandLobby.luau. All gameplay runs on the server.
local Players = game:GetService("Players")
local root = script.Parent
local origin = root:GetAttribute("Origin")
local spawn = root:FindFirstChild("LobbySpawn", true)
local activities = root.Activities
local courses = root.ObbyCourses
local random = Random.new()
local active, practising, ballots, ui, connections = {}, {}, {}, {}, {}
local headline = "Welcome to Gameland"
local white = Color3.fromRGB(255,247,226)
local actions=Instance.new("RemoteEvent")
actions.Name="LobbyAction"
actions.Parent=root
local actionCooldown={}

local function character(player)
    local c = player.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    local r = c and c:FindFirstChild("HumanoidRootPart")
    if h and r and h.Health > 0 then return c,h,r end
end
local function place(player, cf)
    local c,h,r = character(player)
    if not c then return false end
    h.Sit = false
    r.AssemblyLinearVelocity = Vector3.zero
    r.AssemblyAngularVelocity = Vector3.zero
    c:PivotTo(cf)
    return true
end
local function lobby(player)
    practising[player] = nil
    local offset=Vector3.new(random:NextNumber(-4,4),4,random:NextNumber(-3,3))
    place(player, spawn.CFrame + offset)
end
local function textOn(instance, text)
    for _,v in ipairs(instance:GetDescendants()) do
        if v:IsA("TextLabel") then v.Text = text end
    end
end
local function announce(text)
    headline = text
    textOn(activities.RoundBoard,text)
    for _,labels in pairs(ui) do labels.title.Text=text end
end
local function status(player, text)
    local labels=ui[player]
    if labels then labels.detail.Text=text end
end
actions.OnServerEvent:Connect(function(player,action)
    if active[player] or (action~="Lobby" and action~="Retry") then return end
    if os.clock()-(actionCooldown[player] or 0)<.5 then return end
    actionCooldown[player]=os.clock()
    if action=="Lobby" then
        lobby(player)
        status(player,"Back in the lobby • Explore the gardens and obbys")
    elseif practising[player] then
        place(player,practising[player].cf)
    end
end)
local function addPlayer(player)
    if connections[player] then return end
    connections[player]={}
    player.RespawnLocation=spawn
    player:SetAttribute("InMinigame",false)
    local function onCharacter(c)
        active[player]=nil
        practising[player]=nil
        player:SetAttribute("InMinigame",false)
        local h=c:WaitForChild("Humanoid",10)
        local r=c:WaitForChild("HumanoidRootPart",10)
        if not h or not r or player.Character~=c or not player.Parent then return end
        lobby(player)
        status(player,"Explore the lobby • Four obbys, giant ball and vanishing tiles")
        local old=connections[player] and connections[player].death
        if old then old:Disconnect() end
        if connections[player] then
            connections[player].death=h.Died:Connect(function()
                active[player]=nil
                practising[player]=nil
                player:SetAttribute("InMinigame",false)
            end)
        end
    end
    connections[player].spawn=player.CharacterAdded:Connect(onCharacter)
    if player.Character then task.spawn(onCharacter,player.Character) end
    task.spawn(function()
        local pg=player:WaitForChild("PlayerGui",10)
        if not pg or not player.Parent then return end
        local gui=Instance.new("ScreenGui")
        gui.Name="GamelandLobbyHUD"
        gui.ResetOnSpawn=false
        gui.DisplayOrder=20
        local frame=Instance.new("Frame")
        frame.Size=UDim2.new(.88,0,0,126)
        frame.Position=UDim2.new(.5,0,0,8)
        frame.AnchorPoint=Vector2.new(.5,0)
        frame.BackgroundColor3=Color3.fromRGB(30,50,49)
        frame.BackgroundTransparency=.12
        frame.Parent=gui
        local limit=Instance.new("UISizeConstraint")
        limit.MaxSize=Vector2.new(760,126)
        limit.Parent=frame
        local corner=Instance.new("UICorner")
        corner.CornerRadius=UDim.new(0,14)
        corner.Parent=frame
        local labels={}
        for i,key in ipairs({"title","detail"}) do
            local label=Instance.new("TextLabel")
            label.Size=UDim2.new(1,-20,0,i==1 and 42 or 34)
            label.Position=UDim2.new(0,10,0,i==1 and 4 or 47)
            label.BackgroundTransparency=1
            label.TextColor3=white
            label.Font=i==1 and Enum.Font.GothamBold or Enum.Font.Gotham
            label.TextScaled=true
            label.TextWrapped=true
            local size=Instance.new("UITextSizeConstraint")
            size.MaxTextSize=i==1 and 23 or 16
            size.MinTextSize=10
            size.Parent=label
            label.Parent=frame
            labels[key]=label
        end
        ui[player]=labels
        labels.title.Text=headline
        labels.detail.Text="Four obbys • Giant ball • Vanishing tiles"
        for i,name in ipairs({"Lobby","Retry"}) do
            local button=Instance.new("TextButton")
            button.Name=name
            button.Size=UDim2.new(.46,0,0,28)
            button.Position=UDim2.new(i==1 and .03 or .51,0,0,90)
            button.Text=i==1 and "Return to lobby" or "Retry checkpoint"
            button.Font=Enum.Font.GothamBold
            button.TextSize=14
            button.TextColor3=white
            button.BackgroundColor3=Color3.fromRGB(57,121,117)
            button.Parent=frame
            local rounding=Instance.new("UICorner")
            rounding.CornerRadius=UDim.new(0,7)
            rounding.Parent=button
        end
        local ref=Instance.new("ObjectValue")
        ref.Name="LobbyModel"
        ref.Value=root
        ref.Parent=gui
        root.LobbyControls:Clone().Parent=gui
        gui.Parent=pg
    end)
end
Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(function(player)
    for _,c in pairs(connections[player] or {}) do c:Disconnect() end
    connections[player]=nil
    active[player]=nil
    practising[player]=nil
    ballots[player]=nil
    ui[player]=nil
    actionCooldown[player]=nil
end)
for _,player in ipairs(Players:GetPlayers()) do addPlayer(player) end

-- Lobby obbys remain available during every phase. A checkpoint is local to this attempt.
local promptCooldown={}
for _,course in ipairs(courses:GetChildren()) do
    local entrance=activities:FindFirstChild(course.Name.."Gate")
    entrance.ProximityPrompt.Triggered:Connect(function(player)
        local _,_,r=character(player)
        if not r or active[player] or (r.Position-entrance.Position).Magnitude>15 then return end
        if os.clock()-(promptCooldown[player] or 0)<1 then return end
        promptCooldown[player]=os.clock()
        practising[player]={course=course,checkpoint=0,cf=course.Start.CFrame+Vector3.new(0,4,0)}
        place(player,practising[player].cf)
        status(player,course.Name.." obby • Touch green checkpoints • Fall to retry")
    end)
    course.Start.Return.Triggered:Connect(function(player)
        local _,_,r=character(player)
        if r and not active[player] and (r.Position-course.Start.Position).Magnitude<15 then
            lobby(player)
            status(player,"Back in the lobby")
        end
    end)
    course.Finish.Return.Triggered:Connect(function(player)
        local _,_,r=character(player)
        if r and not active[player] and (r.Position-course.Finish.Position).Magnitude<15 then
            lobby(player)
            status(player,course.Name.." complete! Try the next difficulty")
        end
    end)
end
Players.PlayerRemoving:Connect(function(player) promptCooldown[player]=nil end)

-- Falling tiles use server-observed foot positions, rather than trusting Touched events.
local tileTimers={}
local function triggerTile(tile, delay, restore)
    if tileTimers[tile] then return end
    tileTimers[tile]={at=os.clock(),delay=delay,restore=restore,color=tile.Color}
end
local function above(r, tile, allowance)
    local p=tile.CFrame:PointToObjectSpace(r.Position)
    local height=p.Y-tile.Size.Y/2
    return math.abs(p.X)<=tile.Size.X/2+(allowance or 0)
        and math.abs(p.Z)<=tile.Size.Z/2+(allowance or 0) and height>=0 and height<=5
end
local moving={}
for _,v in ipairs(courses:GetDescendants()) do
    if v:IsA("BasePart") and v:GetAttribute("Moving") then
        table.insert(moving,{part=v,base=v.CFrame,phase=v:GetAttribute("Stage")})
    end
end
local pushBall=activities.PushBall
local ballHome=pushBall.CFrame
pushBall:SetNetworkOwner(nil)
local pushCooldown={}
local function push(player)
    local _,_,r=character(player)
    if not r or active[player] or (r.Position-pushBall.Position).Magnitude>13 then return end
    if os.clock()-(pushCooldown[player] or 0)<.4 then return end
    pushCooldown[player]=os.clock()
    local delta=pushBall.Position-r.Position
    local flat=Vector3.new(delta.X,0,delta.Z)
    if flat.Magnitude<.1 then return end
    pushBall:ApplyImpulse((flat.Unit*17+Vector3.new(0,2,0))*pushBall.AssemblyMass)
end
pushBall.Push.Triggered:Connect(push)
pushBall.Touched:Connect(function(hit)
    local model=hit:FindFirstAncestorOfClass("Model")
    local player=model and Players:GetPlayerFromCharacter(model)
    if player then push(player) end
end)
Players.PlayerRemoving:Connect(function(player) pushCooldown[player]=nil end)
local ballResetAt,goals=0,0
local goalPending=false
local function resetBall()
    pushBall.CFrame=ballHome
    pushBall.AssemblyLinearVelocity=Vector3.zero
    pushBall.AssemblyAngularVelocity=Vector3.zero
end

task.spawn(function()
    while root.Parent do
        local now=os.clock()
        for _,m in ipairs(moving) do
            local old=m.part.CFrame
            m.part.CFrame=m.base*CFrame.new((m.part:GetAttribute("MoveAxis") or Vector3.new(1,0,0))*math.sin(now*(m.part:GetAttribute("MoveSpeed") or .9)+m.phase)*(m.part:GetAttribute("MoveAmplitude") or 1.1))
            -- Carry players standing on an anchored moving platform.
            local delta=m.part.Position-old.Position
            for player,state in pairs(practising) do
                if m.part:IsDescendantOf(state.course) then
                    local c,_,r=character(player)
                    if r then
                        local p=old:PointToObjectSpace(r.Position)
                        if math.abs(p.X)<m.part.Size.X/2 and math.abs(p.Z)<m.part.Size.Z/2
                            and p.Y>0 and p.Y<4.6 and math.abs(r.AssemblyLinearVelocity.Y)<2 then
                            c:PivotTo(c:GetPivot()+delta)
                        end
                    end
                end
            end
        end
        for tile,state in pairs(tileTimers) do
            if not tile.Parent then tileTimers[tile]=nil
            else
                local elapsed=now-state.at
                if elapsed<state.delay then
                    tile.Color=math.floor(elapsed*8)%2==0 and Color3.fromRGB(255,100,80) or state.color
                elseif elapsed<state.delay+state.restore then
                    tile.CanCollide=false
                    tile.Transparency=1
                    for _,g in ipairs(tile:GetChildren()) do if g:IsA("SurfaceGui") then g.Enabled=false end end
                else
                    tile.CanCollide=true
                    tile.Transparency=0
                    for _,g in ipairs(tile:GetChildren()) do if g:IsA("SurfaceGui") then g.Enabled=true end end
                    tile.Color=state.color
                    tileTimers[tile]=nil
                end
            end
        end
        for _,player in ipairs(Players:GetPlayers()) do
            local _,_,r=character(player)
            if r and not active[player] then
                local state=practising[player]
                if state then
                    local p=r.Position-state.course:GetAttribute("Origin")
                    if p.Y< -8 or math.abs(p.X)>100 or math.abs(p.Z)>100 then
                        place(player,state.cf)
                    else
                        for _,tile in ipairs(state.course.Route:GetChildren()) do
                            if tile.CanCollide and above(r,tile) then
                                local stage=tile:GetAttribute("Stage")
                                if tile:GetAttribute("Checkpoint") and stage>state.checkpoint then
                                    state.checkpoint=stage
                                    state.cf=tile.CFrame+Vector3.new(0,4,0)
                                    status(player,state.course.Name.." • Checkpoint "..stage.." saved")
                                end
                                if tile:GetAttribute("Crumble") then
                                    triggerTile(tile,tile:GetAttribute("Delay") or .7,3)
                                end
                            end
                        end
                        if above(r,state.course.Finish) and not state.finished then
                            state.finished=true
                            status(player,state.course.Name.." complete! Use the return prompt")
                        end
                    end
                else
                    for _,tile in ipairs(activities.VanishingTiles:GetChildren()) do
                        if tile.CanCollide and above(r,tile) then triggerTile(tile,.65,3) end
                    end
                    if r.Position.Y<origin.Y-10 then lobby(player) end
                end
            end
        end
        local bp=pushBall.Position-origin
        if goalPending and now>=ballResetAt then
            resetBall()
            goalPending=false
        elseif not goalPending then
            if bp.X< -104 or bp.X> -48 or bp.Z<20 or bp.Z>76 or bp.Y<0 or bp.Y>35 then
                resetBall()
            elseif bp.Z>65 and math.abs(bp.X+76)<8 and bp.Y<15 then
                goals=goals+1
                textOn(activities.BallBoard,"GOAL!\nLobby goals: "..goals)
                ballResetAt=now+1.5
                goalPending=true
            end
        end
        if pushBall.AssemblyLinearVelocity.Magnitude>40 then
            pushBall.AssemblyLinearVelocity=pushBall.AssemblyLinearVelocity.Unit*40
        end
        task.wait(.05)
    end
end)

-- Lobby-only build: no timers, arenas, round selection or minigame teleporting.
announce("GAMELAND • EXPLORE THE LOBBY")
for i=1,3 do
    textOn(activities["VoteBoard"..i],"MAP "..string.format("%02d",i).."\nVoting coming soon")
end
local instructions=activities:FindFirstChild("Voting instructions")
if instructions then textOn(instructions,"EXPLORE THE LOBBY\nMinigames will be added later") end

-- Votes can be previewed in the lobby; they never create a map or start a round.
while root.Parent do
    local counts={0,0,0}
    for _,player in ipairs(Players:GetPlayers()) do
        local _,_,r=character(player)
        if r then
            for i=1,3 do
                if above(r,activities["VotePad"..i],.1) then
                    if ballots[player]~=i then
                        ballots[player]=i
                        status(player,"Map "..string.format("%02d",i).." selected • Lobby voting preview")
                    end
                end
            end
        end
        if ballots[player] then counts[ballots[player]]=counts[ballots[player]]+1 end
    end
    for i=1,3 do
        textOn(activities["VoteBoard"..i],"MAP "..string.format("%02d",i).."\n"..counts[i].." votes • Preview")
    end
    task.wait(.15)
end

