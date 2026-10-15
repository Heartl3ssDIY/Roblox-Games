import bpy
import hashlib
import json
from pathlib import Path

root = Path(r"C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\StuckInTheMud20261003")
native = json.loads((root / "NativeMudGeometry.json").read_text(encoding="utf-8-sig"))
scene = bpy.data.scenes.get("PCMudNativePreview20261003")
assert scene is not None and scene.get("NativePartCount") == len(native["parts"]) == 1511
objects = [obj for obj in scene.objects if "RobloxName" in obj]
assert len(objects) == 1511 and scene.camera is not None
assert bpy.context.scene == scene
assert scene.render.resolution_x == 2048 and scene.render.resolution_y == 1152
assert scene.render.engine == "BLENDER_WORKBENCH"
by_name = {obj.name: obj for obj in objects}
for index, part in enumerate(native["parts"], 1):
    name, class_name, shape, size, cframe, rgb, transparency = part
    obj = by_name[f"PCMud_{index:04d}_{name}"]
    assert obj["RobloxName"] == name and obj["RobloxClass"] == class_name and obj["RobloxShape"] == shape
    assert list(obj["RobloxSize"]) == size and list(obj["RobloxCFrame"]) == cframe
    assert obj.type == "MESH" and obj.material_slots[0].material is not None
files = ("NativeMudGeometry.json", "NativeMudArena_IsolatedPreview.blend", "NativeMudArena_IsolatedWide.png")
hashes = {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in files}
report = {
    "nativeParts": len(objects),
    "sourcePropertiesMatched": len(objects),
    "activeScene": bpy.context.scene.name,
    "renderEngine": scene.render.engine,
    "resolution": [scene.render.resolution_x, scene.render.resolution_y],
    "isolatedVerificationProcess": bpy.app.background,
    "sha256": hashes,
}
(root / "NativeMudPreviewChecks.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print(json.dumps(report), flush=True)
