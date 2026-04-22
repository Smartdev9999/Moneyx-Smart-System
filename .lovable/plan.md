

## v6.71 — แก้ปัญหา Grid Comment ซ้อน/ย้อนเลขหลัง Hedge ปลดล็อค

### วินิจฉัย (จาก image-949)

ออเดอร์เปิดอยู่: `GM1_GL#6, #7, #8, #9` (ฝั่ง Buy, Set#1)
ออเดอร์ใหม่ที่เพิ่งออก: `GM1_GL#5` ← **เลขย้อนหลังต่ำกว่าของเดิม**

**Root cause** อยู่ที่ `CheckGridLoss()` บรรทัด 3361–3463:

```cpp
void CheckGridLoss(ENUM_POSITION_TYPE side, int currentGridCount)
{
   ...
   string comment = GetCommentPrefix() + "_GL#" + IntegerToString(currentGridCount + 1);
}
```

`currentGridCount` คือ **จำนวน GL ที่เปิดอยู่ตอนนี้** (นับจาก `gridLossBuy` ที่ line 1863) ไม่ใช่ "เลข GL สูงสุดที่เคยใช้"

ผลที่เกิด:
- ก่อนปลด hedge: เคยมี GL#1–#9 ครบ
- หลัง matching-close หรือ partial-close ของ hedge ทำให้ GL#1–#5 ปิดไป → เหลือเปิด 4 ตัว (GL#6–#9)
- เมื่อราคาเลื่อนพอเปิดกริดถัดไป: `currentGridCount = 4` → comment = `GL#5`
- **ซ้ำกับเลขที่เคย ใช้** (GL#5 ที่ปิดไปแล้ว) และ "ต่ำกว่า" GL#6–9 ที่ยังเปิดอยู่ → ลำดับเลขไม่สอดคล้อง สับสน และมีโอกาสที่ logic อื่นที่อ้าง comment จะเข้าใจผิด (เช่น matching pool, FIFO, log)
- Lot size ยังถูกอยู่เพราะใช้ `FindMaxLotOnSide` (บรรทัด 3446) → ตรงกับที่ user สังเกต

ปัญหาเดียวกันมีใน:
- `CheckGridLoss()` บรรทัด 3456 (gen ปัจจุบัน, GL)
- `CheckGridProfit()` บรรทัด 3528 (gen ปัจจุบัน, GP)
- `CheckGridLossTF()` บรรทัด 5192 (TF mode, GL)
- `CheckGridProfitTF()` บรรทัด 5263 (TF mode, GP)

### แผนแก้ (Fix-only, ไม่แตะ trading logic)

ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1) เพิ่ม helper ใหม่ `FindMaxGridLevelOnSide(side, suffix)`
สแกน positions ของ MagicNumber + symbol + side + generation ปัจจุบัน + comment ที่ลงท้าย `_GL#N` หรือ `_GP#N` แล้วคืน "เลข N สูงสุด" ที่ยังเปิดอยู่ (skip hedge/bound, เช็ค `ExtractGeneration == g_cycleGeneration`)

ใช้ pattern เดียวกับที่มีอยู่แล้วใน `CountOrphanPositions()` (line 9329–9333) → extract เลขหลัง `#`

#### 2) แก้การตั้ง comment ให้ใช้ "max level + 1" แทน "count + 1"

ใน `CheckGridLoss()` (line 3456):
```cpp
int maxLevel = FindMaxGridLevelOnSide(side, "_GL");
int nextLevel = MathMax(maxLevel + 1, currentGridCount + 1);
string comment = GetCommentPrefix() + "_GL#" + IntegerToString(nextLevel);
```
- ใช้ `MathMax` กันกรณี edge เช่น hedge ปิด GL#9 ลำพังเหลือ GL#1–#8 → max+1=9 ซ้ำ → fallback เป็น count+1=9 ก็ยัง OK (และเรา block ซ้ำเพิ่มในข้อ 3)

จริงๆ ที่เหมาะสมที่สุดคือใช้ `maxLevel + 1` เป็นหลักเสมอ เพราะ hedge ที่ปลดล็อคจะปิดเรียงจาก GL#1 ขึ้นไป (FIFO) → max ของ GL ที่เหลือคือ "เลขสุดท้ายที่เคยเปิด" → +1 ได้เลขใหม่ที่ไม่ซ้ำเสมอ

#### 3) ใช้ pattern เดียวกันกับอีก 3 จุด
- `CheckGridProfit()` line 3528 → ใช้ `FindMaxGridLevelOnSide(side, "_GP")`
- `CheckGridLossTF()` line 5192 → ใช้ helper version TF (อ่าน prefix ของ TF set)
- `CheckGridProfitTF()` line 5263 → เช่นเดียวกัน

(สำหรับ TF: helper รับ `tfPrefix` เพิ่มเพื่อ match prefix ที่ถูกต้อง)

#### 4) เพิ่ม log debug
```cpp
Print("v6.71 GRID NEXT-LEVEL: side=", EnumToString(side),
      " openGL=", currentGridCount, " maxLevel=", maxLevel,
      " → nextLevel=", nextLevel, " comment=", comment);
```
ช่วย verify ว่าหลังแก้แล้วเลขใหม่ > เลขที่เปิดอยู่ทั้งหมดเสมอ

#### 5) Version bump → v6.71
- `#property version "6.71"`
- `#property description`
- Header comment block
- Dashboard version string

### สิ่งที่ไม่เปลี่ยนแปลง
- ไม่แก้ `OpenOrder / trade.Buy / trade.Sell / OrderSend`
- ไม่แก้ entry condition (`shouldOpen`, distance, ATR, signal filter)
- ไม่แก้ `CalculateGridLot` / `FindMaxLotOnSide` (lot ยังถูกต้องอยู่แล้ว)
- ไม่แก้ Hedge logic / Match-Close pool / Sequential FIFO (v6.70)
- ไม่แก้ Sequential Unlock Delay (v6.69)
- ไม่แก้ Triple Gate / DD trigger / Generation lifecycle
- ไม่แก้ License / News / Time filter

### ผลลัพธ์ที่คาดหวัง
1. หลัง hedge ปลดล็อคและ GL#1–#5 ปิดไป → grid ใหม่จะเป็น `GL#10`, `GL#11`, ... ต่อจาก max ที่ยังเปิด (GL#9)
2. Lot size ยังถูกเหมือนเดิม (ใช้ `FindMaxLotOnSide`)
3. ไม่มี comment ซ้ำกับที่เคยใช้ → log/dashboard/match pool อ่านลำดับได้ถูกต้อง
4. ไม่กระทบกริด generation อื่น (GM, GM2, ...) เพราะ helper เช็ค `ExtractGeneration`

### ความเสี่ยง & Mitigation
- **Risk**: ถ้า `GridLoss_MaxTrades = 10` แต่ max level เคยขึ้นถึง 10 แล้วบางตัวปิดไป → `maxLevel+1 = 11` เกิน MaxTrades  
  **Mitigation**: gate `if(currentGridCount >= GridLoss_MaxTrades) return;` ที่ line 3363 ยังทำงานปกติ (นับจำนวนเปิดอยู่) → จะไม่เปิดเพิ่มเกิน MaxTrades แต่เลข comment สูงขึ้นได้ (เพื่อหลีกเลี่ยงซ้ำ) — พฤติกรรมที่ user ต้องการ

- **Risk**: ถ้า user ต้องการให้เลขรีเซ็ตเป็น 1 หลัง matching close ทุกครั้ง  
  **Mitigation**: ไม่ใช่ความตั้งใจตาม report → ถ้าต้องการพฤติกรรมเดิม ค่อยเพิ่ม input toggle ภายหลัง

