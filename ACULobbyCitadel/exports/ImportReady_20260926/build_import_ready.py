"""Export-only import-friendly ACU lobby. Does not save or overwrite the master."""
import bpy, importlib.util, json, sys, time, re, hashlib, gc, ctypes
from pathlib import Path
from collections import defaultdict

ROOT=Path(r"C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\ACULobbyCitadel")
OUT=ROOT/"exports"/"ImportReady_20260926"
OUT.mkdir(parents=True,exist_ok=True)
spec=importlib.util.spec_from_file_location("acu_original_exporter",ROOT/"source"/"export_lobby.py")
base=importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)

class MemStatus(ctypes.Structure):
    _fields_=[("dwLength",ctypes.c_ulong),("dwMemoryLoad",ctypes.c_ulong),("ullTotalPhys",ctypes.c_ulonglong),("ullAvailPhys",ctypes.c_ulonglong),("ullTotalPageFile",ctypes.c_ulonglong),("ullAvailPageFile",ctypes.c_ulonglong),("ullTotalVirtual",ctypes.c_ulonglong),("ullAvailVirtual",ctypes.c_ulonglong),("ullAvailExtendedVirtual",ctypes.c_ulonglong)]
def memory_guard():
    ms=MemStatus();ms.dwLength=ctypes.sizeof(ms)
    ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(ms))
    if ms.ullAvailPhys<2*1024**3:
        raise RuntimeError("Stopped safely: less than 2 GiB physical memory available. Retry after Studio import finishes.")
    return round(ms.ullAvailPhys/1024**3,2)
def digest(path):
    h=hashlib.sha256()
    with open(path,"rb") as f:
        for block in iter(lambda:f.read(1024**2),b""):h.update(block)
    return h.hexdigest()
master=ROOT/"ACU_Festival_Citadel.blend"
master_hash=digest(master)
font_changes=[]
seen=set()
for ob in bpy.context.scene.objects:
    if ob.type!="FONT":continue
    cu=ob.data
    font_changes.append({"object":ob.name,"body":cu.body,"font":cu.font.name,"resolutionBefore":cu.resolution_u,"resolutionAfter":min(cu.resolution_u,4),"bevelResolutionBefore":cu.bevel_resolution,"bevelResolutionAfter":min(cu.bevel_resolution,1),"bevelDepthUnchanged":cu.bevel_depth,"extrusionUnchanged":cu.extrude,"matrixWorldUnchanged":[list(row) for row in ob.matrix_world]})
    if cu.as_pointer() not in seen:
        seen.add(cu.as_pointer())
        cu.resolution_u=min(cu.resolution_u,4)
        cu.bevel_resolution=min(cu.bevel_resolution,1)
        cu.render_resolution_u=cu.resolution_u
bpy.context.view_layer.update()
base.write_json(OUT/"text_optimization.json",font_changes)
original_collection=base.collection_name
def collection_name(ob):
    col=original_collection(ob)
    if col=="60_ArenaPortals":
        hit=re.match(r"Arena_(\d\d)_",ob.name)
        if hit:return "60_ArenaPortals_Gate_"+hit[1]
        hit=re.match(r"Grand_Arena_Torii_(\d\d)",ob.name)
        if hit:return "60_ArenaPortals_Torii_"+hit[1]
    return col
base.collection_name=collection_name

def district(col):
    if col.startswith("60_ArenaPortals_"):return "14_"+col
    if col=="60_ArenaPortals":return "14_Arena_Promenade"
    if col in ("10_Island","50_ExpandedLand"):return "01_Landscape"
    if col.startswith(("11_","12_","13_","14_","15_","51_OuterRoads","52_GrandArrival","55_","70_","71_")):return "02_Plaza_Paths_Arrival"
    if col.startswith(("16_","17_","20_","21_","72_")):return "03_Civic_Branding"
    if col.startswith("30_"):return "04_Story_Gate"
    if col.startswith("31_"):return "05_Summon_Hall"
    if col.startswith("32_"):return "06_Ranked_Hall"
    if col.startswith("33_"):return "07_Champions_Court"
    if col.startswith(("34_","35_")):return "08_Shop_NPC_Stations"
    if col.startswith(("37_","54_")):return "09_Market_Street"
    if col.startswith("51_Academy"):return "10_Academy"
    if col.startswith("52_Celestial"):return "11_Celestial_Pagoda"
    if col.startswith("50_City"):return "12_City_Buildings"
    if col.startswith(("53_","36_")):return "13_Fortress_Backdrop"
    if col.startswith("61_"):return "15_Waterfall_Ravine"
    if col.startswith(("60_Outer","62_","63_")):return "16_Outer_Gardens_Forests"
    return "17_Inner_Gardens_Training"

