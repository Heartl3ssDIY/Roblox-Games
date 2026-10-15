from pathlib import Path
import subprocess,json,hashlib
folder=Path(__file__).resolve().parents[1]
source=(folder/'Before/PlaygroundLeaderboardController.client.luau').read_text()
helper=source[source.index('local function validBoard'):source.index('local function render')]
test='''local checks=0
local function check(value,message)assert(value,message)checks+=1 end
local gui={attrs={PodiumScope="global",PodiumBoard="MostWins"},GetAttribute=function(self,k)return self.attrs[k]end,SetAttribute=function(self,k,v)self.attrs[k]=v end}
local HttpService={JSONEncode=function(_,value)return value end}
__HELPER__
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
'''.replace('__HELPER__',helper)
output=folder/'Tests/Forwarding.generated.luau'
output.write_text(test)
runner=folder.parent/'AttackTiming20260926/tools/luau-0.740/luau.exe'
result=subprocess.run([str(runner),str(output)],capture_output=True,text=True)
print(result.stdout,result.stderr)
assert result.returncode==0
before=(folder/'Before/PlaygroundEmotes.client.luau').read_text()
after=(folder/'After/PlaygroundEmotes.client.luau').read_text()
assert after[:after.index('local catalogEmote')].rstrip()==before[:before.index('local beforeAnimation =')].rstrip()
assert after[after.index('local function animatePracticeBots'):after.index('local catalogEmote')].rstrip()==before[before.index('local function animatePracticeBots'):before.index('local beforeAnimation =')].rstrip()
assert 'ContentProvider' not in after
hashes={name:hashlib.sha256((folder/'After'/name).read_bytes()).hexdigest() for name in ('PlaygroundEmotes.client.luau','PlaygroundPodiumController.client.luau')}
(folder/'Tests/ClientSourceValidation.json').write_text(json.dumps({'passed':True,'forwardingChecks':11,'priorBatToyDodgeBotFunctionsUnchanged':True,'ContentProviderRequired':False,'sourceSHA256':hashes},indent=2))
print('Prior bat/toy/dodge/bot functions preserved; source hashes saved')
