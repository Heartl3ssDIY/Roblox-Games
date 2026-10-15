local source=[====[local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Fishing = {}
Fishing.__index = Fishing

local function characterOf(player)
	if player.Parent ~= Players or player:GetAttribute("PCDataReady") ~= true
		or player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true
		or player:GetAttribute("MDParticipating") == true then return nil end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root then return nil end
	return character, root
end

function Fishing.new(scene, economy)
	local self = setmetatable({ scene = scene, economy = economy, stations = {}, runs = {}, requests = {}, connections = {}, running = false }, Fishing)
	for index = 1, 4 do
		local model = assert(scene:FindFirstChild("Rod" .. index), "Fishing rod is missing")
		local interaction = assert(model:FindFirstChild("Interaction"), "Fishing interaction is missing")
		local prompt = assert(interaction:FindFirstChild("Fish"), "Fishing prompt is missing")
		local bobber = assert(model:FindFirstChild("Bobber"), "Fishing bobber is missing")
		table.insert(self.stations, { model = model, interaction = interaction, prompt = prompt, bobber = bobber, rest = bobber.CFrame })
	end
	return self
end

function Fishing:_tell(player, message)
	if player.Parent ~= Players then return end
	player:SetAttribute("PCRewardText", message)
	player:SetAttribute("PCRewardAt", workspace:GetServerTimeNow())
end

function Fishing:_valid(player, station, character)
	local current, root = characterOf(player)
	return current ~= nil and (character == nil or current == character)
		and station.model:IsDescendantOf(self.scene) and station.interaction.Parent ~= nil
		and (root.Position - station.interaction.Position).Magnitude <= 10
end

function Fishing:_finish(player, run, message)
	if self.runs[player] ~= run then return end
	self.runs[player] = nil
	local station = run.station
	if station.run == run then
		station.run = nil
		if station.bobber.Parent then station.bobber.CFrame = station.rest end
		if station.prompt.Parent then station.prompt.Enabled = self.running end
		if station.model.Parent then station.model:SetAttribute("FishingUserId", nil) end
	end
	if player.Parent == Players then
		player:SetAttribute("PCFishingCasting", false)
		player:SetAttribute("PCFishingCastEnds", 0)
		if message then self:_tell(player, message) end
	end
end

function Fishing:_begin(player, station)
	if not self.running or station.run or self.runs[player] or not self:_valid(player, station) then return end
	local now = os.clock()
	if now - (self.requests[player] or -math.huge) < 0.75 then return end
	self.requests[player] = now
	local ok, reason = self.economy:CanFish(player)
	if not ok then self:_tell(player, reason or "Fishing isn't available right now.") return end
	if station.run or self.runs[player] or not self.running or not self:_valid(player, station) then return end
	local run = { station = station, character = player.Character, started = os.clock(), claiming = false }
	self.runs[player], station.run = run, run
	station.prompt.Enabled = false
	station.model:SetAttribute("FishingUserId", player.UserId)
	player:SetAttribute("PCFishingCasting", true)
	player:SetAttribute("PCFishingCastEnds", workspace:GetServerTimeNow() + 6)
	self:_tell(player, "Fishing... stay by the rod until you get a bite!")
end

function Fishing:_claim(player, run)
	if run.claiming or self.runs[player] ~= run or not self.running then return end
	if not self:_valid(player, run.station, run.character) then self:_finish(player, run, "Fishing cancelled. Your catch wasn't used.") return end
	run.claiming = true
	local called, ok, message = pcall(function() return self.economy:ClaimFishingReward(player) end)
	if not called then
		warn("Fishing reward could not finish: " .. tostring(ok))
		message = "Your catch couldn't be confirmed. Please try the rod again."
	elseif typeof(message) ~= "string" then
		message = ok and "Caught a five-minute boost!" or "Your catch couldn't be confirmed. Try again."
	end
	self:_finish(player, run, message)
end

function Fishing:_step(now)
	for player, run in self.runs do
		if run.claiming then continue end
		if not self:_valid(player, run.station, run.character) then
			self:_finish(player, run, "Fishing cancelled. Your catch wasn't used.")
		else
			local elapsed = now - run.started
			local dip = elapsed > 4.8 and -0.22 or 0
			run.station.bobber.CFrame = run.station.rest * CFrame.new(0, math.sin(elapsed * 5) * 0.055 + dip, 0)
			if elapsed >= 6 then
				run.claiming = true
				task.spawn(function()
					run.claiming = false
					self:_claim(player, run)
				end)
			end
		end
	end
end

function Fishing:Start()
	if self.running then return self end
	self.running = true
	for _, station in self.stations do
		station.prompt.Enabled = true
		station.model:SetAttribute("FishingUserId", nil)
		table.insert(self.connections, station.prompt.Triggered:Connect(function(player) self:_begin(player, station) end))
	end
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player)
		local run = self.runs[player]
		if run then self:_finish(player, run) end
		self.requests[player] = nil
	end))
	local elapsed = 0
	table.insert(self.connections, RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 0.08 then elapsed = 0 self:_step(os.clock()) end
	end))
	return self
end

function Fishing:Stop()
	self.running = false
	for _, connection in self.connections do connection:Disconnect() end
	table.clear(self.connections)
	for player, run in self.runs do self:_finish(player, run) end
	table.clear(self.requests)
	for _, station in self.stations do
		if station.prompt.Parent then station.prompt.Enabled = false end
		if station.bobber.Parent then station.bobber.CFrame = station.rest end
	end
