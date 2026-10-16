"""Review-only R6 choreography for Rock Lii's Drunken Fist.

Run this file in Blender's Text Editor, then call::

    action = create_drunken_fist(bpy.data.objects["__Rock Lii_Armature"])

The function creates a seven-second in-place Action on the imported R6
armature. It does not save the .blend, export an animation, or upload anything
to Roblox. Route timing is stored as Action metadata. Server-side gameplay
code must own the actual front/midline/backline travel, hit contacts, damage,
and seven-second invulnerability; an animation Action cannot enforce those.
"""

import math

import bpy
from mathutils import Quaternion, Vector


DURATION_SECONDS = 7.0
ACTION_NAME = "Rock Lii - Drunken Fist (REVIEW)"

# Timing guide for gameplay movement; the Action itself stays in place.
ROUTE_BEATS_SECONDS = (
    (0.0, "frontline_start"),
    (1.85, "midline_outbound"),
    (3.35, "backline"),
    (4.90, "midline_return"),
    (6.25, "frontline_return"),
    (DURATION_SECONDS, "neutral"),
)

CONTACT_BEATS_SECONDS = (1.45, 2.50, 3.48, 4.58, 5.48)
REQUIRED_BONES = (
    "HumanoidRootPart",
    "Torso",
    "Head",
    "Right Arm",
    "Left Arm",
    "Right Leg",
    "Left Leg",
)

# Measured from the imported arm meshes, shoulder pivot to the white wrist
# center in the neutral pose. The R6 bone tails are diagonally offset from the
# visible arms, so aiming bone.tail alone leaves the actual fists hanging.
WRIST_REST_VECTORS = {
    "Right Arm": Vector((0.5, 0.0, -1.5)),
    "Left Arm": Vector((-0.5, 0.0, -1.5)),
}


def _smoothstep(value):
    value = max(0.0, min(1.0, value))
    return value * value * (3.0 - 2.0 * value)


def _strike(seconds, beat, width=0.16):
    """A soft reach/withdrawal pulse; contact is decided in gameplay code."""
    offset = (seconds - beat) / width
    return math.exp(-0.5 * offset * offset)


def _set_rotation(pose_bone, pitch=0.0, roll=0.0, yaw=0.0):
    """Convert a character-facing turn into this imported bone's local axes."""
    rest = pose_bone.bone.matrix_local.to_quaternion()
    desired = (
        Quaternion((1.0, 0.0, 0.0), pitch)
        @ Quaternion((0.0, 1.0, 0.0), roll)
        @ Quaternion((0.0, 0.0, 1.0), yaw)
    )
    pose_bone.rotation_mode = "QUATERNION"
    pose_bone.rotation_quaternion = rest.inverted() @ desired @ rest


def _key_rotation(pose_bone, frame):
    pose_bone.keyframe_insert(data_path="rotation_quaternion", frame=frame)


def _aim_arm(pose_bone, wrist_rest_vector, desired_direction, extension):
    """Aim the visible R6 wrist, whose position differs from the bone tail."""
    rest_vector = wrist_rest_vector
    target = rest_vector.lerp(Vector(desired_direction), extension)
    turn = rest_vector.rotation_difference(target)
    rest = pose_bone.bone.matrix_local.to_quaternion()
    pose_bone.rotation_mode = "QUATERNION"
    pose_bone.rotation_quaternion = rest.inverted() @ turn @ rest


