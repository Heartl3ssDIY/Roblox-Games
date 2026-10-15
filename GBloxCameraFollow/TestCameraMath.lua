local M=assert(loadstring(game.ReplicatedStorage.RunnerCameraFollow.Source))()
local cfg=assert(loadstring(game.ReplicatedStorage.RunnerConfig.Source))()
local checks=0
local function check(ok,label) assert(ok,label) checks+=1 end
check(M.StepY(nil,250,1/60,6,7,18)==250,"initial center")
for _,dy in {-6,-3,0,3,6} do check(M.StepY(100,100+dy,1/60,6,7,18)==100,"dead zone prevents bobbing") end
local y=M.StepY(0,20,1/60,6,7,18)
check(y>0 and y<20,"smooth following")
check(math.abs(M.StepY(0,1000,1/60,6,7,18)-1000)<=18,"extreme upward jump remains framed")
check(math.abs(M.StepY(0,-1000,1/60,6,7,18)+1000)<=18,"extreme fall remains framed")
local offset=cfg.CameraOffset
local dead,lag=M.Limits(offset,cfg.CameraFieldOfView,6,18)
for _,fps in {15,30,60,144} do
 for _,base in {0,34800,-50500} do
  local current=base
  for frame=1,fps*12 do
   local t=frame/fps
   local playerY=base+140*math.sin(t*1.7)
   current=M.StepY(current,playerY,1/fps,dead,7,lag)
   check(math.abs(playerY-current)<=lag+.00001,"bounded lag")
   local focus=Vector3.new(0,current,0)
   local cf=CFrame.lookAt(focus+offset,focus)
   local view=cf:PointToObjectSpace(Vector3.new(0,playerY,0))
   check(view.Z<0 and math.abs(view.Y/(-view.Z*math.tan(math.rad(58/2)) ))<.75,"character inside vertical frame")
  end
 end
end
local nearDead,nearLag=M.Limits(Vector3.new(0,0,-20),40,6,18)
check(nearLag<18 and nearDead<6,"safe limits adapt to closer camera")
local a=0 local b=0
for i=1,30 do a=M.StepY(a,10,1/30,6,7,18) end
for i=1,144 do b=M.StepY(b,10,1/144,6,7,18) end
check(math.abs(a-b)<1e-6,"frame rate independent smooth follow")
for _,s in {game.ReplicatedStorage.RunnerCameraFollow,game.ReplicatedStorage.RunnerConfig,game.StarterPlayer.StarterPlayerScripts.RunnerClient} do
 local fn,err=loadstring(s.Source) check(fn~=nil,s.Name..": "..tostring(err))
end
return tostring(checks).." camera math, view-framing and compilation checks passed."

