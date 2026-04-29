# Gold Miner EA v6.88 — Independent Squeeze Pause Trailing

## ปัญหา (v6.87)
`IsSqueezePausingTrailing()` อ่านจาก `g_squeezeBlocked` / `g_squeezeBuyBlocked` / `g_squeezeSellBlocked` ซึ่ง flag เหล่านี้ถูกตั้งใน `UpdateSqueezeState` ภายใต้เงื่อนไข `if(InpSqueeze_BlockOnExpansion)` เท่านั้น

ผลคือเมื่อ user ตั้ง:
- `Block New Orders on Expansion = false`
- `Pause Trailing Stop on Expansion = true`

→ flag ไม่เคยถูกตั้ง → trailing ไม่หยุด (ตามที่ user เจอ)

## แนวทางแก้ — แยก logic ออกจากกันโดยสมบูรณ์

Pause Trailing ต้องนับ TF Expansion ด้วยตัวเอง โดยอ่านจาก `g_squeeze[].state` โดยตรง ไม่พึ่ง `g_squeezeBlocked*`

### 1. เพิ่ม Input ใหม่
```cpp
input int InpSqueeze_PauseTrail_MinTF = 1;   // v6.88: Min TFs in Expansion to Pause Trailing (1-3)
```
วางใต้ `InpSqueeze_PauseTrailing` ในกลุ่ม Volatility Squeeze Filter

### 2. แก้ `IsSqueezePausingTrailing()` (~line 3132)
นับ TF ที่ `state == 2` (EXPANSION) เองจาก `g_squeeze[0..2]`:

```cpp
bool IsSqueezePausingTrailing()
{
   if(!InpUseSqueezeFilter) return false;
   if(!InpSqueeze_PauseTrailing) return false;

   int expCount = 0;
   for(int sq = 0; sq < 3; sq++)
      if(g_squeeze[sq].state == 2) expCount++;

   int minTF = InpSqueeze_PauseTrail_MinTF;
   if(minTF < 1) minTF = 1;
   if(minTF > 3) minTF = 3;

   return (expCount >= minTF);
}
```

ไม่อ่าน `g_squeezeBlocked*` อีกต่อไป → ทำงานได้แม้ `BlockOnExpansion = false`

### 3. Dashboard (optional แต่ช่วย debug)
ในส่วน Squeeze panel เพิ่มบรรทัด `Trailing: PAUSED (n TF Exp)` หรือ `Trailing: ACTIVE` เมื่อ `InpSqueeze_PauseTrailing = true`

### 4. Version bump v6.87 → v6.88
- `#property version`
- `#property description`
- Header comment block
- `OnInit` / `OnDeinit` log
- Dashboard `headerVersion`

## สิ่งที่ไม่เปลี่ยนแปลง (ยืนยันตามกฎเหล็ก)
- **ไม่แตะ Order Execution** — `OrderSend` / `trade.*` ไม่แตะ
- **ไม่แตะ Trading Strategy** — SMA / Grid Loss / Grid Profit / TP / Hedge / Accumulate / DD exit ไม่แตะ
- **ไม่แตะ `UpdateSqueezeState`** — BB/KC/ATR/Intensity/state machine ทำงานเหมือนเดิม
- **ไม่แตะ Block New Orders logic** — `g_squeezeBlocked` / `BuyBlocked` / `SellBlocked` / `InpSqueeze_BlockOnExpansion` / `InpSqueeze_MinTFExpansion` / `InpSqueeze_DirectionalBlock` / `InpSqueeze_CloseOnExpansion` ทำงานเหมือนเดิม 100%
- **ไม่แตะ Hedge Trigger Expansion** — `HEDGE_TRIGGER_EXPANSION` ทำงานเหมือนเดิม
- **ไม่แตะ guard 5 จุดของ v6.87** (`ManagePerOrderTrailing`, `ManageMaxGridTrailing`, `ManageTrailingStop_TF`, `ApplyTrailingSL`, `ApplyTrailingSL_TF`) — แค่เปลี่ยน "ใจ" ของ helper เท่านั้น
- ไม่แตะ License / News / Time / Sync

## Memory
สร้าง `mem://trading/gold-miner-ea/squeeze-pause-trailing-independent-v6-88.md` และอัปเดต `mem://index.md`
