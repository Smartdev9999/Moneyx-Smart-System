

## Fix: Grid Recovery ไม่เปิด Order + Hedge State หายหลัง Restart + Dashboard v5.21 (v5.20 → v5.21)

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

---

### สาเหตุหลัก: ไม่มี Restore Logic สำหรับ Hedge Sets

**Line 677-695 (OnInit):** ทุกครั้งที่ EA เริ่มใหม่ (recompile, TF change, restart) → reset ALL hedge sets เป็น `active=false, gridMode=false, boundTicketCount=0` → **ข้อมูล hedge ทั้งหมดหายไป**

```text
ผล:
1. Bound orders กลายเป็น orphan — ไม่มี set ดูแล
2. gridMode=false → ไม่มี ManageGridRecoveryMode ถูกเรียก
3. ออเดอร์ค้างอยู่ไม่มีใครแก้
```

ถึง `IsTicketBound()` จะ return false หลัง restart (เพราะ arrays ว่าง) → orders กลับมาเป็น normal orders ที่ normal grid มองเห็น — แต่ normal grid ต้องมี **initial price reference** ซึ่งอาจไม่มีสำหรับ orders ที่ถูกผูกอยู่ก่อนหน้า → grid ไม่ออก

---

### การแก้ไข

#### 1. เพิ่ม `RestoreHedgeSets()` ใน OnInit — กู้คืน Hedge State จาก Orders ที่มีอยู่

สแกน positions ที่มี comment `GM_HEDGE_`, `GM_HG` เพื่อ rebuild hedge sets:

```text
RestoreHedgeSets():
1. สแกนทุก position ที่มี MagicNumber + _Symbol
2. จับ GM_HEDGE_{N} → สร้าง set N: hedgeTicket, hedgeSide, hedgeLots, active=true
3. จับ GM_HG{N}_GL → สร้าง/อัปเดต set N: gridMode=true, เก็บ grid tickets
4. สแกน orders ที่ไม่มี hedge/grid comment → ตรวจสอบว่าเป็น counter-side ของ set ที่ active → ผูกเป็น bound tickets
5. ถ้ามี set ที่ gridMode=true + hedgeTicket=0 + boundTickets>0 → ready for recovery
6. คำนวณ g_hedgeSetCount, g_currentCycleIndex จาก suffix ใน comments
```

เพิ่มเรียกหลัง `RecoverInitialPrices()` ใน OnInit (line 635):
```cpp
RecoverInitialPrices();
RestoreHedgeSets();  // ← เพิ่ม
```

#### 2. เพิ่ม `RestoreCycleIndex()` — กู้ Cycle จาก Order Comments

สแกน comments ที่มี suffix `_A`, `_B`, ... `_J` เพื่อหา cycle สูงสุดที่ใช้อยู่ → set `g_currentCycleIndex` ถูกต้อง ใช้ `FindLowestFreeCycle()` หลัง restore เพื่อให้ cycle ใหม่เริ่มจากต่ำสุดที่ว่าง

#### 3. Dashboard — Side Symbol + ความกว้าง (จากแผน v5.21 ที่อนุมัติแล้ว)

- เปลี่ยน "B:" (Bound) → "BD:" เพื่อไม่สับสนกับ Buy
- เพิ่ม side ทุก mode: `H1:REC(S) BD:5`, `H1:B 0.15L BD:3`
- เพิ่ม `input int HedgeDashWidth = 500;` เพื่อปรับความกว้างได้
- ใช้ `HedgeDashWidth` แทนค่าคงที่

#### 4. อัปเดตกฎเหล็ก — เพิ่มกฎรวมแผน

เพิ่มใน `.lovable/rules.md`:
> เมื่อผู้ใช้ส่งข้อมูลหลายครั้ง (2-3 ข้อความ) ก่อน approve → รวมทุกอย่างเป็นแผนเดียว ไม่ต้องพูดซ้ำเนื้อหาเก่า ทำทีเดียวจบ

#### 5. Version bump: v5.20 → v5.21

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL/Trailing)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Hedge Guards (cycle-aware, squeeze directional block)
- Normal Matching Close logic
- Grid Recovery lot calculation + direction logic (ManageGridRecoveryMode)

