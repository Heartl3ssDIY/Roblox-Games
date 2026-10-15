# Player Stats UI

The editable panel is `StarterGui.StatsGui`. The existing `LobbyMenuGui.Sidebar.PlayerStats` button opens it. Clicking the full-screen `Dim` area or the reused `Panel.Close` button closes it. The panel's `FitToScreen` UIScale keeps its authored positions and sizes intact.

| Image | Roblox asset ID |
| --- | --- |
| Background | `rbxassetid://82584145231238` |
| Name banner | `rbxassetid://134708878712865` |
| Kills | `rbxassetid://77811114778396` |
| Units collected | `rbxassetid://95708832119339` |
| Highest trophies | `rbxassetid://140448424375422` |
| Win rate | `rbxassetid://107736812064284` |
| Losses | `rbxassetid://130447604401391` |
| Wins | `rbxassetid://131973507242307` |
| Bronze frame | `rbxassetid://127162746869068` |
| Silver frame | `rbxassetid://103938672730379` |
| Gold frame | `rbxassetid://133548151025839` |
| Platinum frame | `rbxassetid://107976210097894` |
| Diamond frame | `rbxassetid://121678927867657` |

The name uses Permanent Marker with an outlined, measured font size. The frame follows the player's current league. Units collected counts owned units, including starters. Losses include forfeits, and win rate uses wins divided by wins plus losses. Opponent-unit kills and the highest trophy count persist through the profile store; the match ticket prevents duplicate kill credit. Existing Studio test and live profile stores remain separate.

Changed script exports are in this folder. Studio edits must be saved and the group game republished to reach players.
