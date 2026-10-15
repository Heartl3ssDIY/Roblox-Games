return function(sourceText)
 local storage=game:GetService("ServerStorage")
 local fixture=Instance.new("Folder")
 fixture.Name="_LevelUIChecks_"..game:GetService("HttpService"):GenerateGUID(false)
 fixture.Parent=storage
 local report={mode="Edit",playStarted=false,checks={},generatedAt=DateTime.now():ToIsoDate()}
 local sessions={}
 local function check(name,callback)
  report.currentCheck=name
  callback()
  table.insert(report.checks,{name=name,passed=true})
 end
 local ok,failure=xpcall(function()
  local original=game.StarterGui.PlaygroundShell.PlayerLevelController
  local module=Instance.new("ModuleScript")
  module.Name="LevelControllerChecks"
  module.Capabilities=original.Capabilities
  module.Sandboxed=original.Sandboxed
  local source=sourceText or original.Source
  source=source:gsub("local player=Players.LocalPlayer\n","",1):gsub("local gui=script.Parent\n","",1)
  module.Source="return function(player,gui,task)\n"..source.."\nreturn {Refresh=refresh,Cleanup=cleanup,Schedule=scheduleRefresh,Generation=function() return noticeGeneration end,Baseline=function() return lastAnnouncedLevel end,Alive=function() return alive end,Connections=connections}\nend"
  module.Parent=fixture
  local run=require(module)
  local function makeSession(attributes)
   local gui=Instance.new("ScreenGui")
   gui.Name="FixtureShell"
   gui.Parent=fixture
   for _,name in ipairs({"LevelPanel","CompactLevelPanel","LevelUpNotice"}) do
    local object=game.StarterGui.PlaygroundShell[name]:Clone()
    object.Parent=gui
   end
   local values=table.clone(attributes or {})
   local attrSignals={}
   local function signal()
    local callbacks={}
    local event={}
    function event:Connect(callback)
     local connection={Connected=true}
     function connection:Disconnect() self.Connected=false end
     table.insert(callbacks,{callback=callback,connection=connection})
     return connection
    end
    function event:Fire(...)
     for _,entry in ipairs(callbacks) do if entry.connection.Connected then entry.callback(...) end end
    end
    return event
   end
   local player={Character=nil,CharacterAdded=signal(),CharacterRemoving=signal(),CharacterAppearanceLoaded=signal()}
   function player:GetAttribute(name) return values[name] end
   function player:GetAttributeChangedSignal(name)
    if not attrSignals[name] then attrSignals[name]=signal() end
    return attrSignals[name]
   end
   function player:SetAttribute(name,value)
    if values[name]==value then return end
    values[name]=value
    if attrSignals[name] then attrSignals[name]:Fire() end
   end
   local clock={delayed={},deferred={}}
   function clock.delay(seconds,callback) table.insert(clock.delayed,{seconds=seconds,callback=callback}) end
   function clock.defer(callback) table.insert(clock.deferred,callback) end
   function clock.flush()
    local callbacks=clock.deferred clock.deferred={}
    for _,callback in ipairs(callbacks) do callback() end
   end
   function clock.finish()
    for _=1,5 do
     if #clock.delayed==0 then break end
     local callbacks=clock.delayed clock.delayed={}
     for _,entry in ipairs(callbacks) do entry.callback() end
    end
   end
   local layouts={}
   for _,object in ipairs(gui:GetDescendants()) do if object:IsA("GuiObject") then layouts[object]={Position=object.Position,Size=object.Size,AnchorPoint=object.AnchorPoint} end end
   local controls=run(player,gui,clock)
   local session={player=player,gui=gui,clock=clock,controls=controls,layouts=layouts}
   table.insert(sessions,session)
   return session
  end
  local function assertLayout(session)
   for object,properties in pairs(session.layouts) do
    for name,value in pairs(properties) do assert(object[name]==value,"Runtime changed authored "..object.Name.."."..name) end
   end
  end
  check("Loading profile never announces and displays loading state",function()
   local session=makeSession()
   assert(not session.gui.LevelUpNotice.Visible and session.controls.Baseline()==nil)
   assert(session.gui.LevelPanel.NextLevel.Text=="LOADING PROGRESS")
   session.player:SetAttribute("PCLevel",18)
   session.clock.flush()
   assert(not session.gui.LevelUpNotice.Visible and session.controls.Baseline()==nil)
   session.player:SetAttribute("PCLevelXP",500)
   session.player:SetAttribute("PCLevelXPRequired",1050)
   session.player:SetAttribute("PCDataReady",true)
   session.clock.flush()
   assert(not session.gui.LevelUpNotice.Visible and session.controls.Baseline()==18)
   assert(session.gui.LevelPanel.Level.Text=="LEVEL 18" and session.gui.LevelPanel.NextLevel.Text=="NEXT: LEVEL 19")
   assert(session.gui.LevelPanel.XP.Text=="500 / 1,050 XP" and session.gui.CompactLevelPanel.XP.Text=="500 / 1,050 XP")
   assertLayout(session)
  end)
  check("Already-loaded rejoin uses a silent current-level baseline",function()
   local session=makeSession({PCDataReady=true,PCLevel=76,PCLevelXP=12,PCLevelXPRequired=3950})
   assert(session.controls.Baseline()==76 and not session.gui.LevelUpNotice.Visible)
   assert(session.gui.LevelPanel.Level.Text=="LEVEL 76")
  end)
  check("Ready flag before missing level waits for a valid baseline",function()
   local session=makeSession({PCDataReady=true})
   assert(session.controls.Baseline()==nil)
   session.player:SetAttribute("PCLevel",12)
   session.clock.flush()
   assert(session.controls.Baseline()==12 and not session.gui.LevelUpNotice.Visible)
  end)
  check("A genuine level increase announces only once",function()
   local session=makeSession({PCDataReady=true,PCLevel=3})
   local initial=session.controls.Generation()
   session.player:SetAttribute("PCLevel",4)
   session.player:SetAttribute("PCLevelXP",15)
   session.player:SetAttribute("PCLevelXPRequired",350)
   session.clock.flush()
   assert(session.gui.LevelUpNotice.Visible and session.gui.LevelUpNotice.Level.Text=="LEVEL 4")
   assert(session.controls.Generation()==initial+1)
   session.controls.Refresh()
   session.player:SetAttribute("PCLevel",4)
   session.player:SetAttribute("PCXP",777)
   session.clock.flush()
   assert(session.controls.Generation()==initial+1)
   assertLayout(session)
  end)
  check("Batched multi-level gain announces the latest level",function()
   local session=makeSession({PCDataReady=true,PCLevel=2})
   local initial=session.controls.Generation()
   for _,level in ipairs({3,4,7,9}) do session.player:SetAttribute("PCLevel",level) end
   session.clock.flush()
   assert(session.controls.Generation()==initial+1 and session.gui.LevelUpNotice.Level.Text=="LEVEL 9")
   assert(session.gui.LevelPanel.NextLevel.Text=="NEXT: LEVEL 10")
  end)
  check("New level supersedes pending notice and stale fade cannot hide it",function()
   local session=makeSession({PCDataReady=true,PCLevel=1})
   session.player:SetAttribute("PCLevel",2) session.clock.flush()
   local oldCallbacks=session.clock.delayed session.clock.delayed={}
   session.player:SetAttribute("PCLevel",5) session.clock.flush()
   local generation=session.controls.Generation()
   for _,entry in ipairs(oldCallbacks) do entry.callback() end
   assert(session.gui.LevelUpNotice.Visible and session.controls.Generation()==generation and session.gui.LevelUpNotice.Level.Text=="LEVEL 5")
   session.clock.finish()
   assert(not session.gui.LevelUpNotice.Visible and session.gui.LevelUpNotice.GroupTransparency==1)
  end)
  check("Loading reset hides old notice and establishes a fresh silent baseline",function()
   local session=makeSession({PCDataReady=true,PCLevel=1})
   session.player:SetAttribute("PCLevel",2) session.clock.flush()
   assert(session.gui.LevelUpNotice.Visible)
   session.player:SetAttribute("PCDataReady",false)
   assert(not session.gui.LevelUpNotice.Visible and session.controls.Baseline()==nil)
   session.player:SetAttribute("PCLevel",25)
   session.player:SetAttribute("PCDataReady",true)
   session.clock.flush()
   assert(not session.gui.LevelUpNotice.Visible and session.controls.Baseline()==25)
   session.clock.finish()
   assert(not session.gui.LevelUpNotice.Visible)
  end)
  check("Lower or repeated level values never replay an old announcement",function()
   local session=makeSession({PCDataReady=true,PCLevel=10})
   session.player:SetAttribute("PCLevel",11) session.clock.flush()
   local generation=session.controls.Generation()
   session.player:SetAttribute("PCLevel",10) session.clock.flush()
   session.player:SetAttribute("PCLevel",11) session.clock.flush()
   assert(session.controls.Generation()==generation)
   session.player:SetAttribute("PCLevel",12) session.clock.flush()
   assert(session.controls.Generation()==generation+1 and session.gui.LevelUpNotice.Level.Text=="LEVEL 12")
  end)
  check("XP clamps safely and the visible reusable fill matches its progress gradient",function()
   local session=makeSession({PCDataReady=true,PCLevel=8,PCLevelXP=9000,PCLevelXPRequired=550})
   assert(session.gui.LevelPanel.XP.Text=="550 / 550 XP")
   for _,panel in ipairs({session.gui.LevelPanel,session.gui.CompactLevelPanel}) do
    local a=panel.XPTrack.Fill.Progress.Transparency
    local b=panel.XPTrack.Fill.ReusableSkin.Progress.Transparency
    assert(a==b and a.Keypoints[1].Value==0)
   end
   session.player:SetAttribute("PCLevelXP",88) session.clock.flush()
   for _,panel in ipairs({session.gui.LevelPanel,session.gui.CompactLevelPanel}) do
    local source=panel.XPTrack.Fill.Progress.Transparency
    local image=panel.XPTrack.Fill.ReusableSkin.Progress.Transparency
    assert(source==image and #image.Keypoints==4)
    assert(math.abs(image.Keypoints[2].Time-0.1599)<0.00001 and math.abs(image.Keypoints[3].Time-0.1601)<0.00001)
    assert(image.Keypoints[2].Value==0 and image.Keypoints[3].Value==1)
   end
   session.player:SetAttribute("PCLevelXP",-4) session.clock.flush()
   assert(session.gui.LevelPanel.XP.Text=="0 / 550 XP")
   assert(session.gui.LevelPanel.XPTrack.Fill.Progress.Transparency.Keypoints[1].Value==1)
   assertLayout(session)
  end)
  check("Cleanup stops connections, tweens and delayed notice callbacks",function()
   local session=makeSession({PCDataReady=true,PCLevel=1})
   session.player:SetAttribute("PCLevel",2) session.clock.flush()
   session.controls.Cleanup()
   local generation=session.controls.Generation()
   session.player:SetAttribute("PCLevel",8) session.clock.flush() session.clock.finish()
   assert(not session.controls.Alive() and #session.controls.Connections==0 and not session.gui.LevelUpNotice.Visible)
   assert(session.controls.Generation()==generation)
   session.controls.Cleanup()
   assertLayout(session)
  end)
  check("Editable notification uses the existing skin and outside contextual text outlines",function()
   local notice=game.StarterGui.PlaygroundShell.LevelUpNotice
   assert(notice:IsA("CanvasGroup") and not notice.Visible)
   assert(notice.ReusableSkin.Image=="rbxassetid://84589903135132")
   for _,label in ipairs({notice.Title,notice.Level}) do
    assert(label.TextXAlignment==Enum.TextXAlignment.Center and label.TextYAlignment==Enum.TextYAlignment.Center)
    assert(label.TextOutline.ApplyStrokeMode==Enum.ApplyStrokeMode.Contextual)
    assert(label.TextOutline.BorderStrokePosition==Enum.BorderStrokePosition.Outer)
   end
  end)
  check("Exact live capability set used and Play remains stopped",function()
   assert(module.Capabilities==original.Capabilities and module.Sandboxed==original.Sandboxed)
   assert(not game:GetService("RunService"):IsRunning())
   report.capabilities=tostring(module.Capabilities)
   report.sandboxed=module.Sandboxed
  end)
 end,debug.traceback)
 for _,session in ipairs(sessions) do session.controls.Cleanup() end
 fixture:Destroy()
 report.fixtureDestroyed=fixture.Parent==nil
 report.passed=ok
 if not ok then report.error=failure else report.currentCheck=nil end
 return report
end

