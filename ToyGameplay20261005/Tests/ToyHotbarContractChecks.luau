local report={checks={},playStarted=false}
local function check(name,value) assert(value,name) table.insert(report.checks,name) end
local attributes={PCDataReady=true,PCToyEmberUntil=110,PCToyEmberShotUntil=0,PCToyCooldown_M07=115.8}
local now=100
local workspace={GetServerTimeNow=function()return now end}
local humanoid={Health=100}
local player={Character={FindFirstChildOfClass=function()return humanoid end}}
function player:GetAttribute(key)return attributes[key] end
local alive,pending,requestToken=true,false,0
local notice,noticeUntil="",0
local activeIndex,activeId=1,"M07"
local bar={Visible=true}
local gui={Enabled=true}
local modal=false
local function modalOpen()return modal end
local function inRound()return attributes.BBParticipating or attributes.TGParticipating or attributes.MDParticipating end
local refreshCount=0
local function refresh()refreshCount+=1 end
local backpackSuppressed,savedBackpackState=false,nil
local nativeBackpack=true
local StarterGui={}
function StarterGui:GetCoreGuiEnabled()return nativeBackpack end
function StarterGui:SetCoreGuiEnabled(_,value)nativeBackpack=value end
local delayed,spawned={},{}
local task={}
function task.delay(_,fn)table.insert(delayed,fn) end
function task.spawn(fn)table.insert(spawned,fn) end
local calls={}
local remote={}
function remote:IsA(kind)return kind=="RemoteFunction"end
function remote:InvokeServer(action,payload)table.insert(calls,{action=action,payload=payload})return{ok=true,message="Done"}end
local ReplicatedStorage={}
function ReplicatedStorage:FindFirstChild(name) if name=="PlaygroundShopRequest"or name=="PlaygroundToyRequest"then return remote end end
local function aimAt(position)return position or Vector3.new(0,0,-100)end
local catalog={ById={M01={name="Barrel"},M02={name="Speed Potion"},M07={name="Fire Potion"},M10={name="Launcher"}}}
local slots={}
for i=1,4 do slots[i]={id="",button={ItemName={Text=""}}}end
local function preview(record,id)record.id=id end
local data={equipped={Toys={"M01","M07","M10"},Gear="M07",Bat="B01"}}

local function showNativeBackpack(show)
	if not show and not backpackSuppressed then
		local ok, previous = pcall(function() return StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack) end)
		if not ok then return end
		local applied = pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end)
		if applied then savedBackpackState = previous backpackSuppressed = true end
	elseif show and backpackSuppressed then
		local applied = pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, savedBackpackState) end)
		if applied then backpackSuppressed = false savedBackpackState = nil end
	end
end

local function usable()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return player:GetAttribute("PCDataReady") == true and not inRound() and humanoid and humanoid.Health > 0
end

local function tell(message, seconds)
	notice = tostring(message or "")
	noticeUntil = workspace:GetServerTimeNow() + (seconds or 3)
end

local function cooldownEndsAt(id)
	local now = workspace:GetServerTimeNow()
	local ember = tonumber(player:GetAttribute("PCToyEmberUntil")) or 0
	local attribute = id == "M07" and ember > now and "PCToyEmberShotUntil" or "PCToyCooldown_" .. id
	return tonumber(player:GetAttribute(attribute)) or 0
end

local function syncLoadout()
	if not alive then return end
	for index, record in ipairs(slots) do
		local id = player:GetAttribute("PCToySlot" .. tostring(index))
		if typeof(id) ~= "string" or not catalog.ById[id] then id = "" end
		preview(record, id)
		record.button.ItemName.Text = id ~= "" and catalog.ById[id].name or "EMPTY"
	end
	activeIndex = math.clamp(math.floor(tonumber(player:GetAttribute("PCToyIndex")) or 0), 0, 4)
	activeId = slots[activeIndex] and slots[activeIndex].id or ""
	refresh()
end

local function invoke(remoteName, action, payload, itemId)
	if pending or not alive then return end
	local remote = ReplicatedStorage:FindFirstChild(remoteName)
	if not remote or not remote:IsA("RemoteFunction") then tell("Toys are getting ready.") refresh() return end
	pending = true
	requestToken += 1
	local token = requestToken
	refresh()
	task.delay(8, function()
		if not alive or requestToken ~= token or not pending then return end
		requestToken += 1
		pending = false
		tell("That took too long. Try again.")
		refresh()
	end)
	task.spawn(function()
		local ok, reply = pcall(function() return remote:InvokeServer(action, payload) end)
		if not alive or requestToken ~= token then return end
		pending = false
		if ok and typeof(reply) == "table" then
			if reply.message then tell(reply.message) elseif not reply.ok then tell("That did not go through.") end
		else
			tell("That did not go through. Try again.")
		end
		refresh()
	end)
end

local function useToy(position)
	if not gui.Enabled or not bar.Visible or not usable() or modalOpen() or activeId == "" or pending then return end
	local item = catalog.ById[activeId]
	if item and item.toyActionPending then tell("This toy's action is coming soon.") refresh() return end
	if cooldownEndsAt(activeId) > workspace:GetServerTimeNow() then return end
	invoke("PlaygroundToyRequest", "Use", aimAt(position), activeId)
