

## v6.58 — Sequential Recovery Fix + Prevent Re-Hedge on Released Orders

### ปัญหาที่พบจาก v6.57

**ปัญหา #1: Sequential Recovery ปลด hedge ทุกชุดพร้อมกัน**
ใน `ManageHedgeSets()` loop (line 8998-9007) ใช้ `FindOldestActiveHedgeSet()` ภายในแต่ละ iteration ของ `h` — เมื่อ H1 (idx เก่าสุด) ปิดสำเร็จในรอบนี้ → `g_hedgeSets[h].active = false` → loop ดำเนินต่อไปยัง h ถัดไป → `FindOldestActiveHedgeSet()` ถูกเรียกใหม่ → คืนค่าเป็น H2 → H2 ก็ปิดด้วย → H3 → H4… **ทำให้ปลดทุกชุดในรอบ tick เดียว**

**ปัญหา #2: ออเดอร์ที่เคยถูก Bound กลับโดน Hedge ใหม่อีก**
`SaveBoundTicketsToPrevHedged()` บันทึก ticket แล้ว แต่ guard `IsPrevHedgedTicket()` ถูกเช็คเฉพาะใน DD trigger (line 7985) เท่านั้น
ตอน **bind** orders เข้า hedge set ใหม่ (line 7884) **ไม่ได้เช็ค `IsPrevHedgedTicket`** → ออเดอร์ที่เพิ่ง release จาก H1/H2 สามารถถูก bind เข้า hedge set ใหม่ได้ทันที (ถ้า generation ตรงกัน เช่น orphan recovery สร้าง orders gen เดียวกัน)

นอกจากนี้ Expansion-trigger / Squeeze-trigger ที่ scan loss orders ก็ไม่ได้กรอง `IsPrevHedgedTicket` เช่นกัน

---

### แผนแก้ไข — `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Version bump → v6.58

#### 2. Fix Sequential Recovery — ปลดเพียงชุดเดียวต่อ tick

แก้ `ManageHedgeSets()` (lines ~8995-9058):

**วิธีแก้:** เพิ่ม flag `bool sequentialRecoveryActedThisTick = false` ใน scope ของ loop. หลังจาก `ManageHedgeMatchingClose / ManageHedgeBoundAvgTP / ManageHedgePartialClose` ทำงาน (ไม่ว่าจะปิดสำเร็จหรือยัง) → ถ้า `InpHedge_SequentialRecovery == true` → ตั้ง flag = true → iteration ถัดไปของ loop ข้ามการประมวลผล closing ทั้งหมด

```cpp
bool sequentialActed = false;  // v6.58

for(int h = 0; h < MAX_HEDGE_SETS; h++)
{
   // ... existing checks (active, exists, gate) ...

   // v6.57: Sequential Recovery
   if(InpHedge_SequentialRecovery)
   {
      // v6.58: หลัง act ไปแล้วในรอบนี้ → block ชุดอื่นทันที
      if(sequentialActed) { g_hedgeSets[h].matchingDone = false; continue; }
      
      int oldestActiveIdx = FindOldestActiveHedgeSet();
      if(oldestActiveIdx >= 0 && h != oldestActiveIdx)
      {
         g_hedgeSets[h].matchingDone = false;
         continue;
      }
   }

   // ... existing matching/avgTP/partial close logic ...

   // v6.58: Mark that we acted on a set this tick
   if(InpHedge_SequentialRecovery)
      sequentialActed = true;
}
```

ผลลัพธ์: H1 ทำงาน (ปิดหรือยัง matching) → H2/H3 รอ tick ถัดไป → ถ้า H1 ปิดจริง → tick ถัดไป H2 ขึ้นเป็น oldest → ค่อยทำงาน → **ปลดทีละชุดจริงๆ**

#### 3. Fix Re-Hedge Guard — เพิ่ม `IsPrevHedgedTicket` ในทุก bind/scan

จุดที่ต้องเพิ่ม guard `if(IsPrevHedgedTicket(ticket)) continue;`:

| Location (line) | Function | ปัจจุบัน | ต้องเพิ่ม |
|---|---|---|---|
| ~7739 | Expansion trigger scan loss | มี IsTicketBound | + IsPrevHedgedTicket |
| ~7884 | Hedge OPEN — bind unbound counter-side | มี IsTicketBound | + IsPrevHedgedTicket |
| ~8136 | (DD or other open path scan) | มี IsTicketBound | + IsPrevHedgedTicket |
| ~8323 | Bound add scan (orphan link) | มี IsTicketBound | + IsPrevHedgedTicket |

(จะเช็คทุกบรรทัดที่ใช้ `IsTicketBound(ticket)` ในเส้นทาง **OPEN/BIND ของ hedge** เท่านั้น — **ไม่แตะ** จุดที่เป็น Grid/Recovery loop ของออเดอร์ปกติ เช่น line 1794, 2085, 2991, 3022 ที่เกี่ยวกับ Grid Loss/Profit/AvgTP ของออเดอร์ปกติ)

#### 4. Dashboard เพิ่มบรรทัด

```
Hedge Recovery | Sequential | Active: H1 | Acted: YES (H2,H3 wait next tick)
PrevHedged     | 12 tickets locked from re-hedge
```

---

### สิ่งที่ไม่เปลี่ยนแปลง

- Order Execution Logic (`trade.Buy/Sell/PositionClose`) — ไม่แก้
- Trading Strategy — ไม่แก้
- `FindOldestActiveHedgeSet()` ตรรกะ FIFO — ไม่แก้
- `ManageHedgeMatchingClose / BoundAvgTP / PartialClose` ตรรกะภายใน — ไม่แก้
- `SaveBoundTicketsToPrevHedged / IsPrevHedgedTicket` — ไม่แก้ (มีอยู่แล้ว)
- DD trigger guard — ไม่แก้ (มี IsPrevHedgedTicket อยู่แล้ว)
- Grid Loss/Profit/AvgTP ของออเดอร์ปกติ — ไม่แก้
- Recovery Grid v6.57 / BB Filter v6.56 / Triple Gate / Balance Guard — ไม่แก้
- v6.37–v6.57 features — ไม่แก้

### ผลลัพธ์ที่คาดหวัง

1. **Sequential Recovery ทีละชุดจริง**: tick นี้ปลด H1 → tick ถัดไปค่อยพิจารณา H2 → ลด DD แบบควบคุมได้
2. **Released orders ไม่โดน Hedge ซ้ำ**: ออเดอร์ที่ release จาก H1/H2 จะไม่ถูก bind เข้า hedge set ใหม่ + ไม่ถูกนับในการ trigger Expansion hedge → กลายเป็น recovery orders ที่ orphan recovery จัดการเท่านั้น

