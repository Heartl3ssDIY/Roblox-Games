local temporary=Instance.new("Folder") temporary.Name="HideSeekAbilityClientChecksTemporary" temporary.Parent=game.ServerStorage
local count=0
local function check(value,message) assert(value,message) count+=1 end
local ok,result=xpcall(function()
 local source=game.StarterGui.HideAndSeekHUD.Abilities.Source
 source=source:gsub("function Abilities.Start%(gui, state, remote%)","function Abilities.Start(gui, state, remote, environment)",1)
 source=source:gsub("local player = Players.LocalPlayer",[=[local Players, RunService, UserInputService, ContextActionService, GuiService = environment.Players, environment.RunService, environment.UserInputService, environment.ContextActionService, environment.GuiService
 local player = Players.LocalPlayer]=],1)
 local module=game.StarterGui.HideAndSeekHUD.Abilities:Clone() module.Source=source module.Parent=temporary
 local Abilities=require(module)
 local function signal()
  local event=Instance.new("BindableEvent") event.Parent=temporary return event
 end
 local heartbeat,characterRemoving,playerRemoving,focusReleased,focusGained,inputChanged=signal(),signal(),signal(),signal(),signal(),signal()
 local function actor(id,role)
  local attrs={HSParticipating=true,HSRole=role,HSPropMorphed=role=="Hider",HSDecoyCount=0}
  local character=Instance.new("Model") character.Name="TestAvatar"..id character.Parent=temporary
  local root=Instance.new("Part") root.Name="HumanoidRootPart" root.Anchored=true root.Parent=character
  local humanoid=Instance.new("Humanoid") humanoid.Parent=character
  local prop=Instance.new("Model") prop.Name="SchoolPropMorph" prop.Parent=character
  local part=Instance.new("Part") part.Anchored=true part.Parent=prop
  local object={UserId=id,Character=character,CharacterRemoving=characterRemoving.Event}
  function object:GetAttribute(name) return attrs[name] end
  return object,attrs
 end
 local owner,attrs=actor(70001,"Hider")
 local opponent,otherAttrs=actor(70002,"Hider")
 local seeker,seekerAttrs=actor(70003,"Seeker")
 local players={LocalPlayer=owner,PlayerRemoving=playerRemoving.Event,GetPlayers=function()return {owner,opponent,seeker}end}
 function players:GetPlayerByUserId(id) for _,p in ipairs(self:GetPlayers()) do if p.UserId==id then return p end end end
 local input={TouchEnabled=false,KeyboardEnabled=true,WindowFocusReleased=focusReleased.Event,WindowFocused=focusGained.Event,LastInputTypeChanged=inputChanged.Event,
 GetFocusedTextBox=function()return nil end,GetLastInputType=function()return Enum.UserInputType.Keyboard end,GetStringForKeyCode=function(_,key)return key.Name end}
 local actions={}
 local cas={BindActionAtPriority=function(_,name,fn)actions[name]=fn end,UnbindAction=function(_,name)actions[name]=nil end}
 local environment={Players=players,RunService={Heartbeat=heartbeat.Event},UserInputService=input,ContextActionService=cas,GuiService={MenuIsOpen=false}}
 local gui=game.StarterGui.HideAndSeekHUD:Clone()
 for _,child in ipairs(gui:GetDescendants()) do if child:IsA("LocalScript") then child.Enabled=false end end
 gui.Enabled=true gui.Parent=temporary
 local state=Instance.new("Folder") state.Name="TestState" state.Parent=temporary state:SetAttribute("Phase","Seeking")
 local sent={}
 local stop=Abilities.Start(gui,state,{FireServer=function(_,action)table.insert(sent,action)end},environment)
 local effectFolder=workspace:FindFirstChild("LocalHideSeekRevealEffects")
 check(effectFolder~=nil,"Effect container missing")
 local function tick() heartbeat:Fire(0.2) task.wait() end
 local function press(key) return actions.HideSeekPropAbilities("HideSeekPropAbilities",Enum.UserInputState.Begin,{KeyCode=key}) end
 check(Abilities.Describe(owner,"Seeking",100).primary=="ChangeProp","Hider E")
 attrs.HSSwitchReadyAt=105
 check(not Abilities.Describe(owner,"Seeking",100).primaryReady,"Switch cooldown")
 attrs.HSSwitchReadyAt=0
 check(Abilities.Describe(owner,"Seeking",100).decoyReady,"Decoy available")
 check(press(Enum.KeyCode.E)==Enum.ContextActionResult.Sink and sent[1]=="ChangeProp","E dispatch")
 task.wait(0.22)
 press(Enum.KeyCode.Q)
 check(sent[2]=="DropDecoy","Q dispatch")
 attrs.HSHiding=true tick()
 check(press(Enum.KeyCode.E)==Enum.ContextActionResult.Pass,"Locker consumes no switch")
 attrs.HSHiding=false
 otherAttrs.HSRevealedUntil=workspace:GetServerTimeNow()+10 otherAttrs.HSRevealSource=70003 tick()
 check(#effectFolder:GetChildren()==0,"Hider can see another hidden player")
 attrs.HSRevealedUntil=workspace:GetServerTimeNow()+5 attrs.HSRevealReason="Decoy" attrs.HSRevealSource=70003 tick()
 check(#effectFolder:GetChildren()==1,"Own reveal missing")
 local effect=effectFolder:FindFirstChild("70001")
 check(effect.RevealedHider.Adornee==owner.Character.SchoolPropMorph,"Prop highlight target")
 check(effect.RedRevealBeam.Enabled,"Red beam missing")
 local warning=gui[Abilities.Layout(workspace.CurrentCamera.ViewportSize,false).."RevealNotice"]
 check(warning.Visible and warning.Reason.Text=="A seeker hit your decoy","Decoy warning")
 attrs.HSRole="Seeker" attrs.HSPropMorphed=false tick()
 check(effectFolder:FindFirstChild("70001")==nil and effectFolder:FindFirstChild("70002")~=nil,"Seeker reveal visibility")
 task.wait(0.22)
 press(Enum.KeyCode.ButtonY)
 check(sent[3]=="Scan","Controller scan dispatch")
 attrs.HSScanActiveUntil=workspace:GetServerTimeNow()+10 attrs.HSScanReadyAt=workspace:GetServerTimeNow()+70 tick()
 local scan=Abilities.Describe(owner,"Seeking",workspace:GetServerTimeNow())
 check(scan.scanTime>9 and not scan.primaryReady and scan.primaryWait>69,"Scan active/cooldown")
 otherAttrs.HSRevealedUntil=0 tick()
 check(#effectFolder:GetChildren()==0,"Expired reveal remains")
 state:SetAttribute("Phase","Results") tick()
 for _,variant in ipairs({"Desktop","Compact","Portrait"}) do check(not gui[variant.."Abilities"].Visible,"Results ability visible") end
 check(Abilities.Describe(owner,"Results",100).primary==nil,"Results input")
 check(not Abilities.Describe(owner,"Hiding",100).primaryReady,"Blindfold scan allowed")
 local viewports={{1920,1080,false,"Desktop"},{1366,768,false,"Compact"},{1024,768,true,"Compact"},{844,390,true,"Compact"},{667,375,true,"Compact"},{568,320,true,"Compact"},{390,844,true,"Portrait"},{360,640,true,"Portrait"}}
 for _,spec in ipairs(viewports) do
  local width,height=spec[1],spec[2]
  local variant=Abilities.Layout(Vector2.new(width,height),spec[3])
  check(variant==spec[4],"Layout breakpoint")
  local bar=gui[variant.."Abilities"]
  local w,h=bar.Size.X.Scale*width+bar.Size.X.Offset,bar.Size.Y.Scale*height+bar.Size.Y.Offset
  local limit=bar:FindFirstChildOfClass("UISizeConstraint")
  if limit then w=math.clamp(w,limit.MinSize.X,limit.MaxSize.X) h=math.clamp(h,limit.MinSize.Y,limit.MaxSize.Y) end
  local x=bar.Position.X.Scale*width+bar.Position.X.Offset-bar.AnchorPoint.X*w
  local y=bar.Position.Y.Scale*height+bar.Position.Y.Offset-bar.AnchorPoint.Y*h
  check(x>=0 and x+w<=width and y>=0 and y+h<=height,"Ability off screen")
  check((w/2-4)>=86 and h>=44,"Touch targets too small")
  if variant=="Compact" then check(x>=160 and x+w<=width-160,"Ability overlaps thumb zones") end
 end
 stop()
 check(actions.HideSeekPropAbilities==nil,"Action not unbound")
 check(effectFolder.Parent==nil,"Effects not destroyed")
 check(seeker.Character.HumanoidRootPart:FindFirstChild("LocalRevealSource")==nil,"Source attachment leaked")
 return {checks=count,viewportCases=#viewports}
end,debug.traceback)
local leaked=workspace:FindFirstChild("LocalHideSeekRevealEffects") if leaked then leaked:Destroy() end
temporary:Destroy()
return {ok=ok,result=result}
