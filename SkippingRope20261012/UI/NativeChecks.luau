assert(not game:GetService("RunService"):IsRunning(), "Edit only")
local fixture = Instance.new("Folder") fixture.Name, fixture.Parent = "_SkippingHudFixture", game.ServerStorage
local results = {}
local function check(name, callback)
	local ok, failure = xpcall(callback, debug.traceback)
	table.insert(results, {name=name,passed=ok,error=not ok and tostring(failure) or nil})
end
local function signal()
	local callbacks={}
	return {Connect=function(_,fn) callbacks[fn]=true return {Disconnect=function() callbacks[fn]=nil end} end,
		Fire=function(_,...) for fn in pairs(callbacks) do fn(...) end end, Count=function() local n=0 for _ in pairs(callbacks) do n+=1 end return n end}
end
local outcome
local ok, failure = xpcall(function()
	local gui=game.StarterGui.SkippingRopeHUD:Clone() gui.Parent=fixture
	local session=Instance.new("ScreenGui") session.Name,session.Parent="PlaygroundSessionControls",fixture
	local player=Instance.new("Folder") player.Parent=fixture
	local state=Instance.new("Folder") state.Parent=fixture
	local round=Instance.new("Folder") round.Parent=fixture round:SetAttribute("ActiveGame","SkippingRope")
	local heart=signal()
	local env={now=0,viewport=Vector2.new(844,390)}
	env.workspace={GetServerTimeNow=function() return env.now end,CurrentCamera={ViewportSize=env.viewport}}
	local services={Players={LocalPlayer=player},RunService={Heartbeat=heart},UserInputService={TouchEnabled=true},
		ReplicatedStorage={WaitForChild=function(_,name) assert(name=="SkippingRopeState") return state end,
		FindFirstChild=function(_,name) return name=="PlaygroundState" and round or nil end}}
	env.game={GetService=function(_,name) return assert(services[name],name) end}
	env.script=gui.Controller
	local candidate=Instance.new("ModuleScript") candidate.Name="ControllerCandidate"
	candidate.Source="return function(env)\nlocal game,workspace,script=env.game,env.workspace,env.script\n"..gui.Controller.Source.."\nend"
	candidate.Parent=fixture
	local authored={}
	for _,item in ipairs(gui:GetDescendants()) do if item:IsA("GuiObject") then authored[item]={item.Position,item.Size} end end
	state:SetAttribute("Phase","Waiting")
	require(candidate)(env)
	check("Hidden outside the round",function() assert(not gui.CompactHeader.Visible and not gui.RulesButton.Visible) end)
	local function tick() heart:Fire(0.2) end
	player:SetAttribute("SKParticipating",true) player:SetAttribute("SKLane",2) player:SetAttribute("SKHits",0)
	state:SetAttribute("Phase","Countdown") state:SetAttribute("EndsAt",8) state:SetAttribute("CountdownValue",8) state:SetAttribute("AliveCount",24)
	tick()
	check("Phone countdown shows rules and correct lane",function() assert(gui.CompactHeader.Visible and gui.CompactRules.Visible and gui.CompactHeader.Role.Text=="ROPE 2") end)
	state:SetAttribute("Phase","Playing") state:SetAttribute("StartedAt",8) state:SetAttribute("EndsAt",128) env.now=8 tick()
	check("Playing hides briefing and starts two-minute timer",function() assert(not gui.CompactRules.Visible and gui.CompactHeader.Timer.Text=="2:00") end)
	check("Initial health message and speed",function() assert(gui.CompactHeader.Counts.Text:find("2 hits left",1,true) and gui.CompactHeader.Speed.Text=="SPEED 1.00x") end)
	env.now=18 tick()
	check("Five percent speed increase after ten seconds",function() assert(gui.CompactHeader.Speed.Text=="SPEED 1.05x") end)
	player:SetAttribute("SKHits",1) tick()
	check("First hit shows one life and warning",function() assert(gui.CompactHeader.Counts.Text:find("1 hit left",1,true) and gui.CompactHitNotice.Visible and gui.CompactHeader.Hint.Text:find("One hit left",1,true)) end)
	player:SetAttribute("SKHits",2) player:SetAttribute("SKParticipating",false) player:SetAttribute("SKEliminated",true) tick()
	check("Eliminated stays visible with OUT",function() assert(gui.CompactHeader.Visible and gui.CompactHeader.Role.Text=="OUT" and gui.CompactHitNotice.Caption.Text:find("OUT!",1,true)) end)
	env.now=23 tick()
	check("Temporary hit notice disappears",function() assert(not gui.CompactHitNotice.Visible and gui.CompactHeader.Role.Text=="OUT") end)
	session:SetAttribute("UIHidden",true) tick()
	check("Hide UI preference hides all skipping HUD",function() assert(not gui.CompactHeader.Visible and not gui.RulesButton.Visible and not gui.CompactHitNotice.Visible) end)
	session:SetAttribute("UIHidden",false) player:SetAttribute("SKEliminated",false) session:SetAttribute("Spectating",true) tick()
	check("Spectators get matching game view",function() assert(gui.CompactHeader.Visible and gui.CompactHeader.Role.Text=="WATCHING") end)
	round:SetAttribute("ActiveGame","Tag") tick()
	check("Other game spectators do not see skipping HUD",function() assert(not gui.CompactHeader.Visible) end)
	round:SetAttribute("ActiveGame","SkippingRope") session:SetAttribute("Spectating",false) player:SetAttribute("SKParticipating",true)
	state:SetAttribute("Phase","Results") player:SetAttribute("SKResult","Won") tick()
	check("Survivor sees win and no countdown",function() assert(gui.CompactHeader.Role.Text=="SURVIVED!" and gui.CompactHeader.Timer.Text=="") end)
	player:SetAttribute("SKResult","Cancelled") tick()
	check("Cancelled round has no false win",function() assert(gui.CompactHeader.Role.Text=="CANCELLED") end)
	state:SetAttribute("Phase","Countdown") state:SetAttribute("CountdownValue",8)
	for _,size in ipairs({Vector2.new(568,320),Vector2.new(667,375),Vector2.new(844,390),Vector2.new(320,568),Vector2.new(390,844),Vector2.new(768,1024),Vector2.new(1024,768),Vector2.new(1366,1024),Vector2.new(1920,1080)}) do
		env.workspace.CurrentCamera.ViewportSize=size tick()
		check("Responsive layout inside "..tostring(size),function()
			local count=0
			for _,prefix in ipairs({"Desktop","Compact","Portrait"}) do
				local h,c=gui[prefix.."Header"],gui[prefix.."Rules"]
				if h.Visible then count+=1 assert(h.Size.X.Offset<=size.X-16 and c.Size.X.Offset<=size.X-16 and c.Size.Y.Offset<=size.Y-40) end
			end
			assert(count==1)
		end)
	end
	local textService=game:GetService("TextService")
	check("Rules text fits authored phone and tablet boxes",function()
		for _,prefix in ipairs({"Desktop","Compact","Portrait"}) do
			local card=gui[prefix.."Rules"]
			for i=1,4 do
				local row=card["Rule"..i]
				local width=card.Size.X.Offset*row.Size.X.Scale+row.Size.X.Offset
				local height=card.Size.Y.Offset*row.Size.Y.Scale+row.Size.Y.Offset
				local bounds=textService:GetTextSize(row.Text,row.UITextSizeConstraint.MinTextSize,row.Font,Vector2.new(width,1000))
				assert(bounds.Y<=height+1,prefix.." rule"..i)
			end
		end
	end)
	check("Runtime preserves editable positions and sizes",function() for item,pair in pairs(authored) do assert(item.Position==pair[1] and item.Size==pair[2],item:GetFullName()) end end)
	gui.Controller:Destroy()
	task.wait(0.01)
	check("Destroy disconnects heartbeat",function() assert(heart:Count()==0) end)
	local passed=true for _,r in ipairs(results) do if not r.passed then passed=false end end
	outcome={passed=passed,checkCount=#results,checks=results}
end,debug.traceback)
fixture:Destroy()
assert(ok,failure)
return outcome
