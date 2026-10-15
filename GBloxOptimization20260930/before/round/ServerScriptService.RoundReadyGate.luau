-- Server-owned, round-versioned readiness barrier. No timers can advance it.
local Gate = {}
Gate.__index = Gate
function Gate.new()
 return setmetatable({version=nil, members={}}, Gate)
end
function Gate:Open(version, userIds)
 self.version=version self.members={}
 for _,id in userIds do self.members[id]=false end
end
function Gate:SetReady(userId, version, ready)
 if self.version~=version or self.members[userId]==nil or typeof(ready)~="boolean" then return false end
 self.members[userId]=ready
 return true
end
function Gate:Remove(userId)
 self.members[userId]=nil
end
function Gate:Summary()
 local count,total,ids=0,0,{}
 for id,ready in self.members do
  total+=1
  if ready then count+=1 table.insert(ids,id) end
 end
 table.sort(ids)
 return {courseVersion=self.version,readyCount=count,totalCount=total,readyIds=ids,allReady=total>0 and count==total}
end
function Gate:Close()
 self.version=nil self.members={}
end
return Gate

