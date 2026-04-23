

## v6.71 — Fix: comment ของ GL/GP ซ้ำเลขเดิมหลัง Hedge ปลดปิดไม้กลาง

### วินิจฉัยจากภาพ
ในภาพออเดอร์ฝั่ง buy ของ Set#2 มีลำดับ:
- GM2_GL#5, GM2_GL#6, GM2_GL#7, GM2_GL#8, GM2_GL#9, GM2_GL#10
- จากนั้น EA เปิดเพิ่ม: **GM2_GL#7, GM2_GL#8, GM2_GL#9** (ซ้ำเลขเดิม!)

เกิดเพราะหลัง hedge matching/partial close ปิดไม้ระดับล่าง (GL#1–#4) ทำให้ `currentGridCount` ลดลง พอ EA จะเปิด GL ใหม่ จะใช้ `currentGridCount + 1` → ได้เลขที่ **เคยใช้ไปแล้ว** และยังเปิดอยู่ (#7, #8, #9) → ซ้ำ

### Root Cause
ใน `Gold_Miner_EA.mq5` ทั้ง 4 จุดยังใช้ `currentGridCount + 1` ตรงๆ:
- บรรทัด 3456 `CheckGridLoss` → `"_GL#" + (currentGridCount + 1)`
- บรรทัด 3528 `CheckGridProfit` → `"_GP#" + (currentGridCount + 1)`
- บรรทัด 5192 `CheckGridLossTF` → `"GL#" + (currentGridCount + 1)`
- บรรทัด 5263 `CheckGridProfitTF` → `"GP#" + (currentGridCount + 1)`

แม้เคยมีแผน v6.71 (memory `grid-comment-max-level-v6-71`) แต่ **โค้ดจริงไม่เคยถูกแก้** — ยังเป็นพฤติกรรมเดิม

### แผนแก้ v6.71 (Fix-only)

ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1) เพิ่ม helper `FindMaxGridLevelOnSide(side, suffix)`
สแกนทุก position ของ MagicNumber + symbol + side ปัจจุบัน เลือกเฉพาะ generation เดียวกับ `g_cycleGeneration` และที่มี suffix `_GL` หรือ `_GP` แล้วดึงเลขหลัง `#` มาหาค่า max
- ข้าม hedge comments (`IsHedgeComment`)
- ข้าม bound tickets (`IsTicketBound`)
- ใช้ `ExtractGeneration(comment)` กรอง gen ตรง

#### 2) เพิ่ม helper `FindMaxGridLevelOnSideTF(tfIdx, side, suffix)`
สำหรับโหมด TF — กรองด้วย prefix ของ TF (เหมือน `FindLastOrderTF`)

#### 3) แก้ comment ที่ 4 จุด
แทนที่:
```cpp
"_GL#" + IntegerToString(currentGridCount + 1)
```
ด้วย:
```cpp
int maxLvl = FindMaxGridLevelOnSide(side, "_GL");
int nextLvl = MathMax(maxLvl + 1, currentGridCount + 1);
"_GL#" + IntegerToString(nextLvl)
```
ทำเหมือนกันสำหรับ `_GP`, และ TF version

#### 4) สิ่งที่ไม่เปลี่ยนแปลง (ตามกฎเหล็ก)
- ไม่แก้ `OpenOrder / OpenOrderTF / trade.Buy / trade.Sell / trade.PositionClose`
- ไม่แก้เงื่อนไขเปิด GL/GP (distance, ATR, candle, BB filter)
- ไม่แก้ `CalculateGridLot / FindMaxLotOnSide` — lot ยังคงใช้ค่าเดิมตาม max existing lot
- ไม่แก้ Hedge / Sequential FIFO / Cooldown / Strict FIFO (v6.70)
- ไม่แก้ MaxOpenOrders / MaxTrades gate
- ไม่แก้ Triple Gate, Match-Close pool, Owner lock
- ไม่แก้ License/News/Time filter

#### 5) Version bump → v6.71
- `#property version "6.71"`
- `#property description "Gold Miner EA v6.71 - v6.70 + Grid comment numbering uses MAX(maxLevel+1, count+1) — no duplicate GL#/GP# after hedge unlock"`
- Header comment block
- Dashboard footer string

### ผลลัพธ์ที่คาดหวัง
จากภาพ: maxLevel ปัจจุบัน = 10 (GM2_GL#10) → ไม้ถัดไปจะเป็น **GM2_GL#11** เสมอ ไม่ว่า count จริงเหลือกี่ไม้หลัง hedge ปิดไป
- ไม่มีการซ้ำเลข GL#/GP# ภายในเซตเดียวกัน อีก
- รักษา property: เลขเรียงเพิ่มขึ้นเสมอ ภายใน gen เดียวกัน
- Lot sizing คงใช้ `FindMaxLotOnSide` เดิม → lot ยังคงต่อเนื่อง
- MaxTrades gate ยังคุมจำนวนรวม ไม่ทำให้เกินลิมิต

### ความเสี่ยง & Mitigation
- **Risk**: ถ้า user ปิดเองด้วยมือทั้งหมด แล้วเริ่มใหม่ใน gen เดิม → maxLevel = 0 → เริ่มที่ #1 ปกติ ไม่มีปัญหา
- **Risk**: ตัวเลขอาจขึ้นเลย `MaxTrades` เช่น #15 ขณะที่นับจริงเหลือ 6 → เป็นเลข label เท่านั้น ไม่กระทบ logic เพราะ gate ใช้ count ไม่ใช่ level
- **Risk**: TF mode มี prefix ต่างจาก standard → helper TF version ใช้ตัวกรอง prefix แยกตาม `FindLastOrderTF` pattern เพื่อไม่ปนข้าม TF

