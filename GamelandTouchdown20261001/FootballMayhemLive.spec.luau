local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local folder = game.ServerScriptService.FootballMayhem
local Rules = require(folder.FootballMayhemRules)
local service = require(folder.FootballMayhemService)
local arena = workspace["Oni's Work"].FootballMayhem
local origin = game.ReplicatedStorage.FootballMayhem.ArenaOrigin.Value
local player = Players:GetPlayers()[1]
local original = Rules.NewPlayerState
local checks = {}
local function check(value, name)
    assert(value, name)
    table.insert(checks, name)
    script:SetAttribute("Stage", name)
end
local function position(x,z,y)
    local c=player.Character
    c:PivotTo(origin*CFrame.new(x,y or 4,z))
    c.HumanoidRootPart.AssemblyLinearVelocity=Vector3.zero
    task.wait(.12)
end
local function unanchor()
    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then player.Character.HumanoidRootPart.Anchored=false end
end
local function beginRound()
    local ok,why=service.StartRound({player})
    check(ok,"Round starts: "..tostring(why))
    task.wait(3.4)
    local r=player.Character.HumanoidRootPart
    r:SetNetworkOwner(nil)
    r.Anchored=true
    check(player:GetAttribute("FootballMayhemStatus")=="Active","Participant becomes active")
    check(player.Character:FindFirstChild("FootballMayhemBall")~=nil,"Player carries imported football")
end
local success, err=xpcall(function()
    check(service.GetRoundSummary().id>0,"Test script observes live runtime state")
    if player:GetAttribute("CurrentMinigame")=="FootballMayhem" then
        position(70,126)
        task.wait(2.1)
    end
    task.wait(5.1)
    Rules.NewPlayerState=function(rng,rows,lanes)
        local state=original(rng,rows,lanes)
        for row=1,rows do state.wrong[row]=6 end
        return state
    end
    beginRound()
    position(-40,132)
    position(-40,122)
    position(-40,112)
    position(-40,108)
    check(player:GetAttribute("FootballMayhemRowsCompleted")==1,"Safe lane advances exactly one row")
    position(-40,40)
    check(player:GetAttribute("FootballMayhemRowsCompleted")==1,"Large jump cannot skip rows")
    position(-40,101)
    position(-40,91)
    for x=-24,40,16 do position(x,91) end
    position(40,86,13)
    check(player:GetAttribute("FootballMayhemStatus")=="Eliminated","Wrong lane eliminates even during a jump")
    check(arena.RoundEffects:FindFirstChild("QuarterbackFor_"..player.UserId)~=nil,"Quarterback appears for the failed choice")
    local dropped=arena.RoundEffects:FindFirstChild("FootballMayhemBall")
    check(dropped~=nil and dropped.PrimaryPart:FindFirstChild("CarryWeld")==nil,"Football detaches and drops")
    check(player:GetAttribute("FootballMayhemFinishingRow")==2 and player:GetAttribute("FootballMayhemRowsCompleted")==1,"Finishing row and cleared rows are recorded")
    task.wait(2.2)
    unanchor()
    check(player:GetAttribute("InMinigame")==false,"Eliminated player returns to lobby")
    check((player.Character.HumanoidRootPart.Position-workspace.GamelandLobby:FindFirstChild("LobbySpawn",true).Position).Magnitude<15,"Return reaches lobby spawn")
    check(service.GetRoundSummary().phase=="Finished","Round ends when nobody remains")
    task.wait(3.2)
    beginRound()
    position(-40,132)
    for z=122,-108,-10 do position(-40,z) end
    position(-40,-112)
    check(player:GetAttribute("FootballMayhemRowsCompleted")==10,"All ten rows can be cleared")
    check(player:GetAttribute("FootballMayhemStatus")=="Qualified","Reaching the end qualifies")
    check(player:GetAttribute("FootballMayhemFinishOrder")==1,"Finish order recorded")
    local delivered=arena.RoundEffects:FindFirstChild("FootballMayhemBall")
    check(delivered~=nil and delivered.PrimaryPart.Anchored,"Football is delivered in the end zone")
    task.wait(2.2)
    unanchor()
    check(player:GetAttribute("CurrentMinigame")==nil,"Successful delivery returns to lobby")
    check(player.Character.HumanoidRootPart.CollisionGroup=="Default","Player collision group restored")
    check(service.GetRoundSummary().remaining==0,"No active participant left behind")
end,debug.traceback)
Rules.NewPlayerState=original
unanchor()
script:SetAttribute("Result",HttpService:JSONEncode({success=success,error=err,checks=checks}))

