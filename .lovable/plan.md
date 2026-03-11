## สร้าง EA ใหม่: Jutlameasu - Cross-Over TP/SL Hedging System

### สิ่งที่สร้าง
- **`public/docs/mql5/Jutlameasu_EA.mq5`** — EA สมบูรณ์พร้อม compile

### Core Logic
1. คำนวณ Mid Price → วาง Buy Stop + Sell Stop ที่ ±Zone/2
2. TP/SL แบบ Cross-Over: Buy TP = Sell SL, Sell TP = Buy SL
3. เมื่อ Pending ถูกกระตุ้น → วาง Pending ฝั่งตรงข้ามด้วย Lot x2 (Martingale)
4. เมื่อ TP hit → รีเซ็ต cycle ใหม่ด้วย Lot เริ่มต้น
5. Max Martingale Level + Drawdown Protection

### Modules ที่รวมอยู่
- License verification (x-api-key header)
- Data Sync (trade history)
- News Filter
- Time Filter
- Dashboard (table layout with buttons)
- OnChartEvent (Pause/Resume, Close All, New Cycle)

### สิ่งที่ไม่เปลี่ยนแปลง (ไฟล์อื่น)
- Gold_Miner_EA.mq5 — ไม่แตะ
- ไฟล์ EA อื่นทั้งหมด — ไม่แตะ
- Backend Edge Functions — ไม่แตะ
