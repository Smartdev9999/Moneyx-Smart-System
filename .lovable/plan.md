

## Golden2 EA v1.4 — Hedging Master Toggle + Lot Mirror Fix + Pre-Hedge Block + Dynamic Top-Up

ปรับลอจิก Hedging ทั้งระบบให้ตรงกับพฤติกรรม Gold Miner: Hedge ต้อง mirror ออเดอร์ฝั่งตรงข้ามแบบ 1:1 จริง (ทั้ง lot และ comment), เพิ่ม master toggle, หยุดออกออเดอร์ใหม่เมื่อใกล้แตะเกณฑ์ hedge, และ top-up pending hedge ทุกครั้งที่ฝั่ง loss มีไม้เพิ่ม

### ไฟล์ที่จะแก้
- `public/docs/mql5/Golden2_EA.mq5` (ไฟล์เดียว)

### สิ่งที่ "ไม่เปลี่ยนแปลง" (ยืนยันไม่กระทบ trading logic)
- ไม่แตะ `OrderSend / trade.Buy / trade.Sell / trade.PositionClose` ในส่วน strategy หลัก
- ไม่แตะลอจิก Grid Loss / Grid Profit / Max-Grid Trailing
- ไม่แตะ Triple-Gate Matching Close, Average TP/SL sync (v1.3), Strip-Broker-TPSL
- ไม่แตะ License/News/Time filter
- ไม่เปลี่ยนสูตรคำนวณ DD% ที่ใช้ trigger hedge (ยังเป็น `lossUSD/InpHedgeTriggerUSD × 100`)

---

### 1) Master Toggle เปิด/ปิด Hedging
เพิ่ม input ใหม่:
```
input bool InpHedge_Enabled = true;   // Enable Hedging system (master switch)
```
- ถ้า `false`: ข้าม `ManageGroupHedgeArm`, ไม่วาง pending hedge ใหม่, ไม่ block new orders จาก pre-hedge guard, dashboard แสดง `HEDGE: OFF`
- ถ้ามี pending hedge ค้างอยู่ตอนปิด toggle → ลบทิ้งอัตโนมัติครั้งเดียว (ไม่ปิดไม้ hedge ที่ activate แล้ว — ปลอดภัย)

### 2) แก้บั๊กขนาดล็อต Hedge 1:1 (Mirror จริง)
**ปัญหาปัจจุบัน:** `PlaceHedgePendingSet` ใช้ `LotForLevel(lvl)` (สูตร multiply ของ grid ใหม่) → ทำให้ pending hedge ใหญ่กว่าฝั่งตรงข้ามมาก

