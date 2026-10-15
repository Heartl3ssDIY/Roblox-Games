# Anime Combat Units — Season 1 Battle Pass concept

This version follows the user's edited layout: a gold-framed panel, blue **Free** lane, pink **Paid** lane, purple level rail, and a horizontally scrolling 45-level track. Only the level-one coin and diamond cards are filled. Later rewards are deliberately blank until the reward schedule is supplied.

## View and edit

- Open [the interactive preview](./preview/index.html) to try the scrolling track and simulated match progression. The small **Demo controls** button is for review only.
- Drag [battle-pass-edited.svg](./figma-svg-edited/battle-pass-edited.svg) into Figma for the full design at 1095 × 729. [BattlePass_UserEdit_Figma_Import.zip](./figma-svg-edited/BattlePass_UserEdit_Figma_Import.zip) also contains reusable background, lane, and reward-card SVGs plus the project font.
- The frame, pattern, rail, cards, and text are SVG elements. The coin and diamond illustrations inside the first reward cards are the user's supplied raster artwork. The gray editor background in the reference image is excluded from the SVG.

The 1499 price button is a visual mockup. The preview does not charge Robux or grant paid access when it is clicked. A developer-only toggle can simulate owning the paid pass. No files have been uploaded to Figma or Roblox Studio.

## Prototype behavior

The pass has 45 levels at 15 Battle Pass XP each, separate from account XP. A win gives 5 pass XP and 10 trophies; a loss gives 2 pass XP and removes 4 trophies, with a floor of zero. A forfeit removes up to 3 XP from the current level only and never reverses a completed level. The first free card can be claimed after level one; the first paid card additionally requires the developer premium toggle. Reward amounts, levels 2–45, the actual paid pass price and purchase flow, and season rollover remain to be specified.
