

## Fix v6.17: DD Hedge ต้องผ่าน Expansion Gate เหมือนกัน + ยืนยัน Set แยกอิสระ

### ปัญหาที่พบ

**ปัญหา 1: DD Hedge ข้าม Gate 1 (Expansion Cycle)**

โค้ดปัจจุบัน (line 7478-7494):
```text
if(g_hedgeSets[h].triggerType == 0) {
   // expansion hedge → check cycle gate
} 
// DD hedge (triggerType==1) → ข้ามไปเลย ไม่ต้องผ่าน expansion
```

และตอนเปิด DD hedge (line 6749-6750):
```text
g_hedgeSets[slot].seenExpansionSinceHedge = true;  // ← pre-pass Gate 1
```

**ผลลัพธ์**: DD hedge set ปิดได้ทันทีที่ราคาออกจาก zone + ห่างพอ โดยไม่ต้องรอ expansion → ผิดจากเงื่อนไขที่ต้องการ

**ปัญหา 2**: ไม่ใช่ bug ในโค้ด — `IsTicketBound()` ป้องกันการ bind ซ้ำอยู่แล้ว และแต่ละ set ทำ matching/grid แยกกัน แต่ต้องยืนยันว่า expansion tracking แต่ละ set เป็นอิสระจริง ✅ (line 7543-7548 track per set)

### แผนแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. แก้ `IsHedgeCloseAllowed()` — บังคับ Gate 1 ทุก triggerType

```cpp
bool IsHedgeCloseAllowed(int h)
{
   // Gate 1: Expansion Cycle — บังคับทุกโหมด (ทั้ง Expansion และ DD%)
   if(g_hedgeSets[h].hedgedDuringExpansion)
   {
      // Case A: Hedge ตอน Expansion → รอ Normal
      if(!IsAllSqueezeTFNormalStrict()) return false;
   }
   else
   {
      // Case B: Hedge ตอน Normal/Squeeze → รอ Expansion TF ใหญ่ 1 รอบ → Normal
      if(!g_hedgeSets[h].seenExpansionSinceHedge) return false;
      if(!IsAllSqueezeTFNormalStrict()) return false;
   }
   
   // Gate 2 + Gate 3: Price Zone + TP Distance (ไม่เปลี่ยน)
   ...
}
```

ลบ `if(triggerType == 0)` wrapper ออก → ทุก set ต้องผ่าน expansion เหมือนกัน

#### 2. แก้ `OpenDDHedge()` — ไม่ pre-pass expansion

```cpp
// เดิม (ผิด):
g_hedgeSets[slot].seenExpansionSinceHedge = true;

// แก้เป็น (ถูก) — track ตามจริงเหมือน expansion hedge:
bool isBigTFExpansion = (g_squeeze[2].state == 2);
g_hedgeSets[slot].hedgedDuringExpansion = isBigTFExpansion;
g_hedgeSets[slot].seenExpansionSinceHedge = isBigTFExpansion;
```

#### 3. Dashboard — ลบ "Skip(DD)" แสดงสถานะจริงแทน

แสดง cycle status เหมือนกันทุก set: "Wait Exp" / "Wait Norm" / "Ready"

#### 4. Version bump: v6.16 → v6.17

### ตัวอย่างสถานการณ์

```text
DD Hedge Set#1 เปิดตอน TF ใหญ่ = Normal
→ seenExpansion = false, hedgedDuringExpansion = false
→ ต้องรอ TF ใหญ่ Expansion 1 รอบ → กลับ Normal → ค่อยเข้า Gate 2+3

DD Hedge Set#2 เปิดตอน TF ใหญ่ = Expansion
→ hedgedDuringExpansion = true
→ รอแค่ TF ทั้ง 3 กลับ Normal → เข้า Gate 2+3

ทั้ง 2 set track แยกกัน ปิดตอนผ่านเงื่อนไขของตัวเอง
```

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Gate 2 (Price Zone) + Gate 3 (TP Distance) — ไม่แก้
- Matching Close / Grid Mode logic ภายใน — ไม่แก้
- Accumulate Close — ทำงานรวมเหมือนเดิม
- DD% trigger logic (CheckAndOpenHedgeByDD) — ไม่แก้การเปิด
- Bound ticket isolation (IsTicketBound) — ไม่แก้
- Orphan Recovery / Squeeze detection — ไม่แก้

