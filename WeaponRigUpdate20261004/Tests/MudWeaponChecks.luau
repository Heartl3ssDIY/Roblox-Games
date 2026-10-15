local Service=assert(loadstring(assert(_G.MudWeaponCandidateSource)))()
local fixture=Instance.new("Folder")fixture.Name="MudWeaponLifecycleCheck20261004"fixture.Parent=workspace
local checks={}
local connections={}
local function check(name,condition)assert(condition,name)table.insert(checks,name)end
local ok,failure=xpcall(function()
	local r=game.ServerStorage.WeaponRigFixtures.R6:Clone()
	for _,t in ipairs(r:GetChildren())do if t:IsA("Tool")then t:Destroy()end end
	r.Parent=fixture
	local playerData=Instance.new("Folder")playerData.Name="FakePlayer"playerData.Parent=fixture
	local backpack=Instance.new("Backpack")backpack.Parent=playerData
	local starter=Instance.new("Folder")starter.Name="StarterGear"starter.Parent=playerData
	local player={Character=r,UserId=-8104}
	function player:GetAttribute(k)return playerData:GetAttribute(k)end
	function player:SetAttribute(k,v)playerData:SetAttribute(k,v)end
	function player:FindFirstChild(k)return playerData:FindFirstChild(k)end
	local humanoid={Health=100}
	function humanoid:UnequipTools()for _,t in ipairs(r:GetChildren())do if t:IsA("Tool")then t.Parent=backpack end end end
	function humanoid:EquipTool(tool)tool.Parent=r end
	local record={player=player,isBot=false,ready=true,character=r,root=r.HumanoidRootPart,humanoid=humanoid,managedTools={},participating=false}
	local service=setmetatable({active=false,roundNumber=71,records={[player]=record}},Service)
	service._publishRecord=function()end
	local function guns()
		local n=0
		for _,c in ipairs({r,backpack,starter})do for _,t in ipairs(c:GetChildren())do if t:IsA("Tool")and(t.Name=="MudGun"or t.Name=="HeatGun")and t:GetAttribute("ManagedMudTemplate")then n+=1 end end end
		return n
	end
	service:_giveTools(record)check("No lobby guns",guns()==0)
	service.active=true;service:_giveTools(record)check("Spectators get no guns",guns()==0)
	record.participating=true;service:_giveTools(record)
	check("Mud participant gets two native tools",guns()==2)
	check("Mud service selects MudGun for native equip",r:FindFirstChild("MudGun")~=nil and backpack:FindFirstChild("HeatGun")~=nil)
	local mud=r.MudGun
	check("Round ownership is stamped",mud:GetAttribute("MDRound")==71 and mud:GetAttribute("MDOwnerUserId")==player.UserId)
	check("Guns cannot be dropped",mud.CanBeDropped==false)
	check("Current owned gun can fire",service:_equipped(record,"Mud")==mud)
	mud:SetAttribute("MDOwnerUserId",19)check("Other player's gun cannot fire",service:_equipped(record,"Mud")==nil)
	mud:SetAttribute("MDOwnerUserId",player.UserId);mud:SetAttribute("MDRound",70)
	check("Previous round gun cannot fire",service:_equipped(record,"Mud")==nil)
	service:_giveTools(record)check("Regrant replaces, never duplicates",guns()==2 and mud.Parent==nil)
	player:SetAttribute("BBParticipating",true);service:_giveTools(record)
	check("Bulldog cannot keep or obtain guns",guns()==0)
	player:SetAttribute("BBParticipating",nil);player:SetAttribute("TGParticipating",true);service:_giveTools(record)
	check("Tag cannot keep or obtain guns",guns()==0)
	player:SetAttribute("TGParticipating",nil);record.ready=false;service:_giveTools(record)
	check("Dead or unready characters get no guns",guns()==0)
	record.ready=true;player.Character=nil;service:_giveTools(record)
	check("Old respawn character gets no guns",guns()==0)
	player.Character=r;service:_giveTools(record)
	service:_watchTools(record,r,connections);service:_watchTools(record,backpack,connections);service:_watchTools(record,starter,connections)
	task.wait(.1)check("Container watchers preserve valid tools",guns()==2)
	local illegal=game.ReplicatedStorage.MudAssets.MudGun:Clone();illegal.Parent=starter
	task.wait(.1)check("StarterGear cannot preserve a gun",illegal.Parent==nil)
	illegal=game.ReplicatedStorage.MudAssets.MudGun:Clone();illegal:SetAttribute("MDRound",70);illegal:SetAttribute("MDOwnerUserId",player.UserId);illegal.Parent=backpack
	task.wait(.1)check("Backpack rejects stale round tools",illegal.Parent==nil)
	illegal=game.ReplicatedStorage.MudAssets.MudGun:Clone();illegal:SetAttribute("MDRound",71);illegal:SetAttribute("MDOwnerUserId",100);illegal.Parent=r
	task.wait(.1)check("Character rejects another player's tool",illegal.Parent==nil)
	service.active=false;service:_destroyTools(record)
	check("Round exit clears backpack and character",guns()==0)
	illegal=game.ReplicatedStorage.MudAssets.HeatGun:Clone();illegal.Parent=backpack
	task.wait(.1)check("Lobby watcher removes externally copied guns",illegal.Parent==nil)
	local foreign=Instance.new("Tool");foreign.Name="MudGun";foreign.Parent=backpack
	illegal=game.ReplicatedStorage.MudAssets.HeatGun:Clone();illegal.Parent=backpack
	record.managedTools={};service:_destroyTools(record)
	check("Cleanup sweeps untracked managed tools",illegal.Parent==nil)
	check("Cleanup preserves unrelated tools",foreign.Parent==backpack)
	for _,name in ipairs({"MudGun","HeatGun"})do
		local live=game.ReplicatedStorage.MudAssets[name]
		local before=game.ServerStorage.WeaponRigBackup20261004[name]
		local count=0
		for _,p in ipairs(live:GetDescendants())do if p:IsA("MeshPart")then
			count+=1
			local b=before:FindFirstChild(p.Name,true)
			assert(b and b.MeshId==p.MeshId and b.Size==p.Size and (b.CFrame.Position-p.CFrame.Position).Magnitude<.0001,"Art changed: "..p.Name)
		end end
		check(name.." preserves every imported mesh",count==(name=="MudGun"and 70 or 65))
		check(name.." has matching editable hand attachment",live.Handle.RightGripAttachment.CFrame==live.Grip)
		local nozzle=live:FindFirstChild("SITM_"..name.."_SplatNozzle_Front",true)
		local front=live.Handle.CFrame:PointToObjectSpace(nozzle.Position).Z-nozzle.Size.Z/2
		check(name.." muzzle clears barrel tip",live.Handle.MuzzleAttachment.Position.Z<front and front-live.Handle.MuzzleAttachment.Position.Z<.03)
	end
end,debug.traceback)
for _,c in ipairs(connections)do c:Disconnect()end
fixture:Destroy()
assert(ok,failure)
return game.HttpService:JSONEncode({passed=#checks,checks=checks})
