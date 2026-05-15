---
name: Golden2 v2.8.3 Match-Close Win-Pool Gate + Recovery Grid + Per-Grid Dashboard
description: TryMatchingCloseForGroup gate now uses winProfit (winning side pool) instead of netCheck so deeply negative groups can still match-close; PlaceRecoveryGridIfNeeded auto-opens RC#N market order on residual losing side; Hedging dashboard adds per-pair Grid#N (Loss/Hedge/Net) rows + Recovery row.
type: feature
---

## Bug
Hedging Table showed `G1* ACTIVE P/L=-2981.59  Gate Cy:Ready Z:OUT OK 2468pts  TripleGrid G:$484.08/$100.00` (every gate green) but Triple-Gate matching close NEVER fired and no orders closed. Root cause at `TryMatchingCloseForGroup`:
```
double netCheck = plBuyMain+plSellMain+plBuyHedge+plSellHedge; // -2981
if(netCheck < InpExitMinNetUSD) return; // -2981 < 1.0 → bail forever
```
`netCheck` is the WHOLE group floating P/L which stays deeply negative whenever the losing side is bigger than the hedge — yet matching close exists precisely to USE the winning side profit ($484) to shred the losing side.

## v2.8.3 changes (`public/docs/mql5/Golden2_EA.mq5`)

### Gate fix (one line)
- Replaced `if(netCheck < InpExitMinNetUSD) return;` with `if(winProfit < InpExitMinNetUSD) return;`. `winProfit = plMain+plHedge` of the side price ran toward (already computed). MinGain (gain since hedge) gate kept verbatim.
- Added `Golden2 v2.8.3: G%d MATCH-CLOSE win=%s pool=$... lossBefore=N lossAfter=N` log so journal proves the close fired.

### Recovery Grid (RC#N) — new
- New inputs: `InpRecovery_Enable=true`, `InpRecovery_StartLot=0.0` (0=use largest residual ticket lot), `InpRecovery_Multiplier=1.5`, `InpRecovery_DistancePips=0` (0=reuse `GridLoss_Points`), `InpRecovery_MaxLevels=5`.
- New global `int g_groupRecoveryLevel[51]` (cleared OnInit + group-empty branch).
- New `PlaceRecoveryGridIfNeeded(g, losSide)` opens market BUY/SELL on losing side with comment `G{n}_{B|S}_RC#N` (uses MakeComment, no comment-format change). Auto-called once per match-close cycle when residual remains. RC tickets parse as `gp==g` so they join next match-close cycle naturally.

### Hedging dashboard rows (Gold-Miner style)
For every hedge-active group, after `Gate` + `TripleGrid`:
- `Grid#N  L:-... H:+... N:+/-...` per GL#N pair (capped by `InpDashGridPairsMax=5`, losing side detected via `min(plBuyMain, plSellMain)`).
- `Recovery RC#N/Max  mult=1.50` only when `g_groupInRecovery[g]`.

### Version bump
- Header / `#property version "2.83"` / `#property description` / dashboard title `Golden2 EA v2.8.3` / init log `v2.8.3 ... ExitGate=Squeeze-TF3-Latch+WinPool ... RecoveryGrid=...` all aligned.

## Rules of Steel — UNTOUCHED
- ❌ Entry SMA/INSTANT/PENDING flow, Squeeze BB/KC/ADX/EMA/ATR computation
- ❌ Grid Loss/Profit lot/distance/candle confirm/ATR snapshot
- ❌ Hedge mirror 1:1 / pending hedge / arm/disarm / Block percent / Force-close opp unhedged
- ❌ Avg TP/SL / Per-order trail / Bar-close trail / Cost-Hit / Accumulate
- ❌ ParseComment / MakeComment B_/S_ side tags (RC#N reuses MakeComment)
- ❌ ATR/ADX TesterHideIndicators wiring (v2.8.1)
- ❌ Sequential Queue / MinGainUSD / Squeeze TF3 latch close logic (v2.8.0/v2.8.1) — only the abs-net guard line changed
- ❌ Prior-group advance guard (v2.8.2)

## Rule
**Triple-Gate matching close MUST gate on winning-side pool, NEVER on whole-group net.** When the losing side outweighs the hedge, full netCheck stays negative even when winProfit covers MinNetUSD; gating on netCheck guarantees deadlock.
