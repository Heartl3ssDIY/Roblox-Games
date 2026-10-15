# G-Blox — Roblox ID checklist
Audited the open G-Blox lobby and Round 1 Muliplayer Studio places on 16 September 2026.

Create these under the **G-Blox experience** in Creator Dashboard, not a separate experience for each course. Send back the item name and its Pass ID or Developer Product ID. Do not send an icon/image ID in place of a purchase ID.

Prices below are the current shop labels/configuration, not newly chosen prices. Keep unfinished purchases off sale until their rewards and receipt handling are connected and tested.

## Already wired, waiting for IDs
- **Triple Egg Open** — Game Pass; price not configured. Unlocks opening three trophy eggs at once (the trophy cost still applies).
- **Auto Egg Open** — Game Pass; price not configured. Automatically opens trophy eggs while the player is near the stand.
- **Orbit Egg — 1 hatch** — Developer Product; **249 Robux**. One ID is sufficient; the catalog's OrbitSingle and Orbit ProductId placeholders refer to the same intended purchase. Paid-random-item policy checks must also be completed before selling.

## Shop previews: IDs plus implementation still needed
### Game Passes — permanent benefits
- **2x Cash** — 399 Robux.
- **5x Cash** — 4,499 Robux.
- **+1 Pet Equip** — 500 Robux.
- **2x Trophies** — 799 Robux.
- **Dominus Pet** — 999 Robux. Current preview says “5x the multiplier of your equipped pet”; its final pet/stacking behaviour is not implemented.
- **Permanent Abilities** — 10,000 Robux. Current preview says no rebuying uses; it does not specify removal of cooldowns.

### Developer Products — repeatable purchases
Cash packs (a separate ID per pack):
- **1,000 Cash** — 99 Robux.
- **5,000 Cash** — 500 Robux.
- **25,000 Cash** — 2,000 Robux.
- **100,000 Cash** — 8,999 Robux.
- **1,000,000 Cash** — 25,000 Robux.

Trophy packs (a separate ID per pack):
- **50 Trophies** — 299 Robux.
- **250 Trophies** — 1,000 Robux.
- **1,000 Trophies** — 3,999 Robux.

Ability recharges (a separate ID per ability; visible usage rules say **2 game uses** per Robux recharge):
- **Gravity Switch recharge** — current button 298 Robux.
- **Plat Be Gone recharge** — current button 198 Robux.
- **Freeze recharge** — current button 198 Robux.
- **Antispike recharge** — current button 298 Robux.
- **Superspeed recharge** — current button 598 Robux.

Important: older hidden ability labels still contain different prices (149/99/299). Confirm the current button prices above before setting these products on sale. Initial ability unlocks currently use in-game cash, so separate Robux unlock IDs are not required by the working purchase flow.

## Hold / confirm before creating
- **Refresh Ability** — preview price 99 Robux. If this is a one-off recharge, it should be a Developer Product, despite currently appearing under the Gamepasses tab. Clarify how it differs from the ability-specific recharges.
- **Skip Cooldowns** — preview price 99 Robux. Choose whether this permanently removes cooldowns (Game Pass) or skips one cooldown (Developer Product).
- **Kong recharge** — button shows 598 Robux, but Kong is intentionally unavailable. Leave it inactive.
- **Orbit triple hatch / Orbit auto-open** — not configured; the error text mentions these, but there is no agreed product, quantity or price. Do not create extra paid products based only on that message.
- **Custom emotes** — future 30-trophy emote shop needs suitable, permitted animation asset IDs per chosen emote, not Robux purchase products. The current inventory emote tab is still “Coming soon”; podium default emotes and players' existing avatar emotes use a separate system.

## No new IDs needed for the existing setup
Daily/playtime/free rewards themselves, their uploaded UI artwork, current pet artwork, the cash-priced ability unlocks, and the existing three music tracks already have their resources or use in-game data. Do not create a product for every free reward.

## Roblox reference
Roblox distinguishes permanent, one-time passes from repeatable Developer Products:
https://create.roblox.com/docs/production/monetization
https://create.roblox.com/docs/production/monetization/developer-products

