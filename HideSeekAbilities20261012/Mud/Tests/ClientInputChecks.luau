local runController=require(script.Parent.ClientCandidate)
local result={}
local function signal()
 local callbacks={}
 local value={}
 function value:Connect(fn)
  local entry={callback=fn,live=true} table.insert(callbacks,entry)
  return {Disconnect=function() entry.live=false end}
 end
 function value:Fire(...) for _,entry in ipairs(callbacks) do if entry.live then entry.callback(...) end end end
 return value
end
local function fixture(touch)
 local gui=game.StarterGui.MudHUD:Clone() gui.Parent=script.Parent gui.ColourPicker.Visible=false
 local env={now=100,callbacks={},calls={}}
 local input={TouchEnabled=touch,PreferredInput=touch and Enum.PreferredInput.Touch or Enum.PreferredInput.KeyboardAndMouse,MouseBehavior=Enum.MouseBehavior.Default}
 for _,name in ipairs({"InputEnded","InputChanged","WindowFocusReleased","WindowFocused","TextBoxFocused"}) do input[name]=signal() end
 function input:GetFocusedTextBox() return self.textFocused end
 function input:GetMouseLocation() return Vector2.new(500,300) end
 local run={Heartbeat=signal()}
 function run:BindToRenderStep(_,_,fn) self.render=fn end
 function run:UnbindFromRenderStep() self.render=nil end
 local pValues={MDParticipating=true,MDTool="MudGun",MDSprintMax=10,MDSprintRemaining=10}
 local sValues={Phase="Playing",EndsAt=500,TeamCount=2,TeamSummaryJSON="[]",MudCooldownSeconds=0.65}
 local state={GetAttribute=function(_,key) return sValues[key] end}
 local remote={InvokeServer=function(_,action,value,aim) table.insert(env.calls,{action=action,value=value,aim=aim}) return {ok=true} end}
 local backpack={ChildAdded=signal(),children={}}
 function backpack:IsA(name) return name=="Backpack" end
 function backpack:GetChildren() return self.children end
 function backpack:FindFirstChild(name) for _,v in ipairs(self.children) do if v.Name==name then return v end end end
 local character={ChildAdded=signal(),children={}}
 function character:GetChildren() return self.children end
 function character:FindFirstChild(name) for _,v in ipairs(self.children) do if v.Name==name then return v end end end
 local humanoid={}
 function humanoid:EquipTool(tool)
  for _,old in ipairs(character.children) do old.Parent=backpack old.Unequipped:Fire() table.insert(backpack.children,old) end
  character.children={tool} tool.Parent=character character.ChildAdded:Fire(tool)
 end
 function character:FindFirstChildOfClass(name) return name=="Humanoid" and humanoid or nil end
 local player={Character=character,CharacterAdded=signal(),CharacterRemoving=signal(),ChildAdded=signal(),PlayerGui={FindFirstChild=function() end}}
 function player:GetAttribute(key) return pValues[key] end
 function player:FindFirstChildOfClass(name) return name=="Backpack" and backpack or nil end
 local function tool(name)
  local t={Name=name,Parent=character,Enabled=true,Activated=signal(),Deactivated=signal(),Unequipped=signal()}
  function t:IsA(kind) return kind=="Tool" end
  function t:GetAttribute(key) return key=="MDManaged" and true or nil end
  return t
 end
 local mud=tool("MudGun") local heat=tool("HeatGun") heat.Parent=backpack
 character.children={mud} backpack.children={heat}
 local camera={ViewportSize=Vector2.new(1000,600),ViewportPointToRay=function(_,x,y) env.rayPixel=Vector2.new(x,y) return Ray.new(Vector3.new(0,3,4),Vector3.new(0,0,-1)) end}
 local services={Players={LocalPlayer=player},ReplicatedStorage={WaitForChild=function(_,name) return name=="MudState" and state or remote end},RunService=run,UserInputService=input,
  ContextActionService={BindActionAtPriority=function() end,UnbindAction=function() end},HttpService=game:GetService("HttpService"),
  GuiService={GetInsetArea=function() return Rect.new(0,-58,1000,542) end}}
 env.game={GetService=function(_,name) return services[name] end}
 env.workspace={CurrentCamera=camera,GetServerTimeNow=function() return env.now end}
 env.script={Parent=gui,Destroying=signal()}
 env.os={clock=function() return env.now end}
 env.gui,env.input,env.run,env.player,env.character,env.mud,env.heat,env.pValues,env.sValues,env.backpack=gui,input,run,player,character,mud,heat,pValues,sValues,backpack
 env.controller=runController(env)
 table.clear(env.calls)
 function env:count(action,value) local count=0 for _,c in ipairs(self.calls) do if c.action==action and (value==nil or c.value==value) then count+=1 end end return count end
 function env:step(delta) self.now+=delta self.run.Heartbeat:Fire(delta) if self.run.render then self.run.render() end end
 function env:inputFire() local i={UserInputType=Enum.UserInputType.Touch} self.callbacks.fire(i) return i end
 function env:destroy() self.script.Destroying:Fire() self.gui:Destroy() end
 return env
