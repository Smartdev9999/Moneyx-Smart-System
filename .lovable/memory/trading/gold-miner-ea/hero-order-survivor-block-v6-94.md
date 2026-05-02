---
name: Gold Miner EA v6.94 — Hero Order Survivor-Only Block
description: Hero formed only when side count > N (was: first INIT became Hero); same-side INIT/GL/GP block fires only when non-Hero basket is empty (Hero survivor). Restores GL/GP behavior that v6.92/v6.93 broke.
type: feature
---

# Gold Miner EA v6.94

ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

## Bug from v6.93
Journal showed `v6.92 Hero BLOCK: side=POSITION_TYPE_BUY has 1 Hero — skip GM1_GL#1` immediately after first INIT → GL/GP never opened. Two root causes:
1. `BuildHeroTicketCache` tagged `min(n, InpHero_OrderCount)` newest = first INIT became Hero alone
2. `OpenOrder` blocked any side with `CountHeroOnSide > 0`, so the lone Hero blocked its own basket

## Fix v6.94
1. `BuildHeroTicketCache`: `if(n <= InpHero_OrderCount) continue;` — Hero forms only when basket exists beyond N
2. New helper `CountNonHeroMainOnSide(side)` — counts current-gen INIT/GL/GP that are not hedge/bound/Hero
3. New helper `ShouldBlockSameSideGridForHero(side)` — true only when `CountHeroOnSide>0 && CountNonHeroMainOnSide==0`
4. `OpenOrder` Hero block now uses `ShouldBlockSameSideGridForHero` (was raw `CountHeroOnSide>0`)
5. Cache audit log expanded to show `nonHeroBUY/nonHeroSELL` so user can see why block fires (or doesn't)

## ไม่เปลี่ยน
- ❌ Order execution / OrderSend / trade.PositionClose
- ❌ Grid Loss / Grid Profit lot/distance/candle confirm formulas
- ❌ Hedge / Triple-Gate / Matching close / Recovery
- ❌ Trailing SL value calculation (only Hero exclusion guard from v6.93 retained)
- ❌ DD% TP / Daily Target / Balance Guard / News / License / Sync
- ❌ ManageHeroSameSideClose semantics (still closes Hero with same-side basket per v6.93)

## Behavior matrix
| Side count | Hero count input | Heroes formed | Block GL/GP? |
|------------|------------------|---------------|--------------|
| 1          | 1                | 0             | No           |
| 2          | 1                | 1             | No (1 non-Hero) |
| 3          | 2                | 2             | No (1 non-Hero) |
| basket-trail closes 1 non-Hero, leaves 2 Hero | 2 | 2 | YES (Hero survivor) |
