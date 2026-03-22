

## Fix: Directional Block ไม่ทำงานเมื่อ Expansion เกิดใน TF เดียว (v5.19 → v5.20)

### สาเหตุ

Line 1038: `if(expCount >= InpSqueeze_MinTFExpansion)` — ถ้า `InpSqueeze_MinTFExpansion = 2` แต่มี expansion แค่ 1 TF (เช่น H1 เท่านั้น) → `expCount = 1 < 2` → **ไม่เข้า block เลย** → Squeeze Status แสดง "OK" ทั้งที่ H1 เป็น EXPANSION SELL

ผู้ใช้ต้องการ: **ไม่ว่า TF ไหนแค่ 1 TF ก็ต้อง block ฝั่งตรงข้ามทันที**

### การแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. แยก Directional Block ออกจาก MinTFExpansion threshold

```text
เดิม (line 1038-1054):
  if(expCount >= InpSqueeze_MinTFExpansion)
  {
     if(InpSqueeze_DirectionalBlock && bestDir != 0)
        // directional block
     else
        // block all
  }

ใหม่:
  // Directional block: ANY expansion (≥1 TF) → block counter-side
  if(InpSqueeze_DirectionalBlock && expCount >= 1 && bestDir != 0)
  {
     if(bestDir == 1)       // Bullish → block SELL
        g_squeezeSellBlocked = true;
     else                   // Bearish → block BUY
        g_squeezeBuyBlocked = true;
  }
  
  // Full block: ใช้ MinTFExpansion threshold เดิม (สำหรับ non-directional mode)
  if(!InpSqueeze_DirectionalBlock && expCount >= InpSqueeze_MinTFExpansion)
  {
     g_squeezeBlocked = true;
     g_newOrderBlocked = true;
  }
```

**ผล:** เมื่อ H1 เป็น EXPANSION SELL → `expCount=1, bestDir=-1` → `g_squeezeBuyBlocked = true` → BUY orders ทุก set ถูก block ทันที

#### 2. Version bump: v5.19 → v5.20

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL/Trailing)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Hedge/Grid Recovery logic ทั้งหมด
- Normal Matching Close logic
- Dashboard layout/styling

