# G-Blox Falcon — first Blender pet

Created through Blender MCP from the approved floating falcon reference.

## Files

- `GBlox_Falcon.blend`: editable model, materials, studio lighting and packed reference image. Active scene: `GBlox_Falcon_Reference`. The pre-existing scene was preserved.
- `GBlox_Falcon_Parts.fbx`: base geometry only, without optional glow meshes.
- `GBlox_Falcon_WithGlow.fbx`: same model with separate thruster/core/underlight meshes and emitter guides.
- `GBlox_Falcon_Preview.png`: rendered reference preview.
- `Roblox_Falcon_VFX.server.lua`: optional Roblox Neon and short movement-trail setup.
- `parts_manifest.json`: named parts, materials, triangle counts and topology checks.

## Recolouring and import

The complete model has 56 mesh objects, including five optional glow meshes. Every mesh has exactly one material. White armour, cyan panels, violet feathers, silver details, black eyes, highlights and yellow beak/insignia are separate geometry, with no baked colour texture. Parts in the same colour group share a Blender material; make the material single-user if recolouring just one part in Blender.

Import an FBX with Roblox Studio's 3D importer, keeping its parts separate rather than merging the model. Scale the complete model as one unit. This export is a static cosmetic pet, not a rig or follow system. Choose the head as the model's PrimaryPart and connect it to your existing pet-follow system. For a physics-driven pet, weld the parts to the head and use suitable non-colliding/massless settings.

Blender emission and lights do not become Roblox VFX through FBX. The optional Lua script creates Neon glow and two short trails after it is placed inside the imported Model. It removes SurfaceAppearance only from the explicitly named optional VFX meshes so Neon/Color can display. The trails show during movement; this is not a particle simulation or an animation rig. Change the script's cyan colour to recolour the effects.

No Roblox playtest or live-game import has been performed. Blender geometry and export checks are recorded in the manifest. Each mesh is closed/manifold; pieces deliberately overlap at armour joins and wing roots.
