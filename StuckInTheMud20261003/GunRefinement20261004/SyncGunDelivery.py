import hashlib
import json
import shutil
import struct
import zipfile
from pathlib import Path

root = Path(__file__).resolve().parent
canonical = root.parent
before = root / 'Before'
inspection = json.loads((root/'Inspection.json').read_text(encoding='utf-8'))
manifest = json.loads((root/'ExportManifest.json').read_text(encoding='utf-8'))
assert inspection['passed']

for name in ('gun-asset-validation.json','blender-asset-build.json'):
    source = canonical / name
    target = before / name
    if source.exists() and not target.exists():
        shutil.copy2(source,target)

for gun in ('MudGun','HeatGun'):
    assert (root/(gun+'.fbx')).read_bytes().startswith(b'Kaydara FBX Binary')
    assert (root/(gun+'.glb')).read_bytes()[:4] == b'glTF'
    for suffix in ('.fbx','.glb','_Preview.png'):
        shutil.copy2(root/(gun+suffix),canonical/(gun+suffix))
shutil.copy2(root/'MudHeatGun_Preview.png',canonical/'MudHeatGun_Preview.png')

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

report = {}
for gun in ('MudGun','HeatGun'):
    item = inspection['guns'][gun]
    data = (root/(gun+'.glb')).read_bytes()
    length,kind = struct.unpack_from('<II',data,12)
    gltf = json.loads(data[20:20+length])
    report[gun] = {'meshes':item['meshCount'],'triangles':item['triangleCount'],
        'largestMeshTriangles':manifest[gun]['largestMeshTriangles'],'gripOrigin':[0,0,0],
        'muzzleRoblox':[0,1,-2.65],'targetRobloxStudDimensions':item['dimensionsExport'],
        'fbxSha256':sha(canonical/(gun+'.fbx')),'glbSha256':sha(canonical/(gun+'.glb')),
        'embeddedMaterials':len(gltf.get('materials',[])),'externalAssets':0,
        'boundsExport':item['boundsExport']}
for name in ('MudHeatGuns.blend','MudHeatGun_Preview.png','MudGun_Preview.png','HeatGun_Preview.png'):
    path = canonical / name
    report[name] = {'bytes':path.stat().st_size,'sha256':sha(path)}
report['version'] = 2
report['exportGeometryInspected'] = True
report['visuallyReviewed'] = True
report['gameplayRun'] = False
report['robloxMeshImportPerformed'] = False
report['backup'] = str(before)
(root/'DeliveryReport.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
(canonical/'gun-asset-validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
for gun in ('MudGun','HeatGun'):
    manifest[gun]['fbx'] = str(canonical/(gun+'.fbx'))
    manifest[gun]['glb'] = str(canonical/(gun+'.glb'))
    manifest[gun]['fbxBytes'] = (canonical/(gun+'.fbx')).stat().st_size
    manifest[gun]['glbBytes'] = (canonical/(gun+'.glb')).stat().st_size
(canonical/'gun-export-manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
notes = (root/'DeliveryNotes.txt').read_text(encoding='utf-8')
(canonical/'GunAssetNotes.txt').write_text(notes,encoding='utf-8')
package = root/'MudHeatGuns_Refined.zip'
members = ['MudHeatGuns_Refined.blend','MudGun.fbx','HeatGun.fbx','MudGun.glb','HeatGun.glb',
           'MudHeatGun_Preview.png','MudGun_Preview.png','HeatGun_Preview.png','DeliveryNotes.txt','DeliveryReport.json']
with zipfile.ZipFile(package,'w',zipfile.ZIP_DEFLATED) as archive:
    for name in members:
        archive.write(root/name,name)
print(json.dumps({'package':str(package),'bytes':package.stat().st_size,'canonicalFilesRefreshed':True,'backup':str(before)}))
