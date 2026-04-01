

## v6.26 — แก้ Sequential Close: ล็อคชุดที่กำลัง process จนกว่าจะเสร็จ

### ปัญหาที่พบ

v6.25 เลือก "oldest eligible" ใหม่ทุก tick → ถ้า Set#3 กำลังทำ grid recovery อยู่ แล้ว Set#1 ผ่าน gate ได้ → ระบบจะสลับไป Set#1 → Set#3 ถูก pause → grid orders ของ Set#3 ยังค้างอยู่

ผลลัพธ์:
- หลาย set มี grid orders ค้างพร้อมกัน (แม้ process ทีละชุด)
- เมื่อ matching close ปิด set ได้ภายใน 1-2 ticks → backtest จะเห็นปิดหลายชุดรวดเร็ว
- drawdown สูงเพราะ grid orders จากหลาย set ค้างอยู่

### Root cause

```cpp
// ทุก tick: เลือกใหม่เสมอ → ไม่ล็อค
int seqActiveIdx = -1;
for(s...) {
   if(IsHedgeCloseAllowed(s) && oldest) seqActiveIdx = s;
}
```

ไม่มี mechanism "ล็อค" set ที่กำลัง process อยู่ → ถ้า set เก่ากว่าผ่าน gate ก็จะถูกสลับไปทันที

### แผนแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. เพิ่ม global variable สำหรับล็อค set ที่กำลัง process

```cpp
int g_seqLockedIdx = -1;  // index of set currently being processed (-1 = none)
```

#### 2. แก้ sequential selection logic ใน `ManageHedgeSets()`

```text
ลำดับความสำคัญ:
1. ถ้า g_seqLockedIdx >= 0 && set นั้นยัง active → ใช้ set นั้นต่อ (ไม่เปลี่ยน)
2. ถ้า g_seqLockedIdx ไม่ valid (set ปิดแล้ว / -1) → หา oldest eligible ใหม่ → ล็อค
3. เมื่อ set ที่ล็อคถูก deactivate → reset g_seqLockedIdx = -1
```

ผลคือ: เมื่อเริ่ม process Set#3 (matching + grid) → จะทำ Set#3 จนจบ → ถึงจะไปหาชุดถัดไป

#### 3. เพิ่ม cooldown ระหว่างชุด

เมื่อชุดหนึ่งปิดเสร็จ (deactivate) → set cooldown timer ก่อนเริ่มชุดถัดไป:

```cpp
datetime g_seqLastCloseTime = 0;       // เวลาที่ชุดล่าสุดปิดเสร็จ
input int InpHedge_SeqCooldownSec = 30; // Cooldown between sequential closes (sec)
```

ป้องกันการปิดหลายชุดติดกันเร็วเกินไป → ลด drawdown spike

#### 4. ทุกจุดที่ deactivate hedge set → reset lock + set cooldown

7 จุด deactivation ที่มีอยู่ → เพิ่ม:
```cpp
if(idx == g_seqLockedIdx) {
   g_seqLockedIdx = -1;
   g_seqLastCloseTime = TimeCurrent();
}
```

#### 5. เพิ่ม log เพื่อ trace sequential behavior

- Log เมื่อ lock set
- Log เมื่อ unlock (set ปิดเสร็จ)
- Log เมื่อ cooldown กำลัง active

#### 6. Recovery: `RecoverHedgeSets()` → recover lock

ถ้ามี set ที่อยู่ใน gridMode หรือ matchingDone → ล็อค set เก่าสุดที่ active

#### 7. Version bump: v6.25 → v6.26

### Technical details

```text
ก่อน (v6.25):
  Tick 1: Set#3 gate OK → seqActiveIdx=3 → matching close
  Tick 2: Set#1 gate OK (older) → seqActiveIdx=1 → สลับไป Set#1
  Tick 3: Set#1 done → seqActiveIdx=3 → กลับมา Set#3
  ผลลัพธ์: ทั้ง Set#1 และ Set#3 มี orders ค้างพร้อมกัน

หลัง (v6.26):
  Tick 1: Set#3 gate OK → lock=3 → matching close
  Tick 2: Set#1 gate OK แต่ lock=3 → ข้าม → ทำ Set#3 ต่อ
  Tick N: Set#3 grid done → deactivate → lock=-1 → cooldown 30s
  Tick N+30s: cooldown หมด → หา oldest eligible → Set#1 → lock=1
  ผลลัพธ์: ทำทีละชุดจริงๆ ไม่มี orders ค้างข้ามชุด
```

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic — ไม่แก้
- Trading Strategy Logic — ไม่แก้
- Core Module Logic — ไม่แก้
- Triple-gate exit logic — ไม่แก้
- Matching close / Grid recovery logic ภายใน — ไม่แก้
- DD trigger / generation-aware isolation — ไม่แก้
- Orphan recovery — ไม่แก้ (แยก system)

