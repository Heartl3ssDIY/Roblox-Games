local m=Instance.new("ModuleScript")
m.Source="local blue, mint, gold, muted = 1,2,3,4\nlocal function setText(object,value) object.Text=value end\nlocal function emotePlayable(item) return item.slot==\"Emote\" and item.playable==true end\nreturn function(item, owned, equipped, data, busy, unlock)\n local card={Action={}}\n\t\t\tlocal isCoins = item.unlock and item.unlock.kind == \"Coins\"\n\t\t\tlocal canBuy = isCoins and (unlock and unlock.purchasable == true or not unlock and data.coins >= (item.price or 0))\n\t\t\tlocal available = item.available ~= false and (item.slot ~= \"Emote\" or emotePlayable(item))\n\t\t\tlocal action = not available and \"UNAVAILABLE\" or not data.ready and \"LOADING\" or equipped and \"UNEQUIP\" or owned and \"EQUIP\" or isCoins and \"BUY\" or item.unlock and item.unlock.kind == \"VIP\" and \"VIP ONLY\" or item.unlock and item.unlock.kind == \"BetaTester\" and \"BETA ONLY\" or \"LOCKED\"\n\t\t\tif busy then action = \"PLEASE WAIT\" end\n\t\t\tsetText(card.Action, action)\n\t\t\tcard.Action.Visible = true\n\t\t\tcard.Action.Active = not busy and data.ready and available and (owned or canBuy)\n\t\t\tcard.Action.Selectable = card.Action.Active\n\t\t\tcard.Action.BackgroundColor3 = not card.Action.Active and muted or equipped and mint or owned and blue or gold\n\n return card.Action\nend"
m.Parent=game.ServerStorage
local ok,result=pcall(function()
 local action=require(m)
 local item={id="P36",slot="Pet",price=0,unlock={kind="VIP",amount=0},available=true}
 local ready={coins=999999,ready=true}
 local a=action(item,false,false,ready,false,nil)
 assert(a.Text=="VIP ONLY" and not a.Active,"VIP offered a free Buy")
 a=action(item,true,false,ready,false,nil) assert(a.Text=="EQUIP" and a.Active,"VIP cannot equip")
 a=action(item,true,true,ready,false,nil) assert(a.Text=="UNEQUIP" and a.Active,"VIP cannot unequip")
 a=action(item,false,false,{coins=0,ready=false},false,nil) assert(a.Text=="LOADING" and not a.Active,"Loading enabled")
 a=action(item,true,false,ready,true,nil) assert(a.Text=="PLEASE WAIT" and not a.Active,"Busy enabled")
 item.unlock.kind="BetaTester" a=action(item,false,false,ready,false,nil) assert(a.Text=="BETA ONLY" and not a.Active,"Beta offered Buy")
 item.unlock={kind="Coins",amount=30} item.price=30
 a=action(item,false,false,ready,false,nil) assert(a.Text=="BUY" and a.Active,"Coin purchase regressed")
 return {checks=7,VIPCannotBuy=true,ownedEquip=true}
end)
m:Destroy()
assert(ok,result)
return result
