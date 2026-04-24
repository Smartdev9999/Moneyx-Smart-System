
## Golden2 EA v2.1 — Accumulate Close Re-trigger Loop Fix + Harden Bar-Close Trail

### Root cause (จาก Journal log ของ user)
ในภาพ Journal ทุก tick (03:47:20 → 21 → 22) มี pattern ซ้ำ:
```
Golden2 v2.0: GLOBAL Accumulate Close net=1000.32 >= 1000
order canceled [#1879 sell stop ... at 4599.45]
order canceled [#1878 buy stop  ... at 4609.45]
buy stop  ... at 4609.43 tp 4612.43
sell stop ... at 4599.43 tp 4596.43
Golden2 v2.0: Placed initial frame G1 mid=4604.43...
Golden2 v2.0: GLOBAL Accumulate Close net=1000.32 >= 1000   ← ยิงอีก!
```

**สาเหตุที่แท้จริง:** Accumulate Close trigger สำเร็จ → `CloseEverythingNow()` ลบ pending+ปิด position → tick ถัดไป `AnyOrderInSystem()`=false ครู่หนึ่ง แต่ **`SumRealizedSince()` ยังอ่าน realized=1000.32 จาก history** → tick ถัดไปอีก `PlaceInitialFrame()` วาง pending ใหม่ → `AnyOrderInSystem()` กลับเป็น true ทันที (ก่อนที่ branch reset จะทัน) → `g_accumRealizedSinceReset` ไม่เคย reset → `net ≥ 1000` ตลอดเวลา → **ปิด/เปิดวนทุก tick ทั้งสองฝั่ง**

ที่ user เห็นว่า "stop ขยับทุก tick ทั้งสองฝั่ง" ไม่ใช่ trail bug — เป็นการ **ปิด+ยิงใหม่ทั้งกรอบ initial** จาก loop นี้ Trail v1.8 (bar-close, ฝั่งที่ไกลออก) ทำงานถูกอยู่แล้ว แต่ถูกบดบังด้วย loop ที่ยิงทุก tick

---

### ไฟล์ที่จะแก้
- `public/docs/mql5/Golden2_EA.mq5` — bump version → `2.10`

### สิ่งที่ "ไม่เปลี่ยนแปลง" (ยืนยันไม่กระทบ trading logic)
- ไม่แตะ `OrderSend / trade.Buy / trade.Sell / trade.PositionClose`
- ไม่แตะสูตร Grid Loss / Grid Profit / Frame distance / Hedging mirror / Avg TP-SL / Triple-Gate / Squeeze / License / News / Time filter / Group sequencing / BuyStop TP fix
- ไม่แตะค่า target accumulate / สูตร realized + floating
- ไม่แตะ `ManageInitialTrailOnBarClose` (bar-close trail v1.8 ทำงานถูกแล้ว — แค่เพิ่ม guard กันยิงซ้ำในรอบเดียวกัน)

---

### Fix 1 — Accumulate Close Re-trigger Guard (จุดหลัก)

**คอนเซ็ปต์:** หลัง `CloseEverythingNow()` ทำงาน → **ห้าม trigger อีก** จนกว่าจะเห็น "no orders" จริงๆ และ "เริ่ม cycle ใหม่" ครบรอบ + บล็อกการยิง initial frame ใหม่ในช่วง cooldown

**เพิ่ม global state:**
```cpp
bool     g_accumJustTriggered = false;   // ตั้ง true หลัง CloseEverythingNow()
datetime g_accumTriggerTime   = 0;       // เวลาที่ trigger
input int InpTP_AccumCooldownSec = 30;   // [v2.1] cooldown หลังปิด accumulate (วินาที)
```

