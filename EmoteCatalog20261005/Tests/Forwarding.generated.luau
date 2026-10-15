local checks=0
local function check(value,message)assert(value,message)checks+=1 end
local gui={attrs={PodiumScope="global",PodiumBoard="MostWins"},GetAttribute=function(self,k)return self.attrs[k]end,SetAttribute=function(self,k,v)self.attrs[k]=v end}
local HttpService={JSONEncode=function(_,value)return value end}
local function validBoard(data)
 return typeof(data) == "table" and typeof(data.entries) == "table"
  and (data.state == nil or data.state == "loading" or data.state == "ready" or data.state == "stale" or data.state == "unavailable")
end

local function publishPodium(record, reply)
 if gui:GetAttribute("PodiumBoard") ~= record.id or gui:GetAttribute("PodiumScope") ~= record.scope then return end
 local data = reply.boards[record.id]
 if not validBoard(data) then return end
 local entries = {}
 for index = 1, 3 do
  local entry = data.entries[index]
  if entry then entries[index] = entry end
 end
 local packet = { board = record.id, scope = record.scope, region = reply.region, state = data.state or reply.state or "ready", status = data.status or reply.status, entries = entries }
 gui:SetAttribute("PodiumSnapshot", HttpService:JSONEncode(packet))
end


local record={id="MostWins",scope="global"}
local entries={}
for i=1,4 do entries[i]={userId=i,name="Player",value="25",emoteId="E0"..i,emoteAnimationId="rbxassetid://123",emoteRigType="R15"}end
publishPodium(record,{boards={MostWins={entries=entries,state="ready"}},state="ready"})
local result=gui.attrs.PodiumSnapshot
check(#result.entries==3,"Only top three forwarded")
for i=1,3 do
 check(result.entries[i].emoteId==entries[i].emoteId,"Equipped identifier preserved")
 check(result.entries[i].emoteAnimationId==entries[i].emoteAnimationId,"Resolved animation ID preserved")
 check(result.entries[i].emoteRigType=="R15","Rig requirement preserved")
end
gui.attrs.PodiumScope="server"publishPodium(record,{boards={MostWins={entries={}}}})
check(gui.attrs.PodiumSnapshot==result,"Unselected scope cannot overwrite winner data")
print("Leaderboard forwarding checks passed: "..checks)
