import bpy,bmesh,json
from pathlib import Path
ROOT=Path(r"C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\ACULobbyCitadel\exports\ImportReady_ScaleFixed_20260926")
for ob in list(bpy.data.objects):bpy.data.objects.remove(ob,do_unlink=True)
bpy.ops.mesh.primitive_cube_add(size=10,location=(0,0,0))
ob=bpy.context.object;ob.name="ACU_10_STUD_CALIBRATION_CUBE"
bm=bmesh.new();bm.from_mesh(ob.data);bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(ob.data);bm.free()
kwargs=dict(filepath=str(ROOT/"00_SCALE_CHECK_10_STUDS.fbx"),use_selection=True,object_types={"MESH"},global_scale=.01,apply_unit_scale=False,apply_scale_options="FBX_SCALE_NONE",axis_forward="-Z",axis_up="Y",use_space_transform=True,bake_space_transform=True,use_mesh_modifiers=False,mesh_smooth_type="FACE",use_tspace=False,bake_anim=False,use_custom_props=True,path_mode="RELATIVE",embed_textures=False,add_leaf_bones=False)
allowed=set(bpy.ops.export_scene.fbx.get_rna_type().properties.keys())
assert all(k in allowed for k in kwargs)
assert not Path(kwargs["filepath"]).exists()
bpy.ops.export_scene.fbx(**kwargs)
(ROOT/"calibration_export_settings.json").write_text(json.dumps({"expectedSizeStuds":[10,10,10],"settings":{k:sorted(v) if isinstance(v,set) else v for k,v in kwargs.items()}},indent=2))
print("CALIBRATION_EXPORTED")

