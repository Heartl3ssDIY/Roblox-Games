import bpy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'Pets/Blend/p01-pocket-bulldog.blend'))
scene=bpy.context.scene
scene.render.engine='CYCLES'
scene.cycles.samples=48
scene.cycles.use_denoising=True
scene.render.filepath=str(ROOT/'Previews/Bulldog-render-check.png')
bpy.ops.render.render(write_still=True)
