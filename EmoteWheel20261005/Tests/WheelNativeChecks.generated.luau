assert(not game:GetService("RunService"):IsRunning(),"Edit only")
local fixture=Instance.new("ModuleScript") fixture.Name="EmoteWheelNativeChecks20261005"
fixture.Capabilities=game.StarterGui.PlaygroundShell.Controller.Capabilities
fixture.Sandboxed=game.StarterGui.PlaygroundShell.Controller.Sandboxed
fixture.Source=[====[local ok,result=xpcall(function()
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

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer
local gui = script.Parent
local panel = gui:WaitForChild("Panel")
local backdrop = gui:WaitForChild("Backdrop")
local toggle = gui:WaitForChild("Toggle")
local catalogObject = ReplicatedStorage:WaitForChild("PlaygroundCatalog", 10)
if not catalogObject then toggle.Visible = false return end
local catalog = require(catalogObject)
local alive = true
local connections = {}
local slots = {}
local owned = {}
local equipped = {}
local ready = false
local page = 1
local pageCount = 1
local dances = {}
local busy = false
local requestSerial = 0
local requestWorker
local refreshQueued = false
local lastFetch = -math.huge
local notice = ""
local noticeUntil = 0
local previousSelection
local nativeSuppressed = false
local savedNativeState
local render
local request
local setOpen
local actionName = "PlaygroundEmoteWheelControls"
local numberKeys = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight }

local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end

local function inRound()
	return player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true or player:GetAttribute("MDParticipating") == true
end

local function otherModalOpen()
	if GuiService.MenuIsOpen then return true end
	local shell = player.PlayerGui:FindFirstChild("PlaygroundShell")
	if shell then
		for _, name in ipairs({ "ShopPanel", "VotePanel", "CompactVotePanel" }) do
			local object = shell:FindFirstChild(name)
			if object and object.Visible then return true end
		end
	end
	local admin = player.PlayerGui:FindFirstChild("PlaygroundAdminPanel")
	local hub = admin and admin:FindFirstChild("AdminHub")
	return admin and admin.Enabled and hub and hub.Visible or false
end

local function isPlaying()
	local status = player:GetAttribute("PCEmotePlaybackStatus")
	return (status == "playing" or status == "loading") and (player:GetAttribute("PCEmoteUntil") or 0) > workspace:GetServerTimeNow()
end

local function tell(message, seconds)
	notice = tostring(message or "")
	noticeUntil = os.clock() + (seconds or 4)
end

local function gamepadActive()
	return string.find(UserInputService:GetLastInputType().Name, "Gamepad", 1, true) ~= nil
end

local function buttonState(button, enabled, selected)
	button.Active = enabled
	button.Selectable = enabled
	local skin = button:FindFirstChild("ReusableSkin")
	local attribute = not enabled and "DisabledImage" or selected and "SelectedImage" or "NormalImage"
	local image = button:GetAttribute(attribute)
	if skin and typeof(image) == "string" then skin.Image = image end
end

local function restoreSelection()
	local selected = GuiService.SelectedObject
	if selected and selected:IsDescendantOf(gui) then
		GuiService.SelectedObject = previousSelection and previousSelection.Parent and previousSelection or nil
	end
	previousSelection = nil
end

local function selectFirst()
	if not gamepadActive() then return end
	for _, record in ipairs(slots) do
		if record.button.Visible and record.button.Selectable then GuiService.SelectedObject = record.button return end
	end
	GuiService.SelectedObject = panel.ShopButton
end

local function imageState(record)
	if not record.item then return end
	if record.button.Thumbnail.IsLoaded then
		record.imageStatus = ""
	else
		if panel.Visible and not record.imageStartedAt then record.imageStartedAt = os.clock() end
		record.imageStatus = record.imageStartedAt and os.clock() - record.imageStartedAt >= 8 and "IMAGE UNAVAILABLE" or "LOADING IMAGE"
	end
end

local function setImage(record, item)
	if record.item == item then imageState(record) return end
	record.item = item
	record.imageStartedAt = nil
	record.imageStatus = ""
	local thumbnail = record.button.Thumbnail
	thumbnail.Image = item and item.thumbnail or ""
	thumbnail.Visible = item ~= nil
	if not item then return end
	imageState(record)
end

render = function()
	if not alive then return end
	dances = {}
	for _, item in ipairs(catalog.Items) do
		if item.slot == "Emote" and item.playable == true and item.available ~= false and owned[item.id] == true then
			table.insert(dances, item)
		end
	end
	pageCount = math.max(1, math.ceil(#dances / 8))
	page = math.clamp(page, 1, pageCount)
	local active = isPlaying() and player:GetAttribute("PCEmoteAction") or ""
	for index, record in ipairs(slots) do
		local item = dances[(page - 1) * 8 + index]
		setImage(record, item)
		local button = record.button
		button.Visible = item ~= nil
		buttonState(button, item ~= nil and ready and not busy, item ~= nil and (active == item.id or record.hovered == true))
		button.ItemName.Text = item and item.name or ""
		record.selected.Visible = item ~= nil and (active == item.id or record.hovered == true)
		button.State.Text = item and (active == item.id and "PLAYING" or record.imageStatus ~= "" and record.imageStatus or equipped.Emote == item.id and "PODIUM EMOTE" or "") or ""
	end
	panel.PageLabel.Text = tostring(page) .. " / " .. tostring(pageCount)
	buttonState(panel.Previous, not busy and page > 1)
	buttonState(panel.Next, not busy and page < pageCount)
	buttonState(panel.StopButton, not busy and isPlaying())
	panel.StopButton.Visible = isPlaying()
	if notice ~= "" and os.clock() < noticeUntil then panel.Status.Text = notice
	elseif busy then panel.Status.Text = "Loading..."
	elseif not ready then panel.Status.Text = "Your emotes are getting ready."
	elseif #dances == 0 then panel.Status.Text = "No emotes yet. Unlock dances in the shop."
	else panel.Status.Text = tostring(#dances) .. " owned • Move or jump to stop" end
	panel.Hint.Text = not ready and "LOADING\nEMOTES" or #dances == 0 and "UNLOCK DANCES\nIN THE SHOP" or gamepadActive() and "A TO PLAY\nB TO CLOSE" or UserInputService.TouchEnabled and "TAP A\nDANCE" or "CLICK OR 1–8\nTO DANCE"
	local caption = toggle:FindFirstChild("LiveCaption")
	if caption then caption.Text = gamepadActive() and "EMOTES [D-PAD]" or UserInputService.TouchEnabled and "EMOTES" or "EMOTES [ . ]" end
end

local function acceptStatus(reply)
	if typeof(reply) ~= "table" then return false end
	if typeof(reply.owned) == "table" and typeof(reply.equipped) == "table" and typeof(reply.ready) == "boolean" then
		owned, equipped, ready = reply.owned, reply.equipped, reply.ready
		return true
	end
	return false
end

request = function(action, id)
	if not alive then return end
	if busy then
		if action == "GetStatus" then refreshQueued = true end
		return
	end
	local remote = ReplicatedStorage:FindFirstChild("PlaygroundShopRequest")
	if not remote or not remote:IsA("RemoteFunction") then tell("The emote shop is getting ready.") render() return end
	if action == "GetStatus" and os.clock() - lastFetch < 0.2 then
		refreshQueued = true
		return
	end
	busy = true
	requestSerial += 1
	local serial = requestSerial
	if action == "GetStatus" then lastFetch = os.clock() end
	render()
	task.delay(8, function()
		if not alive or serial ~= requestSerial or not busy then return end
		requestSerial += 1
		busy = false
		if requestWorker then pcall(task.cancel, requestWorker) requestWorker = nil end
		tell("That took too long. Open the wheel to try again.")
		render()
	end)
	requestWorker = task.spawn(function()
		local ok, reply = pcall(function() return remote:InvokeServer(action, id) end)
		if not alive or serial ~= requestSerial then return end
		requestWorker = nil
		busy = false
		local valid = ok and acceptStatus(reply)
		if not valid then
			tell("The emote shop could not respond. Try again.")
		elseif action == "UseEmote" and reply.ok == true then
			notice = ""
			setOpen(false)
		elseif action ~= "GetStatus" then
			tell(reply.message ~= "" and reply.message or (reply.ok and "Done." or "Try again in a moment."))
		end
		render()
		if panel.Visible then selectFirst() end
	end)
end

setOpen = function(show)
	if not alive then return end
	if show and (not gui.Enabled or inRound() or otherModalOpen()) then return end
	if show == panel.Visible then return end
	panel.Visible = show
	backdrop.Visible = show
	if show then
		previousSelection = GuiService.SelectedObject
		notice = ""
		render()
		selectFirst()
		request("GetStatus")
	else
		restoreSelection()
	end
end

local function playSlot(index)
	local record = slots[index]
	if not panel.Visible or busy or not ready or inRound() or otherModalOpen() or not record or not record.item then return end
	request("UseEmote", record.item.id)
end

for index = 1, 8 do
	local button = panel.Wheel:WaitForChild("Slot" .. tostring(index))
	local record = { button = button, selected = button:WaitForChild("Selected"), imageStatus = "", hovered = false }
	table.insert(slots, record)
	connect(button.Activated, function() playSlot(index) end)
	connect(button.MouseEnter, function() record.hovered = true render() end)
	connect(button.MouseLeave, function() record.hovered = false render() end)
	connect(button.SelectionGained, function() record.hovered = true render() end)
	connect(button.SelectionLost, function() record.hovered = false render() end)
	connect(button.Thumbnail:GetPropertyChangedSignal("IsLoaded"), function() imageState(record) render() end)
end

local function movePage(delta)
	if busy then return end
	page = math.clamp(page + delta, 1, pageCount)
	for _, record in ipairs(slots) do record.hovered = false end
	render()
	selectFirst()
end

connect(toggle.Activated, function() setOpen(not panel.Visible) end)
connect(panel.Close.Activated, function() setOpen(false) end)
connect(backdrop.Activated, function() setOpen(false) end)
connect(panel.Previous.Activated, function() movePage(-1) end)
connect(panel.Next.Activated, function() movePage(1) end)
connect(panel.StopButton.Activated, function() if not busy then request("StopEmote") end end)
connect(panel.ShopButton.Activated, function()
	local shell = player.PlayerGui:FindFirstChild("PlaygroundShell")
	if not shell then tell("The shop is getting ready.") render() return end
	setOpen(false)
	shell:SetAttribute("OpenEmoteShopSerial", (tonumber(shell:GetAttribute("OpenEmoteShopSerial")) or 0) + 1)
end)

local function inputAction(_, state, input)
	if not gui.Enabled or UserInputService:GetFocusedTextBox() or GuiService.MenuIsOpen then return Enum.ContextActionResult.Pass end
	local key = input.KeyCode
	if key == Enum.KeyCode.DPadDown and panel.Visible then return Enum.ContextActionResult.Pass end
	if key == Enum.KeyCode.Period or key == Enum.KeyCode.DPadDown then
		if inRound() or otherModalOpen() then return Enum.ContextActionResult.Pass end
		if state == Enum.UserInputState.Begin then setOpen(not panel.Visible) end
		return Enum.ContextActionResult.Sink
	end
	if not panel.Visible then return Enum.ContextActionResult.Pass end
	if state == Enum.UserInputState.Begin then
		if key == Enum.KeyCode.ButtonB then setOpen(false)
		elseif key == Enum.KeyCode.ButtonL1 then movePage(-1)
		elseif key == Enum.KeyCode.ButtonR1 then movePage(1)
		else
			local index = table.find(numberKeys, key)
			if index then playSlot(index) end
		end
	end
	return Enum.ContextActionResult.Sink
end

ContextActionService:BindActionAtPriority(actionName, inputAction, false, Enum.ContextActionPriority.High.Value + 1, Enum.KeyCode.Period, Enum.KeyCode.DPadDown, Enum.KeyCode.ButtonB, Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1, table.unpack(numberKeys))

for _, attribute in ipairs({ "BBParticipating", "TGParticipating", "MDParticipating" }) do
	connect(player:GetAttributeChangedSignal(attribute), function() if inRound() then setOpen(false) end render() end)
end
for _, attribute in ipairs({ "PCInventoryVersion", "PCDataReady" }) do
	connect(player:GetAttributeChangedSignal(attribute), function()
		if player:GetAttribute("PCDataReady") ~= true then ready = false end
		refreshQueued = true
		render()
	end)
end
for _, attribute in ipairs({ "PCEmotePlaybackStatus", "PCEmoteAction", "PCEmoteUntil", "PCEmote" }) do
	connect(player:GetAttributeChangedSignal(attribute), function()
		if attribute == "PCEmotePlaybackStatus" and player:GetAttribute(attribute) == "failed" then
			tell(player:GetAttribute("PCEmotePlaybackMessage") or "This dance could not load.", 5)
		end
		render()
	end)
end
connect(UserInputService.LastInputTypeChanged, function() render() end)
connect(player.CharacterAdded, function() setOpen(false) refreshQueued = true end)
connect(player.CharacterRemoving, function() setOpen(false) end)
connect(gui:GetPropertyChangedSignal("Enabled"), function() if not gui.Enabled then setOpen(false) end end)
connect(ReplicatedStorage.ChildAdded, function(child) if child.Name == "PlaygroundShopRequest" then refreshQueued = true end end)

panel.Visible = false
backdrop.Visible = false
render()
refreshQueued = true

task.spawn(function()
	for _ = 1, 10 do
		if not alive then return end
		local ok, previous = pcall(function() return StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu) end)
		if ok then
			local applied = pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, false) end)
			if applied then savedNativeState = previous nativeSuppressed = true return end
		end
		task.wait(0.5)
	end
	warn("Playground emote wheel could not hide the native emote menu")
end)

task.spawn(function()
	while alive do
		local blocked = inRound() or otherModalOpen() or not gui.Enabled
		toggle.Visible = not blocked and not panel.Visible
		if blocked then setOpen(false) end
		if refreshQueued and not busy and os.clock() - lastFetch >= 0.2 then
			refreshQueued = false
			request("GetStatus")
		end
		if panel.Visible then render() end
		task.wait(0.2)
	end
end)

connect(script.Destroying, function()
	setOpen(false)
	alive = false
	requestSerial += 1
	if requestWorker then pcall(task.cancel, requestWorker) requestWorker = nil end
	ContextActionService:UnbindAction(actionName)
	for _, connection in ipairs(connections) do connection:Disconnect() end
	if nativeSuppressed then pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, savedNativeState) end) end
end)

