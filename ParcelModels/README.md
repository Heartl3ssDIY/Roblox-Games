# Parcel models

Saved in the existing `WarehouseRedesign/To_be_rich_Warehouse.blend`, in the `To be rich - Parcels` scene.

## Exports

- Small: flat carton, 1.50 × 1.08 × 0.72 studs (width × depth × height).
- Medium: rectangular box, 1.90 × 1.55 × 1.45 studs.
- Large: tall box, 2.25 × 1.90 × 2.60 studs.
- Fragile: medium box with red border and wine-glass warning label.
- Gold: medium box with gold coating and separate glow border.
- Rainbow: medium box with violet coating and a multicoloured glow border.

Every variant has separate body, lid flaps, tape, labels and printed details. Colours and glow borders remain editable. Models contain 1,023–1,307 triangles.

The FBXs embed six 1024px cardboard colour maps and a shared normal map. Separate PNGs are also in Textures, and the images are packed into the Blender file. Keep imported textures/SurfaceAppearance on Body and TopFlaps. Use white MeshPart colour for textured surfaces to avoid tinting the cardboard twice.

## After importing into Studio

Select imported parcel Models and run ApplyParcelSettings.luau in the Command Bar to apply colours, sheen, Neon borders, and rigid joints. It preserves imported body textures. The Body is the only collidable, non-massless part. It stays anchored during setup; unanchoring the Body allows the intact assembly to tumble and bounce. Surface details stay attached.

The models are not yet installed into PackageService. That service currently creates its own Part-based boxes. Integration after import must retain the existing package attributes, GrabParcel prompt, carrying Motor6Ds, size/rarity rewards, and restaging logic. Ragdoll-style dropping, settling and animated rainbow glow require that gameplay integration; FBX geometry alone does not add those behaviours.

Gold and rainbow borders use Neon after setup. A soft halo depends on Studio lighting/post-processing. Their coating uses Metal with low reflectance; regular cardboard stays matte.

## Warehouse floor fix

The visible warehouse had moved up approximately 0.85 studs while staging and several gameplay anchors stayed at their previous heights. Those points are now aligned. Parcel placement reads the actual FloorSurface top and each parcel's height. Worker walking height also follows that surface. The baseplate was retained.

Checks in Edit mode covered 510 parcel size/slot combinations, floor collision height, the desk anchor and translated plot copies. Play mode was not started. Original scripts and the pre-fix warehouse are in ServerStorage.WarehouseHeightBackup_20260915_234402.
