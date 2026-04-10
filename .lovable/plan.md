

## v6.44 — Fix TP ไม่ทำงานใน Live Trading (2 ปัญหาซ้อนกัน)

### สาเหตุที่พบ (Root Cause)

มี **2 ปัญหาซ้อนกัน** ทำให้ TP ไม่ทำงานเลยใน Live:

**ปัญหาที่ 1: Dollar TP ถูก block โดย `EnablePerOrderTrailing`**
- `UseTP_Dollar = true` (default) แต่ code อยู่ใน `if(!EnablePerOrderTrailing)` (lines 2122, 2198, 4794, 4857)
- `EnablePerOrderTrailing = true` (default) → `!true = false` → **Dollar TP ไม่เคยถูก check เลย**
- Per-Order Trailing เป็นระบบจัดการ SL ของแต่ละออเดอร์ → ไม่ควร block basket TP

**ปัญหาที่ 2: SyncBrokerTPSL ไม่ถูกเรียก**
- Line 1371: `if(UseTP_Points || ...)` → `UseTP_Points = false` (default) → `SyncBrokerTPSL()` ไม่ถูกเรียกเลย
- ปัจจุบัน SyncBrokerTPSL รองรับแค่ Points mode → ไม่ครอบคลุม Dollar/Percent TP

**ผลลัพธ์**: ทั้ง EA-side TP และ Broker-side TP ถูก disable พร้อมกัน → ไม่มี TP ใดๆ ทำงาน

### แผนแก้ไข — ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Version bump → v6.44

#### 2. Fix Dollar/Percent TP — ลบ `!EnablePerOrderTrailing` guard ออกจาก TP checks

Per-Order Trailing = ระบบจัดการ **SL** ของแต่ละออเดอร์ (breakeven + trailing)
Basket TP = ระบบปิดกำไร **ทั้งชุด** เมื่อถึงเป้า

ทั้งสองเป็นคนละระบบ ไม่ควร block กัน:

```text
// Lines 2122-2126 (ManageTPSL BUY)
Before: if(!EnablePerOrderTrailing) {
           if(UseTP_Dollar && plBuy >= TP_DollarAmount) closeTP = true;
           if(UseTP_PercentBalance && ...) closeTP = true;
        }
After:  if(UseTP_Dollar && plBuy >= TP_DollarAmount) closeTP = true;
        if(UseTP_PercentBalance && ...) closeTP = true;

// Lines 2198-2202 (ManageTPSL SELL) — same fix
// Lines 4794-4799 (ManageTPSL_TF BUY) — same fix
// Lines 4857-4863 (ManageTPSL_TF SELL) — same fix
```

#### 3. Extend SyncBrokerTPSL — รองรับ Dollar TP ด้วย

แปลง Dollar amount เป็นราคา TP แล้ว set ลง broker:
```text
// Dollar TP → Price conversion:
tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
totalBuyLots = total lots of BUY positions;

priceDistance = (TP_DollarAmount / (totalBuyLots * tickValue / tickSize));
tpBuy = avgBuy + priceDistance;
```

- TP Dollar: คำนวณจาก avg + (dollarTarget / lots * tickValue)
- TP Percent: คำนวณจาก avg + (balance * pct / 100 / lots * tickValue)
- TP Points: คำนวณจาก avg + points * point (เหมือนเดิม)

#### 4. ขยาย SyncBrokerTPSL condition ให้ครอบคลุมทุก TP mode

```text
// Line 1371:
Before: if(UseTP_Points || (EnableSL && UseSL_Points))
After:  if(UseTP_Points || UseTP_Dollar || UseTP_PercentBalance || (EnableSL && UseSL_Points))
```

#### 5. เพิ่ม Debug Print เมื่อ modify สำเร็จ

เพิ่ม Print log ทุกครั้งที่ PositionModify สำเร็จ เพื่อยืนยันว่า broker TP ถูก set จริง:
```text
Print("v6.44 BrokerTP: SET #", ticket, " TP=", tpPrice, " SL=", slPrice);
```

#### 6. Dashboard Render Throttle + OnInit (จาก plan v6.43 เดิม)

- Throttle dashboard render ทุก 1 วินาที
- เพิ่ม `DisplayDashboard()` ใน `OnInit()`
- ลบ redundant `CalculateFloatingPL()` / `CalculateTotalLots()` calls

### ตัวอย่าง Flow (Dollar TP)

1. มี SELL 3 orders รวม 0.09 lots, avg = 4750.00, TP_Dollar = $100
2. tickValue = 1.0, tickSize = 0.01 (XAUUSD)
3. priceDistance = 100 / (0.09 * 1.0 / 0.01) = 100 / 9 = 11.11 points
4. tpSell = 4750.00 - 11.11 = 4738.89
5. EA set TP = 4738.89 ลงในทุก 3 orders ผ่าน `PositionModify()`
6. ราคาวิ่งถึง 4738.89 → **Broker ปิดทันที**
7. EA-side Dollar TP ยังเป็น backup ตรวจสอบ `plSell >= $100` ทุก tick

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic — ไม่แก้
- Trading Strategy Logic — ไม่แก้
- Core Module Logic — ไม่แก้
- Accumulate Close / Drawdown Exit — ไม่แก้
- Grid distance / min gap / new candle / candle confirm — ไม่แก้
- DD trigger / Hedge / Balance Guard — ไม่แก้
- Per-Order Trailing Stop logic — ไม่แก้ (ยังจัดการ SL per order เหมือนเดิม)
- v6.37-v6.43 features — ไม่แก้

