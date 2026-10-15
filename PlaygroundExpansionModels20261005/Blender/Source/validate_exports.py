import bpy,sys,json,math,traceback
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'Source'))
from assetlib import checked_enum

def bbox(objects):
    points=[o.matrix_world@Vector(p) for o in objects for p in o.bound_box]
    return [max(p[i] for p in points)-min(p[i] for p in points) for i in range(3)]

def clear():
    for obj in list(bpy.data.objects):bpy.data.objects.remove(obj,do_unlink=True)

reports=[]
args=sys.argv[sys.argv.index('--')+1:] if '--'in sys.argv else []
for path in sorted(ROOT.glob('*/Metadata/*.json')):
    meta=json.loads(path.read_text(encoding='utf-8-sig'))
    if args and meta['id'] not in args and meta['category'] not in args:continue
    row={'id':meta['id'],'name':meta['name'],'checks':{},'errors':[]}
    try:
        for key in ['blend','fbx','texture','preview']:
            p=Path(meta[key]);row['checks'][key+'Exists']=p.is_file() and p.stat().st_size>100
            assert row['checks'][key+'Exists'],key+' missing'
        bpy.ops.wm.open_mainfile(filepath=meta['blend'])
        source=[o for o in bpy.data.objects if o.type=='MESH' and o.get('AssetId')==meta['id'] and not o.get('IsRobloxExport')]
        row['checks']['editableParts']=len(source)
        assert source and all(len(o.data.vertices)>0 for o in source)
        row['checks']['packedReference']=any(image.packed_file for image in bpy.data.images if image.source=='FILE')
        row['checks']['liveBevels']=sum(m.type=='BEVEL' for o in source for m in o.modifiers)
        for obj in source:
            assert all(math.isfinite(c) for v in obj.data.vertices for c in v.co),'Nonfinite coordinates'
        assert all('OneDrive/Roblox UI Assets' not in image.filepath.replace('\\','/') for image in bpy.data.images)
        row['checks']['localPaths']=True
        if meta['category']=='Pets':
            rigs=[o for o in bpy.data.objects if o.type=='ARMATURE']
            assert len(rigs)==1 and len(rigs[0].data.bones)>=2
            row['checks']['poseBones']=len(rigs[0].data.bones)
            assert all(o.vertex_groups and any(m.type=='ARMATURE' for m in o.modifiers) for o in source),'Unbound source mesh'
            rig=rigs[0]
            bpy.context.scene.frame_set(1);p1=rig.pose.bones['Body'].matrix.translation.copy()
            bpy.context.scene.frame_set(13);p2=rig.pose.bones['Body'].matrix.translation.copy()
            bpy.context.scene.frame_set(25);p3=rig.pose.bones['Body'].matrix.translation.copy()
            assert p2.z-p1.z>.05 and (p3-p1).length<1e-5,'Idle is not a closed vertical bounce'
            row['checks']['idleLoop']=True
        clear()
        bpy.ops.import_scene.fbx(filepath=meta['fbx'])
        meshes=[o for o in bpy.data.objects if o.type=='MESH']
        assert meshes,'FBX has no mesh'
        tris=[]
        for obj in meshes:
            obj.data.calc_loop_triangles();tris.append(len(obj.data.loop_triangles))
            assert obj.data.uv_layers and obj.data.materials,'FBX missing UV or material'
            assert all(t.area>1e-12 for t in obj.data.loop_triangles),'Degenerate FBX triangles'
        row['checks']['fbxMeshes']=len(meshes)
        row['checks']['fbxTriangles']=sum(tris)
        row['checks']['maxMeshTriangles']=max(tris)
        assert max(tris)<=20000,'Individual mesh triangle budget exceeded'
        bpy.context.scene.frame_set(1);bpy.context.view_layer.update()
        actual=bbox(meshes);expected=meta['exportDimensions']
        row['checks']['roundtripDimensions']=actual
        assert all(abs(a-b)<max(.03,b*.02) for a,b in zip(actual,expected)),f'FBX scale mismatch {actual} vs {expected}'
        if meta['category']=='Pets':
            assert any(o.type=='ARMATURE' for o in bpy.data.objects),'FBX rig missing'
            assert all(o.vertex_groups for o in meshes),'FBX skin weights missing'
            row['checks']['fbxRigged']=True
        row['checks']['fbxUVAndMaterials']=True
        row['passed']=True
    except Exception as e:
        row['passed']=False;row['errors'].append(str(e));traceback.print_exc()
    reports.append(row)
    print('VALIDATED',row['id'],row['passed'],flush=True)
target=ROOT/('Validation-'+(args[0] if args else 'All')+'.json')
target.write_text(json.dumps({'passed':all(x['passed'] for x in reports),'count':len(reports),'assets':reports},indent=2),encoding='utf-8')
print('VALIDATION_COMPLETE',target,flush=True)
