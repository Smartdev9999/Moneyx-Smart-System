
## v6.39 — ตรวจสอบ DDCooldown + เพิ่ม Hedge Side Pause

### ส่วนที่ 1: ตรวจสอบ InpHedge_DDCooldownSec

`InpHedge_DDCooldownSec` (ค่า default 60, ผู้ใช้ตั้ง 120) ทำหน้าที่เว้นระยะเวลาขั้นต่ำระหว่าง **การเปิด hedge set ใหม่** — ไม่ใช่ระยะห่างระหว่าง set 1 กับ set 2 โดยเฉพาะ แต่เป็น cooldown หลังจากเปิด hedge ครั้งล่าสุด (ทุกครั้ง)

**ปัญหาที่พบ:** Cooldown นี้ใช้ `g_lastDDHedgeTime` ซึ่งอัปเดตทุกครั้งที่ `OpenDDHedge()` สำเร็จ — แต่ใน v6.37/v6.38 เมื่อทั้งสองฝั่ง trigger พร้อมกัน (ใน tick เดียวกัน) cooldown ไม่ช่วยเพราะทั้งสองฝั่งถูกประเมินใน function call เดียวกัน ก่อนที่ cooldown จะมีผล → **นี่คือ design ที่ถูกต้อง** เพราะ v6.37 ต้องการให้ทั้งสองฝั่ง hedge ได้ในรอบเดียวกัน

Cooldown ทำงานถูกต้องสำหรับ: ป้องกันไม่ให้ gen ถัดไปเปิด hedge ซ้ำภายใน 120 วินาที

### ส่วนที่ 2: เพิ่ม Hedge Side Pause (ฟีเจอร์ใหม่)

**หลักการ:** เมื่อฝั่ง BUY โดน hedge (BUY orders ติดลบ → เปิด SELL hedge) → หยุดเปิดออเดอร์ BUY ใหม่ชั่วคราว เพราะอาจเป็น downtrend | เมื่อฝั่ง SELL โดน hedge → หยุดเปิด SELL ใหม่ เพราะอาจเป็น uptrend

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Version bump → v6.39

#### 2. เพิ่ม input parameter (ใต้ InpHedge_DDCooldownSec)
```cpp
input int InpHedge_SidePauseMin = 0; // v6.39: Pause hedged side entries (minutes, 0=Off)
```

#### 3. เพิ่ม global variables
```cpp
datetime g_lastHedgeBuyTime  = 0;  // เมื่อ BUY orders โดน hedge → pause BUY entries
datetime g_lastHedgeSellTime = 0;  // เมื่อ SELL orders โดน hedge → pause SELL entries
```

#### 4. บันทึกเวลาใน CheckAndOpenHedgeByDD()
- BUY side DD trigger → เปิด SELL hedge → `g_lastHedgeBuyTime = now`
- SELL side DD trigger → เปิด BUY hedge → `g_lastHedgeSellTime = now`

#### 5. เพิ่ม guard ใน OnTick — block ทั้ง INIT entry และ Grid Loss
- BUY INIT + Grid Loss BUY: ถ้า `buyHedgePaused` → skip
- SELL INIT + Grid Loss SELL: ถ้า `sellHedgePaused` → skip

#### 6. Reset เมื่อ flat (TotalOrderCount() == 0)

#### 7. Dashboard แสดงสถานะ pause + เวลาที่เหลือ

### ตัวอย่าง
- ตั้ง 60 นาที → SELL 10 ตัวโดน DD → เปิด BUY hedge → หยุด SELL ใหม่ 60 นาที
- ตั้ง 0 → ปิดฟีเจอร์

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic, Trading Strategy Logic, Core Module Logic — ไม่แก้
- DD trigger / Triple-gate / Matching close — ไม่แก้
- OpenDDHedge / binding / generation logic — ไม่แก้
- Balance Guard (v6.33/v6.35), Daily Target (v6.32) — ไม่แก้
- Gen Race fix (v6.37), Orphan fix (v6.38) — ไม่แก้
- InpHedge_DDCooldownSec — ไม่แก้ (ทำงานถูกต้อง)