def create_drunken_fist(armature, fps=30):
    """Create and assign a seven-second, 30 fps R6 preview Action.

    The body staggers, guards, reaches with alternating fists, and makes a
    controlled full spin in place. At frame 210 (30 fps) it is visually
    neutral. Existing Actions are kept. The route beats in Action metadata
    tell gameplay code when to travel between the current enemy rows.
    """
    if armature is None or armature.type != "ARMATURE":
        raise TypeError("Pass the imported Rock Lii R6 armature object")
    if not isinstance(fps, int) or fps <= 0:
        raise ValueError("fps must be a positive integer")

    missing = [name for name in REQUIRED_BONES if name not in armature.pose.bones]
    if missing:
        raise ValueError(f"The armature is missing R6 bones: {', '.join(missing)}")

    scene = bpy.context.scene
    scene.render.fps = fps
    scene.frame_start = 0
    end_frame = round(DURATION_SECONDS * fps)
    scene.frame_end = end_frame

    # Blender 5.2 uses layered Actions with a slot for the animated object.
    action = bpy.data.actions.new(ACTION_NAME)
    action.use_fake_user = True
    slot = action.slots.new(id_type="OBJECT", name=armature.name)
    animation_data = armature.animation_data_create()
    animation_data.action = action
    animation_data.action_slot = slot

    action.use_frame_range = True
    action.frame_start = 0
    action.frame_end = end_frame

    action["review_only"] = True
    action["duration_seconds"] = DURATION_SECONDS
    action["route_beat_seconds"] = [t for t, _ in ROUTE_BEATS_SECONDS]
    action["route_beat_names"] = [name for _, name in ROUTE_BEATS_SECONDS]
    action["contact_beats_seconds"] = list(CONTACT_BEATS_SECONDS)
    action["gameplay_note"] = "Server controls path, per-contact 50 damage, and immunity."

    bones = {name: armature.pose.bones[name] for name in REQUIRED_BONES}
    root = bones["HumanoidRootPart"]

    # Six samples a second make the stagger readable while preserving the
    # wider, slow turning arc. Include the exact terminal frame explicitly.
    stride = max(1, round(fps / 6))
    frames = sorted(set(range(0, end_frame + 1, stride)) | {end_frame})
    for frame in frames:
        seconds = frame / fps
        envelope = max(0.0, math.sin(math.pi * seconds / DURATION_SECONDS))
        beat = 2.0 * math.pi * 1.18 * seconds
        # Keep translation out of the Action. Gameplay will choose the actual
        # route using the live enemy positions and move the model there.
        root.location = (0.0, 0.0, 0.0)
        root.keyframe_insert(data_path="location", frame=frame)

        # A complete 360-degree turn finishes at the frontline-return beat,
        # then holds the equivalent neutral quaternion through recovery.
        turn_fraction = _smoothstep(min(seconds / 6.25, 1.0))
        _set_rotation(root, yaw=2.0 * math.pi * turn_fraction)
        _key_rotation(root, frame)

        right_contact = sum(_strike(seconds, t) for t in CONTACT_BEATS_SECONDS[::2])
        left_contact = sum(_strike(seconds, t) for t in CONTACT_BEATS_SECONDS[1::2])
        right_contact = min(right_contact, 1.0)
        left_contact = min(left_contact, 1.0)

        # Raise the arms from rest in the opening half-second, keep them out
        # during the dance, then lower them over the final recovery beat.
        extension = _smoothstep(seconds / 0.55) * _smoothstep((DURATION_SECONDS - seconds) / 0.60)

        _set_rotation(
            bones["Torso"],
            pitch=envelope * (0.10 * math.sin(beat + 0.6) - 0.10 * (right_contact + left_contact)),
            roll=envelope * 0.18 * math.sin(beat * 0.5),
            yaw=envelope * 0.10 * math.sin(beat + 1.0),
        )
        _set_rotation(
            bones["Head"],
            pitch=envelope * (-0.06 * math.sin(beat + 0.6)),
            roll=envelope * (-0.12 * math.sin(beat * 0.5)),
            yaw=envelope * (-0.06 * math.sin(beat + 1.0)),
        )
        # Rock faces +Y. Aimed vectors keep both fists away from the torso;
        # contact pulses move one fist forward while the other stays extended.
        _aim_arm(
            bones["Right Arm"],
            WRIST_REST_VECTORS["Right Arm"],
            (
                1.10 - 0.48 * right_contact,
                0.62 + 0.72 * right_contact + 0.12 * math.sin(beat),
                0.12 + 0.10 * math.sin(beat + 0.6),
            ),
            extension,
        )
        _aim_arm(
            bones["Left Arm"],
            WRIST_REST_VECTORS["Left Arm"],
            (
                -0.92 + 0.30 * left_contact,
                0.52 + 0.82 * left_contact - 0.10 * math.sin(beat),
                -0.12 - 0.08 * math.sin(beat + 0.6),
            ),
            extension,
        )
        _set_rotation(
            bones["Right Leg"],
            pitch=envelope * (0.23 * math.sin(beat + 0.3)),
            roll=envelope * (-0.05 + 0.06 * math.sin(beat * 0.5)),
        )
        _set_rotation(
            bones["Left Leg"],
            pitch=envelope * (-0.23 * math.sin(beat + 0.3)),
            roll=envelope * (0.05 - 0.06 * math.sin(beat * 0.5)),
        )
        for name in REQUIRED_BONES[1:]:
            _key_rotation(bones[name], frame)

    scene.frame_set(0)
    return action
