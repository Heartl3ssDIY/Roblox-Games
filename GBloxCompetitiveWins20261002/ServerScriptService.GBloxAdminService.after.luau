local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")

local Data=require(script.Parent:WaitForChild("PlayerData"))
local remote=ReplicatedStorage:WaitForChild("GBloxAdminRequest")
local GiveawayService=(function()
local GiveawayService={}
GiveawayService.__index=GiveawayService

local THRESHOLD=10
local PAGE_SIZE=50
local REQUEST_INTERVAL=.8
local REFRESH_INTERVAL=15
local CURSOR_LIFETIME=300
local NAME_LIFETIME=21600
local NAME_CACHE_LIMIT=2000
local MAX_REQUEST_ID=2147483647

local function validInteger(value,minimum,maximum)
 return type(value)=="number" and value==value and value~=math.huge
  and value~=-math.huge and value==math.floor(value)
  and value>=minimum and value<=maximum
end

local function entryUserId(entry)
 if type(entry)~="table" then return nil end
 local key=entry.key
 if type(key)~="string" and type(key)~="number" then return nil end
 return tonumber(key)
end

function GiveawayService.new(dependencies)
 assert(dependencies and dependencies.WinsStore and dependencies.Players
  and dependencies.UserService and dependencies.Send,"Giveaway dependencies are required")
 return setmetatable({
  _wins=dependencies.WinsStore,
  _players=dependencies.Players,
  _users=dependencies.UserService,
  _send=dependencies.Send,
  _clock=dependencies.Clock or os.clock,
  _time=dependencies.Time or os.time,
  _states=setmetatable({},{__mode="k"}),
  _names={},
  _nameOrder={},
 },GiveawayService)
end

function GiveawayService:Remove(player)
 self._states[player]=nil
end

function GiveawayService:_active(player,state)
 return self._states[player]==state and player.Parent==self._players
end

function GiveawayService:_reply(player,state,requestId,ok,message,rows,more)
 if not self:_active(player,state) then return end
 if more==nil then more=state.Pages~=nil and state.Finished~=true end
 self._send(player,{
  Kind="Giveaway",
  RequestId=requestId,
  Ok=ok,
  Message=message,
  Rows=rows or {},
  Page=state.Page or 0,
  More=more==true,
  CanRetryNext=state.PendingPage==true,
  Threshold=THRESHOLD,
  RefreshedAt=state.RefreshedAt or 0,
 })
end

function GiveawayService:_retainPage(state,pages,refreshing)
 if refreshing then
  state.Pages=pages
  state.Page=0
  state.Seen={}
  state.ExpiresAt=self._clock()+CURSOR_LIFETIME
  state.RefreshedAt=self._time()
 end
 state.PendingPage=true
 state.InFlight=false
end

function GiveawayService:_namesFor(entries)
 local now=self._clock()
 local missing={}
 local queued={}
 for _,entry in ipairs(entries) do
  local userId=entryUserId(entry)
  if validInteger(userId,1,9007199254740991)
   and validInteger(entry.value,THRESHOLD,9007199254740991) and not queued[userId] then
   queued[userId]=true
   local cached=self._names[userId]
   if not cached or now-cached.At>=NAME_LIFETIME then
    table.insert(missing,userId)
   end
  end
 end
 for first=1,#missing,PAGE_SIZE do
  local batch={}
  for index=first,math.min(first+PAGE_SIZE-1,#missing) do table.insert(batch,missing[index]) end
  local ok,infos=pcall(function()
   return self._users:GetUserInfosByUserIdsAsync(batch)
  end)
  if ok and type(infos)=="table" then
   for _,info in ipairs(infos) do
    if type(info)=="table" and queued[info.Id] and type(info.Username)=="string" then
     if not self._names[info.Id] then
      table.insert(self._nameOrder,info.Id)
      if #self._nameOrder>NAME_CACHE_LIMIT then
       self._names[table.remove(self._nameOrder,1)]=nil
      end
     end
     self._names[info.Id]={
      Username=info.Username,
      DisplayName=type(info.DisplayName)=="string" and info.DisplayName or info.Username,
      At=now,
     }
    end
   end
  end
 end
end

function GiveawayService:_rows(entries,seen)
 self:_namesFor(entries)
 local rows={}
 local added={}
 for _,entry in ipairs(entries) do
  local userId=entryUserId(entry)
  local wins=type(entry)=="table" and entry.value or nil
  if validInteger(userId,1,9007199254740991)
   and validInteger(wins,THRESHOLD,9007199254740991)
   and not seen[userId] and not added[userId] then
   added[userId]=true
   local info=self._names[userId]
   local fallback="User #"..tostring(userId)
   table.insert(rows,{
    UserId=userId,
    Username=info and info.Username or fallback,
    DisplayName=info and info.DisplayName or fallback,
    Wins=wins,
   })
  end
 end
 return rows,added
end

function GiveawayService:Handle(player,action,requestId)
 if action~="GiveawayRefresh" and action~="GiveawayNext" then return false end
 if player.Parent~=self._players or not validInteger(requestId,1,MAX_REQUEST_ID) then return true end
 local state=self._states[player]
 if not state then
  state={Page=0,Seen={}}
  self._states[player]=state
 end
 local now=self._clock()
 if state.InFlight then
  self:_reply(player,state,requestId,false,"A giveaway check is still loading. Please wait.")
  return true
 end
 if state.LastRequest and now-state.LastRequest<REQUEST_INTERVAL then
  self:_reply(player,state,requestId,false,"Please wait a moment before checking again.")
  return true
 end
 state.LastRequest=now
 if action=="GiveawayRefresh" then
  if state.LastRefresh and now-state.LastRefresh<REFRESH_INTERVAL then
   self:_reply(player,state,requestId,false,"Wait 15 seconds between full refreshes.")
   return true
  end
  state.LastRefresh=now
 elseif not state.Pages or not state.ExpiresAt or now>=state.ExpiresAt then
  self:_reply(player,state,requestId,false,"Refresh the giveaway list before loading another page.")
  return true
 elseif state.Finished and not state.PendingPage then
  self:_reply(player,state,requestId,false,"All saved players with 10 or more wins have been listed.")
  return true
 end
 state.InFlight=true
 local pages=state.Pages
 local refreshing=action=="GiveawayRefresh"
 if refreshing then
  local ok,result=pcall(function()
   return self._wins:GetSortedAsync(false,PAGE_SIZE,THRESHOLD)
  end)
  if not self:_active(player,state) then return true end
  if not ok or not result then
   state.InFlight=false
   self:_reply(player,state,requestId,false,"Roblox could not load the saved wins list. Please try again shortly.")
   return true
  end
  pages=result
 elseif not state.PendingPage then
  local ok=pcall(function() pages:AdvanceToNextPageAsync() end)
  if not self:_active(player,state) then return true end
  if not ok then
   state.InFlight=false
   self:_reply(player,state,requestId,false,"Roblox could not load the next page. You can retry NEXT.")
   return true
  end
  state.PendingPage=true
 end
 local ok,entries,finished=pcall(function()
  return pages:GetCurrentPage(),pages.IsFinished
 end)
 if not self:_active(player,state) then return true end
 if not ok or type(entries)~="table" then
  self:_retainPage(state,pages,refreshing)
  self:_reply(player,state,requestId,false,"The saved wins page is not ready. Retry NEXT to load this page.")
  return true
 end
 local seen=refreshing and {} or state.Seen
 local rowOk,rows,added=pcall(function() return self:_rows(entries,seen) end)
 if not self:_active(player,state) then return true end
 if not rowOk then
  self:_retainPage(state,pages,refreshing)
  self:_reply(player,state,requestId,false,"The saved wins page could not be displayed. Retry NEXT to load this page.")
  return true
 end
 if refreshing then
  state.Page=0
  state.Seen=seen
  state.ExpiresAt=self._clock()+CURSOR_LIFETIME
  state.RefreshedAt=self._time()
 end
 for userId in pairs(added) do state.Seen[userId]=true end
 state.Pages=pages
 state.Page+=1
 state.Finished=finished==true
 state.PendingPage=false
 state.InFlight=false
 self:_reply(player,state,requestId,true,
  "Saved G-Blox win totals (10+), including offline players. Recent wins appear after saving.",
  rows,not state.Finished)
 return true
end

return GiveawayService

end)()
local giveaway=GiveawayService.new({
 WinsStore=Data.OrderedStores.Wins,
 Players=Players,
 UserService=game:GetService("UserService"),
 Send=function(player,payload) remote:FireClient(player,payload) end,
})

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
 giveaway:Remove(player)
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
 if giveaway:Handle(player,currency,amount) then return end
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

