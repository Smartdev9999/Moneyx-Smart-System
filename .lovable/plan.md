## ปัญหาที่เจอ (จาก log + ภาพ)

ใน v1.50 `ManageHeroOppositeClose` ใช้เงื่อนไข:
```text
opp basket = 0 (ไม่นับ Hero) AND oppRealized > InpHero_OppCloseMinProfit → ปิด Hero
```

ปัญหาคือ "opp basket = 0" เกิดได้หลายทาง — **ไม่ใช่แค่ Avg-TP/Avg-Trail trigger**:
- Per-Order Trail / Per-Order BE ค่อย ๆ ปิดทีละไม้กำไรเล็กน้อย
- Master TP Points ของ broker hit ทีละไม้
- SL ของ Cost-Hit / manual close

ตามที่ผู้ใช้เห็น: ราคาขยับขึ้นนิดหน่อย → BUY 2 ไม้โดน Per-Order Trail ปิดกำไรเล็ก → BUY basket = 0 + accumulator > 0 → **Hero SELL ปิดทันที** ทั้งที่ basket BUY **ยังไม่เคยชน Avg-TP**

ความตั้งใจที่ถูกต้อง: Hero ปิดเฉพาะเมื่อ **basket ฝั่งตรงข้าม (ไม่นับ Hero candidate) ชน Average-TP / Avg-Trail HIT / Master TP Dollar / Master TP %Bal / Accumulate HIT** — เพราะตอนนั้น Hero ฝั่งเรากำไรพอดีตามคู่กัน

## แผนแก้ v1.51 — Hero AvgTP-Trigger Only

### 1. เพิ่ม "intent flag" ก่อนเรียก `CloseAllSide / CloseAllOurs` ของกลุ่ม Avg-TP

เพิ่ม global:
```text
bool g_oppCloseIntent_AvgTP_Buy  = false; // BUY basket จะถูกปิดด้วย Avg-TP/Avg-Trail/Accum
bool g_oppCloseIntent_AvgTP_Sell = false; // SELL basket จะถูกปิดด้วย Avg-TP/Avg-Trail/Accum
datetime g_oppCloseIntentTime_Buy  = 0;
datetime g_oppCloseIntentTime_Sell = 0;
```

ตั้ง flag = true ทันที **ก่อน** เรียก CloseAllSide ใน 5 จุดต่อไปนี้ (ไม่แตะ trade.PositionClose / order logic):

| จุด | เงื่อนไข |
|---|---|
| `ManageTakeProfit` Accumulate (1305) | ตั้งทั้งสองฝั่ง (CloseAllOurs ปิดทุกอย่าง) |
| `ManageTakeProfit` TP Dollar (1322)  | ตั้งฝั่งที่ปิด |
| `ManageTakeProfit` TP %Bal (1331)    | ตั้งฝั่งที่ปิด |
| `ManageAverageTrailing` BUY HIT (1391)  | ตั้ง `_Buy = true` |
| `ManageAverageTrailing` SELL HIT (1423) | ตั้ง `_Sell = true` |

หมายเหตุ: `Master TP Points` (Points-from-Average ที่ push TP เข้า broker) จะปิดผ่าน broker TP hit ทีละไม้ — ถ้าผู้ใช้ใช้โหมดนี้ จะตรวจจับยากกว่า ดังนั้นเพิ่ม **option ที่ 2** ด้านล่าง

### 2. แก้ `ManageHeroOppositeClose` (block เดียว, บรรทัด ~870–909)

เปลี่ยนเงื่อนไขจาก `oppRealized > InpHero_OppCloseMinProfit` เป็น:
```text
intentFlag = (heroSide == BUY) ? g_oppCloseIntent_AvgTP_Sell
                                : g_oppCloseIntent_AvgTP_Buy

ปิด Hero ก็ต่อเมื่อ:
  CountNonHeroMainOnSide(opp) == 0  AND  intentFlag == true  AND  oppRealized > InpHero_OppCloseMinProfit
```

ถ้า opp flat แต่ intentFlag = false → **HOLD** (log throttled) + reset accumulator + เคลียร์ค้าง flag ฝั่งนั้น
หลังปิด Hero → ล้าง intent flag ทั้งสองฝั่ง

