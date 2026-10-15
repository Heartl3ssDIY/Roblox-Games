local client=CLIENT
local builder=BUILDER
local original=game.StarterGui.GBloxAdminPanel
local gui=original:Clone()
gui.Name="TemporaryGiveawayUICheck"
gui.Enabled=false
for _,x in gui:GetDescendants() do if x:IsA("LuaSourceContainer") then x:Destroy() end end
gui.Parent=game.StarterGui
local build=assert(loadstring(builder))
setfenv(build,setmetatable({game={StarterGui={GBloxAdminPanel=gui}}},{__index=getfenv()}))
build()
local function signal()
 local listeners={}
 local s={}
 function s:Connect(fn)
  local c={}
  function c:Disconnect() end
  table.insert(listeners,fn)
  return c
 end
 function s:Fire(...) for _,fn in listeners do fn(...) end end
 return s
end
local viewport=Vector2.new(1280,720)
local cameraSignal=signal()
local camera={GetPropertyChangedSignal=function() return cameraSignal end}
setmetatable(camera,{__index=function(_,key) if key=="ViewportSize" then return viewport end end})
local world={CurrentCamera=camera,GetPropertyChangedSignal=function() return signal() end}
local attrs={}
local player={UserId=1201803949,GetAttribute=function(_,key) return attrs[key] end,GetAttributeChangedSignal=function() return signal() end}
local sent={}
local remoteSignal=signal()
local remote={OnClientEvent=remoteSignal,FireServer=function(_,...) table.insert(sent,table.pack(...)) end}
local services={
 Players={LocalPlayer=player},
 UserInputService={InputBegan=signal()},
 ReplicatedStorage={WaitForChild=function(_,name) if name=="GBloxAdminRequest" then return remote end return game.ReplicatedStorage:WaitForChild(name) end},
}
local delayed={}
local env=setmetatable({
 require=function() return {GetPet=function() return nil end} end,
 game={GetService=function(_,name) return services[name] or game:GetService(name) end},
 workspace=world,script={Parent=gui},task={delay=function(seconds,fn) table.insert(delayed,fn) end},
},{__index=getfenv()})
local api=assert(loadstring(client.."\nreturn {setOpen=setOpen,checkerRequest=checkerRequest,pending=function() return giveawayPending end}"))
setfenv(api,env)
local controls=api()
local checks={}
local function check(name,condition) assert(condition,name) table.insert(checks,name) end
controls.setOpen(true)
check("Existing admin still opens",gui.Panel.Visible and not gui.GiveawayPanel.Visible)
controls.setOpen(false)
check("Close hides both panels",not gui.Panel.Visible and not gui.GiveawayPanel.Visible)
gui.Panel.Visible=false;gui.GiveawayPanel.Visible=true
services.UserInputService.InputBegan:Fire({KeyCode=Enum.KeyCode.F2},false)
check("F2 closes the checker",not gui.GiveawayPanel.Visible)
controls.checkerRequest("GiveawayRefresh")
check("Checker requests correct admin read action",sent[1][1]=="GiveawayRefresh" and sent[1][2]==1 and controls.pending())
local legacy=gui.Panel.Status.Text
remoteSignal:Fire({Kind="Giveaway",RequestId=1,Ok=true,Rows={{UserId=123,Username="Example",DisplayName="Display",Wins=10}},Page=1,More=true,Message="Saved"})
check("Candidate rendered with inclusive ten wins",#gui.GiveawayPanel.Rows:GetChildren()==2 and gui.GiveawayPanel.Rows.User123.Wins.Text=="10 WINS")
check("Checker replies do not change grant status",gui.Panel.Status.Text==legacy)
check("Next page enabled only when more exist",gui.GiveawayPanel.Next.Active and not controls.pending())
controls.checkerRequest("GiveawayNext")
check("Next page carries monotonic request ID",sent[2][1]=="GiveawayNext" and sent[2][2]==2)
remoteSignal:Fire({Kind="Giveaway",RequestId=1,Ok=true,Rows={},Page=9,More=false,Message="Stale"})
check("Old response ignored",gui.GiveawayPanel.Rows:FindFirstChild("User123")~=nil and controls.pending())
remoteSignal:Fire({Kind="Giveaway",RequestId=2,Ok=true,Rows={{UserId=456,Username="Offline",Wins=22}},Page=2,More=false,Message="End"})
check("Page replaces previous rows, not an unbounded list",gui.GiveawayPanel.Rows:FindFirstChild("User123")==nil and gui.GiveawayPanel.Rows:FindFirstChild("User456")~=nil)
check("End-of-list disables Next",not gui.GiveawayPanel.Next.Active)
local scales={}
for _,size in {Vector2.new(1920,1080),Vector2.new(1280,720),Vector2.new(844,390),Vector2.new(390,844)} do
 viewport=size;cameraSignal:Fire()
 local scale=gui.GiveawayPanel.ResponsiveScale.Scale
 check("Checker fits viewport "..tostring(size),550*scale<=size.X-48+.01 and 620*scale<=size.Y-122-16+.01)
 table.insert(scales,{viewport=tostring(size),scale=scale})
end
local result={passed=#checks,checks=checks,scales=scales}
gui:Destroy()
return result
