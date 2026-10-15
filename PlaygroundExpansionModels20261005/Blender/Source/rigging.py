import bpy
from mathutils import Vector
from assetlib import checked_enum

def rig_asset(a):
    specs=getattr(a,'rig_bones',None)
    if not specs:
        specs={'Root':{'head':(0,0,0),'tail':(0,0,.25)},'Body':{'head':(0,0,.25),'tail':(0,0,1),'parent':'Root'}}
    data=bpy.data.armatures.new(a.spec['id']+'_PoseBones')
    rig=bpy.data.objects.new(a.spec['id']+'_PetRig',data)
    a.collection.objects.link(rig)
    rig.parent=a.root
    bpy.ops.object.select_all(action=checked_enum(bpy.ops.object.select_all.get_rna_type(),'action','DESELECT'))
    rig.select_set(True);bpy.context.view_layer.objects.active=rig
    bpy.ops.object.mode_set(mode=checked_enum(bpy.ops.object.mode_set.get_rna_type(),'mode','EDIT'))
    for name,spec in specs.items():
        bone=data.edit_bones.new(name);bone.head=spec['head'];bone.tail=spec['tail']
        if (bone.tail-bone.head).length<.01:bone.tail.z+=.1
    for name,spec in specs.items():
        if spec.get('parent'):data.edit_bones[name].parent=data.edit_bones[spec['parent']]
    bpy.ops.object.mode_set(mode=checked_enum(bpy.ops.object.mode_set.get_rna_type(),'mode','OBJECT'))
    for obj in a.objects:
        bone=obj.get('RigBone','Body')
        if bone not in data.bones:bone='Body'
        obj['RigBone']=bone
        group=obj.vertex_groups.new(name=bone);group.add(list(range(len(obj.data.vertices))),1,'REPLACE')
        mod=obj.modifiers.new('Pet pose rig',checked_enum(bpy.types.Modifier,'type','ARMATURE'));mod.object=rig
    scene=bpy.context.scene;scene.frame_start=1;scene.frame_end=25;scene.render.fps=24
    for frame,z in [(1,0),(7,.065),(13,.12),(19,.065),(25,0)]:
        if 'Body' in rig.pose.bones:
            bone=rig.pose.bones['Body'];bone.location=bone.bone.matrix_local.to_3x3().inverted()@Vector((0,0,z));bone.keyframe_insert(data_path='location',frame=frame,group='Body')
        for name in ('Head','Tail','WingL','WingR'):
            bone=rig.pose.bones.get(name)
            if bone:
                bone.rotation_mode=checked_enum(bone,'rotation_mode','XYZ')
                bone.rotation_euler.y=(z/.12)*(.1 if name in ('WingL','WingR') else .045)*(-1 if name=='WingR' else 1)
                bone.keyframe_insert(data_path='rotation_euler',frame=frame,group=name)
    if rig.animation_data and rig.animation_data.action:rig.animation_data.action.name=a.spec['id']+'_JollyIdle'
    rig['LoopFrames']='1–25, 24fps; first and last poses match'
    rig.show_in_front=True
    a.rig=rig
    scene.frame_set(1)
