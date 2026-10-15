local p=game.Players:GetPlayers()[1]
local rules=require(game.ServerScriptService.FootballMayhem.FootballMayhemRules)
local service=require(game.ServerScriptService.FootballMayhem.FootballMayhemService)
local origin=game.ReplicatedStorage.FootballMayhem.ArenaOrigin.Value
local original=rules.NewPlayerState
local checks={}
local baseline=p.Character.Humanoid.WalkSpeed
local function check(condition,name) assert(condition,name) table.insert(checks,name) script:SetAttribute("Stage",name) end
local function pos(x,z,y)
 p.Character:PivotTo(origin*CFrame.new(x,y or 4,z))
 p.Character.HumanoidRootPart.AssemblyLinearVelocity=Vector3.zero
 task.wait(.16)
end
local function begin()
 assert(service.StartRound({p}))
 task.wait(3.4)
 local r=p.Character.HumanoidRootPart r:SetNetworkOwner(nil) r.Anchored=true
 check(p.Character.Humanoid.WalkSpeed==40,"Speed doubles the original 20 to 40")
end
local ok,err=xpcall(function()
 p.Character.Humanoid.WalkSpeed=20
 rules.NewPlayerState=function(rng,rows,lanes) local s=original(rng,rows,lanes) for row=1,rows do s.wrong[row]=6 end return s end
 begin()
 pos(-40,132) pos(-40,120) pos(-40,108)
 check(p:GetAttribute("FootballMayhemRowsCompleted")==1,"First safe choice commits")
 pos(-24,108)
 local rp=origin:PointToObjectSpace(p.Character.HumanoidRootPart.Position)
 check(rp.X<=-32.8,"Cannot change lanes inside a committed choice")
 pos(-40,120)
 rp=origin:PointToObjectSpace(p.Character.HumanoidRootPart.Position)
 check(rp.Z<=108.9,"Cannot backtrack behind committed row")
 pos(-40,98) pos(-40,92)
 pos(-40,98)
 rp=origin:PointToObjectSpace(p.Character.HumanoidRootPart.Position)
 check(rp.Z<=94,"Cannot step back onto row after leaving it")
 pos(-40,91)
 for x=-24,40,16 do pos(x,91) end
 rp=origin:PointToObjectSpace(p.Character.HumanoidRootPart.Position)
 check(math.abs(rp.X-40)<1,"Can select a different lane in the next staging strip")
 p.Character.HumanoidRootPart.Anchored=false
 pos(40,86)
 check(p:GetAttribute("FootballMayhemStatus")=="Eliminated","Wrong choice still eliminates")
 task.wait(.7)
 check(math.abs(p.Character.HumanoidRootPart.CFrame.UpVector.Y)<.1,"Tackled character falls flat")
 check(p.Character.Humanoid.PlatformStand,"Knockdown stops normal character movement")
 task.wait(3)
 check(p.Character.Humanoid.WalkSpeed==20,"Elimination restores original speed")
 check(not p.Character.Humanoid.PlatformStand and not p.Character.HumanoidRootPart.Anchored,"Knockdown movement restored")
 check(p:GetAttribute("CurrentMinigame")==nil,"Tackle returns player to lobby")
 task.wait(2)
 begin()
 p.Character.HumanoidRootPart.Anchored=false
 check(service.StopRound(),"Admin stop accepted")
 check(p.Character.Humanoid.WalkSpeed==20,"Admin stop restores original speed")
 check(not p:GetAttribute("InMinigame"),"Admin stop clears round membership")
 task.wait(.7)
 begin()
 pos(-40,132)
 for z=122,-108,-10 do pos(-40,z) end
 p.Character.HumanoidRootPart.Anchored=false
 pos(-40,-112)
 check(p:GetAttribute("FootballMayhemStatus")=="Qualified","All ten choices can still qualify")
 task.wait(2.2)
 check(p.Character.Humanoid.WalkSpeed==20,"Qualification restores original speed")
 check(service.GetRoundSummary().remaining==0,"No players left active after completion")
end,debug.traceback)
rules.NewPlayerState=original
if p.Character then p.Character.HumanoidRootPart.Anchored=false p.Character.Humanoid.WalkSpeed=baseline end
script:SetAttribute("Result",game:GetService("HttpService"):JSONEncode({passed=ok,error=err,checks=checks}))

