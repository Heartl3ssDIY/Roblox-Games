assert(not game:GetService("RunService"):IsRunning())
local sss=game:GetService("ServerScriptService")
local storage=game:GetService("ServerStorage")
local fixture=Instance.new("Folder") fixture.Name="_FinalWeaponLoadCheck" fixture.Parent=storage
local modules={}
local report={}
local ok,err=xpcall(function()
 local caller=sss.PlaygroundBootstrap:Clone() caller.Enabled=false caller.Parent=fixture
 local runner=Instance.new("ModuleScript") runner.Name="RequireInstalledServices"
 runner.Source="local out={} for _,link in ipairs(script.Parent:GetChildren()) do if link:IsA('ObjectValue') then local ok,result=pcall(require,link.Value) table.insert(out,{name=link.Name,passed=ok,result=ok and typeof(result) or tostring(result)}) end end return out"
 runner.Parent=caller
 for _,name in ipairs({"BritishBulldogService","TagService","TagSprintService","StuckInTheMudService","PlaygroundEquipmentService","PlaygroundAdminService"}) do
  local clone=sss[name]:Clone() clone.Name="_FinalLoad_"..name clone.Parent=sss table.insert(modules,clone)
  local link=Instance.new("ObjectValue") link.Name=name link.Value=clone link.Parent=caller
 end
 report=require(runner)
 for _,entry in ipairs(report) do assert(entry.passed,entry.name..": "..entry.result) end
end,debug.traceback)
for _,m in ipairs(modules) do m:Destroy() end
fixture:Destroy()
return {passed=ok,error=not ok and err or nil,modules=report,playStarted=false,launcherAnimation=tostring(sss.PlaygroundBootstrap.Capabilities):find("Animation",1,true)~=nil}