**แก้ `ManageGlobalAccumulateClose()`:**
1. ถ้า `g_accumJustTriggered == true`:
   - **ถ้ายังมี order ในระบบ** (ปิดยังไม่หมด เช่นช่วง 1-2 tick แรก) → ไม่ทำอะไร return
   - **ถ้าไม่มี order แล้ว** → force reset: `g_accumRealizedSinceReset=0`, `g_accumResetTime=TimeCurrent()`, `g_accumNetCached=0`, `g_accumFloatingCached=0`, `g_accumJustTriggered=false` (จบ cooldown)
   - **ระหว่าง cooldown `InpTP_AccumCooldownSec`** → เช็ค `TimeCurrent() - g_accumTriggerTime < InpTP_AccumCooldownSec` → return ก่อน trigger ตรวจ ≥ target
2. หลัง `CloseEverythingNow()` สำเร็จ → ตั้ง `g_accumJustTriggered=true; g_accumTriggerTime=TimeCurrent();`

**บล็อกการยิง initial frame ระหว่าง cooldown:**
- ใน `PlaceInitialFrame(g)` เพิ่ม guard ที่ต้นฟังก์ชัน:
  ```cpp
  if(g_accumJustTriggered) {
     if(InpVerboseLog) PrintFormat("Golden2 v2.1: PlaceInitialFrame G%d skipped (accum cooldown)", g);
     return;
  }
  ```
- แบบนี้แม้ history อ่าน realized ค้าง → ก็ไม่ trigger ซ้ำ + ไม่วาง pending ใหม่ → รอจน `AnyOrderInSystem()`=false 1 tick → reset → resume normally

---

### Fix 2 — Harden Bar-Close Trail (กันการยิงซ้ำในแท่งเดิม)

`ManageInitialTrailOnBarClose` ใช้ `g_lastTrailBar[g] == curBar` เป็น guard อยู่แล้ว (line 778) ดังนั้น trail เองไม่ได้ยิงทุก tick อยู่แล้ว — **ไม่ต้องแก้ logic** แค่เพิ่มความชัดเจน:
- เพิ่ม VerboseLog เมื่อ "skip เพราะ side ที่เข้าใกล้" เพื่อ debug ครั้งหน้า
- ยืนยันว่ายัง: ขยับเฉพาะฝั่งที่ราคาวิ่ง **ห่างออก** (newPx ผ่าน threshold เฉพาะทิศทางที่ห่าง) + เฉพาะ M1 bar close (`InpInitTrailTF=PERIOD_M1`)

ไม่มีการแก้ตรรกะ trail (เพราะมันถูกอยู่แล้วตาม spec ที่ user ต้องการ)

---

### Inputs ใหม่ (สรุป)
```cpp
input int InpTP_AccumCooldownSec = 30;  // [v2.1] cooldown หลัง Accumulate Close (วินาที)
```

### Version Bump → 2.10
- `#property version "2.10"`, `#property description`, header comment, `Print` ใน `OnInit`, dashboard `L_TITLE` → `Golden2 EA v2.1`

### บันทึก Memory
- `mem://trading/golden2-ea/v2-1-accum-cooldown-trail-harden.md`

---

### สรุปสำหรับ user (ภาษาไทย)

ปัญหาที่เห็น "stop ขยับทุก tick ทั้งสองฝั่ง" จริงๆ แล้ว **ไม่ใช่ trail bug** ครับ — เป็น Accumulate Close ปิดทำกำไร $1000.32 สำเร็จแล้ว แต่ **trigger ซ้ำทุก tick** เพราะ history ของ broker ส่งค่ากำไรกลับมาช้ากว่าที่ EA ยิง initial frame ใหม่ → วน loop ปิด-เปิดไม่หยุด

แก้โดย: หลัง Accumulate Close ปิดทุกอย่าง → ใส่ **cooldown 30 วินาที** + บล็อกการวาง initial frame ใหม่ในช่วงนี้ → รอ "no orders" จริง → reset cycle → กลับมาเทรดปกติ

Trail logic v1.8 (ขยับเฉพาะฝั่งที่ราคาทิ้งห่าง, M1 bar close) ทำงานถูกตาม spec อยู่แล้ว — ไม่ต้องแก้