end
local function check(name,touch,fn)
 local env
 local ok,errorMessage=xpcall(function() env=fixture(touch) fn(env) end,debug.traceback)
 if env then env:destroy() end
 table.insert(result,{name=name,passed=ok,error=not ok and tostring(errorMessage) or nil})
end
check("Very quick PC click fires exactly once before next frame",false,function(e)
 e.mud.Activated:Fire() e.mud.Deactivated:Fire() e:step(0.016)
 assert(e:count("Fire")==1,"quick click was dropped")
end)
check("Very quick phone fire-button tap fires exactly once",true,function(e)
 local i=e:inputFire() e.input.InputEnded:Fire(i) e:step(0.016)
 assert(e:count("Fire")==1,"quick tap was dropped")
end)
check("Camera pan on touch does not fire the Tool",true,function(e)
 e.mud.Activated:Fire() e:step(0.016)
 assert(e:count("Fire")==0,"camera movement fired the gun")
end)
check("Touch fire remains held when native Tool deactivates",true,function(e)
 e:inputFire() e.mud.Deactivated:Fire() e:step(0.8)
 assert(e:count("Fire")==2,"tool deactivation cancelled fire-button hold")
end)
check("Switching to Heat uses actual equipped Tool before attribute replication",false,function(e)
 e.mud.Parent=e.backpack e.heat.Parent=e.character e.character.children={e.heat}
 e.character.ChildAdded:Fire(e.heat)
 e.heat.Activated:Fire() e:step(0.016)
 assert(e:count("Heat",true)==1 and e:count("Fire")==0,"stale MDTool selected wrong weapon")
end)
check("Holding Mud respects cooldown and stops on release",false,function(e)
 e.mud.Activated:Fire() e:step(0.1) assert(e:count("Fire")==1)
 e:step(0.6) assert(e:count("Fire")==2)
 e.mud.Deactivated:Fire() e:step(1) assert(e:count("Fire")==2)
end)
check("Stuck players cannot fire",false,function(e)
 e.pValues.MDMuddy=true e.mud.Activated:Fire() e:step(0.016) assert(e:count("Fire")==0)
end)
check("Opening colour menu cancels firing",false,function(e)
 e.mud.Activated:Fire() e:step(0.02) local before=e:count("Fire")
 e.gui.ColourPicker.Visible=true e:step(1) assert(e:count("Fire")==before)
end)
check("Text entry never starts gunfire",false,function(e)
 e.input.textFocused=true e.mud.Activated:Fire() e:step(0.016) assert(e:count("Fire")==0)
end)
check("Touch sprint does not fire",true,function(e)
 e.callbacks.sprint({UserInputType=Enum.UserInputType.Touch})
 e:step(0.016) assert(e:count("Fire")==0)
end)
check("Respawn reconnects once to new tools",false,function(e)
 local old=e.mud local new={Name="MudGun",Enabled=true,Activated=signal(),Deactivated=signal(),Unequipped=signal(),IsA=old.IsA,GetAttribute=old.GetAttribute}
 local character={children={new},ChildAdded=signal(),GetChildren=e.character.GetChildren,FindFirstChild=e.character.FindFirstChild,FindFirstChildOfClass=e.character.FindFirstChildOfClass}
 new.Parent=character e.player.Character=character e.player.CharacterAdded:Fire(character)
 old.Activated:Fire() e:step(0.02) assert(e:count("Fire")==0)
 new.Activated:Fire() new.Deactivated:Fire() e:step(0.02) assert(e:count("Fire")==1)
end)
local passed=0 for _,v in ipairs(result) do if v.passed then passed+=1 end end
return {passed=passed,total=#result,checks=result}
