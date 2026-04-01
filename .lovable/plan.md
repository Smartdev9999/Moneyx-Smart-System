



## Implemented: v6.18 — Generation-Aware DD Hedge Isolation

### Changes Made

1. **`CheckAndOpenHedgeByDD()`**: Added `ExtractGeneration()` filter — only counts DD from orders matching `g_cycleGeneration`. Old generation orders (GM, GM1, etc.) no longer trigger new hedges.

2. **`CountUnboundOrders()`**: Added optional `genFilter` parameter. When `genFilter >= 0`, only orders with matching generation are counted. Existing callers (expansion mode) unaffected (default = -1).

3. **`OpenDDHedge()`**: Binding loop now filters by `g_cycleGeneration` — prevents new hedge sets from binding orders from older generations.

4. **Dashboard**: Added "DD Scope" row showing which generation is being monitored (e.g., `Scope: GM1 (Gen 1)`).

5. **Version bump**: v6.17 → v6.18

### กฎที่บังคับใช้

```text
Generation Isolation (v6.18):
- DD calculation ดูเฉพาะ order ของ generation ปัจจุบัน
- Hedge Set#1 bind เฉพาะ GM → cycle ขยับเป็น GM1
- DD Hedge รอบถัดไปดูเฉพาะ GM1 เท่านั้น
- GM เดิมไม่ถูกเอามาคิด DD เปิด Hedging2

Expansion Gate (Gate 1) — บังคับทุกโหมด:
- Case A: Hedge ตอน Expansion → รอ all TFs Normal
- Case B: Hedge ตอน Normal/Squeeze → รอ TF ใหญ่ Expansion 1 รอบ → all TFs Normal
- ทั้ง Expansion-triggered และ DD%-triggered ต้องผ่านเหมือนกัน

Set Independence:
- แต่ละ set track expansion/zone/distance แยกกัน
- IsTicketBound() ป้องกัน bind ซ้ำ
- Matching/Grid recovery ทำงานแยกชุด
```

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Gate 2 (Price Zone) + Gate 3 (TP Distance) — ไม่แก้
- Matching Close / Grid Mode logic ภายใน — ไม่แก้
- Accumulate Close — ทำงานรวมเหมือนเดิม
- DD% trigger logic threshold (InpHedge_DDTriggerPct) — ไม่แก้ค่า
- Bound ticket isolation (IsTicketBound) — ไม่แก้
- Orphan Recovery / Squeeze detection — ไม่แก้
- Expansion hedge OpenHedge() — ไม่แก้ (ใช้ CountUnboundOrders default genFilter=-1)
