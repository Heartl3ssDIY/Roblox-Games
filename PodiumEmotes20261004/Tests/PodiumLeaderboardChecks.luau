return function(sourceText)
 local storage=game:GetService("ServerStorage")
 local fixture=Instance.new("Folder")
 fixture.Name="_LeaderboardScopeChecks_"..game:GetService("HttpService"):GenerateGUID(false)
 fixture.Parent=storage
 local sessions={}
 local report={mode="Edit",playStarted=false,checks={},generatedAt=DateTime.now():ToIsoDate()}
 local function check(name,callback)
  report.currentCheck=name
  callback()
  table.insert(report.checks,{name=name,passed=true})
 end
 local ok,failure=xpcall(function()
  local authored=game.StarterGui.PlaygroundLeaderboards
  local original=authored.Controller
  local module=Instance.new("ModuleScript")
  module.Name="LeaderboardControllerChecks"
  module.Capabilities=original.Capabilities
  module.Sandboxed=original.Sandboxed
  local function remove(source,needle)
   local a,b=source:find(needle,1,true)
   assert(a,"Test seam not found")
   return source:sub(1,a-1)..source:sub(b+1)
  end
  local source=sourceText or original.Source
  source=remove(source,'local ReplicatedStorage = game:GetService("ReplicatedStorage")\n')
  source=remove(source,'local RunService = game:GetService("RunService")\n')
  source=remove(source,"local gui = script.Parent\n")
  source=remove(source,"local clock = os.clock\n")
  module.Source="return function(gui,ReplicatedStorage,RunService,workspace,task,clock)\n"..source.."\nreturn {Tick=tick,Select=selectScope,Cleanup=cleanup,Records=records,Connections=connections,Alive=function() return alive end,InFlight=function() return inFlight end}\nend"
  module.Parent=fixture
  local run=require(module)
  local function response(scope,name,state,region)
   local boards={}
   for _,id in ipairs({"MostWins","HighestLevel"}) do
    boards[id]={state=state or "ready",status=scope.." snapshot",emptyText=state=="loading" and "Loading rankings..." or "No scores yet.",
     entries=(state=="loading" or state=="unavailable") and {} or {{userId=12345,name=name or "ExamplePlayer",image="",value=id=="MostWins" and "420" or "LV 38"}}}
    if state=="loading" or state=="unavailable" then boards[id].entries={} end
   end
   return {scope=scope,region=region,state=state or "ready",retryAfter=state=="loading" and 5 or 30,boards=boards}
  end
  local function session(remoteAvailable)
   local root=Instance.new("Folder")
   root.Parent=fixture
   local world=Instance.new("Folder")
   world.Name="World"
   world.Parent=root
   local lobby=Instance.new("Folder")
   lobby.Name="Playground Lobby" lobby.Parent=world
   local boards=Instance.new("Folder")
   boards.Name="Leaderboards" boards.Parent=lobby
   local gui=authored:Clone()
   gui.Controller:Destroy()
   gui.Parent=root
   local fallback={}
   for _,id in ipairs({"MostWins","HighestLevel"}) do
    local board=Instance.new("Folder") board.Name=id board.Parent=boards
    local face=Instance.new("Part") face.Name="Face" face.Parent=board
    local display=workspace["Playground Lobby"].Leaderboards[id].Face.Display:Clone()
    display.Enabled=true display.Parent=face
    gui[id].Adornee=face gui[id].Enabled=false
    fallback[id]=display
   end
   local state={now=0,requests={},remotePresent=remoteAvailable~=false}
   local remote={}
   function remote:IsA(class) return class=="RemoteFunction" end
   function remote:InvokeServer(scope)
    local request={scope=scope,time=state.now,thread=coroutine.running()}
    table.insert(state.requests,request)
    local reply,rejected=coroutine.yield()
    if rejected then error("Simulated remote failure") end
    return reply
   end
   state.remote=remote
   local replicated={}
   function replicated:FindFirstChild(name) return name=="PlaygroundLeaderboardRequest" and state.remotePresent and state.remote or nil end
   local heartbeat={}
   function heartbeat:Connect(callback)
    local connection={Connected=true}
    function connection:Disconnect() self.Connected=false end
    return connection
   end
   local taskMock={}
   function taskMock.spawn(callback)
    local thread=coroutine.create(callback)
    local started,message=coroutine.resume(thread)
    assert(started,message)
    return thread
   end
   function taskMock.cancel(thread)
    state.cancelled=(state.cancelled or 0)+1
    local closed,message=coroutine.close(thread)
    assert(closed,message)
   end
   local layouts={}
   for _,object in ipairs(gui:GetDescendants()) do
    if object:IsA("GuiObject") then layouts[object]={Position=object.Position,Size=object.Size,AnchorPoint=object.AnchorPoint} end
   end
   local controls=run(gui,replicated,{Heartbeat=heartbeat},world,taskMock,function() return state.now end)
   local result={root=root,world=world,gui=gui,controls=controls,state=state,fallback=fallback,layouts=layouts}
   function result:resolve(index,reply,rejected)
    local request=assert(state.requests[index],"Request missing")
    local resumed,message=coroutine.resume(request.thread,reply,rejected)
    assert(resumed,message)
   end
   function result:tick(time) state.now=time controls.Tick() end
   function result:select(id,scope)
    for _,record in ipairs(controls.Records) do if record.id==id then controls.Select(record,scope) return end end
    error("Board missing")
   end
   table.insert(sessions,result)
   return result
  end
  local function assertLayout(s)
   for object,properties in pairs(s.layouts) do
    for property,value in pairs(properties) do assert(object[property]==value,"Runtime altered "..object:GetFullName().."."..property) end
   end
  end
  check("Initial request is shared and global world fallback stays visible until a valid reply",function()
   local s=session()
   assert(#s.state.requests==1 and s.state.requests[1].scope=="global")
   for id,world in pairs(s.fallback) do assert(world.Enabled and not s.gui[id].Enabled) end
   s:resolve(1,response("global","GlobalPlayer"))
   for id,world in pairs(s.fallback) do
    assert(not world.Enabled and s.gui[id].Enabled)
    assert(s.gui[id].Body.Row01.PlayerName.Text=="GlobalPlayer" and s.gui[id].Body.Row01.Visible)
    assert(s.gui[id].Body.Row01.Avatar.Placeholder.Visible)
   end
   assertLayout(s)
  end)
  check("Each board selects independently and the scheduler throttles all requests together",function()
   local s=session() s:resolve(1,response("global","GlobalPlayer"))
   s:select("MostWins","server")
   assert(s.gui.MostWins.Empty.Visible and not s.gui.MostWins.Body.Row01.Visible)
   assert(s.gui.HighestLevel.Body.Row01.PlayerName.Text=="GlobalPlayer")
   s:tick(0.5) assert(#s.state.requests==1)
   s:tick(1.06) assert(#s.state.requests==2 and s.state.requests[2].scope=="server")
   s:resolve(2,response("server","ServerPlayer"))
   assert(s.gui.MostWins.Body.Row01.PlayerName.Text=="ServerPlayer")
   assert(s.gui.HighestLevel.Body.Row01.PlayerName.Text=="GlobalPlayer")
   assert(s.gui.MostWins.ScopeTabs.server:GetAttribute("Selected") and s.gui.HighestLevel.ScopeTabs.global:GetAttribute("Selected"))
   assertLayout(s)
  end)
  check("Rapid selections send only the latest scope after the one-second limit",function()
   local s=session() s:resolve(1,response("global"))
   s:select("MostWins","server") s:tick(0.1)
   s:select("MostWins","region") s:tick(0.2)
   s:select("MostWins","server") s:tick(0.3)
   assert(#s.state.requests==1)
   s:tick(1.06)
   assert(#s.state.requests==2 and s.state.requests[2].scope=="server")
  end)
  check("A stale response cannot overwrite a newer selection",function()
   local s=session() s:resolve(1,response("global","GlobalPlayer"))
   s:select("MostWins","server") s:tick(1.06)
   s:select("MostWins","region")
   s:resolve(2,response("server","OldServer"))
   assert(not s.gui.MostWins.Body.Row01.Visible)
   s:tick(2.12)
   s:resolve(3,response("region","EuropePlayer","ready","Europe"))
   assert(s.gui.MostWins.Body.Row01.PlayerName.Text=="EuropePlayer")
   assert(s.gui.MostWins.Header.Subtitle.Text=="EUROPE · TOP 10")
   assert(s.gui.HighestLevel.Body.Row01.PlayerName.Text=="GlobalPlayer")
  end)
  check("Cached scope results serve the other board without changing the first selection",function()
   local s=session() s:resolve(1,response("global"))
   s:select("MostWins","server") s:tick(1.06) s:resolve(2,response("server","CachedServer"))
   s:select("HighestLevel","server") s:tick(1.2)
   assert(#s.state.requests==2 and s.gui.HighestLevel.Body.Row01.PlayerName.Text=="CachedServer")
   s:select("MostWins","global")
   assert(s.gui.HighestLevel.ScopeTabs.server:GetAttribute("Selected"))
   assert(s.gui.MostWins.ScopeTabs.global:GetAttribute("Selected"))
  end)
  check("Server refreshes at ten seconds and global at sixty seconds",function()
   local s=session() s:resolve(1,response("global"))
   s:tick(59.9) assert(#s.state.requests==1)
   s:tick(60.1) assert(#s.state.requests==2)
   local t=session() t:resolve(1,response("global"))
   t:select("MostWins","server") t:tick(1.06) t:resolve(2,response("server"))
   t:tick(11) assert(#t.state.requests==2)
   t:tick(11.07) assert(#t.state.requests==3 and t.state.requests[3].scope=="server")
  end)
  check("A loading cache retries after five seconds and keeps honest empty text",function()
   local s=session() s:resolve(1,response("global",nil,"loading"))
   assert(s.gui.MostWins.Enabled and s.gui.MostWins.Empty.Visible and s.gui.MostWins.Empty.Text=="Loading rankings...")
   s:tick(4.9) assert(#s.state.requests==1)
   s:tick(5.1) assert(#s.state.requests==2)
   s:resolve(2,response("global","LoadedPlayer"))
   assert(s.gui.MostWins.Body.Row01.PlayerName.Text=="LoadedPlayer")
  end)
  check("Unavailable geographic region is not replaced with global or server scores",function()
   local s=session() s:resolve(1,response("global","GlobalPlayer"))
   s:select("MostWins","region") s:tick(1.06)
   local reply=response("region",nil,"unavailable")
   reply.boards.MostWins.emptyText="Your region is unavailable."
   s:resolve(2,reply)
   assert(not s.gui.MostWins.Body.Row01.Visible and s.gui.MostWins.Empty.Text=="Your region is unavailable.")
   assert(s.gui.MostWins.ScopeTabs.region:GetAttribute("Selected"))
   assert(s.gui.HighestLevel.Body.Row01.PlayerName.Text=="GlobalPlayer")
  end)
  check("Refresh failures preserve same-scope data and malformed initial replies preserve world fallback",function()
   local s=session() s:resolve(1,response("global","PreviousPlayer"))
   s:tick(60.1) s:resolve(2,nil,true)
   assert(s.gui.MostWins.Body.Row01.PlayerName.Text=="PreviousPlayer" and s.gui.MostWins.Body.Row01.Visible)
   assert(s.gui.MostWins.Status.Text:find("unavailable",1,true))
   local t=session() t:resolve(1,response("server"))
   assert(not t.gui.MostWins.Enabled and t.fallback.MostWins.Enabled)
  end)
  check("Remote timeout cancels the blocked task and recovers with a fresh request",function()
   local s=session()
   local old=s.state.requests[1]
   s:tick(12.1)
   assert(#s.state.requests==1 and s.controls.InFlight()==nil and s.state.cancelled==1)
   assert(coroutine.status(old.thread)=="dead")
   assert(s.fallback.MostWins.Enabled and not s.gui.MostWins.Enabled)
   s:tick(27) assert(#s.state.requests==1)
   s:tick(27.2) assert(#s.state.requests==2)
   local late=coroutine.resume(old.thread,response("global","TooLate"))
   assert(not late and not s.gui.MostWins.Enabled)
   s:resolve(2,response("global","Recovered"))
   assert(s.gui.MostWins.Body.Row01.PlayerName.Text=="Recovered")
  end)
  check("Missing remote keeps world fallback and recovers when the remote appears",function()
   local s=session(false)
   s:tick(100)
   assert(#s.state.requests==0 and s.fallback.MostWins.Enabled and not s.gui.MostWins.Enabled)
   s.state.remotePresent=true
   s:tick(101.1) assert(#s.state.requests==1)
   s:resolve(1,response("global","Connected"))
   assert(s.gui.MostWins.Enabled and s.gui.MostWins.Body.Row01.PlayerName.Text=="Connected")
  end)
  check("Removing a remote cancels its pending request even before the timeout",function()
   local s=session()
   local old=s.state.requests[1]
   s.state.remotePresent=false
   s:tick(5)
   assert(s.controls.InFlight()==nil and s.state.cancelled==1 and coroutine.status(old.thread)=="dead")
   assert(s.fallback.MostWins.Enabled and not s.gui.MostWins.Enabled)
   s:tick(100)
   assert(#s.state.requests==1 and s.state.cancelled==1)
   s.state.remotePresent=true
   s:tick(101.1)
   assert(#s.state.requests==2)
   s:resolve(2,response("global","Reconnected"))
   assert(s.gui.MostWins.Body.Row01.PlayerName.Text=="Reconnected")
  end)
  check("Replacing a remote cancels the old call and only the replacement may render",function()
   local s=session()
   local old=s.state.requests[1]
   s.state.remote=setmetatable({}, {__index=s.state.remote})
   s:tick(1.06)
   assert(#s.state.requests==2 and s.state.cancelled==1 and coroutine.status(old.thread)=="dead")
   local late=coroutine.resume(old.thread,response("global","OldConnection"))
   assert(not late and not s.gui.MostWins.Enabled)
   s:resolve(2,response("global","ReplacementConnection"))
   assert(s.gui.MostWins.Body.Row01.PlayerName.Text=="ReplacementConnection")
  end)
  check("A wrong-class replacement cancels safely and a valid remote can reconnect",function()
   local s=session()
   local real=s.state.remote
   s.state.remote={IsA=function() return false end}
   s:tick(3)
   assert(s.controls.InFlight()==nil and s.state.cancelled==1 and #s.state.requests==1)
   s.state.remote=real
   s:tick(4.1)
   assert(#s.state.requests==2)
   s:resolve(2,response("global","ValidAgain"))
   assert(s.gui.HighestLevel.Body.Row01.PlayerName.Text=="ValidAgain")
  end)
  check("Disabling or destroying the local UI restores the world boards",function()
   local s=session() s:resolve(1,response("global"))
   s.gui.Enabled=false s.controls.Tick()
   assert(s.fallback.MostWins.Enabled and not s.gui.MostWins.Enabled)
   s.gui.Enabled=true s.controls.Tick()
   assert(not s.fallback.MostWins.Enabled and s.gui.MostWins.Enabled)
   s.controls.Cleanup()
   assert(not s.controls.Alive() and #s.controls.Connections==0)
   assert(s.fallback.MostWins.Enabled and s.fallback.HighestLevel.Enabled)
   assert(not s.gui.MostWins.Enabled and not s.gui.HighestLevel.Enabled)
   assertLayout(s)
  end)
  check("Cleanup cancels an in-flight request without changing live world objects",function()
   local s=session()
   local thread=s.state.requests[1].thread
   s.controls.Cleanup()
   assert(coroutine.status(thread)=="dead" and s.state.cancelled==1 and s.controls.InFlight()==nil)
   s:tick(100)
   assert(#s.state.requests==1 and s.fallback.MostWins.Enabled and not s.gui.MostWins.Enabled)
  end)
  check("Native task cancellation succeeds under the exact controller capabilities",function()
   local cancellation=Instance.new("ModuleScript")
   cancellation.Capabilities=original.Capabilities
   cancellation.Sandboxed=original.Sandboxed
   cancellation.Source='local thread=task.spawn(function() task.wait(30) end) local ok,why=pcall(task.cancel,thread) assert(ok,why) assert(coroutine.status(thread)=="dead") return true'
   cancellation.Parent=fixture
   assert(require(cancellation))
  end)
  check("Authored tabs, headers and all ten rows remain inside the boards",function()
   assert(authored:IsA("ScreenGui") and not authored.ResetOnSpawn)
   for _,id in ipairs({"MostWins","HighestLevel"}) do
    local display=authored[id]
    assert(display:IsA("SurfaceGui") and display.Adornee and not display.Enabled)
    assert(display.Header.Size.Y.Offset==128)
    assert(display.ScopeTabs.Position.Y.Offset+display.ScopeTabs.Size.Y.Offset<display.Body.Position.Y.Offset)
    local last=display.Body.Row10
    assert(display.Body.Position.Y.Offset+last.Position.Y.Offset+last.Size.Y.Offset<display.Status.Position.Y.Offset)
    for _,scope in ipairs({"global","server","region"}) do
     local button=display.ScopeTabs[scope]
     assert(button.Active and button.Selectable and button.NextSelectionLeft and button.NextSelectionRight)
     assert(button.Caption.TextXAlignment==Enum.TextXAlignment.Center and button.Caption.TextYAlignment==Enum.TextYAlignment.Center)
     assert(button.Caption.TextOutline.ApplyStrokeMode==Enum.ApplyStrokeMode.Contextual)
     assert(button.Caption.TextOutline.BorderStrokePosition==Enum.BorderStrokePosition.Outer)
    end
   end
  end)
  local function podium(s) return game:GetService("HttpService"):JSONDecode(s.gui:GetAttribute("PodiumSnapshot")) end
  check("Podium starts with only the top three winners from Most Wins Global",function()
   local s=session()
   local reply=response("global","First")
   for index=2,10 do table.insert(reply.boards.MostWins.entries,{userId=12344+index,name="Player"..index,value=tostring(421-index),image=""}) end
   s:resolve(1,reply)
   local p=podium(s)
   assert(p.board=="MostWins" and p.scope=="global" and p.state=="ready" and #p.entries==3 and p.entries[3].name=="Player3")
   assert(#s.state.requests==1)
  end)
  check("Clicking an already-selected metric tab updates the podium without a request",function()
   local s=session() s:resolve(1,response("global","Champion"))
   s:select("HighestLevel","global")
   local p=podium(s)
   assert(p.board=="HighestLevel" and p.entries[1].value=="LV 38" and #s.state.requests==1)
  end)
  check("New scope clears the podium until matching ranks arrive and carries broad region",function()
   local s=session() s:resolve(1,response("global","Global"))
   s:select("MostWins","region")
   local p=podium(s) assert(p.scope=="region" and p.state=="loading" and #p.entries==0)
   s:tick(1.06) s:resolve(2,response("region","Regional","ready","Europe"))
   p=podium(s) assert(p.region=="Europe" and p.entries[1].name=="Regional")
   s:select("HighestLevel","region")
   p=podium(s) assert(p.board=="HighestLevel" and p.entries[1].value=="LV 38" and #s.state.requests==2)
  end)
  check("A reply for a deselected scope cannot replace the podium",function()
   local s=session() s:resolve(1,response("global"))
   s:select("MostWins","server") s:tick(1.06)
   s:select("MostWins","region")
   s:resolve(2,response("server","Wrong"))
   local p=podium(s) assert(p.scope=="region" and p.state=="loading" and #p.entries==0)
  end)
  check("Failed refresh marks saved podium data stale including after reselecting its tab",function()
   local s=session() s:resolve(1,response("global","Saved"))
   s:tick(60.1) s:resolve(2,nil,true)
   local p=podium(s) assert(p.state=="stale" and p.entries[1].name=="Saved")
   s:select("MostWins","global")
   p=podium(s) assert(p.state=="stale" and p.entries[1].name=="Saved")
  end)
  check("Unavailable new scope never copies winners from previous scope",function()
   local s=session() s:resolve(1,response("global","Wrong"))
   s:select("MostWins","server") s:tick(1.06) s:resolve(2,nil,true)
   local p=podium(s) assert(p.scope=="server" and p.state=="unavailable" and #p.entries==0)
   s:select("MostWins","server")
   p=podium(s) assert(p.state=="unavailable" and #p.entries==0)
  end)
  check("Exact installed controller capabilities are retained and Play is stopped",function()
   assert(module.Capabilities==original.Capabilities and module.Sandboxed==original.Sandboxed)
   assert(not game:GetService("RunService"):IsRunning())
   report.capabilities=tostring(module.Capabilities)
   report.sandboxed=module.Sandboxed
  end)
 end,debug.traceback)
 for _,s in ipairs(sessions) do s.controls.Cleanup() end
 fixture:Destroy()
 report.fixtureDestroyed=fixture.Parent==nil
 report.passed=ok
 if not ok then report.error=failure else report.currentCheck=nil end
 return report
end
