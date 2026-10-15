# Laptop replacements

All three are saved in the existing `WarehouseRedesign/To_be_rich_Warehouse.blend`, in the `To be rich - Laptops` scene.

- `Laptop1_Dell.fbx` replaces `ServerStorage.FurnitureModels.Laptop1`.
- `Laptop2_HP.fbx` replaces `ServerStorage.FurnitureModels.Laptop2`.
- `Laptop3_MacBook.fbx` replaces `ServerStorage.FurnitureModels.Laptop3`.

The FBX sizes compensate for the current FurnitureService scale factors: 1, 1.4 and 0.5. Keep those factors and do not resize the imports. Their final widths are approximately 3.2, 3.15 and 3.3 studs. The exports include an orientation correction for the current Studio importer and furniture anchors; verify facing when installing them.

Keep each imported laptop as a Model with separate MeshParts. If Studio imports it grey, select the imported model(s) and run `ApplyLaptopColours.luau` in Studio's Command Bar. The helper only applies colours and part settings; it does not replace existing templates. Back up the existing templates before swapping them, and retain the names Laptop1, Laptop2 and Laptop3.

Screens are plain black. Each colour group is independently recolourable. Individual keys are joined into one keycap mesh, with key lettering in a separate mesh. Parts are named by function. The laptops contain 4,418–4,524 triangles each.

FBX files were reimported into Blender and checked for matching names, triangle counts, floor-level feet, black-screen material and expected scale. The laptops have not yet been imported or installed in Roblox Studio.
