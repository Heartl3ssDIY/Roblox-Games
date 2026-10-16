"""Export the two approved Rock Lii Actions without changing the source blend.

Run with Blender 5.2 in background mode against Rock Lii Animations Review.blend::

    blender -b "Rock Lii Animations Review.blend" -P export_rock_lii_animations.py

The native .rbxanim files use RBXMonkey's exact zlib-compressed JSON format.
The adjacent .keyframes.json files carry the same Motor6D samples with only
HumanoidRootPart's motion transferred to the Torso RootJoint pose, ready for a
Roblox KeyframeSequence builder. Neither file is an animation asset ID. This script
never saves the source .blend, invokes Studio, or uploads anything.
"""

from __future__ import annotations

import copy
import hashlib
import json
import math
import pathlib
import sys
import zlib

import bpy
from mathutils import Matrix


ROOT = pathlib.Path(__file__).resolve().parent
SOURCE = ROOT / "Rock Lii Animations Review.blend"
OUTPUT = ROOT / "exports"
ARMATURE_NAME = "__Rock Lii_Armature"
R6_BONES = (
    "HumanoidRootPart", "Torso", "Head", "Right Arm", "Left Arm",
    "Right Leg", "Left Leg",
)
HIERARCHY = {
    "HumanoidRootPart": None,
    "Torso": "HumanoidRootPart",
    "Head": "Torso",
    "Right Arm": "Torso",
    "Left Arm": "Torso",
    "Right Leg": "Torso",
    "Left Leg": "Torso",
}
EXPORTS = (
    ("Rock Lii | Triple Punch | Review", "rock_lii_triple_punch", 1, 46, 1.5),
    ("Rock Lii - Drunken Fist (REVIEW)", "rock_lii_drunken_fist", 0, 210, 7.0),
)
IDENTITY = (0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0)


def _matrix(components):
    x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = components
    return Matrix((
        (r00, r01, r02, x),
        (r10, r11, r12, y),
        (r20, r21, r22, z),
        (0.0, 0.0, 0.0, 1.0),
    ))


def _components(matrix):
    return [
        float(matrix[0][3]), float(matrix[1][3]), float(matrix[2][3]),
        float(matrix[0][0]), float(matrix[0][1]), float(matrix[0][2]),
        float(matrix[1][0]), float(matrix[1][1]), float(matrix[1][2]),
        float(matrix[2][0]), float(matrix[2][1]), float(matrix[2][2]),
    ]


def _jsonable(value):
    if isinstance(value, dict):
        return {str(key): _jsonable(item) for key, item in value.items()}
    if isinstance(value, (str, int, float, bool)) or value is None:
        return value
    try:
        return [_jsonable(item) for item in value]
    except TypeError:
        return str(value)


def _correct_drunken_quaternion_crossing(root_motions):
    """Correct Blender's quaternion-component Bézier artifact at the 180° turn.

    The authored root keys at frames 90 and 95 represent adjacent orientations
    of the same smooth 360° spin, but their quaternion signs disagree. Blender
    independently interpolates the four components, yielding non-unit values
    and a 38° snap in frames 91–94. Preserve both authored keys exactly and
    interpolate only those four intermediate export samples by shortest path.
    """
    start_index, end_index = 90, 95
    begin = root_motions[start_index]
    end = root_motions[end_index]
    begin_q = begin.to_quaternion()
    end_q = end.to_quaternion()
    if sum(a * b for a, b in zip(begin_q, end_q)) < 0:
        end_q.negate()
    segment_degrees = math.degrees(begin_q.rotation_difference(end_q).angle)
    if not 8.0 < segment_degrees < 20.0:
        raise RuntimeError(f"Unexpected Drunken Fist 180-degree crossing: {segment_degrees}")
    for index in range(start_index + 1, end_index):
        factor = (index - start_index) / (end_index - start_index)
        q = begin_q.slerp(end_q, factor)
        matrix = q.to_matrix().to_4x4()
        matrix.translation = begin.to_translation().lerp(end.to_translation(), factor)
        root_motions[index] = matrix


def _motion_step_degrees(a, b):
    angle = math.degrees(a.to_quaternion().rotation_difference(b.to_quaternion()).angle)
    return min(angle, 360.0 - angle)


