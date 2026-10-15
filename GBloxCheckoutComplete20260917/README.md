# G-Blox checkout integration — 17 September 2026

## Applied in Studio
- Lobby G-Blox, place 74498603638770.
- Round 1 Muliplayer, place 106769122906103.
- Both belong to experience 10611575889.
- Neither place was published; both were returned to Edit mode.

## Purchase catalog
Game passes:
- 1981874715 — 2x Cash — base 399 R$.
- 1981928696 — 5x Cash — base 1999 R$ (highest cash pass wins, not 10x).
- 1982264711 — +1 Pet Equip — base 500 R$.
- 1982600733 — 2x Trophies — base 799 R$.
- 1981952807 — Triple Egg Open — base 299 R$.
- 1986410259 — Auto Egg Open — base 149 R$.

Developer products:
- 3713203989 — 1000 Cash — 99 R$.
- 3713204079 — 5000 Cash — 499 R$.
- 3713204982 — 25000 Cash — 2000 R$.
- 3713205097 — 100000 Cash — 4499 R$.
- 3713205149 — 1000000 Cash — 9499 R$.
- 3713206457 — 50 Trophies — 299 R$.
- 3713206491 — 250 Trophies — 1000 R$.
- 3713207026 — 1000 Trophies — 3999 R$.
- 3713207054 — Orbit Egg — 249 R$.
- 3713207574 — Gravity Switch recharge (+2 game uses) — 299 R$.
- 3713207627 — Plat Be Gone recharge (+2 game uses) — 198 R$.
- 3713207658 — Freeze recharge (+2 game uses) — 199 R$.
- 3713208203 — Antispike recharge (+2 game uses) — 298 R$.
- 3713207914 — Superspeed recharge (+2 game uses) — 598 R$.

Client price displays use Roblox's current player-specific price, not only the base prices above. The test account received lower prices from Roblox; this is expected live pricing, not a changed product ID.

## Buttons and rewards
- 19 shop/recharge checkout targets: 6 passes, 5 cash packs, 3 trophy packs, 5 recharges.
- Orbit uses its stand prompt followed by an odds confirmation and Roblox checkout.
- Purchases are fulfilled only by the single server ProcessReceipt callback in each place.
- Currency packs are exact amounts, not multiplied by passes/pets.
- Recharges require the ability already unlocked before prompting; add 2 uses rather than replacing the remaining uses.
- Receipt markers and rewards share the existing leased player profile save. Duplicate or failed-save retries do not add the reward twice; acknowledgement waits for a successful save.
- Round place can finish outstanding receipts as well, so changing places does not abandon a purchase.
- Cash passes apply to earned lobby cash/race payouts; 2x Trophies applies to earned race trophies.
- Two pet bonuses add above 1x, as requested: two 1.2x pets give 1.4x. Inventory supports equipping/removing two pets (including two copies if owned), and lobby followers display both.
- Race reward rows include each pet and the cash/trophy pass contributions.
- Permanent Abilities, Dominus Pet, Skip Cooldowns and the undecided Refresh Ability are absent from active checkout. Kong stays unavailable.
- Triple/auto opening applies to trophy eggs. Orbit remains one paid hatch per purchase.

## Paid random rewards
All egg requests use PolicyService eligibility checks and fail closed if eligibility cannot be checked.
Because trophies are purchasable with Robux, trophy eggs are also gated for restricted users; there is not currently a separate earned-only trophy balance.
Orbit displays its four chances before checkout: Orca 85%, Swordfish 10%, Shark 4.5%, Alien 0.5%.
An ineligible/unverifiable Orbit receipt remains pending rather than being silently acknowledged without its reward.
Do not advertise Orbit as an externally purchasable product that bypasses the in-game eligibility/odds flow.

Roblox references:
https://create.roblox.com/docs/reference/engine/classes/MarketplaceService
https://create.roblox.com/docs/production/monetization/paid-random-items

## Verification
- 87 isolated actual-rule/data-function checks passed: all product rewards, duplicates, retry/save failure, odds boundaries, two-pet bonuses, entitlements and policy rejection.
- 44 actual-client-callback tests passed: 19 correct checkout IDs, double-click protection, cancellation unlock, server refusal, prompt error/retry, owned passes and hidden exclusions.
- 48 lobby scripts and 47 race scripts compiled with no errors.
- Live lobby: price lookups worked, pass ownership showed OWNED, ability recharge prices loaded, two-pet capacity loaded.
- Fixed a runtime loop bug where a layout object without AbilityId matched products without Ability; clean restart confirmed no shop script errors.
- Live race: profile ready, 5x cash, 2x trophies, 2 pet slots; console empty.
- Only one active ProcessReceipt handler in the lobby; former egg receipt callback removed.
- No real purchases were made. Isolated tests made no real DataStore writes. Normal Studio playtests loaded/saved the existing profile and legitimate pass ownership through the game's normal lifecycle.
- Screenshot/mouse tools did not respond, so actual mouse-through-checkout/cancellation still needs a manual Studio check. The menu also logged existing image preload failures; no image assets were replaced in this task.
- No paid checkout confirmation or live-money transaction was performed.

## Files
before/ preserves the original scripts from the start of this task.
Lobby_*.luau and Round_*.luau are the installed sources.
UIBuild.luau records the Studio UI property changes.
IsolatedRulesTests.luau and IsolatedButtonTests.luau are mock-only test runners.

