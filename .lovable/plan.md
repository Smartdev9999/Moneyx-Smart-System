

## v6.72 — One Hedge Per Generation (ห้าม DD Hedge ครั้งที่ 2 ต่อ generation)

### วินิจฉัยจากภาพ (image-951)
- ออเดอร์ Buy 3 ไม้ของ `Set#2 (GM2)`: `GM2_GL#5 (0.16)`, `GM2_GL#6 (0.22)`, `GM2_GL#7 (0.31)`
- Hedge: `GM_Hedge_D2` (sell 0.53) — **D = DD-triggered, suffix `2` = bound generation 2**
- `0.16 + 0.22 + 0.31 = 0.69 ≠ 0.53` → แสดงว่า hedge ตัวนี้ถูกเปิดตอนที่ Buy ยังไม่ครบ (น่าจะตอนมีแค่ #5+#6 = 0.38 หรือใกล้เคียง) แล้วหลังจากนั้น GL#7 เปิดเพิ่ม
- **ปัญหาที่ user รายงาน**: เมื่อระบบออกกริดเพิ่ม (GL#7) แล้ว DD ของ side Buy พุ่งใหม่ → ระบบมีแนวโน้มออก hedge "รอบที่ 2" ของ generation เดิม → ผู้ใช้ไม่ต้องการพฤติกรรมนี้
- **ความต้องการที่ user ยืนยัน**: "ห้ามไม่ให้ออก hedge ครั้งที่ 2 ตั้งแต่แรก" → 1 generation = 1 hedge ต่อ side เท่านั้น

### Root Cause
ที่ `CheckAndOpenHedgeByDD()` (line 8783–8883):
- มี cooldown (`g_lastDDHedgeTime`, `g_lastHedgeCloseTime`)
- มี per-side pause (`InpHedge_SidePauseMin` → `g_lastHedgeBuyTime/SellTime`)
- มี cap `InpHedge_MaxSets`

แต่ **ไม่มี guard ที่เช็คว่า "generation นี้ + side นี้ มี hedge active อยู่แล้วหรือยัง"**
ผลคือ ถ้า side Buy ของ Gen2 มี `GM_Hedge_D2` อยู่แล้ว แต่ DD ของ Buy พุ่งเกิน threshold อีกครั้ง (เพราะ GL ใหม่เพิ่ม loss) → ระบบสามารถเปิด hedge ตัวที่ 2 สำหรับ Gen2 ได้ (จะเป็น `GM_Hedge_D2` อีกตัวใน slot อื่น) — ไม่ตรงตามเจตนา user

### แผนแก้ (Fix-only, ไม่แตะ trading logic)

ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1) เพิ่ม helper ใหม่ `HasActiveHedgeForGenSide(bindGen, hedgedCounterSide)`
สแกน `g_hedgeSets[]` คืน `true` ถ้ามี set ใดที่:
- `active == true`
- `boundGeneration == bindGen`
- `counterSide == hedgedCounterSide` (ฝั่งที่ขาดทุนซึ่งถูก hedge — เช่น Buy เป็น counter เมื่อ hedge เป็น Sell)

#### 2) เพิ่ม input toggle ใหม่
```cpp
input bool InpHedge_OnePerGenSide = true; // v6.72: Allow only 1 DD hedge per generation per side
```
- Default `true` ตามที่ user ต้องการ
- ถ้าตั้ง `false` พฤติกรรมจะกลับมาเหมือน v6.71

#### 3) ใส่ guard ใน `CheckAndOpenHedgeByDD()` ก่อนเรียก `OpenDDHedge(...)` ทั้ง 4 จุด (Dollar mode 2 จุด + Percent mode 2 จุด)
ตัวอย่างฝั่ง Buy:
```cpp
if(buyLossAbs >= InpHedge_DDTriggerDollar)
{
   if(InpHedge_OnePerGenSide && HasActiveHedgeForGenSide(curGen, POSITION_TYPE_BUY))
   {
      // throttled log every 60s
      static datetime lastLog = 0;
      if(now - lastLog > 60) {
         Print("v6.72 DD HEDGE BLOCKED: BUY side of Gen", curGen, 
               " already has active hedge → no 2nd hedge");
         lastLog = now;
      }
   }
   else if(OpenDDHedge(POSITION_TYPE_BUY, POSITION_TYPE_SELL, curGen)) { ... }
}
```
ทำซ้ำกับ Sell side และ Percent mode

#### 4) เพิ่ม guard ลำดับสองใน `OpenDDHedge()` (defense-in-depth)
ก่อน `FindFreeHedgeSlot()` ใส่:
```cpp
if(InpHedge_OnePerGenSide && HasActiveHedgeForGenSide(bindGen, counterSide))
{
   Print("v6.72 OpenDDHedge BLOCKED: Gen", bindGen, " ", 
         EnumToString(counterSide), " already hedged");
   return false;
}
```
ป้องกันกรณีถูกเรียกจากที่อื่นในอนาคต

#### 5) Dashboard
เพิ่มแถวใหม่ในหมวด Hedge:
```
"OnePerGen": "ENABLED" / "DISABLED"
```

#### 6) Log diagnostics ช่วยตรวจสอบสาเหตุที่ "ไม่ออกออเดอร์เพิ่ม"
ใน `CheckGridLoss()` (gen ปัจจุบัน) เพิ่ม throttled log (ทุก 60s) เมื่อ `shouldOpen == false` ระบุ:
- ระยะปัจจุบันจาก max GL price
- distance threshold ที่ต้องเกิน
- Hedge Side Pause active หรือไม่
- BB filter block หรือไม่

ช่วยให้ user (และเรา) เห็นชัดว่าทำไมไม่มี GL#8 ออกหลัง hedge

#### 7) Version bump → v6.72
- `#property version "6.72"`
- `#property description`
- Header comment block
- Dashboard version string

### สิ่งที่ไม่เปลี่ยนแปลง
- ไม่แก้ `OpenOrder / trade.Buy / trade.Sell / OrderSend`
- ไม่แก้ entry condition ของ initial/grid (`shouldOpen`, distance, ATR, signal filter)
- ไม่แก้ `CalculateGridLot` / `FindMaxLotOnSide`
- ไม่แก้ Hedge Matching Close / Reverse Hedge / Bound logic
- ไม่แก้ Sequential FIFO (v6.70), Sequential Unlock Delay (v6.69), Grid Comment Max-Level (v6.71)
- ไม่แก้ Triple Gate / DD threshold calculation / Generation lifecycle
- ไม่แก้ License / News / Time filter / BB filter

### ผลลัพธ์ที่คาดหวัง
1. เมื่อ `Gen2 BUY` มี `GM_Hedge_D2` active อยู่แล้ว → แม้ DD พุ่งเกิน threshold อีก ระบบจะ **ไม่** ออก hedge ตัวที่ 2 ของ Gen2 BUY
2. ถ้า hedge เซต Gen2 ปิดเรียบร้อย (matching close) → ค่อยเริ่ม cycle ใหม่ (Gen3) hedge ใหม่ได้ตามปกติ
3. Set อื่น generation อื่น (Gen1, Gen3, ...) ยัง hedge ได้อิสระตามเดิม
4. ฝั่ง Sell ของ Gen เดียวกันก็ hedge ได้อิสระจากฝั่ง Buy (เพราะ guard เช็ค side ด้วย)
5. มี log ใน Experts tab อธิบายชัดเจนว่าทำไมไม่ออกอีก hedge / ทำไมไม่ออก GL ถัดไป

### ความเสี่ยง & Mitigation
- **Risk**: ถ้า DD ของ side ที่ถูก hedge แล้วยังเพิ่มขึ้นเรื่อย ๆ ระบบจะไม่ป้องกันเพิ่ม
  **Mitigation**: เป็นเจตนาตามที่ user ขอ → exposure ที่เหลือจัดการด้วย Triple Gate / Matching Close / Balance Guard เดิม + user ปรับ `InpHedge_OnePerGenSide = false` ได้ถ้าต้องการพฤติกรรมเก่า
- **Risk**: User เปลี่ยนใจอยากให้ hedge เพิ่มได้ภายหลัง
  **Mitigation**: toggle input — สลับได้ทันทีโดยไม่ต้อง recompile

