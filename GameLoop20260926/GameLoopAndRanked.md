# Game loop and ranked design — draft

No economy, rank system or battle-pass logic was installed by this task. Only character model candidates were imported to review storage. Confirmed intent below is separated from proposed values and open questions.

## Player journey

1. Short loading screen → optional guided first fight.
2. Play Story Arena 1 with a starter team.
3. Receive any first-clear gift and unlock that arena’s pack pool.
4. Spend cash on eligible packs → collect units → equip up to the game’s existing team size.
5. Complete Arenas 2 and 3; continue story, mastery and team upgrades.
6. Arena 3 clear unlocks Unranked and Ranked queues.
7. Ranked results change trophies and add ranked wins; eligible completed matches add Season XP.
8. Claim pass tiers during the month; settle ranked rewards at season end; rotate the Mystical store weekly.

## Confirmed direction

- Dragon Ball / Z / Super character choices come from you.
- Story arena completions unlock additional character pools; a gift unit is separate from pack eligibility.
- Cash earned through play buys packs; obtained units enter inventory and can be equipped into a team.
- Both ranked and unranked PvP unlock after Arena 3.
- Mystical units are excluded from normal arena packs. Intended sources: a rotating weekly Robux store or ranked rewards.
- The season pass has 45 levels; you will supply rewards and UI artwork.
- Top-100 ranked players should receive the selected Mystical unit plus other rewards such as XP cards / pack rewards.

## Counters and economy

- **Cash:** spendable currency for packs. Amounts and prices remain yours to set.
- **Season XP / Win Points:** one non-spendable pass-progress counter, not two currencies.
- **Ranked trophies:** proposed competitive rating, gained/lost through ranked results. Story completion is tracked separately in completion flags.
- **Season ranked wins:** leaderboard statistic. Do not use this interchangeably with trophies or XP.

The request initially suggests trophies also represent story progress. That does not reliably match collection strength: players completing the same story can own different units. The recommendation is to preserve the Arena 3 unlock and use progression grouping plus ranked rating. This is a proposal, not an implemented change.

## Recommendations awaiting approval

- Use 5 Season XP for a completed win and 2 for a completed loss, with 15 XP per reward tier. Monthly pass reset; daily tasks can refresh separately.
- Use story completion flags to group progression, and ranked trophies to measure PvP results. Story wins should not inflate competitive trophies.
- Treat season ranked wins as a separate leaderboard counter. Provisional simplest launch: global top 100 eligible players by ranked wins, with trophy total then head-to-head or earliest achievement as published tie-breakers.
- To reduce farming weaker opponents, use the highest league reached this season for reward eligibility, rating-based matchmaking, repeat-opponent limits and server-validated completed matches.
- Example trophy movement only: +20 for an even-rated ranked win, -15 for a loss, zero change for unranked. Tune after playtesting; do not ship these numbers as confirmed rules.
- Keep Mystical units within the same competitive power budget as top earnable units, with distinctive abilities/appearance. A rotating paid unit should not be required to compete.

## Pass pacing

Assuming 45 earnable tiers starting at tier 0, 15 XP per tier means **675 XP per month**. At 5 XP per win / 2 per loss: 135 all-win matches; 338 all-loss matches; roughly 193 matches at a 50% win rate, or about 6.4 matches/day over 30 days. At an assumed five-minute match that is roughly 16 hours per month, excluding queues. This match-length assumption needs testing.

The later 5-win / 10-loss wording reverses the incentive: 68 losses finish the same pass, versus 135 wins. Do not finalize that rule accidentally. A monthly reset and daily activity are compatible; daily tasks reset without wiping the monthly pass.

If level 1 is granted immediately, only 44 advances remain, giving 660 XP instead. User confirmation pending.

## Rank rewards and fairness

A fixed top 100 **per league** multiplies the number of winners and can reward staying in a low league. A global top 100 by raw wins rewards volume more than skill. These are distinct choices, not equivalent rankings. Suggested launch draft: eligible ranked wins leaderboard, trophy-based matchmaking, high-water league tracking, server validation, and explicit tie-breakers. Decide global versus per-league before implementation.

First-clear story gifts, pack-pool eligibility, pack ownership and mastery milestones must remain separate grants. Clearing an arena should not silently grant all units in its pool. Mystical acquisition is direct rotating-store purchase or ranked reward; none of the ordinary candidates are assigned Mystical.

## UI handoff

### PvP hub

- Ranked: current league, trophy total, progress to next league, season wins and countdown.
- Unranked: practise with no trophy gain or loss; show whether Season XP/cash is enabled once decided.
- Before Arena 3: both queue buttons explain the unlock requirement and offer Continue Story.
- After Arena 3: separate Find Ranked Match and Find Unranked Match buttons.

### Ranked queue / results

- Queue: team check, opponent search status, elapsed time and Cancel.
- Before match: own/opponent league and a readable team summary; no misleading guarantee of identical unit collections.
- Results: outcome, cash, Season XP and trophy change as separate rows; ranked-win counter updates only after a validated win.
- Leaderboard: clearly label global versus league scope, season identifier, tie-breakers and top-100 reward preview.

### Season pass / store

- Pass: current tier / 45, XP progress, monthly end date, claim states and reward slots supplied by you.
- Daily challenges, if added, show their own reset timer; they do not wipe monthly pass progress.
- Store: show the current Mystical unit, fixed Robux price, weekly rotation timer and ownership state.
- Rank rewards: show qualifying finish, claim deadline and duplicate policy once chosen.

## Server-side implementation outline for later

Persist cash, unit inventory, arena completion flags and unlock flags separately from seasonal XP, claimed pass tiers, ranked trophies, season wins and reward-claim state. All match awards should be computed on the server, once per match ID. Duplicate result delivery must not duplicate rewards. Reward tables and UI assets stay configurable until you supply them. Version season IDs, snapshot final standings, and make claims idempotent. Do not activate paid offers before their unit/price/rotation schedule is chosen.

## Open decisions

- Arena participants versus strongest known in the wider verse; provisional lists use each arena's story period.
- 5 XP per win / 2 per loss versus the later 5 / 10 wording.
- Does top 100 mean global or top 100 within every league? Per-league distribution creates far more winners and needs anti-deranking rules.
- Which modes award Season XP, whether story replays have caps, and whether draws grant anything.
- Trophy gain/loss values, league thresholds, matchmaking rules and the monthly trophy reset/soft-reset policy.
- Whether rank rewards are based on most wins or final trophies. The draft preserves your most-wins idea as a separate leaderboard.
- Cash amounts, pack costs/odds, gift units, mastery rewards and XP-card purpose.
- 45 earnable rewards from tier 0 (675 XP), or start at level 1 with only 44 advances (660 XP).
- Weekly store rotation time, price, reward unit schedule, late claims and duplicate Mystical compensation.
