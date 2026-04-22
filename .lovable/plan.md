
## v6.67 — Unify Recovery Mode: ใช้ Grid Recovery params ตัวเดียว ตัด Auto Init/Mult ซ้ำซ้อน

### ปัญหา (จาก image-901)

ตอนนี้มี input ซ้ำซ้อน 2 ชุดในกลุ่ม Recovery Grid:
- **Manual mode**: `GridLoss_InitLot`, `GridLoss_LotMultiplier`, `Recovery_MaxGridTrades`, `GridLoss_Distance` ฯลฯ (อยู่ด้านบน)
- **Auto mode**: `Recovery_AutoLot` (toggle), `Recovery_AutoInitLot=0.05`, `Recovery_AutoMult=1.4` (เพิ่มใน v6.65)

User สับสนว่าจะใช้ค่าชุดไหน → ต้องการให้ Auto mode **ใช้ค่า init lot + multiplier ตัวเดียวกันกับ Grid Recovery (Manual)** ไม่ต้องตั้งซ้ำ

---

## แผนแก้ไข — `public/docs/mql5/Gold_Miner_EA.mq5`

### 1) Version bump → v6.67
อัปเดต `#property version`, `#property description`, header, init/deinit log, dashboard label

### 2) ลบ input ซ้ำซ้อน
- ลบ `Recovery_AutoInitLot`
- ลบ `Recovery_AutoMult`
- คง `Recovery_AutoLot` ไว้เป็น toggle หลัก (label ปรับให้ชัด: `"Auto Recovery (Reverse-walk seed, ใช้ค่า Grid Recovery ด้านบน)"`)

### 3) ปรับ helper ทั้ง 2 ตัวให้อ่านค่าจาก Grid Recovery params

**`ComputeAutoSeedLot(double remHedgeLots)`**
```cpp
double curLot = GridLoss_InitLot;        // ← จาก v6.65: Recovery_AutoInitLot
...
curLot = normLot * GridLoss_LotMultiplier; // ← จาก v6.65: Recovery_AutoMult
```

**`ComputeAutoNextLot(double lastGridLot)`**
```cpp
double next = MathFloor((lastGridLot * GridLoss_LotMultiplier) / lotStep) * lotStep;
```

### 4) Dashboard / Logging ปรับให้สื่อความชัด
```text
Recovery Grid | Mode: AUTO | Init=0.05 Mult=1.40 (shared with Manual) | H1 seed=0.20 lvl=2/10
v6.67 SEED Set#1: rem=0.50 init=0.05 mult=1.40 series=0.05+0.07+0.10+0.14+0.20=0.56 -> seed=0.20
```

(ค่า init/mult ที่แสดงดึงจาก `GridLoss_InitLot` / `GridLoss_LotMultiplier`)

### 5) Migration หมายเหตุ
- ถ้า user เคยใช้ v6.65/v6.66 และตั้ง `Recovery_AutoInitLot=0.05` / `Recovery_AutoMult=1.4` ไว้ → MT5 จะ ignore input ที่ถูกลบโดยอัตโนมัติเมื่อ recompile
- ค่าใหม่จะใช้ `GridLoss_InitLot` / `GridLoss_LotMultiplier` ที่ user ตั้งใน Manual mode อยู่แล้ว → ไม่ต้องตั้งซ้ำ

---

## สิ่งที่ไม่เปลี่ยนแปลง

- Order Execution (`OrderSend` / `trade.Buy/Sell/PositionClose/PositionClosePartial`) — ไม่แก้
- Trading Strategy / Signal / Initial Grid / Grid Loss / Grid Profit (basket หลัก) — ไม่แก้
- Reverse-Walk Seed algorithm v6.66 (logic การเดิน series) — ไม่แก้ เปลี่ยนแค่ที่มาของ init/mult
- One-Time Shred + `shredCompleted` flag v6.66 — ไม่แก้
- Combined Avg TP (`SyncRecoveryBasketTP`) v6.66 — ไม่แก้
- `Recovery_MaxGridTrades` cap (Auto+Manual) v6.66 — ไม่แก้
- Strict Sequential Matching v6.65 — ไม่แก้
- Sequential Recovery Owner v6.59-v6.60 — ไม่แก้
- Persistent slot numbering v6.63 / Comment residue fallback v6.66 — ไม่แก้
- Hedge open trigger / Triple Gate / DD threshold / Reverse — ไม่แก้
- BB Filter / Recovery distance / candle confirm / Re-hedge guard — ไม่แก้
- Accumulate Close / Balance Guard / News / License / Time Filter — ไม่แก้

## Validation Checklist

1. หน้า input ของ EA: เห็นเฉพาะ `Recovery_AutoLot` (toggle) ในกลุ่ม Auto — ไม่มี Init/Mult แยกอีกแล้ว
2. `Recovery_AutoLot=true`, `GridLoss_InitLot=0.05`, `GridLoss_LotMultiplier=1.4`, hedge=0.50 → seed=0.20, ถัดไป 0.28 (เหมือน v6.66)
3. เปลี่ยน `GridLoss_InitLot=0.10` → seed คำนวณใหม่จาก 0.10 ทันที (Manual + Auto sync ค่ากัน)
4. `Recovery_AutoLot=false` → ใช้ Manual mode เดิม 100% (regression)
5. Dashboard แสดง `Init=0.05 Mult=1.40` ดึงจาก GridLoss_* ตรงกับที่ user ตั้ง
6. Recompile EA เก่าที่มี Recovery_AutoInit/Mult ใน .set file → ไม่ error, ค่าถูก ignore เงียบๆ
