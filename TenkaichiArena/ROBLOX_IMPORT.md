# Tenkaichi tropical arena

Bright Dragon Ball tournament environment for a Roblox fighting/card game. Includes a tiled ring, temple, sculpted guardian reliefs, three spectator galleries, annexes, palms, banners, parasols, landscaping and small grounds props. No characters, animations, attack effects or game logic are included yet.

## Files

- `Tenkaichi_Arena.blend`: finished scene, organized into editable environment modules; this is the version open in Blender.
- `Tenkaichi_Arena_Editable.blend`: construction version with individual components and foliage reduction modifiers.
- `exports/Tenkaichi_Arena_Roblox.fbx`: assembled visual environment; 32 meshes, 160,698 triangles total, largest mesh 14,000 triangles.
- `exports/Tenkaichi_Collision.fbx`: 36 simple collision boxes for the ground, ring, walkway, temple floor, stand tiers and access steps. Walls and decorative architecture are not included in this floor-oriented collision set.
- `textures/Arena_ColorAtlas.png`: 2048px color map shared by all visual meshes.
- `textures/Arena_NormalAtlas.png`: 2048px tangent-space normal map.
- `textures/Arena_RoughnessAtlas.png`: 2048px roughness map.
- `previews/`: full arena, front view and temple detail images.
- `exports/mesh_report.json` and `exports/fbx_validation.json`: geometry and FBX round-trip checks.
- `Configure_Arena.lua`: optional Studio Command Bar helper for anchoring the imported models and configuring the supplied collisions.

## Import into Roblox Studio

1. Use Studio's 3D importer to import `exports/Tenkaichi_Arena_Roblox.fbx` as one Model containing separate meshes.
2. Enable **Insert Using Scene Position**. Set **Scale Unit** to **Stud**. Keep the same position, scale and orientation settings when importing the collision FBX. The files were exported with FBX Unit Scale, Z Forward and Y Up, following the current Creator Hub Blender guidance.
3. Check scale before accepting: the square tiled fighting surface is **64 x 64 studs**, the outer platform is about **64.55 x 64.55 studs**, and the ground footprint is **158 x 154 studs**. If your importer version handles FBX unit metadata differently, correct the import scale using those measurements. Apply the identical adjustment to both files.
4. Check the embedded color, normal and roughness textures. If Studio only picks up the color map, upload the three PNGs and assign them to the `ColorMap`, `NormalMap` and `RoughnessMap` of a SurfaceAppearance on each visual MeshPart. Use the same maps for every visual mesh and a white part color. No metalness map is required.
5. Import `Tenkaichi_Collision.fbx` using the same settings. Do not reposition the two imports separately. The collider names start with `COL_`.
6. Select both imported Models. Optionally paste the contents of `Configure_Arena.lua` into Studio's Command Bar. It anchors the selected parts, turns visual mesh collisions off, and makes the collision boxes invisible and solid. The helper has not been executed in Studio in this session.
7. Group the visual and collision Models into one arena Model before moving or scaling the environment. Place your fighters on the ring and check the fighting camera against your card UI.

## Gameplay reference

The Blender scene contains non-rendering reference markers for the arena center and two opposing team positions. These empties are not included in the mesh FBX. They are starting references, not a finished combat layout.

- Blender Z is up; the ring top is approximately Z = 2.54.
- Arena center: (0, -4, 2.56) in Blender coordinates.
- Suggested opposing positions: (-13, -4, 2.56) and (13, -4, 2.56).
- Characters, weapons, rigs, animations, beams, blasts, hit detection and card-driven timing should be added in the next production stage.

## Checks and limits

The visual FBX was imported into a clean Blender scene and checked: 32 meshes, 160,698 triangles, all UVs present, three usable embedded textures, and no zero-area faces. Rendered overview and close views were visually inspected. The asset has **not yet been imported or performance-tested in Roblox Studio**. Overall triangle count is for the entire environment; final mobile performance will also depend on characters, effects, UI and game settings. The collision boxes cover walkable surfaces; add gameplay boundaries if players should be prevented from leaving the courtyard.

References: [Roblox general mesh specifications](https://create.roblox.com/docs/art/modeling/specifications), [Blender to Studio setup](https://create.roblox.com/docs/art/blender), [FBX export settings](https://create.roblox.com/docs/art/modeling/export-requirements).
