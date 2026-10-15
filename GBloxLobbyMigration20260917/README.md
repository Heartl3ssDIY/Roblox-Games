# G-Blox active lobby migration — 17 September 2026

Applied in the G-Blox lobby Studio place, 74498603638770, in Edit mode only. Nothing published and no Play/Stop operation used.

## Active layout

The new Teal Arena is now `Workspace.Lobby`; its exact doubled floor is `Workspace.Lobby.Lobby floor`, preserving existing script paths. Floor centre X/Z: 697.554565 / 5.979412. Floor top Y: 0.937745. Dimensions: 288.34268 × 200.13206 studs.

The original gameplay instances were moved, not replaced with decorative copies:

- Three eggs and their prompts: right/front bay.
- Abilities shop: left/front bay.
- Gravity and speed treadmills: left-side training area, with clear exits.
- Free community/like gift: centre-right approach.
- Three party/round teleport zones: raised rear platform.
- Both enabled lobby spawns, queue exit position, and Eggs/Play/Shops navigation markers: safe positions inside the new building.
- Real leaderboard and champion podiums: left wall, replacing the display-only copy.
- All 45 coins: clear main-floor positions; respawning samples the new floor bounds.
- Original lightning decorations: perimeter of new lobby.
- Invisible perimeter barriers: expanded to new footprint.
- Pet source models: kept hidden below the new map, with the existing `Workspace.Pets` path retained. These are templates, not shop decorations.

The functional models remain at their established Workspace paths even though they are physically inside the new building. This preserves references used by existing scripts.

## Script and animation support

Five existing scripts updated:

1. `ServerScriptService.LobbyCoins`: shared spatial-placement helper embedded in this existing script; no missing ModuleScript dependency. Uses canonical new floor, clear-space and coin-spacing checks.
2. `ServerScriptService.GlobalLeaderboardServer`: generated champion avatars face relative to their moved/rotated anchor.
3. `ServerScriptService.QueueServer`: clears `GBloxInParty` on party removal/reset, preventing stale party restrictions.
4. `ServerScriptService.GBloxEggService`: accepts tagged stands only in Workspace, ignoring archived copies.
5. `StarterPlayer.StarterPlayerScripts.LobbyInteractions`: same active-stand/ring guard on client.

Updated all six egg-ring `RingRestCFrame` attributes, all 45 coin `RestCFrame` attributes, and the gift's `GiftRestPivot` / `GiftCenter`. Removed gameplay tags from decorative podium copies and archived snapshots. Set each party billboard's Adornee to its ZoneContainer.

Party destination remains Round 1 Multiplayer, 106769122906103. Read-only inspection confirmed the round server returns players to lobby place 74498603638770 with its existing playtime handoff. No round-place changes were necessary. Purchase IDs, receipt handling, balances and player profiles were not modified.

## Verification

- 317 Edit-mode checks passed, including compilation of all 63 active scripts.
- Verified safe spawn/navigation spaces, floor beneath navigation targets, original interaction tags/counts, animation rest positions, party bounds and treadmill exits.
- All 45 existing coin placements passed clearance/spacing checks.
- 100 sampled future coin respawns passed.
- Two additional isolated party-function checks passed: removal and reset both clear the party attribute.
- Exact readback matched all five intended script edits.

These are not multiplayer gameplay tests. No purchases, rewards or DataStore writes were triggered. Final Studio screenshot captures returned a blank 3D view, so the final populated layout has numerical checks but not a successful final visual capture. Walkthrough/multiplayer testing is still needed when the user chooses to run it.

## Recovery

Complete Studio backup: `ServerStorage.GBloxLobbyMigration_20260917_023615`.

- `WorldBefore`: snapshots of all moved containers and both pre-move lobby models.
- `ScriptsBefore`: exact original sources of the five edited scripts, saved as StringValues.
- `RetiredOriginalShellAndPreview`: original lobby shell and retired display-only leaderboard.

Archived objects have gameplay tags removed to prevent duplicate interactions; original tag lists are stored in `MigrationArchivedTags`. Script-containing model snapshots store script source as a StringValue with original class/name/disabled-state metadata, avoiding executable backup scripts. Restore deliberately, including tags and source metadata; do not simply duplicate snapshots into Workspace alongside the live systems.

The earlier `GBloxLobbyMigration_20260917_023522` folder is explicitly marked `IncompleteBackupOnly` and is not the restore point.

Local `before/` contains original script sources. The migration scripts are one-time records, not scripts to run during gameplay or repeat on the migrated map. `GBloxLobbyCoinPlacement.luau` is a standalone helper source used by tests; the same code is embedded in the live LobbyCoins script, not installed as another module.
