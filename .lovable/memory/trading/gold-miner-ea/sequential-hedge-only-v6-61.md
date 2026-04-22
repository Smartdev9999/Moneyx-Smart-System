---
name: sequential-hedge-only-v6-61
description: Gold Miner EA v6.61 — Sequential gate scans hedge comments only; orphans never block next hedge generation
type: feature
---

Gold Miner EA v6.61 fixes the v6.60 freeze where `GetSequentialAllowedGeneration()` stayed pinned to Gen 0 forever after a matching close because released bound losses (`GM_GL#*`) remained as orphans and re-parsed to Gen 0. The helper now skips every comment that does not start with `GM_HD`, so only live hedge tickets contribute to the allowed-generation calculation:

```cpp
if(StringFind(c, "GM_HD") != 0) continue;
int gen = ParseGenerationFromComment(c);   // GM_HD1→0, GM_HD2→1, ...
```

Behavior:
- Hedge #1 (Gen 0) + Hedge #2 (Gen 1) active → allowed = 0, only Set#1 runs recovery
- Set#1 matching close → `GM_HD1` closed, bound loss released as orphan → next tick allowed = 1, Set#2 activates immediately
- All hedge sets closed (only orphans remain) → allowed = -1 → full trading + free orphan recovery

`ManageOrphanGrid()` gate changed from `gen != seqAllowed` to `gen > seqAllowed`: orphans whose generation is older than or equal to the oldest active hedge gen recover in parallel; orphans newer than the active hedge gen freeze until the older hedge is resolved.

Dashboard row shows `Seq Release | ON | Allowed Hedge: GenN (GM_HD(N+1)) | New cycles: ALLOWED | Frozen Hedge: X | Frozen Orphans: Y` or `ON | No active hedge — full trading + free orphan recovery`. With `InpHedge_SequentialRelease = false`, returns -1 and behavior matches pre-v6.57.
