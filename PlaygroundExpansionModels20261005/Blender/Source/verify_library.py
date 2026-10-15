import bpy,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'Playground-Classics-Expansion-Library.blend'))
manifest=json.loads((ROOT/'Asset-Manifest.json').read_text())
assert len(manifest)==35
assert len([o for o in bpy.data.objects if o.type=='ARMATURE'])==15
for row in manifest:
    roots=[o for o in bpy.data.objects if o.type=='EMPTY' and o.get('id')==row['id']]
    assert len(roots)==1,row['id']
    parts=[o for o in bpy.data.objects if o.type=='MESH' and o.get('AssetId')==row['id']]
    assert len(parts)==row['parts'],row['id']
    if row['rigged']:
        rigs=[o for o in bpy.data.objects if o.type=='ARMATURE' and o.parent==roots[0]]
        assert len(rigs)==1 and rigs[0].animation_data.action,row['id']
        assert all(any(m.type=='ARMATURE' and m.object==rigs[0] for m in o.modifiers) for o in parts),row['id']
category_reports=[json.loads((ROOT/f'Validation-{category}.json').read_text()) for category in ['Bats','Miscellaneous','Pets']]
assert all(r['passed'] for r in category_reports)
assert sum(r['count'] for r in category_reports)==35
report={'passed':True,'models':35,'riggedPets':15,'editableParts':sum(r['parts'] for r in manifest),'totalTriangles':sum(r['triangles'] for r in manifest),'maxMeshTriangles':max(r['maxMeshTriangles'] for r in manifest),'sourceAndExportChecks':category_reports,'libraryVerified':True,'robloxPlayTested':False}
(ROOT/'Delivery-Validation.json').write_text(json.dumps(report,indent=2))
print('LIBRARY_VERIFIED',json.dumps({k:v for k,v in report.items() if k!='sourceAndExportChecks'}),flush=True)
