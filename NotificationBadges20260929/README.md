# Notification badges

The editable badge objects are in StarterGui. Each uses the supplied circle art with a centered editable `!` TextLabel.

| Badge | Studio path | Asset |
| --- | --- | --- |
| Battle Pass | `LobbyMenuGui.Sidebar.BattlePass.Badge` | `rbxassetid://99552023005519` (green) |
| Season Rank | `LobbyMenuGui.Sidebar.SeasonRank.Badge` | `rbxassetid://99552023005519` (green) |
| Pack button | `PacksButtonGui.PacksBtn.PackBadge` | `rbxassetid://140490410313144` (red) |
| Pack shop | `PackShopGui.Board.Panel.{Common,Silver,Gold,Diamond}.PackBadge` | `rbxassetid://140490410313144` (red) |
| Arena daily-pack Claim | `ArenaSelectGui.Board.Action.PackBadge` | `rbxassetid://140490410313144` (red) |

The red badges show only for owned packs or a pending arena daily pack. The Season Rank badge shows after a trophy or league change following profile load, then clears when Season Rank is clicked. The Battle Pass badge checks for a claimable reward; its current reward flow auto-credits tiers, so it remains hidden until a claimable state exists.

Changed script exports are beside this file. Studio edits must be saved and the group game republished to reach players.
