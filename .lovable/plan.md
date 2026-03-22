

## Fix: Grid Recovery ไม่เปิด Order — Reference Price ผิดทิศ (v5.12 → v5.13)

### สาเหตุที่ Grid Recovery ไม่เปิด Order ชุด E

เมื่อ hedge set เข้า recovery mode (`hedgeTicket = 0, gridMode = true`) → `ManageGridRecoveryMode()` ทำงาน → พยายามเปิด grid order ใหม่

**ปัญหาอยู่ที่ line 6754-6765 + 6783-6807:**

ถ้ายังไม่มี GM_HG grid order → `lastGridPrice` ใช้ราคาของ **bound orders** (order ที่ค้างอยู่ด้านล่าง) เป็น reference

ตัวอย่าง Group E:
- Bound orders = SELL orders ค้างที่ราคาต่ำ (เช่น 4435)
- `hedgeSide = POSITION_TYPE_BUY` (hedge เดิมเป็น BUY)
- ราคาปัจจุบัน = 4465 (สูงกว่า bound orders)

Distance check สำหรับ BUY:
```text
distance = (lastGridPrice - currentAsk) / point
         = (4435 - 4465) / point
         = -3000  ← ติดลบ! → ไม่เปิด order
```

**Grid recovery ต้องการเปิด BUY order ที่ราคาปัจจุบัน** เพื่อเมื่อราคาขึ้นจะได้กำไรไป matching close กับ SELL ที่ค้าง — แต่ distance logic ตรงข้าม ทำให้ไม่มีทางเปิดได้เลย

### การแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. แก้ Reference Price ใน `ManageGridRecoveryMode()` — กรณีไม่มี Grid Order

เมื่อ `hedgeTicket == 0` (recovery mode) และยังไม่มี GM_HG grid orders → **เปิด order แรกทันที** ที่ราคาตลาดโดยไม่ต้องเช็ค distance

```text
เดิม (line 6754-6765):
  if(lastGridPrice <= 0)
  {
     for bound orders → lastGridPrice = bound order price
  }
  if(lastGridPrice <= 0) return;

ใหม่:
  if(lastGridPrice <= 0 && currentGridCount == 0)
  {
     // Recovery mode: no grid orders yet → open first grid at market immediately
     double nextLot = InitialLotSize;
     string comment = "GM_HG" + IntegerToString(idx+1) + "_GL1";
     ENUM_ORDER_TYPE orderType = (g_hedgeSets[idx].hedgeSide == POSITION_TYPE_BUY)
                                ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
     if(OpenOrder(orderType, nextLot, comment))
     {
        g_lastHedgeGridTime = TimeCurrent();
        Print("GRID RECOVERY Set#", idx+1, " opened first grid order");
     }
     return;
  }
  if(lastGridPrice <= 0) return;
```

#### 2. แก้ Grid Order ถัดไป — ใช้ Grid Order ล่าสุดเป็น Reference (ไม่ใช่ Bound Order)

เมื่อมี GM_HG grid orders แล้ว → `lastGridPrice` จะได้จาก loop ที่ line 6730-6751 → distance check ทำงานถูกต้องเพราะ reference เป็น grid order ที่อยู่ในโซนราคาปัจจุบัน

ไม่ต้องแก้ไขเพิ่มเติม — fallback ไป bound order price จะไม่ถูกใช้อีกเมื่อมี grid order แล้ว

#### 3. รวมแผน v5.13: Cycle Recycling + Dashboard Styling

ตามแผนที่อนุมัติก่อนหน้า:

**Cycle Recycling:**
- เพิ่ม `FindLowestFreeCycle()` — สแกน cycle 0-6 หา slot แรกที่ว่าง
- แก้ 6 จุด INIT order จาก `g_currentCycleIndex++` → `g_currentCycleIndex = FindLowestFreeCycle()`

**Dashboard Styling:**
- `colW`: 68 → 90
- `rowH`: 32 → 36
- สีพื้นหลังสว่างขึ้น: rows `C'55,60,72'`/`C'45,50,62'`, header `C'80,40,120'`
- Font size min: 8

#### 4. Version bump: v5.12 → v5.13

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL/Trailing)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Hedge Guards (cycle-aware, squeeze directional block)
- Normal Matching Close logic

