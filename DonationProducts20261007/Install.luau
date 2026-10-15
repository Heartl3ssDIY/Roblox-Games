assert(not game:GetService("RunService"):IsRunning(), "Install in Edit only")
assert(game.GameId == 10769034155, "Unexpected experience")
local commerce = game.ReplicatedStorage:WaitForChild("PlaygroundCommerce")
local donations = game.ReplicatedStorage:WaitForChild("PlaygroundDonationProducts")
local products = {
 {folder=commerce,name="Coin5000",id=3717139252,robux=49,coins=5000},
 {folder=commerce,name="Coin10000",id=3717139576,robux=99,coins=10000},
 {folder=commerce,name="Coin25000",id=3717139651,robux=249,coins=25000},
 {folder=commerce,name="Coin50000",id=3717139714,robux=499,coins=50000},
 {folder=commerce,name="Coin100000",id=3717139770,robux=999,coins=100000},
 {folder=donations,name="Donation50",id=3717139873,robux=50},
 {folder=donations,name="Donation100",id=3717139915,robux=100},
 {folder=donations,name="Donation250",id=3717139945,robux=250},
 {folder=donations,name="Donation1000",id=3717140010,robux=1000},
}
local verified = {}
local pages = game.MarketplaceService:GetDeveloperProductsAsync()
repeat
 for _, info in pages:GetCurrentPage() do verified[info.ProductId] = info end
 if pages.IsFinished then break end
 pages:AdvanceToNextPageAsync()
until false
for _, product in products do
 local entry = product.folder:FindFirstChild(product.name)
 assert(entry and entry:IsA("IntValue") and entry.Value == 0, "Configuration changed: " .. product.name)
 local info = verified[product.id]
 assert(info and info.UniverseId == game.GameId and info.IsForSale == true, "Product unavailable or wrong experience")
 assert(info.UserBasePriceInRobux == product.robux, "Base price mismatch: " .. product.name)
 if product.coins then
  assert(entry:GetAttribute("Coins") == product.coins and entry:GetAttribute("Kind") == "Product", "Coin reward mismatch")
 else
  assert(entry:GetAttribute("BaseRobux") == product.robux, "Donation amount mismatch")
 end
end
assert(not game.ServerStorage:FindFirstChild("DonationProductsBackup20261007"), "Existing installation backup found")
local backup = Instance.new("Folder")
backup.Name = "DonationProductsBackup20261007"
backup.Parent = game.ServerStorage
commerce:Clone().Parent = backup
donations:Clone().Parent = backup
local installed = {}
for _, product in products do
 product.folder[product.name].Value = product.id
 table.insert(installed, {name=product.name,id=product.id,baseRobux=product.robux,coins=product.coins})
end
assert(commerce:GetAttribute("Ready") == false, "Edit readiness unexpectedly enabled")
return game.HttpService:JSONEncode({installed=installed,backup=backup:GetFullName()})
