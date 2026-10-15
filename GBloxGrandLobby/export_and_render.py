import bpy, os, json
from mathutils import Vector
OUT=os.path.dirname(os.path.abspath(__file__))
s=bpy.context.scene
# Export architecture only: no default-scene cube, Blender lights or cameras.
bpy.ops.object.select_all(action='DESELECT')
for o in s.objects:
    if o.type in {'MESH','FONT'}: o.select_set(True)
bpy.ops.export_scene.fbx(filepath=os.path.join(OUT,"G-Blox_Gravity_Hall.fbx"),use_selection=True,object_types={'MESH','OTHER'},use_mesh_modifiers=True,add_leaf_bones=False,bake_anim=False,axis_forward='-Z',axis_up='Y')
deps=bpy.context.evaluated_depsgraph_get()
triangles=0
for o in s.objects:
    if o.type in {'MESH','FONT'}:
        e=o.evaluated_get(deps)
        mesh=e.to_mesh()
        mesh.calc_loop_triangles()
        triangles+=len(mesh.loop_triangles)
        e.to_mesh_clear()
report={"scene":s.name,"objects":len(s.objects),"evaluated_triangles":triangles,
        "floor_dimensions":[round(v,5) for v in s.objects["FLOOR_Main_288.343x200.132"].dimensions],
        "roof_visible":not bpy.data.collections["03 Roof - hide for placement"].hide_render}
print("VALIDATION",json.dumps(report))
for cam,file in [("CAM_01_Interior","01_Gravity_Hall_Interior.png"),("CAM_02_Entrance","02_Entrance_View.png"),("CAM_03_Obby","03_Practice_Obby.png")]:
    s.camera=s.objects[cam]
    s.render.filepath=os.path.join(OUT,file)
    bpy.ops.render.render(write_still=True)
# Cutaway preview only. Main .blend stays saved with all walls and roof present.
bpy.data.collections["03 Roof - hide for placement"].hide_render=True
for o in s.objects:
    if o.name.startswith(("SHELL_Endwall","WALL_Entrance")) and o.location.y<0:
        o.hide_render=True
    if o.name.startswith("EMIT_Entrance"): o.hide_render=True
    if o.location.x>130 and o.name.startswith(('SHELL_Sidewall','WALL_','EMIT_Wall')): o.hide_render=True
s.camera=s.objects["CAM_04_Layout"]
s.render.filepath=os.path.join(OUT,"04_Layout_Cutaway.png")
bpy.ops.render.render(write_still=True)
print("EXPORT_AND_RENDERS_COMPLETE")
