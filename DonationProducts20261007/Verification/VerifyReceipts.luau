assert(not game:GetService("RunService"):IsRunning(), "Edit only")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local fixture=Instance.new("Folder")
fixture.Name,fixture.Parent="DonationReceiptVerification",game.ServerStorage
local econModule=game.ServerScriptService.PlaygroundEconomyService:Clone()
econModule.Parent=fixture
game.ServerScriptService.PlaygroundRedemptionCodes:Clone().Parent=fixture
local commerceModule=game.ServerScriptService.PlaygroundCommerceService:Clone()
local find='local Players = game:GetService("Players")'
assert(commerceModule.Source:find(find,1,true),"Player seam changed")
commerceModule.Source=commerceModule.Source:gsub('local Players = game:GetService%("Players"%)','local Players = require(script.Parent.FixturePlayers)',1)
commerceModule.Parent=fixture
local mockPlayers=Instance.new("ModuleScript")
mockPlayers.Name,mockPlayers.Source,mockPlayers.Sandboxed="FixturePlayers","return {}",true
mockPlayers.Capabilities=SecurityCapabilities.new(Enum.SecurityCapability.Basic,Enum.SecurityCapability.RunServerScript)
mockPlayers.Parent=fixture
local checks=0
local function check(condition,message) assert(condition,message); checks+=1 end
local function copy(value) return value and HttpService:JSONDecode(HttpService:JSONEncode(value)) end
local economy
local result
local ok,err=xpcall(function()
	local Economy,Commerce=require(econModule),require(commerceModule)
	local data,profileMode
	local store={}
	function store:UpdateAsync(_,transform)
		if profileMode=="fail" then error("Expected profile save failure") end
		local value=transform(copy(data))
		if value then data=copy(value) end
		return copy(value)
	end
	economy=Economy.new(workspace["Playground Lobby"],store,false)
	local attrs={}
	local player={Parent=Players,UserId=987654321,Name="ReceiptFixture"}
	function player:GetAttribute(n) return attrs[n] end
	function player:SetAttribute(n,v) attrs[n]=v end
	function player:FindFirstChild() return nil end
	local registered=true
	require(mockPlayers).GetPlayerByUserId=function(_,id) return registered and id==player.UserId and player or nil end
	local function acquire()
		local p={player=player,ready=false,version=0,connections={},pickups={}}
		economy.profiles[player]=p
		check(economy:_claim(p),"Profile lease unavailable")
		return p
	end
	local profile=acquire()
	economy:SetPassBenefits(player,true,true,true)
	profile.data.FishingCoinsExpires=os.time()+300
	economy:_sync(profile)
	check(attrs.PCCoinMultiplier==6,"VIP + fishing precondition missing")
	local commerce=Commerce.new(economy)
	commerce.running=true
	commerce.config=game.ReplicatedStorage.PlaygroundCommerce:Clone()
	commerce.donations=game.ReplicatedStorage.PlaygroundDonationProducts:Clone()
	commerce.config.Parent,commerce.donations.Parent=fixture,fixture
	local bundles={{5000,3717139252},{10000,3717139576},{25000,3717139651},{50000,3717139714},{100000,3717139770}}
	local donations={{50,3717139873},{100,3717139915},{250,3717139945},{1000,3717140010}}
	for _,pair in bundles do
		local entry=commerce.config:FindFirstChild("Coin"..pair[1])
		check(entry and entry:GetAttribute("Kind")=="Product" and entry:GetAttribute("Coins")==pair[1],"Bundle configuration amount mismatch")
		check(entry.Value==pair[2],"Installed coin product ID mismatch")
	end
	for _,pair in donations do
		local entry=commerce.donations:FindFirstChild("Donation"..pair[1])
		check(entry~=nil,"Donation configuration missing")
		check(entry.Value==pair[2],"Installed donation product ID mismatch")
	end
	local toastCount,donationToast=0,0
	commerce.result={FireClient=function() toastCount+=1 end}
	commerce.donationResult={FireClient=function() donationToast+=1 end}
	local receipts,donationMode={},nil
	commerce.receipts={UpdateAsync=function(_,key,transform)
		if donationMode=="fail" then error("Expected donation storage failure") end
		local value=transform(copy(receipts[key]))
		if value then receipts[key]=copy(value) end
		if donationMode=="ambiguous" then error("Expected ambiguous donation acknowledgement") end
		return copy(value)
	end}
	local granted,retry=Enum.ProductPurchaseDecision.PurchaseGranted,Enum.ProductPurchaseDecision.NotProcessedYet
	local function receipt(purchaseId,productId,spent) return {PurchaseId=purchaseId,ProductId=productId,PlayerId=player.UserId,CurrencySpent=spent or 1} end
	for i,pair in bundles do
		local before=profile.data.Coins
		local value=receipt("coin-"..i,pair[2],1)
		check(commerce:_receipt(value)==granted,"Valid coin bundle not acknowledged")
		check(profile.data.Coins==before+pair[1] and data.Coins==before+pair[1],"Purchased coins multiplied or wrong amount")
		check(data.CoinPurchases[value.PurchaseId].ProductId==pair[2] and data.CoinPurchases[value.PurchaseId].Coins==pair[1],"Receipt marker not durable with exact amount")
		check(commerce:_receipt(value)==granted and profile.data.Coins==before+pair[1],"Duplicate coin receipt double credited")
	end
	check(economy:_save(profile,true),"Profile release failed")
	profile=acquire()
	local before=profile.data.Coins
	check(commerce:_receipt(receipt("coin-5",3717139770))==granted and profile.data.Coins==before,"Rejoin repeated a paid grant")
	profileMode="fail"
	check(commerce:_receipt(receipt("coin-pending",3717139252))==retry,"Failed profile save acknowledged")
	profileMode=nil
	check(commerce:_receipt(receipt("coin-pending",3717139252))==granted and profile.data.Coins==before+5000,"Pending purchase retry duplicated grant")
	before=profile.data.Coins
	for i,pair in donations do
		local value=receipt("donation-"..i,pair[2],pair[1])
		check(commerce:_receipt(value)==granted,"Donation not acknowledged")
		check(receipts[value.PurchaseId].productId==pair[2] and receipts[value.PurchaseId].robux==pair[1],"Donation receipt not recorded")
		check(commerce:_receipt(value)==granted,"Duplicate donation receipt not idempotent")
		check(profile.data.Coins==before and data.CoinPurchases[value.PurchaseId]==nil,"Donation granted coins")
	end
	donationMode="fail"
	check(commerce:_receipt(receipt("donation-pending",3717139873,50))==retry,"Failed donation save acknowledged")
	donationMode=nil
	check(commerce:_receipt(receipt("donation-pending",3717139873,50))==granted and profile.data.Coins==before,"Donation retry granted coins")
	donationMode="ambiguous"
	check(commerce:_receipt(receipt("donation-ambiguous",3717139915,100))==retry,"Ambiguous donation save acknowledged")
	donationMode=nil
	check(commerce:_receipt(receipt("donation-ambiguous",3717139915,100))==granted and profile.data.Coins==before,"Ambiguous donation retry affected coins")
	check(commerce:_receipt(receipt("donation-1",3717139915,100))==retry,"Conflicting donation receipt product accepted")
	check(commerce:_receipt(receipt("unknown",999999999))==retry,"Unknown product acknowledged")
	registered=false
	check(commerce:_receipt(receipt("absent",3717139252))==retry,"Absent player purchase acknowledged")
	registered=true
	check(commerce:_receipt(receipt("",3717139252))==retry,"Missing receipt ID accepted")
	check(commerce:_receipt(receipt(string.rep("X",51),3717139252))==retry,"Oversize receipt ID accepted")
	check(profile.data.Coins==before,"Rejected receipts changed balance")
	result={passed=true,checks=checks,coinBundles=5,donationProducts=4,playStarted=false,realDataStoreUsed=false,liveSourcesChanged=false}
end,debug.traceback)
if economy then economy.effects:Destroy() economy.hiddenCoins:Destroy() end
fixture:Destroy()
if not ok then error(err) end
return result
