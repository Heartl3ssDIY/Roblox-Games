# Arena teleport setup — 26 September 2026

Applied in the open Roblox Studio place Anime Combat Units (111313211501470).

1. Tenkaichi
2. Chūnin Exam Hall
3. Loguetown
4. Jujutsu High
5. Mount Fujikasane
6. Heavens Arena
7. Hyperbolic Time Chamber
8. Wano
9. Marineford

Tournament of Power is excluded and its imports are untouched.

The existing arena menu now cycles through these nine entries. Tenkaichi retains Battle. The other eight offer Teleport without loadout requirements or starting a match, with a Return to Lobby button. Travel uses the existing anchored spectator position and arena camera system.

Editable controls are in StarterGui.ArenaSelectGui. ArenaCatalog in ReplicatedStorage holds labels and order. Each Workspace.Arena_* model has Environment, Collision, BattleOrigin, CameraFocus, DeploymentMarkers and Sidelines. Existing Tenkaichi geometry and markers were retained.

Rewards, unlocks, PlayerData and ArenaMatchClient were not changed.

Repairs:
- Aligned Fujikasane and Time Chamber collision imports with their visible models.
- Replaced the malformed 2000-stud Time Chamber floor collider with an invisible native block.
- Enabled double-sided rendering on map visuals to restore hidden reverse-facing surfaces.
- Filled 11 blank SurfaceAppearance material slots using the correct atlas already assigned to each mesh, restoring the dome, pagoda and other details.
- Existing translucent hourglass glass was preserved.

Verification:
- All five changed/new scripts compile.
- Isolated server tests pass all nine destination/return round trips, Tenkaichi default entry and rejection of excluded or non-match destinations.
- Isolated menu tests pass nine labels, eight visit/return flows and wraparound.
- Both sideline markers for each arena have collision below them.
- 81 central floor samples per arena (729 total) have no missing floor or high obstructions.
- Studio visual previews inspected for material repairs and the longest arena label.
- No Play session was started; live multiplayer behavior was not tested.

Rollback backup in ServerStorage:
BeforeArenaTeleports_20260926_053314
Includes original imported models, four original scripts and ArenaSelectGui.

The scripts folder contains installed source; before contains original source. SetupModelsFreshImports is for the original ungrouped imports only, not for rerunning on the configured place. Test Menu creates a temporary preview which must be removed after use.

Changes are in the open Studio place. This task did not publish the game.
