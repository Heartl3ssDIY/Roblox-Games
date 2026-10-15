# Gift parcels installed in Studio

Installed in **To be rich** on 16 September 2026, in Edit mode.

## Models and behaviour

- ServerStorage.GiftModels contains Rose, Sky, Violet, Mint, Amber and Coral.
- Each template has an invisible collision root and ten recolourable visual MeshParts, attached with Motor6Ds. Decorative pieces are massless and noncolliding; all names remain under 50 characters.
- The scheduled gift truck event now uses these six models. The existing schedule, gift count, reward table and odds are unchanged.
- Grab with the existing E/touch/controller proximity prompt. Base carry capacity is one, with existing upgrades up to five. Deliver by returning within the existing 45-stud radius of your own warehouse origin; delivery also checks ownership and height.
- Each gift rolls once when spawned. Dropping or reclaiming keeps that reward. Cash/crypto apply on delivery; weather and boost items enter the existing inventory; mutation rewards use the existing staged-parcel handling.
- Death, character removal or leaving drops carried gifts back into the active event. Expired events clean up remaining gifts.
- Duplicate/distant pickups, duplicate delivery, invalid rewards and rewards from destroyed gifts are rejected. Carried models use their actual height for spacing.

The imported source models and the original service are preserved in **ServerStorage.GiftImportBackup_20260916_051630**. The loose imports were moved there; active gifts appear through the event instead of remaining as unpickable preview props.

Updated script: ServerScriptService.Services.SpecialTruckService. The current local copy is SpecialTruckService.luau in this folder. Older local copies in other asset folders are superseded.

## Validation

- All six variants and 60 visual parts: colours, joints, names, collision settings and ground position checked.
- Pickup, distance rejection, competing pickup, base/upgraded carry limits, different-sized stack spacing, drop/regrab, leave cleanup, own-plot delivery and duplicate reward rejection passed isolated checks.
- All 16 RewardService entries exercised with mock currency/inventory: expected cash, crypto, inventory items and mutations; reward weights still total 100.
- Five event cases created and removed 95 gifts; scheduled start/end, forced expiry, same-day duplicate protection and town-building restoration passed.
- Visual check performed in Studio; temporary previews and test fixtures removed. Normal town-centre state restored.

No Play session was started. These checks do not exercise multiplayer replication, published animation permissions or live DataStore persistence. A later playtest should cover R6/R15 carrying, death during delivery and saving/rejoining.
