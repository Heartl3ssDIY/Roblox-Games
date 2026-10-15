# Loguetown Arena — Anime Combat Units

A stylized, original Blender interpretation of the supplied Loguetown references, arranged as a playable town-square arena. The design combines the anime plaza with a waterfront entrance and keeps the main landmarks outside the combat area.

## Included
- Loguetown_Arena.blend: consolidated, editable scene with packed textures and three cameras.
- Loguetown_Arena_Editable.blend: component-level construction version for moving and editing individual details.
- exports/Loguetown_Arena_Roblox.fbx: 28 visual mesh modules.
- exports/Loguetown_Arena_Collision.fbx: 38 simplified collision meshes.
- textures: color, normal and roughness maps.
- previews: final hero, entrance and overhead views.
- source: modeling and verification scripts.
- Configure_Arena.lua: optional setup helper for selected imported models in Studio.

Before_Loguetown.blend preserves the previous Blender scene and is excluded from the delivery package.

## Layout
The stone town square has an unobstructed 64 x 64 combat area, centered on Blender (0,0,0.12). Its bounds are X -32 to 32 and Y -32 to 32. Team markers are at (0,-22,0.12) and (0,22,0.12). The narrow gold paving border sits just outside these bounds.

Roger's execution platform stands at the rear, in front of the domed civic hall. Two fountains, eight pastel shop buildings, market stalls, trees, street lamps and benches surround the square. Waterfront stairs lead through the Loguetown sign into the plaza. The docks and water complete the entrance view.

This is a static arena environment. Fountain streams and water are modeled surfaces; there is no water animation, climbing behavior, AI, combat logic or building interior.

## Roblox import
Use the same intended scale as the previous arenas: 1 Blender unit to 1 Roblox stud. Import both FBX files at the same origin and scale. Verify the marked combat area measures 64 x 64 studs. Blender Z becomes Roblox Y.

Anchor all visual LT_ meshes and disable their collision. Use the separate COL_ meshes as invisible collision surfaces, with Hull collision fidelity. The optional Configure_Arena.lua helper operates only on LT_ and COL_ parts within the selected imports.

The collision set covers the plaza, waterfront quay, entrance steps and landing, building shells, fountains, gate columns, retaining walls, docks and scaffold posts/deck. Small props and foliage are decorative. The 64 x 64 combat area was checked for collision obstructions and is clear.

Set up lighting and sky separately in Roblox; Blender lights, cameras and the presentation world are not included in the mesh-only FBX.

## Validation
28 visual meshes, 97,456 triangles total; largest module 7,600 triangles. UVs are present on every visual mesh. Export/re-import preserved the mesh count, triangle count and all three texture maps. No zero-area triangles were found. Detailed reports are in exports/mesh_report.json and exports/validation.json.

The model has not yet been imported or performance-tested in Roblox Studio.

## References
Primary visual direction came from the four images supplied in this task: the anime plaza, the illustrated map, the waterfront entrance model and the paired-fountain square model. These were used as references, not imported geometry.

Additional visual reference search:
- [Loguetown plaza screenshot](https://tr.onepiece.wikia.com/wiki/Loguetown)
- [Loguetown manga plaza reference](https://opwiki.org/wiki?filetimestamp=20140201211718&title=Datei%3ALoguetown_Colo.jpg)

All delivered mesh geometry and texture atlases were constructed for this task. No third-party model was downloaded or included.

## Source scripts
For regeneration in an empty Blender session, update the local ROOT and source paths if necessary, then run source/01_architecture.py through source/05_validate_and_render.py in order. Keep backups before rerunning into a populated scene; scripts use deterministic object names.
