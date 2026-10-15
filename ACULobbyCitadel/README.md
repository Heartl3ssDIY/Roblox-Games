# ACU Festival Citadel

An editable anime city lobby with a roughly 600 × 600 layout, 63 architectural placements, and nine named arena portal stations. The expanded town includes a large temple academy, seven-tier pagoda, merchant street, northern fortress gate, waterfall ravine, flowering gardens and dense woodland.

The central character podium is intentionally empty. Any future character statues should use simple Roblox R6 figures, as requested. Signs use the Permanent Marker font. The master Blender file packs the supplied visual references, ACU branding and display font.

## Open and explore

Open `ACU_Festival_Citadel.blend`. Districts, scenery, lighting, cameras and interaction markers are organized into separate collections for editing.

In the camera collection, try `CAM_08_ExpandedCity`, `CAM_09_MarketStreet`, `CAM_10_Waterfall` and `CAM_13_CivicCourt`. Select a camera and press **Ctrl + Numpad 0** to make it active, then **Numpad 0** to view it. Preview images are in `previews/`. Material Preview is enabled in the saved scene so image textures are visible.

The layout provides places for fishing, tea, training, exploration, NPC conversations, leaderboards and portal travel. These are modeled locations and named markers; their gameplay, rewards and interactions are not connected yet.

## Textures and credits

Textured surfaces use real 2K Color, Normal and Roughness image maps with authored `DetailUV` coordinates. The seven active texture families provide 21 JPG source files in `textures/PBR/`; `sources.json` lists their filenames, source links and map details. The completed GLB was checked: all 24 embedded images are present, including the seven Color/Normal/Roughness sets and branding.

Texture assets are from [Poly Haven under CC0](https://polyhaven.com/license): [Stone Floor](https://polyhaven.com/a/stone_floor), [Slate Floor](https://polyhaven.com/a/slate_floor), [Wood Planks](https://polyhaven.com/a/wood_planks), [Grey Roof 01](https://polyhaven.com/a/grey_roof_01), [Aerial Grass Rock](https://polyhaven.com/a/aerial_grass_rock), [Rock Face 03](https://polyhaven.com/a/rock_face_03) and [Bark Brown 01](https://polyhaven.com/a/bark_brown_01).

## File index

- `ACU_Festival_Citadel.blend` — current editable master scene.
- `exports/ACU_Citadel_Roblox.fbx` — visual model export filename.
- `exports/ACU_Citadel_Roblox.glb` — alternate visual model export filename.
- `exports/ACU_Citadel_Collision.fbx` — starter collision geometry.
- `exports/markers.json` — interaction and placement markers.
- `exports/textures/` — export textures.
- `references/`, `textures/`, `previews/` — reference assets, branding and review images.
- `source/` — construction, integration and export scripts.

FBX and GLB exports completed successfully. The GLB structure, embedded images and mesh counts were checked against the manifest. This is a high-detail art build: 14,788,577 evaluated triangles in 5,824 export meshes, with at most 9,000 triangles per mesh. Roblox runtime performance has not been tested. The collision set is a starting point and still needs a full Roblox playtest of walking routes, stairs, bridges and boundaries.

This work is a Blender lobby deliverable. Roblox Studio and the live game remain unchanged.

