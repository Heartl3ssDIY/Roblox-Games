assert(not game:GetService("RunService"):IsRunning(), "Edit only")
local fixture = Instance.new("Folder")
fixture.Name, fixture.Parent = "VIPDragonUnlockFixture", game.ServerStorage
local catalogModule = game.ReplicatedStorage.PlaygroundCatalog:Clone()
catalogModule.Parent = fixture
local module = game.ServerScriptService.PlaygroundEconomyService:Clone()
module.Source = module.Source:gsub('require%(ReplicatedStorage:WaitForChild%("PlaygroundCatalog"%)%)', 'require(script.Parent.PlaygroundCatalog)')
module.Parent = fixture
game.ServerScriptService.PlaygroundRedemptionCodes:Clone().Parent = fixture
local checks = 0
local function check(value, message) assert(value, message); checks += 1 end
local ok, result = xpcall(function()
	local Economy, Catalog = require(module), require(catalogModule)
	check(Catalog.ById.P36.unlock.kind == "VIP" and Catalog.ById.P36.price == 0, "Wrong VIP catalog rule")
	local data
	local store = {}
	local function copy(value) return value and game.HttpService:JSONDecode(game.HttpService:JSONEncode(value)) end
	function store:UpdateAsync(_, transform)
		local nextData = transform(copy(data))
		if nextData then data = copy(nextData) end
		return copy(nextData)
	end
	local economy = Economy.new(workspace["Playground Lobby"], store, false)
	local attrs = {}
	local player = {Parent=game.Players, UserId=987654323, Name="VIPDragonFixture"}
	function player:GetAttribute(key) return attrs[key] end
	function player:SetAttribute(key, value) attrs[key]=value end
	function player:FindFirstChild() return nil end
	local profile = {player=player, ready=false, version=0, connections={}, pickups={}, lastMutation=-math.huge, lastStatus=-math.huge, lastExpression=-math.huge}
	economy.profiles[player]=profile
	check(economy:_claim(profile), "Mock profile unavailable")
	economy:_sync(profile)
	check(not profile.data.Owned.P36, "Dragon owned without VIP")
	check(not economy:Handle(player,"Buy","P36").ok, "Dragon bypass through zero-price purchase")
	profile.lastMutation=-math.huge
	check(not economy:Handle(player,"Equip","P36").ok, "Dragon equipped without VIP")
	check(economy:AdminGrantEntitlement(player,"VIP"), "VIP admin grant failed")
	check(profile.data.Owned.P36 and attrs.PCVIP, "VIP grant did not award dragon")
	check(economy:SetPassBenefits(player,false,false,false) and attrs.PCVIP and profile.data.Owned.P36, "Pass refresh lost manual dragon reward")
	profile.lastMutation=-math.huge
	check(economy:Handle(player,"Equip","P36").ok and attrs.PCPet=="P36", "VIP dragon did not equip")
	check(economy:_save(profile,true), "Mock save failed")
	check(data.Entitlements.VIP and data.Owned.P36 and data.Equipped.Pet=="P36", "Dragon ownership or equip was not saved")
	check(next(require(fixture.PlaygroundRedemptionCodes))==nil, "An active code was invented")
	return {passed=true, checks=checks}
end, debug.traceback)
fixture:Destroy()
return {ok=ok,result=result}

