import bpy,bmesh
from mathutils import Matrix

def refine():
    scene=bpy.context.scene;rig=bpy.data.objects['Guku_MasterInstinct_R6']
    source=bpy.data.collections['CHARACTER - R6 body and clothing']
    backup=bpy.data.collections.new('SOURCE - editable muscle forms (hidden)')
    scene.collection.children.link(backup)
    skin=bpy.data.materials['MI_Muscle planes']
    groups={
        'Torso':['Torso core','pectoral','abdominal','oblique'],
        'Right Arm':['Right arm core','Right deltoid','Right bicep','Right forearm'],
        'Left Arm':['Left arm core','Left deltoid','Left bicep','Left forearm'],
    }
    out=[]
    for part,tokens in groups.items():
        originals=[o for o in source.objects if o.type=='MESH' and o.get('r6_part')==part and any(t in o.name for t in tokens)]
        copies=[]
        for o in originals:
            for mod in o.modifiers:
                if mod.type=='ARMATURE':mod.show_viewport=False
            dg=bpy.context.evaluated_depsgraph_get()
            data=bpy.data.meshes.new_from_object(o.evaluated_get(dg),depsgraph=dg)
            for mod in o.modifiers:
                if mod.type=='ARMATURE':mod.show_viewport=True
            bm=bmesh.new();bm.from_mesh(data)
            boundary=[e for e in bm.edges if e.is_boundary]
            if boundary:bmesh.ops.holes_fill(bm,edges=boundary,sides=0)
            bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
            bm.to_mesh(data);bm.free()
            n=bpy.data.objects.new('Union_piece',data);source.objects.link(n);n.matrix_world=o.matrix_world.copy()
            copies.append(n)
        for obj in bpy.context.selected_objects:obj.select_set(False)
        for obj in copies:obj.select_set(True)
        bpy.context.view_layer.objects.active=copies[0];bpy.ops.object.join()
        united=bpy.context.object;united.name='Sculpted '+part
        voxel=united.modifiers.new('Unified sculpt surface','REMESH');voxel.mode='VOXEL';voxel.voxel_size=.032;voxel.use_smooth_shade=True
        bpy.ops.object.modifier_apply(modifier=voxel.name)
        smooth=united.modifiers.new('Organic muscle transitions','SMOOTH');smooth.factor=.55;smooth.iterations=5
        bpy.ops.object.modifier_apply(modifier=smooth.name)
        dec=united.modifiers.new('Game mesh reduction','DECIMATE');dec.ratio=.32
        bpy.ops.object.modifier_apply(modifier=dec.name)
        united.data.materials.clear();united.data.materials.append(skin)
        for p in united.data.polygons:p.material_index=0;p.use_smooth=True
        united.vertex_groups.clear()
        g=united.vertex_groups.new(name=part);g.add(list(range(len(united.data.vertices))),1,'REPLACE')
        united.parent=rig;united['r6_part']=part
        a=united.modifiers.new('R6 rigid binding','ARMATURE');a.object=rig
        for original in originals:
            backup.objects.link(original);source.objects.unlink(original)
        out.append((part,len(united.data.vertices),len(united.data.polygons)))
    backup.hide_render=True;backup.hide_viewport=True
    return out
