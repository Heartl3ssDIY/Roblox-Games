local M={}
function M.Expected(joinData,lobbyId,universeId,maxPlayers)
 if typeof(joinData)~="table" or joinData.SourcePlaceId~=lobbyId or joinData.SourceGameId~=universeId then return nil end
 local payload=joinData.TeleportData
 if typeof(payload)~="table" or payload.FromLobby~=true then return nil end
 local count=tonumber(payload.HumanCount)
 if not count or count~=count or math.abs(count)==math.huge then return nil end
 return math.clamp(math.floor(count),1,maxPlayers)
end
function M.AfterDeadline(expected,connected)
 return math.min(expected,math.max(1,connected))
end
return M
