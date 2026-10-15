# Anime Combat Units — result and Battle Pass Studio import

Target: **Anime Combat Units**, Roblox place `111313211501470`. [asset-ids.json](./asset-ids.json) maps the supplied PNGs to their uploaded Roblox image IDs; staged copies are in [assets](./assets).

## Studio paths

- `StarterGui.ArenaHUD.RewardOverlay.ResultFlow`: editable mastery and awards screens. `ReplicatedStorage.MatchResultsUI` fills the four real unit viewports, animates mastery, then opens the awards stage.
- `StarterGui.ArenaHUD.PityBackdrop` and `PityDim`, with `ReplicatedStorage.DraftController`: the red **Pick One Loser** art appears on the actual between-round pity choice.
- `StarterPlayer.StarterPlayerScripts.ArenaMatchClient`: awards match results, opens the new result flow, and reports a win, loss, or forfeit to `ReplicatedStorage.SeasonPassData` once per full match. Defeat gives each unit **4 mastery**, victory **10**.
- `StarterGui.BattlePassGui`: editable horizontal free/paid Battle Pass with 45 levels; `ReplicatedStorage.LevelPassUI` keeps the prior `build/open/close/isOpen` interface. `ReplicatedStorage.SeasonPassData` tracks pass XP separately from legacy account XP.
- `StarterGui.LobbyMenuGui.Sidebar.BattlePass`: uses the supplied button art.

Backups are under `ServerStorage.ACU_UI_Backup_20260927_ResultPass`, `ServerStorage.ACU_UI_Backup_20260927`, and `ServerStorage.BeforePityArt_20260927`.

## Current rules and pending setup

The result screens show the game's actual match grants: victory **100 coins / 10 Mastery Chips**, defeat **35 coins / 4 Mastery Chips**, plus any configured arena milestone bonuses. The provided large example amounts in reference images were not substituted for the game values. Boost Mastery retains the existing **1 chip for +10 mastery once per unit per result screen**. A daily win pack appears only when the game's existing daily-pack rule awards one.

Battle Pass wins give **5 pass XP and 10 trophies**; losses give **2 pass XP and remove 4 trophies** (minimum zero); forfeits remove **3 XP from the current level only**. Each of the 45 levels needs 15 pass XP. Only the first coin and diamond reward cards have artwork because their actual amounts and the remaining reward schedule are unspecified. The **1499** paid button is display-only until a Roblox product and price are configured. Pass progress is currently session-only and requires server-authoritative persistence and a monthly reset before live release.
