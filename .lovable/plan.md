


## Implemented: v6.17 — DD Hedge ต้องผ่าน Expansion Gate + Set แยกอิสระ

### Changes Made

1. **`IsHedgeCloseAllowed()`**: Removed `triggerType == 0` wrapper — Gate 1 (Expansion Cycle) now mandatory for ALL hedge types (Expansion & DD%)

2. **`OpenDDHedge()`**: Removed pre-pass `seenExpansionSinceHedge = true`. Now tracks actual biggest TF state at open time via `g_squeeze[2].state == 2`

3. **Dashboard**: Removed "Skip(DD)" status. All sets now show real cycle status: "Wait Exp" / "Wait Norm" / "Ready"

4. **Version bump**: v6.16 → v6.17

### กฎที่บังคับใช้

```text
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
- DD% trigger logic (CheckAndOpenHedgeByDD) — ไม่แก้การเปิด
- Bound ticket isolation (IsTicketBound) — ไม่แก้
- Orphan Recovery / Squeeze detection — ไม่แก้
