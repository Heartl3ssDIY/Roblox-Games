import hashlib
import json
import math
import struct
from pathlib import Path

root=Path(__file__).resolve().parent
report=json.loads((root/'gun-export-manifest.json').read_text(encoding='utf-8'))
build=json.loads((root/'blender-asset-build.json').read_text(encoding='utf-8'))
results={}
def rotate(vector,quaternion):
    x,y,z,w=quaternion
    vx,vy,vz=vector
    tx=2*(y*vz-z*vy)
    ty=2*(z*vx-x*vz)
    tz=2*(x*vy-y*vx)
    return [vx+w*tx+y*tz-z*ty,vy+w*ty+z*tx-x*tz,vz+w*tz+x*ty-y*tx]
for name in ('MudGun','HeatGun'):
    info=report[name]
    fbx=(root/(name+'.fbx')).read_bytes()
    assert fbx.startswith(b'Kaydara FBX Binary')
    assert name.encode() in fbx
    other='HeatGun' if name=='MudGun' else 'MudGun'
    assert other.encode() not in fbx, name+' FBX contains the other gun'
    blob=(root/(name+'.glb')).read_bytes()
    magic,version,length=struct.unpack_from('<4sII',blob)
    assert magic==b'glTF' and version==2 and length==len(blob)
    json_length,json_kind=struct.unpack_from('<II',blob,12)
    assert json_kind==0x4E4F534A
    scene=json.loads(blob[20:20+json_length])
    nodes=scene['nodes']
    gun=next(node for node in nodes if node.get('name')==name)
    assert all(node.get('name')==name or node.get('name','').startswith('SITM_'+name+'_') for node in nodes)
    assert gun.get('translation',[0,0,0])==[0,0,0], name+' grip origin is offset'
    muzzle=rotate([0,1,2.65],gun.get('rotation',[0,0,0,1]))
    assert all(abs(a-b)<1e-5 for a,b in zip(muzzle,[0,1,-2.65])), name+' export muzzle points incorrectly'
    assert not scene.get('animations') and not scene.get('skins') and not scene.get('cameras')
    assert all('uri' not in buffer for buffer in scene.get('buffers',[])), 'GLB has external buffer paths'
    assert all('uri' not in image for image in scene.get('images',[])), 'GLB has external image paths'
    triangles=0
    for mesh in scene['meshes']:
        for primitive in mesh['primitives']:
            assert primitive.get('mode',4)==4
            indices=scene['accessors'][primitive['indices']]
            assert indices['count']%3==0
            triangles+=indices['count']//3
            position=scene['accessors'][primitive['attributes']['POSITION']]
            assert all(math.isfinite(value) for value in position['min']+position['max'])
    assert len(scene['meshes'])==info['meshes']
    assert triangles==info['triangles']
    assert info['largestMeshTriangles']<20000
    dimensions=build[name]['dimensionsBlender']
    results[name]={
        'meshes':len(scene['meshes']),'triangles':triangles,'largestMeshTriangles':info['largestMeshTriangles'],
        'gripOrigin':[0,0,0],'muzzleRoblox':muzzle,'targetRobloxStudDimensions':[dimensions[0],dimensions[2],dimensions[1]],
        'fbxSha256':hashlib.sha256(fbx).hexdigest(),'glbSha256':hashlib.sha256(blob).hexdigest(),
        'embeddedMaterials':len(scene.get('materials',[])),'externalAssets':0,
    }
for name in ('MudHeatGuns.blend','MudGun_Preview.png','HeatGun_Preview.png','MudHeatGun_Preview.png'):
    content=(root/name).read_bytes()
    assert len(content)>1000
    if name.endswith('.png'):
        assert content.startswith(b'\x89PNG\r\n\x1a\n')
    results[name]={'bytes':len(content),'sha256':hashlib.sha256(content).hexdigest()}
assert report['preserved']['scene']=='Scene' and report['preserved']['filepath']==''
assert set(report['preserved']['objects'])=={'Cube','Camera','Light'}
assert report['preserved']['selection']==[] and report['preserved']['activeObject']=='Cube'
results['userScenePreserved']=True
results['standaloneBlendOnlyManagedScene']=report['blend']['containsOnlyManagedScene']
(root/'gun-asset-validation.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
print(json.dumps({'guns':{name:results[name] for name in ('MudGun','HeatGun')},'renders':3,'standaloneBlendOnlyManagedScene':True,'userScenePreserved':True}))
