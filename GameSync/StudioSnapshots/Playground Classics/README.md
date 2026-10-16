# Playground Classics — Studio source snapshot

Captured on 16 October 2026 from the connected Edit data model, place **95034648955135**, universe **10769034155**, published place version **307**. The data model name is Place4. Capture uses current Script Editor buffers through ScriptEditorService:GetEditorSource. Unsaved status could not be read; this does not confirm that Studio has been saved or published.

## Contents

- 81 editable Luau source files (1,306,464 UTF-8 bytes), with original instance paths, classes, disabled/run-context metadata, and SHA-256 in metadata.json and sources.snapshot.json.
- 24 ServerScriptService, 37 StarterGui, 6 StarterPlayer, 2 ReplicatedStorage, 10 ServerStorage WeaponRigFixtures, and 2 Workspace rig scripts. The authored fixture/world Animate scripts are included; engine CoreScripts and packages were not traversed.
- Inventory of 448 historical backup/recovery scripts (sources are not duplicated in this current snapshot). PetAdminFix20261007 contains PlaygroundPetsBefore and is also historical.
- Selected British Bulldog authoring state: 81 gameplay/root parts, arena attributes, collision groups/matrix, and StarterPlayer zoom defaults.
- Local comparison against 2,215 prior Lua/Luau files and a final verification record.

All 81 sources were re-read from Studio and matched their captured byte lengths and Adler32 values. This verifies capture consistency; no game tests were run. No Studio instance, source, UI, save state, play mode, or published place was changed.

## Differences from previous local exports

65 sources have an exact normalized content match somewhere in existing exports. BritishBulldogService, TagService, and TagSprintService include later stamina changes absent from their latest complete local exports. Newer local files with those names are method-only snippets; this snapshot preserves full modules. 13 sources have no matching prior export: twelve rig Animate scripts plus StarterPlayer.StarterPlayerScripts.4 ORBIT REVEAL.

Current round camera code permits zoom from 0.5 to 25. StarterPlayer defaults are 0.5 to 128. The arena folder still carries a legacy CameraZoomDistance attribute of 30. These are distinct values; the snapshot preserves all of them. CrossingLength is 288, CourtLength is 368, and CourtWidth is 224.

## Scope limit

This is **not a full place backup**. Authored ScreenGui layouts, complete geometry, terrain, models, mesh/texture/animation payloads, and unrelated instance properties are not serialized here. Existing project assets and history remain separate. No import or synchronization back into Studio has been performed. File names encode unsafe path characters; original instance segments and duplicate ordinals are preserved in JSON.
