# Gold Miner EA v6.89 — Pause Trailing Strip Broker SL (DONE)

ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

## เพิ่ม
- `InpSqueeze_PauseTrail_StripSL` (default true)
- `g_squeezePauseTrailingActive` (edge state)
- `StripTrailingBrokerSL()` — clear SL on _INIT/_GL/_GP (skip hedge tickets)
- `IsTrailingPausedAndHandleEdge()` — edge handler + state reset + strip on Normal→Pause
- Pause guard ใน `ManageTrailingStop()` (จุดที่หายไปใน v6.87)
- `SyncBrokerTPSL` force `effectiveSl=0` ตอน paused → ป้องกัน re-apply SL เก่า

## พฤติกรรม
- Pause edge → strip + reset trailing state ครั้งเดียว
- ระหว่าง Pause → ทุก trailing manager skip + SyncBrokerTPSL บังคับ SL=0
- Resume → log + trailing เริ่มจากราคาปัจจุบัน

## ไม่เปลี่ยน
- Hedge SL/TP / Order execution / Strategy / Grid / TP / Accumulate / Block orders / News / License

## Version
v6.88 → v6.89

## Memory
`mem://trading/gold-miner-ea/squeeze-pause-strip-sl-v6-89.md`
