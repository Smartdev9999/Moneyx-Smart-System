# Golden2 EA v2.6 — Re-entry Pending Order หลังปิดออเดอร์

## ปัญหา
ใน Group ที่ active เมื่อ pending stop ฝั่งหนึ่งถูก trigger → กลายเป็น market position → ปิดด้วย TP/SL → ฝั่งนั้น "ว่าง" (ไม่มีทั้ง position และ pending) ทำให้ frame เหลือฝั่งเดียว

ตัวอย่างจากภาพ: G3 #125 BuyStop trigger → buy 0.01 → TP ที่ 4604.04 → ปิด → ฝั่ง Buy ของ G3 ว่างทันที เหลือแค่ SellStop #126 ฝั่ง