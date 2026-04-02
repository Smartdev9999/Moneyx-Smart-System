

## v6.26 — ป้องกัน DD Hedge Re-trigger บนออเดอร์ที่เคยอยู่ใน Hedge Set

### ปัญหา
หลัง Matching Close ปิด hedge set ออเดอร์ที่ติดลบที่เหลือถูก "ปล่อย" (released) กลับสู่ระบบปกติ แต่ออเดอร์เหล่านี้ยังมี DD เกินค่า threshold ทำให้ `CheckAndOpenHedgeByDD()` เปิด hedge ใหม่ทันทีบน tick ถัดไป — cooldown เพียง time-based ไม่เพียงพอ

### แนวทาง
เพิ่ม **"Previously-Hedged Tickets"** array เพื่อจำ ticket ที่เคยถูก bind ใน DD-triggered hedge set มาก่อน → `CheckAndOpenHedgeByDD()` จะข้าม ticket เหล่านี้เมื่อคำนวณ DD

### Changes (5 steps)

#### 1. Version bump v6.25 → v6.26

#### 2. เพิ่ม global array สำหรับ previously-hedged tickets (near line 535)
```cpp
#define MAX_PREV_HEDGED 200
ulong    g_prevHedgedTickets[MAX_PREV_HEDGED];
int      g_prevHedgedCount = 0;
```
พร้อม helper functions:
- `AddPrevHedgedTicket(ulong ticket)` — เพิ่ม ticket เข้า array
- `IsPrevHedgedTicket(ulong ticket)` — ตรวจว่า ticket เคยถูก hedge แล้วหรือไม่
- `ClearPrevHedgedTickets()` — เคลียร์ array

#### 3. บันทึก ticket เข้า prevHedged เมื่อ hedge set ถูก deactivate
ที่ทุก deactivation point (7 จุด) — ก่อน clear boundTickets ให้ copy ticket ที่เหลือ (ยังไม่ถูกปิด) เข้า `g_prevHedgedTickets` เฉพาะ set ที่ triggerType เป็น DD (1 หรือ 2)

#### 4. `CheckAndOpenHedgeByDD()` — เพิ่ม guard ข้าม prevHedged tickets
```cpp
if(IsPrevHedgedTicket(ticket)) continue;  // v6.26: skip previously-hedged orders
```
เพิ่มหลังบรรทัด `if(IsTicketBound(ticket)) continue;` (line 6727)

#### 5. เคลียร์ prevHedged เมื่อ reset ทั้งหมด
- เมื่อ `g_cycleGeneration` reset เป็น 0 (all hedge sets closed + no positions)
- เมื่อ OnInit/full position close reset

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic — ไม่แก้
- Trading Strategy Logic — ไม่แก้
- Core Module Logic — ไม่แก้
- Triple-gate exit logic — ไม่แก้
- OpenDDHedge / binding logic — ไม่แก้
- Generation-aware isolation — ไม่แก้
- Matching close / grid recovery ทำงานเหมือนเดิม

