# Cat in the Hat — editable model base

Built from the five supplied film/costume references, with proportions informed by the linked Roblox avatar. This is a stylized interpretation, modeled from scratch, in a relaxed A-pose.

## Files

- **CatInTheHat_Base.blend** — editable Blender project, with six character collections, packed surface texture, camera and lights. The original starting scene is preserved in a hidden collection.
- **CatInTheHat_Base.fbx** — separated meshes for Studio import.
- **CatInTheHat_Base.glb** — alternative export with embedded materials and surface texture.
- **Cat_SurfaceNormal.png** — 2048 × 2048 normal atlas for fur and cloth surface detail. This contains no character colours.
- **CatInTheHat_ThreeQuarter.png**, **CatInTheHat_Front.png**, **CatInTheHat_Back.png** — model previews.
- **Apply_Default_Colours.luau** — optional Studio Command Bar helper to restore or edit the default solid colour palette after import. Select the imported model first.
- **Model_Parts.json** — exact mesh names, colour values and geometry counts.

## Separately editable pieces

- **Body:** black body mesh and white chest/belly bib.
- **Head:** black head/ear fur and white face; separate inner ears, eyes, pupils, brows, nose, mouth and whiskers.
- **Hat:** five individually named bands, alternating red and white, plus a white brim and rolled rim. Every band can be recoloured independently.
- **Bow tie:** left/right loops, centre knot, and two hanging ribbons.
- **Gloves:** left/right gloves, cuffs, and seam details.
- **Tail:** black tail, white tip, and white fur tufts.

The base colours are solid materials. There is no coloured image texture or vertex colour layer locking the character to a palette. The surface normal texture can remain while you recolour the pieces.

## Importing the base into Cat in the hat

1. In the intended Studio game, choose **File → Import**, and select the FBX.
2. Keep **Merge Meshes disabled** to retain the separate colour regions. Importing the hierarchy as one Model still preserves its separate MeshParts.
3. For this unrigged base, use **No Rig** if a rig choice is shown. Enable **Anchored** while reviewing the static model.
4. Check the import size: the intended total height is approximately **8 studs with the hat**, with a body/head height of approximately **6.1 studs**. In Blender, one modeling unit corresponds to one intended stud and the scene unit scale is 0.28 metres.
5. Select individual MeshParts to change their solid colours. The included palette helper provides an editable colour list by exact mesh name and clears any imported colour-map tint while preserving the normal map.
6. If the normal texture is not connected automatically, import Cat_SurfaceNormal.png and assign it as the SurfaceAppearance NormalMap for the character meshes. Keep the colour map empty for solid recolouring.

Importer reference: https://create.roblox.com/docs/studio/importer

## Current state

This delivery is the **visual model base**. It is not yet a playable morph: it has no armature, skin weights, Humanoid, animations, morph trigger or game script. The AttachTo notes on small parts are organization hints, not a working rig. It has not been uploaded to Roblox or tested as a character in Studio.

To turn it into a morph, the next stage is to rig and skin the body, attach the separate colour meshes to the same rig, and test movement and the transformation flow in Cat in the hat.

The character contains **62 mesh objects and 57,162 triangles**. The largest individual mesh is **16,000 triangles**. The export check verified closed geometry with no nonmanifold edges or zero-area faces. This is a general game-model base, not a Marketplace avatar submission or a certified R15 body.

Roblox general mesh specifications: https://create.roblox.com/docs/art/modeling/specifications

## Reference

Proportions reference: https://www.roblox.com/bundles/139187072420539/Cat-In-the-Hat

The supplied photographs informed the hat, red bow, pale face/bib, white gloves, body silhouette and tail. Only this character was modeled.