def _verify(payload, duration, expected_frames, complete_and_neutral):
    assert math.isclose(float(payload["t"]), duration, abs_tol=1e-6)
    keyframes = payload["kfs"]
    assert len(keyframes) == expected_frames, len(keyframes)
    assert math.isclose(float(keyframes[0]["t"]), 0.0, abs_tol=1e-6)
    assert math.isclose(float(keyframes[-1]["t"]), duration, abs_tol=1e-6)
    for frame in keyframes:
        names = set(frame["kf"])
        assert names <= set(R6_BONES) and (not complete_and_neutral or names == set(R6_BONES)), (
            frame["t"], frame["kf"].keys(),
        )
        for name, (components, style, direction) in frame["kf"].items():
            assert len(components) == 12, name
            assert all(math.isfinite(float(value)) for value in components), name
            assert style and direction
    if complete_and_neutral:
        for frame in (keyframes[0], keyframes[-1]):
            for name in R6_BONES:
                components = frame["kf"][name][0]
                assert max(abs(a - b) for a, b in zip(components, IDENTITY)) < 1e-3, (
                    frame["t"], name, components,
                )


def main():
    if pathlib.Path(bpy.data.filepath).resolve() != SOURCE.resolve():
        raise RuntimeError(f"Open the approved review blend first: {SOURCE}")
    if str(ROOT) not in sys.path:
        sys.path.insert(0, str(ROOT))
    import rbxmonkey_addon

    rbxmonkey_addon.register()
    from rbxmonkey_addon.animation.serialization import serialize, _analyze_export
    from rbxmonkey_addon.animation.sampling import serialize_animation_state
    from rbxmonkey_addon.core.utils import to_matrix

    armature = bpy.data.objects.get(ARMATURE_NAME)
    if armature is None or armature.type != "ARMATURE":
        raise RuntimeError(f"Missing approved R6 armature: {ARMATURE_NAME}")
    if tuple(sorted(b.name for b in armature.data.bones if b.get("rbx_joint_type") == "Motor6D")) != tuple(sorted(R6_BONES)):
        raise RuntimeError("Imported Motor6D hierarchy has changed")
    # These are the original Roblox RootJoint offsets stamped during RBXM import.
    # C0 conjugation preserves root spin/bob when moved into the Torso Pose.
    root_joint_c0 = to_matrix(armature.data.bones["Torso"].get("transform0"))
    root_joint_c0_inverse = root_joint_c0.inverted()

    scene = bpy.context.scene
    if scene not in armature.users_scene:
        raise RuntimeError("Armature does not belong to the active scene")
    scene.render.fps = 30
    scene.render.fps_base = 1.0
    scene.frame_step = 1
    armature.animation_data_create()
    armature.animation_data.use_nla = False  # The review scene combines both Actions in NLA.
    for track in armature.animation_data.nla_tracks:
        track.mute = True

    outputs = []
    planned_writes = []
    for action_name, stem, start, end, duration in EXPORTS:
        action = bpy.data.actions.get(action_name)
        if action is None or len(action.slots) != 1:
            raise RuntimeError(f"Missing or ambiguous approved Action: {action_name}")
        if abs(action.frame_range[0] - start) > 1e-5 or abs(action.frame_range[1] - end) > 1e-5:
            raise RuntimeError(f"Unexpected Action range for {action_name}")

        armature.animation_data.action = action
        armature.animation_data.action_slot = action.slots[0]
        scene.frame_start, scene.frame_end = start, end
        scene.frame_set(start)
        analysis = _analyze_export(armature, None)
        if analysis.is_skinned_rig or analysis.run_deform_path or analysis.use_nla_bake or analysis.action != action:
            raise RuntimeError(f"Not a clean Motor6D Action export: {action_name}")

        raw = serialize(armature)  # RBXMonkey's actual Motor6D serialization.
        _verify(raw, duration, end - start + 1, complete_and_neutral=False)

        # The RBXM was imported from a model placed far from world origin.
        # RBXMonkey's raw root sample retains that fixed placement. Roblox does
        # not evaluate root Pose motion for an ordinary R6 AnimationTrack, so
        # transfer the relative root movement to the Torso RootJoint pose.
        # A raw bone entry may be omitted by RBXMonkey's keyframe filtering.
        # Resample all seven joints directly with the same Motor6D sampler,
        # avoiding any ambiguity about whether omission meant hold or rest.
        ready = copy.deepcopy(raw)
        base = _matrix(raw["kfs"][0]["kf"]["HumanoidRootPart"][0])
        base_inverse = base.inverted()
        style_history = {}
        root_motions = []
        for index, frame in enumerate(ready["kfs"]):
            original_entries = frame["kf"]
            for name, entry in original_entries.items():
                style_history[name] = entry[1:3]
            scene.frame_set(start + index)
            sampled = serialize_animation_state(armature)
            complete = {}
            for name in R6_BONES:
                components = list(sampled.get(name, IDENTITY))
                if name in original_entries:
                    error = max(abs(a - b) for a, b in zip(components, original_entries[name][0]))
                    if error > 1e-5:
                        raise RuntimeError(f"Raw/direct sampler disagreement at {frame['t']}, {name}: {error}")
                complete[name] = [components, *style_history[name]]
            frame["kf"] = complete
            root_motion = base_inverse @ _matrix(frame["kf"]["HumanoidRootPart"][0])
            root_motions.append(root_motion)

        if stem == "rock_lii_drunken_fist":
            _correct_drunken_quaternion_crossing(root_motions)

        for frame, root_motion in zip(ready["kfs"], root_motions):
            torso_entry = frame["kf"]["Torso"]
            torso_entry[0] = _components(
                root_joint_c0_inverse @ root_motion @ root_joint_c0 @ _matrix(torso_entry[0])
            )
            frame["kf"]["HumanoidRootPart"][0] = list(IDENTITY)
        _verify(ready, duration, end - start + 1, complete_and_neutral=True)

        max_root_shift = max(motion.to_translation().length for motion in root_motions)
        max_root_turn = max(math.degrees(motion.to_quaternion().angle) for motion in root_motions)
        root_steps = [_motion_step_degrees(a, b) for a, b in zip(root_motions, root_motions[1:])]
        cumulative_root_turn = sum(root_steps)
        max_root_step = max(root_steps)
        if stem == "rock_lii_triple_punch" and max_root_shift < 0.03:
            raise RuntimeError("Triple Punch root footwork/ground correction did not export")
        if stem == "rock_lii_drunken_fist" and not (340 < cumulative_root_turn < 380 and max_root_step < 5):
            raise RuntimeError(f"Drunken Fist spin is not smooth: {cumulative_root_turn} degrees, {max_root_step} max step")

        raw_bytes = zlib.compress(json.dumps(raw, separators=(",", ":")).encode("utf-8"), 9)
        ready_bytes = json.dumps(ready, separators=(",", ":")).encode("utf-8")
        planned_writes.extend((
            (OUTPUT / f"{stem}.rbxanim", raw_bytes),
            (OUTPUT / f"{stem}.keyframes.json", ready_bytes),
        ))
        outputs.append({
            "name": action_name,
            "stem": stem,
            "duration_seconds": duration,
            "fps": 30,
            "frame_start": start,
            "frame_end": end,
            "keyframe_count": len(ready["kfs"]),
            "hierarchy": HIERARCHY,
            "max_root_shift_studs": max_root_shift,
            "max_root_turn_degrees": max_root_turn,
            "cumulative_root_turn_degrees": cumulative_root_turn,
            "max_root_step_degrees": max_root_step,
            "root_motion_folded_into": "Torso",
            "interpolation_correction": "Drunken Fist export frames 91-94 shortest-path quaternion interpolation between unchanged authored keys 90 and 95" if stem == "rock_lii_drunken_fist" else None,
            "root_joint_c0": _components(root_joint_c0),
            "raw_rbxanim": f"{stem}.rbxanim",
            "keyframe_sequence_input": f"{stem}.keyframes.json",
            "metadata": _jsonable(dict(action.items())),
        })
        print("EXPORTED", action_name, "seconds", duration, "frames", len(ready["kfs"]), "max_root_shift", round(max_root_shift, 5), "cumulative_root_turn", round(cumulative_root_turn, 2), "max_root_step", round(max_root_step, 2))

    manifest = {
        "schema": "rock-lii-r6-motor6d-export-v1",
        "source_blend": SOURCE.name,
        "source_sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        "format": {
            "rbxanim": "RBXMonkey native zlib-compressed JSON for provenance only; root retains source world placement and Drunken Fist retains Blender's quaternion sign artifact. Do not publish this file as a Roblox KeyframeSequence.",
            "keyframes_json": "Complete RBXMonkey Motor6D samples; root motion folded into Torso via imported RootJoint C0; HumanoidRootPart Pose is identity. Drunken Fist frames 91-94 correct Blender quaternion sign interpolation.",
            "pose_entry": "[12 CFrame floats (xyz then row-major 3x3), easingStyle, easingDirection]",
            "time_unit": "seconds",
            "root_hierarchy": HIERARCHY,
        },
        "animations": outputs,
    }
    planned_writes.append((OUTPUT / "manifest.json", json.dumps(manifest, indent=2).encode("utf-8")))
    OUTPUT.mkdir(exist_ok=True)
    for path, data in planned_writes:
        # Previous files in this directory may be staged in Studio. Replace
        # each one atomically so readers see the complete corrected payload.
        temporary = path.with_name(path.name + ".tmp")
        temporary.write_bytes(data)
        temporary.replace(path)
        print("SAVED", path, len(data), "bytes")


if __name__ == "__main__":
    main()
