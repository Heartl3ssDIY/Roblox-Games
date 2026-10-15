from pathlib import Path
import json
import re

root = Path(__file__).parent
snapshot = json.loads((root/'SourceSnapshot.json').read_text(encoding='utf-8'))
metadata = {row['path']:row for row in snapshot['metadata']}
(root/'After').mkdir(exist_ok=True)

def exact(source, before, after):
    assert before in source, before
    return source.replace(before, after)

def fingerprint(source):
    value = 0
    for byte in source.replace('\r\n','\n').encode('utf-8'):
        value = (value*31+byte)%2147483647
    return value

sources = {}
before_hashes = {}
for row in snapshot['sources']:
    path, source = row['path'], row['source']
    name = path.replace('.','__')+'.luau'
    (root/'Before'/name).write_bytes(source.encode('utf-8'))
    before_hashes[path] = fingerprint(source)
    if path.endswith('PlaygroundPets'):
        continue
    source = re.sub(r'or\s+([\w.]+):GetAttribute\("HSParticipating"\)(\s*==\s*true)?',lambda m:m.group(0)+' or '+m.group(1)+':GetAttribute("DGParticipating")'+(m.group(2) or ''),source)
    source = re.sub(r'and\s+([\w.]+):GetAttribute\("HSParticipating"\)(\s*~=\s*true)',lambda m:m.group(0)+' and '+m.group(1)+':GetAttribute("DGParticipating")'+m.group(2),source)
    source = re.sub(r'and not ([\w.]+):GetAttribute\("HSParticipating"\)',lambda m:m.group(0)+' and not '+m.group(1)+':GetAttribute("DGParticipating")',source)
    source = re.sub(r',\s*"HSParticipating"(?=\s*[,}])',', "HSParticipating", "DGParticipating"',source)
    source = re.sub(r'or\s+([\w.]+):GetAttribute\("HSRagdolled"\)(\s*==\s*true)',lambda m:m.group(0)+' or '+m.group(1)+':GetAttribute("DGRagdolled")'+m.group(2),source)
    source = re.sub(r'"HSRagdolled"(?=\s*[,}])','"HSRagdolled", "DGRole", "DGRagdolled"',source)
    source = re.sub(r',\s*"HideAndSeek"(?=\s*})',', "HideAndSeek", "DuckDuckGoose"',source)
    source = source.replace('HideAndSeek = "Hide and Seek"','HideAndSeek = "Hide and Seek", DuckDuckGoose = "Duck Duck Goose"')
    source = source.replace('HideAndSeek = "HSParticipating"','HideAndSeek = "HSParticipating", DuckDuckGoose = "DGParticipating"')
    source = source.replace('HideAndSeek = "HideAndSeekState"','HideAndSeek = "HideAndSeekState", DuckDuckGoose = "DuckDuckGooseState"')
    source = source.replace('HideAndSeek = true','HideAndSeek = true, DuckDuckGoose = true')
    source = source.replace('HideAndSeekState = true','HideAndSeekState = true, DuckDuckGooseState = true')
    source = source.replace('"HideAndSeekState" }','"HideAndSeekState", "DuckDuckGooseState" }')
    source = source.replace('HS = "HideAndSeek"','HS = "HideAndSeek", DG = "DuckDuckGoose"')
    if path.endswith('PlaygroundBootstrap'):
        source = exact(source,'local HideAndSeek = require(ServerScriptService:WaitForChild("HideAndSeekService"))','local HideAndSeek = require(ServerScriptService:WaitForChild("HideAndSeekService"))\nlocal DuckDuckGoose = require(ServerScriptService:WaitForChild("DuckDuckGooseService"))')
        source = exact(source,'local hideAndSeek = HideAndSeek.new(workspace:WaitForChild("Hide and Seek"))','local hideAndSeek = HideAndSeek.new(workspace:WaitForChild("Hide and Seek"))\nlocal duckDuckGoose = DuckDuckGoose.new(workspace:WaitForChild("Duck Duck Goose"))')
        source = exact(source,'hideAndSeek.lobbySpawn = spawn','hideAndSeek.lobbySpawn = spawn\nduckDuckGoose.lobbySpawn = spawn')
        source = exact(source,'hideAndSeek:Start()','hideAndSeek:Start()\nduckDuckGoose:Start()\nscript.Destroying:Connect(function() duckDuckGoose:Stop() end)')
        source = source.replace('HideAndSeek = hideAndSeek }','HideAndSeek = hideAndSeek, DuckDuckGoose = duckDuckGoose }')
        source = exact(source,'[hideAndSeek] = "_begin"','[hideAndSeek] = "_begin", [duckDuckGoose] = "_begin"')
    elif path.endswith('PlaygroundCoordinator'):
        source = exact(source,'HideAndSeek = 0','HideAndSeek = 0, DuckDuckGoose = 0')
        start=source.index('function Coordinator:_rewardHideAndSeek()')
        end=source.index('\nfunction Coordinator:_padVoting()',start)
        reward=source[start:end].replace('_rewardHideAndSeek','_rewardDuckDuckGoose').replace('self.services.HideAndSeek','self.services.DuckDuckGoose').replace('"HS:"','"DG:"').replace('gameId = "HideAndSeek"','gameId = "DuckDuckGoose"')
        source=source[:end]+'\n'+reward+'\n'+source[end:]
        source=exact(source,'if self.services.HideAndSeek then table.insert(self.connections, self.services.HideAndSeek.state:GetAttributeChangedSignal("LastResultRound"):Connect(function() self:_rewardHideAndSeek() end)) end','if self.services.HideAndSeek then table.insert(self.connections, self.services.HideAndSeek.state:GetAttributeChangedSignal("LastResultRound"):Connect(function() self:_rewardHideAndSeek() end)) end\n\tif self.services.DuckDuckGoose then table.insert(self.connections, self.services.DuckDuckGoose.state:GetAttributeChangedSignal("LastResultRound"):Connect(function() self:_rewardDuckDuckGoose() end)) end')
    elif path.endswith('PlaygroundEquipmentService') or path=='StarterGui.PlaygroundBatControls.Controller':
        existing='if state and state:GetAttribute("Phase") == "Seeking" then '+('return "HideAndSeek"' if path.endswith('PlaygroundEquipmentService') else 'gameId = "HideAndSeek"')+' end'
        assignment='return "DuckDuckGoose"' if path.endswith('PlaygroundEquipmentService') else 'gameId = "DuckDuckGoose"'
        source=exact(source,existing,existing+'\n\telseif player:GetAttribute("DGParticipating") == true and player:GetAttribute("DGRole") == "Goose" then\n\t\tlocal state = ReplicatedStorage:FindFirstChild("DuckDuckGooseState")\n\t\tif state and state:GetAttribute("Phase") == "Playing" and state:GetAttribute("TurnPhase") == "Chasing" then '+assignment+' end')
        if path.endswith('PlaygroundEquipmentService'):
            existing='if state then table.insert(self.connections, state:GetAttributeChangedSignal("Phase"):Connect(function()\n\t\t\tfor _, record in pairs(self.records) do self:_queue(record) end\n\t\tend)) end'
            source=exact(source,existing,'if state then\n\t\t\tfor _, attribute in { "Phase", "TurnPhase" } do\n\t\t\t\ttable.insert(self.connections, state:GetAttributeChangedSignal(attribute):Connect(function()\n\t\t\t\t\tfor _, record in pairs(self.records) do self:_queue(record) end\n\t\t\t\tend))\n\t\t\tend\n\t\tend')
    elif path.endswith('PlaygroundAdminService'):
        source=exact(source,'controls.HSStart = { game = "HideAndSeek" }','controls.HSStart = { game = "HideAndSeek" }\ncontrols.DGStart = { game = "DuckDuckGoose" }')
        source=exact(source,'role = active == "HideAndSeek"','role = active == "DuckDuckGoose" and player:GetAttribute("DGRole") or active == "HideAndSeek"')
    elif path=='StarterGui.PlaygroundAdminPanel.Controller':
        source=exact(source,'"HSStart", "StopRound"','"HSStart", "DGStart", "StopRound"')
    elif path.endswith('PlaygroundPushService'):
        source=exact(source,'if record.player:GetAttribute("MDParticipating") == true then return false end','if record.player:GetAttribute("MDParticipating") == true or record.player:GetAttribute("HSParticipating") == true or record.player:GetAttribute("DGParticipating") == true then return false end')
    elif path=='StarterGui.PlaygroundPushControls.Controller':
        source=exact(source,'or player:GetAttribute("PCPushed") == true then return nil end','or player:GetAttribute("PCPushed") == true or player:GetAttribute("HSParticipating") == true\n\t\tor player:GetAttribute("DGParticipating") == true then return nil end')
    elif path.endswith('PlaygroundEmotes'):
        source=exact(source,'or (gameName == "HideAndSeek" and player:GetAttribute("HSParticipating") == true)', 'or (gameName == "HideAndSeek" and player:GetAttribute("HSParticipating") == true)\n\t\tor (gameName == "DuckDuckGoose" and player:GetAttribute("DGParticipating") == true and player:GetAttribute("DGRole") == "Goose")')
    elif path=='StarterGui.PlaygroundShell.Controller':
        source=exact(source,'local button, counter = vote[id], vote["Votes" .. id]','local card = vote.Choices[id]\n  local button, counter = card.Button, card.VoteCount')
        source=exact(source,'HideAndSeek = Color3.fromRGB(188,143,245)','HideAndSeek = Color3.fromRGB(188,143,245), DuckDuckGoose = Color3.fromRGB(246,189,62)')
        source=exact(source,'local function refreshVotes()','local lastDisplayedVote = {}\nlocal function refreshVotes()')
        source=exact(source,' end\n if not voteBusy then\n  vote.Message.Text=', ''' end
 if chosen and chosen ~= "" and chosen ~= lastDisplayedVote[vote] then
  local card = vote.Choices:FindFirstChild(chosen)
  if card then
   local left = card.Position.X.Offset
   local right = left + card.Size.X.Offset
   local current = vote.Choices.CanvasPosition.X
   local width = vote.Choices.AbsoluteSize.X
   local maximum = math.max(0, vote.Choices.AbsoluteCanvasSize.X - width)
   if left < current then current = left elseif right > current + width then current = right - width end
   vote.Choices.CanvasPosition = Vector2.new(math.clamp(current, 0, maximum), 0)
   lastDisplayedVote[vote] = chosen
  end
 end
 if not voteBusy then
  vote.Message.Text=''')
        source=exact(source,'panel[id].Activated:Connect','panel.Choices[id].Button.Activated:Connect')
        source=exact(source,' end\n if chosen and chosen ~= ""', '''  local fallback = button:FindFirstChild("ArtFallback")
  if fallback then
   fallback.Visible = not button.ReusableSkin.IsLoaded
   fallback.Face.BackgroundColor3 = button.BackgroundColor3
  end
 end
 if chosen and chosen ~= ""''')
    if path not in {'ServerScriptService.PlaygroundCoordinator','ServerScriptService.PlaygroundAdminService','StarterGui.PlaygroundSessionControls.Controller','StarterGui.PlaygroundBatControls.Controller','StarterPlayer.StarterPlayerScripts.BritishBulldogCamera'}:
        source = re.sub(r'or\s+([\w.]+):GetAttribute\("DGParticipating"\)(\s*==\s*true)?',lambda m:m.group(0)+' or '+m.group(1)+':GetAttribute("DGEliminated")'+(m.group(2) or ''),source)
        source = re.sub(r'and\s+([\w.]+):GetAttribute\("DGParticipating"\)(\s*~=\s*true)',lambda m:m.group(0)+' and '+m.group(1)+':GetAttribute("DGEliminated")'+m.group(2),source)
        source = re.sub(r'and not ([\w.]+):GetAttribute\("DGParticipating"\)',lambda m:m.group(0)+' and not '+m.group(1)+':GetAttribute("DGEliminated")',source)
        source = re.sub(r',\s*"DGParticipating"(?=\s*[,}])',', "DGParticipating", "DGEliminated"',source)
    if source != row['source']:
        sources[path] = source
        (root/'After'/name).write_bytes(source.encode('utf-8'))

