## ปัญหาที่พบใน Average Trailing Stop (v6.83) — ไม่ทำงานเมื่อเปิด 2 ฝั่งพร้อมกัน

ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

### 🔍 Root Cause (เจอ 2 บั๊ก)

**บั๊ก #1 — `ResetTrailingState()` ล้างทั้ง 2 ฝั่งทิ้ง (บรรทัด 3149-3157)**
ฟังก์ชันนี้ reset ทั้ง Buy + Sell พร้อมกัน:
```cpp
void ResetTrailingState() {
   g_trailingSL_Buy = 0;     // ← ล้างฝั่ง Buy
   g_trailingSL_Sell = 0;    // ← ล้างฝั่ง Sell ที่กำลังทำงานอยู่ทิ้งด้วย!
   g_trailingActive_Buy = false;
   g_trailingActive_Sell = false;
   ...
}
```
ถูกเรียกเมื่อ:
- บรรทัด 3033 — หลัง BUY trailing SL hit → ปิด Buy แล้วล้าง state ฝั่ง Sell ทิ้ง
- บรรทัด 3094 — หลัง SELL trailing SL hit → ล้าง state ฝั่ง Buy ทิ้งเช่นกัน

ผล: เมื่อฝั่งหนึ่งโดน trail-out ฝั่งที่เหลือถูก "รีเซ็ต" (`g_trailingSL=0`, `g_trailingActive=false`) ทำให้ trailing ฝั่งนั้นเริ่มนับใหม่จาก 0 = ดูเหมือน "ไม่ทำงาน"

**บั๊ก #2 — `return;` หลัง CloseAllSide (บรรทัด 3034)**
หลัง BUY trail-hit `return;` ทันที → block SELL section (3044+) ใน function เดียวกัน → SELL ไม่ถูกประมวลผลใน tick นั้น

### ✅ แผนแก้ไข — v6.84

**1. แยก reset เป็นรายฝั่ง**
```cpp
void ResetTrailingStateBuy()  { g_trailingSL_Buy=0;  g_trailingActive_Buy=false;  g_breakevenDone_Buy=false;  }
void ResetTrailingStateSell() { g_trailingSL_Sell=0; g_trailingActive_Sell=false; g_breakevenDone_Sell=false; }
```
เก็บ `ResetTrailingState()` เดิมไว้สำหรับ cycle reset / OnInit (จุดอื่นไม่กระทบ)

**2. แทนที่ใน `ManageTrailingStop()` 2 จุด**
- บรรทัด 3033: `ResetTrailingState();` → `ResetTrailingStateBuy();`
- บรรทัด 3094: `ResetTrailingState();` → `ResetTrailingStateSell();`

**3. ลบ `return;` บรรทัด 3034** ปล่อยให้ flow ดำเนินต่อไปประมวลผลฝั่ง SELL ใน tick เดียวกัน

**4. ตรวจ `ManageTrailingStop_TF()` (บรรทัด 5701+)** ว่ามีบั๊กเดียวกันไหม ถ้าใช่ — แก้แบบเดียวกัน

**5. Versioning** v6.83 → **v6.84** (`#property version/description`, header, OnInit log, Dashboard headerVersion)

### 🚫 สิ่งที่ไม่เปลี่ยนแปลง (ยืนยันไม่กระทบ trading logic)
- ไม่แตะ `OrderSend / trade.Buy / trade.Sell / trade.PositionClose / CloseAllSide`
- ไม่แตะสูตร `newSL`, `TrailingStep`, `TrailingActivation`, `BreakevenBuffer`, `BreakevenActivation`
- ไม่แตะ `ApplyTrailingSL` (v6.83 throttle ครบเหมือนเดิม)
- ไม่แตะ Hedge / Triple-Gate / DD / Squeeze / News / License / Grid / Accumulate
- เงื่อนไข activation / breakeven / SL-hit เหมือนเดิมทุกจุด

### 📋 ผลลัพธ์
- BUY และ SELL trailing ทำงาน **อิสระต่อกัน 100%**
- ฝั่งหนึ่ง trail-out ไม่กระทบ state อีกฝั่ง