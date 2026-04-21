
## v6.60 — แก้ Sequential Recovery ให้ขาด: GM ต้องเป็น Owner ได้ และนับ owner เฉพาะ order ของ generation นั้นจริงๆ

### ปัญหาที่เจอจริงจากรูปและ log

อาการตอนนี้ไม่ใช่แค่ dashboard เพี้ยน แต่เป็น **owner lock ไปจับ generation ผิดตัว** ทำให้ดูเหมือนระบบยัง “ปลดพร้อมกัน” อยู่

หลักฐานจาก log/ภาพ:
- Dashboard แสดง `LOCKED | Owner Gen1 (Src H2)` ทั้งที่ยังมี `Gen0 (GM)` ค้างอยู่
- Journal มี `v6.59 SEQ WAIT: Skip orphan Gen0 (owner=Gen1)`
- แปลว่า queue ไปล็อคที่ **H2 / Gen1** ก่อน ทั้งที่ **H1 / GM / Gen0** ยังไม่ปิดหมด

### Root cause ที่แท้จริง

1. `SetSequentialRecoveryOwner()` มี guard `if(gen <= 0) return;`
   - ทำให้ **GM / Gen0 ไม่มีสิทธิ์เป็น owner**
   - ถ้า H1 ปลดแล้ว boundGen = 0 ระบบจะไม่ assign owner
   - จากนั้นพอ H2 ปลด → Gen1 กลายเป็น owner ทันที
   - ผลคือคิว recovery ข้าม H1 ไปจับ H2

2. `CountAllGenPositions()` นับ generation จาก `ExtractGeneration(comment)` แบบกว้างเกินไป
   - comment พวก `GM_HEDGE_*`, `GM_HG*`, `GM_RHEDGE*` ถูกตีเป็น `Gen0`
   - ถ้าเปิดให้ Gen0 เป็น owner โดยไม่แก้ตัวนับนี้ ระบบจะ **นับ hedge/grid-hedge/reverse hedge ปนกับ GM ปกติ**
   - ทำให้ owner completion ของ Gen0 ผิด และ unlock timing เพี้ยนต่อ

3. ดังนั้นบั๊กหลักของ v6.59 คือ
   - **Gen0 claim owner ไม่ได้**
   - และตัวนับ owner ยังไม่แม่นพอสำหรับการตัดสินว่า “ชุดนี้ปิดหมดแล้วจริงหรือยัง”

---

## แผนแก้ไข — `public/docs/mql5/Gold_Miner_EA.mq5`

### 1) Version bump → v6.60
อัปเดตทุกจุด:
- `#property version`
- `#property description`
- header comment
- init/deinit log
- dashboard version label

### 2) แก้ owner claim ให้ GM / Gen0 ใช้งานได้จริง
เปลี่ยนใน `SetSequentialRecoveryOwner()` จาก:
```cpp
if(gen <= 0) return;
```
เป็น:
```cpp
if(gen < 0) return;
```

ผลลัพธ์:
- H1 ที่มี `boundGeneration = 0` จะ claim owner ได้
- ลำดับจะเริ่มจาก GM/H1 จริง ไม่โดดไป H2

### 3) แยกตัวนับ owner ใหม่ให้ “นับเฉพาะ order recovery ของ generation นั้น”
ไม่ใช้ `CountAllGenPositions()` แบบเดิมในการตัดสิน owner อีกต่อไป

เพิ่ม helper ใหม่ เช่น:
```cpp
int CountSequentialOwnerOrders(int gen);
```

กติกาการนับ:
- นับเฉพาะ order ของ EA + symbol นี้
- **ข้าม hedge comments ทั้งหมด**
  - `GM_HEDGE_*`
  - `GM_HG*`
  - `GM_RHEDGE*`
- ใช้ prefix แบบ exact:
  - `gen == 0` → ต้องขึ้นต้นด้วย `GM_`
  - `gen > 0` → ต้องขึ้นต้นด้วย `GM<gen>_`
- นับเฉพาะ order ปกติของ generation นั้น เช่น `_INIT`, `_GL`, `_GP` ที่ยังเปิดอยู่

ผลลัพธ์:
- Gen0 owner จะนับเฉพาะ `GM_INIT / GM_GL#...`
- ไม่นับ hedge/reverse/grid-hedge ปน
- owner complete จะตรงกับ requirement จริง: “ปิดชุดนั้นหมดก่อนค่อย unlock ชุดถัดไป”

### 4) เปลี่ยนทุกจุดของ Sequential Owner ให้ใช้ตัวนับใหม่
จุดที่ต้องเปลี่ยน:
- `SetSequentialRecoveryOwner()` → ใช้ `CountSequentialOwnerOrders(gen)` เช็คว่ามี released orders จริงไหม
- `IsSequentialRecoveryComplete()` → ใช้ `CountSequentialOwnerOrders(g_sequentialRecoveryGen) == 0`
- Dashboard owner count → ใช้ตัวนับใหม่ ไม่ใช้ `CountAllGenPositions()`

