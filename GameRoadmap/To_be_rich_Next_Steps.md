# To be rich — next steps

Updated 16 September 2026. Based on the current Studio models and scripts. These are future tasks, except the gift integration marked complete below. Chairs are deferred as requested. The UI redesign stays with you.

## Completed this session

- [x] Recolour all six imported gift variants: Rose, Sky, Violet, Mint, Amber and Coral.
- [x] Install them as the gift event's templates, with separate recolourable pieces attached to one collision body.
- [x] Connect pickup, carrying, dropping and delivery to the existing rewards. Each parcel keeps its individual reward roll; colours do not change reward odds.
- [x] Block duplicate pickups/rewards, distant pickups, invalid rewards and delivery to another player's warehouse. Return gifts on death or leaving; space different-sized carried gifts apart.
- [x] Check six variants, carry upgrades, all 16 reward entries, and five event cases containing 95 gifts. No Play session was started. Multiplayer animation, network behaviour and real saving still need a later playtest.

## Fix first

- [ ] **Worker shift cleanup can lose carried parcels.** `WorkerService.despawnPlot` calls `releaseCarry`, which clears `w.carry`, then passes `w.carry` to restaging. Preserve the whole carried batch before releasing it, and return every parcel safely. Evidence: `WorkerService`, lines 174–178 and 269–275.
- [ ] **Guards need to recognise actual theft.** Guards and CCTV currently use the total carried-parcel count, including a player's own parcels. Record the original owner and use that to decide whether a player is stealing from this warehouse. A damaged guard also needs to remember its attacker instead of treating the nearest passer-by as responsible. Evidence: `ManualLoadService.carryCount`, `GuardService.stepGuard`, `CCTVService.step`.
- [ ] **Guards and cameras need wall checks.** Guard damage is a random hit roll without a raycast; CCTV detection uses the ground ring and range without checking visibility. Check for obstructions before detecting or damaging a target. Evidence: `GuardService` lines 158–164; `CCTVService` lines 293–308.
- [ ] **Gun shots must start at the actual gun.** The server accepts a client-supplied shot origin when it is a Vector3. Use the equipped gun's muzzle, validate finite aim values and retain ownership, night and cooldown checks. Evidence: `SecurityGunService.fire`, lines 39–58.
- [ ] **Rotate the cabinet and armoury with each warehouse.** Both still use old desk-position offsets without rotating the placement. Add movable cabinet/rack anchors, as the laptops already use. Evidence: `TrophyService.ensureCase`, `SecurityArmouryService.ensureRack`.
- [ ] **Update guard patrols and CCTV ground height.** Patrol bounds ignore wall rotation and movement travels straight through obstacles. CCTV assumes ground height 0.35. Use plot-local patrol points, obstacle-aware movement and the real ground surface. Evidence: `GuardService.footprint/waypoints/stepGuard`, `CCTVService.FLOOR_Y`.

## Receiving, carrying and animations

- [ ] **Show parcels leaving the receiving truck.** Currently cargo disappears and new parcels appear directly in staging, 0.05 seconds apart. Add a short unload movement from the open truck to staging, without changing production balance.
- [ ] **Give workers a proper walk-and-carry animation.** Walking is deliberately stopped while carrying, so the legs glide. Combine moving legs with a stable upper-body carry pose; replace whole-body pickup tilting with a bend, reach and lift.
- [ ] **Make ordinary parcel carry spacing follow parcel size.** Worker offsets and the player's two-column stack use fixed spacing. Large parcels can overlap. Add stable joints, two-handed poses and distinct pickup/place/drop animations. Give the new gifts a proper multi-carry pose too; their current spacing is corrected, but they still stack up from the hand.
- [ ] **Improve route and loading feedback.** Guide players to the correct bay, show why a bay cannot accept a parcel, and separate “parcel loaded” from “cash paid.” The current manual-load message shows money while payout occurs when the truck departs.
- [ ] **Plan staging for mixed box heights.** Upper layers use fixed 2.7-stud spacing, so smaller boxes can appear suspended. Use shelves, pallets or supported stacks. Keep gameplay parcel placement controlled; reserve loose physics for deliberate drops.
- [ ] **Test interruption cases.** Full bays, disconnects, shift changes, death, theft, event expiry and simultaneous pickups should never duplicate or silently lose items. Reward persistence should eventually record successful redemption so a save failure can be handled safely.

