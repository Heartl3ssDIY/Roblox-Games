# Gift truck parcels

Six separate FBX models: Rose (square), Sky (flat), Violet (tall), Mint (round), Amber (long), Coral (compact).

Saved in the existing WarehouseRedesign/To_be_rich_Warehouse.blend file, in the scene **To be rich - Gift Parcels**. Other asset scenes remain in the same file.

Import the six Gift_*.fbx files into Studio using the same scale as the previous parcels. Each gift is about 1–2 studs across. Preserve the individual mesh parts and their names. Each file contains one gift with ten separately recolourable mesh parts: body, lid, ribbons, lid ribbons, printed pattern, tails, bow, knot, tag and tag print. Names are under 50 characters. The presentation floor, lights and camera are excluded.

The FBX files include solid material colours, with no external textures required. gift_manifest.json records the exact RGB colours if Studio needs recolouring after import.

These models were imported and connected to SpecialTruckService on 16 September 2026. See StudioIntegration.md for their locations, pickup/reward behaviour and checks. The installed versions use one simple collision root with massless, noncolliding visual parts. Existing reward odds are unchanged.

Checks: all six files were reimported in a temporary Blender scene; mesh counts, triangle counts, dimensions, ground level and names passed. All exported meshes have closed edges and no degenerate triangles. Typical gifts contain 720–912 triangles; the round gift contains 1,936.