**แก้ใหม่:** สแกนไม้ฝั่ง loss ทุกตัว (ทั้ง IN และ GL#1..GL#N) แล้วสร้าง pending hedge **1 ตัวต่อ 1 ไม้** โดย:
- `lot ของ pending hedge[i] = lot ของไม้ loss[i]` (mirror ตรง ๆ ตามที่ user ต้องการ)
- `comment ของ pending hedge[i] = "G{g}_HD_" + (tag ของไม้ loss[i])` เช่น loss `G1_IN` → hedge `G1_HD_IN`, loss `G1_GL#7` → hedge `G1_HD_GL#7`
- Sort ไม้ loss ตามราคา open เพื่อให้ pending วางเป็นแนวชัดเจน
- ใช้ `InpHedgeLotMatch1to1` เป็น gate: ถ้า `false` → fallback เก่า (แต่แก้ให้ใช้ lot ของไม้ loss แทน LotForLevel)

### 3) Dynamic Top-Up Pending Hedge
เมื่อ pending set ถูกวางแล้ว และฝั่ง loss มีไม้ใหม่เพิ่ม (เช่นจาก 10 → 11 ไม้):
- ทุก tick ใน `ManageGroupHedgeArm`: เปรียบเทียบ `count(loss positions)` กับ `count(hedge pendings)`
- ถ้า loss > hedge pending → เพิ่ม pending hedge ใหม่เฉพาะไม้ที่ยังไม่มี comment match (เช็ค `G1_HD_GL#11` ว่ามีอยู่ไหม)
- lot/comment ตาม rule ข้อ 2
- ถ้า loss < hedge pending (ไม้ loss ปิดไปก่อน) → ลบ pending hedge ที่ comment ไม่มี match แล้ว
- ทำเฉพาะตอน `hedgePosExists == false` (ยังไม่ activate); ถ้า activate แล้วไม่ยุ่ง

### 4) Pre-Hedge Block New Orders
เพิ่ม input:
```
input double InpHedge_BlockNewOrderPercent = 75.0;  // Block new grid orders when DD% reaches (0=off, < ArmPercent)
```
- เมื่อ `pct >= InpHedge_BlockNewOrderPercent` ในกรุ๊ปใด → set `g_blockNewOrders[g] = true`
- ผลกระทบ (เพิ่ม guard ที่ "ทางเข้า" ฟังก์ชันที่เปิดไม้ใหม่ ไม่แตะ logic การคำนวณ):
  - `TryPlaceGridLoss(g)` → return ถ้า block
  - `TryPlaceGridProfit(g)` → return ถ้า block
  - การวางกรุ๊ปถัดไป (`PlaceInitialFrame(next)` ใน sequential queue) → return ถ้ากรุ๊ปปัจจุบัน block
- ปลด block เมื่อ `pct < InpHedge_BlockNewOrderPercent - 5` (hysteresis 5%) — กัน flap
- Disarm 70% (มีอยู่แล้ว) ยังทำงานเหมือนเดิม → ลบ pending hedge เมื่อ DD ลดลง
- Dashboard ต่อกรุ๊ป: เพิ่ม flag `BLK` เมื่อ block อยู่

### 5) Cross-Group Activation (มีอยู่แล้ว — แค่ยืนยัน)
เมื่อราคาวิ่งทะลุชน pending hedge ของกรุ๊ปปัจจุบัน → hedge activate → `g_stripped[g]=true` → กรุ๊ปนี้เข้าโหมด matching close
Sequential queue เดิมจะตรวจและเปิด **กรุ๊ปใหม่ (g+1)** อัตโนมัติด้วย input ชุดเดิม — ทำงานแยกกรุ๊ป **ไม่ต้องแก้** เพราะมีอยู่แล้วใน `OnTick` (`PlaceInitialFrame(next)`)

ยืนยันว่า: pre-hedge block ของกรุ๊ป g **ไม่ block** การเปิดกรุ๊ป g+1 หลัง hedge activate (เพราะกรุ๊ป g เข้าโหมด stripped/matching แล้ว ไม่นับเป็น pre-hedge)

### 6) Dashboard
เพิ่มต่อกรุ๊ปที่ active:
```
G1: DD 65% [BLK] HEDGE:ARMED(11p)  AVG-BR(B:11) INIT(S:1)
```
- `DD%` = pct ของกรุ๊ป
- `[BLK]` = pre-hedge block อยู่
- `HEDGE: OFF | IDLE | ARMED(Np) | ACTIVE` ; `Np` = จำนวน pending hedge

### Inputs ใหม่ (สรุป)
```
input bool   InpHedge_Enabled              = true;   // Master Hedging on/off
input double InpHedge_BlockNewOrderPercent = 75.0;   // Stop new grid when DD% ≥ this (0=off)
```
(คงเดิมทั้งหมด: `InpHedgeTriggerUSD`, `InpHedgeArmPercent=80`, `InpHedgeDisarmPercent=70`, `InpHedgeLotMatch1to1`, `InpHedge_OpenDelayMin`)

### Technical Detail
- `MirrorLossSideToHedgePendings(g, lossSide)`: scan loss positions → build map `tag→lot` → for each tag, ถ้ายังไม่มี pending `HD_<tag>` ให้สร้าง; ถ้ามี pending ไม่ตรง tag loss แล้วให้ลบ
- ราคา pending: ใช้ราคาเดียวกันทั้ง set (anchor ห่างจาก market `MathMax(50, InpGridStepPips/4)` points ฝั่งตรงข้าม) — เหมือนภาพที่ user แสดง (ทุกไม้ pending วางใกล้ราคาเดียวกัน) เพื่อให้ activate พร้อมกันเมื่อราคาทะลุ
- Block guard: เพิ่มบรรทัดเดียวที่ต้นฟังก์ชัน Try* — ไม่แตะลอจิกข้างใน
- Bump version → `1.40` ทุกจุด (`#property version`, `description`, header, dashboard)

