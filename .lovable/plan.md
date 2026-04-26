# Gold Miner EA v6.82 — Grid Profit Candle Confirmation (DONE)

ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

มิเรอร์ logic จาก v6.40 (GL CandleConfirm) มาฝั่ง Grid Profit สมมาตร

- Input ใหม่: `GridProfit_CandleConfirm` (default 0)
- เช็คใน `CheckGridProfit` + `CheckGridProfitTF` (MTF)
- Dashboard: แถว "GP CandleConfirm"
- Reuse `HasCandleConfirmation()` เดิม
- Version bump: v6.81 → v6.82 (header, #property, OnInit log, Deinit log, Dashboard headerVersion)
