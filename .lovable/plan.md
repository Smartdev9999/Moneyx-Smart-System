

## Implemented: v6.14 — Directional Expansion Agreement Gate

### Changes Made

1. **`CountDirectionalExpansion(int &outDir)`**: New helper that counts expansion TFs and checks directional agreement
   - Returns `outDir = 0` if BUY and SELL expansions co-exist (conflict)
   - Used consistently across all 3 entry points

2. **`CheckAndOpenHedge()`**: Replaced manual scan loop with `CountDirectionalExpansion()` — blocks entry when `bestDir == 0` (conflict)

3. **`CheckAndOpenReverseHedge()`**: Same replacement — blocks reverse entry when expansion TFs disagree

4. **Squeeze Filter block logic**: Updated to use `CountDirectionalExpansion()` — when `bestDir == 0` (conflict), directional block has no direction to block, so nothing is blocked

5. **Version bump**: v6.13 → v6.14 (all 5 locations)

### กฎที่บังคับใช้

```text
เปิด Hedge/Reverse ได้เมื่อ:
1. มี TF expansion ≥ MinTFConfirm
2. TF expansion ทั้งหมดต้องไปทิศทางเดียวกัน (BUY ล้วน หรือ SELL ล้วน)
3. ถ้ามี BUY+SELL expansion พร้อมกัน → bestDir = 0 → BLOCK
```

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Hedge matching close / partial close / grid recovery logic
- Reverse Hedge NET calculation / balanced lock
- Orphan Recovery system
- Squeeze state detection (BB/KC) — แค่เปลี่ยนวิธีตีความ direction
- v6.13 strict 3-TF normal gate + matching-first sequencing
