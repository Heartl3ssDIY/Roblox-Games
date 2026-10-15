# G-Blox purchase buttons — prepared for approval

## Status
Prepared locally. NOT applied to either Studio place.
Automatic approval review rejected the application because it modifies persistent player data and real-money receipt handling, and extends the cash-pass effect into the race place.
Read-only checks confirmed both places are unchanged.

## What changes
- Convert the displayed price artwork into clickable checkout targets.
- Five cash packs: 1K, 5K, 25K, 100K, 1M; verified product IDs already provided.
- 2x and 5x Cash game passes: verified IDs already provided.
- Validate purchases on the server before opening Roblox checkout.
- Award cash only from Roblox ProcessReceipt, never from a client purchase-finished event.
- Store purchased cash and receipt marker in the same existing player profile save.
- A failed save is not acknowledged. Receipt retries do not add cash twice.
- Cache server-verified permanent pass ownership and apply the highest multiplier (5x replaces 2x).
- Apply cash passes to earned lobby cash and race payouts; cash packs give their exact advertised amount.
- Preserve current pet multipliers.
- Keep dynamic, player-specific Roblox price display.
- Shop items without IDs and Robux ability refills show Coming soon.

## Scope
Lobby: G-Blox, place 74498603638770.
Race: Round 1 Muliplayer, place 106769122906103.
Both are in universe 10611575889 and use GBlox_PlayerData_v1.
Existing scripts are backed up locally in *.before.luau.
No publishing or real purchases performed.

## Files to apply
Lobby: LobbyPlayerData.luau -> ServerScriptService.PlayerData
Race: RoundPlayerData.luau -> ServerScriptService.PlayerData
Both: PlayerDataServer.luau -> ServerScriptService.PlayerDataServer
Lobby: ShopClient.luau -> StarterGui.GBloxShopMockups.PreviewNavigation
Lobby: BuildPurchaseButtons.luau -> UI construction changes
Race: RunnerServer.luau -> one cash payout multiplier line

## Verification completed
All four main script sources compiled successfully in Luau.
Ten isolated tests passed using mock profiles, ownership and saves:
1. All five exact cash-pack amounts.
2. Duplicate receipt awards once.
3. Failed save is not acknowledged; retry saves without a second award.
4. Persisted receipt survives reload.
5. Unknown product, wrong player and invalid receipt rejected.
6. Expired lease and unsavable profile rejected.
7. Highest cash multiplier wins; purchased packs remain exact.
8. Cached ownership survives an ownership service outage.
9. New ownership check failures block checkout.
10. Only configured items can open checkout.

## Remaining checks after approval
- Apply backups and scripts to both Studio places.
- Play-test actual price-button clicks, checkout cancellation and owned-state feedback.
- Verify server receipt integration and race reward display.
- No real-money purchase is needed for isolated verification.

## Limitations
Only the two game passes and five cash packs have supplied IDs. Other shop/ability/egg monetization cannot be activated until their IDs and rewards are configured.
The isolated tests exercise the actual new receipt and ownership functions with mock storage. They do not prove live DataStore or Roblox checkout success.

