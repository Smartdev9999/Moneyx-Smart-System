

## v6.70 — บังคับ Strict FIFO ของ Hedge Set (ห้ามข้ามเซต แม้กำไร)

### วินิจฉัยปัญหาจากภาพ

ภาพ image-948 แสดงชัดว่า:
- **GM1_INIT/GL#1–9** (Set#1 ฝั่ง sell) ยังค้างอยู่ ขาดทุนหนัก
- **GM_Hedge_D3** (Set#3) ถูกปิดไปแล้ว และ **GM3_GL#1–5** กำลังรันอยู่ (กำไร)
- ระบบกระโดดไปปิด Set#3 ก่อน Set#1 → ผิดลำดับ FIFO

### Root Cause

ใน `ManageHedgeSets()` (บรรทัด 9819–9891):

```cpp
// ปัจจุบัน: Profit Bypass ข้าม FIFO ทั้งดุ้น
bool seqBypass_profitClose = false;
if(_hPnL > InpHedge_MatchMinProfit) seqBypass_profitClose = true;

if(InpHedge_SequentialRecovery && !seqBypass_profitClose) {
   // ✅ ตรงนี้เช็ค oldest set
   if(g_sequentialRecoveryActive) continue;
   if(h != oldestActiveIdx) continue;
}
else if(seqBypass_profitClose) {
   // ❌ ตรงนี้ไม่เช็ค oldest set — ปล่อยให้ปิดได้เลย!
   // ❌ ไม่เช็ค g_sequentialRecoveryActive — ข้าม owner ด้วย
}
```

**สรุป**: เมื่อ Set#3 หรือ Set#4 มีกำไร > `InpHedge_MatchMinProfit` ระบบปิดทันทีโดยไม่สนว่า Set#1 ยังค้าง — นี่คือการ "ปลดข้ามชุด" ที่ user เจอ

นอกจากนี้ใน v6.67–v6.69 logic profit-bypass ถูกใส่เพื่อ "ลดความเสี่ยง" แต่ขัดเจตนา FIFO ของ user โดยตรง

### แผนแก้ v6.70 (Fix-only)

ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1) เพิ่ม Input toggle สำหรับ Profit Bypass
```cpp
input bool InpHedge_AllowProfitBypass = false; // true=ให้ hedge กำไรปิดข้าม FIFO ได้, false=บังคับ FIFO เคร่งครัด (default)
```
- **Default = false** → กลับไปใช้ FIFO เคร่งครัดตามที่ user ต้องการ
- ใครต้องการพฤติกรรม v6.67–v6.69 เดิม สามารถเปิด `true` ได้เอง

#### 2) ปรับ logic ใน `ManageHedgeSets()` (line ~9819–9891)
- ถ้า `InpHedge_AllowProfitBypass = false` → `seqBypass_profitClose` จะเป็น `false` เสมอ (ปิดบายพาสทั้งหมด)
- เซตทั้งหมดที่ไม่ใช่ oldest จะถูก `continue` ไม่ว่าจะกำไรแค่ไหน
- Owner ของ Gen ก่อนหน้ายัง active → ทุกเซตถูกบล็อกหมด รวมเซตที่กำไรด้วย
- เพิ่ม log: `v6.70 STRICT FIFO BLOCK: Set#X profit=$Y deferred until Set#1 completes`

#### 3) เพิ่มการเช็ค "oldest set" แม้ใน bypass path (กรณี user เปิด bypass)
แม้เปิด `InpHedge_AllowProfitBypass = true` เซตที่จะ bypass ได้ต้องเป็น oldest ที่กำไรเท่านั้น — ไม่ใช่ใครก็ได้ที่กำไร เพื่อกันการกระโดดข้ามชุดยังคงอยู่บางส่วน

#### 4) ตรวจ `FindOldestActiveHedgeSet()` ให้แน่ใจว่า fallback ถูกต้อง
- บรรทัด 8405: เงื่อนไข `(t > 0 && t < oldestTime) || oldestTime == 0` อาจเลือก set ที่มี `hedgeOpenTime = 0` เป็น oldest โดยผิด → ถ้า fallback ดึงจาก ticket แล้วยัง 0 ให้ใช้ `boundGeneration` ต่ำสุดเป็น tiebreaker
- เพิ่ม helper เสริม: ถ้า `hedgeOpenTime` เท่ากันให้เปรียบ `boundGeneration` (gen ต่ำกว่า = เก่ากว่า)

#### 5) Dashboard เพิ่มข้อมูล FIFO position
แถว Hedge Recovery แสดง:
- `Strict FIFO | Next: Set#1 (Gen1) | Waiting: Set#2,3,4`
- ถ้ามี cooldown: `Strict FIFO | Cooldown 0m45s | Next: Set#1`

#### 6) Version bump → v6.70
- `#property version "6.70"`
- `#property description`
- Header comment block
- Dashboard display

### สิ่งที่ไม่เปลี่ยนแปลง
- ไม่แก้ `trade.Buy / trade.Sell / trade.PositionClose / OrderSend`
- ไม่แก้ signal/strategy/grid/TP/SL
- ไม่แก้ Triple Gate (`IsHedgeCloseAllowed`)
- ไม่แก้ Match-Close pool คำนวณ (v6.61)
- ไม่แก้ Sequential Recovery Owner core
- ไม่แก้ Sequential Unlock Delay (v6.69) — ยังทำงานทับอีกชั้น
- ไม่แก้ DD trigger / hedge opening / generation recycle
- ไม่แก้ News/Time Filter/License

### ผลลัพธ์ที่คาดหวัง
1. Set#1 ต้องปิดให้เสร็จ 100% ก่อน Set#2 เริ่มปลด
2. Set#3, Set#4 ที่กำไรอยู่จะ "ค้าง" รอจนกว่า Set#1 จบ — **ไม่ปิดข้ามอีก**
3. Owner Gen lock ยังคุมต่อ ห้ามเซตอื่นแทรก
4. Cooldown 1–2 นาที (v6.69) ยังทำงานต่อระหว่างเซต
5. ถ้า user ต้องการพฤติกรรมเดิม → เปิด `InpHedge_AllowProfitBypass = true`

### รายละเอียดเทคนิค

ลำดับใหม่:
```text
Tick:
  1. หา oldest set (FIFO) จาก hedgeOpenTime
  2. ถ้า g_sequentialRecoveryActive → block ทุกเซต
  3. ถ้า in cooldown (v6.69) → block ทุกเซต
  4. ถ้า h != oldest → block (ไม่ว่ากำไรหรือไม่ — strict mode)
  5. ถ้า h == oldest → ทำ matching/release ปกติ
  6. ตั้ง sequentialActed=true, ใส่ cooldown ถ้ามีการปิด
```

### ความเสี่ยง & Mitigation
- **Risk**: เซตที่กำไรหนักจะถูกค้างไว้ ราคาอาจกลับมาทำให้กำไรหาย
- **Mitigation**: ทำเป็น input toggle (`InpHedge_AllowProfitBypass`) ให้ user เลือกได้

- **Risk**: ถ้า Set#1 ค้างนานมาก เซตหลังจะรอนาน
- **Mitigation**: นี่คือพฤติกรรมที่ user ขอชัดเจน ("ไม่ให้ปลดทันที", "ตามลำดับ") — Triple Gate และ DD recovery ยังทำให้ Set#1 ปิดได้เร็วขึ้นเอง