ผล:
- Dashboard จะสะท้อน owner จริง
- logic clear owner จะตรงกับของจริง
- Gen0 จะไม่ติดค้างเพราะนับ hedge comment ผิด

### 5) คง owner lock เดิม แต่ทำให้ “จับเจ้าของคิวถูกตัว”
ใน `ManageHedgeSets()` และ `ManageOrphanGrid()` จะยังใช้โครงเดิมของ v6.59:
- มี owner active → block release ของ set อื่น
- orphan recovery ทำงานเฉพาะ owner gen
- one-tick handoff ยังอยู่

แต่หลังแก้ v6.60:
- H1 release แล้ว → owner = Gen0 ได้จริง
- H2/H3 จะถูกล็อคจนกว่า `GM / Gen0` ปิดหมดจริง
- เมื่อ Gen0 flat → clear owner → tick ถัดไปค่อยอนุญาต H2

### 6) เพิ่ม log debug ให้ชัดเฉพาะจุดสำคัญ
เพิ่ม log แบบ event-based:
- ตอน owner claim สำเร็จ
- ตอน claim ไม่สำเร็จเพราะไม่มี released orders
- ตอน owner complete
- ตอน skip orphan เพราะรอ owner

ตัวอย่าง:
```cpp
Print("v6.60 SEQ OWNER: Gen", gen, " claimed from Set#", idx + 1);
Print("v6.60 SEQ OWNER SKIP: Gen", gen, " has 0 released recovery orders");
Print("v6.60 SEQ COMPLETE: Gen", gen, " flat -> unlock next set next tick");
```

### 7) Dashboard ปรับข้อความให้ตรงกับ behavior จริง
ตัวอย่างหลังแก้:
```text
Hedge Recovery | LOCKED | Owner Gen0 (Src H1) | 3 order(s) left
ORPHAN RECOVERY | 2 group(s)
Gen0 (GM)  | ACTIVE OWNER
Gen1 (GM1) | WAITING
```

เมื่อ H1 จบ:
```text
Hedge Recovery | Sequential | Next Unlock: H2
```

---

## สิ่งที่ไม่เปลี่ยนแปลง

- Order Execution Logic (`trade.Buy`, `trade.Sell`, `trade.PositionClose`) — ไม่แก้
- Trading Strategy Logic / signal / TP/SL / grid logic หลัก — ไม่แก้
- Hedge open trigger conditions / Expansion / DD thresholds — ไม่แก้
- Triple Gate logic ภายใน `IsHedgeCloseAllowed()` — ไม่แก้
- Matching Close / BoundAvgTP / PartialClose ตรรกะภายใน — ไม่แก้
- Orphan recovery entry rules / Recovery grid settings v6.57 — ไม่แก้
- Re-hedge guard `IsPrevHedgedTicket()` ของ v6.58 — คงไว้
- BB Filter / Balance Guard / News / License / Time Filter / Data Sync — ไม่แก้

## ผลลัพธ์ที่คาดหวังหลังแก้

1. ถ้า H1 มี `boundGeneration = 0` ระบบจะ lock ที่ **Gen0 / H1** ได้ทันที
2. H2/H3/H4 จะไม่สามารถปลดตามมาได้จนกว่า order ของ H1 จะปิดหมดจริง
3. owner completion จะไม่เพี้ยนจาก hedge comments ที่ถูกตีเป็น Gen0
4. Dashboard จะไม่โชว์ `Owner Gen1 (Src H2)` ทั้งที่ GM ยังไม่จบ
5. Sequential recovery จะกลายเป็น “ทีละชุดจน flat จริง” ตาม requirement เดิมแบบ fix-only

## Validation checklist หลัง implement

1. Scenario: มี H1=GM และ H2=GM1 พร้อมกัน
   - เมื่อ H1 release → dashboard ต้องขึ้น `Owner Gen0 (Src H1)`
   - ห้ามขึ้น `Owner Gen1` ก่อน GM ปิดหมด

2. ระหว่าง Gen0 owner active
   - log ต้องมี `Skip orphan Gen1 (owner=Gen0)`
   - H2 ต้องยังไม่ release

3. เมื่อ GM/Gen0 ปิดครบทั้งหมด
   - owner clear
   - tick ถัดไปเท่านั้น H2 จึงมีสิทธิ์ release

4. ทดสอบซ้ำกับกรณี Gen1 → Gen2
   - ต้องไล่ตามลำดับ H1 → H2 → H3 จริง

