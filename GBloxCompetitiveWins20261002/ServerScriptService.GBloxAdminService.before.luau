local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")

local Data=require(script.Parent:WaitForChild("PlayerData"))
local remote=ReplicatedStorage:WaitForChild("GBloxAdminRequest")

local ADMIN_USER_IDS={
 [1201803949]=true,
}
local lastRequest={}
local cashInFlight={}
local departing=setmetatable({},{__mode="k"})

local function reply(player,ok,message)
 if player.Parent~=Players then return end
 remote:FireClient(player,{
  Ok=ok,
  Message=message,
  Cash=player:GetAttribute("Cash") or 0,
  Trophies=player:GetAttribute("Trophies") or 0,
 })
end

Players.PlayerRemoving:Connect(function(player)
 lastRequest[player]=nil
 cashInFlight[player]=nil
 departing[player]=true
end)

local function resolveTarget(requester,query)
 if typeof(query)~="string" then return requester end
 query=string.lower(string.gsub(query,"^%s*(.-)%s*$","%1"))
 if query=="" or query=="me" or query=="self" then return requester end
 local userId=tonumber(query)
 for _,candidate in Players:GetPlayers() do
  if (userId and candidate.UserId==userId) or string.lower(candidate.Name)==query then
   return candidate
  end
 end
end

remote.OnServerEvent:Connect(function(player,currency,amount,targetQuery)
 if not ADMIN_USER_IDS[player.UserId] then
  warn(string.format("[GBloxAdmin] Rejected request from %s (%d)",player.Name,player.UserId))
  return
 end
 if currency~="Cash" and currency~="Trophies" and currency~="EarnedCash" and currency~="AdjustTrophies" and currency~="GiveTargetCash" then return end
 if typeof(amount)~="number" or amount~=amount or math.abs(amount)==math.huge then
  reply(player,false,"Enter a valid amount.")
  return
 end
 if currency=="GiveTargetCash" then
  if amount<1 or amount>1000000 or amount~=math.floor(amount) then
   reply(player,false,"Enter a whole cash amount from 1 to 1,000,000.")
   return
  end
  if typeof(targetQuery)~="string" or #targetQuery>100 then
   reply(player,false,"Use an exact username, user ID, or ME.")
   return
  end
 elseif currency=="AdjustTrophies" then
  amount=math.clamp(math.floor(amount),-1000000,1000000)
  if amount==0 then reply(player,false,"Enter an amount greater than zero.") return end
 else
  amount=math.clamp(math.floor(amount),1,1000000)
 end
 local now=os.clock()
 if now-(lastRequest[player] or 0)<.12 then return end
 lastRequest[player]=now

 if currency=="GiveTargetCash" then
  if cashInFlight[player] then
   reply(player,false,"A cash gift is still saving. Please wait.")
   return
  end
  local target=resolveTarget(player,targetQuery)
  if not target or target.Parent~=Players or departing[target] then
   reply(player,false,"That player is not in this server. Use their exact username or user ID.")
   return
  end
  local profile=Data.Get(target)
  if not profile or (not profile.CanSave and not profile.StudioTemporary) then
   reply(player,false,target.Name.."'s player data is not ready yet.")
   return
  end
  if profile.PurchasePending or (profile.CanSave and os.time()>=(profile.LeaseUntil or 0))
   or (profile.PlaytimeRewards and profile.PlaytimeRewards.Handoff)
   or target:GetAttribute("GBloxPlaytimeTransferring") then
   reply(player,false,target.Name.."'s save is busy or they are travelling. Try again shortly.")
   return
  end
  cashInFlight[player]=true
  local balance=Data.AddCash(target,amount)
  if balance==nil then
   cashInFlight[player]=nil
   reply(player,false,target.Name.."'s player data is not ready yet.")
   return
  end
  local message=string.format("Gave %d cash to %s. Balance: %d.",amount,target.Name,balance)
  if profile.StudioTemporary then
   message=message.." Studio test only; not saved."
  else
   local ok,saved=pcall(Data.Save,target)
   if not ok or not saved then
    message=message.." Added; save pending. Do not repeat this gift."
   end
  end
  cashInFlight[player]=nil
  reply(player,true,message)
  return
 end

 if currency=="AdjustTrophies" then
  local target=resolveTarget(player,targetQuery)
  if not target then
   reply(player,false,"That player is not in this server. Use their exact username or user ID.")
   return
  end
  local before=target:GetAttribute("Trophies") or 0
  local balance=Data.AddTrophies(target,amount)
  if balance==nil then
   reply(player,false,target.Name.."'s player data is not ready yet.")
   return
  end
  local changed=balance-before
  if changed>=0 then
   reply(player,true,string.format("Gave %d trophies to %s. Balance: %d.",changed,target.Name,balance))
  else
   reply(player,true,string.format("Took %d trophies from %s. Balance: %d.",math.abs(changed),target.Name,balance))
  end
  return
 end

 local balance,awarded
 if currency=="Cash" then
  balance=Data.AddCash(player,amount)
 elseif currency=="Trophies" then
  balance=Data.AddTrophies(player,amount)
 else
  balance,awarded=Data.AddEarnedCash(player,amount)
 end
 if balance==nil then
  reply(player,false,"Your player data is not ready yet.")
  return
 end
 if currency=="EarnedCash" then
  local multiplier=Data.GetPetMultipliers(player)
  reply(player,true,string.format("%d base cash × %g = %d cash.",amount,multiplier,awarded))
 else
  reply(player,true,string.format("Added %s %s.",amount,currency:lower()))
 end
end)

