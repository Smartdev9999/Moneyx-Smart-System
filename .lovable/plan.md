

## Fix: เพิ่ม Hedge Slots เป็น 16 + Hedge Cycle Groups เป็น 7 (v5.9 → v5.10)

### สาเหตุ HedgeD2 ไม่เปิด

**MAX_HEDGE_SETS = 4** → หมายความว่ามี **4 slots รวมทั้งระบบ** ไม่ใช่ 4 ต่อ group

เมื่อ HedgeA1 + HedgeB1 + HedgeC1 + HedgeD1 ใช้ครบ 4 slots → `FindFreeHedgeSlot()` return -1 → HedgeD2 เปิดไม่ได้

Guards ทั้งหมดผ่านถูกต้อง — ปัญหาคือ **slot เต็ม**

### การแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. เพิ่ม MAX_HEDGE_SETS จาก 4 เป็น 16

```cpp
#define MAX_HEDGE_SETS 16   // รองรับ 7 groups × 4 hedges ต่อ group (ใช้ได้ถึง 16 slots)
```

7 groups × 4 hedges = 28 ในทฤษฎี แต่ในทางปฏิบัติ hedge sets เก่าจะถูกปิดไปเรื่อยๆ → 16 slots เพียงพอ

#### 2. เพิ่ม Cycle Groups จาก 4 เป็น 7 (A-G)

แก้ทุกจุดที่มี `g_currentCycleIndex < 3` (6 จุด) → `g_currentCycleIndex < 6`

#### 3. แก้ Hedge Cycle Monitor Dashboard — 4 คอลัมน์ → 7 คอลัมน์

- Arrays ทั้งหมด (`groupColors`, `groupNames`, `groupHasHedge`, `groupStatus`) ขยายจาก `[4]` → `[7]`
- เพิ่ม Group E (สีฟ้าอ่อน), F (สีชมพู), G (สีเทาอ่อน)
- ลูปทุกจุด `g < 4` → `g < 7`
- ปรับ `colW` ให้แคบลงพอ 7 คอลัมน์

#### 4. Version bump: v5.9 → v5.10

### สิ่งที่ไม่เปลี่ยนแปลง
- Hedge Guards logic (cycle-aware guards ยังเหมือนเดิม)
- Hedge Partial/Matching/Grid Close logic
- Trading Strategy Logic ทั้งหมด
- Dashboard หลัก

