import bpy,bmesh,json,math,traceback,sys
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
results=[]
targets=sys.argv[sys.argv.index('--')+1:]if'--'in sys.argv else[]
for meta in sorted(ROOT.glob('*/Metadata/*.json')):
    r=json.loads(meta.read_text());checks={};issues=[]
    if targets and r['id']not in targets:continue
    for o in list(bpy.data.objects):bpy.data.objects.remove(o,do_unlink=True)
    bpy.ops.import_scene.fbx(filepath=r['fbx'],use_anim=False)
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    tris=0;boundary=0;nonmanifold=0;zeroarea=0;uvbad=0;texture_missing=[]
    for obj in meshes:
        me=obj.data;me.calc_loop_triangles();tris+=len(me.loop_triangles)
        if len(me.loop_triangles)>20000:issues.append('Mesh over 20,000 triangles: '+obj.name)
        if any(not math.isfinite(c)for v in me.vertices for c in v.co):issues.append('Nonfinite coordinates')
        bm=bmesh.new();bm.from_mesh(me)
        boundary+=sum(e.is_boundary for e in bm.edges)
        nonmanifold+=sum(not e.is_manifold for e in bm.edges)
        zeroarea+=sum(f.calc_area()<1e-10 for f in bm.faces)
        bm.free()
        if not me.uv_layers:uvbad+=1
        else:
            uv=me.uv_layers.active.data
            for p in me.polygons:
                a,b,c=(uv[li].uv for li in p.loop_indices[:3])
                if abs((b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x))<1e-10:uvbad+=1
        for mat in me.materials:
            images=[n.image for n in mat.node_tree.nodes if n.type=='TEX_IMAGE' and n.image]if mat and mat.use_nodes else[]
            if not images:texture_missing.append(obj.name)
            for im in images:
                if not im.packed_file and not Path(bpy.path.abspath(im.filepath)).is_file():texture_missing.append(im.name)
    points=[o.matrix_world@Vector(v)for o in meshes for v in o.bound_box]
    dims=[max(p[i]for p in points)-min(p[i]for p in points)for i in range(3)]if points else[]
    if not meshes:issues.append('No meshes imported')
    if tris!=r['triangles']:issues.append('Triangle count changed')
    if 'exportDimensions'in r and max(abs(a-b)for a,b in zip(dims,r['exportDimensions']))>1e-4:issues.append('Export dimensions changed during roundtrip')
    if boundary:issues.append('Boundary edges: '+str(boundary))
    if nonmanifold:issues.append('Nonmanifold edges: '+str(nonmanifold))
    if zeroarea:issues.append('Zero-area faces: '+str(zeroarea))
    if uvbad:issues.append('Missing or collapsed UVs: '+str(uvbad))
    if texture_missing:issues.append('Missing textures: '+str(texture_missing))
    result={'id':r['id'],'meshes':len(meshes),'triangles':tris,'boundaryEdges':boundary,'nonmanifoldEdges':nonmanifold,'degenerateFaces':zeroarea,'badUVs':uvbad,'dimensions':dims,'issues':issues,'pass':not issues}
    results.append(result);print('FBX_AUDIT '+json.dumps(result),flush=True)
report_path=ROOT/'Source'/'FBX-validation.json'
if targets and report_path.exists():
    previous={r['id']:r for r in json.loads(report_path.read_text())}
    previous.update({r['id']:r for r in results})
    report_path.write_text(json.dumps(sorted(previous.values(),key=lambda r:r['id']),indent=2))
else:report_path.write_text(json.dumps(results,indent=2))
print('AUDIT_COMPLETE',len(results),'FAILURES',sum(not r['pass']for r in results),flush=True)
