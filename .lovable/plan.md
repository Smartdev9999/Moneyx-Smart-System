

## v6.68 — Fix: ห้ามปลด hedge เกิน 1 ชุดต่อ tick (แม้มี profit-bypass)

### วินิจฉัยปัญหา

จาก v6.67 ที่เพิ่ม `seqBypass_profitClose` เพื่อให้ hedge กำไรปิดได้ข้าม sequential lock — เกิด side-effect:

ดู loop ที่ `ManageHedgeSets()` (line 9714–9866):
- ตัวแปร `sequentialActed = true` ถูกตั้งเฉพาะใน `if(InpHedge_SequentialRecovery && !seqBypass_profitClose)` branch (line 9810)
- เมื่อ hedge set A เข้าเงื่อนไข bypass (กำไรพอ) → ข้าม guard → ไป `ManageHedgeMatchingClose` → ปิด → **ไม่ตั้ง `sequentialActed = true`**
- รอบเดียวกัน loop ไป set B ที่กำไรพอเช่นกัน → bypass อีก → ปิดอีกชุด
- ผลคือ **ปลด 2 ชุดพร้อมกันใน 1 tick** ตามที่ user เห็น

แต่ถ้า hedge set A ปิดผ่าน normal path (ไม่ bypass, เป็น oldest) → set B โดน `sequentialActed` block → ปลดทีละชุด → ตรงตามที่ user เห็นบางครั้งปิดทีละชุด

### Root Cause สรุป

v6.67 bypass ลืม respect "one-set-per-tick" rule ที่เป็นกฎพื้นฐานของ Sequential Recovery — bypass ควรอนุญาตแค่ "ข้าม owner lock + ข้าม oldest-first rule" แต่ยังต้องเคารพ "หนึ่ง set ต่อ tick" เพื่อให้:
1. Match-Close pool คำนวณบน state ล่าสุดของ tick (ไม่ทับซ้อน)
2. Sequential Recovery owner สามารถ claim ได้ถูกต้องหลังปิด
3. ไม่ปลด basket หลายฝั่งพร้อมกันจนสูญเสียการป้องกัน

### แผนแก้ v6.68 (Fix-only)

ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

#### Fix 1: Bypass ต้องเช็กและตั้ง `sequentialActed`
แก้ branch `else if(seqBypass_profitClose ...)` (line 9812–9815):

```cpp
else if(seqBypass_profitClose && InpHedge_SequentialRecovery)
{
   // v6.68: bypass ยังต้องเคารพ one-set-per-tick — ป้องกันปลด hedge หลายชุดพร้อมกัน
   if(sequentialActed)
   {
      g_hedgeSets[h].matchingDone = false;
      Print("v6.68 SEQ BYPASS DEFER: Set#", h+1, " profit-close deferred (another set already acted this tick)");
      continue;
   }
   if(g_sequentialRecoveryCompletedThisTick)
   {
      g_hedgeSets[h].matchingDone = false;
      continue;
   }
   Print("v6.67 SEQ BYPASS: Set#", h+1, " profit-close allowed (hedge PnL > MatchMinProfit) despite seq owner Gen", g_sequentialRecoveryGen);
   sequentialActed = true;  // v6.68: mark — บล็อก set ถัดไปใน tick นี้
}
```

#### Fix 2: Version bump → v6.68
- `#property version "6.68"`
- `#property description` += "v6.68 — Enforce one-hedge-per-tick rule on profit-close bypass"
- Header comment + Dashboard version string

### สิ่งที่ไม่เปลี่ยนแปลง (กฎเหล็ก)

- `trade.Buy/Sell/PositionClose` / `OpenOrder` — ไม่แก้
- Trading strategy / signal / grid entry / TP/SL calc — ไม่แก้
- `IsHedgeCloseAllowed()` Triple Gate — ไม่แก้
- `ManageHedgeMatchingClose` / Match-Close pool (v6.61) — ไม่แก้
- Sequential Recovery Owner mechanism — ไม่แก้
- Smart Generation Recycling (v6.66) — ไม่แก้
- `seqBypass_profitClose` threshold (`InpHedge_MatchMinProfit`) — ไม่แก้
- v6.67 bypass concept (อนุญาต profit hedge ปิดได้แม้มี seq owner) — **คงไว้** เพียงเพิ่ม guard ต่อ tick
- BB / News / License / Time filter / Dashboard layout — ไม่แก้

### ผลลัพธ์ที่คาดหวัง

1. **ปลด hedge ทีละ 1 ชุดต่อ tick เสมอ** — ไม่ว่าผ่าน normal path หรือ profit-bypass
2. Set ที่กำไรชุดอื่นที่รอ → จะปิดใน tick ถัดไป (1 tick = ~milliseconds)
3. Match-Close pool ทำงานบน state ที่สม่ำเสมอ → ไม่มี race condition
4. Log ใหม่ `v6.68 SEQ BYPASS DEFER` ช่วย debug ลำดับการปิด

### ความเสี่ยง & Mitigation

- **Risk**: หลาย hedge set กำไรพร้อมกัน อาจช้าลง 1 tick ต่อชุด
- **Mitigation**: ห่างกันแค่ ms-level ไม่กระทบกำไร และปลอดภัยกว่ามาก (ป้องกัน basket ขาดการป้องกันพร้อมกัน)