end

local function selectToy(index)
	local record = slots[index]
	if not record or record.id == "" or not bar.Visible or not usable() or modalOpen() or pending then return end
	invoke("PlaygroundShopRequest", "SelectToy", index)
end
local function isEquipped(item)
	if item.slot == "Gear" and typeof(data.equipped.Toys) == "table" then
		return table.find(data.equipped.Toys, item.id) ~= nil
	end
	return data.equipped[item.slot] == item.id
end


check("Toy membership includes inactive loaded toys",isEquipped({id="M01",slot="Gear"}))
check("Toy membership includes active loaded toy",isEquipped({id="M07",slot="Gear"}))
check("Owned but unloaded toy is not equipped",not isEquipped({id="M02",slot="Gear"}))
check("Bat equipment remains singular",isEquipped({id="B01",slot="Bat"}))
data.equipped.Toys={}
check("Empty new loadout does not use stale Gear alias",not isEquipped({id="M07",slot="Gear"}))
data.equipped.Toys=nil
check("Legacy Gear status remains readable",isEquipped({id="M07",slot="Gear"}))
check("Active fire potion ignores drink cooldown",cooldownEndsAt("M07")==0)
attributes.PCToyEmberShotUntil=100.8
check("Fire potion uses authoritative shot cooldown",cooldownEndsAt("M07")==100.8)
now=111
check("Expired Ember returns to drink cooldown",cooldownEndsAt("M07")==115.8)
attributes.PCToyEmberUntil=0 attributes.PCToyEmberShotUntil=0 attributes.PCToyCooldown_M07=0
check("Death/round cooldown reset is immediately respected",cooldownEndsAt("M07")==0)
attributes.PCToyCooldown_M10=117
check("Other toys use their authoritative cooldown",cooldownEndsAt("M10")==117)
check("Healthy ready lobby player may use toys",usable())
for _,key in ipairs({"BBParticipating","TGParticipating","MDParticipating"})do
 attributes[key]=true check(key.." blocks toy use",not usable()) attributes[key]=false
end
humanoid.Health=0 check("Dead character cannot use toys",not usable()) humanoid.Health=100
attributes.PCDataReady=false check("Unready data cannot use toys",not usable()) attributes.PCDataReady=true
attributes.PCToySlot1="M01" attributes.PCToySlot2="M07" attributes.PCToySlot3="M10" attributes.PCToySlot4="BAD" attributes.PCToyIndex=2
syncLoadout()
check("Atomic loadout reads four slots and filters invalid IDs",slots[1].id=="M01"and slots[2].id=="M07"and slots[3].id=="M10"and slots[4].id=="")
check("Atomic loadout reads active selection",activeIndex==2 and activeId=="M07")
check("Slot captions use catalog names",slots[1].button.ItemName.Text=="Barrel"and slots[4].button.ItemName.Text=="EMPTY")
selectToy(3)
check("Slot selection waits for one request",pending and#spawned==1)
selectToy(1)
check("Overlapping requests are rejected",#spawned==1)
table.remove(spawned,1)()
check("Slot selection sends SelectToy with slot index",calls[1].action=="SelectToy"and calls[1].payload==3 and not pending)
local total=#calls
selectToy(4)
check("Empty slot never sends a request",#spawned==0 and#calls==total)
modal=true selectToy(1)
check("Modal blocks selection",#spawned==0)
modal=false
useToy(Vector3.new(1,2,3))
table.remove(spawned,1)()
check("Use sends one authoritative action and target",calls[#calls].action=="Use"and calls[#calls].payload==Vector3.new(1,2,3))
attributes.PCToyCooldown_M07=999
useToy()
check("Cooldown blocks use before remote",#spawned==0)
attributes.PCToyCooldown_M07=0
gui.Enabled=false useToy()
check("Disabled GUI cannot send world-click use",#spawned==0)
gui.Enabled=true
selectToy(1)
local abandoned=table.remove(spawned,1)
local timeout=delayed[#delayed]
timeout()
check("Eight-second request timeout releases pending state",not pending and notice=="That took too long. Try again.")
local noticeBefore=notice
abandoned()
check("Late RPC reply cannot replace timeout feedback",notice==noticeBefore and not pending)
showNativeBackpack(false)
check("Custom bar suppresses native Backpack",not nativeBackpack and backpackSuppressed)
showNativeBackpack(true)
check("Leaving bar restores previously enabled Backpack",nativeBackpack and not backpackSuppressed)
nativeBackpack=false showNativeBackpack(false) showNativeBackpack(true)
check("Previously disabled Backpack remains disabled",not nativeBackpack)
activeId="M09" catalog.ById.M09={name="Mystery Toy",toyActionPending=true}
useToy()
check("Pending toy action does not send Use or block ownership",#spawned==0 and notice=="This toy's action is coming soon.")
report.passed=true
return report

