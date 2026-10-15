local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Fishing = {}
Fishing.__index = Fishing

local function characterOf(player)
	if player.Parent ~= Players or player:GetAttribute("PCDataReady") ~= true
		or player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true
		or ( player:GetAttribute("MDParticipating") == true or player:GetAttribute("HSParticipating") == true or player:GetAttribute("DGParticipating") == true or player:GetAttribute("DGEliminated") == true ) then return nil end
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


