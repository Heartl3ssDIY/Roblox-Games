# Fishing for packs prototype

Installed in the current **Anime Combat Units** Studio Edit session on 2026-09-26. A live playtest is still pending. This README records the installed state; it does not confirm that the place has been saved or published.

The lobby has active fishing prompts at these two markers:

- `Workspace.Lobby_MainModeZone.Markers.HOBBY_Fishing`
- `Workspace.Lobby_MainModeZone.Markers.HOBBY_OuterGardenFishing`

Both markers have `LobbyAction = "Fishing"`. The installed `StarterPlayer.StarterPlayerScripts.LobbyDestinations` source is saved as [LobbyDestinations_Fishing.luau](./LobbyDestinations_Fishing.luau). It opens the fishing UI and closes it when another lobby panel opens, on arena entry, and on respawn. `ReplicatedStorage.FishingUI` binds the interface, and `ServerScriptService.FishingServer` handles cast and reel requests through `ReplicatedStorage.ArenaEvents.FishingRequest`.

The editable `StarterGui.FishingGui` contains `Panel.Cast`, `Panel.Reel`, `Panel.Close`, `Panel.Status`, and `Panel.ProgressTrack.Cursor/CatchBand`. The script updates the meter elements, status text, and button interaction state.

The server validates lobby proximity, the cast token, cooldown, and reel timing from server time. It awards at most one Common Pack per player per server session and never trusts a score submitted by the client. Experience Configs are loaded asynchronously, so the server can start accepting requests even if a config load is slow. The optional keys are `fishingInteractionDistance`, `fishingAttemptCooldown`, `fishingCatchHalfWidth`, `fishingMeterPeriod`, and `fishingLatencyTolerance`; local defaults apply if a value is unavailable.

Current limitation: `PlayerData` is client-only with no persistent inventory. The client credits the pack after the server approves the catch, but that pack exists only for the current client session and is not tamper-proof. The success message says, “Common Pack earned for this session. Open it at the Packs hall.” Do not describe it as a permanent reward or use it for paid or competitive rewards. Migrate pack ownership and claim records to server-owned persisted data before production.

The installed `ReplicatedStorage.PackShopUI` includes the banked Common Pack opening handler from `PackShopUI_OwnedOpen.luau`. `PackShopUI_BeforeOwnedOpen.luau` records the source from before installation. The separate Common Buy purchase stub remains unchanged.

The installed editable owned-pack button has these properties:

| Property | Value |
| --- | --- |
| Class / name | `TextButton` / `OwnedOpen` |
| Parent | `StarterGui.PackShopGui.Board.Panel.Common` |
| Position / size | `UDim2.fromOffset(373, 105)` / `UDim2.fromOffset(213, 61)` |
| ZIndex / initial Visible | `3` / `false` |
| Font / size | `FredokaOne` / `19` |
| Colors | Dark purple background, warm cream text and 3-pixel gold `UIStroke` |
| Shape | 12-pixel `UICorner`, `TextWrapped = false` |

This control shares the existing Common Buy button's footprint. When a banked Common Pack exists, the script shows `OwnedOpen` and hides the existing `Buy`; otherwise it reverses that visibility. The existing Common Buy handler remains unchanged. The new handler checks pack ownership and `PackOpening.info("bronze").eligible` before consuming. It then rolls once, consumes one pack, applies once, and runs the reveal once.

Pack odds are unchanged. An eligible player with no owned card pool may still roll no reward if the new-unit chance misses; that existing probability issue should be addressed separately before treating the Common Pack as a paid product.
