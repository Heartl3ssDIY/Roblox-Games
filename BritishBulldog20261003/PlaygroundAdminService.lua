local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ServerStorage=game:GetService("ServerStorage")
local RunService=game:GetService("RunService")

local Admin={}
Admin.__index=Admin
local actions={StartRound=true,PracticeRunner=true,PracticeBulldog=true,StopRound=true,GetStatus=true}

function Admin.new(service,config,isStudio)
 return setmetatable({service=service,config=config,isStudio=isStudio,lastRequest={},lastStatus={},busy=false,connections={}},Admin)
end

function Admin:IsAuthorized(player)
 if self.isStudio then return true end
 local id=player.UserId
 if game.CreatorType==Enum.CreatorType.User and id==game.CreatorId then return true end
 if id==self.config:GetAttribute("AdminUserId") then return true end
 local extra=self.config:GetAttribute("ExtraAdminUserIds")
 if typeof(extra)=="string" then
  for value in string.gmatch(extra,"%d+") do if tonumber(value)==id then return true end end
 end
 return false
end

function Admin:Status(player,ok,message)
 return {
  ok=ok,
  message=message or "",
  phase=self.service.phase or "Waiting",
  mode=self.service.state:GetAttribute("Mode") or "Waiting",
  role=player:GetAttribute("BBRole") or "Spectator",
 }
end

function Admin:Handle(player,action)
 if not self:IsAuthorized(player) then return {ok=false,message="Admin access required."} end
 if typeof(action)~="string" or not actions[action] then return self:Status(player,false,"Unknown control.") end
 local now=os.clock()
 local timestamps=action=="GetStatus" and self.lastStatus or self.lastRequest
 local last=timestamps[player] or -math.huge
 local cooldown=action=="GetStatus" and 0.1 or 0.5
 if now-last<cooldown then return self:Status(player,false,"Please wait a moment.") end
 timestamps[player]=now
 if action=="GetStatus" then return self:Status(player,true,"Ready to play.") end
 if self.busy then return self:Status(player,false,"Another game command is finishing.") end
 self.busy=true
 local ok,success,message=pcall(function()
  if action=="StopRound" then
   return self.service:StopRound()
  elseif self.service.active then
   return false,"A game is running. Press Stop Game first."
  elseif action=="PracticeRunner" then
   local started,reason=self.service:StartPractice(player,"Runner")
   return started,started and "Starting as Runner against an AI Bulldog." or reason
  elseif action=="PracticeBulldog" then
   local started,reason=self.service:StartPractice(player,"Bulldog")
   return started,started and "Starting as Bulldog against AI Runners." or reason
  else
   local started,reason=self.service:StartRound()
   if not started and reason=="Not enough ready players" then
    reason="Play as Runner or Bulldog to test alone. A normal round needs two players."
   end
   return started,started and "Starting British Bulldog with all ready players." or reason
  end
 end)
 self.busy=false
 if not ok then
  warn("Playground admin command failed: "..tostring(success))
  return self:Status(player,false,"The game couldn't start. Try again.")
 end
 return self:Status(player,success==true,message or (success and "Done." or "The game is not ready yet."))
end

function Admin:Destroy()
 for _,connection in ipairs(self.connections) do connection:Disconnect() end
 table.clear(self.connections)
 table.clear(self.lastRequest)
 table.clear(self.lastStatus)
 if self.remote then self.remote.OnServerInvoke=nil end
end

function Admin.Start(service)
 local config=ServerStorage:WaitForChild("PlaygroundAdminConfig")
 local remote=ReplicatedStorage:WaitForChild("PlaygroundAdminRequest")
 local self=Admin.new(service,config,RunService:IsStudio())
 self.remote=remote
 remote.OnServerInvoke=function(player,action) return self:Handle(player,action) end
 local function bindPlayer(player)
  player:SetAttribute("PlaygroundAdmin",self:IsAuthorized(player))
 end
 table.insert(self.connections,Players.PlayerAdded:Connect(bindPlayer))
 table.insert(self.connections,Players.PlayerRemoving:Connect(function(player) self.lastRequest[player]=nil self.lastStatus[player]=nil end))
 for _,player in ipairs(Players:GetPlayers()) do bindPlayer(player) end
 table.insert(self.connections,config.AttributeChanged:Connect(function()
  for _,player in ipairs(Players:GetPlayers()) do bindPlayer(player) end
 end))
 return self
end

return Admin