end

return Fishing

]====]
source=source:gsub('local Players = game:GetService%("Players"%)\n','',1):gsub('local RunService = game:GetService%("RunService"%)\n','',1)
local fixture=Instance.new("Folder") fixture.Name="FishingChecks20261007" fixture.Parent=game.ServerStorage
local testModule=Instance.new("ModuleScript") testModule.Source="return function(Players, RunService)\n"..source.."\nend" testModule.Parent=fixture
local passed=0
local function check(value,message) assert(value,message);passed+=1 end
local function signal()
 local callbacks={}
 return {Connect=function(_,fn)
  local connection={Connected=true}
  function connection:Disconnect() self.Connected=false end
  table.insert(callbacks,{connection=connection,fn=fn})
  return connection
 end}
end
local players={PlayerRemoving=signal()}
local rs={Heartbeat=signal()}
local scene=Instance.new("Model") scene.Name="Scene" scene.Parent=fixture
for index=1,4 do
 local rod=Instance.new("Model") rod.Name="Rod"..index rod.Parent=scene
 local interaction=Instance.new("Part") interaction.Name="Interaction" interaction.Anchored=true interaction.Position=Vector3.new(index*20,4,0) interaction.Parent=rod
 local prompt=Instance.new("ProximityPrompt") prompt.Name="Fish" prompt.Parent=interaction
 local bobber=Instance.new("Part") bobber.Name="Bobber" bobber.Anchored=true bobber.Position=interaction.Position+Vector3.new(0,0,8) bobber.Parent=rod
end
local function player(id)
 local character=Instance.new("Model") character.Parent=fixture
 local root=Instance.new("Part") root.Name="HumanoidRootPart" root.Anchored=true root.Position=Vector3.new(20,5,0) root.Parent=character
 local humanoid=Instance.new("Humanoid") humanoid.Parent=character
 local p={Parent=players,UserId=id,Character=character,attributes={PCDataReady=true}}
 function p:GetAttribute(name) return self.attributes[name] end
 function p:SetAttribute(name,value) self.attributes[name]=value end
 return p,root,humanoid
end
local p,root,humanoid=player(1)
local q,qroot=player(2)
local claims=0
local allowance=true
local econ={}
function econ:CanFish() return allowance, "No catches remaining." end
function econ:ClaimFishingReward() claims+=1 return true,"+5 minutes of 2x coins!","Coins",os.time()+300 end
local ok,err=pcall(function()
 local Fishing=require(testModule)(players,rs)
 local service=Fishing.new(scene,econ):Start()
 check(#service.stations==4,"four stations")
 check(#service.connections==6,"six event bindings")
 service:Start();check(#service.connections==6,"idempotent start")
 local a=service.stations[1]
 root.Position=Vector3.new(200,5,0)
 service:_begin(p,a);check(service.runs[p]==nil,"remote distant trigger rejected")
 root.Position=a.interaction.Position
 p.attributes.BBParticipating=true;service:_begin(p,a);check(service.runs[p]==nil,"round player rejected");p.attributes.BBParticipating=false
 p.attributes.PCDataReady=false;service:_begin(p,a);check(service.runs[p]==nil,"unloaded player rejected");p.attributes.PCDataReady=true
 humanoid.Health=0;service:_begin(p,a);check(service.runs[p]==nil,"dead player rejected");humanoid.Health=100
 allowance=false;service:_begin(p,a);check(service.runs[p]==nil and claims==0,"daily cap does not start cast");allowance=true
 service.requests[p]=nil;service:_begin(p,a);check(service.runs[p] and not a.prompt.Enabled,"cast reserves rod")
 check(p.attributes.PCFishingCasting==true,"cast feedback")
 qroot.Position=a.interaction.Position
 service:_begin(q,a);check(service.runs[q]==nil,"occupied rod denied")
 service:_begin(p,service.stations[2]);check(service.stations[2].run==nil,"one cast per player")
 root.Position=Vector3.new(200,5,0);service:_step(os.clock())
 check(service.runs[p]==nil and a.prompt.Enabled and claims==0,"walking away cancels without consuming")
 root.Position=a.interaction.Position;service.requests[p]=nil;service:_begin(p,a)
 service:_step(service.runs[p].started+5);check(claims==0,"no early catch")
 service.runs[p].started=os.clock()-7;service:_step(os.clock());task.wait()
 check(claims==1 and service.runs[p]==nil and a.prompt.Enabled,"six second catch awarded once")
 service:_step(os.clock()+10);check(claims==1,"no repeated completion")
 service.requests[p]=nil;service:_begin(p,a);p.attributes.TGParticipating=true;service:_step(os.clock())
 check(service.runs[p]==nil and claims==1,"round entry cancels cast");p.attributes.TGParticipating=false
 service.requests[p]=nil;service:_begin(p,a)
 local connections=table.clone(service.connections)
 service:Stop()
 check(service.running==false and next(service.runs)==nil,"stop clears active cast")
 for _,connection in connections do check(not connection.Connected,"connection cleaned") end
 check(p.attributes.PCFishingCasting==false and not a.prompt.Enabled,"stop clears feedback")
 service:Stop();check(next(service.runs)==nil,"stop idempotent")
end)
fixture:Destroy()
assert(ok,tostring(err))
return game.HttpService:JSONEncode({passed=passed,play=game:GetService("RunService"):IsRunning()})
