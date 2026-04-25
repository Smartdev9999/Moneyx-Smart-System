# Golden2 EA v2.7.8 — Force-Close Opp Unhedged on Hedge Lock (DONE)

ไฟล์: `public/docs/mql5/Golden2_EA.mq5`

เมื่อกรุ๊ปถูก hedge-lock ฝั่งใดฝั่งหนึ่ง → ระบบปิด main ฝั่งตรงข้ามที่ไม่ถูกคุมโดย hedge ทันที (ไม่สนกำไร/ขาดทุน) เพื่อให้ hedge สะอาด และ G ใหม่เปิดต่อได้

- Inputs: `InpHedge_ForceCloseOppUnhedged` (ON), `InpHedge_ForceCloseDelaySec` (3s)
- ฟังก์ชันใหม่: `ForceCloseUnhedgedOppositeSide(g)` + `ForceCloseSideMain(g, side)`
- Hook: ใน `TryAdvanceToNextGroup()` หลัง `DeleteLeftoverInitialPendingsAfterHedge`
- Dashboard: แถว "Force-Close Opp"
- Version: v2.7.8 (header, #property, L_TITLE, OnInit log)
