Playground Classics retro studs

Applied directly to the Playground Classics place, ID 95034648955135.
4,301 opaque colored surfaces across the lobby, British Bulldog, Tag You're It,
and Stuck in the Mud use MaterialService.PlaygroundRetroStuds.
The shared material covers blocks, wedges, cylinders and spheres.

The ink geometry and 81 Highlight outlines retain their original finish.
Water, glass, transparent markers and unanchored parts are excluded.
Base material, geometry, colors, collision and effective physics are preserved.
All 42 script sources and 327 authored StarterGui layouts are unchanged.

To adjust stud size, edit MaterialService > PlaygroundRetroStuds > StudsPerTile.
The current value is 1. Increasing it makes the repeating studs larger.
No global material override is enabled, so character and UI preview materials
are unaffected. No runtime script was added for this finish.

ApplyRetroStuds.luau reapplies the treatment in Studio Edit mode.
RestoreRetroStuds.luau restores the tracked materials using the native backup:
ServerStorage.PlaygroundRetroStudsBackup20261003.
VerifyRetroStuds.luau checks the material, outlines, geometry and physics.
Run these through the Studio connection or the Studio command bar in Edit mode.

OriginalMaterials.json contains the original materials for all 7,026 map parts.
Its columns are path, material, materialVariant, changed, map.
The native ObjectValue backup is the authoritative restore mechanism because
it preserves exact instance references, including any duplicate instance names.
Keep the native backup when saving the place.

Texture maps match the stud material in the open source Resurface plugin:
https://github.com/cxmeel/resurface-plugin/blob/main/src/Assets/MaterialVariants.luau
Color: rbxassetid://10509831729
Normal: rbxassetid://10509831753
The native renderer confirmed both assets loaded. Direct string PreloadAsync
initially reported failure, so verification uses the rendered result and fetch
status after the material is installed.

Lobby-RetroStuds.png is a native Studio preview. ScreenGui visibility was
temporarily hidden for that capture and then restored to its authored values.
Verification.json records the finished checks and protected UI/script digests.
