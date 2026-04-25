# Gold Miner EA v6.81 — Auto-Close Opposite-Side Survivors on Hedge Open

ไฟล์เดียว: `public/docs/mql5/Gold_Miner_EA.mq5`

## ปัญหา
- Gen ปัจจุบัน (เช่น GM4) เกิด hedge ฝั่ง SELL → ระบบ `g_cycleGeneration++` ไป gen ใหม่
- ฝั่ง BUY ของ gen เก่าที่ยังค้าง (กำไร/ขาดทุนเล็กน้อย, ไม่ถูก bind เพราะ bind เฉพาะ counter side) กลายเป็น orphan
- Cross-Gen INIT Guard v6.76 บล็อก `GM5_INIT BUY` ใหม่เพราะมี normal order ของ gen เก่าฝั่งเดียวกันค้างอยู่
- ผลคือฝั่ง BUY ของ gen ใหม่ออกไม่ได้

## Concept แก้
เพิ่ม toggle ให้ปิด "ฝั่งตรงข้ามของ gen เดียวกัน" ทิ้งทันทีเมื่อ hedge เปิด เพื่อให้ gen ใหม่เริ่ม clean

## Inputs ใหม่ (กลุ่ม Hedging)
```
input bool   InpHedge_CloseOppositeSurvivors = false;  // Close opposite-side survivors of same gen on hedge open
input string InpHedge_CloseOppSurvivorsNote  = "Closes profitable BUY of GM4 when SELL hedge fires on GM4 → next gen starts clean";
```
Default = `false` เพื่อ backward compatible 100%

## Implementation
1. **Helper ใหม่** `CloseOppositeSurvivorsOfGen(int gen, ENUM_POSITION_TYPE hedgeSide)`
   - `oppositeSide = (hedgeSide == POSITION_TYPE_BUY) ? POSITION_TYPE_SELL : POSITION_TYPE_BUY`
   - Loop `PositionsTotal()`:
     - เลือก position ที่ magic ตรง + symbol ตรง + comment prefix ตรงกับ `gen` (GM/GM1/GM2/...) + type == oppositeSide
     - ข้าม hedge comment (`GM_HEDGE_*`, `GM_HD*`) และ recovery comment
     - เรียก `SavePrevHedgedTicket(ticket)` ก่อนปิด (ให้ no-rehedge lock v6.74 ทำงานต่อ)
     - `trade.PositionClose(ticket)` พร้อม log `OPP-SURVIVOR CLOSE gen=X side=Y ticket=Z profit=...`

2. **Hook เข้า 2 จุด** (ก่อน `g_cycleGeneration++`)
   - `CheckAndOpenHedge()` (Expansion trigger) — หลัง hedge เปิดสำเร็จ
   - `CheckAndOpenHedgeByDD()` (DD% trigger) — หลัง hedge เปิดสำเร็จ
   ```
   if(InpHedge_CloseOppositeSurvivors)
      CloseOppositeSurvivorsOfGen(g_cycleGeneration, hedgeSide);
   g_cycleGeneration++;
   ```

3. **Dashboard** เพิ่ม 1 บรรทัด: `OppSurv Close: ON/OFF`

## Version Bump → v6.81
- `#property version "6.81"`
- `#property description` — เพิ่มบรรทัด v6.81 feature
- Header comment block
- Dashboard title
- `OnInit` startup log

## สิ่งที่ "ไม่เปลี่ยน" (ยืนยัน)
- ❌ ไม่แตะ OrderSend / trade.Buy / trade.Sell / trade.PositionClose logic หลัก
- ❌ ไม่แตะ Hedge trigger (Expansion / DD% / Dollar) — logic เดิม
- ❌ ไม่แตะ Triple-Gate exit / Match-Close pool / Recovery grid / Auto Recovery seed
- ❌ ไม่แตะ Cross-Gen INIT Guard v6.76 / No-ReHedge gen-side lock v6.74 / Owner sequential
- ❌ ไม่แตะ Squeeze / BB filter / News / License / Sync / TP-SL broker sync
- ✅ Default `false` → พฤติกรรมเดิม 100%
- ✅ User เปิด `true` → orphan survivor ของ gen เดียวกันถูกเก็บก่อนเลื่อน gen → fix Cross-Gen INIT Guard block

---

# กฎเหล็กเพิ่มเติม (จะบันทึกลง mem://~user เมื่อออก plan mode)
- **Plan mode hard rule**: เมื่ออยู่ใน Plan mode → เรียก `plan--create` ทันทีพร้อมแผนเต็ม → รอ approve อย่างเดียว ห้ามเขียนคำอธิบายยาวก่อน/หลัง tool call