ex=base.Exporter(OUT,9000,48)
objects=[ob for ob in bpy.context.scene.objects if ob.type in base.SOURCE_TYPES and not base.excluded(ob)]
objects.sort(key=lambda ob:(collection_name(ob),ob.name))
source_type_triangles=defaultdict(int)
seen_materials=set()
for ob in objects:
    for slot in ob.material_slots:
        mat=slot.material
        if mat is not None and mat.name not in seen_materials:
            ex.get_material(mat,ob);seen_materials.add(mat.name)
bpy.context.view_layer.update()
depsgraph=bpy.context.evaluated_depsgraph_get()
previous=None
started=time.perf_counter()
print("IMPORT_READY_BEGIN "+str(len(objects))+" objects; free GiB "+str(memory_guard()),flush=True)
for i,ob in enumerate(objects):
    col=collection_name(ob)
    if previous is not None and col!=previous:
        for key in [k for k in ex.buckets if k[0]==previous]:ex.flush(key)
    previous=col
    before=ex.source_triangles
    ex.process_object(ob,i,depsgraph)
    source_type_triangles[ob.type]+=ex.source_triangles-before
    if (i+1)%750==0:
        print("GEOMETRY "+str(i+1)+"/"+str(len(objects))+" freeGiB="+str(memory_guard()),flush=True)
for key in list(ex.buckets):ex.flush(key)
for evaluated in ex.evaluated_temporaries:evaluated.to_mesh_clear()
ex.evaluated_temporaries.clear()
gc.collect()
memory_guard()
ex.materialize_export_objects()
ex.refresh_atlases()
assert len(ex.mesh_records)==len(ex.objects)
assert all(r["triangles"]<=9000 for r in ex.mesh_records)
records_by_name={r["name"]:r for r in ex.mesh_records}
grouped=defaultdict(list)
for ob in ex.objects:grouped[district(ob["ACU_Collection"])].append(ob)
fbx=ex.operator("export_scene.fbx","io_scene_fbx")
assert fbx is not None,"FBX exporter unavailable"
outputs=[]
def write_batch(label,items,index):
    memory_guard()
    bpy.ops.object.select_all(action="DESELECT")
    for ob in items:ob.hide_set(False);ob.select_set(True)
    bpy.context.view_layer.objects.active=items[0]
    path=OUT/(label+"_"+str(index).zfill(2)+".fbx")
    assert not path.exists(),"Refusing to overwrite existing batch "+str(path)
    ex.call_operator(fbx,dict(filepath=str(path),use_selection=True,object_types={"MESH"},
        global_scale=1.0,apply_unit_scale=False,apply_scale_options="FBX_SCALE_NONE",
        axis_forward="-Z",axis_up="Y",use_space_transform=True,bake_space_transform=True,
        use_mesh_modifiers=False,mesh_smooth_type="FACE",use_tspace=False,
        bake_anim=False,use_custom_props=True,path_mode="RELATIVE",embed_textures=False,
        add_leaf_bones=False))
    assert path.is_file() and path.stat().st_size>256
    assert path.stat().st_size<=50*1024**2,"Batch over 50 MiB; split it before delivering"
    rows=[records_by_name[ob.name] for ob in items]
    outputs.append({"file":path.name,"bytes":path.stat().st_size,"meshes":len(items),"triangles":sum(r["triangles"] for r in rows),"collections":sorted(set(r["collection"] for r in rows)),"meshNames":[ob.name for ob in items],"sha256":digest(path)})
    print("BATCH "+path.name+" "+str(path.stat().st_size)+" bytes",flush=True)

for label,items in sorted(grouped.items()):
    items.sort(key=lambda ob:ob.name)
    current=[];tris=0;index=1
    for ob in items:
        n=int(ob["ACU_TriangleCount"])
        if current and (len(current)>=250 or tris+n>250000):
            write_batch(label,current,index);index+=1;current=[];tris=0
        current.append(ob);tris+=n
    if current:write_batch(label,current,index)
old=json.loads((ROOT/"exports"/"export_manifest.json").read_text(encoding="utf-8"))
marker_data=ex.markers()
base.write_json(OUT/"markers.json",marker_data)
import shutil
for filename in ("ACU_Citadel_Collision.fbx","collision_manifest.json"):
    shutil.copy2(ROOT/"exports"/filename,OUT/filename)
