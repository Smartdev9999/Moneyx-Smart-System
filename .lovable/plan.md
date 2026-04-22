

## v6.66 — Fix Active Hedge Counting + Generation Recycling

### วินิจฉัยจากภาพ (image-939)

ภาพแสดง: GM11_INIT/GL#1-5 + GM_Hedge_D11 (ล็อกอยู่) + GM12_INIT/GL#1-3 + GM12 ฝั่ง buy (เปิด basket ใหม่) — ระบบนับขึ้นไปถึง GM12 ทั้งที่ user ตั้ง `InpHedge_MaxSets = 10`

### Root Cause 2 จุด

**ปัญหา 1: Active Hedge Limit ไม่ทำงาน**
- โค้ดที่ line 8485, 8735 เช็ก `activeSetCount >= InpHedge_MaxSets` ก็ถูกแล้ว
- **แต่** ในภาพมี `GM_Hedge_D11` แค่ตัวเดียวที่ active → activeSetCount = 1 ไม่ใช่ 11 → ผ่านการเช็ก → เปิด GM12 hedge ได้
- ปัญหาที่แท้คือ user เข้าใจว่า `MaxSets=10` = "ห้ามเกิน 10 hedge ที่ active พร้อมกัน" ซึ่ง**ทำงานถูกต้องอยู่แล้ว** — ที่เห็น GM11/GM12 คือ generation counter ไม่ใช่จำนวน active hedge
- → ต้องการ feedback ที่ดีกว่า: dashboard แสดงให้เห็นชัดว่า active = X / 10

**ปัญหา 2: Generation ไม่รีเซ็ตกลับ GM1 เมื่อไม่มี order**
- `TryResetCycleStateIfFlat()` (line 8097) reset เฉพาะเมื่อ `g_hedgeSetCount == 0` **และ** `TotalOrderCount() == 0` (account flat ทั้งหมด)
- แต่ในภาพ: GM_Hedge_D11 ปลดไปแล้ว (เห็น GM11_* ไม่มี hedge ผูก ไม่มี TP) แต่ GM11_INIT-GL#5 ยังเปิดค้าง (เป็น orphan losing orders) → `TotalOrderCount() > 0` → ไม่ reset → ระบบเปิด GM12 ต่อไป
- **กฎที่ user ต้องการ**: เมื่อ basket ของ generation ปัจจุบันถูกปิดหมด (ไม่มี hedge active สำหรับ gen นี้แล้ว) → ควร reset gen counter กลับไปที่ค่าต่ำสุดที่ยังมี order อยู่ หรือ GM1 ถ้าไม่มี order เลย

### แผนแก้ v6.66 (Fix-only)

ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

#### Fix 1: Smart Generation Recycling — `TryResetCycleStateIfFlat()`
แทนที่จะรีเซ็ตเฉพาะเมื่อ flat 100% ให้ปรับลอจิกเป็น:

```cpp
void TryResetCycleStateIfFlat(string reason)
{
   if(g_hedgeSetCount > 0) return;               // มี hedge active อยู่ → ห้ามรีเซ็ต
   if(g_cycleGeneration <= 1) return;            // เป็น GM1 อยู่แล้ว
   
   int total = TotalOrderCount();
   
   // Case A: Account flat ทั้งหมด → reset เป็น GM1 (เดิม)
   if(total == 0) {
      g_cycleGeneration = 1;
      ClearPrevHedgedTickets();
      // ... (เดิม)
      Print("v6.66 CYCLE RESET → GM1 (account flat) — ", reason);
      return;
   }
   
   // Case B (ใหม่): ยังมี orphan orders ลอยอยู่ และไม่มี hedge active
   // → re-anchor cycleGen ไปที่ "max gen ของ orders ที่ยังเหลือ" 
   // → Gen ปัจจุบันที่ basket ปิดหมดแล้วจะไม่ถูกใช้ต่อ — Gen ถัดไปจะนับจาก max ที่ยังเหลือ
   int maxRemainingGen = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong t = PositionGetTicket(i);
      if(t==0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      int g = ExtractGeneration(PositionGetString(POSITION_COMMENT));
      if(g > maxRemainingGen) maxRemainingGen = g;
   }
   int newGen = (maxRemainingGen < 1) ? 1 : maxRemainingGen;
   if(newGen < g_cycleGeneration) {
      Print("v6.66 CYCLE RE-ANCHOR: GM", g_cycleGeneration, " → GM", newGen,
            " (orphans remain, no active hedge) — ", reason);
      g_cycleGeneration = newGen;
      SaveCycleGeneration();
   }
}
```

