return function(moduleSource,handlerSource)
 local checks=0
 local function check(value,message) checks+=1 assert(value,message) end
 local function run(source,values)
  local fn,err=loadstring(source) assert(fn,err)
  setfenv(fn,setmetatable(values,{__index=getfenv()}))
  return fn()
 end
 local function fixture()
  local pending,calls,notifications={},0,{}
  local now=1
  local tokens={GBloxEmoteCatalog={},GBloxEmoteRules={},PlayerData={}}
  local catalog={ById={owned={Name="Owned",AnimationId="rbxassetid://900"}}}
  local rules={Sanitize=function(value) return value end,IsEquipped=function(state,id) return table.find(state.Equipped,id)~=nil end}
  local data={Get=function() return {Emotes={Owned={owned=true},Equipped={"owned"}}} end}
  local modules={[tokens.GBloxEmoteCatalog]=catalog,[tokens.GBloxEmoteRules]=rules,[tokens.PlayerData]=data}
  local services={}
  function services.GetHumanoidDescriptionFromUserIdAsync()
   return {GetEmotes=function() return {Native={123}} end,Destroy=function() end}
  end
  local failed=false
  local inserted={LoadAsset=function()
   calls+=1
   if failed then error("Simulated asset failure") end
   return {FindFirstChildWhichIsA=function() return {AnimationId="rbxassetid://321"} end,Destroy=function() end}
  end}
  local g={ReplicatedStorage={WaitForChild=function(_,name) return tokens[name] end},ServerScriptService={WaitForChild=function(_,name) return tokens[name] end}}
  function g:GetService(name) return name=="Players" and services or inserted end
  local e=run(moduleSource,{game=g,require=function(token) return modules[token] end,task={spawn=function(fn) table.insert(pending,fn) end,wait=function() end},os={clock=function() return now end}})
  e.SetAnimationReadyHandler(function(p,key,id) table.insert(notifications,{player=p,key=key,id=id}) end)
  local attrs={}
  local player={Parent=true,UserId=42}
  function player:SetAttribute(name,value) attrs[name]=value end
  function player:GetAttribute(name) return attrs[name] end
  local function nextTask()
   local taskToRun=table.remove(pending,1)
   check(taskToRun~=nil,"Expected deferred resolver task")
   taskToRun()
  end
  return {module=e,player=player,attrs=attrs,pending=pending,notifications=notifications,nextTask=nextTask,
   fail=function() failed=true end,advance=function() now+=1 end,calls=function() return calls end}
 end
 local f=fixture()
 f.module.Register(f.player) f.nextTask()
 check(f.attrs.RankingEmotesLoaded==true,"Avatar option list is ready without blocking on asset resolution")
 check(f.module.Select(f.player,"avatar:Native"),"Native emote can be selected while resolution is pending")
 check(f.module.AnimationId(f.player,"avatar:Native")==nil and #f.notifications==0,"Reproduces the original early-selection race")
 f.nextTask()
 check(#f.notifications==1 and f.notifications[1].id=="rbxassetid://321","Late resolution notifies current selection exactly once")
 check(f.module.AnimationId(f.player,"avatar:Native")=="rbxassetid://321","Resolved ID remains cached")
 check(f.calls()==1,"Fix issues no extra catalog request")
 check(f.module.Options(f.player)[5].animationId=="rbxassetid://321","Options still carry resolved preview ID")
 f.advance()
 check(f.module.Select(f.player,"shop:owned"),"Equipped shop emote selection is unchanged")
 check(f.module.AnimationId(f.player,"shop:owned")=="rbxassetid://900","Shop emote direct ID is unchanged")
 for _,kind in {"switched","removed","reregistered","failed","handlerRemoved"} do
  local item=fixture()
  item.module.Register(item.player) item.nextTask()
  item.module.Select(item.player,"avatar:Native")
  if kind=="switched" then item.advance() item.module.Select(item.player,"idle")
  elseif kind=="removed" then item.module.Remove(item.player)
  elseif kind=="reregistered" then item.module.Register(item.player)
  elseif kind=="failed" then item.fail()
  elseif kind=="handlerRemoved" then item.module.SetAnimationReadyHandler(nil) end
  item.nextTask()
  check(#item.notifications==0,"No obsolete/failed callback after "..kind)
 end
 local function handlerFixture(options)
  options=options or {}
  local player={UserId=42,Parent=not options.left}
  local row={userId=options.wrongUser and 99 or 42,emoteKey=options.wrongRow and "idle" or "avatar:Native"}
  local packet=not options.noPacket and {courseVersion=options.oldVersion and 1 or 2,rows={row}} or nil
  local racers=options.missingRunner and {} or {[player]={leavingLobby=options.leaving}}
  local sent={}
  local callback=run("return "..handlerSource,{
   players=racers,roundPhase=options.running and "Running" or "Intermission",
   lastRankingPacket=packet,courseVersion=2,
   RankingEmotes={Selected=function() return options.switched and "idle" or "avatar:Native" end},
   event={FireAllClients=function(_,action,payload) table.insert(sent,{action=action,payload=payload}) end},
  })
  callback(player,"avatar:Native","rbxassetid://321")
  if next(options)==nil then
   check(#sent==1 and row.emoteAnimationId=="rbxassetid://321","Current ranking row receives late resolved ID")
   check(sent[1].action=="RankingEmoteChanged" and sent[1].payload.courseVersion==2 and sent[1].payload.userId==42,"Broadcast retains current version and owner")
  else
   check(#sent==0 and row.emoteAnimationId==nil,"Stale/ineligible intermission update is suppressed")
  end
 end
 for _,options in {{},{left=true},{wrongUser=true},{wrongRow=true},{noPacket=true},{oldVersion=true},{missingRunner=true},{leaving=true},{running=true},{switched=true}} do handlerFixture(options) end
 return {passed=checks,networkRequests=0,scope="Deterministic deferred-resolution and current-round broadcast mocks only"}
end
