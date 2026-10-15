# Tenkaichi migration

The active Anime Combat Units Studio place now uses `Workspace.Arena_Tenkaichi`.

Press Play in Studio to start one quick round. Picks resolve after three seconds if no card is selected. The test awards no rewards. Use Play Again on the results panel to repeat, or Back to Lobby to return. F6 starts another quick round from the lobby. Set the Workspace attribute `StudioQuickRoundOnPlay` to false to start in the lobby instead.

Normal matches remain available through Play, the main-mode ring, and Enter Tenkaichi. They use the four-card loadout, three selections per round, four lives, accumulated armies, and a bonus pick for the previous round's loser.

## Changes

- Moved the imported arena and collision model together to the original battle location. Ring surface is at Y=51, centered at X=1000, Z=0.
- Replaced static West City deployment coordinates with the arena's BattleOrigin marker. Camera, formations, and movement use the new arena.
- Added server-controlled travel for the main lobby portal, pack-shop portal, arena entry, and return.
- Rebuilt round cancellation, combat cleanup, procedural animation cleanup, replay, and character removal handling.
- Preserved existing UI layouts, updated arena labels and progression keys, and added the in-match Back to Lobby button.
- Corrected the pack-shop trigger path under Lobby_MainModeZone.
- Followed the G-Blox scripting preference: functions, explicit state, and no decorative comments.

## Verification

Completed quick rounds with attacks and damage on the tournament ring. Tested replay, exiting a draft, exiting combat, camera and lighting restoration, server-side lobby travel, normal match entry, advancement into round two with accumulated units, and pack-shop travel/opening. The final fresh playtest produced an empty Studio output log.

## Backups

Original models are in `ServerStorage.BeforeTenkaichi_20260917.Workspace`. Original script sources are in `backup_scripts`; installed sources are in `scripts`.

Combat and progression still run locally as in the original single-player prototype. Multiplayer combat authority and persistent player data are separate work; this migration does not implement them. Existing unit-specific ability descriptions are not a complete implemented ability system.
