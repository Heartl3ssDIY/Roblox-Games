import bpy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'Miscellaneous/Blend/c01-collectible-coin.blend'))
# Standard is confirmed in this Blender installation's active OCIO configuration.
bpy.context.scene.view_settings.view_transform='Standard'
bpy.context.scene.view_settings.exposure=-.2
bpy.context.scene.render.filepath=str(ROOT/'Previews/Coin-colour-check.png')
bpy.ops.render.render(write_still=True)
