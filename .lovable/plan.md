# Gold Miner EA v6.92 — Hero Order Feature

## เจตนา (สรุปจากที่ user อธิบาย)

Hero Order = "เก็บ N order ใหม่สุด ของ generation+side ปัจจุบัน" แยกออกจากชุดที่ใช้คำนวณ Average เพื่อให้:

1. Avg TP / MaxGrid Trail / Avg SL ปกติ คำนวณจาก order เก่าเท่านั้น (basket = total - N) → ปิด basket ได้เร็วขึ้น
2. Hero N ตัวที่เหลือ ใช้ **trailing-per-order ของเดิม** (`ManagePerOrderTrailing`) ล็อคกำไรเอง
3. ระหว่างที่ยังมี Hero ค้างอยู่บนฝั่งใด → **ห้ามออก INIT/GL/GP ฝั่งนั้น** (ฝั่งตรงข้ามทำงานปกติเต็มรูปแบบ)
4. เมื่อฝั่งตรงข้าม TP/Trail ปิ