# Jujutsu High — Training Courtyard

A stylized interpretation of the supplied Jujutsu High campus references, arranged around a clear courtyard for arena combat. Includes timber and shoji halls, grey tiled roofs, a five-storey pagoda, tall rear campus building, entrance gate, boundary walls, stone lanterns, training posts and 34 trees.

## Files
- Jujutsu_High.blend: final scene, organized into 29 visual mesh pieces.
- Jujutsu_High_Editable.blend: separate components for editing.
- exports/Jujutsu_High_Roblox.fbx: visual meshes with embedded texture maps.
- exports/Jujutsu_High_Collision.fbx: 54 separate collision proxies.
- textures/: 1024px color, normal and roughness atlases.
- previews/: hero, courtyard and overhead images.
- Configure_Arena.lua: optional helper for selected imported arena models.
- source/: construction and validation scripts for reference.

## Layout
The sand court is 80 x 116 Blender units, with surface Z=0.05.
The central X=-32..32, Y=-32..32 square is clear of raised obstacles.
Spawn layout markers are at (-18,0,0.05) and (18,0,0.05). These are reference empties, not automatic gameplay spawns.
Blender uses Z up. Match model scale against a player avatar after importing; Studio stud scale has not been tested.

## Import
Import both FBX files with identical scale, axis and origin settings. Preserve their shared alignment; do not independently centre or scale individual pieces.
Keep the visual meshes anchored with CanCollide disabled.
Set COL_ meshes to anchored, invisible and collidable. Each proxy is convex and intended for Hull collision. Keep the proxies separate.
The optional helper only changes selected objects and their descendants with JH_ or COL_ name prefixes.
If maps are not connected automatically, use JH_ColorAtlas.png as the color map, JH_NormalAtlas.png as the normal map and JH_RoughnessAtlas.png as the roughness map on the existing UVs.

## Checks and scope
29 visual meshes, 143,512 triangles total; largest piece 12,000 triangles.
54 collision meshes. FBX round-trip validation in Blender passed: counts match, all visual meshes have UVs, all three maps load, and no zero-area triangles were found.
The collision bounds audit found no obstructions in the central 64 x 64 area.
Final packed texture pixels were compared with the supplied PNG files after reopening the Blender scene.
Roblox Studio import, avatar scale, collision behaviour, camera clearance and play testing remain pending.
The collision set covers the court, ground, raised rear terrace, major buildings, walls, entrance posts, lanterns and tree trunks.
Small training posts, shrubs, roof tiles and decorative stairs do not have separate collision. Building interiors are not playable.
No characters, match logic, combat scripts or automatic spawns are included.
The campus arrangement is adapted for fighting and is not a measured reconstruction of a particular episode shot.
Blender lighting is for the previews; adjust game lighting in Studio.
