# Mount Fujikasane — Final Selection arena

A stylized interpretation of the supplied Demon Slayer clearing references, expanded for combat.
Built in Blender 5.2.1. No downloaded third-party meshes.

## Files
- Fujikasane_Arena.blend: final scene, consolidated meshes, packed textures, cameras and evening lighting.
- Fujikasane_Arena_Editable.blend: component-level construction version.
- exports/Fujikasane_Arena_Roblox.fbx: 54 visual meshes, 341,767 triangles.
- exports/Fujikasane_Arena_Collision.fbx: 73 simplified collision meshes.
- textures/: shared color, normal and roughness maps.
- previews/: hero, approach and overhead images.
- Configure_Arena.lua: optional Studio command-bar helper for selected imported models.
- source/: construction scripts; local paths must be updated if moved.

## Layout
The central combat region is 64 × 64 Blender units, centred on the origin. The six main red posts frame a wider space approximately 76 units across and 86 units long. Two smaller ceremony posts stand at the back. Fifteen wisteria trees, angular rocks and two rear stair flights surround the clearing.

Blender marker empties identify the centre, team positions and board corners. These are not included in the mesh-only FBX.
Blender coordinates: centre (0, 0, 0.06); team A (0, -22, 0.06); team B (0, 22, 0.06); board corners (-32, -32, 0.06) and (32, 32, 0.06).

## Import preparation
Import the visual and collision FBX files using matching scale and transforms. Keep their relative positioning; do not centre the two imports independently. Adjust both together to match your game's unit scale.
Retain the FK_ and COL_ name prefixes. Select both imported models and run Configure_Arena.lua from the Studio command bar in Edit mode. The helper only changes matching parts inside the selection.

Visual FK_ parts should be anchored and noncollidable. COL_ parts should be anchored, invisible and collidable. Collisions cover the flat clearing, approach, stairs, posts, major rocks and trunks. The outer forest terrain is decorative and is not fully walkable.

The color atlas is embedded in the FBX and also supplied separately. The maps are FK_ColorAtlas.png, FK_NormalAtlas.png and FK_RoughnessAtlas.png; assign them to the corresponding SurfaceAppearance fields if needed after import. The Blender lighting and subtle flower emission are presentation settings and need separate adjustment in Studio.

## Verification and limits
The visual FBX was re-imported into Blender: all 54 meshes, all 341,767 triangles and all three loaded texture maps were verified. UVs are present and no zero-area triangles were found. No raised collision proxy overlaps the 64 × 64 combat region.
The flower and banner faces are explicitly two-sided geometry.
Studio import, gameplay collision behaviour and device performance have not yet been tested. This is a detailed environment with dense flower geometry; reduce foliage detail for lower-end devices if profiling requires it.
No characters, gameplay scripts, wind animation, sky environment or AI are included. Banner emblems are an original stylized floral interpretation.

## Reference direction
The user's four supplied screenshots were the primary layout and aesthetic references.
Additional visual reference:
- https://poggers.com/blogs/anime/demon-slayer-the-demon-slayer-corps
- https://note.com/yukiringo1230/n/n956431ec4ed3
- https://www.ogidera.com/fuji/

Construction scripts run in numerical order in a new scene. common.py is a shared helper, not a standalone scene builder. Hidden construction detail is excluded from export.