### 3. (Option B safety net) Master TP Points mode

ถ้า `InpUseTPPoints = true` — broker TP จะ trigger หลายไม้พร้อมกันบนแท่งเดียว:
ดักโดยตรวจ "ภายใน 1–2 วินาทีปิด ≥ `InpAvgTP_MinOrders` ไม้พร้อมกัน" ใน `OnTradeTransaction` → ตั้ง intent flag อัตโนมัติ

เพิ่ม counter ในช่วง `DEAL_ENTRY_OUT` (ที่บล็อกเดียวกันบรรทัด 1718+):
```text
ถ้า DEAL_REASON == DEAL_REASON_TP และไม่ใช่ Hero ticket
  นับจำนวน TP-deal ของฝั่งนั้นในหน้าต่าง 2 วินาที
  ถ้า ≥ InpAvgTP_MinOrders → ตั้ง g_oppCloseIntent_AvgTP_<side> = true
```

### 4. รีเซ็ต intent flag เมื่อ basket ฝั่งนั้น re-arm (มี order non-Hero ใหม่)

ใน `BuildHeroTicketCache` หรือ tick loop: ถ้า `CountNonHeroMainOnSide(side) > 0` AND `intentFlag` ค้างมานาน > 60s → เคลียร์ (กัน flag ค้าง)

### 5. เพิ่ม input toggle (เผื่อเลือกพฤติกรรมเดิม)
```text
input bool InpHero_OppCloseRequireAvgTP = true;  // v1.51 — true=ปิด Hero เฉพาะเมื่อ opp ปิดด้วย Avg-TP/Avg-Trail/Accum,
                                                  //         false=v1.50 (อาศัย realized > 0 + basket=0)
```

### 6. อัปเดต Version v1.50 → v1.51
- Header / `#property version` / `#property description` / Dashboard title / Print logs

### 7. เพิ่ม memory file
`mem://trading/golden-kuy3/v1-51-hero-avgtp-trigger-only.md`

## สิ่งที่ไม่เปลี่ยนแปลง (กฎเหล็ก)

- ❌ `trade.Buy / trade.Sell / trade.PositionClose / OrderSend` — ไม่แตะวิธีส่งคำสั่ง
- ❌ Grid entry/exit / lot multiplier / Initial entry / `CalcGridLot`
- ❌ TP/SL/Trailing/Breakeven calculation, Avg-Trail strict-2-cross, Cost-Hit Restart
- ❌ Accumulate close, Master TP, TP Dollar/%Bal, Master TP Points logic เดิม (เพิ่มแค่ตั้ง flag ก่อนเรียก CloseAllSide เท่านั้น)
- ❌ Price-extreme Hero selection v1.48 / `BuildHeroTicketCache` Branch A v1.49 / `IsHeroProtectedTicket` 9 จุด
- ❌ Side-Alternation Lock v1.46 / Single-Side Lock v1.45 / Post-close grace
- ❌ `ComputeHeroLockProfitSL / ApplyHeroLockProfitSL / StripBrokerTPSLFromHeroTickets`
- ❌ STEP 1 prune + external-close detect / STEP 5 auto-release
- `InpHero_Enabled = false` → พฤติกรรม = v1.50
- `InpHero_OppCloseRequireAvgTP = false` → พฤติกรรม = v1.50

## ผลที่คาดหวัง

1. ราคาขยับเล็กน้อย → BUY 2 ไม้โดน Per-Order Trail ปิด → intent flag ยัง false → **Hero SELL ไม่ปิด** ✅
2. ราคาวิ่งลงต่อ → BUY basket ทั้งหมดชน Avg-Trail HIT → flag = true → CloseAllSide(BUY) → opp flat + flag true → **Hero SELL ปิดพร้อม Avg-TP จริง** ✅
3. ถ้าใช้ Master TP Points: 5 ไม้ BUY โดน broker TP พร้อมกันบนแท่งเดียว → counter ≥ MinOrders → flag auto-set → Hero ปิด ✅
4. SL hit / Cost-Hit / manual close → flag ยัง false → Hero HOLD ที่ BE-SL รอรอบถัดไป ✅
