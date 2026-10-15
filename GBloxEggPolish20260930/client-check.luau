local source=SOURCE
local build=assert(loadstring(BUILDER))
local realGame=game
local catalog=require(game.ReplicatedStorage.GBloxPetCatalog)
local gui=game.StarterGui.GBloxEggOpening:Clone()
gui.Name="TemporaryEggClientCheck"
gui.Enabled=false
for _,x in gui:GetDescendants() do if x:IsA("LuaSourceContainer") then x:Destroy() end end
gui.Parent=game.StarterGui
local templates=build()
templates.Parent=gui
local function signal()
 local listeners={}
 local s={}
 function s:Connect(fn)
  local connection={Connected=true}
  function connection:Disconnect() self.Connected=false end
  table.insert(listeners,{fn=fn,c=connection})
  return connection
 end
 function s:Fire(...)
  for _,entry in listeners do if entry.c.Connected then entry.fn(...) end end
 end
 function s:Count()
  local n=0
  for _,entry in listeners do if entry.c.Connected then n+=1 end end
  return n
 end
 return s
end
local now=0
local jobs={}
local function schedule(delay,fn,...)
 local co=type(fn)=="thread" and fn or coroutine.create(fn)
 table.insert(jobs,{at=now+delay,co=co,args=table.pack(...)})
end
local fakeTask={}
function fakeTask.spawn(fn,...) schedule(0,fn,...) end
function fakeTask.defer(fn,...) schedule(0,fn,...) end
function fakeTask.delay(delay,fn,...) schedule(delay,fn,...) end
function fakeTask.wait(delay) return coroutine.yield(delay or .02) end
local runSignal=signal()
local function run(seconds)
 local target=now+seconds
 local steps=0
 repeat
  now=math.min(target,now+.02)
  local ready=true
  while ready do
   ready=false
   for i=#jobs,1,-1 do
    local job=jobs[i]
    if job.at<=now+.000001 then
     table.remove(jobs,i)
     local ok,delay=coroutine.resume(job.co,table.unpack(job.args,1,job.args.n))
     assert(ok,delay)
     if coroutine.status(job.co)~="dead" then schedule(delay or .02,job.co) end
     ready=true
    end
   end
  end
  runSignal:Fire(.02)
  steps+=1
  assert(steps<2000,"Scheduler runaway")
 until now>=target
end
local remoteSignal=signal()
local promptSignal=signal()
local destroying=signal()
local assetMode="failure"
local preloads=0
local services={
 Players={LocalPlayer={FindFirstChild=function() return nil end}},
 RunService={RenderStepped=runSignal},
 CollectionService={GetTagged=function() return {} end},
 ProximityPromptService={PromptShown=promptSignal},
 ContentProvider={PreloadAsync=function(_,images,callback)
  preloads+=1
  for _,x in images do if callback then callback(x.Image,assetMode=="success" and Enum.AssetFetchStatus.Success or Enum.AssetFetchStatus.Failure) end end
 end},
 TweenService={Create=function(_,object,info,props)
  return {Play=function() for k,v in props do object[k]=v end end,Cancel=function() end}
 end},
 ReplicatedStorage={FindFirstChild=function(_,name) return realGame.ReplicatedStorage:FindFirstChild(name) end,
  WaitForChild=function(_,name)
   if name=="GBloxEggRequest" then return {OnClientEvent=remoteSignal} end
   return realGame.ReplicatedStorage:WaitForChild(name)
  end},
}
local fakeGame={GetService=function(_,name) return services[name] or realGame:GetService(name) end}
local fn=assert(loadstring(source..[[
return {advance=advance,begin=beginBatch,finish=finishBatch,
 get=function() return {state=state,busy=busy,token=generation,holders=holders,queue=queue} end}
]]))
local env=setmetatable({game=fakeGame,script={Parent=gui,Destroying=destroying},task=fakeTask},{__index=getfenv()})
setfenv(fn,env)
local api=fn()
local checks={}
local function check(name,value)
 assert(value,name)
 table.insert(checks,name)
end
local one={Theme="Velocity",Results={{Id="Horse",CashMultiplier=1.2,TrophyMultiplier=1}}}
remoteSignal:Fire(one)
run(.1)
local s=api.get()
check("Unloaded egg has visible procedural fallback",s.busy and s.holders[1].Fallback.Visible and s.holders[1].Holder.Visible)
check("Single hatch has ten capped sparkles",#s.holders==1 and #s.holders[1].Particles==10)
local base=s.holders[1].EggPosition
api.advance()
run(.04)
check("Stronger egg shake moves only visual",s.holders[1].Visual.Position~=base)
for _=1,4 do run(.4) api.advance() end
run(1.5)
s=api.get()
check("Unavailable pictures still reach complete",s.state=="complete")
check("3D pet fallback and name exist",s.holders[1].Viewport.CurrentCamera~=nil and #s.holders[1].Viewport.World:GetChildren()==1 and s.holders[1].Name.Text=="HORSE")
api.advance()
check("Finish releases effect connection",api.get().state=="idle" and runSignal:Count()==0)
check("Finish destroys only runtime holders",gui:FindFirstChild("Templates")~=nil and #api.get().holders==0)
local triple={Theme="Gravity",Results={
 {Id="Ostrich",CashMultiplier=2.8,TrophyMultiplier=1.9},
 {Id="Bat",CashMultiplier=8.5,TrophyMultiplier=5},
 {Id="Eagle",CashMultiplier=12,TrophyMultiplier=8},
}}
remoteSignal:Fire(triple)
run(.1)
s=api.get()
check("Triple uses three holders and thirty sparkles",#s.holders==3 and #s.holders[3].Particles==10)
check("Authored triple holder dimensions retained",s.holders[1].Holder.Size==templates.TripleHatch.Size)
remoteSignal:Fire(one)
check("Hatch results queue without losing a batch",#api.get().queue==1)
api.finish(s.token)
run(.1)
check("Queued hatch starts correctly",api.get().state=="cracking" and #api.get().holders==1)
api.finish(api.get().token)
run(.1)
remoteSignal:Fire({Theme="Spark",Results=one.Results})
check("Spark string cannot be treated as egg theme",not api.get().busy)
assetMode="success"
local auto={Theme="Orbit",Results={{Id="Orca",CashMultiplier=3,TrophyMultiplier=2}},AutoActive=true}
remoteSignal:Fire(auto)
run(3.8)
s=api.get()
check("Auto hatch completes without tap",s.state=="complete")
check("Successful cache chooses egg image",s.holders[1].Egg.Image~="")
api.advance()
remoteSignal:Fire(triple)
local newer=api.get().token
run(.8)
check("Old auto completion cannot close new hatch",api.get().busy and api.get().token==newer and api.get().state=="cracking")
api.finish(newer)
remoteSignal:Fire(one)
for _=1,5 do api.advance() run(.4) end
check("Destruction test reached revealing",api.get().state=="revealing")
destroying:Fire()
run(3)
check("Destroying mid-reveal cancels all client animation",not api.get().busy and runSignal:Count()==0 and remoteSignal:Count()==0 and promptSignal:Count()==0)
check("Original root authored layout remains intact",gui.Root.Position==game.StarterGui.GBloxEggOpening.Root.Position and gui.Root.Slots.Size==game.StarterGui.GBloxEggOpening.Root.Slots.Size)
local result={passed=#checks,checks=checks,preloadCalls=preloads}
gui:Destroy()
return result
