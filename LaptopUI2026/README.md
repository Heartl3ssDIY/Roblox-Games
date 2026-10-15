# Laptop UI replacement

Installed in the connected To be rich Studio place on 16 September 2026.

## Behaviour
- Laptop icon opens business selection.
- Warehouse opens Contracts; Car Dealership and Jet Company remain locked.
- Back returns to business selection; Close closes the laptop.
- Corrected tabs, green active outline, original supplied artwork.
- Contracts artwork stays at its full row height; extra content scrolls.
- Existing Payments, Trucks, Statistics, Agency, Store, Customise, Black Market, Security and Achievements pages remain connected.
- Custom image scrollbars support wheel scrolling and dragging.
- Moving gloss, press animation, quiet hover/click/tab/open/back/close cues.
- Runtime feedback uses bundled Roblox sounds; no external audio permissions needed.

## Verification
- Actual mouse navigation through business selection, Contracts, Payments, Achievements and Security.
- Corrected art loaded; exactly one sidebar selection outline active.
- Car and Jet clicks remain on business selection.
- Vertical and horizontal custom thumb drags changed their scrolling positions.
- Standard Tender charged 25 Crypto once; selected Beacon Distribution and signed Bay 2 successfully.
- Insufficient-funds message displayed correctly.
- All six sound instances loaded with non-zero duration; no UI runtime errors in the tested session.
- iPhone 17 Pro landscape and portrait previewed with Sensor orientation and DeviceSafeInsets.
- Portrait keeps the complete laptop visible but makes text small; a dedicated portrait layout remains a possible future improvement.
- Studio returned to Edit; device simulation stopped.
- Temporary Studio-only test funding removed, Main restored byte-for-byte, no live currency changes.

## Files
- Controller.before.luau: original controller.
- Controller.luau: installed controller.
- InstallLayout.luau: layout construction reference; controller source is separate.
- AssetIds.json: uploaded asset references.
- images/: copies of supplied source artwork.

Studio backup: ServerStorage.LaptopUIBackup_20260916 (original GUI without executable scripts, plus original controller source).

