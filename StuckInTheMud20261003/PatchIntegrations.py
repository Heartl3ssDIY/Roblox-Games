from pathlib import Path
import re
root=Path(r"C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns")
out=root/"StuckInTheMud20261003"
exp=root/"PlaygroundExpansion20261003"
def load(name):
    return (exp/name).read_text(encoding="utf-8-sig")
def save(name,text):
    (out/name).write_text(text,encoding="utf-8",newline="\n")
def replace(text,old,new):
    assert old in text,old[:100]
    return text.replace(old,new)
c=load("PlaygroundCoordinator.lua")
c=replace(c,'local games = { "BritishBulldog", "TagYoureIt" }','local games = { "BritishBulldog", "TagYoureIt", "StuckInTheMud" }')
c=replace(c,'TagYoureIt = "Tag You\'re It" }','TagYoureIt = "Tag You\'re It", StuckInTheMud = "Stuck in the Mud" }')
c=replace(c,'if self.services[id].active then return id end','if self.services[id] and self.services[id].active then return id end')
c=replace(c,'not player:GetAttribute("TGParticipating") and','not player:GetAttribute("TGParticipating") and not player:GetAttribute("MDParticipating") and')
c=replace(c,'player:GetAttribute("TGParticipating") or not self:_insideZone','player:GetAttribute("TGParticipating") or player:GetAttribute("MDParticipating") or not self:_insideZone')
c=replace(c,'local counts = { BritishBulldog = 0, TagYoureIt = 0 }','local counts = { BritishBulldog = 0, TagYoureIt = 0, StuckInTheMud = 0 }')
c=replace(c,'if self.services[id].active then self.services[id]:StopRound() stopped = true end','if self.services[id] and self.services[id].active then self.services[id]:StopRound() stopped = true end')
c=replace(c,'local maximum = math.max(counts.BritishBulldog, counts.TagYoureIt)','local maximum = 0\n\tfor _, id in ipairs(games) do if self.services[id] then maximum = math.max(maximum, counts[id]) end end')
c=replace(c,'if counts[id] == maximum then table.insert(tied, id) end','if self.services[id] and counts[id] == maximum then table.insert(tied, id) end')
reward='''function Coordinator:_rewardMud()
 local service=self.services.StuckInTheMud
 if not service then return end
 local state=service.state
 local ids,participants={},{}
 for value in string.gmatch(state:GetAttribute("LastResultWinnerIds") or "", "%-?%d+") do table.insert(ids,tonumber(value)) end
 for value in string.gmatch(state:GetAttribute("LastResultParticipantIds") or "", "%-?%d+") do table.insert(participants,tonumber(value)) end
 self.economy:AwardRound("MUD:"..tostring(state:GetAttribute("LastResultRound")),ids,state:GetAttribute("LastResultPractice")==true,participants,{winnerXP=50,loserXP=50})
end

function Coordinator:_padVoting()
 self.padChoices=self.padChoices or {}
 if self.state:GetAttribute("Phase")~="Voting" then table.clear(self.padChoices) return end
 local choices=self.lobby.Gameplay:FindFirstChild("VoteChoices")
 if not choices then return end
 for _,player in ipairs(Players:GetPlayers()) do
  local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  local choice
  if root and self:_insideZone(player) then
   for _,pad in ipairs(choices:GetChildren()) do
    if pad:IsA("BasePart") and pad:GetAttribute("Available")~=false then
     local point=pad.CFrame:PointToObjectSpace(root.Position)
     local half=pad.Size/2
     if math.abs(point.X)<=half.X and math.abs(point.Y)<=half.Y and math.abs(point.Z)<=half.Z then choice=pad:GetAttribute("GameId") break end
    end
   end
  end
  if choice~=self.padChoices[player] then
   self.padChoices[player]=choice
   if choice then self:Vote(player,choice) end
  end
 end
end

'''
c=replace(c,'function Coordinator:_loop()',reward+'function Coordinator:_loop()')
c=replace(c,'\t\ttask.wait(0.25)','\t\tself:_padVoting()\n\t\ttask.wait(0.25)')
c=replace(c,'\ttask.spawn(function() self:_loop() end)','\tif self.services.StuckInTheMud then table.insert(self.connections,self.services.StuckInTheMud.state:GetAttributeChangedSignal("LastResultRound"):Connect(function() self:_rewardMud() end)) end\n\ttask.spawn(function() self:_loop() end)')
save("PlaygroundCoordinator.lua",c)
e=load("PlaygroundEconomyService.lua")
e=e.replace('player:GetAttribute("TGParticipating") then','(player:GetAttribute("TGParticipating") or player:GetAttribute("MDParticipating")) then')
e=re.sub(r'(profile\.player|player):GetAttribute\("TGParticipating"\) == true',lambda match:'('+match.group(1)+':GetAttribute("TGParticipating") == true or '+match.group(1)+':GetAttribute("MDParticipating") == true)',e)
e=replace(e,'function Economy:AwardRound(key, winnerIds, practice, participantIds)','function Economy:AwardRound(key, winnerIds, practice, participantIds, rewardOptions)')
e=replace(e,'self:_setting("BaseLevelXP", 100)','self:_setting("BaseLevelXP", 200)')
e=replace(e,'local xp = self:_setting(won and "WinnerXP" or "LoserXP", won and 100 or 25)','local xp = self:_setting(won and "WinnerXP" or "LoserXP", 50)\n\t\t\tif typeof(rewardOptions) == "table" then xp = integer(won and rewardOptions.winnerXP or rewardOptions.loserXP, xp) end')
save("PlaygroundEconomyService.lua",e)
a=load("PlaygroundAdminService.lua")
a=replace(a,'TagTagger = { game = "TagYoureIt", role = "Tagger" },','TagTagger = { game = "TagYoureIt", role = "Tagger" },\n\tMudStart = { game = "StuckInTheMud" }, MudShooter = { game = "StuckInTheMud", role = "Shooter" }, MudMedic = { game = "StuckInTheMud", role = "Medic" },')
a=replace(a,'role = active == "TagYoureIt" and player:GetAttribute("TGRole") or player:GetAttribute("BBRole")','role = active == "StuckInTheMud" and (player:GetAttribute("MDMuddy") and "Stuck" or "Free") or active == "TagYoureIt" and player:GetAttribute("TGRole") or player:GetAttribute("BBRole")')
save("PlaygroundAdminService.lua",a)
a=load("PlaygroundAdminPanel.client.luau")
a=replace(a,'local tag = ReplicatedStorage:WaitForChild("TagState")','local tag = ReplicatedStorage:WaitForChild("TagState")\nlocal mud = ReplicatedStorage:WaitForChild("MudState")')
a=replace(a,'{ BritishBulldog = bb, TagYoureIt = tag }','{ BritishBulldog = bb, TagYoureIt = tag, StuckInTheMud = mud }')
a=replace(a,'{ state, bb, tag }','{ state, bb, tag, mud }')
save("PlaygroundAdminPanel.client.luau",a)
s=load("PlaygroundShell.client.luau")
s=replace(s,'player:GetAttribute("TGParticipating")==true','(player:GetAttribute("TGParticipating")==true or player:GetAttribute("MDParticipating")==true)')
s=replace(s,'vote.VotesTagYoureIt.Text=votesText(state and state:GetAttribute("VotesTagYoureIt") or 0)','vote.VotesTagYoureIt.Text=votesText(state and state:GetAttribute("VotesTagYoureIt") or 0)\n vote.VotesStuckInTheMud.Text=votesText(state and state:GetAttribute("VotesStuckInTheMud") or 0)')
s=replace(s,'vote.TagYoureIt.BackgroundColor3=chosen=="TagYoureIt" and gold or pink','vote.TagYoureIt.BackgroundColor3=chosen=="TagYoureIt" and gold or pink\n vote.StuckInTheMud.BackgroundColor3=chosen=="StuckInTheMud" and gold or mint')
s=replace(s,'vote.TagYoureIt.Active=voting and not voteBusy','vote.TagYoureIt.Active=voting and not voteBusy\n vote.StuckInTheMud.Active=voting and not voteBusy\n vote.StuckInTheMud.Selectable=vote.StuckInTheMud.Active')
s=replace(s,'vote.TagYoureIt.Activated:Connect(function() castVote("TagYoureIt") end)','vote.TagYoureIt.Activated:Connect(function() castVote("TagYoureIt") end)\nvote.StuckInTheMud.Activated:Connect(function() castVote("StuckInTheMud") end)')
save("PlaygroundShell.client.luau",s)
b=load("PlaygroundBootstrap.server.lua")
b=replace(b,'local Economy = require','local Mud = require(ServerScriptService:WaitForChild("StuckInTheMudService"))\nlocal TagSprint = require(ServerScriptService:WaitForChild("TagSprintService"))\nlocal Economy = require')
b=replace(b,'local spawn = lobby.Gameplay.LobbySpawn','local mud = Mud.new(workspace:WaitForChild("Stuck in the Mud"))\nlocal tagSprint = TagSprint.new(tag)\nlocal spawn = lobby.Gameplay.LobbySpawn')
b=replace(b,'tag.lobbySpawn = spawn','tag.lobbySpawn = spawn\nmud.lobbySpawn = spawn')
b=replace(b,'tag:Start()','tag:Start()\nmud:Start()\ntagSprint:Start()')
b=replace(b,'TagYoureIt = tag }','TagYoureIt = tag, StuckInTheMud = mud }')
save("PlaygroundBootstrap.server.lua",b)
t=load("TagHUD.client.luau")
t=replace(t,'rolePanel.BackgroundColor3 =','rolePanel.Visible = not gui:FindFirstChild("SprintPanel")\n\trolePanel.BackgroundColor3 =')
t=replace(t,'protected > 0 and role == "Runner" and phase == "Playing"','protected > 0 and role == "Runner" and phase == "Playing" and now >= messageEndsAt')
t=replace(t,'string.upper(action) .. " " ..','string.upper(action) .. "\\n" ..')
save("TagHUD.client.luau",t)
l=(root/"BritishBulldogMovement20261003"/"PlayerLevel.client.luau").read_text(encoding="utf-8-sig")
l=l.replace('player:GetAttribute("TGParticipating")==true','(player:GetAttribute("TGParticipating")==true or player:GetAttribute("MDParticipating")==true)')
l=l.replace('"TGParticipating"}','"TGParticipating","MDParticipating"}')
l=l.replace('"PCLevelXPRequired",100+50*(level-1)','"PCLevelXPRequired",200+50*(level-1)')
save("PlayerLevel.client.luau",l)
t=load("TagService.lua")
t=t.replace('player:GetAttribute("BBParticipating") ~= true','player:GetAttribute("BBParticipating") ~= true and player:GetAttribute("MDParticipating") ~= true')
t=t.replace('player:GetAttribute("BBParticipating") == true then','(player:GetAttribute("BBParticipating") == true or player:GetAttribute("MDParticipating") == true) then')
save("TagService.lua",t)
print("Written 9 integration sources")

