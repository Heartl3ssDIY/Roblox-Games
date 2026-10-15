# Arena selection - 2026-09-25

The editable screen is StarterGui.ArenaSelectGui. The former runtime-built arena screen was replaced in LobbyClient. ArenaSelectionUI binds behavior and updates labels, rewards and bar fill without changing authored layout.

Rules:
- Win: +1 arena progress. Loss: -1, minimum 0, maximum 10.
- At 2 / 4 / 8 / 10 progress: 1,000 cash / Bluma unlockable in packs / 10 diamonds / Pikkolo unlockable in packs.
- Milestones grant automatically once. Their green tick stays after losses.
- Completing 10 permanently unlocks the next story, even if later progress drops.
- First four daily wins across arenas: Common, Common, Common, Silver. Wins beyond four give no daily pack.
- Daily reward slots reset together at 00:00 UTC. Unclaimed packs survive the day boundary.
- Daily green ticks mean earned and awaiting claim. Claimed packs become faded.
- A pending pack changes Battle to Claim. Lobby battle entry is guarded until pending packs are claimed. In-arena replay remains available, as requested.
- Back returns to mode selection. Next switches between Tenkaichi and Arena 2's placeholder. Only Tenkaichi currently exists; Arena 2 has no playable story.
- Existing short hover/click audio reused. No trophy/ranked PvP system was added.

Existing limitation: PlayerData is client-side session-only prototype state. This update does not introduce DataStore persistence or a server-authoritative reward backend.

Assets: supplied Arena selection folder; exact uploaded IDs in AssetMap.json.
Backup: ServerStorage.BeforeArenaSelection20260925 and backup_scripts.
Verification.luau is a development test, not installed in the final game.

Verified in Studio Play:
- Milestone grants at 2, 4, 8 and 10; no duplicates or revocations.
- Loss changes 4/10 to 3/10 while the 4-win milestone stays checked.
- Daily four-pack cap, midnight rollover, and pending rewards surviving rollover.
- Next/back navigation and locked Arena 2 preview.
- Pending claim blocks lobby battle entry; repeated claim blocked; Battle restored after reveal.
- Authored geometry unchanged, supplied images loaded, screenshot inspected.
- Test scripts removed and Studio returned to Edit.

Save the place in Studio to persist live edits.
