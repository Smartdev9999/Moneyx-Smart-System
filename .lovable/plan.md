

## v6.25 — Sequential Hedge Recovery: ปิดทีละชุด ตามลำดับเก่าสุดก่อน

### ปัญหาปัจจุบัน

`ManageHedgeSets()` (line 7636) ลูปทุก active hedge set ทุก tick:
```text
for(h = 0; h < MAX_HEDGE_SETS; h++)
   → matching close + grid recovery ทุกชุดพร้อมกัน
   → orders ออกเยอะมาก → เสี่ยงพอร์ตแตก
```

### สิ่งที่ต้องการ

- ปิด hedge set ทีละชุด โดยเลือก **ชุดที่เก่าที่สุด** (เปิดก่อน) ที่ผ่าน Triple Gate
- หลังปิดชุดนั้นจบ (deactivate) → รีเช็คชุดเก่าสุดถัดไปที่ผ่าน gate
- เพิ่ม input toggle เปิด/ปิดฟังก์ชันนี้ (default = true)

### แผนแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. เพิ่ม input parameter

```cpp
// ใน group "=== Counter-Trend Hedging ==="
input bool     InpHedge_SequentialClose      = true;    // Sequential Close (oldest first, one at a time)
```

#### 2. แก้ `ManageHedgeSets()` — เพิ่ม sequential mode

เมื่อ `InpHedge_SequentialClose == true`:

```text
แทนที่จะลูปทุก set แล้วทำ recovery ทุกชุด:

1. หา active set ที่เก่าที่สุด (openTime น้อยสุด) ที่ผ่าน IsHedgeCloseAllowed()
2. ทำ matching close / grid recovery เฉพาะ set นั้น
3. set อื่นๆ ที่ active → ทำแค่ RefreshBoundTickets + track expansion (maintenance)
   แต่ข้าม matching close / grid logic
4. เมื่อ set นั้น deactivate → tick ถัดไปจะเลือกชุดเก่าสุดที่เหลือ
```

เมื่อ `InpHedge_SequentialClose == false` → ทำงานเหมือนเดิมทุกประการ

#### 3. เพิ่ม field `openTime` ใน `HedgeSet` struct

ใช้เพื่อเรียงลำดับว่า set ไหนเก่ากว่า:
```cpp
datetime openTime;  // เวลาที่เปิด hedge set นี้
```

ตั้งค่าตอน `OpenDDHedge()` / Expansion hedge trigger ที่สร้าง set ใหม่

#### 4. Recovery ยังอยู่ใน `RecoverHedgeSets()` ตอน restart

`openTime` จะถูก recover จาก hedge ticket's open time

#### 5. Version bump: v6.24 → v6.25

### Logic flow (Sequential mode)

```text
Tick N:
  Active sets: H1(old), H2, H3, H4
  H1 ผ่าน gate → ทำ matching/grid สำหรับ H1
  H2,H3,H4 → maintenance only (refresh bounds, track expansion)

Tick N+X:
  H1 ปิดเสร็จ (deactivated)
  H2 ไม่ผ่าน gate, H3 ผ่าน gate → ข้าม H2 แต่ H3 เป็น eligible
  หา oldest eligible: H3 ไม่ใช่เก่าสุด, H2 เก่าสุดแต่ไม่ผ่าน gate
  → เลือก H3 (oldest ที่ผ่าน gate) → ทำ recovery

Tick N+Y:
  H3 ปิดเสร็จ, H2 ผ่าน gate แล้ว → เลือก H2 → ทำ recovery
  H4 → maintenance only
```

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose) — ไม่แก้
- Trading Strategy Logic (SMA/ZigZag/Grid/TP/SL) — ไม่แก้
- Core Module Logic (License, News, Time, Data sync) — ไม่แก้
- Triple-gate exit logic — ไม่แก้ (ยังใช้เป็น gate เหมือนเดิม)
- Matching close / Grid recovery logic ภายใน — ไม่แก้ (แค่จำกัดว่าทำทีละชุด)
- DD trigger / generation-aware isolation — ไม่แก้
- OpenDDHedge / CheckAndOpenHedgeByDD — ไม่แก้

