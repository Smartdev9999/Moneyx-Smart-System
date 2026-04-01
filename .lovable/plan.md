



## Implemented: v6.19 — Expansion Hedge Generation-Aware (ต่อจาก v6.18)

### Changes Made

1. **`CheckAndOpenHedge()` (Expansion mode)**: เปลี่ยน `CountUnboundOrders()` จากนับทุก generation → นับเฉพาะ `g_cycleGeneration` เพื่อไม่ให้ bind order ข้าม generation

2. **Binding loop ใน `CheckAndOpenHedge()`**: เพิ่ม `ExtractGeneration(cmt)` filter — bind เฉพาะ order ที่ตรงกับ `g_cycleGeneration` เท่านั้น

3. **Version bump**: v6.18 → v6.19

### กฎที่บังคับใช้

```text
Generation Isolation (v6.18 + v6.19):
- DD calculation + Expansion binding ดูเฉพาะ order ของ generation ปัจจุบัน
- Set#1 bind เฉพาะ GM → cycle ขยับเป็น GM1
- Set#2 bind เฉพาะ GM1 → cycle ขยับเป็น GM2
- Set#3 bind เฉพาะ GM2 → สามารถเปิดได้ ✅
- order generation เก่าไม่ถูกเอามาคิด DD หรือ bind ใหม่

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
- DD% trigger logic (CheckAndOpenHedgeByDD / OpenDDHedge) — ไม่แก้ (แก้ไปแล้วใน v6.18)
- Bound ticket isolation (IsTicketBound) — ไม่แก้
- Orphan Recovery / Squeeze detection — ไม่แก้
- Expansion hedge OpenHedge() trigger logic — ไม่แก้ (แก้เฉพาะ scope ของ order ที่นับ/bind)
