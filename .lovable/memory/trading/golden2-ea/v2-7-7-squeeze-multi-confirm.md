---
name: Golden2 EA v2.7.7 — Squeeze Multi-Confirm
description: v2.7.7 adds ADX + BB-Breakout + ATR-MA + EMA confirmation stages on top of BB/KC ratio for the Volatility Squeeze Filter. All enabled stages must pass (AND) before a TF is flagged Expansion. Per-TF dashboard shows BB/ADX/ATR/EMA pass marks.
type: feature
---

# Golden2 EA v2.7.7 — Volatility Squeeze Multi-Confirm

ไฟล์: `public/docs/mql5/Golden2_EA.mq5`

## Pipeline ใหม่ (ต่อ TF) — AND
1. BB/KC ratio ≥ `InpSQ_ExpansionThreshold` (1.6)
2. BB Breakout — close[1] > BB Upper หรือ < BB Lower (ถ้า `InpSQ_UseBBBreakout`)
3. ADX — ADX[1] ≥ `InpSQ_ADXThreshold` (25) + DI+/DI− ตรงทิศ
4. ATR — atr[1] ≥ ATR-MA(`InpSQ_ATRMAPeriod`=20) × `InpSQ_ATRMult` (1.0)
5. EMA — close[1] อยู่ฝั่งเดียวกับ EMA(`InpSQ_EMAPeriod`=50) ตามทิศ

ทุกตัวเปิด/ปิดได้แยกกัน (`InpSQ_UseADX/UseEMA/UseATRConfirm/UseBBBreakout`) — ปิดทั้งหมด = พฤติกรรมเดิม v2.7.6

## Inputs (default)
- `InpSQ_UseBBBreakout=true`
- `InpSQ_UseADX=true`, `InpSQ_ADXPeriod=14`, `InpSQ_ADXThreshold=25.0`
- `InpSQ_UseATRConfirm=true`, `InpSQ_ATRMAPeriod=20`, `InpSQ_ATRMult=1.0`
- `InpSQ_UseEMA=true`, `InpSQ_EMAPeriod=50`, `InpSQ_EMAPrice=PRICE_CLOSE`

## Dashboard
แต่ละ TF เพิ่มแถว `Confirm  BB:v ADX:v(25.3) ATR:v EMA:v` (v=pass, x=fail, แสดง ADX value)

## ไม่เปลี่ยน
- ไม่แตะ Order execution / Hedge / Grid / Initial frame / Entry mode (PENDING/SMA/INSTANT)
- ไม่แตะ `SqueezeBlocksSide` / `RefreshSqueezeStateThrottled`
- Backward compatible — closed `.set` เก่ายังใช้ได้ (input ใหม่มี default)
