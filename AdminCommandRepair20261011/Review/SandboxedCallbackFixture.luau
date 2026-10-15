local SSS = game:GetService("ServerScriptService")
local SS = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local temporary = Instance.new("Folder")
temporary.Name = "AdminRealBeginAuditTemporary"
temporary.Parent = SS
local warnings = {}
local listener = game:GetService("LogService").MessageOut:Connect(function(message)
 if message:find("Playground admin command failed:", 1, true) then table.insert(warnings, message) end
end)
local ok, result = xpcall(function()
 local modules = {}
 for _, name in ipairs({"PlaygroundAdminService","PlaygroundCoordinator","PlaygroundEquipmentService","PlaygroundToyService","BritishBulldogRules","BritishBulldogService","TagService","StuckInTheMudService"}) do
  local clone = SSS[name]:Clone()
  clone.Parent = temporary
  modules[name] = clone
 end
 local callback = Instance.new("ModuleScript")
 callback.Name, callback.Sandboxed, callback.Capabilities = "AdminCallback", true, SSS.PlaygroundAdminService.Capabilities
 callback.Source = "return function(admin, player, action, payload) return admin:Handle(player, action, payload) end"
 callback.Parent = temporary
 local invokeAdmin = require(callback)
 local wrapper = Instance.new("ModuleScript")
 wrapper.Name, wrapper.Sandboxed, wrapper.Capabilities = "BootstrapWrapper", true, SSS.PlaygroundBootstrap.Capabilities
 wrapper.Source = [=[
 return function(service, methodName, equipment)
  local original = service[methodName]
  service[methodName] = function(instance, selected, ...)
   equipment:PrepareRound(selected)
   return original(instance, selected, ...)
  end
 end
 ]=]
 wrapper.Parent = temporary
 local wrap = require(wrapper)
 local Admin, Coordinator = require(modules.PlaygroundAdminService), require(modules.PlaygroundCoordinator)
 local Equipment, Toys = require(modules.PlaygroundEquipmentService), require(modules.PlaygroundToyService)
 local gameTypes = {BritishBulldog=require(modules.BritishBulldogService),TagYoureIt=require(modules.TagService),StuckInTheMud=require(modules.StuckInTheMudService)}
 local config = Instance.new("Folder")
 config.Name, config.Parent = "TestAdminConfig", temporary
 config:SetAttribute("AdminUserId", 123)
 local actors = {}
 for index=1,2 do
  local character = Instance.new("Model")
  character.Name, character.Parent = "AuditCharacter"..index, temporary
  local root = Instance.new("Part") root.Name,root.Anchored,root.Parent="HumanoidRootPart",true,character
  local humanoid=Instance.new("Humanoid") humanoid.Parent=character
  local backpack=Instance.new("Folder") backpack.Name,backpack.Parent="Backpack"..index,temporary
  local attrs={PCDataReady=true}
  local actor={UserId=index==1 and 123 or 456,Name="AuditPlayer"..index,DisplayName="AuditPlayer"..index,Parent=Players,Character=character}
  function actor:GetAttribute(name)return attrs[name]end
  function actor:SetAttribute(name,value)attrs[name]=value end
  function actor:FindFirstChildOfClass(class)return class=="Backpack" and backpack or nil end
  function actor:FindFirstChild()return nil end
  actors[index]={player=actor,character=character,root=root,humanoid=humanoid,backpack=backpack,attrs=attrs}
 end
 local players={GetPlayers=function()return {actors[1].player,actors[2].player}end}
 function players:GetPlayerByUserId(id) for _,actor in ipairs(actors)do if actor.player.UserId==id then return actor.player end end end
 local answer={}
 for _,spec in ipairs({
  {"BBStart","BritishBulldog"},{"BBRunner","BritishBulldog"},{"BBBulldog","BritishBulldog"},
  {"TagStart","TagYoureIt"},{"TagRunner","TagYoureIt"},{"TagTagger","TagYoureIt"},
  {"MudStart","StuckInTheMud"}
 })do
  for _,actor in ipairs(actors)do table.clear(actor.attrs) actor.attrs.PCDataReady=true end
  local arena=Instance.new("Folder") arena.Name,arena.Parent="Arena_"..spec[1],temporary
  arena:SetAttribute("MinimumPlayers",2)
  local state=Instance.new("Folder") state.Name,state.Parent="State_"..spec[1],temporary
  local shared=Instance.new("Folder") shared.Name,shared.Parent="Shared_"..spec[1],temporary
  local service=setmetatable({arena=arena,state=state,records={},running=true,active=false,mode="Waiting",phase="Waiting",random=Random.new()},gameTypes[spec[2]])
  for _,actor in ipairs(actors)do service.records[actor.player]={ready=true,character=actor.character,root=actor.root,humanoid=actor.humanoid,player=actor.player,isBot=false}end
  service._run=function(self,selected)self.lastCount=#selected end
  service._runRound=service._run
  service._createPracticeBot=function()return {Name="IsolatedBot"}end
  service._newBot=service._createPracticeBot
  service._weaponsReady=function()return true end
  if spec[2]=="StuckInTheMud"then service._readyPlayers=function()return {actors[1].player,actors[2].player}end end
  local toys=Toys.new()
  local equipment=Equipment.new({},toys)
  for _,actor in ipairs(actors)do
   local tool=Instance.new("Tool") tool.Name,tool.RequiresHandle,tool.Parent="AuditToy",false,actor.character
   tool:SetAttribute("PCToy",true)
   tool:SetAttribute("CatalogId","M01")
   equipment.records[actor.player]={player=actor.player,character=actor.character,gear=tool,gearId="M01",gearConnections={},closed=false}
   toys.records[actor.player]={player=actor.player,character=actor.character,humanoid=actor.humanoid,serial=0,busyUntil=0,base={WalkSpeed=16},written={WalkSpeed=16}}
  end
  local method=spec[2]=="BritishBulldog" and "_beginRound" or "_begin"
  wrap(service,method,equipment)
  local coordinator=setmetatable({services={[spec[2]]=service},state=shared,votes={},autoEnabled=false,_readyPlayers=function()return {actors[1].player,actors[2].player}end},Coordinator)
  local admin=Admin.new(coordinator,config,true,players)
  local firstWarning=#warnings
  local passed,reply=pcall(invokeAdmin,admin,actors[1].player,spec[1],{})
  task.wait()
  local failures={}
  for i=firstWarning+1,#warnings do table.insert(failures,warnings[i])end
  answer[spec[1]]={passed=passed,reply=reply,warnings=failures,runCount=service.lastCount,clearedToy=equipment.records[actors[1].player].gear==nil,toysReset=toys.records[actors[1].player]==nil}
 end
 return answer
end,debug.traceback)
listener:Disconnect()
temporary:Destroy()
return {ok=ok,result=result}

