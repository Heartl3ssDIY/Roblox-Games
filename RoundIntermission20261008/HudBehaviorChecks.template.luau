return function(gui, toast, folder)
local passed = 0
local function check(condition, label)
    assert(condition, label)
    passed += 1
end
local signals = {}
local function signal()
    local value = { callbacks = {} }
    function value:Connect(callback)
        local connection = { Connected = true }
        function connection:Disconnect() self.Connected = false end
        table.insert(self.callbacks, { callback = callback, connection = connection })
        return connection
    end
    function value:Fire(...)
        for _, entry in self.callbacks do
            if entry.connection.Connected then entry.callback(...) end
        end
    end
    table.insert(signals, value)
    return value
end
local function attributes()
    local value = { values = {}, AttributeChanged = signal() }
    function value:GetAttribute(name) return self.values[name] end
    function value:SetAttribute(name, data)
        self.values[name] = data
        self.AttributeChanged:Fire(name)
    end
    return value
end
local authored = {}
for _, object in gui:GetDescendants() do
    if object:IsA("GuiObject") then authored[object] = {position=object.Position,size=object.Size,anchor=object.AnchorPoint} end
end
local state, player = attributes(), attributes()
local heartbeat, destroying = signal(), signal()
local camera = { ViewportSize = Vector2.new(1280,720) }
local now = 100
local workspaceMock = { CurrentCamera = camera, GetServerTimeNow = function() return now end }
local gameMock = {}
function gameMock:GetService(name)
    if name == "Players" then return { LocalPlayer = player } end
    if name == "ReplicatedStorage" then return { WaitForChild = function(_, child) assert(child=="PlaygroundState");return state end } end
    if name == "RunService" then return { Heartbeat = heartbeat } end
    error("Unexpected service: "..name)
end
local scriptMock = { Parent = gui, Destroying = destroying }
local function runController()
    local game, workspace, script = gameMock, workspaceMock, scriptMock
    -- CONTROLLER_SOURCE
