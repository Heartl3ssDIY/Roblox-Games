import bpy,json,time
from pathlib import Path
from mathutils import Vector
source=Path(r"C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\ACULobbyCitadel\exports\ImportReady_ScaleFixed_20260926\03_Civic_Branding_01.fbx")
out=Path(r"C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\ACULobbyCitadel\reviews\ScaleAudit20260926\blender_import_smoke.json")
bpy.ops.wm.read_factory_settings(use_empty=True)
started=time.perf_counter()
status=bpy.ops.import_scene.fbx(filepath=str(source),use_anim=False)
meshes=[ob for ob in bpy.context.scene.objects if ob.type=="MESH"]
assert "FINISHED" in status,status
assert len(meshes)==87,len(meshes)
points=[ob.matrix_world @ Vector(corner) for ob in meshes for corner in ob.bound_box]
bounds=[[min(v[i] for v in points) for i in range(3)],[max(v[i] for v in points) for i in range(3)]]
result={"passed":True,"source":str(source),"officialImporter":"Blender built-in import_scene.fbx","blenderVersion":bpy.app.version_string,"status":sorted(status),"expectedMeshCount":87,"actualMeshCount":len(meshes),"blenderWorldBounds":bounds,"elapsedSeconds":time.perf_counter()-started,"scope":"Binary-container smoke test only. Blender converts FBX centimeter metadata into Blender units; this is not a Roblox preview or Roblox scale validation.","modifiedSourceFiles":False,"blendSaved":False}
out.write_text(json.dumps(result,indent=2),encoding="utf8")
print("INDEPENDENT_FBX_IMPORT_SMOKE "+json.dumps(result),flush=True)

