# Golden2 EA v2.7.5 — Entry Mode Hard-Gate

ไฟล์: `public/docs/mql5/Golden2_EA.mq5`

## ปัญหา
เลือก `InpEntryMode = INSTANT` แต่ยังเห็น BuyStop/SellStop ออกมา

## สาเหตุ
`PlaceInitialFrame()` ถูก gate แล้ว (บรรทัด 867 → ส่ง `PlaceInitialMarket` แล้ว return)
แต่ **`ManageInitialReArm()` (บรรทัด 1276-1326)** ยัง call `trade.BuyStop/SellStop` ทุก tick โดยไม่เช็ค `InpEntryMode` →
- v1.7 Re-arm after TP
- v2.6 Re-entry on close
- v2.70 Continuous frame maintenance
ทั้ง 3 path สร้าง pending stop ใหม่เสมอแม้อยู่ในโหมด INSTANT/SMA

## แก้ไข

### 1. Gate `ManageInitialReArm` (บรรทัด 1276)
หลังบรรทัด `if(!InpInitReArmAfterTP && !InpInitReEntryOnClose) return;` เพิ่ม:
```cpp
// [v2.7.5] Re-arm uses BuyStop/SellStop pendings — only valid in PENDING mode.
// In SMA/INSTANT modes, re-entry is handled by PlaceInitialMarket via the
// continuous-frame logic in OnTick (idle group → PlaceInitialFrame → market).
if(InpEntryMode != G2_ENTRY_PENDING) return;
```

### 2. ตรวจสอบ entry path สำหรับ SMA/INSTANT ทำงานต่อเนื่อง
เช็คว่าหลัง market position ปิด (TP/SL) แล้ว loop หลักใน OnTick ยังเรียก `PlaceInitialFrame(g)` ซ้ำ → routes to `PlaceInitialMarket` → market re-entry ทำงานปกติ (ไม่ต้องแตะ logic หลัก)

### 3. Bump version → v2.7.5
- `#property version "2.75"`
- `#property description` — สั้นลงตามที่ user ขอ:
  ```
  "Golden2 EA v2.7.5 — Entry Mode hard-gate. SMA/INSTANT no longer place BuyStop/SellStop via re-arm path. PENDING mode unchanged."
  ```
- Header comment block
- Dashboard L_TITLE → `Golden2 EA v2.7.5`
- OnInit log → `v2.7.5 initialized`

### 4. ปรับ description เก่าให้สั้นลง (ตามคำขอ user)
ลด description ของ inputs/version ก่อนหน้าที่ยาวเกินไป → เก็บแค่หัวข้อสั้นๆ เข้าใจง่าย

## สิ่งที่ "ไม่เปลี่ยนแปลง"
- ❌ ไม่แตะ `trade.Buy/Sell/PositionClose` ใน `PlaceInitialMarket`
- ❌ ไม่แตะ Hedge mirror (lines 1777-1803 — hedge ใช้ pending stop เสมอ ทุกโหมด)
- ❌ ไม่แตะ Grid Loss/Profit/Triple-Gate/Accumulate/Squeeze/BB
- ❌ ไม่แตะ v2.7.4 IsSideEffectivelySafeForAdvance / advance logic
- ❌ ไม่แตะ Trail (TrailIn/bar-close trail) — modify-only, ปลอดภัย
- ✅ PENDING mode เหมือนเดิม 100%
- ✅ INSTANT/SMA จะออกเฉพาะ market order, ไม่มี BuyStop/SellStop หลุดอีก

## Memory updates
- ลบ `mem://trading/golden2-ea/v2-7-3-entry-mode-pending-sma-instant.md` (ทับด้วย v2.7.5)
- เขียน `mem://trading/golden2-ea/v2-7-5-entry-mode-hard-gate.md`
- อัปเดต `mem://index.md`
