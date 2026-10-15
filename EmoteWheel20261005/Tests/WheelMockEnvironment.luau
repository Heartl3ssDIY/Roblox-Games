local NativeContentProvider = game:GetService("ContentProvider")
local clock = 100
local jobs, pending = {}, {}
local function signal()
 local callbacks={}
 return {Connect=function(_,callback)
  local connection={Connected=true}
  function connection:Disconnect()self.Connected=false end
  table.insert(callbacks,{connection,callback}) return connection
 end,Fire=function(_,...)for _,entry in ipairs(callbacks)do if entry[1].Connected then entry[2](...) end end end}
end
local function object(name,parent)
 local o={Name=name,Parent=parent,Visible=true,Enabled=true,Active=true,Selectable=true,IsLoaded=true,Image="",Text="",attrs={},signals={}}
 for _,key in ipairs({"Activated","MouseEnter","MouseLeave","SelectionGained","SelectionLost","Destroying","CharacterAdded","CharacterRemoving","ChildAdded","LastInputTypeChanged"})do o[key]=signal()end
 function o:WaitForChild(key)return self[key]end
 function o:FindFirstChild(key)return self[key]end
 function o:IsA(key)return key=="RemoteFunction" and self.isRemote==true end
 function o:IsDescendantOf(ancestor)local p=self while p do if p==ancestor then return true end p=p.Parent end return false end
 function o:GetAttribute(key)return self.attrs[key]end
 function o:SetAttribute(key,value)self.attrs[key]=value self:GetAttributeChangedSignal(key):Fire()end
 function o:GetAttributeChangedSignal(key)self.signals[key]=self.signals[key]or signal()return self.signals[key]end
 function o:GetPropertyChangedSignal(key)return self:GetAttributeChangedSignal(key)end
 return o
end
local function resumeJob(job,...)
 if coroutine.status(job.thread)=="dead"then return end
 local ok,delay=coroutine.resume(job.thread,...)
 assert(ok,delay)
 job.when=typeof(delay)=="number" and clock+delay or nil
end
local task={}
function task.spawn(callback)
 local job={thread=coroutine.create(callback)} table.insert(jobs,job)resumeJob(job)return job.thread
end
function task.delay(delay,callback)local job={thread=coroutine.create(callback),when=clock+delay}table.insert(jobs,job)return job.thread end
function task.wait(delay)return coroutine.yield(delay or 0)end
function task.cancel(thread)coroutine.close(thread)end
function task.defer(callback)return task.delay(0,callback)end
local function advance(amount)
 clock+=amount
 local snapshot=table.clone(jobs)
 for _,job in ipairs(snapshot)do if job.when and job.when<=clock and coroutine.status(job.thread)~="dead"then resumeJob(job)end end
end
local function complete(request,reply)
 request.reply=reply
 for _,job in ipairs(jobs)do if job.thread==request.thread then
  if coroutine.status(job.thread)=="dead"then return false end
  resumeJob(job,reply)return true
 end end
 error("Missing request worker")
end
local clockOs={clock=function()return clock end}
local os=clockOs
local workspace={GetServerTimeNow=function()return clock end}
local fakeGui=object("PlaygroundEmoteWheel")
fakeGui.Panel=object("Panel",fakeGui)fakeGui.Panel.Visible=false
fakeGui.Backdrop=object("Backdrop",fakeGui)fakeGui.Toggle=object("Toggle",fakeGui)
for _,key in ipairs({"PageLabel","Previous","Next","StopButton","Status","Hint","ShopButton","Close","Wheel"})do fakeGui.Panel[key]=object(key,fakeGui.Panel)end
for i=1,8 do
 local slot=object("Slot"..i,fakeGui.Panel.Wheel)fakeGui.Panel.Wheel[slot.Name]=slot
 for _,key in ipairs({"Thumbnail","ItemName","Selected","State"})do slot[key]=object(key,slot)end
end
local fakeScript=object("Controller",fakeGui)
local fakePlayer=object("Player")fakePlayer.attrs.PCDataReady=true
fakePlayer.PlayerGui=object("PlayerGui")
fakeGui.Parent=fakePlayer.PlayerGui
local shell=object("PlaygroundShell",fakePlayer.PlayerGui)fakePlayer.PlayerGui.PlaygroundShell=shell
for _,key in ipairs({"ShopPanel","VotePanel","CompactVotePanel"})do shell[key]=object(key,shell)shell[key].Visible=false end
local remote=object("PlaygroundShopRequest")remote.isRemote=true
function remote:InvokeServer(action,id)
 local row={action=action,id=id,thread=coroutine.running()};table.insert(pending,row)
 return coroutine.yield("remote")
end
local rep=object("ReplicatedStorage")rep.PlaygroundShopRequest=remote rep.PlaygroundCatalog={}
local fakeCatalog={Items={},ById={}}
for i=1,20 do local item={id="E"..string.format("%02d",i),name="Dance "..i,slot="Emote",playable=true,available=true,thumbnail="rbxthumb://type=Asset&id="..i.."&w=150&h=150"} table.insert(fakeCatalog.Items,item)fakeCatalog.ById[item.id]=item end
fakeCatalog.Items[7].available=false
fakeCatalog.Items[19].slot="Pet"
fakeCatalog.Items[20].playable=false
local fakeUIS=object("UserInputService")fakeUIS.input=Enum.UserInputType.Keyboard fakeUIS.TouchEnabled=false
function fakeUIS:GetFocusedTextBox()return self.focus end
function fakeUIS:GetLastInputType()return self.input end
local fakeCAS={}
function fakeCAS:BindActionAtPriority(name,callback,...)self.name=name self.callback=callback end
function fakeCAS:UnbindAction(name)self.unbound=name end
local fakeGS={MenuIsOpen=false}
local fakeSG={native=true,sets={}}
function fakeSG:GetCoreGuiEnabled()return self.native end
function fakeSG:SetCoreGuiEnabled(_,value)self.native=value table.insert(self.sets,value)end
local fakeCP={stall=false}
function fakeCP:PreloadAsync(_,callback)if self.stall then coroutine.yield("preload")else callback("image",Enum.AssetFetchStatus.Success)end end
local services={Players={LocalPlayer=fakePlayer},ReplicatedStorage=rep,UserInputService=fakeUIS,ContextActionService=fakeCAS,GuiService=fakeGS,StarterGui=fakeSG,ContentProvider=fakeCP}
local game={GetService=function(_,key)return services[key]end}
local script=fakeScript
local require=function()return fakeCatalog end
