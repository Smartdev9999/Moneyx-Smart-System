

## เพิ่มระบบ Max Drawdown แบบ Fix Dollar ใน Gold Miner EA

### สิ่งที่เพิ่ม/แก้ไข

**1. Enum ใหม่สำหรับเลือกโหมด:**
```text
enum ENUM_DD_MODE { DD_PERCENT, DD_FIXED_DOLLAR };
```

**2. Input Parameters ใหม่ (General Settings group):**
```text
input ENUM_DD_MODE    DrawdownMode       = DD_PERCENT;  // Drawdown Mode (% or Fixed $)
input double          MaxDrawdownDollar  = 5000.0;      // Max Drawdown $ (fixed dollar)
```
- `MaxDrawdownPct` คงเดิม (ใช้เมื่อ mode = DD_PERCENT)
- `MaxDrawdownDollar` ใช้เมื่อ mode = DD_FIXED_DOLLAR

**3. แก้ไข `CheckDrawdownExit()` (~line 1742-1770):**
- เพิ่ม branch ตาม `DrawdownMode`:
  - `DD_PERCENT`: logic เดิม `(balance - equity) / balance * 100 >= MaxDrawdownPct`
  - `DD_FIXED_DOLLAR`: `(balance - equity) >= MaxDrawdownDollar`
- Print message ปรับตาม mode ที่ใช้

**4. Dashboard แถว Current DD% / Max DD%:**
- ถ้า mode = DD_FIXED_DOLLAR → แสดงเพิ่ม `$xxx / $MaxDrawdownDollar` แทน `xx% / MaxDrawdownPct%`

### ไฟล์ที่แก้ไข
`public/docs/mql5/Gold_Miner_EA.mq5`

### สิ่งที่ไม่เปลี่ยนแปลง
- Trading Strategy Logic (SMA, ZigZag, Grid entry/exit)
- Order Execution
- TP/SL/Trailing/Breakeven/Accumulate/Matching Close logic
- License / News / Time Filter core logic
- Dashboard buttons

