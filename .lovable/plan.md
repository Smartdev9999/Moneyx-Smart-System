

## แก้ไข: Gold Miner EA v6.5 → v6.6 (News Filter TZ + Close All on Expansion + Dashboard + กฎเหล็กใหม่)

### สิ่งที่แก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. News Filter — เพิ่ม Server GMT Offset Conversion
- เพิ่ม `serverGMTOffset` ใน `RefreshNewsData()` แปลง UTC → broker server time
- เพิ่ม debug print แสดง offset (1 ครั้งต่อ refresh)
- อ้างอิง logic จาก MoneyX Smart System

#### 2. เพิ่มฟังก์ชัน Close All on Expansion
- Input ใหม่: `InpSqueeze_CloseOnExpansion` (default: false)
- เมื่อ expansion >= MinTFExpansion → ปิดทุก position (ยกเว้น GM_RHEDGE)
- มี cooldown (`g_expansionCloseTriggered`) ป้องกันปิดซ้ำ
- Dashboard แสดง "ARMED" / "TRIGGERED"

#### 3. เพิ่ม "Gold Miner EA" ใน trading_systems table

#### 4. อัปเดตกฎเหล็ก `.lovable/rules.md`
- กฎ 7: Standard Modules — ต้องถามก่อนเพิ่ม (News Filter, License, Data Sync)
- กฎ 8: News Filter ต้องใช้ serverGMTOffset เสมอ
- กฎ 9: Data Sync ต้องอ้างอิง MoneyX Smart System

#### 5. Version bump: v6.5 → v6.6

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL)
- Core Module Logic (License, News filter core, Time filter, Data sync)
- Hedge system logic ทั้งหมด (Matching/Partial/AvgTP/Grid/Reverse)
- Orphan Recovery system, Comment Generation logic