texture_checks=[]
for path in sorted(ex.tex_dir.iterdir()):
    if path.is_file():
        oldpath=ROOT/"exports"/"textures"/path.name
        texture_checks.append({"file":"textures/"+path.name,"bytes":path.stat().st_size,"sha256":digest(path),"identicalToPreviousExport":oldpath.is_file() and digest(oldpath)==digest(path)})
assert all(t["identicalToPreviousExport"] for t in texture_checks),"Texture bytes changed"
assert digest(master)==master_hash,"Master file unexpectedly changed"
triangles=sum(r["triangles"] for r in ex.mesh_records)
manifest={
    "sourceBlend":str(master),"sourceMasterSHA256":master_hash,"sourceMasterUnchanged":True,"editableBlendSaved":False,
    "generatedUtc":base.datetime.datetime.now(base.datetime.timezone.utc).isoformat(),"blenderVersion":bpy.app.version_string,
    "fontPolicy":"Same Permanent Marker font, text, matrices, bevel depth, extrusion; only FONT sampling resolution reduced from12/4 to4/1 in background session.",
    "sceneryDecimationApplied":False,"sourceNormalsPreserved":True,"sourceObjects":len(objects),
    "textObjectsOptimized":len(font_changes),"sourceTrianglesByObjectType":dict(source_type_triangles),
    "before":{"triangles":old["triangles"],"meshes":old["exportMeshes"],"fbxBytes":(ROOT/"exports"/"ACU_Citadel_Roblox.fbx").stat().st_size},
    "after":{"triangles":triangles,"meshes":len(ex.mesh_records),"fbxBatches":len(outputs),"fbxBytes":sum(r["bytes"] for r in outputs),"maximumBatchBytes":max(r["bytes"] for r in outputs)},
    "maximumMeshTriangles":max(r["triangles"] for r in ex.mesh_records),"triangleLimit":9000,
    "sourceTrianglesBeforeCleanup":ex.source_triangles,"zeroAreaTrianglesRemoved":ex.removed_faces,
    "coordinateConversion":"Blender (X,Y,Z) -> Roblox (X,Z,-Y), same world origin for every batch; unitScale1",
    "PBRMaterials":ex.material_maps,"paletteTexture":"textures/ACU_Palette_1024x512.png","textures":texture_checks,
    "exportOnlyUVProjections":ex.uv_projection_fallbacks,"warnings":sorted(set(ex.warnings)),
    "batches":outputs,"meshes":ex.mesh_records}
base.write_json(OUT/"import_manifest.json",manifest)
notes="""ACU FESTIVAL CITADEL - SMALLER IMPORT BATCHES

Keep every .fbx beside the textures folder. Import the numbered visual FBXs, one batch at a time.
Import settings: Scale Unit Studs; scale1; Merge Meshes OFF; Insert Using Scene Position ON; Set Pivot to Scene Origin ON; Anchored ON.
Every batch uses the original shared origin. Do not individually center/reposition batches. Move their common parent model after assembly if needed.
Avoid importing these batches on top of a completed original lobby, which would duplicate it.

The original .blend, original FBX/GLB and full-size delivery are untouched.
Only FONT curve tessellation and bevel subdivision were simplified in an isolated export session. The same Permanent Marker font, exact strings, text locations, extrusion and physical bevel depth are retained.
Scenery dimensions, architecture, materials, 24 texture images, UV coordinates and original shading are preserved. Textures have byte-for-byte checks in import_manifest.json.
Each mesh stays at or below9,000 triangles. All batches are below50MiB. File sizes here are packaging targets, not claimed Roblox importer limits.
The visual FBXs use shared external textures instead of embedding a copy in every batch. Missing PBR channels can be assigned through SurfaceAppearance from PBRMaterials in import_manifest.json.

Visual meshes: CanCollide false. Import ACU_Citadel_Collision.fbx separately as the collision proxy; hide its visual appearance. The proxy is unchanged and still needs walk testing.
Set DoubleSided true only for flagged meshes in import_manifest.json.
markers.json contains unchanged interaction anchors; no game logic has been wired.

This variant has been checked as export files. Actual Studio import and runtime performance still need validation.
"""
notes+="\nBEFORE: "+str(old["triangles"])+" triangles / "+str(old["exportMeshes"])+" meshes\n"
notes+="AFTER: "+str(triangles)+" triangles / "+str(len(ex.mesh_records))+" meshes / "+str(len(outputs))+" batches\n"
notes+="Triangle reduction: "+str(round((1-triangles/old["triangles"])*100,2))+"%\n"
(OUT/"START_HERE.txt").write_text(notes,encoding="utf-8")
print("IMPORT_READY_COMPLETE "+json.dumps(manifest["after"])+" durationSeconds="+str(round(time.perf_counter()-started,1)),flush=True)

