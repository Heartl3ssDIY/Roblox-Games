# Marineford — Frozen Bay
A stylized fighting arena based on the supplied Marineford references. The pale frozen sea is the main play surface; the fortress, horseshoe harbour walls, cannons, ships and pressure ridges frame it.

## Files
- Marineford_Frozen_Bay.blend: final scene with 22 organized visual mesh pieces.
- Marineford_Frozen_Bay_Editable.blend: separate components for editing.
- exports/Marineford_Frozen_Bay_Roblox.fbx: visual geometry and embedded textures.
- exports/Marineford_Frozen_Bay_Collision.fbx: 47 separate collision proxies.
- textures/: 1024px color, normal and roughness atlases.
- previews/: overhead, fortress-facing and hero views.
- Configure_Arena.lua: optional helper for selected imported arena models.
- source/: construction and validation scripts, for reference.

## Layout
Blender uses Z up. The bay radius is 96 units; its flat visual surface is Z=0.065.
The central square X=-32..32, Y=-32..32 is reserved for fighting and is unobstructed.
Spawn markers are at (-18,0,0.03) and (18,0,0.03). They are layout references only.
The whole bay is traversable; the 64x64 area has no visible border. Ships and ice ridges are outside that area.

## Roblox import
Import both FBX files with identical axis, scale and origin settings. Do not independently centre each mesh, or individually rescale visual and collision sets.
Keep the 22 visual pieces separate and anchored, with CanCollide disabled.
Make all COL_ meshes invisible and anchored, with CanCollide enabled. Use Hull collision for the individual convex proxies. Do not merge the harbour wall pieces into one hull: that would fill the bay.
Match scale to a player avatar before placing the arena in the game; Blender units have not yet been verified as Studio studs.
The optional Configure_Arena helper acts only on selected models and their descendants.
If the importer does not reconnect textures, apply MF_ColorAtlas.png as the color map, MF_NormalAtlas.png as the normal map, and MF_RoughnessAtlas.png as the roughness map. Use the same UVs on every piece.

## Scope and validation
22 visual meshes, 66,956 triangles total, largest piece 11,984 triangles.
47 collision meshes. FBX files were reimported into Blender: mesh and triangle counts match, all visual meshes have UVs, all 3 atlases load, and no zero-area triangles were found.
Collision bounds leave the central 64x64 area clear.
Packed final color pixels were checked against the external texture after reopening the final Blender file.
Roblox Studio import, avatar scale, camera behaviour and play testing are pending.
Collision proxies cover the main ice floor, harbour walls, rear land, fortress and ships. Small decorative ice ridges, tower details, cannons and buildings are visual scenery; they do not have individual collision.
The front harbour entrance remains open. The surrounding ocean has no floor collision or ring-out logic.
No characters, combat scripts, slippery-ice physics, match logic, interiors or automatic spawns are included.
Lighting in the previews is a Blender presentation setup; tune game lighting in Studio.