ผลลัพธ์: เมื่อ GM_Hedge_D11 ปลด → ไม่มี hedge active → orphan GM11 ยังอยู่ → cycleGen re-anchor เป็น 11 (max ที่เหลือ) → DD trigger ครั้งถัดไปจะเปิด `GM_Hedge_D12` (เพราะ increment หลัง bind) — แต่ถ้า orphan ของ GM11 ถูก match-close หมดด้วย → next call → maxRemaining อาจเป็น GM10/9/... → **ไม่บานปลายไปเรื่อย ๆ**

> หมายเหตุ: ถ้า user ต้องการพฤติกรรม "reset เป็น GM1 ทันทีเมื่อไม่มี hedge active แม้มี orphan ค้าง" จะแรงเกินไปและทำให้ comment ใหม่ชนกับ orphan เดิม (GM1 เคยใช้แล้ว) — re-anchor แบบนี้ปลอดภัยกว่า

#### Fix 2: Hard Cap Generation by InpHedge_MaxSets
เพิ่ม guard ใน `OpenDDHedge()` และ expansion hedge ก่อน increment:

```cpp
// v6.66: ถ้า cycleGen ไปไกลเกิน MaxSets แล้วและไม่มี hedge active → re-anchor ก่อน
if(g_cycleGeneration > InpHedge_MaxSets * 2 && g_hedgeSetCount == 0) {
   TryResetCycleStateIfFlat("gen exceeded cap, no active hedge");
}
```

ป้องกันกรณี edge ที่ generation วิ่งไปไกลผิดปกติ

#### Fix 3: Dashboard เพิ่มความชัดเจน
แสดง 2 แถว:
- **Active Hedge: 1 / 10** (จำนวน hedge set ที่ active)
- **Cycle Gen: GM12** (generation ปัจจุบัน — แค่ counter ของชื่อ comment, ไม่ใช่ limit)

อธิบายให้ user เห็นว่า GM11/GM12 คือ "ลำดับชื่อรอบ" ไม่ใช่ "จำนวน hedge active"

#### Fix 4: Log ให้ชัดเจนเมื่อบล็อก
แก้ log ที่ line 8487 / 8737 จาก:
```
HEDGE: Max active sets reached (10/10) - skip
```
เป็น:
```
v6.66 HEDGE BLOCKED: Active hedge sets = 10 / Max=10 → skip new hedge for GM<gen>
```

#### Fix 5: Version bump → v6.66
- `#property version "6.66"`
- `#property description` += "v6.66 — Smart Gen Recycling + Active Hedge Visibility"
- Header + Dashboard

### สิ่งที่ไม่เปลี่ยนแปลง (กฎเหล็ก)

- `trade.Buy/Sell/PositionClose` / `OpenOrder` — ไม่แก้
- Trading strategy / signal / grid entry / TP/SL — ไม่แก้
- `IsHedgeCloseAllowed()` Triple Gate — ไม่แก้
- Sequential Recovery / Match-Close pool — ไม่แก้
- `InpHedge_MaxSets` semantic เดิม (= max active concurrent hedge sets) — **ยืนยันถูกต้อง**, ไม่เปลี่ยน
- v6.62 hedge comment scheme / v6.63 / v6.64 / v6.65 — ไม่แก้
- BB / News / License / Time filter — ไม่แก้

### ผลลัพธ์ที่คาดหวัง

1. **Active Hedge limit ทำงานถูกตามดีไซน์** — ถ้ามี 10 hedge set กำลังล็อกอยู่ → hedge ที่ 11 จะไม่เปิด (มีอยู่แล้วใน v6.65 — จะเพิ่ม log/dashboard ให้เห็นชัด)
2. **Generation ลด/รีเซ็ตได้** — เมื่อ basket ของ gen ปัจจุบันถูกปิดและไม่มี hedge active → cycleGen re-anchor เป็น max gen ของ orphan ที่เหลือ → ป้องกันการเลื่อนเป็น GM13/14/15... ไม่หยุด
3. **Reset เป็น GM1 เต็มรูปแบบ** ยังเกิดเมื่อ account flat ทั้งหมด (เดิม)
4. Dashboard แยกชัดระหว่าง "Active Hedge X/10" กับ "Cycle Gen GMx"

### ความเสี่ยงและ Mitigation

- **Risk**: Re-anchor cycleGen ขณะมี orphan ค้าง → comment ใหม่อาจซ้ำกับ orphan เดิม (เช่น GM11_GL#6 ใหม่ vs GM11_GL#5 เก่า)
- **Mitigation**: `GetCommentPrefix()` + grid level counter (`GL#N`) นับจาก order ที่มีอยู่จริงของ gen นั้น → ใช้ `#N+1` ต่อจากตัวเดิม — ตรวจ logic นี้ระหว่าง implement ถ้าพบว่า counter เริ่มที่ 1 เสมอ จะปรับให้สแกน max GL# ของ gen นั้นก่อน

