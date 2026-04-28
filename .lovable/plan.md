# Gold Miner EA v6.87 — Squeeze Pause Trailing

ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

## เป้าหมาย
เมื่อเปิด **Volatility Squeeze Filter** และตลาดเข้าสถานะ **Expansion** ตามเกณฑ์ที่ตั้ง (`InpSqueeze_ExpThreshold` + `InpSqueeze_MinTFExpansion`) → **ระบบ Trailing Stop ทุกชนิดจะหยุดอัปเดต SL ชั่วคราว** จนกว่าจะกลับเป็น Normal แล้วค่อยทำงานต่อ

**ส่วนที่ pause เฉพาะ trailing เท่านั้น — ไม่กระทบการเปิดออเดอร์ใหม่ / Grid / Hedge / TP / Accumulate Close**

## เพิ่ม Input ใหม่ (1 ตัว)
```
input bool InpSqueeze_PauseTrailing = true;  // Pause Trailing Stop on Expansion
```
อยู่ในกลุ่ม `=== Volatility Squeeze Filter ===` (default = true)

## แก้ไข
### 1. Helper ใหม่ (read-only)
```cpp
bool IsSqueezePausingTrailing()
{
   if(!InpUseSqueezeFilter || !InpSqueeze_PauseTrailing) return false;
   // pause เมื่อมี TF ใดเข้า Expansion ตามเกณฑ์ block (ใช้ flag ที่คำนวณแล้วใน OnTick)
   return (g_squeezeBlocked || g_squeezeBuyBlocked || g_squeezeSellBlocked);
}
```

### 2. Pause `ManagePerOrderTrailing()` (~L2854)
- ใส่ early-return ตอนต้นฟังก์ชัน:
  ```cpp
  if(IsSqueezePausingTrailing()) return;
  ```
- ผลคือ Per-Order Trailing/Breakeven **ไม่อัปเดต SL** ระหว่าง Expansion (SL เดิมที่ส่งโบรกไว้แล้วยังอยู่)

### 3. Pause `ManageMaxGridTrailing()` (~L3423)
- ใส่ early-return หลัง reset block (ก่อน auto-advance gen):
  ```cpp
  if(IsSqueezePausingTrailing()) return;
  ```
- Average-Based Trailing + Breakeven หยุดขยับ SL จนกว่าจะ Normal

### 4. Pause MTF Trailing (~L5778, L5830, L5880 `ApplyTrailingSL_TF`)
- ใส่ guard ที่ต้นบล็อก trailing/breakeven ของแต่ละ TF เช่นเดียวกัน

### 5. Dashboard
- เพิ่มบรรทัดสถานะใต้ Squeeze panel: `Trailing: PAUSED (Expansion)` หรือ `Trailing: ACTIVE`

### 6. Version
v6.86 → **v6.87** ทุกจุด: `#property version`, `#property description`, header comment, Dashboard headerVersion, log ใน `OnInit`/`OnDeinit`

## สิ่งที่ไม่เปลี่ยนแปลง (ยืนยัน)
- ❌ ไม่แตะ Order Execution (`OrderSend`, `trade.Buy/Sell`, `PositionClose`)
- ❌ ไม่แตะ Trading Strategy (SMA signal, Grid Loss/Profit entry, TP, Accumulate Close, Hedge trigger, DD exit)
- ❌ ไม่แตะ guard การเปิดออเดอร์ใหม่ (`g_squeezeBlocked`/`Buy`/`Sell` ที่ใช้ block grid/initial ยังเหมือนเดิม)
- ❌ ไม่แตะ License / News / Time Filter / Sync
- ❌ ไม่แตะการคำนวณ Squeeze (`UpdateSqueezeState`, BB/KC/ATR)
- ❌ ไม่แตะ `CalcGenAveragePrice` / `CountGenOrders` / `CloseGenSide` (v6.86)
- ✅ เปลี่ยนเฉพาะ "การยิง `PositionModify` ของ Trailing/Breakeven" เท่านั้น
- ✅ Backward compatible — `.set` เก่ายังใช้ได้ (input ใหม่ default true; ปิดได้ถ้าไม่ต้องการ)

## Memory
สร้าง `mem://trading/gold-miner-ea/squeeze-pause-trailing-v6-87.md` + อัปเดต `mem://index.md`