local checks=0
local function check(value,message)assert(value,message)checks+=1 end
local function input(key,state)return fakeCAS.callback("test",state or Enum.UserInputState.Begin,{KeyCode=key})end
local function status()
 local inventory={}for i=1,20 do inventory["E"..string.format("%02d",i)]=true end
 inventory.E18=nil
 return{ok=true,ready=true,owned=inventory,equipped={Emote="E05"},message=""}
end
check(fakeSG.native==false and nativeSuppressed,"Native emote menu suppressed")
check(#pending==1 and pending[1].action=="GetStatus","Initial status refresh")
complete(pending[1],status())
check(ready and #dances==16 and pageCount==2,"Owned playable available Emotes only, eight per page")
check(slots[7].item.id=="E08" and slots[8].item.id=="E09","Sparse removed E07 omitted without shifting IDs")
check(slots[5].button.State.Text=="PODIUM EMOTE","Equipped podium label preserved")
fakeUIS.focus={}check(input(Enum.KeyCode.Period)==Enum.ContextActionResult.Pass and not panel.Visible,"Typing does not open wheel")fakeUIS.focus=nil
fakeGS.MenuIsOpen=true check(input(Enum.KeyCode.Period)==Enum.ContextActionResult.Pass,"Escape menu has priority")fakeGS.MenuIsOpen=false
shell.ShopPanel.Visible=true check(input(Enum.KeyCode.Period)==Enum.ContextActionResult.Pass and not panel.Visible,"Shop modal blocks opening")shell.ShopPanel.Visible=false
fakePlayer.attrs.BBParticipating=true check(input(Enum.KeyCode.Period)==Enum.ContextActionResult.Pass,"Round blocks input")fakePlayer.attrs.BBParticipating=nil
local external=object("PriorSelection",fakePlayer.PlayerGui)fakeGS.SelectedObject=external
fakeUIS.input=Enum.UserInputType.Gamepad1
check(input(Enum.KeyCode.DPadDown)==Enum.ContextActionResult.Sink and panel.Visible,"DPadDown opens wheel")
check(fakeGS.SelectedObject==slots[1].button,"Gamepad starts on first owned slot")
check(input(Enum.KeyCode.DPadDown)==Enum.ContextActionResult.Pass and panel.Visible,"DPadDown while open navigates rather than closing")
advance(.21)complete(pending[#pending],status())
input(Enum.KeyCode.ButtonR1)
check(page==2 and slots[1].item.id=="E10","Right bumper selects next page")
input(Enum.KeyCode.ButtonL1)check(page==1,"Left bumper selects previous page")
input(Enum.KeyCode.ButtonB)
check(not panel.Visible and fakeGS.SelectedObject==external,"Close restores previous gamepad selection")
fakeUIS.input=Enum.UserInputType.Keyboard
advance(.3)input(Enum.KeyCode.Period)complete(pending[#pending],status())
input(Enum.KeyCode.Three)
local play=pending[#pending]
check(play.action=="UseEmote" and play.id=="E03","Number key invokes UseEmote without Equip")
local reply=status()complete(play,reply)
check(not panel.Visible and equipped.Emote=="E05","Successful dance closes wheel preserving podium choice")
advance(.3)setOpen(true)complete(pending[#pending],status())
fakePlayer:SetAttribute("PCEmotePlaybackStatus","loading")fakePlayer:SetAttribute("PCEmoteUntil",clock+30)fakePlayer:SetAttribute("PCEmoteAction","E03")
check(panel.StopButton.Visible and panel.StopButton.Active,"Stop available while real playback is loading")
panel.StopButton.Activated:Fire()local stopping=pending[#pending]
check(stopping.action=="StopEmote" and stopping.id==nil,"Stop uses dedicated action")complete(stopping,status())
fakePlayer:SetAttribute("TGParticipating",true)
check(not panel.Visible,"Entering a round closes existing wheel")fakePlayer:SetAttribute("TGParticipating",false)
advance(.3)request("GetStatus")local stalled=pending[#pending]local thread=stalled.thread
advance(8.1)
check(not busy and coroutine.status(thread)=="dead","Hung InvokeServer worker cancelled after bounded timeout")
check(not complete(stalled,{ok=true,ready=true,owned={},equipped={}}),"Expired callback cannot overwrite ownership")
advance(.3)request("GetStatus")local retry=pending[#pending]complete(retry,status())
check(ready and #dances==16 and not busy,"Fresh request recovers after timeout")
local accepted=acceptStatus({ok=false,ready=true,owned=status().owned,equipped={Emote="E05"},message="Please wait"})
check(accepted and ready,"Throttled GetStatus still supplies valid ownership state")
setOpen(true)advance(.3)if busy then complete(pending[#pending],status())end
fakeGui.Enabled=false fakeGui:GetPropertyChangedSignal("Enabled"):Fire()
check(not panel.Visible,"Disabling GUI closes panel")
check(input(Enum.KeyCode.Period)==Enum.ContextActionResult.Pass and input(Enum.KeyCode.DPadDown)==Enum.ContextActionResult.Pass,"Disabled wheel relinquishes keyboard and gamepad controls")fakeGui.Enabled=true
local imageRecord=slots[1]imageRecord.button.Thumbnail.IsLoaded=false
imageRecord.imageStartedAt=nil imageState(imageRecord)
advance(9)
check(imageRecord.imageStartedAt==nil,"Hidden wheel does not expire thumbnail grace before display")
setOpen(true)if busy then complete(pending[#pending],status())end
check(imageRecord.imageStatus=="LOADING IMAGE","Visible unloaded thumbnail starts honest loading grace")
advance(8.1)
check(imageRecord.imageStatus=="IMAGE UNAVAILABLE","Visible thumbnail timeout is reported without preload service")
imageRecord.button.Thumbnail.IsLoaded=true imageRecord.button.Thumbnail:GetPropertyChangedSignal("IsLoaded"):Fire()
check(imageRecord.imageStatus=="","Late native ImageLabel success clears timeout status")
advance(.3)request("GetStatus")local destroyThread=pending[#pending].thread
fakeScript.Destroying:Fire()
check(not alive and coroutine.status(destroyThread)=="dead","Destroy cancels outstanding request")
check(fakeSG.native==true and fakeCAS.unbound==actionName,"Destroy restores original native menu and unbinds action")
check(not panel.Visible and not backdrop.Visible,"Destroy clears wheel and backdrop")
check(not complete(pending[#pending],status()),"Destroyed controller rejects later callback")
return {passed=true,checks=checks,nativeContentProviderAvailable=NativeContentProvider~=nil}

end,debug.traceback)
return {passed=ok,result=result}
]====] fixture.Parent=game.ServerStorage
local ok,result=xpcall(function()return require(fixture)end,debug.traceback)
fixture:Destroy()
return {passed=ok,result=result,fixtureCleaned=game.ServerStorage:FindFirstChild("EmoteWheelNativeChecks20261005")==nil}
