

## แก้ไข Reverse Hedge Logic — Gold Miner EA v6.7 → v6.8

### ภาพรวม 2 ส่วนที่ต้องแก้

---

### ส่วนที่ 1: เปิด Reverse Hedge แบบ NET + ล็อค TP/SL เมื่อเท่ากัน

**หลักการ:**
```text
เปิด Reverse Hedge:
  1. สแกนทุก order (Buy, Sell, Bound, Hedge, Grid Hedge, Reverse เก่า)
  2. รวม totalBuyLots vs totalSellLots
  3. ส่วนต่าง NET = |buyLots - sellLots|
  4. NET > 0 → เปิด Reverse Hedge ขนาด NET ในฝั่งที่น้อยกว่า
  5. NET = 0 → ไม่เปิด Reverse BUT ระบบต้องถอด TP/SL/Matching Close
     เพื่อไม่ให้ order ถูกปิดไปก่อน (ล็อคทั้ง 2 ฝั่งเป็น hedge pair)
  6. ไม่จำกัดจำนวน Reverse — ทุกครั้งคำนวณ NET ใหม่ทุก order

เมื่อ order เท่ากัน (balanced):
  - g_hedgeBalancedLock = true
  - ManageTPSL / ManageMatchingClose ข้ามการทำงานเมื่อ flag นี้เปิด
  - ระบบยังเปิด order ฝั่ง trend-following ได้ตามปกติ
  - เมื่อมี order ใหม่ → NET ≠ 0 อีกครั้ง → flag ถูก reset
```

**แก้ไขในโค้ด:**

1. **`CheckAndOpenReverseHedge()`** — ลบ `g_reverseHedgeActive` guard, เปลี่ยนการนับ lot จาก "เฉพาะ hedgeSide" เป็น "รวมทุก order ทั้ง 2 ฝั่ง", เก็บ ticket ใน array แทน single variable

2. **Global ใหม่:** `g_hedgeBalancedLock` (bool), `g_reverseHedgeTickets[]` (ulong array), `g_reverseHedgeCount` (int)

3. **Guard conditions ใน ManageTPSL / ManageMatchingClose:** เพิ่ม `if(g_hedgeBalancedLock && g_hedgeSetCount > 0) return;` — ข้าม TP/SL/Matching Close เมื่อระบบอยู่ในสถานะ balanced lock

4. **Reset flag:** ทุก tick ใน OnTick ก่อนเรียก hedge management ให้เช็ค NET ใหม่ → ถ้า NET ≠ 0 → `g_hedgeBalancedLock = false`

---

### ส่วนที่ 2: Recovery Grid หลัง Normal — Dual-Track

**หลักการ:**
```text
เมื่อกลับ Normal → ManageReverseHedge / ManageHedgeMatchingClose:
  1. สแกนทุก order ไม่จำแนกชุด → กำไร vs ขาดทุน
  2. Matching close: เอากำไรรวมหักลบขาดทุนรวม ปิดให้ได้มากที่สุด
  3. Order ที่เหลือ (ติดลบ) → แบ่ง 2 กลุ่มสำหรับ Grid Recovery:

  Track A: Bound Orders ที่เหลือ
    → เปิด Grid Recovery แบบเดิม (ไม่เปลี่ยน)

  Track B: Hedge + Reverse Orders ที่เหลือ (GM_HEDGE + GM_RHEDGE)
    → รวม lot ทั้ง 2 ตัว เป็น "combined hedge lots"
    → เปิด Grid Recovery ชุดใหม่ (GM_HG_COMBINED)
    → คำนวณ EquivGridLevel จาก combined lots
    → ทำงานแยกจาก Track A

  เมื่อ Track ไหนปิดครบ → reset track นั้น
  เมื่อทั้ง 2 tracks ปิดครบ → deactivate hedge set ทั้งหมด
```

**แก้ไขในโค้ด:**

5. **`ManageReverseHedge()`** — เมื่อ Normal:
   - สแกน **ทุก order** (ไม่จำแนก bound/hedge/reverse) 
   - รวมกำไรทั้งหมดเป็น budget → matching close กับขาดทุนทั้งหมด (เก่าสุดก่อน)
   - ปิด reverse hedge order หลัง matching

6. **HedgeSet struct เพิ่ม fields:**
   - `bool combinedGridMode` — Track B active
   - `int combinedGridLevel` — level สำหรับ combined hedge+reverse
   - `double combinedLots` — combined lot size
   - `ulong combinedTickets[]` — tickets ของ hedge+reverse ที่ต้อง recover

7. **`ManageHedgeGridMode()` แยก logic:**
   - เช็ค bound orders เหลือ → Track A (เหมือนเดิม)
   - เช็ค hedge+reverse เหลือ → Track B (ฟังก์ชันใหม่ `ManageCombinedGridRecovery`)
   - Track B: รวม lots ของ GM_HEDGE + GM_RHEDGE → คำนวณ grid level → เปิด grid ช่วยแบบเดียวกัน

8. **Recovery:** `RecoverHedgeSets()` สแกน GM_RHEDGE ทั้งหมดเข้า array + กู้ combined grid state

9. **Version bump:** v6.7 → v6.8

---

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Orphan Recovery system
- Grid Recovery Track A สำหรับ bound orders (logic เดิม 100%)
- TP/SL เดิมทั้งหมดทำงานปกติเมื่อไม่อยู่ในสถานะ balanced lock

