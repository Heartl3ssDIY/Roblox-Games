local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local SSS = game:GetService("ServerScriptService")
local folder = Instance.new("Folder")
folder.Name, folder.Parent = "AdventureVerificationFixture", workspace
local modules = Instance.new("Folder")
modules.Name, modules.Parent = "AdventureVerificationModules", ServerStorage
local economy, obby
local count = 0
local function check(value, message) assert(value, message); count += 1 end
local result
local ok, err = xpcall(function()
	local economyModule = SSS.PlaygroundEconomyService:Clone()
	economyModule.Parent = modules
	local obbyModule = SSS.PlaygroundSecretObbyService:Clone()
	obbyModule.Parent = modules
	local Economy, Obby = require(economyModule), require(obbyModule)
	local data
	local store = {}
	function store:UpdateAsync(_, transform) local nextValue=transform(data); if nextValue then data=nextValue end; return nextValue end
	economy = Economy.new(workspace["Playground Lobby"], store, false)
	local attrs = {}
	local player = { Parent=Players, UserId=987654321, Name="AdventureFixture" }
	function player:GetAttribute(name) return attrs[name] end
	function player:SetAttribute(name, value) attrs[name]=value end
	function player:FindFirstChild() return nil end
	local profile = { player=player, ready=false, version=0, connections={}, pickups={} }
	economy.profiles[player] = profile
	check(economy:_claim(profile), "Profile could not claim test store")
	check(profile.data.SecretObbyClaimDay == 0, "Older profile did not receive default claim marker")
	local oldCoins, oldWins, oldXP = profile.data.Coins, profile.data.Wins, profile.data.XP
	local rewarded = economy:ClaimSecretObbyReward(player)
	check(rewarded and profile.data.Coins == oldCoins + 1000, "Completion did not grant exactly1000")
	check(profile.data.Wins==oldWins and profile.data.XP==oldXP, "Obby incorrectly granted wins or XP")
	check(not economy:ClaimSecretObbyReward(player), "Duplicate daily prize allowed")
	task.wait()
	check(data.Coins==profile.data.Coins and data.SecretObbyClaimDay==math.floor(os.time()/86400), "Coins and daily marker not saved together")
	check(economy:_save(profile,true), "Profile could not release")
	local nextProfile={player=player,ready=false,version=0,connections={},pickups={}}
	economy.profiles[player]=nextProfile
	check(economy:_claim(nextProfile), "Rejoin profile did not load")
	check(not economy:ClaimSecretObbyReward(player), "Rejoining reset daily reward")
	check(nextProfile.data.Coins==oldCoins+1000, "Rejoin balance changed")
	nextProfile.data.SecretObbyClaimDay=math.floor(os.time()/86400)-1
	check(economy:ClaimSecretObbyReward(player), "Next UTC day did not unlock reward")
	check(nextProfile.data.Coins==oldCoins+2000, "New day wrong amount")
	attrs.BBParticipating=true
	nextProfile.data.SecretObbyClaimDay=0
	check(not economy:ClaimSecretObbyReward(player), "Round participant accepted reward")
	attrs.BBParticipating=false
	nextProfile.data.Coins=1000000000
	check(not economy:ClaimSecretObbyReward(player), "Coin cap overflow allowed")
	local scene=workspace["Playground Lobby"].SecretCaveObby:Clone()
	scene.Parent=folder
	local entry=workspace["Playground Lobby"].Improvements20261003.CaveAlcove.SecretPassage:Clone()
	entry.Parent=folder
	local character=Instance.new("Model")
	character.Name,character.Parent="TestCharacter",folder
	local root=Instance.new("Part")
	root.Name,root.Size,root.Anchored,root.Parent="HumanoidRootPart",Vector3.new(2,2,1),true,character
	character.PrimaryPart=root
	local humanoid=Instance.new("Humanoid")
	humanoid.HipHeight=2
	humanoid.Parent=character
	player.Character=character
	attrs.PCDataReady=true
	local grants=0
	local reward={ClaimSecretObbyReward=function() grants+=1;return true,"awarded" end}
	obby=Obby.new(scene,entry,reward)
	check(#obby.tiles==8 and #scene.Tiles:GetChildren()==24, "Wrong tile count")
	for row=1,8 do
		check(obby.path[row]>=1 and obby.path[row]<=3, "Unsafe path column")
		if row>1 then check(math.abs(obby.path[row]-obby.path[row-1])<=1,"Path cannot be crossed by normal jumps") end
	end
	character:PivotTo(CFrame.new(0,5,0))
	obby:_enter(player)
	check(not obby.runs[player], "Remote entrance trigger accepted")
	character:PivotTo(CFrame.new(entry.Opening.Position+Vector3.new(0,0,4)))
	attrs.TGParticipating=true
	obby:_enter(player)
	check(not obby.runs[player], "Round player entered secret area")
	attrs.TGParticipating=false
	obby:_enter(player)
	check(obby.runs[player] and (root.Position-scene.StartPoint.Position).Magnitude<0.01, "Entry did not transport player")
	local run=obby.runs[player]
	local bad=obby.tiles[1][obby.path[1]%3+1]
	obby:_visit(player,run,bad,os.clock())
	check(bad.failedAt~=nil and run.row==0,"Wrong tile granted progress")
	bad.failedAt=os.clock()-.3
	obby:_tick(.1)
	check(not bad.top.CanCollide and bad.top.Transparency==1,"Wrong tile did not disappear")
	bad.failedAt=os.clock()-4
	obby:_tick(.1)
	check(bad.top.CanCollide and bad.top.Transparency==0,"Wrong tile did not restore")
	obby:_visit(player,run,obby.tiles[3][obby.path[3]],os.clock())
	check(run.row==0,"Skipping rows accepted")
	for row=1,8 do obby:_visit(player,run,obby.tiles[row][obby.path[row]],os.clock()+row) end
	check(run.row==8 and attrs.PCSecretObbyRow==8,"Valid full path rejected")
	character:PivotTo(CFrame.new(scene.StartPoint.Position))
	obby:_claim(player)
	check(grants==0,"Reward accepted away from chest")
	run.started=os.clock()-10
	character:PivotTo(CFrame.new(scene.TreasureChest.Latch.Position+Vector3.new(0,1,3)))
	obby:_claim(player)
	check(grants==1,"Valid finish did not reach reward service")
	attrs.MDParticipating=true
	obby:_tick(.1)
	check(obby.runs[player]==nil,"Round start failed to clear obby attempt")
	attrs.MDParticipating=false
	check(obby:Start()==obby and obby:Start()==obby,"Start was not idempotent")
	check(#obby.connections==6,"Unexpected event connections")
	obby:Stop()
	check(#obby.connections==0,"Stop leaked connections")
	result={passed=true,checks=count,realDataStoreUsed=false,playStarted=false}
end,debug.traceback)
if obby then obby:Stop() end
if economy then economy:Stop() end
folder:Destroy()
modules:Destroy()
if not ok then error(err) end
return game:GetService("HttpService"):JSONEncode(result)
