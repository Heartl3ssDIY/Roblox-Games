"""Read-only audit of approved Drunken Fist root motion versus RBXMonkey export."""

import json
import pathlib
import sys
import zlib

import bpy


ROOT = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))
import rbxmonkey_addon
from rbxmonkey_addon.animation.sampling import serialize_animation_state
from rbxmonkey_addon.core.utils import cf_to_mat


def deg(a, b):
    return a.rotation_difference(b).angle * 180 / 3.141592653589793


rbxmonkey_addon.register()
a = bpy.data.objects["__Rock Lii_Armature"]
ad = a.animation_data
ad.use_nla = False
for track in ad.nla_tracks:
    track.mute = True
action = bpy.data.actions["Rock Lii - Drunken Fist (REVIEW)"]
ad.action = action
ad.action_slot = action.slots[0]
scene = bpy.context.scene
scene.render.fps = 30
scene.render.fps_base = 1
scene.frame_start, scene.frame_end = 0, 210
raw = json.loads(zlib.decompress((ROOT / "exports" / "rock_lii_drunken_fist.rbxanim").read_bytes()))
rest = None
previous_pose = None
previous_export = None
max_pose_step = (0, -1)
max_export_step = (0, -1)
held_export = {}
max_sparse_error = (0, -1, "")
for i in range(211):
    scene.frame_set(i)
    bone = a.pose.bones["HumanoidRootPart"]
    pose_q = bone.matrix.to_quaternion()
    state = serialize_animation_state(a)
    held_export.update({name: entry[0] for name, entry in raw["kfs"][i]["kf"].items()})
    for name in ("HumanoidRootPart", "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg"):
        if name not in raw["kfs"][i]["kf"]:
            direct = state.get(name, [0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1])
            error = max(abs(x - y) for x, y in zip(direct, held_export[name]))
            max_sparse_error = max(max_sparse_error, (error, i, name))
            if error > 0.0001:
                print("SPARSE_ERROR", i, name, error, "DIRECT", direct, "HELD", held_export[name])
    export_q = cf_to_mat(state["HumanoidRootPart"]).to_quaternion()
    recorded = raw["kfs"][i]["kf"].get("HumanoidRootPart")
    if recorded:
        raw_q = cf_to_mat(recorded[0]).to_quaternion()
        export_delta = deg(export_q, raw_q)
        if export_delta > 0.001:
            print("DIFFERENT_EXPORT_SAMPLE", i, export_delta)
    if previous_pose:
        pose_step = deg(previous_pose, pose_q)
        export_step = deg(previous_export, export_q)
        max_pose_step = max(max_pose_step, (pose_step, i))
        max_export_step = max(max_export_step, (export_step, i))
        if pose_step > 5 or export_step > 5 or 89 <= i <= 97:
            print("FRAME", i, "POSE_STEP", round(pose_step, 3), "EXPORT_STEP", round(export_step, 3),
                  "ROT_MODE", bone.rotation_mode,
                  "ROT_Q", [round(v, 6) for v in bone.rotation_quaternion],
                  "STATE_CF", [round(v, 6) for v in state["HumanoidRootPart"]])
    previous_pose = pose_q.copy()
    previous_export = export_q.copy()

print("MAX_POSE_STEP", max_pose_step)
print("MAX_EXPORT_STEP", max_export_step)
print("MAX_SPARSE_ERROR", max_sparse_error)
for layer in action.layers:
    for strip in layer.strips:
        for bag in strip.channelbags:
            if bag.slot_handle != action.slots[0].handle:
                continue
            for fc in bag.fcurves:
                if 'pose.bones["HumanoidRootPart"].rotation_quaternion' in fc.data_path:
                    print("ROOT_CURVE", fc.array_index,
                          [(round(k.co.x, 3), round(k.co.y, 6), k.interpolation)
                           for k in fc.keyframe_points if 80 <= k.co.x <= 105])
