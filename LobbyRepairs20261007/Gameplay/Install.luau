local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Edit mode only")
local function checksum(s)
 local a,b=1,0
 for i=1,#s do a=(a+string.byte(s,i))%65521 b=(b+a)%65521 end
 return b*65536+a
end
local function replace(s, old, new)
 local first,last=string.find(s,old,1,true)
 assert(first,"Missing expected source: "..old:sub(1,70))
 return s:sub(1,first-1)..new..s:sub(last+1)
end
local function replaceAll(s, old, new)
 local result,n=s:gsub(old:gsub("(%W)","%%%1"),function() return new end)
 assert(n>0,"Missing expected source: "..old)
 return result
end
local specs={{name=[====[BritishBulldogService]====], target=game.ServerScriptService.BritishBulldogService, before=4287254714, after=1453243384},
{name=[====[BritishBulldogRules]====], target=game.ServerScriptService.BritishBulldogRules, before=4013572699, after=2095802061},
{name=[====[BulldogMovement]====], target=game.StarterGui.BritishBulldogHUD.MovementController, before=1412185453, after=1937318463},
{name=[====[TagSprint]====], target=game.StarterGui.TagHUD.SprintController, before=2359438022, after=1332285336},
{name=[====[MudController]====], target=game.StarterGui.MudHUD.Controller, before=1133263004, after=1581915502}}
for _,entry in specs do assert(checksum(entry.target.Source)==entry.before,"Source changed: "..entry.name) end
local generated={}
for _,entry in specs do
 local source=entry.target.Source
 if entry.name=="BritishBulldogService" then
  source=replace(source,[====[function Service:_outcome()
	local runners, bulldogs, tagged, participants = self:_counts()
	return Rules.Outcome(runners, bulldogs, tagged, participants, self.endsAt > 0 and workspace:GetServerTimeNow() >= self.endsAt, self.lastRunnerWins == true)
end]====],[====[function Service:_outcome()
	local runners, bulldogs, tagged, participants = self:_counts()
	local lastRunnerArrived = false
	if self.lastRunnerWins and runners == 1 then
		for _, record in pairs(self.records) do
			if record.participating and record.role == "Runner" and alive(record) then
				lastRunnerArrived = record.arrived == true and record.departed == true
				break
			end
		end
	end
	return Rules.Outcome(runners, bulldogs, tagged, participants, self.endsAt > 0 and workspace:GetServerTimeNow() >= self.endsAt,
		self.lastRunnerWins == true, lastRunnerArrived)
end]====])
 elseif entry.name=="BritishBulldogRules" then
  source=[====[local Rules = {}

function Rules.IsInside(x, y, z, halfX, halfY, halfZ)
	return math.abs(x) <= halfX and math.abs(y) <= halfY and math.abs(z) <= halfZ
end

function Rules.DepartureExpired(mustLeave, deadline, now)
	return mustLeave and deadline > 0 and now >= deadline
end

function Rules.CrossingResolved(unresolvedRunners)
	return unresolvedRunners == 0
end

function Rules.Outcome(runners, bulldogs, tagged, participants, timedOut, lastRunnerWins, lastRunnerArrived)
	if participants == 0 then
		return "None"
	end
	if runners == 0 then
		return "Bulldogs"
	end
	if lastRunnerWins and runners == 1 then
		if lastRunnerArrived then return "Runners" end
		if timedOut then return "Bulldogs" end
		return nil
	end
	if timedOut or bulldogs + tagged == 0 then
		return "Runners"
	end
	return nil
end

function Rules.CanTag(phase, runnerRole, runnerDeparted, runnerArrived, inField, bulldogFrozen)
	return phase == "Crossing"
		and runnerRole == "Runner"
		and runnerDeparted
		and not runnerArrived
		and inField
		and not bulldogFrozen
end

return Rules
]====]
 else
  source=replaceAll(source,"Enum.KeyCode.LeftControl,Enum.KeyCode.RightControl","Enum.KeyCode.LeftShift")
  source=replaceAll(source,"input.KeyCode==Enum.KeyCode.LeftControl or input.KeyCode==Enum.KeyCode.RightControl","input.KeyCode==Enum.KeyCode.LeftShift")
  source=replaceAll(source,"HOLD CTRL","HOLD SHIFT")
 end
 assert(checksum(source)==entry.after,"Unexpected generated source: "..entry.name)
 generated[entry]=source
end
local storage=game:GetService("ServerStorage")
assert(not storage:FindFirstChild("CrossingSprintBackup20261007"),"Backup exists; check installation")
local backup=Instance.new("Folder")
backup.Name="CrossingSprintBackup20261007"
backup.Parent=storage
for _,entry in specs do
 local original=Instance.new("StringValue")
 original.Name=entry.name
 original.Value=entry.target.Source
 original:SetAttribute("TargetPath",entry.target:GetFullName())
 original.Parent=backup
 entry.target.Source=generated[entry]
 assert(checksum(entry.target.Source)==entry.after,"Readback mismatch: "..entry.name)
end
local labels=0
for _,gui in {game.StarterGui.BritishBulldogHUD,game.StarterGui.TagHUD,game.StarterGui.MudHUD} do
 for _,v in gui:GetDescendants() do
  if (v:IsA("TextLabel") or v:IsA("TextButton")) and v.Text:find("HOLD CTRL",1,true) then
   local old=Instance.new("StringValue")
   old.Name="Label"..tostring(labels+1)
   old.Value=v.Text
   old:SetAttribute("TargetPath",v:GetFullName())
   old.Parent=backup
   v.Text=v.Text:gsub("HOLD CTRL","HOLD SHIFT")
   labels+=1
  end
 end
end
return game:GetService("HttpService"):JSONEncode({installed=#specs,labels=labels,shiftLockEnabled=game.StarterPlayer.EnableMouseLockOption,running=RunService:IsRunning()})

