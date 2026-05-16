## ปัญหา

หลังจาก Triple-Gate Matching Close ออก RC#1 แล้ว ระบบ **หยุดยิง RC เพิ่ม** แม้ราคาจะเคลื่อนต่อจนเกินระยะ grid ปกติ ทำให้ฝั่งติดลบไม่มี order เฉลี่ยใหม่เข้ามาช่วยปิด

## Root Cause

1. `PlaceRecoveryGridIfNeeded()` ถูกเรียก **ครั้งเดียวต่อ match-close cycle** (line 2560 ใน `TryMatchingCloseForGroup`) — ไม่มี loop ต่อเนื่องในทุก tick
2. `TryPlaceGridLoss()` ที่รันทุก tick ติด guard `IsGroupHedgeMatched(g)` (line 1616) → หลัง match-close ฝั่งติดลบยังมีทั้ง main + hedge-orphan-offset อยู่ → `CountGroupPositions(g,-1,0)>0 && CountGroupPositions(g,-1,1)>0` = TRUE → bail ตลอด → GL#N ก็ไม่ออก, RC#N ก็ไม่ต่อ
3. ผลคือเหลือแค่ RC#1 แช่ตลอด ไม่มีการเฉลี่ย

## แผน v2.8.8

เพิ่ม **Recovery Grid Continuation** — ทำงานต่อเนื่องทุก tick เมื่อ `g_groupInRecovery[g] == true`

### A) ฟังก์ชันใหม่: `TryPlaceRecoveryGridContinuation(int g)`

ใส่ก่อน/หลัง `TryPlaceGridLoss(g)` ใน OnTick loop (line ~3906):

- guard: `if(!InpRecovery_Enable) return;`
- guard: `if(!g_groupInRecovery[g]) return;`
- guard: `if(g_groupRecoveryLevel[g] >= InpRecovery_MaxLevels) return;`
- หา `losSide` = ฝั่งที่ยังเหลือ position ในกลุ่มนี้ (ฝั่งกำไรถูกปิดไปแล้ว)
  - ถ้าไม่มี position เลย → group จะถูก reset โดย OnTick housekeeping (clear `g_groupInRecovery`)
- หา `lastPrice = LastEntryPrice(g, losSide, false)` — ราคา entry ล่าสุดของ losing side (รวม RC#N ล่าสุด, เพราะ RC สร้างด้วย `MakeComment(...,false,...)` → hd=false)
- คำนวณ `gapPts = (InpRecovery_DistancePips>0) ? InpRecovery_DistancePips : GridLoss_Points`
- trigger:
  - BUY losing: `ask <= lastPrice - gapPts*g_point`
  - SELL losing: `bid >= lastPrice + gapPts*g_point`
- ถ้า trigger → เรียก `PlaceRecoveryGridIfNeeded(g, losSide)` ซ้ำได้ (มันจะ `level+1`, lot คูณ multiplier เอง, log เดิม)
- ป้องกัน double-fire ในแท่งเดียวกัน: ใช้ array ใหม่ `datetime g_lastRecoveryCandle[51]` ถ้าต้องการให้ออกแค่ครั้งเดียวต่อแท่ง (ตามสไตล์ `GridLoss_OnlyNewCandle`) — default ON

### B) เพิ่ม input ใหม่

```
input bool InpRecovery_OnlyNewCandle = true; // [v2.8.8] RC#2..N: รอแท่งใหม่ก่อนยิง RC ถัดไป
```

### C) Globals ใหม่

```
datetime g_lastRecoveryCandle[51]; // เคลียร์ใน OnInit + group-empty branch
```

### D) เรียกใน OnTick

เพิ่มบรรทัดใน main loop ต่อจาก `TryPlaceGridProfit(g);`:
```
TryPlaceRecoveryGridContinuation(g); // [v2.8.8]
```

### E) Dashboard

แถว Recovery แสดงเหมือนเดิม (`RECOV RC#n/N`) — ตัวเลขจะอัปเดตอัตโนมัติเมื่อ level เพิ่ม

### F) Version & Header

- `#property version "2.88"`
- `#property description` อัปเดตเพิ่ม "Recovery Grid Continuation: RC#2..N auto-fires at GridLoss distance while in recovery."
- Dashboard title → v2.8.8
- Init log → v2.8.8

## สิ่งที่ไม่เปลี่ยนแปลง (Rules of Steel)

- ❌ Order execution (trade.Buy/Sell ของ RC ใช้ logic เดิมใน `PlaceRecoveryGridIfNeeded`)
- ❌ Triple-Gate Matching Close logic / Reserve-Profit (v2.8.7) / Shred passes
- ❌ Hedge Orphan Offset (v2.8.6) / One-Hedge-Per-Group (v2.8.5) / Post-Match Avg TP (v2.8.4)
- ❌ TryPlaceGridLoss / TryPlaceGridProfit (ยังคง freeze ตอน hedge matched ตามเดิม)
- ❌ Squeeze BB/KC ratio, Entry SMA/INSTANT/PENDING, License/News/Time/Sync
- ❌ Recovery seed lot / multiplier formula ใน `PlaceRecoveryGridIfNeeded` (ใช้ของเดิมเป๊ะ)

## ไฟล์ที่แก้

- `public/docs/mql5/Golden2_EA.mq5` (version → 2.88)
- สร้าง `.lovable/memory/trading/golden2-ea/v2-8-8-recovery-grid-continuation.md`
- อัปเดต `mem://index.md`
