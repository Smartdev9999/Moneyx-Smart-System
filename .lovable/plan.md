

## แผนการแก้ไข Gold Miner EA v6.5 → v6.6 (4 งาน)

---

### งาน 1: แก้ News Filter — เพิ่ม Server GMT Offset Conversion

**ปัญหาที่พบ:** Line 5436 ใน `RefreshNewsData()`:
```cpp
datetime eventTime = (datetime)StringToInteger(timestampStr);
```
API ส่ง timestamp เป็น UTC แต่ EA ไม่ได้แปลงเป็น broker server time ทำให้ News Filter พักเทรดผิดเวลาถ้า broker ไม่อยู่ UTC

**Reference (MoneyX Smart System):** MT5EAGuide.tsx line 7831-7836 มีการคำนวณ:
```cpp
int serverGMTOffset = (int)(TimeCurrent() - TimeGMT());
eventTime += serverGMTOffset;
```

**แก้ไข:** เพิ่ม 3 บรรทัดหลัง line 5436:
```cpp
datetime eventTime = (datetime)StringToInteger(timestampStr);
// Convert UTC timestamp to broker server time (same as MoneyX Smart System)
int serverGMTOffset = (int)(TimeCurrent() - TimeGMT());
eventTime += serverGMTOffset;
```

เพิ่ม debug print (1 ครั้งต่อ refresh):
```cpp
static bool tzDebugPrinted = false;
if(!tzDebugPrinted) {
   Print("NEWS FILTER TZ: Server GMT offset = ", serverGMTOffset/3600, "h");
   tzDebugPrinted = true;
}
```

---

### งาน 2: เพิ่ม "Gold Miner EA" ใน Dashboard Monitoring

EA ส่ง `ea_name` อยู่แล้ว แต่ต้องเพิ่ม record ในตาราง `trading_systems` ผ่าน database migration:
```sql
INSERT INTO trading_systems (name, description, version, is_active)
VALUES ('Gold Miner EA', 'Gold Miner SQ EA - MTF ZigZag + CDC + Squeeze + Grid + Hedging', '6.6', true)
ON CONFLICT DO NOTHING;
```

---

### งาน 3: เพิ่มฟังก์ชัน Close All on Expansion

**Input Parameter ใหม่:**
```cpp
input bool InpSqueeze_CloseOnExpansion = false;  // Close All Orders on Expansion
```

**Logic:** เพิ่มใน OnTick หลัง squeeze block check (line ~1128) เมื่อ `expCount >= InpSqueeze_MinTFExpansion`:
```cpp
if(InpSqueeze_CloseOnExpansion && !g_expansionCloseTriggered) {
   CloseAllOnExpansion();
   g_expansionCloseTriggered = true;
}
```

Reset `g_expansionCloseTriggered = false` เมื่อ `expCount < InpSqueeze_MinTFExpansion` (cooldown ป้องกันปิดซ้ำทุก tick)

**ฟังก์ชัน `CloseAllOnExpansion()`:**
- สแกน positions ทั้งหมดที่ MagicNumber ตรง
- Skip reverse hedge orders (`GM_RHEDGE`)
- ปิดทุก position ด้วย `trade.PositionClose()`
- Print log จำนวนที่ปิด

**Dashboard:** แสดง `CLOSE ALL: TRIGGERED` เมื่อ feature ทำงาน

---

### งาน 4: อัปเดตกฎเหล็ก `.lovable/rules.md`

เพิ่ม 3 กฎใหม่:

**กฎที่ 7: Standard Modules Reference**
- ทุกครั้งที่สร้าง EA ใหม่ ต้องถามผู้ใช้ก่อนว่าจะเพิ่ม News Filter, License Check, และ Data Sync หรือไม่
- ไฟล์อ้างอิงหลัก: `docs/mql5/Moneyx_Smart_Gold_EA_Licensed.mq5`
- ห้ามเพิ่ม modules เหล่านี้โดยไม่ได้รับอนุญาต

**กฎที่ 8: News Filter Implementation**
- ต้องใช้ `serverGMTOffset` แปลง UTC → broker time เสมอ
- อ้างอิง logic จาก MoneyX Smart System

**กฎที่ 9: Data Sync Implementation**
- ต้องอ้างอิงรูปแบบการ sync จาก MoneyX Smart System
- รวมถึง trade history sync

---

### Version bump: v6.5 → v6.6

อัปเดต: `#property version "6.60"`, `#property description`, Header comment, Dashboard, Print log

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose — ไม่แก้ logic เดิม แค่เพิ่มจุดเรียก close ใน feature ใหม่)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL)
- Core Module Logic (License, Time filter, Data sync — News Filter แค่เพิ่ม timezone offset)
- Hedge system logic ทั้งหมด (Matching/Partial/AvgTP/Grid/Reverse)
- Orphan Recovery system

