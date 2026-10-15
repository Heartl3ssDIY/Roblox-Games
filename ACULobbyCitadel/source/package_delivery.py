from pathlib import Path
import ast, json, zipfile
ROOT=Path(__file__).resolve().parent.parent
required=[ROOT/'ACU_Festival_Citadel.blend',ROOT/'README.md']
required += [ROOT/'exports'/name for name in ('ACU_Citadel_Roblox.fbx','ACU_Citadel_Roblox.glb','ACU_Citadel_Collision.fbx','export_manifest.json','collision_manifest.json','markers.json','IMPORT_README.txt')]
required += [ROOT/'previews'/name for name in ('01_Civic_Court.png','02_Complete_City.png','03_Merchant_Street.png','04_Waterfall_Garden.png','05_Celestial_Pagoda.png','06_Grand_Entrance.png','07_Moon_Garden.png','08_Festival_Night.png')]
if len([p for p in required if p.parent.name=='previews']) != 8:raise RuntimeError('Expected eight final renders')
for p in required:
    if not p.is_file() or p.stat().st_size==0:raise RuntimeError('Missing delivery file: '+str(p))
manifest=json.loads((ROOT/'exports'/'export_manifest.json').read_text())
if manifest.get('exportFailures'):raise RuntimeError('Export failures remain')
files=set(required)
files.update((ROOT/'source').glob('*.py'))
files.update(p for p in (ROOT/'references').iterdir() if p.is_file())
files.update(p for p in (ROOT/'textures').iterdir() if p.is_file())
for stmt in ast.parse((ROOT/'source'/'texture_pass.py').read_text(encoding='utf-8-sig')).body:
    if isinstance(stmt,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='SPECS' for t in stmt.targets):specs=ast.literal_eval(stmt.value)
for asset in {value[0] for value in specs.values()}:
    for channel in ('Color','Normal','Roughness'):files.add(ROOT/'textures'/'PBR'/(asset+'_'+channel+'.jpg'))
files.add(ROOT/'textures'/'PBR'/'sources.json')
files.update(p for p in (ROOT/'exports'/'textures').iterdir() if p.is_file())
target=ROOT/'ACU_Festival_Citadel_Delivery.zip'
temporary=target.with_suffix('.zip.tmp')
with zipfile.ZipFile(temporary,'w',zipfile.ZIP_DEFLATED,compresslevel=5) as archive:
    for path in sorted(files):archive.write(path,path.relative_to(ROOT).as_posix())
with zipfile.ZipFile(temporary) as archive:
    bad=archive.testzip()
    if bad:raise RuntimeError('Archive failed CRC check: '+bad)
temporary.replace(target)
print(json.dumps({'package':str(target),'files':len(files),'bytes':target.stat().st_size,'crcCheck':'passed'}),flush=True)

