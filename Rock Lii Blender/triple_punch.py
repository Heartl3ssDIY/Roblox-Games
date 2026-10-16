"""Create a review-only, full-body R6 triple-punch Action for Rock Lii.

Open Rock Lii R6.blend and call:
    action = create_triple_punch(bpy.data.objects["__Rock Lii_Armature"])

The 1.5-second right-left-right Taijutsu combo steps the matching foot into
each hit. The opposite hand stays in guard. The rigid R6 arm reaches forward
without an elbow bend or mesh stretching. Dust, impact strokes, and audio are
separate game effects. This script never saves or uploads an animation.
"""

from __future__ import annotations

import math

import bpy
from mathutils import Quaternion, Vector


ACTION_NAME = "Rock Lii | Triple Punch | Review"
ANIMATED_BONES = (
    "HumanoidRootPart", "Torso", "Head", "Right Arm", "Left Arm",
    "Right Leg", "Left Leg",
)
IMPACTS = (9, 20, 33)

# Angles are degrees about character/world axes. Positive arm pitch swings
# its rigid mesh toward Rock Lii's +Y front. Yaw aims slightly inward.
# frame, torso(pitch,yaw,roll), head(pitch,yaw), right arm(pitch,yaw),
# left arm(pitch,yaw), right leg(pitch,yaw), left leg(pitch,yaw),
# root displacement in world XYZ studs.
POSES = (
    (1,  (0, 0, 0),    (0, 0),  (0, 0),   (0, 0),    (0, 0),  (0, 0),  (0, 0, 0)),
    (4,  (-3, 0, 0),   (1, 0),  (32, 8),  (32, -8),  (3, 0),  (-3, 0), (0, 0, 0)),
    (6,  (2, -7, -2), (-1, 3), (8, -5),  (43, -9),  (23, 1), (-4, 0), (0.035, 0.015, 0.025)),
    (8,  (-4, 5, 1),   (2, -3), (70, 19), (44, -9),  (16, 1), (-5, 0), (0.045, 0.045, 0.015)),
    (9,  (-7, 9, 2),   (3, -4), (90, 28), (47, -9),  (18, 1), (-8, 0), (0.050, 0.060, 0)),
    (11, (-8, 10, 2),  (3, -5), (93, 30), (47, -9),  (19, 1), (-8, 0), (0.055, 0.065, 0)),
    (14, (-2, 2, 0),   (1, -1), (38, 10), (37, -8),  (6, 0),  (-2, 0), (0.015, 0.030, 0)),
    (17, (2, 7, 2),   (-1, -3),(43, 9),  (8, 5),    (-4, 0),(23, -1),(-0.035, 0.015, 0.025)),
    (19, (-4, -5, -1),(2, 3),  (44, 9),  (70, -19), (-5, 0),(16, -1),(-0.045, 0.045, 0.015)),
    (20, (-7, -9, -2),(3, 4),  (47, 9),  (90, -28), (-8, 0),(18, -1),(-0.050, 0.060, 0)),
    (22, (-8, -10, -2),(3, 5), (47, 9),  (93, -30), (-8, 0),(19, -1),(-0.055, 0.065, 0)),
    (25, (-2, -2, 0), (1, 1),  (37, 8),  (38, -10), (-2, 0),(6, 0), (-0.015, 0.030, 0)),
    (29, (3, -9, -2),(-1, 4),  (5, -7),  (45, -10), (25, 1),(-5, 0),(0.040, 0.020, 0.030)),
    (32, (-5, 7, 2),  (2, -3), (72, 21), (47, -10), (17, 1),(-6, 0),(0.050, 0.050, 0.015)),
    (33, (-9, 12, 3), (4, -5), (92, 32), (50, -11), (20, 1),(-9, 0),(0.055, 0.070, 0)),
    (35, (-10, 13, 3),(4, -6), (95, 34), (50, -11), (20, 1),(-9, 0),(0.060, 0.075, 0)),
    (39, (-3, 2, 0),  (1, -1), (38, 10), (37, -8),  (5, 0),(-2, 0),(0.020, 0.030, 0)),
    (46, (0, 0, 0),   (0, 0),  (0, 0),   (0, 0),    (0, 0),  (0, 0),  (0, 0, 0)),
)


def _world_turn(pitch: float, yaw: float, roll: float = 0.0) -> Quaternion:
    """Character-space turn; Rock Lii faces Blender +Y."""
    return (
        Quaternion((0.0, 0.0, 1.0), math.radians(yaw))
        @ Quaternion((1.0, 0.0, 0.0), math.radians(pitch))
        @ Quaternion((0.0, 1.0, 0.0), math.radians(roll))
    )


