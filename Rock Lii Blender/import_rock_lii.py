"""Import the exact live Studio RBXM into a clean Blender scene."""

import importlib
import pathlib
import sys
import time

import bpy


ROOT = pathlib.Path(__file__).resolve().parent
SOURCE = ROOT / "Rock Lii.rbxm"
OUTPUT = ROOT / "Rock Lii R6.blend"

# Keep any later animation work safe if this helper is run again.
if OUTPUT.exists():
    raise RuntimeError(f"Refusing to replace an existing Blender file: {OUTPUT}")

if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

addon = importlib.import_module("rbxmonkey_addon")
addon.register()

for obj in list(bpy.data.objects):
    bpy.data.objects.remove(obj, do_unlink=True)

started = time.monotonic()
result = bpy.ops.object.rbxanims_import_rbxm(filepath=str(SOURCE))
print("IMPORT_RESULT", result, "SECONDS", round(time.monotonic() - started, 2))

armatures = [obj for obj in bpy.data.objects if obj.type == "ARMATURE"]
meshes = [obj for obj in bpy.data.objects if obj.type == "MESH"]
print("ARMATURES", [(obj.name, [bone.name for bone in obj.data.bones]) for obj in armatures])
print("MESHES", [obj.name for obj in meshes])
print("IMAGES", [(img.name, img.size[:]) for img in bpy.data.images])

if result != {"FINISHED"} or len(armatures) != 1:
    raise RuntimeError("RBXM import did not produce exactly one armature")

for obj in bpy.context.selected_objects:
    obj.select_set(False)
armatures[0].select_set(True)
bpy.context.view_layer.objects.active = armatures[0]

try:
    bpy.ops.file.pack_all()
except Exception as exc:
    print("PACK_WARNING", repr(exc))

bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT), compress=True)
print("SAVED", str(OUTPUT), "BYTES", OUTPUT.stat().st_size)