## Buying and equipping

- [ ] **Laptop purchase pass.** Keep the rebuilt Dell, HP and MacBook. Confirm Tier 1 → Tier 2 ($50k) → Tier 3 ($100k), free switching between owned tiers, correct scale/orientation on every plot, and persistence after rejoining. Refresh only the furniture that changed, report placement errors, and reject non-integer tier selections.
- [ ] **Security shop pass.** Verify the Level 15 gate, progressive CCTV/guard/gun upgrades, insufficient-funds responses, owned/equipped states, night-only gun availability and save/load behaviour. Test ownership and currency saving together.
- [ ] **Weapon behaviour pass.** Add proper equip/idle/aim/fire/reload animations, muzzle attachments and readable impact effects. Decide whether the shotgun should use multiple pellets; the present server path fires one ray for every gun type. Keep the black-market weapon and security armoury clearly distinguished.
- [ ] **Trophy display pass.** Keep unlock/save rules and all 15 display slots working with the rebuilt cabinet. Give earned trophies clear names, lighting and placement previews.

## Blender build list

- [ ] **Trophy cabinet:** simple frame, shelves, glass, doors/handles, subtle lights, and 15 named display slots. Separate recolourable materials.
- [ ] **Trophy set:** gold/silver/bronze cups, star, crown, shield, medal, diamond, obelisk, globe, rocket, bolt, coins, skull and plaque. These 15 types already exist in the game; give them one consistent visual style.
- [ ] **Armoury rack:** wall/office rack, separate weapon holders and purchase/display positions.
- [ ] **Player weapons:** Gun 1, Gun 2, shotgun and the separate black-market gun; preserve tool handles and add muzzle/grip attachments.
- [ ] **Guard weapons:** standard and upgraded gun, with correct hand grips. Fix attachment placement so the whole model moves together, rather than moving its base before welding the other pieces.
- [ ] **Security cameras:** fixed wall bracket, separate rotating head, lens and status light; optional visible freeze-ray upgrade and damaged state.
- [ ] **Security guards:** two recognisable R15 guard appearances, uniforms, belts and vest upgrade. Keep the existing compatible rig and make the visual parts around it; create matching patrol, alert, aim, shoot and downed animations.
- [ ] **Foliage kit:** a few tree silhouettes, low bushes/hedges, planters, grass patches and small rocks. Simple Roblox shapes, matte surfaces and modest part counts.
- [ ] **Map dressing:** footpaths between plots and the town centre, kerbs, streetlights, benches, bins, directional signs and small planted areas. Place scenery at road edges and between plots; keep loading aprons, truck routes, entrances and gift collection space clear.

The warehouses, trucks, regular parcels, gift parcels, laptops and town-centre buildings already have rebuilt assets. Finish their integration and polish before rebuilding them again. Chairs remain deferred. The car dealership remains a later project.

## UI handoff

Keep a checklist for your redesign: reliable laptop close button, consistent back/close actions, mobile/touch and controller support, owned/equipped/locked/pending purchase states, useful errors, gift carry capacity, event countdown and reward results. The old close-button issue is user-reported; it was not reproduced in Play during this review.

Suggested order: **parcel safety and security rules → animations and purchase checks → cabinet/security models → foliage and paths → connect your redesigned UI.**

## Reference

Read-only snapshots of the scripts reviewed are in the `ReviewedScripts` folder beside this file. They are evidence for these notes, not replacement files to paste over newer Studio work. This review identifies code behaviour; it does not claim a full multiplayer or visual animation test.