groups=[]
for path in sources:
    if path=='ServerScriptService.PlaygroundBootstrap':
        continue
    if not groups or sum(len(sources[x]) for x in groups[-1])+len(sources[path])>70000:
        groups.append([])
    groups[-1].append(path)
groups.append(['ServerScriptService.PlaygroundBootstrap'])
for index, group in enumerate(groups,1):
    entries=',\n'.join(' {path='+json.dumps(path)+',expected='+str(before_hashes[path])+',after='+str(fingerprint(sources[path]))+',caps='+json.dumps(metadata[path]['caps'])+',sandboxed='+str(metadata[path]['sandboxed']).lower()+',source=[==['+sources[path]+']==]}' for path in group)
    install='''assert(not game:GetService("RunService"):IsRunning(), "Stop Play before integrating Duck Duck Goose.")
assert(game.PlaceId == 95034648955135, "Wrong experience.")
local entries = {ENTRIES}
local function fingerprint(source)
 source = string.gsub(source,"\\r\\n","\\n")
 local value=0
 for index=1,#source do value=(value*31+string.byte(source,index))%2147483647 end
 return value
end
local objects={}
for _,entry in entries do
 local object=game
 for name in string.gmatch(entry.path,"[^.]+") do object=object:FindFirstChild(name) assert(object,"Missing "..entry.path) end
 local hash=fingerprint(object.Source)
 assert(hash==entry.expected or hash==entry.after,"Source changed: "..entry.path)
 assert(tostring(object.Capabilities)==entry.caps and object.Sandboxed==entry.sandboxed,"Permissions changed: "..entry.path)
 objects[entry.path]=object
end
local storage=game:GetService("ServerStorage")
local backup=storage:FindFirstChild("DuckDuckGooseIntegrationBackup20261010")
if not backup then backup=Instance.new("Folder") backup.Name,backup.Parent="DuckDuckGooseIntegrationBackup20261010",storage end
local changed=0
for _,entry in entries do
 local object=objects[entry.path]
 if fingerprint(object.Source)~=entry.after then
  local snapshot=object:Clone()
  snapshot.Name=entry.path
  if snapshot:IsA("BaseScript") then snapshot.Enabled=false end
  snapshot.Parent=backup
  object.Source=entry.source
  object:SetAttribute("DuckDuckGooseIntegrated20261010",true)
  changed+=1
 end
end
return {patched=changed,capabilitiesPreserved=true,backup=backup:GetFullName()}
'''.replace('ENTRIES',entries)
    (root/('InstallSources'+str(index)+'.luau')).write_text(install,encoding='utf-8')
(root/'Manifest.json').write_text(json.dumps({'groups':groups,'beforeHashes':before_hashes,'afterHashes':{k:fingerprint(v) for k,v in sources.items()},'metadata':metadata},indent=2),encoding='utf-8')
print(json.dumps({'patched':len(sources),'groups':len(groups),'sources':list(sources)}))