end
local ok, result = xpcall(function()
    runController()
    local desktop, compact = gui.Desktop, gui.Compact
    check(desktop.Visible and not compact.Visible, "Default desktop selected")
    check(desktop.Detail.Text == "Preparing the lobby...", "Startup label")
    state:SetAttribute("Phase","Voting")
    state:SetAttribute("IntermissionStatus","Next round starts in")
    state:SetAttribute("VotingEndsAt",135)
    check(desktop.Timer.Text=="0:35", "35-second countdown")
    check(desktop.Title.Text=="INTERMISSION" and desktop.Detail.Text=="Vote for the next game!", "Voting labels")
    now = 100.1
    heartbeat:Fire(0.1)
    check(desktop.Timer.Text=="0:35", "Countdown rounds remaining seconds upward")
    now = 134.1
    heartbeat:Fire(0.1)
    check(desktop.Timer.Text=="0:01", "Last second displayed")
    now = 135
    heartbeat:Fire(0.1)
    check(desktop.Timer.Text=="0:00", "Countdown reaches zero")
    now = 140
    heartbeat:Fire(0.1)
    check(desktop.Timer.Text=="0:00", "Countdown cannot become negative")
    state:SetAttribute("IntermissionStatus","Preparing the next round - retrying")
    check(desktop.Detail.Text=="Preparing the next round - retrying", "Retry reason visible")
    state:SetAttribute("Phase","Waiting")
    state:SetAttribute("ReadyPlayerCount",1)
    state:SetAttribute("MinimumReadyPlayers",2)
    state:SetAttribute("IntermissionStatus","Waiting for ready players (1/2)")
    check(desktop.Timer.Text=="" and desktop.Title.Text=="WAITING FOR PLAYERS", "Waiting clears countdown")
    check(desktop.Detail.Text=="Waiting for ready players (1/2)", "Server wait reason")
    state:SetAttribute("IntermissionStatus","")
    check(desktop.Detail.Text=="1 / 2 players ready", "Fallback ready count")
    state:SetAttribute("Phase","Paused")
    check(desktop.Title.Text=="ROUNDS PAUSED" and desktop.Timer.Text=="", "Pause label")
    check(desktop.Detail.Text=="Automatic rounds paused by an admin", "Pause explanation")
    state:SetAttribute("Phase","Playing")
    check(not desktop.Visible and not compact.Visible, "HUD hidden while round is playing")
    state:SetAttribute("Phase","Voting")
    for _,name in {"BBParticipating","TGParticipating","MDParticipating"} do
        player:SetAttribute(name,true)
        check(not desktop.Visible and not compact.Visible, name.." hides lobby HUD")
        player:SetAttribute(name,false)
        check(desktop.Visible and not compact.Visible, name.." restores lobby HUD")
    end
    camera.ViewportSize=Vector2.new(390,844)
    heartbeat:Fire(0.1)
    check(compact.Visible and not desktop.Visible, "Portrait phone uses compact layout")
    camera.ViewportSize=Vector2.new(844,390)
    heartbeat:Fire(0.1)
    check(compact.Visible and not desktop.Visible, "Landscape phone uses compact layout")
    camera.ViewportSize=Vector2.new(899,900)
    heartbeat:Fire(0.1)
    check(compact.Visible, "Narrow tablet uses compact layout")
    camera.ViewportSize=Vector2.new(900,599)
    heartbeat:Fire(0.1)
    check(compact.Visible, "Short viewport uses compact layout")
    camera.ViewportSize=Vector2.new(900,600)
    heartbeat:Fire(0.1)
    check(desktop.Visible and not compact.Visible, "Desktop boundary selected")
    camera.ViewportSize=Vector2.new(390,844)
    state:SetAttribute("Phase","Waiting")
    check(compact.Title.Text=="WAITING", "Compact waiting heading")
    toast.Visible=true
    heartbeat:Fire(0.1)
    check(not compact.Visible and not desktop.Visible, "Compact toast suppresses overlapping HUD")
    toast.Visible=false
    heartbeat:Fire(0.1)
    check(compact.Visible, "Compact HUD returns after toast")
    camera.ViewportSize=Vector2.new(1280,720)
    toast.Visible=true
    heartbeat:Fire(0.1)
    check(desktop.Visible, "Desktop HUD remains during toast")
    local backdrop=toast.Parent.Backdrop
    local session=folder.PlaygroundSessionControls
    for _,size in {Vector2.new(1280,720),Vector2.new(390,844)} do
        camera.ViewportSize=size
        toast.Visible=false
        backdrop.Visible=true
        heartbeat:Fire(0.1)
        check(not desktop.Visible and not compact.Visible, "Shop backdrop hides HUD")
        backdrop.Visible=false
        heartbeat:Fire(0.1)
        check(desktop.Visible or compact.Visible, "Closing shop restores HUD")
        for _,attribute in {"UIHidden","SessionMenuOpen"} do
            session:SetAttribute(attribute,true)
            heartbeat:Fire(0.1)
            check(not desktop.Visible and not compact.Visible, attribute.." hides HUD")
            session:SetAttribute(attribute,false)
            heartbeat:Fire(0.1)
            check(desktop.Visible or compact.Visible, attribute.." restores HUD")
        end
    end
    check(desktop.Fallback.Visible==not desktop.ReusableSkin.IsLoaded, "Desktop fallback follows image loading")
    check(compact.Fallback.Visible==not compact.ReusableSkin.IsLoaded, "Compact fallback follows image loading")
    workspaceMock.CurrentCamera=nil
    heartbeat:Fire(0.1)
    check(desktop.Visible and not compact.Visible, "Missing camera uses stable desktop fallback")
    for object, geometry in authored do
        check(object.Position==geometry.position and object.Size==geometry.size and object.AnchorPoint==geometry.anchor, "Authored layout unchanged: "..object.Name)
    end
    local connected=0
    for _,event in signals do for _,entry in event.callbacks do if entry.connection.Connected then connected+=1 end end end
    check(connected==4, "Exactly four connections bound")
    local title=desktop.Title.Text
    destroying:Fire()
    connected=0
    for _,event in signals do for _,entry in event.callbacks do if entry.connection.Connected then connected+=1 end end end
    check(connected==0, "Destroy cleans every connection")
    state:SetAttribute("Phase","Voting")
    heartbeat:Fire(0.1)
    check(desktop.Title.Text==title, "Destroyed controller no longer renders")
    return {passed=passed,scope="Native authored GUI clone and exact installed controller with mocked state, local player, clock and heartbeat",productionChanged=false}
end,debug.traceback)
folder:Destroy()
if not ok then error(result) end
return result
end

