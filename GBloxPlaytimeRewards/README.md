# G-Blox Playtime Rewards — 15 September 2026

Implemented in the open G-Blox lobby (74498603638770) and Round 1 Muliplayer (106769122906103) Studios. No publishing was performed. Both places were left in Edit mode.

## Behaviour

- Original supplied panel, clock, two card atlases, claim button and claimed stamp.
- Twelve thresholds: 5, 10, 15, 25, 30, 45, 60, 70, 80, 90, 105 and 120 minutes.
- Each reward can be claimed once per continuous session. The completed track does not loop.
- Server-owned time continues through all multiplayer rounds and valid lobby/round return teleports.
- An ordinary rejoin starts a fresh track. Tutorials are excluded from carry-over, as requested.
- Claims are made in the lobby. Cash/trophies are exact advertised amounts; Horses add inventory copies; recharges affect the equipped, owned, available ability. Missing equipment leaves the recharge unclaimed.
- Daily calendar rewards remain separate. Settings, community rewards and daily rewards respect the new panel.

## Saving and transfer

The start time, claim receipts and reward balances live together in PlayerData. A server-issued per-player nonce is saved before an internal teleport. The destination validates the nonce against the saved record, approved source/destination places, source experience and expiry, and consumes it in the profile-loading UpdateAsync. No elapsed time or balances are trusted from TeleportData. Load retries preserve their arrival ID; independent joins reset it.

## Verification

- 99 isolated reward/session checks passed against each installed rules module. These used synthetic profiles, not player balances or live DataStores.
- All 11 initially changed scripts compiled successfully.
- Lobby Studio playtest verified countdown updates, panel open/close, settings/calendar hide and restore, uploaded art loading, and ready/claimed visuals.
- Ready/claimed preview changes were client-only and discarded when stopping the test. No reward claims were made on the real player profile.
- Final UI controller remains enabled and panel hidden until opened.
- End-to-end real server teleport testing remains required after both places are published; Roblox Studio cannot perform TeleportService teleports.
- Desktop layout was visually inspected; phone-device usability has not been device-tested.

`Backups/` contains original scripts; `Installed/` contains final Studio script exports. `BuildUI.lua` recreates the original-art UI in a place where it does not already exist. The short-lived localhost artwork server has been stopped.
