from pathlib import Path
import subprocess
folder=Path(__file__).resolve().parents[1]
source=(folder/'After/BritishBulldogService.luau').read_text(encoding='utf-8-sig')
shared=source[source.index('local function dodgeSpeed'):source.index('function Service:_updateMovement')]
template=(folder/"Tests"/"DodgeBehavior.template.luau").read_text()
generated=folder/"Tests"/"DodgeBehavior.generated.luau"
generated.write_text(template.replace("__SHARED__",shared),encoding="utf-8")
runner=folder.parent/"AttackTiming20260926"/"tools"/"luau-0.740"/"luau.exe"
result=subprocess.run([str(runner),str(generated)],capture_output=True,text=True)
print('Exact merged Bulldog:',result.stdout,result.stderr)
assert result.returncode==0
tag=(folder/'After/TagService.luau').read_text(encoding='utf-8-sig')
shared=tag[tag.index('local function dodgeSpeed'):tag.index('function Service:_role')]
tagtemplate=template.replace('_startDodgeBurst','_startBurst').replace('dodgeBurst','burst').replace('BBDodge','TGDodge').replace('setAttribute','attribute').replace('phase="Crossing"','phase="Playing"')
tagtemplate=tagtemplate.replace('"death","arrived","role"','"death","role"')
tagtemplate=tagtemplate.replace('function service:_inside(_,p)return math.abs(p.X)<20 and math.abs(p.Z)<20 end','function service:_batInField(record)return math.abs(record.root.Position.X)<20 and math.abs(record.root.Position.Z)<20 end')
tagfile=folder/'Tests/TagDodgeBehavior.generated.luau'
tagfile.write_text(tagtemplate.replace('__SHARED__',shared),encoding='utf-8')
result=subprocess.run([str(runner),str(tagfile)],capture_output=True,text=True)
print('Exact merged Tag:',result.stdout,result.stderr)
raise SystemExit(result.returncode)