def _bone_local_turn(armature, bone_name, desired_world, torso_world):
    """Convert visible world turn into this imported R6 bone's local axes."""
    rest = armature.data.bones[bone_name].matrix_local.to_quaternion()
    parent_turn = Quaternion() if bone_name in ("HumanoidRootPart", "Torso") else torso_world
    return rest.inverted() @ parent_turn.inverted() @ desired_world @ rest


def create_triple_punch(armature: bpy.types.Object, fps: int = 30) -> bpy.types.Action:
    """Create the combo for inspection while keeping the source blend unsaved."""
    if armature is None or armature.type != "ARMATURE":
        raise TypeError("Pass the imported Rock Lii R6 armature")
    missing = [name for name in ANIMATED_BONES if name not in armature.pose.bones]
    if missing:
        raise ValueError(f"Missing R6 bones: {', '.join(missing)}")
    if not isinstance(fps, int) or fps < 24:
        raise ValueError("fps must be an integer of at least 24")

    def at(frame30: int) -> int:
        return 1 + round((frame30 - 1) * fps / 30)

    scene = bpy.context.scene
    scene.render.fps = fps
    scene.render.fps_base = 1.0
    scene.frame_start = 1
    scene.frame_end = at(46)  # 45 intervals / 30 fps = 1.5 seconds.

    armature.animation_data_create()
    action = bpy.data.actions.new(ACTION_NAME)
    action.use_fake_user = True
    slot = action.slots.new(armature.id_type, armature.name)
    armature.animation_data.action = action
    armature.animation_data.action_slot = slot
    action.use_frame_range = True
    action.frame_start = 1
    action.frame_end = at(46)
    action["unit"] = "Rock Lii"
    action["impact_frames"] = ", ".join(str(at(f)) for f in IMPACTS)
    action["status"] = "Review only: not uploaded to Roblox"

    root_rest = armature.data.bones["HumanoidRootPart"].matrix_local.to_quaternion()
    previous = {}
    for frame30, torso, head, right_arm, left_arm, right_leg, left_leg, root_shift in POSES:
        frame = at(frame30)
        torso_world = _world_turn(*torso)
        desired = {
            "HumanoidRootPart": Quaternion(),
            "Torso": torso_world,
            "Head": _world_turn(*head),
            "Right Arm": _world_turn(*right_arm),
            "Left Arm": _world_turn(*left_arm),
            "Right Leg": _world_turn(*right_leg),
            "Left Leg": _world_turn(*left_leg),
        }
        for name in ANIMATED_BONES:
            bone = armature.pose.bones[name]
            rotation = _bone_local_turn(armature, name, desired[name], torso_world)
            old = previous.get(name)
            if old is not None and old.dot(rotation) < 0.0:
                rotation.negate()
            bone.rotation_mode = "QUATERNION"
            bone.rotation_quaternion = rotation
            previous[name] = rotation.copy()
            bone.keyframe_insert("rotation_quaternion", frame=frame, group=name)

        # Subtle weight shift follows the stepping foot. Z lift on the swing
        # drops to zero at each contact, and all displacement resets at end.
        root = armature.pose.bones["HumanoidRootPart"]
        root.location = root_rest.inverted() @ Vector(root_shift)
        root.keyframe_insert("location", frame=frame, group="HumanoidRootPart")

    for layer in action.layers:
        for strip in layer.strips:
            for channelbag in strip.channelbags:
                for curve in channelbag.fcurves:
                    for key in curve.keyframe_points:
                        key.interpolation = "BEZIER"
                        key.handle_left_type = "AUTO_CLAMPED"
                        key.handle_right_type = "AUTO_CLAMPED"

    scene.frame_set(1)
    # R6 feet cannot bend at an ankle. Keep the lowest visible sole on the
    # starting floor as the rigid legs tilt, using only a small hip-height
    # correction. Gather the full motion before inserting extra root keys.
    feet = [obj for obj in bpy.data.objects if obj.type == "MESH" and any(
        constraint.type == "CHILD_OF" and constraint.target == armature
        and constraint.subtarget in ("Right Leg", "Left Leg")
        for constraint in obj.constraints
    )]
    if feet:
        def floor_height():
            graph = bpy.context.evaluated_depsgraph_get()
            return min((evaluated.matrix_world @ Vector(corner)).z
                       for obj in feet
                       for evaluated in [obj.evaluated_get(graph)]
                       for corner in evaluated.bound_box)

        floor = floor_height()
        corrections = []
        world_to_armature = armature.matrix_world.to_3x3().inverted()
        for frame in range(1, at(46) + 1):
            scene.frame_set(frame)
            lift = max(0.0, floor - floor_height())
            location = root.location.copy() + root_rest.inverted() @ (
                world_to_armature @ Vector((0.0, 0.0, lift))
            )
            corrections.append((frame, location))
        for frame, location in corrections:
            root.location = location
            root.keyframe_insert("location", frame=frame, group="HumanoidRootPart")
        scene.frame_set(1)
    return action
