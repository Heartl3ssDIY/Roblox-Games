local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
assert(not game:GetService("RunService"):IsRunning(), "Edit only")
local fixture = Instance.new("Folder")
fixture.Name, fixture.Parent = "VIPServerVerification", game.ServerStorage
local module = game.ServerScriptService.PlaygroundEconomyService:Clone()
module.Parent = fixture
game.ServerScriptService.PlaygroundRedemptionCodes:Clone().Parent = fixture
local commerceModule = game.ServerScriptService.PlaygroundCommerceService:Clone()
commerceModule.Parent = fixture
local economy, character
local checks = 0
local function check(value, message) assert(value, message); checks += 1 end
local function copy(value) return value and HttpService:JSONDecode(HttpService:JSONEncode(value)) end
local result
local ok, err = xpcall(function()
	local Economy = require(module)
	local Commerce = require(commerceModule)
	local data, mode
	local store = {}
	function store:UpdateAsync(_, transform)
		if mode == "fail" then error("Expected storage failure") end
		if mode == "delay" then task.wait(.15) end
		local value = transform(copy(data))
		if value then data = copy(value) end
		if mode == "ambiguous" then error("Expected acknowledgement failure") end
		return copy(value)
	end
	economy = Economy.new(workspace["Playground Lobby"], store, false)
	local attrs = {}
	local player = {Parent=Players,UserId=987654321,Name="EntitlementFixture"}
	function player:GetAttribute(name) return attrs[name] end
	function player:SetAttribute(name,value) attrs[name]=value end
	function player:FindFirstChild() return nil end
	local function acquire()
		local p = {player=player,ready=false,version=0,connections={},pickups={},lastMutation=-math.huge,lastStatus=-math.huge,lastExpression=-math.huge}
		economy.profiles[player] = p
		check(economy:_claim(p),"Mock profile acquisition failed")
		economy:_sync(p)
		return p
	end
	local profile = acquire()
	check(not profile.data.Entitlements.VIP and not profile.data.Entitlements.BetaTester and next(profile.data.RedeemedCodes)==nil,"Legacy profile migration failed")
	check(not attrs.PCVIP and not attrs.PCBetaTester,"Entitlements leaked before grant")
	check(not economy:AdminGrantEntitlement(player,"Admin"),"Unknown entitlement accepted")
	check(economy:AdminGrantEntitlement(player,"VIP"),"VIP grant failed")
	check(data.Entitlements.VIP and attrs.PCVIP,"VIP grant not persisted or replicated")
	check(economy:_earnedCoins(profile,5)==15 and economy:_earnedXP(profile,50)==100,"Manual VIP benefits incorrect")
	check(economy:SetPassBenefits(player,false,false,false) and attrs.PCVIP,"False gamepass refresh revoked manual VIP")
	check(economy:AdminGrantEntitlement(player,"BetaTester") and data.Entitlements.BetaTester and attrs.PCBetaTester,"Beta grant failed")
	check(economy:AdminGrantEntitlement(player,"VIP"),"Repeat VIP grant not idempotent")
	profile.data.FishingCoinsExpires,profile.data.FishingXPExpires=os.time()+300,os.time()+300
	economy:_sync(profile)
	check(attrs.PCCoinMultiplier==6 and attrs.PCXPMultiplier==4,"Fishing did not double manual VIP")
	local status=economy:Status(player,true)
	check(status.entitlements.VIP and status.entitlements.BetaTester,"Status entitlement contract broken")
	check(economy:_save(profile,true),"Save/release failed")
	profile=acquire()
	check(attrs.PCVIP and attrs.PCBetaTester and data.Entitlements.VIP,"Entitlement rejoin lost")
	local rule={id="fixtureVIP",unlock={kind="VIP"},available=true}
	check(Economy.EvaluateUnlock(profile.data,rule,1,{VIP=true}).unlocked,"VIP catalog rule not supported")
	check(not Economy.EvaluateUnlock(profile.data,rule,1,{VIP=false}).unlocked,"Non-VIP catalog bypass")
	character=Instance.new("Model") character.Name="EntitlementTagFixture" character.Parent=fixture
	local head=Instance.new("Part") head.Name="Head" head.Parent=character player.Character=character
	local commerce=Commerce.new(economy)
	commerce:_tag(player)
	check(head.PlaygroundVIPTag.Title.Text=="VIP • BETA TESTER","Dual tag hidden or overwritten")
	attrs.PCVIP=false commerce:_tag(player)
	check(head.PlaygroundVIPTag.Title.Text=="BETA TESTER","Beta-only tag missing")
	attrs.PCBetaTester=false commerce:_tag(player)
	check(not head:FindFirstChild("PlaygroundVIPTag"),"Tag not removed when neither entitlement")
	economy:_sync(profile)
	local function redeem(payload)
		profile.lastRedeem=-math.huge
		return economy:RedeemCode(player,payload)
	end
	check(not redeem(nil) and not redeem({code=7}) and not redeem({code=string.rep("a",65)}),"Malformed payload accepted")
	check(not redeem({code="a b"}) and not redeem({code=""}),"Invalid code accepted")
	check(not redeem({code="MISSING"}),"Nonexistent code accepted")
	economy.redemptionCodes.DISABLED={Enabled=false,Kind="VIP"}
	economy.redemptionCodes.EXPIRED={Enabled=true,Kind="Coins",Amount=10,ExpiresAt=os.time()-1}
	economy.redemptionCodes.BAD={Enabled=true,Kind="Coins",Amount=math.huge}
	check(not redeem({code="DISABLED"}) and not redeem({code="EXPIRED"}) and not redeem({code="BAD"}),"Disabled, expired or invalid reward accepted")
	economy.redemptionCodes.COINS={Enabled=true,Kind="Coins",Amount=123}
	local before=profile.data.Coins
	check(redeem({code="  coins  "}),"Trim/case-insensitive code failed")
	check(profile.data.Coins==before+123 and data.Coins==before+123 and data.RedeemedCodes.COINS~=nil,"Code reward/marker not atomic or coins multiplied")
	check(not economy:RedeemCode(player,{code="COINS"}),"Rate limit bypassed")
	check(not redeem({code="COINS"}) and profile.data.Coins==before+123,"Code duplicate granted")
	check(economy:_save(profile,true),"Code release failed")
	profile=acquire()
	check(not redeem({code="COINS"}),"Rejoin allowed duplicate code")
	economy.redemptionCodes.WAIT={Enabled=true,Kind="Coins",Amount=99}
	before=profile.data.Coins
	mode="fail"
	check(not redeem({code="WAIT"}),"Unconfirmed code reported successful")
	check(profile.data.Coins==before+99 and profile.data.RedeemedCodes.WAIT and not profile.codeSaving,"Failed save lost pending marker or left saving lock")
	mode=nil
	check(redeem({code="WAIT"}) and profile.data.Coins==before+99 and data.RedeemedCodes.WAIT,"Retry doubled reward or failed to confirm")
	economy.redemptionCodes.AMBIGUOUS={Enabled=true,Kind="Coins",Amount=50}
	before=profile.data.Coins mode="ambiguous"
	check(not redeem({code="AMBIGUOUS"}),"Ambiguous save reported success")
	mode=nil
	check(redeem({code="AMBIGUOUS"}) and profile.data.Coins==before+50 and data.Coins==before+50,"Ambiguous retry duplicated coins")
	economy.redemptionCodes.BETA={Enabled=true,Kind="BetaTester"}
	check(redeem({code="BETA"}) and data.RedeemedCodes.BETA and data.Entitlements.BetaTester,"Entitlement code missing durable marker")
	economy.sessionOnly=true
	check(not redeem({code="NEW"}) and not economy:AdminGrantEntitlement(player,"VIP"),"Data offline silently granted persistent benefit")
	economy.sessionOnly=false
	economy.redemptionCodes.BUSY={Enabled=true,Kind="Coins",Amount=20}
	mode="delay" before=profile.data.Coins
	local done,response=false,nil
	task.spawn(function() response=redeem({code="BUSY"}); done=true end)
	task.wait(.03)
	check(not redeem({code="BUSY"}),"Concurrent code request accepted")
	while not done do task.wait(.05) end
	mode=nil
	check(response and profile.data.Coins==before+20,"Concurrent reward duplicated")
	profile.data.Entitlements.VIP=false profile.savedEntitlements.VIP=false
	mode="fail"
	check(not economy:AdminGrantEntitlement(player,"VIP") and not profile.entitlementSaving,"Failed grant retained busy state or acknowledged")
	mode=nil
	check(economy:AdminGrantEntitlement(player,"VIP") and data.Entitlements.VIP,"Pending grant retry failed")
	profile.lastRedeem=-math.huge
	economy.redemptionCodes.HANDLER={Enabled=true,Kind="Coins",Amount=1}
	local r=economy:Handle(player,"RedeemCode",{code="HANDLER"})
	check(r.ok and r.entitlements.VIP,"Remote handler contract failed")
	economy.isStudio=true
	economy.redemptionCodes.STUDIO={Enabled=true,Kind="Coins",Amount=1}
	local granted,message=redeem({code="STUDIO"})
	check(granted and message:find("Studio test",1,true),"Studio persistence caveat missing")
	check(not redeem({code="STUDIO"}),"Studio code duplicated")
	result={checks=checks,passed=true,mode="Edit fixtures with in-memory leased profile store"}
end,debug.traceback)
if economy then economy.effects:Destroy() economy.hiddenCoins:Destroy() end
fixture:Destroy()
if not ok then error(err) end
return result
