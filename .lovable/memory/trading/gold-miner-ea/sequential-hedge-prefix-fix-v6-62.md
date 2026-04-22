---
name: sequential-hedge-prefix-fix-v6-62
description: Gold Miner EA v6.62 — Sequential gate uses real hedge comment prefix GM_HEDGE_ instead of GM_HD
type: feature
---

Gold Miner EA v6.62 fixes the v6.61 regression where multiple hedge sets ran recovery simultaneously. Root cause: v6.61 filtered hedge orders with prefix `"GM_HD"`, but the EA actually emits hedge comments as `"GM_HEDGE_<n>"` (lines 877 / 7796). `StringFind("GM_HEDGE_6", "GM_HD") == 0` returned true (passed the filter), then `ParseGenerationFromComment` sliced from offset 5 → `"EDGE_6"` → `StringToInteger == 0` → returned `-1`. Net effect: `GetSequentialAllowedGeneration()` saw zero valid hedges, returned `-1`, and every set unfroze.

v6.62 changes:

```cpp
// ParseGenerationFromComment
if(StringFind(c, "GM_HEDGE_") == 0)
{
   string numStr = StringSubstr(c, 9);   // skip "GM_HEDGE_"
   int n = (int)StringToInteger(numStr);
   if(n >= 1) return n - 1;
   return -1;
}

// GetSequentialAllowedGeneration
if(StringFind(c, "GM_HEDGE_") != 0) continue;
```

Dashboard label updated to `Allowed Hedge: GenN (GM_HEDGE_(N+1))`. With one live hedge `GM_HEDGE_6` the gate now correctly returns Gen 5; only Set #6 (boundGen=5) runs recovery; Sets #1–#5 freeze until their hedge becomes the lowest live one. Toggle `InpHedge_SequentialRelease=false` still returns `-1` (full pre-v6.57 behavior).

No other logic changed: matching pool (v6.60), `ManageHedgeSets()` freeze, `ManageOrphanGrid()` gate (`gen > seqAllowed`), commentPrefix format, hedge slot persistence (v6.68), Triple Gate, BB filter, Balance Guard, initial entry rules (v6.59) all untouched.
