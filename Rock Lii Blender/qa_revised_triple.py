"""Independent, unsaved mesh QA of the revised Rock Lii triple punch."""

import math
from pathlib import Path
import sys
from types import SimpleNamespace
import uuid

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "Rock Lii R6.blend"
if Path(bpy.data.filepath).resolve() != SOURCE.resolve():
    raise RuntimeError(f"Open the base rig first: {SOURCE}")
sys.path.insert(0, str(ROOT))

from triple_punch import create_triple_punch  # noqa: E402
import render_animation_previews as preview  # noqa: E402


rig = bpy.data.objects["__Rock Lii_Armature"]
action = create_triple_punch(rig, fps=30)
scene = bpy.context.scene
parts = {
    name: bpy.data.objects[f"Rock Lii.model/{name}.Part"]
    for name in ("Right Arm", "Left Arm", "Right Leg", "Left Leg")
}


def wrist_indices(obj):
    low = min(v.co.z for v in obj.data.vertices)
    return [v.index for v in obj.data.vertices if v.co.z <= low + 0.01]


ends = {name: wrist_indices(obj) for name, obj in parts.items()}
records = {}
angles = {"Right Arm": [], "Left Arm": []}
previous_directions = {}

for frame in range(1, 47):
    scene.frame_set(frame)
    depsgraph = bpy.context.evaluated_depsgraph_get()
    values = {}
    for name, obj in parts.items():
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        try:
            points = [evaluated.matrix_world @ vertex.co for vertex in mesh.vertices]
        finally:
            evaluated.to_mesh_clear()
        bottom = min(point.z for point in points)
        if name.endswith("Leg"):
            # Track the same original sole cap vertices even when a pitched
            # foot's back edge becomes its lowest point.
            foot = sum((points[index] for index in ends[name]), Vector()) / len(ends[name])
            values[name] = {"bottom_z": bottom, "foot_y": foot.y}
        else:
            wrist = sum((points[index] for index in ends[name]), Vector()) / len(ends[name])
            values[name] = {"wrist": wrist}
            bone = rig.pose.bones[name]
            direction = (bone.tail - bone.head).normalized()
            if name in previous_directions:
                angles[name].append((frame - 1, frame, math.degrees(previous_directions[name].angle(direction))))
            previous_directions[name] = direction
    records[frame] = values

ground = min(records[1][name]["bottom_z"] for name in ("Right Leg", "Left Leg"))
print("GROUND_REFERENCE_Z", round(ground, 4))
for frame, strike in ((9, "Right Arm"), (20, "Left Arm"), (33, "Right Arm")):
    rec = records[frame]
    wrist_y = rec[strike]["wrist"].y
    neutral_y = records[1][strike]["wrist"].y
    feet = tuple(
        (name, round(rec[name]["foot_y"] - records[1][name]["foot_y"], 3),
         round(rec[name]["bottom_z"] - ground, 3))
        for name in ("Right Leg", "Left Leg")
    )
    print("HIT", frame, strike, "WRIST_FORWARD_Y", round(wrist_y - neutral_y, 3), "FEET_Y_Z", feet)

floating = [
    frame for frame, rec in records.items()
    if min(rec["Right Leg"]["bottom_z"], rec["Left Leg"]["bottom_z"]) > ground + 0.10
]
deep = [
    frame for frame, rec in records.items()
    if min(rec["Right Leg"]["bottom_z"], rec["Left Leg"]["bottom_z"]) < ground - 0.10
]
print("FLOATING_BOTH_FEET_FRAMES", floating)
print("DEEP_GROUND_PENETRATION_FRAMES", deep)
for name, transitions in angles.items():
    print("LARGEST_ARM_TURNS", name, sorted(transitions, key=lambda row: row[2], reverse=True)[:5])

meshes = preview.rig_meshes(rig)
minimum, maximum = preview.fit_bounds(scene, meshes, 1, 46, 46)
center, span = preview.add_camera(scene, minimum, maximum, 1)
preview.add_stage(scene, center, span, minimum, True)
preview.configure_render(scene, SimpleNamespace(engine="workbench", width=640, height=640, fps=30))
output = ROOT / "previews" / f"Triple Punch Revised QA {uuid.uuid4().hex[:6]}"
output.mkdir(parents=True, exist_ok=False)
scene.render.image_settings.file_format = "PNG"
for frame in (1, 6, 9, 14, 17, 20, 25, 29, 33, 39, 46):
    scene.frame_set(frame)
    scene.render.filepath = str(output / f"frame_{frame:04d}.png")
    bpy.ops.render.render(write_still=True)
print("QA_PNG_DIR", output)
print("SOURCE_NOT_SAVED", SOURCE)
