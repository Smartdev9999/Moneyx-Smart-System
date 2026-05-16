## ปัญหา — Recovery Lot โตเกิน multiplier

จากภาพ (mult = 1.4):
- RC#1 = 0.20
- RC#2 = 0.30 (ควร 0.28)
- RC#3 = 0.67 (ควร 0.39) ← เริ่มเพี้ยน
- RC#4 = 2.26 (ควร 0.55)
- RC#5 = 11.44 (ควร 0.77)

## Root Cause

`PlaceRecoveryGridIfNeeded` (line 2671-2692) คำนวณ `seedLot` ใหม่ทุกครั้งโดยสแกนหา **lot ใหญ่สุดของฝั่งติดลบทั้งกลุ่ม** — ซึ่งรวม `RC#` ตัวก่อนหน้าที่เพิ่งวางไปด้วย แล้วเอามาคูณ `Multiplier^(level-1)` อีกที → lot ทบบน lot ที่ทบไปแล้ว = exponential explosion

ลำดับที่เกิดจริง:
```
RC#2: seed=max(0.20)=0.20, level=2 → 0.20 * 1.4 = 0.28 → 0.30
RC#3: seed=max(0.30)=0.30, level=3 → 0.30 * 1.4^2 = 0.59 → 0.67  ← seed ดึง RC#2 มาเป็นฐาน
RC#4: seed=max(0.67)=0.67, level=4 → 0.67 * 1.4^3 = 1.84 → 2.26
RC#5: seed=max(2.26)=2.26, level=5 → 2.26 * 1.4^4 = 8.68 → 11.44
```

## แผน v2.9.0 — Recovery Seed Lock

### A) ล็อก seed lot ครั้งเดียวต่อ group (ไฟล์: `public/docs/mql5/Golden2_EA.mq5`)

- เพิ่ม global `double g_groupRecoverySeedLot[51];` (init = 0)
- ใน `PlaceRecoveryGridIfNeeded`:
  - ถ้า `g_groupRecoverySeedLot[g] <= 0` → คำนวณ seed ครั้งแรกเท่านั้น **โดย exclude RC# tickets** (parse tag ขึ้นต้น "RC" → ข้าม) แล้วเก็บค่าไว้
  - ครั้งถัดไปใช้ค่าที่ล็อกไว้เลย
- สูตร lot คงเดิม: `base * Multiplier^(level-1)` — แต่คราวนี้ `base` คงที่
- เคลียร์ `g_groupRecoverySeedLot[g] = 0` ในจุดเดียวกับที่เคลียร์ `g_groupRecoveryLevel[g]` (OnInit + group-flat housekeeping ~line 3774, 3948)

### B) Defensive — Exclude RC# จาก seed scan แม้ค่ายังไม่ถูกล็อก

ใน loop หา seedLot (line 2680-2687): ถ้า `StringFind(tag, "RC") == 0` → `continue;` กัน RC ตัวก่อนหน้ามาเป็นฐาน edge case อื่นๆ

### C) Log + Version

- Log line 2702: เพิ่ม `lockedSeed=%.2f` เพื่อ debug
- `#property version "2.90"`, description, dashboard title, init log → v2.9.0
- Init log: `RecoverySeed=LOCKED-First-NonRC`

### D) Memory

- สร้าง `.lovable/memory/trading/golden2-ea/v2-9-0-recovery-seed-lock.md`
- Append index entry

## สิ่งที่ไม่เปลี่ยนแปลง (Rules of Steel)

- ❌ `trade.Buy/Sell` execution
- ❌ Multiplier formula, MaxLevels, distance trigger, OnlyNewCandle gate
- ❌ `TryPlaceRecoveryGridContinuation` body (v2.8.8)
- ❌ Triple-Gate Match-Close, Reserve-Profit (v2.8.7), shred passes
- ❌ Recovery-Mode Order Lock (v2.8.9), Prior-Advance Bypass
- ❌ Hedge Orphan Offset (v2.8.6), One-Hedge-Per-Group (v2.8.5)
- ❌ Post-Match Avg Broker TP/SL (v2.8.4) — RC ยังคงเข้า avg ปกติ
- ❌ Entry/Squeeze/License/News/Time/Sync ทั้งหมด

## ผลที่คาด

ด้วย seed = 0.20 ล็อก, mult = 1.4:
- RC#1=0.20, RC#2=0.28, RC#3=0.39, RC#4=0.55, RC#5=0.77 — ต่อเนื่องเรียบ ไม่มีกระโดด
