from pathlib import Path
import json

root=Path(__file__).resolve().parent
snapshot=json.loads((root/'BeforeShell.json').read_text(encoding='utf-8'))
before=snapshot['source']
helper=(root/'ResponsiveHud.luau').read_text(encoding='utf-8')
anchor='local function showToast(message, duration)'
assert before.count(anchor)==1
after=before.replace(anchor,helper+'\n'+anchor,1)
destroy='script.Destroying:Connect(function()\n\talive = false'
assert after.count(destroy)==1
after=after.replace(destroy,destroy+'\n\thudScaleConnection:Disconnect()\n\ttable.clear(hudScales)',1)
tick=' elapsed=0\n local character=player.Character'
assert after.count(tick)==1
after=after.replace(tick,' elapsed=0\n refreshHudScale()\n local character=player.Character',1)
(root/'AfterShell.luau').write_text(after,encoding='utf-8',newline='\n')
def literal(s):
 eq='='
 while ']'+eq+']' in s:eq+='='
 return '['+eq+'['+s+']'+eq+']'
code='local before='+literal(before)+'\nlocal after='+literal(after)+'\n'+(root/'ApplyHud.luau').read_text(encoding='utf-8')
(root/'Install.luau').write_text(code,encoding='utf-8',newline='\n')
print('Prepared narrow HUD patch; source bytes',len(after.encode()))
