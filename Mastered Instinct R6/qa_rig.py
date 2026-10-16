import bpy,math,json,pathlib
from mathutils import Vector

def run():
    scene=bpy.context.scene;rig=bpy.data.objects['Guku_MasterInstinct_R6']
    active=[]
    for name in ['CHARACTER - R6 body and clothing','HAIR - silver swept spikes']:
        active += [o for o in bpy.data.collections[name].objects if o.type=='MESH']
    failures=[];parts={};vertices=0
    for o in active:
        expected=o.get('r6_part');parts[expected]=parts.get(expected,0)+1
        bind=[m for m in o.modifiers if m.type=='ARMATURE' and m.object==rig]
        if len(bind)!=1:failures.append(o.name+': missing or duplicate rig modifier')
        for v in o.data.vertices:
            weights=[(o.vertex_groups[g.group].name,g.weight) for g in v.groups if g.weight>.00001]
            if len(weights)!=1 or weights[0][0]!=expected or abs(weights[0][1]-1)>.00001:
                failures.append(o.name+': incorrect rigid vertex weight');break
        vertices+=len(o.data.vertices)
    saved={b.name:b.matrix_basis.copy() for b in rig.pose.bones}
    action=rig.animation_data.action if rig.animation_data else None
    if rig.animation_data:rig.animation_data.action=None
    for b in rig.pose.bones:b.matrix_basis.identity()
    bpy.context.view_layer.update()
    def samples():
        dg=bpy.context.evaluated_depsgraph_get();out={}
        for o in active:
            e=o.evaluated_get(dg);me=e.to_mesh()
            ids=sorted(set([0,len(me.vertices)//3,len(me.vertices)//2,len(me.vertices)-1]))
            out[o.name]=[o.matrix_world@me.vertices[i].co for i in ids]
            e.to_mesh_clear()
        return out
    neutral=samples();max_error=0;tests=[]
    for name in ['Head','Left Arm','Right Arm','Left Leg','Right Leg','Torso']:
        b=rig.pose.bones[name];b.rotation_euler=(math.radians(25),math.radians(12),math.radians(8))
        bpy.context.view_layer.update();posed=samples()
        moved=0
        for o in active:
            part=o.get('r6_part');pb=rig.pose.bones[part]
            transform=rig.matrix_world@pb.matrix@rig.data.bones[part].matrix_local.inverted()@rig.matrix_world.inverted()
            for a,actual in zip(neutral[o.name],posed[o.name]):
                err=(transform@a-actual).length;max_error=max(max_error,err)
                if err>.0005:failures.append(o.name+': pose mismatch '+name);break
            if (posed[o.name][0]-neutral[o.name][0]).length>.0001:moved+=1
        tests.append({'bone':name,'moved_meshes':moved})
        b.matrix_basis.identity();bpy.context.view_layer.update()
    for b in rig.pose.bones:b.matrix_basis=saved[b.name]
    if action:rig.animation_data.action=action
    scene.frame_set(1);bpy.context.view_layer.update()
    aura=bpy.data.objects['Aura_CTRL']
    if any(o.parent==aura for o in active):failures.append('Character improperly parented to aura')
    triangles=0
    dg=bpy.context.evaluated_depsgraph_get()
    for o in active:
        e=o.evaluated_get(dg);me=e.to_mesh();triangles+=sum(len(p.vertices)-2 for p in me.polygons);e.to_mesh_clear()
    report={'passed':not failures,'failures':failures,'bones':list(rig.data.bones.keys()),'rigged_meshes':len(active),'base_vertices':vertices,'evaluated_character_triangles':triangles,'meshes_by_body_part':parts,'independent_pose_checks':tests,'max_rigid_binding_error':max_error,'aura_children':len(aura.children),'aura_independent':True}
    path=pathlib.Path(bpy.data.filepath).parent/'rig_validation.json';path.write_text(json.dumps(report,indent=2))
    return report
