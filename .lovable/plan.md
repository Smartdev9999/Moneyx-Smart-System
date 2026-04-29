# Gold Miner EA v6.90 — MaxGridTrail Trigger รวม INIT+GL+GP

## ปัญหาที่พบ
`ManageMaxGridTrailing()` ใช้ `CountGenGridLoss()` เป็น trigger gate (line 3511, 3563) ซึ่งฟังก์ชันนี้นับเฉพาะ comment `_GL` เท่านั้น (line 3367):

```cpp
if(StringFind(comment, "_GL") >= 0) count++;  // นับแค่ GL
```

แต่ `CalcGenAveragePrice()` (v6.86) คำนวณ avg price จาก **INIT + GL + GP** อยู่แล้ว → Logic ขัดแย้งกันเอง

### ผลกระทบ
- Generation ที่มี INIT + GP จำนวนมาก แต่ GL ยังไม่ถึง threshold → trailing **ไม่ activate**
- ทั้งที่ avg price + ขนาด basket รวมจริงถึงเกณฑ์ความเสี่ยงแล้ว
- ผู้ใช้รู้สึกว่า "MaxGridTrail นับแค่ INIT+GL ยังไม่นับ GP"

## แผนแก้ไข v6.90

### 1. เพิ่มฟังก์ชันใหม่ `CountGenGridAll()`
นับ orders ที่มี comment `_INIT` หรือ `_GL` หรือ `_GP` (กิน prefix เดียวกับ `CalcGenAveragePrice`)

```cpp
int CountGenGridAll(int gen, ENUM_POSITION_TYPE side)
{
   // เหมือน CountGenGridLoss แต่ accept _INIT|_GL|_GP
   if(StringFind(comment, "_INIT") >= 0 ||
      StringFind(comment, "_GL")   >= 0 ||
      StringFind(comment, "_GP")   >= 0) count++;
}
```

### 2. แก้ `ManageMaxGridTrailing()` (line 3511, 3563)
เปลี่ยน trigger gate จาก `CountGenGridLoss` → `CountGenGridAll`:
```cpp
int totalCount = CountGenGridAll(gen, POSITION_TYPE_BUY);   // v6.90
if(totalCount >= requiredOrders_Buy) { ... }
```

### 3. เพิ่ม Input toggle ปลอดภัย (default = true เพื่อใช้ logic ใหม่)
```cpp
input bool InpMaxGridTrail_IncludeINITGP = true;  // v6.90
```
- `true` (default) → ใช้ `CountGenGridAll` (รวม INIT+GL+GP)
- `false` → ย้อนกลับ behavior v6.89 (นับเฉพาะ GL)

ผู้ใช้สามารถปิดได้ถ้าต้องการพฤติกรรมเดิม ไม่ทำลาย backward compatibility

### 4. อัปเดต Log
```cpp
Print("v6.90 MaxGridTrail BUY ACTIVATED: Gen=", gen, " AvgPrice=", avgPrice,
      " SL=", g_maxGridTrailSL_Buy, " (count=", totalCount,
      " mode=", (InpMaxGridTrail_IncludeINITGP ? "ALL" : "GL_ONLY"), ")");
```

### 5. Versioning
- `#property version "6.90"`
- `#property description` เพิ่มบรรทัด v6.90
- Header comment block
- Dashboard `headerVersion` ทุก mode (INST/SMA/ZZ) → "Gold Miner EA v6.90"
- `OnInit` / `OnDeinit` log

## สิ่งที่ไม่เปลี่ยน (ยืนยันไม่กระทบ trading logic)
- ❌ ไม่แตะ `OrderSend` / `trade.Buy` / `trade.Sell` / `trade.PositionClose`
- ❌ ไม่แตะ Strategy entry (SMA/INSTANT/ZZ signal logic)
- ❌ ไม่แตะ Grid Loss / Grid Profit entry logic
- ❌ ไม่แตะ Hedge trigger / Hedge release / Triple-Gate
- ❌ ไม่แตะ Accumulate close / DD% TP / Daily Target
- ❌ ไม่แตะ `CountGenGridLoss` (ยังใช้กับ Grid trigger ที่อื่นๆ)
- ❌ ไม่แตะ `CalcGenAveragePrice` / `CountGenOrders` / `CloseGenSide` (v6.86 ครบแล้ว)
- ❌ ไม่แตะ Squeeze Pause Trailing (v6.87-6.89)
- ❌ ไม่แตะ License / News / Time / Sync modules
- ❌ ไม่แตะ ManagePerOrderTrailing / ManageTrailingStop_TF / ApplyTrailingSL

## ไฟล์ที่แก้
- `public/docs/mql5/Gold_Miner_EA.mq5`
- `.lovable/memory/trading/gold-miner-ea/maxgrid-trail-trigger-include-init-gp-v6-90.md` (new)
- `mem://index.md` (เพิ่มบรรทัดใหม่)
