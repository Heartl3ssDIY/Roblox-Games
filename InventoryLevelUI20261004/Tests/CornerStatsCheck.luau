assert(not game:GetService("RunService"):IsRunning())
local wallet=game.StarterGui.PlaygroundShell.Wallet
local shop=game.StarterGui.PlaygroundShell.ShopPanel
local originals={Coins=wallet.Coins.Text,Wins=wallet.Wins.Text,Level=wallet.Level.Text,Shop=shop.Coins.Text}
local positions={}for _,name in ipairs({"Coins","Wins","Level"})do positions[name]={wallet[name].Position,wallet[name].Size}end
local attributes={PCWins=24,PCLevel=7}
local player={GetAttribute=function(_,name)return attributes[name]end}
local data={coins=1250,ready=true}
local function refreshWallet()
	local coins = data.ready and tostring(data.coins or 0) or "..."
	wallet.Coins.Text = coins
	wallet.Wins.Text = data.ready and tostring(player:GetAttribute("PCWins") or 0) or "..."
	wallet.Level.Text = data.ready and tostring(player:GetAttribute("PCLevel") or 1) or "..."
	shop.Coins.Text = coins .. " coins"
end
local ok,err=xpcall(function()
 refreshWallet()
 assert(wallet.Wins.Text=="24" and wallet.Level.Text=="7" and wallet.Coins.Text=="1250")
 data.coins=1255 attributes.PCLevel=8 refreshWallet()
 assert(wallet.Level.Text=="8" and wallet.Coins.Text=="1255" and wallet.Wins.Text=="24")
 data.ready=false refreshWallet()
 assert(wallet.Level.Text=="..." and wallet.Coins.Text=="..." and wallet.Wins.Text=="...")
 for name,p in pairs(positions)do assert(wallet[name].Position==p[1] and wallet[name].Size==p[2])end
end,debug.traceback)
for _,name in ipairs({"Coins","Wins","Level"})do wallet[name].Text=originals[name]end shop.Coins.Text=originals.Shop
return {passed=ok,error=not ok and err or nil,valuesUpdate=true,loadingPlaceholder=true,authoredLayoutUnchanged=true,playStarted=false}
