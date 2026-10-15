local p=game.Players.LocalPlayer
local gui=p.PlayerGui.BritishBulldogHUD
local shell=p.PlayerGui.PlaygroundShell
local state=game.ReplicatedStorage.BritishBulldogState
local started=game.ReplicatedStorage.PlaygroundAdminRequest:InvokeServer("BBRunner")
assert(started.ok,started.message)
local deadline=os.clock()+8
while state:GetAttribute("Phase")=="Countdown" and os.clock()<deadline do task.wait(0.05) end
assert(state:GetAttribute("Phase")=="Crossing","Practice must enter Crossing")
local names={"BBRole","BBStatus","BBMustLeave","BBDepartureEndsAt","PCLevel","PCLevelXP","PCLevelXPRequired"}
local saved={}
for _,name in ipairs(names) do saved[name]=p:GetAttribute(name) end
local checks=0
local function check(ok,label) assert(ok,label) checks+=1 end
local before={}
for _,object in ipairs({gui.MovementControls,gui.Departure,gui.CompactDeparture,gui.Tagged,shell.LevelPanel,shell.CompactLevelPanel}) do before[object]={object.Position,object.Size,object.AnchorPoint} end
local ok,message=pcall(function()
 p:SetAttribute("BBRole","Runner")
 p:SetAttribute("BBMustLeave",true)
 p:SetAttribute("BBDepartureEndsAt",workspace:GetServerTimeNow()+5)
 p:SetAttribute("BBStatus","Safe")
 task.wait(0.22)
 check(gui.MovementControls.Visible,"Runner controls visible")
 check(gui.CompactDeparture.Visible,"Short-screen departure visible")
 check(not gui.Departure.Visible,"Full departure hidden")
 check(gui.CompactDeparture.Panel.SecondsBadge.Seconds.Text=="5","Five-second countdown")
 check(not gui.RolePill.Visible,"Old role pill hidden")
 check(shell.CompactLevelPanel.Visible,"Compact level remains visible")
 p:SetAttribute("BBRole","Tagged")
 p:SetAttribute("BBStatus","Tagged")
 task.wait(0.22)
 check(gui.Tagged.Visible,"Tagged overlay visible")
 check(not gui.MovementControls.Visible,"Frozen controls hidden")
 check(not gui.CompactDeparture.Visible,"Tagged departure hidden")
 check(not gui.RolePill.Visible,"Frozen role pill hidden")
 p:SetAttribute("PCLevel",2)
 p:SetAttribute("PCLevelXP",75)
 p:SetAttribute("PCLevelXPRequired",150)
 task.wait(0.22)
 check(shell.LevelPanel.Level.Text=="LEVEL 2","Full level updates")
 check(shell.CompactLevelPanel.Level.Text=="LV 2","Compact level updates")
 check(shell.LevelPanel.XP.Text=="75 / 150 XP","XP label updates")
 for _,panel in ipairs({shell.LevelPanel,shell.CompactLevelPanel}) do
  check(panel.FacePreview.CurrentCamera~=nil,"Preview camera exists")
  check(panel.FacePreview.World:FindFirstChild("AvatarPreview")~=nil,"Avatar preview exists")
 end
 for object,layout in pairs(before) do check(object.Position==layout[1] and object.Size==layout[2] and object.AnchorPoint==layout[3],"Authored layout preserved") end
end)
for _,name in ipairs(names) do p:SetAttribute(name,saved[name]) end
assert(ok,message)
return {passed=checks,viewport=tostring(workspace.CurrentCamera.ViewportSize),nativeCameras=true,layoutPreserved=true}
