## v6.39 — ตรวจสอบ DDCooldown + เพิ่ม Hedge Side Pause

### ส่วนที่ 1: ตรวจสอบ InpHedge_DDCooldownSec

`InpHedge_DDCooldownSec` (ค่า default 60, ผู้ใช้ตั้ง 120) ทำหน้าที่เว้นระยะเวลาขั้นต่ำระหว่าง **การเปิด hedge set ใหม่** — ไม่ใช่ระยะห่างระหว่าง set 1 กับ set 2 โดยเฉพาะ แต่เป็น cooldown หลังจากเปิด hedge ครั้งล่าสุด (ทุกครั้ง)

**ปัญหาที่พบ:** Cooldown นี้ใช้ `g_lastDDHedgeTime` ซึ่งอัปเดตทุกครั้งที่ `OpenDDHedge()` สำเร็จ — แต่ใน v6.37/v6.38 เมื่อทั้งสองฝั่ง trigger พร้อมกัน (ใน tick เดียวกัน) cooldown ไม่ช่วยเพราะทั้งสองฝั่งถูกประเมินใน function call เดียวกัน ก่อนที่ cooldown จะมีผล → **นี่คือ design ที่ถูกต้อง** เพราะ v6.37 ต้องการให้ทั้งสองฝั่ง hedge ได้ในรอบเดียวกัน

Cooldown ทำงานถูกต้องสำหรับ: ป้องกันไม่ให้ gen ถัดไปเปิด hedge ซ้ำภายใน 120 วินาที

### ส่วนที่ 2: เพิ่ม Hedge Side Pause (ฟีเจอร์ใหม่)

**หลักการ:** เมื่อฝั่ง SELL โดน hedge (เปิด BUY hedge) → หยุดเปิดออเดอร์ SELL ใหม่ชั่วคราว (ทั้ง INIT และ Grid Loss) ตามเวลาที่กำหนด เพราะอาจเป็น trend ที่กำลังดำเนินอยู่ เช่นเดียวกันฝั่งตรงข้าม

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Version bump → v6.39

#### 2. เพิ่ม input parameter (ใต้ InpHedge_DDCooldownSec)
```cpp
input int      InpHedge_SidePauseMin         = 0;     // v6.39: Pause hedged side entries (minutes, 0=Off)
```

#### 3. เพิ่ม global variables
```cpp
datetime g_lastHedgeBuyTime  = 0;   // v6.39: last time BUY-side hedge opened (= SELL orders got hedged → pause SELL)
datetime g_lastHedgeSellTime = 0;   // v6.39: last time SELL-side hedge opened (= BUY orders got hedged → pause BUY)
```

#### 4. อัปเดต CheckAndOpenHedgeByDD() — บันทึกเวลา hedge แต่ละฝั่ง
เมื่อ BUY side DD trigger → เปิด SELL hedge → บันทึก `g_lastHedgeBuyTime = now` (ฝั่ง BUY โดน hedge → pause BUY entries)
เมื่อ SELL side DD trigger → เปิด BUY hedge → บันทึก `g_lastHedgeSellTime = now` (ฝั่ง SELL โดน hedge → pause SELL entries)

#### 5. เพิ่ม guard conditions ใน OnTick entry logic
ก่อน BUY Entry (line ~1443) และ Grid Loss BUY (line ~1393):
```cpp
bool buyHedgePaused = (InpHedge_SidePauseMin > 0 && g_lastHedgeBuyTime > 0 
                       && (TimeCurrent() - g_lastHedgeBuyTime) < InpHedge_SidePauseMin * 60);
```
ก่อน SELL Entry (line ~1464) และ Grid Loss SELL (line ~1397):
```cpp
bool sellHedgePaused = (InpHedge_SidePauseMin > 0 && g_lastHedgeSellTime > 0 
                        && (TimeCurrent() - g_lastHedgeSellTime) < InpHedge_SidePauseMin * 60);
```

Block ทั้ง INIT entry และ Grid Loss entry ของฝั่งที่โดน hedge

#### 6. Reset เมื่อ cycle reset (TotalOrderCount() == 0)
```cpp
g_lastHedgeBuyTime = 0;
g_lastHedgeSellTime = 0;
```

#### 7. Dashboard — แสดงสถานะ pause
แสดง "BUY PAUSED (hedge)" หรือ "SELL PAUSED (hedge)" พร้อมเวลาที่เหลือ

#### 8. อัปเดต version ทุกจุด

### ตัวอย่าง
- ตั้ง `InpHedge_SidePauseMin = 60`
- SELL orders 10 ตัวโดน DD → เปิด BUY hedge → `g_lastHedgeSellTime = now`
- ถัด 60 นาที: ระบบจะไม่เปิด SELL INIT หรือ SELL Grid Loss ใหม่
- หลัง 60 นาที: เปิด SELL ได้ตามปกติ
- ตั้ง `InpHedge_SidePauseMin = 0` → ปิดฟีเจอร์ ไม่มีผลใดๆ

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic — ไม่แก้
- Trading Strategy Logic — ไม่แก้
- Core Module Logic — ไม่แก้
- DD trigger / Triple-gate / Matching close — ไม่แก้
- OpenDDHedge / binding / generation logic — ไม่แก้
- Balance Guard (v6.33/v6.35) — ไม่แก้
- Daily Target Profit (v6.32) — ไม่แก้
- Generation Race Condition fix (v6.37) — ไม่แก้
- Orphan Gen fix (v6.38) — ไม่แก้
- InpHedge_DDCooldownSec — ไม่แก้ (ทำงานถูกต้องตาม design)