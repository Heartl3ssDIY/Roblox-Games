"""Build local review Actions from the imported Rock Lii R6 rig.

Run this in a separate Blender process with ``Rock Lii R6.blend`` loaded.
It creates a new review .blend and never exports or uploads to Roblox.
"""

from pathlib import Path
import sys

import bpy


ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "Rock Lii R6.blend"
OUTPUT = ROOT / "Rock Lii Animations Review.blend"

if Path(bpy.data.filepath).resolve() != SOURCE.resolve():
    raise RuntimeError(f"Open the source file first: {SOURCE}")
if OUTPUT.exists():
    raise RuntimeError(f"Refusing to replace an existing review file: {OUTPUT}")

sys.path.insert(0, str(ROOT))
from triple_punch import create_triple_punch  # noqa: E402
from drunken_fist import create_drunken_fist  # noqa: E402

armature = bpy.data.objects["__Rock Lii_Armature"]
punch = create_triple_punch(armature, fps=30)
drunken = create_drunken_fist(armature, fps=30)

for action in (punch, drunken):
    action.use_fake_user = True
    if len(action.slots) != 1 or not action.layers:
        raise RuntimeError(f"Action has no usable armature keys: {action.name}")

# Leave the shorter attack ready to play when the review file is opened.
armature.animation_data.action = punch
armature.animation_data.action_slot = punch.slots[0]
bpy.context.scene.render.fps = 30
bpy.context.scene.frame_start = 1
bpy.context.scene.frame_end = 46
bpy.context.scene.frame_set(1)

print("REVIEW_ACTIONS", [(action.name, list(action.frame_range)) for action in (punch, drunken)])
print("SCENE_ACTION_COUNT", len(bpy.data.actions))
bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT), compress=True)
print("REVIEW_SAVED", str(OUTPUT), OUTPUT.stat().st_size)
